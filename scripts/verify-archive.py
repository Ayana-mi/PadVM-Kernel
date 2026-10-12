#!/usr/bin/env python3
"""Hash normalized source-tree contents, not unstable gzip/tar metadata."""
import argparse
import hashlib
import posixpath
import sys
import tarfile

def content_fingerprint(fileobj):
    records = []
    names = set()
    with tarfile.open(fileobj=fileobj, mode="r|gz") as source:
        for entry in source:
            path = entry.name
            clean = posixpath.normpath(path)
            if path.startswith("/") or clean in ("", ".", "..") or clean.startswith("../"):
                raise ValueError("Unsafe archive path")
            if clean in names:
                raise ValueError("Duplicate archive entry")
            names.add(clean)
            if entry.isfile():
                content = source.extractfile(entry)
                if content is None:
                    raise ValueError("Unreadable archive entry")
                h = hashlib.sha256()
                for block in iter(lambda: content.read(1024 * 1024), b""):
                    h.update(block)
                info = ("file", entry.mode, entry.size, h.hexdigest())
            elif entry.isdir():
                info = ("dir", entry.mode)
            elif entry.issym():
                info = ("symlink", entry.mode, entry.linkname)
            elif entry.islnk():
                info = ("hardlink", entry.mode, entry.linkname)
            else:
                raise ValueError("Unexpected archive entry type")
            records.append(repr((clean, *info)).encode("utf-8"))
    output = hashlib.sha256()
    for record in sorted(records):
        output.update(len(record).to_bytes(4, "big"))
        output.update(record)
    return output.hexdigest(), len(records)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", help="path to .tar.gz file; '-' reads stdin")
    parser.add_argument("--expected", help="normalized content SHA-256")
    args = parser.parse_args()
    if args.archive == "-":
        fingerprint, count = content_fingerprint(sys.stdin.buffer)
    else:
        with open(args.archive, "rb") as stream:
            fingerprint, count = content_fingerprint(stream)
    if args.expected and fingerprint != args.expected:
        print("Source content fingerprint MISMATCH", file=sys.stderr)
        return 1
    print("content_sha256=" + fingerprint + " entries=" + str(count))
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, EOFError, tarfile.TarError, ValueError) as exc:
        print("Archive verification error: " + str(exc), file=sys.stderr)
        sys.exit(1)
