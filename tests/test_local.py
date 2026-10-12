import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class StagedBuildTests(unittest.TestCase):
    def test_source_revisions_fixed(self):
        lock=json.loads((ROOT/'sources.lock.json').read_text())
        self.assertEqual(lock['kernel']['commit'],'c90a943feed12176302cd479087bf7aa955486e4')
        self.assertEqual(lock['bakasu']['commit'],'f6cb7e70c10ebde149f3121ae68b945514fd0801')
        self.assertEqual(lock['kabi_patch_origin']['commit'],'b48a01de6b7d5f346f7c5028ac7959ddb3561237')
        pinned_content = {
            'kernel': '4924d3639c1ec794f985109ad0f30b3e71757d0066093fff33394351ef3dd489',
            'clang': 'd5fbf3fdef3f0bb7f250af4abecdf2db09f4b6f9e06300a30428a10bcf84a9ef',
            'build_tools': 'b374894ab59bff74c5065e280e68d1a9b3c60b6bc02513a2fc2b7a97fe7d3d6d',
        }
        for name, expected in pinned_content.items():
            self.assertEqual(lock[name]['content_sha256'], expected)
        for kind in ('kernel','clang','build_tools'):
            self.assertEqual(len(lock[kind]['content_sha256']),64)
            self.assertEqual(len(lock[kind]['archive_sha256_reference']),64)
            self.assertIn(lock[kind]['commit'],lock[kind]['url'])
    def test_config_negative_and_positive(self):
        required=ROOT/'configs/required.config'
        with tempfile.TemporaryDirectory() as tmp:
            config=pathlib.Path(tmp)/'.config'
            config.write_text(required.read_text())
            good=subprocess.run(['python3',str(ROOT/'scripts/verify-config.py'),str(config),str(required)])
            self.assertEqual(good.returncode,0)
            config.write_text('CONFIG_KSU=y\n')
            bad=subprocess.run(['python3',str(ROOT/'scripts/verify-config.py'),str(config),str(required)],capture_output=True)
            self.assertNotEqual(bad.returncode,0)
    def test_official_vendor_tree_is_pinned_and_integrated(self):
        lock=json.loads((ROOT/'sources.lock.json').read_text())
        self.assertEqual(
            lock['vendor_reference']['commit'],
            '76792af3e1fefabd34be6dd684bfc9facc4d5b17'
        )
        script=(ROOT/'scripts/build.sh').read_text()
        for requirement in (
            'sparse-checkout set',
            'vendor/oplus/kernel/oplus_performance/oplus_resctrl',
            'vendor/oplus/kernel/storage',
            'vendor/oplus/kernel/cpu',
            'vendor_reference.commit',
            'vendor/oplus/kernel/synchronize',
            'vendor/oplus/kernel/mm/mm_osvelte',
            'verify-vendor-links.py',
        ):
            self.assertIn(requirement,script)
        self.assertNotIn('git pull', script)
        self.assertNotIn('curl | bash', script)

    def test_config_artifact_included(self):
        workflow=(ROOT/'.github/workflows/build.yml').read_text()
        self.assertIn('include-hidden-files: true',workflow)

    def test_no_unpinned_remote_execution(self):
        script=(ROOT/'scripts/build.sh').read_text()
        self.assertNotIn('curl | bash',script)
        self.assertNotIn('git pull',script)
        self.assertNotIn('/mnt/',script)
        self.assertNotIn('adb ',script)
    def test_public_files_do_not_contain_private_data(self):
        for p in ROOT.rglob('*'):
            if p.is_file() and '.git' not in p.parts and '__pycache__' not in p.parts and p != pathlib.Path(__file__):
                self.assertNotIn(p.name,{'boot_b.img','init_boot_b.img','running.config','kernel.btf','hosts.yml'})
                text=p.read_text(errors='replace')
                for unsafe in ('192'+'.168.','/mnt'+'/workstation','/mnt'+'/projects/','GH_TOKEN=','GITHUB_TOKEN='):
                    self.assertNotIn(unsafe,text,p.as_posix())

if __name__=='__main__':
    unittest.main()
