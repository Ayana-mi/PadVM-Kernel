import gzip
import importlib.machinery
import io
from pathlib import Path
import tarfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify-archive.py"
module = importlib.machinery.SourceFileLoader("archive_validation", str(SCRIPT)).load_module()

def sample(data=b"hello", mtime=1, name="source/file.txt"):
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w") as t:
        entry = tarfile.TarInfo(name)
        entry.mode = 0o644
        entry.mtime = mtime
        entry.size = len(data)
        t.addfile(entry, io.BytesIO(data))
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", mtime=mtime) as gz:
        gz.write(raw.getvalue())
    return buf.getvalue()

class ArchiveFingerprintTests(unittest.TestCase):
    def test_tar_and_gzip_timestamp_do_not_change_content(self):
        a = module.content_fingerprint(io.BytesIO(sample(mtime=1)))[0]
        b = module.content_fingerprint(io.BytesIO(sample(mtime=99)))[0]
        self.assertEqual(a, b)

    def test_file_bytes_change_content_fingerprint(self):
        a = module.content_fingerprint(io.BytesIO(sample(data=b"hello")))[0]
        b = module.content_fingerprint(io.BytesIO(sample(data=b"world")))[0]
        self.assertNotEqual(a, b)

    def test_reject_parent_directory(self):
        with self.assertRaises(ValueError):
            module.content_fingerprint(io.BytesIO(sample(name="../private")))

if __name__ == "__main__":
    unittest.main()
