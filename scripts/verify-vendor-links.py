#!/usr/bin/env python3
"""Require all pinned OnePlus kernel symlinks into the public vendor tree."""
from pathlib import Path
import sys

# Verified against pinned OnePlusOSS android_kernel_oneplus_mt6897 source.
EXPECTED_LINKS = (
    "kernel/oplus_cpu",
    "mm/mm-trace.h",
    "kernel/locking/locking_main.h",
    "kernel/locking/oplus_locking.c",
    "kernel/locking/sa_common_struct.h",
    "include/soc/oplus/storage",
    "drivers/soc/oplus/oplus_resctrl",
    "drivers/soc/oplus/storage",
)

def verify(source: Path):
    source = source.resolve()
    workspace = source.parent.resolve()
    failures = []
    for name in EXPECTED_LINKS:
        link = source / name
        if not link.is_symlink():
            failures.append(name + ": expected upstream symlink is absent")
            continue
        target = link.resolve()
        if not target.is_relative_to(workspace):
            failures.append(name + ": target escapes build workspace")
        elif not link.exists():
            failures.append(name + ": vendor target is missing")
    return failures

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: verify-vendor-links.py <kernel-source>")
    errors = verify(Path(sys.argv[1]))
    if errors:
        for error in errors:
            print("VENDOR LINK ERROR: " + error, file=sys.stderr)
        sys.exit(1)
    print("All 8 pinned OnePlus vendor symlinks resolve.")
