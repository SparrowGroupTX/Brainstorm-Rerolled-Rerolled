"""Manufactured gate discovery, no game/policy execution."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

EVAL=Path(__file__).resolve().parents[1]/'tools/advisor_eval'
sys.path.insert(0,str(EVAL))
try:
    spec=importlib.util.spec_from_file_location('validation_manifest404',EVAL/'validate_checkpoint.py')
    gate=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
finally:
    sys.path.pop(0)

class ManifestTest(unittest.TestCase):
    def test_declared_timing_groups_are_hashed(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'tests').mkdir()
            names=['test_advisor_small.py','test_teacher_decision_timing.py','test_wall_time_decomposition.py','advisor_small.lua']
            for name in names:(root/'tests'/name).write_text('manufactured')
            self.assertEqual(set(gate.test_manifest(root)),{'tests/'+n for n in names})

    def test_new_unclassified_test_requires_explicit_group(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'tests').mkdir()
            (root/'tests/test_unclassified.py').write_text('manufactured')
            with self.assertRaisesRegex(ValueError,'Unclassified'):
                gate.test_manifest(root)

    def test_changed_declared_bytes_change_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'tests').mkdir()
            p=root/'tests/test_teacher_decision_timing.py';p.write_text('first')
            first=gate.test_manifest(root);p.write_text('second')
            self.assertNotEqual(first,gate.test_manifest(root))

if __name__=='__main__':unittest.main()
