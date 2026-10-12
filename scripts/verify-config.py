#!/usr/bin/env python3
"""Check that the output kernel configuration keeps critical features."""
import pathlib
import sys

def check(config, required):
    actual = set(pathlib.Path(config).read_text().splitlines())
    needed = [s.strip() for s in pathlib.Path(required).read_text().splitlines() if s.strip()]
    missing = [line for line in needed if line not in actual]
    if missing:
        raise ValueError("Required config missing: " + ", ".join(missing))

if __name__ == "__main__":
    try:
        check(sys.argv[1], sys.argv[2])
    except (ValueError, IndexError) as exc:
        sys.exit(f"Config verification failed: {exc}")
    print("Config verification OK")
