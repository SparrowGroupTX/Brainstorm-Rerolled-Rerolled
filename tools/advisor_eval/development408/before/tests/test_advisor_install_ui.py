"""Exercise the real installer on disposable synthetic files, never the game."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

class InstallAuxiliaryUITests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell unavailable')
    def test_new_ui_is_backed_up_copied_and_recorded(self):
        with tempfile.TemporaryDirectory(prefix='advisor-ui-install-fixture-') as temp:
            root=Path(temp);source=root/'source';target=root/'target'
            files={'Core/Brainstorm.lua':'Brainstorm.VERSION = "Brainstorm v2.101.0-alpha"',
              'Advisor/runtime.lua':'return {}','UI/ui.lua':'return {}',
              'UI/collection_run.lua':'return {new_page=true}',
              'Core/auxiliary.lua':'return {guard=true}',
              'steamodded_compat.lua':'return {}','Immolate-v2.16.dll':'synthetic inert bytes'}
            for name,value in files.items():
                p=source/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value)
            (target/'Core').mkdir(parents=True);(target/'UI').mkdir()
            (target/'Core/Brainstorm.lua').write_text('prior core')
            (target/'UI/collection_run.lua').write_text('prior page')
            (target/'config.lua').write_text('current configuration marker')
            (target/'Immolate-v2.16.dll').write_text('synthetic inert bytes')
            result=subprocess.run(['pwsh','-NoProfile','-File',str(ROOT/'tools/install_advisor.ps1'),
              '-Source',str(source),'-Target',str(target)],capture_output=True,text=True,timeout=15,
              creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            self.assertEqual(result.returncode,0,result.stderr)
            manifest=json.loads(result.stdout.lstrip('\ufeff'))
            self.assertEqual((target/'UI/collection_run.lua').read_text(),files['UI/collection_run.lua'])
            self.assertEqual((Path(manifest['backup'])/'UI/collection_run.lua').read_text(),'prior page')
            self.assertEqual((target/'config.lua').read_text(),'current configuration marker')
            self.assertIn('UI\\collection_run.lua',{r['path'] for r in manifest['files']})
            self.assertEqual(len(manifest['files']),len(files))

if __name__=='__main__':unittest.main()
