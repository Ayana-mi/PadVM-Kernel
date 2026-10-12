# Upstream sources and licensing

- OnePlusOSS [android_kernel_oneplus_mt6897](https://github.com/OnePlusOSS/android_kernel_oneplus_mt6897): Linux 6.1.134, Android14, exact pinned source. Linux kernel GPL-2.0-only overall; retain per-file SPDX and applicable exceptions.
- OnePlusOSS [modules and device tree](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_mt6897): pinned reference only, not uploaded or redistributed here.
- [BakaSU](https://github.com/Baka-SU/BakaSU) (formerly ReSukiSU): pinned main commit; kernel subtree GPL-2.0-only, manager/application and assets have different licensing; no APK included.
- Android Clang and Android kernel build tools: pinned Android public source archives, copyright notices remain with upstream.
- SYSVIPC KABI adaptation: derived from Droidspaces' Android ABI-compatible SYSVIPC relocation approach; adjusted for the pinned OnePlus kernel. Preserve upstream authors' rights and GPL-2.0-only applicability.

A future public binary distribution must provide complete corresponding source as required by the applicable licenses. No device image, firmware, private config, auth material or vendor binary is distributed.
