"""Pure setup/guard tests. No source, worker, graph or policy execution."""
from pathlib import Path
import ast
import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from types import SimpleNamespace

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))

def module(name):
    spec=importlib.util.spec_from_file_location('c09_setup_'+name,HERE/(name+'.py'))
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

class Setup(unittest.TestCase):
    def test_explicit_fresh_complete_recipe(self):
        argv=module('run_attempt9').arguments(HERE)
        self.assertEqual(argv[argv.index('--seed')+1],'M4BVSY11')
        self.assertEqual(argv[argv.index('--gold-objective')+1],'synthetic_fresh_all_missing_v1')
        self.assertIn('--episode',argv)
        for flag in ('--replay-trace','--test-scenario','--override','--opening-only-actions','--stop-on-opening-complete'):
            self.assertNotIn(flag,argv)
        recipe=module('normal_recipe').load(HERE/'normal_opening_recipe.json','M4BVSY11','b_red',8)
        self.assertFalse(recipe['qualification']);self.assertFalse(recipe['native_search_executed_by_adapter'])

    def test_wrong_seed_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)
            for name in ('normal_opening_recipe.json','normal_seed_selection.json'):
                value=json.loads((HERE/name).read_text());value['seed']='S7PXV521';(p/name).write_text(json.dumps(value))
            with self.assertRaises(ValueError):module('run_attempt9').arguments(p)

    def test_exact_one_use_job_version_policy_and_caps(self):
        worker=module('run_attempt9')
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'C09';p.mkdir()
            policy={'version':'2.121.0-alpha','policy':{'policy_digest':'a'*64}}
            (p/'installed_policy_record.json').write_text(json.dumps(policy))
            good={'job':'C09','timeout_seconds':180,'metadata':{'checkpoint':321,'maximum_actions':500,'seed':'M4BVSY11','policy_digest':'a'*64,'installed_version':'2.121.0-alpha'}}
            def put(value):
                (p/'registration.json').write_text(json.dumps(value))
                (p/'spent.json').write_text(json.dumps({'job':'C09','one_use':True,'registration_sha256':sha(p/'registration.json')}))
            put(good);worker.verify_registration(p)
            for key,value in [('checkpoint',320),('maximum_actions',501),('seed','OTHER'),('policy_digest','b'*64),('installed_version','2.120.0-alpha')]:
                bad=json.loads(json.dumps(good));bad['metadata'][key]=value;put(bad)
                with self.assertRaises(ValueError):worker.verify_registration(p)
            for key,value in [('job','C07'),('timeout_seconds',181)]:
                bad=dict(good);bad[key]=value;put(bad)
                with self.assertRaises(ValueError):worker.verify_registration(p)
            put(good);(p/'record.json').write_text('{}')
            with self.assertRaises(ValueError):worker.verify_registration(p)

    def test_gold_context_remains_explicit_and_fresh(self):
        build=module('gold_objective_spec').build
        self.assertFalse(build(SimpleNamespace())['enabled'])
        args=dict(gold_objective='synthetic_fresh_all_missing_v1',episode=True,deck='b_red',stake=8,unlock_profile='all_unlocked_discovered_v1',normal_filter_recipe='declared',seed_selection_evidence='declared')
        self.assertFalse(build(SimpleNamespace(**args))['actual_player_profile'])
        for key,value in [('stake',7),('unlock_profile','source_defaults_v1'),('test_scenario','terminal_win_final'),('replay_trace','oldtrace')]:
            with self.assertRaises(ValueError):build(SimpleNamespace(**dict(args,**{key:value})))

    def test_selected_audit_pointer_containment_hash_and_binding(self):
        register=module('register')
        with tempfile.TemporaryDirectory() as temp:
            register.BASE=Path(temp);p=register.BASE/'C08';p.mkdir()
            (p/'record.json').write_text(json.dumps({'trace_sha256':'trace'}));(p/'registration.json').write_text('{}')
            value={'audit_issues':[],'record_sha256':sha(p/'record.json'),'registration_sha256':sha(p/'registration.json'),'trace_sha256':'trace','disposition':'loss'}
            (p/'audit_verified.json').write_text(json.dumps(value))
            pointer={'filename':'audit_verified.json','sha256':sha(p/'audit_verified.json')}
            (p/'selected_audit.json').write_text(json.dumps(pointer))
            self.assertEqual(register.selected_audit('C08')[1]['disposition'],'loss')
            for name in ('../audit_verified.json','record.json','C08/audit_verified.json'):
                (p/'selected_audit.json').write_text(json.dumps(dict(pointer,filename=name)))
                with self.assertRaises(AssertionError):register.selected_audit('C08')
            (p/'selected_audit.json').write_text(json.dumps(dict(pointer,sha256='b'*64)))
            with self.assertRaises(AssertionError):register.selected_audit('C08')

    def test_adapter_recipe_and_graph_bytes_unchanged(self):
        rows=json.loads((HERE/'preparation_origins.json').read_text())
        self.assertEqual(len(rows),16)
        for row in rows:self.assertEqual(sha(HERE/row['file']),row['prepared_sha256']);self.assertFalse(row['changed'])
        lua=(HERE/'engine_run.lua').read_text()
        self.assertLess(lua.index("require('probe_policy_wiring').verify"),lua.index('decision.run(s,modules)'))
        self.assertIn('max_checkpoint_reloads=0',lua)
        self.assertNotIn('options={retry=',lua)

    def test_python_parses_and_imports_are_inert(self):
        before=set(sys.modules)
        module('run_attempt9');module('bind_installed');module('register')
        self.assertNotIn('engine_probe',set(sys.modules)-before)
        for path in HERE.glob('*.py'):ast.parse(path.read_text(),filename=path.name)
        self.assertNotIn('cycle.run(', (HERE/'register.py').read_text())

if __name__=='__main__':unittest.main()
