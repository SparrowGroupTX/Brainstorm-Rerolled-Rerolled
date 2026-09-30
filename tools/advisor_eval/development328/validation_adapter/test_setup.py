"""Pure JSON/guard/AST fixtures; never imports engine_probe or initializes source."""
from pathlib import Path
from unittest import mock
import ast
import copy
import hashlib
import importlib.util
import json
import tempfile
import unittest
import sys

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import normal_recipe
import run_attempt
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
class Setup(unittest.TestCase):
    def test_three_disclosed_openings(self):
        for seed in run_attempt.SEEDS:
            folder=HERE/'recipes'/seed
            r=normal_recipe.load(folder/'normal_opening_recipe.json',seed,'b_red',8)
            self.assertFalse(r['native_search_executed_by_adapter']);self.assertFalse(r['native_search_receipt_available'])
            self.assertEqual(r['spec']['expected_opening_jokers'],['j_yorick','j_perkeo'])
            self.assertNotIn('native_api_version',r['spec']['filter_info'])
            self.assertEqual(len(r['spec']['filter_info']['normal_opening']['targets']),4)
    def test_public_binding_is_strict(self):
        seed=run_attempt.SEEDS[0];folder=HERE/'recipes'/seed;r=json.loads((folder/'normal_opening_recipe.json').read_text())
        for field,value in [('native_search_receipt_available',True),('future_acquisition_verified',True),('unseen_holdout',True),('seed','OTHER')]:
            bad=copy.deepcopy(r);bad[field]=value
            with self.assertRaises(ValueError):normal_recipe.validate(bad,seed,'b_red',8)
        bad=copy.deepcopy(r);bad['filter_info']['native_api_version']=9
        with self.assertRaises(ValueError):normal_recipe.validate(bad,seed,'b_red',8)
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp);(p/'normal_opening_recipe.json').write_text(json.dumps(r));(p/'opening_public_observation.json').write_text('{}')
            with self.assertRaises(ValueError):normal_recipe.load(p/'normal_opening_recipe.json',seed,'b_red',8)
    def test_arguments_are_fresh_no_search(self):
        seed=run_attempt.SEEDS[1]
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)
            for name in ('normal_opening_recipe.json','normal_seed_selection.json','opening_public_observation.json'):
                (p/name).write_bytes((HERE/'recipes'/seed/name).read_bytes())
            (p/'registration.json').write_text(json.dumps({'metadata':{'seed':seed,'source_install':'synthetic'}}))
            args=run_attempt.arguments(p)
            for value in ['--opening-targets','--replay-trace','--override','--test-scenario','--stop-after-step']:
                self.assertNotIn(value,args)
            self.assertIn('--episode',args);self.assertIn(run_attempt.GOLD_MODE,args)
    def test_python_and_lua_boundary_order(self):
        for path in HERE.glob('*.py'):ast.parse(path.read_text(),filename=path.name)
        text=(HERE/'engine_run.lua').read_text();start=text.index('for step=1,500 do')
        self.assertLess(text.index('information_scope.check(s)',start),text.index('decision.run(s,modules)',start))
        self.assertIn("outcome='unsupported'",text[start:]);self.assertIn('max_checkpoint_reloads=0',text)
        self.assertNotIn('engine_probe',sys.modules)
    def test_registration_one_use_and_exact_binding(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'C01';p.mkdir();source=Path(temp)/'inert_source';source.mkdir()
            for name in ['Balatro.exe','lua51.dll']:(source/name).write_bytes(b'manufactured inert bytes; never loaded')
            policy=p/'policy/Brainstorm/Advisor';policy.mkdir(parents=True);(policy/'dummy.lua').write_text('return {}')
            policy_files={'Brainstorm/Advisor/dummy.lua':sha(policy/'dummy.lua')};policy_digest=run_attempt.digest(policy_files)
            authority={'kind':'fresh_loss_validation_authority','limits':{'complete_attempt_jobs':6,'seconds_per_complete_attempt':180,'total_worker_seconds':1260,'search_jobs':0}}
            (p/'authority.json').write_text(json.dumps(authority))
            for name in run_attempt.ADAPTER_FILES:(p/name).write_bytes((HERE/name).read_bytes())
            for name in ('normal_opening_recipe.json','normal_seed_selection.json','opening_public_observation.json'):
                (p/name).write_bytes((HERE/'recipes'/run_attempt.SEEDS[0]/name).read_bytes())
            (p/'installed_policy_record.json').write_text(json.dumps({'version':'synthetic','policy':{'policy_files':policy_files,'policy_digest':policy_digest}}))
            (p/'installed_graph_check.json').write_text(json.dumps({'passed':True,'policy_digest':policy_digest,'source_initializations':0,'policy_decisions':0}))
            files={f.relative_to(p).as_posix():sha(f) for f in p.rglob('*') if f.is_file()}
            m={'seed':run_attempt.SEEDS[0],'deck':'b_red','stake':8,'maximum_actions':500,'outer_seconds':180,'profile':'all_unlocked_discovered_v1',
               'gold_objective_context':run_attempt.GOLD_MODE,'retry_context':'disabled_clean','information_scope':run_attempt.SCOPE_MODE,
               'qualification':False,'native_search_in_attempt':False,'save_access':False,'player_profile_access':False,
               'policy_digest':policy_digest,'installed_version':'synthetic','source_install':str(source)}
            r={'job':'C01','authority_sha256':sha(p/'authority.json'),'timeout_seconds':180,'metadata':m,'files':files,
               'external_files':{str(f):sha(f) for f in [source/'Balatro.exe',source/'lua51.dll',Path(sys.executable).resolve()]}}
            def put(value):
                (p/'registration.json').write_text(json.dumps(value));(p/'spent.json').write_text(json.dumps({'job':'C01','one_use':True,'registration_sha256':sha(p/'registration.json')}))
            put(r)
            with mock.patch.object(run_attempt,'policy_hashes',return_value=policy_files):
                run_attempt.verify_registration(p)
                for field,value in [('maximum_actions',501),('outer_seconds',181),('profile','player'),('information_scope','ignore'),('seed','OTHER')]:
                    bad=copy.deepcopy(r);bad['metadata'][field]=value;put(bad)
                    with self.assertRaises(ValueError):run_attempt.verify_registration(p)
                put(r);(p/'worker_started.json').write_text('{}')
                with self.assertRaises(ValueError):run_attempt.verify_registration(p)
if __name__=='__main__':unittest.main()
