from pathlib import Path
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/advisor_eval'))
import install_slice as I


class VersionStampTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'version.lua'
        self.fields={
            'Core/Brainstorm.lua':b'Brainstorm.VERSION\t=  "Brainstorm v2.92.0-alpha  "\t',
            'steamodded_compat.lua':b'--- VERSION:  2.92.0-alpha \t',
        }

    def mixed(self,field):
        return b'\xef\xbb\xbf-- \xce\xb1 and opaque \xff\r\n'+field+b'\n-- unrelated 2.92.0-alpha\r-- tail\r\n'

    def test_current_version_preserves_mixed_newlines_without_any_write(self):
        for relative,field in self.fields.items():
            original=self.mixed(field);self.path.write_bytes(original)
            with self.subTest(relative=relative),patch.object(Path,'write_bytes',side_effect=AssertionError('unchanged version was rewritten')):
                self.assertFalse(I.stamp_version(self.path,relative,'2.92.0-alpha'))
            self.assertEqual(self.path.read_bytes(),original)

    def test_replacement_changes_only_version_value_in_both_formats(self):
        for relative,field in self.fields.items():
            original=self.mixed(field);self.path.write_bytes(original)
            expected=self.mixed(field.replace(b'2.92.0-alpha',b'2.93.0-alpha'))
            with self.subTest(relative=relative):
                self.assertTrue(I.stamp_version(self.path,relative,'2.93.0-alpha'))
                self.assertEqual(self.path.read_bytes(),expected)

    def test_missing_or_ambiguous_version_rejects_without_writing(self):
        for relative,field in self.fields.items():
            for contents,message in [(b'-- no version\r\n\n','Missing version'),(field+b'\r\n'+field,'Ambiguous version')]:
                self.path.write_bytes(contents)
                with self.subTest(relative=relative,message=message),patch.object(Path,'write_bytes',side_effect=AssertionError('invalid version was written')):
                    with self.assertRaisesRegex(ValueError,message): I.stamp_version(self.path,relative,'2.93.0-alpha')
                self.assertEqual(self.path.read_bytes(),contents)


class NativeSliceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'repo';self.root.mkdir()
        self.binary=b'test binary bytes; validator does not execute these'
        self.hash=hashlib.sha256(self.binary).hexdigest()
        self.name=f'Immolate-advisor-{self.hash}.dll'
        self.write('Brainstorm/'+self.name,self.binary)
        self.core='Brainstorm.VERSION = "Brainstorm v2.64.0-alpha"\nBrainstorm.NATIVE_FILE = "'+self.name+'"\nlibrary_name = Brainstorm.NATIVE_FILE\n'
        self.write('Brainstorm/Core/Brainstorm.lua',self.core)
        self.write('Immolate/src/feature.cpp','source')
        self.write('Immolate/tests/feature.cpp','test')
        self.write('tools/advisor_eval/runs/build.log','completed bounded build')
        self.write('tools/advisor_eval/runs/test.log','completed bounded test')
        def receipt(log):
            return {'status':'complete','exit_code':0,'command':['bounded-runner','target'],
                'timeout_seconds':60,'elapsed_seconds':1,'log':{'path':log,'sha256':I.sha256(self.root/log)}}
        self.manifest={'schema':1,'kind':'advisor_native_slice','dll':{'path':'Brainstorm/'+self.name,'sha256':self.hash},
            'sources':{'Immolate/src/feature.cpp':I.sha256(self.root/'Immolate/src/feature.cpp')},
            'tests':{'Immolate/tests/feature.cpp':I.sha256(self.root/'Immolate/tests/feature.cpp')},
            'runtime_files':{'Brainstorm/Core/Brainstorm.lua':I.sha256(self.root/'Brainstorm/Core/Brainstorm.lua')},
            'build':receipt('tools/advisor_eval/runs/build.log'),'validation':[receipt('tools/advisor_eval/runs/test.log')]}
        self.path=self.root/'native-evidence.json'
        self.files=['Core/Brainstorm.lua',self.name]

    def write(self,path,data):
        file=self.root/path;file.parent.mkdir(parents=True,exist_ok=True)
        file.write_bytes(data if isinstance(data,bytes) else data.encode())

    def validate(self,manifest=None,files=None):
        self.path.write_text(json.dumps(manifest or self.manifest))
        return I.validate_native_evidence(self.path,files or self.files,self.root)

    def test_exact_artifact_receipts_and_loader_pass_without_execution(self):
        with patch.object(I.subprocess,'run',side_effect=AssertionError('validator executed a process')):
            result=self.validate()
        self.assertEqual(result['native_file'],self.name)
        self.assertEqual(result['manifest_sha256'],I.sha256(self.path))

    def test_changed_binary_source_test_log_or_loader_rejected(self):
        for field in ['Brainstorm/'+self.name,'Immolate/src/feature.cpp','Immolate/tests/feature.cpp',
                      'tools/advisor_eval/runs/test.log','Brainstorm/Core/Brainstorm.lua']:
            with self.subTest(field=field):
                file=self.root/field;old=file.read_bytes();file.write_bytes(old+b'changed')
                with self.assertRaisesRegex(ValueError,'hash mismatch'): self.validate()
                file.write_bytes(old)

    def test_native_name_must_be_full_content_hash_and_requested_exactly(self):
        wrong='Immolate-advisor-'+('1'*64)+'.dll';self.write('Brainstorm/'+wrong,self.binary)
        m=copy.deepcopy(self.manifest);m['dll']['path']='Brainstorm/'+wrong
        with self.assertRaisesRegex(ValueError,'complete DLL SHA256'): self.validate(m,['Core/Brainstorm.lua',wrong])
        with self.assertRaisesRegex(ValueError,'exactly the requested'): self.validate(files=['Core/Brainstorm.lua','Immolate-v2.16.dll'])

    def test_missing_failed_or_censored_receipts_rejected(self):
        for update in [{'status':'timeout'},{'exit_code':1},{'elapsed_seconds':61},{'timeout_seconds':float('inf')},
                       {'command':[]},{'exit_code':False}]:
            m=copy.deepcopy(self.manifest);m['validation'][0].update(update)
            with self.subTest(update=update),self.assertRaises(ValueError): self.validate(m)
        for field in ['sources','tests','runtime_files','validation']:
            m=copy.deepcopy(self.manifest);m[field]={}
            with self.subTest(field=field),self.assertRaises(ValueError): self.validate(m)

    def test_loader_binding_and_companion_hashes_required(self):
        with self.assertRaisesRegex(ValueError,'explicitly tested Core'): self.validate(files=[self.name])
        self.write('Brainstorm/Advisor/new.lua','return {}')
        with self.assertRaisesRegex(ValueError,'companion Lua'): self.validate(files=self.files+['Advisor/new.lua'])
        self.write('Brainstorm/Core/Brainstorm.lua',self.core.replace('library_name = Brainstorm.NATIVE_FILE','library_name = "old.dll"'))
        self.manifest['runtime_files']['Brainstorm/Core/Brainstorm.lua']=I.sha256(self.root/'Brainstorm/Core/Brainstorm.lua')
        with self.assertRaisesRegex(ValueError,'must use'): self.validate()

    def test_path_traversal_arbitrary_dll_and_configuration_rejected(self):
        for path in ['../config.lua','config.lua','CONFIG.lua','C:/outside.lua','/outside.lua','Other.dll','Advisor/../../x.lua']:
            with self.subTest(path=path),self.assertRaises(ValueError): I.requested_files([path])
        self.assertEqual(I.requested_files(['Advisor\\feature.lua']),['Advisor/feature.lua'])
        m=copy.deepcopy(self.manifest);m['sources']={'../outside.cpp':'0'*64}
        with self.assertRaisesRegex(ValueError,'contained'): self.validate(m)

    def test_lua_only_loader_preserves_selected_sidecar_and_legacy(self):
        self.assertEqual(I.loader_name(self.core),self.name)
        self.assertEqual(I.loader_name('library_name = "Immolate-v2.16.dll"'),I.NATIVE_BASE)
        with self.assertRaises(ValueError): I.loader_name(self.core+'Brainstorm.NATIVE_FILE = "Other.dll"')

    def test_native_staging_keeps_old_dll_and_passes_tested_sidecar_to_installer(self):
        mixed_core=self.core.replace('\n','\r\n',1)+'-- LF-only sentinel\n-- CR-only sentinel\r'
        self.write('Brainstorm/Core/Brainstorm.lua',mixed_core)
        self.manifest['runtime_files']['Brainstorm/Core/Brainstorm.lua']=I.sha256(self.root/'Brainstorm/Core/Brainstorm.lua')
        installed=Path(self.temp.name)/'installed';installed.mkdir()
        fixed=['Core/challenge_opening.lua','Core/auxiliary.lua','UI/advisor.lua','UI/challenge_opening.lua','UI/ui.lua','Advisor/one.lua']
        for rel in fixed:
            p=installed/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('return {}')
        (installed/'Core/Brainstorm.lua').write_text('Brainstorm.VERSION = "Brainstorm v2.64.0-alpha"\n')
        (installed/'steamodded_compat.lua').write_text('--- VERSION: 2.64.0-alpha\n')
        (installed/I.NATIVE_BASE).write_bytes(b'old possibly loaded DLL')
        self.write('Brainstorm/steamodded_compat.lua','--- VERSION: 2.64.0-alpha\n')
        self.validate()
        backup=installed/'deployment-backups/new';backup.mkdir(parents=True)
        captured={}
        def deploy(command,**options):
            stage=Path(command[command.index('-Source')+1])
            captured['native']=command[command.index('-NativeFile')+1]
            self.assertEqual((stage/self.name).read_bytes(),self.binary)
            self.assertEqual((stage/I.NATIVE_BASE).read_bytes(),b'old possibly loaded DLL')
            self.assertEqual((stage/'Core/auxiliary.lua').read_text(),'return {}')
            self.assertEqual(I.loader_name((stage/'Core/Brainstorm.lua').read_text()),self.name)
            self.assertIn('2.65.0-alpha',(stage/'Core/Brainstorm.lua').read_text())
            self.assertEqual((stage/'Core/Brainstorm.lua').read_bytes(),mixed_core.replace('v2.64.0-alpha','v2.65.0-alpha').encode())
            return subprocess.CompletedProcess(command,0,json.dumps({'version':'2.65.0-alpha','installedAt':'fixture',
                'backup':str(backup),'configSHA256':'unchanged','activation':'normal restart','files':[]}), '')
        with (patch.object(I,'ROOT',self.root),patch.object(I,'INSTALLED',installed),patch.object(I.subprocess,'run',side_effect=deploy),
            patch.object(sys,'argv',['install_slice.py','--version','2.65.0-alpha','--native-evidence',str(self.path)]+self.files)):
            I.main()
        self.assertEqual(captured['native'],self.name)
        self.assertEqual((installed/I.NATIVE_BASE).read_bytes(),b'old possibly loaded DLL')
        self.assertTrue((backup/'native-evidence.json').is_file())


if __name__=='__main__': unittest.main()
