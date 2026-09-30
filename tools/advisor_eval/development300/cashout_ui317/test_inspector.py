"""Manufactured ZIP tests only. Never read the original archive or any saves."""
from pathlib import Path
import json
import tempfile
import unittest
import zipfile
from inspect_source import inspect, TOTAL_CAP

HERE = Path(__file__).resolve().parent
DECL = {
    'engine/ui.lua': [
        'function UIBox:init(args) self.config=args.config; local s="end" end',
        'function UIBox:remove() for i=1,2 do if i then i=i+1 end end end',
        'function UIBox:get_UIE_by_ID(id) -- function ignored\n return id end',
        'function UIElement:init() local s=[=[function end]=]; return s end'],
    'functions/button_callbacks.lua': ['G.FUNCS.cash_out = function(e) if e then e=nil end end'],
    'engine/moveable.lua': ['function Moveable:remove() repeat local n=1 until true end'],
}


def fixture(path, source):
    with zipfile.ZipFile(path, 'w') as archive:
        for name, lines in source.items():
            archive.writestr(name, '\n'.join(lines))


class Inspector(unittest.TestCase):
    def test_six_complete_methods(self):
        with tempfile.TemporaryDirectory(prefix='M24-ui-synthetic-') as temp:
            p = Path(temp)
            fixture(p/'fake.zip', DECL)
            result = inspect(p/'fake.zip', p/'out')
            self.assertEqual(result['status'], 'complete')
            self.assertEqual(result['complete_methods'], 6)
            self.assertEqual(len(list((p/'out').glob('*.lua'))), 6)
            self.assertLess(sum(f.stat().st_size for f in (p/'out').iterdir())+1000, TOTAL_CAP)

    def test_missing_member_explicit(self):
        with tempfile.TemporaryDirectory(prefix='M24-ui-missing-') as temp:
            p = Path(temp)
            source = dict(DECL)
            source.pop('engine/moveable.lua')
            fixture(p/'fake.zip', source)
            result = inspect(p/'fake.zip', p/'out')
            self.assertEqual(result['status'], 'incomplete_explicit')
            self.assertEqual(result['complete_methods'], 5)
            self.assertEqual(result['members']['engine/moveable.lua']['status'], 'missing')

    def test_oversize_method_omitted_whole(self):
        with tempfile.TemporaryDirectory(prefix='M24-ui-limit-') as temp:
            p = Path(temp)
            source = dict(DECL)
            source['engine/ui.lua'] = list(DECL['engine/ui.lua'])
            source['engine/ui.lua'][0] = 'function UIBox:init()\n'+('--'+'x'*98+'\n')*550+'end'
            fixture(p/'fake.zip', source)
            result = inspect(p/'fake.zip', p/'out')
            first = result['methods'][0]
            self.assertFalse(first['complete_method'])
            self.assertEqual(first['shown_bytes'], 0)
            self.assertNotIn('excerpt_file', first)
            self.assertEqual(result['status'], 'incomplete_explicit')
            self.assertFalse((p/'out/ui_box_init.lua').exists())
            self.assertLess(sum(f.stat().st_size for f in (p/'out').iterdir())+1000, TOTAL_CAP)

    def test_ambiguous_definition_explicit(self):
        with tempfile.TemporaryDirectory(prefix='M24-ui-ambiguous-') as temp:
            p = Path(temp)
            source = dict(DECL)
            source['engine/moveable.lua'] = DECL['engine/moveable.lua']*2
            fixture(p/'fake.zip', source)
            result = inspect(p/'fake.zip', p/'out')
            self.assertEqual(result['methods'][-1]['status'], 'ambiguous')
            self.assertFalse(result['methods'][-1]['complete_method'])


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Inspector))
    if not result.wasSuccessful():
        raise SystemExit(1)
    with (HERE/'synthetic_fixture_report.json').open('x') as stream:
        json.dump(dict(schema=1, tests=result.testsRun, passed=True, synthetic_zip_only=True,
                       original_archive_read=False, source_or_policy_execution=False,
                       lua_runtime_loaded=False, native_actions=0), stream, indent=2)
        stream.write('\n')
