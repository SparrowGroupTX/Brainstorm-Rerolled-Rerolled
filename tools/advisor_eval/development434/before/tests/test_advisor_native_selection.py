from pathlib import Path
import hashlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/advisor_eval'))
from opening_support import native_library_path, validate_later_request, validate_later_result, native_search


class NativeSelectionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.product = self.root / 'Brainstorm'
        (self.product / 'Core').mkdir(parents=True)
        self.core = self.product / 'Core/Brainstorm.lua'

    def test_legacy_freeze_remains_on_legacy_binary(self):
        self.core.write_text('Brainstorm.VERSION="Brainstorm v2.64.0-alpha"')
        (self.product / 'Immolate-v2.16.dll').write_bytes(b'old')
        self.assertEqual(native_library_path(self.root).name, 'Immolate-v2.16.dll')

    def test_selected_sidecar_is_content_bound(self):
        data = b'tested sidecar'
        name = 'Immolate-advisor-' + hashlib.sha256(data).hexdigest() + '.dll'
        self.core.write_text('Brainstorm.NATIVE_FILE = "' + name + '"')
        target = self.product / name
        target.write_bytes(data)
        self.assertEqual(native_library_path(self.root), target)
        target.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'content differs'):
            native_library_path(self.root)

    def test_missing_declared_sidecar_never_falls_back(self):
        name = 'Immolate-advisor-' + '0' * 64 + '.dll'
        self.core.write_text('Brainstorm.NATIVE_FILE = "' + name + '"')
        (self.product / 'Immolate-v2.16.dll').write_bytes(b'old')
        with self.assertRaisesRegex(ValueError, 'missing'):
            native_library_path(self.root)

    def test_unsafe_or_ambiguous_declarations_rejected(self):
        for code in ('Brainstorm.NATIVE_FILE = "../outside.dll"',
                     'Brainstorm.NATIVE_FILE = "Immolate.dll"',
                     'Brainstorm.NATIVE_FILE = make_path()',
                     'Brainstorm.NATIVE_FILE = "Immolate-v2.16.dll"\nBrainstorm.NATIVE_FILE = "Immolate-v2.16.dll"'):
            with self.subTest(code=code):
                self.core.write_text(code)
                with self.assertRaises(ValueError):
                    native_library_path(self.root)

    def test_later_inputs_fail_before_dll_access(self):
        good={'target_key':'j_blueprint','deadline':3,'rare_pool_mask':'1'*20}
        self.assertEqual(validate_later_request(good),good)
        for change in ({'target_key':'j_perkeo'},{'deadline':True},{'deadline':9},
                       {'rare_pool_mask':'1'*19},{'rare_pool_mask':'x'*20},{'unexpected':1}):
            with self.subTest(change=change):
                with self.assertRaises(ValueError):
                    native_search(self.root,'SEARCH1','c_city_1','j_perkeo',10,later={**good,**change})

    def test_later_result_never_promotes_conditional_offer(self):
        later={'target_key':'j_blueprint','deadline':3,'rare_pool_mask':'1'*20}
        good={'status':'found','api_version':2,'later_target':'j_blueprint','later_deadline':3,
              'later_pool_mask':'1'*20,'later_source':'shop_initial',
              'later_schedule':'first_charm_then_play_all_fixed_rare_pool',
              'later_offer_status':'conditional','later_retention':'not_verified',
              'later_found_ante':3,'later_shop':1,'later_slot':2,'later_edition':'base','later_eternal':False}
        validate_later_result(good,later)
        for change in ({'later_retention':'verified'},{'later_offer_status':'acquired'},
                       {'later_target':'j_dna'},{'later_pool_mask':'0'*20},
                       {'later_found_ante':4},{'later_found_ante':1,'later_shop':2},
                       {'later_slot':3},{'later_slot':True},{'api_version':True},
                       {'later_edition':None},{'later_edition':'unknown'},{'later_eternal':0}):
            with self.subTest(change=change):
                with self.assertRaises(ValueError): validate_later_result({**good,**change},later)
        miss={k:v for k,v in good.items() if k not in ('later_found_ante','later_shop','later_slot')}
        miss['status']='not_found';validate_later_result(miss,later)
        validate_later_result({'status':'invalid','reason':'unsupported'},later)


if __name__ == '__main__':
    unittest.main()
