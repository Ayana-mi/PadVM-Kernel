#!/usr/bin/env bash
# Manually dispatched CI build. No device access, boot images or flash commands.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${RUNNER_TEMP:?Expected ephemeral hosted GitHub runner}/padvm"
SRC="$WORK/kernel"
OUT="$WORK/out"
CLANG="$WORK/clang"
TOOLS="$WORK/build-tools"
LOCK="$ROOT/sources.lock.json"
mkdir -p "$SRC" "$OUT" "$CLANG" "$TOOLS"
umask 077

lockval() {
    python3 - "$LOCK" "$1" <<'PY'
import json,sys
group,key=sys.argv[2].split(".",1)
print(json.load(open(sys.argv[1]))[group][key])
PY
}
fetch_archive() {
    local kind="$1" dest="$2" mode="${3:-}" archive="$WORK/$1.tar.gz"
    local url sha
    url="$(lockval "$kind.url")"
    sha="$(lockval "$kind.content_sha256")"
    echo "Fetching pinned source component: $kind"
    curl --fail --location --retry 3 --silent --show-error "$url" -o "$archive"
    # Generated GitHub/Gitiles tar.gz bytes are not a stable integrity anchor.
    # Verify exact names, modes, links and file bytes against our pinned content manifest.
    python3 "$ROOT/scripts/verify-archive.py" "$archive" --expected "$sha"
    if [[ "$mode" == "strip" ]]; then
        tar -xzf "$archive" -C "$dest" --strip-components=1
    else
        tar -xzf "$archive" -C "$dest"
    fi
    rm -- "$archive"
}
echo '[1/5] Exact upstream source archives'
fetch_archive kernel "$SRC" strip
fetch_archive clang "$CLANG"
fetch_archive build_tools "$TOOLS"

# Official kernel contains symlinks into sibling vendor and oplus_cpu trees.
# Sparse fetch from the exact pinned public OnePlusOSS modules revision.
echo 'Fetching pinned vendor Kconfig and Oplus source directories'
VENDOR="$WORK/vendor-modules"
git init -q "$VENDOR"
git -C "$VENDOR" remote add origin "https://github.com/$(lockval vendor_reference.repo).git"
git -C "$VENDOR" sparse-checkout init --cone
git -C "$VENDOR" sparse-checkout set \
    vendor/oplus/kernel/oplus_performance/oplus_resctrl \
    vendor/oplus/kernel/storage \
    vendor/oplus/kernel/cpu \
    vendor/oplus/kernel/synchronize \
    vendor/oplus/kernel/mm/mm_osvelte
git -C "$VENDOR" fetch --quiet --filter=blob:none --depth=1 origin "$(lockval vendor_reference.commit)"
git -C "$VENDOR" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD
test "$(git -C "$VENDOR" rev-parse HEAD)" = "$(lockval vendor_reference.commit)"
mkdir -p "$WORK/vendor"
ln -s ../vendor-modules/vendor/oplus "$WORK/vendor/oplus"
# Check every original external symlink, not just the initial Kconfig entries.
# Otherwise a compilation can fail minutes later due to a dangling header.
python3 "$ROOT/scripts/verify-vendor-links.py" "$SRC"
export PATH="$CLANG/bin:$TOOLS/bin:$PATH"
export KBUILD_BUILD_USER=Ayana-mi
export KBUILD_BUILD_HOST=github-actions
export KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP='Mon Oct 12 00:00:00 UTC 2026'
command -v clang >/dev/null
command -v ld.lld >/dev/null
command -v pahole >/dev/null
echo '[2/5] Official baseline configuration'
make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j1 gki_defconfig

echo '[3/5] Fetch pinned BakaSU and BBG revisions'
BAKASU="$SRC/KernelSU"
git init -q "$BAKASU"
git -C "$BAKASU" remote add origin https://github.com/Baka-SU/BakaSU.git
git -C "$BAKASU" fetch --quiet --depth=1 origin "$(lockval bakasu.commit)"
git -C "$BAKASU" -c advice.detachedHead=false checkout --quiet --detach FETCH_HEAD
# BakaSU's Kbuild computes the kernel version from Git history.
# Never silently accept a shallow history: it would report the wrong version.
git -C "$BAKASU" fetch --quiet --unshallow origin
git -C "$BAKASU" fetch --quiet --tags origin
test "$(git -C "$BAKASU" rev-parse HEAD)" = "$(lockval bakasu.commit)"
test "$(git -C "$BAKASU" rev-list --count HEAD)" -ge 4000
test ! -e "$SRC/drivers/kernelsu"
ln -s ../KernelSU/kernel "$SRC/drivers/kernelsu"
printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$SRC/drivers/Makefile"
printf '\nsource "drivers/kernelsu/Kconfig"\n' >> "$SRC/drivers/Kconfig"

echo 'Fetch pinned Baseband-guard (BBG) revision'
# Full clone: BBG's Makefile would otherwise try to unshallow during make.
BBG="$SRC/Baseband-guard"
git clone --quiet "https://github.com/$(lockval bbg.repo).git" "$BBG"
git -C "$BBG" -c advice.detachedHead=false checkout --quiet --detach "$(lockval bbg.commit)"
test "$(git -C "$BBG" rev-parse HEAD)" = "$(lockval bbg.commit)"
# Same integration as the upstream install script for DEFINE_LSM kernels; that script is not run.
test ! -e "$SRC/security/baseband-guard"
ln -s ../Baseband-guard "$SRC/security/baseband-guard"
printf '\nobj-$(CONFIG_BBG) += baseband-guard/\n' >> "$SRC/security/Makefile"
awk '{a[NR]=$0} END{last=0; for(i=1;i<=NR;i++) if(a[i] ~ /^endmenu[[:space:]]*$/) last=i;
     for(i=1;i<=NR;i++){ if(i==last) print "source \"security/baseband-guard/Kconfig\""; print a[i] }}' \
    "$SRC/security/Kconfig" > "$SRC/security/Kconfig.new"
mv "$SRC/security/Kconfig.new" "$SRC/security/Kconfig"
grep -q 'security/baseband-guard/Kconfig' "$SRC/security/Kconfig"

echo '[4/5] KABI patch and required config (no SuSFS)'
patch -d "$SRC" -p1 --batch --forward < "$ROOT/patches/pad-sysvipc-kabi.patch"
CFG="$SRC/scripts/config"
"$CFG" --file "$OUT/.config" --set-str LOCALVERSION '-android14-PADVM-0.1.0' --disable LOCALVERSION_AUTO
"$CFG" --file "$OUT/.config" --enable KSU --enable KSU_TRACEPOINT_HOOK --disable KSU_SUSFS --enable MTK_GZVM
"$CFG" --file "$OUT/.config" --enable DEBUG_INFO_BTF --enable LTO_CLANG --enable LTO_CLANG_THIN --enable CFI_CLANG
# Baseband-guard LSM; boot/recovery partition blocking stays off (upstream default).
"$CFG" --file "$OUT/.config" --enable BBG --disable BBG_BLOCK_BOOT --disable BBG_BLOCK_RECOVERY
"$CFG" --file "$OUT/.config" --set-str LSM 'landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,baseband_guard,smack,tomoyo,apparmor,bpf'
# Block Oplus security/tuning vendor modules via the kernel's own module_blacklist= parameter
# (appended through CMDLINE_EXTEND); no kernel patch needed.
"$CFG" --file "$OUT/.config" --set-str CMDLINE 'console=ttynull stack_depot_disable=on cgroup_disable=pressure kasan.page_alloc.sample=10 kasan.stacktrace=off kvm-arm.mode=protected bootconfig ioremap_guard module_blacklist=kernelsu,oplus_security_guard,oplus_qr_scan,oplus_score,oplus_vip_task,oplus_dns_cache,oplus_network_linkpower_module,oplus_data_module,oplus_secure_harden,oplus_security_keventupload,oplus_secure_guard_new,oplus_secure_guard,oplus_network_tuning,oplus_networks_tuning'
make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j1 olddefconfig
python3 "$ROOT/scripts/verify-config.py" "$OUT/.config" "$ROOT/configs/required.config"

echo '[5/5] Full Image and modules, all runner cores'
make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j"$(nproc)" Image modules
test -s "$OUT/arch/arm64/boot/Image"
test -s "$OUT/Module.symvers"
mkdir -p "$ROOT/.build/artifact"
cp "$OUT/arch/arm64/boot/Image" "$OUT/.config" "$OUT/Module.symvers" "$ROOT/.build/artifact/"
cp "$LOCK" "$ROOT/.build/artifact/sources.lock.json"
(cd "$ROOT/.build/artifact" && sha256sum Image .config Module.symvers > SHA256SUMS)
echo 'EXPERIMENTAL - NOT FOR FLASHING' > "$ROOT/.build/artifact/NOT_FOR_FLASHING.txt"
echo 'Image built; Pad was not accessed.'
