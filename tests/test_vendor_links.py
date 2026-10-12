import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("vendor_links", ROOT / "scripts/verify-vendor-links.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class VendorLinksTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        work = Path(self.folder.name)
        self.kernel = work / "kernel"
        self.kernel.mkdir()
        expected = {
            "kernel/oplus_cpu": "../../vendor/oplus/kernel/cpu",
            "mm/mm-trace.h": "../../vendor/oplus/kernel/mm/mm_osvelte/mm-trace.h",
            "kernel/locking/locking_main.h": "../../../vendor/oplus/kernel/synchronize/oplus_locking.h",
            "kernel/locking/oplus_locking.c": "../../../vendor/oplus/kernel/synchronize/oplus_locking.c",
            "kernel/locking/sa_common_struct.h": "../../../vendor/oplus/kernel/cpu/sched/sched_assist/sa_common_struct.h",
            "include/soc/oplus/storage": "../../../../vendor/oplus/kernel/storage/include",
            "drivers/soc/oplus/oplus_resctrl": "../../../../vendor/oplus/kernel/oplus_performance/oplus_resctrl",
            "drivers/soc/oplus/storage": "../../../../vendor/oplus/kernel/storage",
        }
        self.assertEqual(set(expected), set(module.EXPECTED_LINKS))
        for name, relative in expected.items():
            link = self.kernel / name
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(relative)
            target = link.resolve()
            if name in ("kernel/oplus_cpu", "include/soc/oplus/storage", "drivers/soc/oplus/oplus_resctrl", "drivers/soc/oplus/storage"):
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("test-only")
    def tearDown(self):
        self.folder.cleanup()
    def test_every_vendor_link_resolves(self):
        self.assertEqual(module.verify(self.kernel), [])
    def test_missing_vendor_file_stops_before_compile(self):
        target = self.kernel / "kernel/locking/locking_main.h"
        target.resolve().unlink()
        errs = module.verify(self.kernel)
        self.assertTrue(any("locking_main.h" in e for e in errs))
    def test_missing_symlink_fails(self):
        (self.kernel / "mm/mm-trace.h").unlink()
        self.assertTrue(any("mm-trace.h" in e for e in module.verify(self.kernel)))

if __name__ == "__main__":
    unittest.main()
