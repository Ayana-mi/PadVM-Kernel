# Upstream sources and licensing

- OnePlusOSS [android_kernel_oneplus_mt6897](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6897): Linux 6.1.134, Android14, exact pinned source. Linux kernel GPL-2.0-only overall; retain per-file SPDX and applicable exceptions.
- OnePlusOSS [modules and device tree](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_mt6897): pinned source revision. The build fetches only the public Oplus CPU, storage, resctrl, synchronize, and mm_osvelte source folders via sparse checkout to resolve the official kernel's external symlinks. No proprietary prebuilt vendor modules, firmware, device dumps, or full private source tree are uploaded here.
- [BakaSU](https://github.com/Baka-SU/BakaSU) (formerly ReSukiSU): pinned main commit; kernel subtree GPL-2.0-only, manager/application and assets have different licensing; no APK included.
- Android Clang and Android kernel build tools: pinned Android public source archives, copyright notices remain with upstream.
- SYSVIPC KABI adaptation: based on [Droidspaces 6.1-compatible patch](https://github.com/ravindu644/Droidspaces-OSS/blob/b48a01de6b7d5f346f7c5028ac7959ddb3561237/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch), adjusted for the pinned OnePlus kernel. Retain Droidspaces attribution and applicable upstream terms.

A future public binary distribution must provide complete corresponding source as required by the applicable licenses. No device image, firmware, private config, auth material or vendor binary is distributed.

Source archive integrity uses normalized tar-entry fingerprints (content, paths, modes and links) pinned in `sources.lock.json`, not compressed tar.gz SHA-256 bytes, which upstream archives can change even at a fixed revision. Original compressed checksums are kept as non-authoritative references.
