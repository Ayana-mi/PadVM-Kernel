# PadVM Kernel

Experimental OnePlus Pad (OPD2407 / MT6897) Linux 6.1.134 kernel build.

**WARNING: Experimental build only. DO NOT FLASH.** Device-tree selection, vendor ABI, recovery, BakaSU integration and GenieZone firmware support have NOT passed on-device verification.

## Components
- Pinned OnePlusOSS 6.1.134 Android14 source
- BakaSU (formerly ReSukiSU), pinned development revision, built in
- MediaTek GZVM built in (build-time experiment only)
- Baseband-guard (BBG) LSM, pinned
- Oplus security/tuning vendor modules blocked via `module_blacklist=`
- No SuSFS
- Manual GitHub-hosted Actions build; no automatic Release

## 中文
PadVM Kernel 是一加 Pad 的实验性自定义内核项目。本项目只验证编译与离线兼容，**产物未经实机验证，不得刷机**。启用 GZVM 不代表固件能够创建虚拟机。BakaSU 需要配套管理器和挂载 metamodule 才能替换现有 Root 方案。

Upstream credits, source versions, copyright and licensing are in [UPSTREAM.md](UPSTREAM.md) and [sources.lock.json](sources.lock.json).
