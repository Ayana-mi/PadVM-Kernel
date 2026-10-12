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
    sha="$(lockval "$kind.sha256")"
    curl --fail --location --retry 3 --silent --show-error "$url" -o "$archive"
    echo "$sha  $archive" | sha256sum --check --status
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

echo '[3/5] Fetch pinned BakaSU revision'
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

echo '[4/5] KABI patch and required config (no SuSFS)'
patch -d "$SRC" -p1 --batch --forward < "$ROOT/patches/pad-sysvipc-kabi.patch"
CFG="$SRC/scripts/config"
"$CFG" --file "$OUT/.config" --set-str LOCALVERSION '-android14-PADVM-0.1.0' --disable LOCALVERSION_AUTO
"$CFG" --file "$OUT/.config" --enable KSU --enable KSU_TRACEPOINT_HOOK --disable KSU_SUSFS --enable MTK_GZVM
"$CFG" --file "$OUT/.config" --enable DEBUG_INFO_BTF --enable LTO_CLANG --enable LTO_CLANG_THIN --enable CFI_CLANG
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
