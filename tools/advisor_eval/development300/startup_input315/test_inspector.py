"""Pure synthetic archive/lexer tests; no original source/archive access."""
from pathlib import Path
import json,tempfile,unittest,zipfile
from inspect_source import inspect,METHODS
HERE=Path(__file__).resolve().parent
DECL={
 'main.lua':['function love.mousepressed(x,y) local s="end" end',
   'function love.mousereleased(x,y) -- function ignored\n end',
   'function love.mousemoved(x,y) if x then x=2 end end',
   'function love.keypressed(k) for i=1,2 do repeat i=i+1 until i>3 end end'],
 'engine/controller.lua':['function Controller:'+name+'(x) return x end'for name in
   ['queue_L_cursor_press','queue_R_cursor_press','L_cursor_press','button_press_update','update','key_press_update']],
 'game.lua':['function Game:save_settings() local x=[=[function end]=] end'],
 'engine/ui.lua':['function UIElement:click() return true end']}
def fixture(path,source):
    with zipfile.ZipFile(path,'w')as z:
        for name,lines in source.items():z.writestr(name,'\n'.join(lines))
class Inspector(unittest.TestCase):
    def test_twelve_complete_methods_only_synthetic(self):
        with tempfile.TemporaryDirectory(prefix='M23-input-synthetic-')as temp:
            t=Path(temp);fixture(t/'fake.zip',DECL);result=inspect(t/'fake.zip',t/'out')
            self.assertEqual(result['complete_methods'],12);self.assertEqual(result['status'],'complete')
            self.assertEqual(len(list((t/'out').glob('*.lua'))),12)
            self.assertLess(sum(p.stat().st_size for p in (t/'out').iterdir()),50000)
    def test_missing_is_explicit(self):
        with tempfile.TemporaryDirectory(prefix='M23-input-missing-')as temp:
            t=Path(temp);source=dict(DECL);source.pop('engine/ui.lua');fixture(t/'fake.zip',source)
            result=inspect(t/'fake.zip',t/'out')
            self.assertEqual(result['members']['engine/ui.lua']['status'],'missing')
            self.assertEqual(result['complete_methods'],11);self.assertEqual(result['status'],'incomplete_explicit')
    def test_bounded_truncation_never_complete(self):
        with tempfile.TemporaryDirectory(prefix='M23-input-bound-')as temp:
            t=Path(temp);source=dict(DECL);source['main.lua']=list(DECL['main.lua'])
            source['main.lua'][0]='function love.mousepressed(x,y)\n'+('--'+('A'*98)+'\n')*550+'end'
            fixture(t/'fake.zip',source);result=inspect(t/'fake.zip',t/'out')
            self.assertLessEqual(result['output_bytes'],40000)
            self.assertTrue(result['methods'][0]['truncated']);self.assertFalse(result['methods'][0]['complete_method'])
            self.assertLess(sum(p.stat().st_size for p in (t/'out').iterdir()),50000)
if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(Inspector)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():raise SystemExit(1)
    with(HERE/'synthetic_fixture_report.json').open('x',encoding='utf-8')as out:
        json.dump(dict(schema=1,tests=result.testsRun,passed=True,source_archive_read=False,
          source_or_policy_execution=False,synthetic_zip_only=True),out,indent=2);out.write('\n')
