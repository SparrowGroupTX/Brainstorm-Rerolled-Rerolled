"""Manufactured setup/guard tests only; never imports engine_probe."""
from pathlib import Path
import ast
import hashlib
import importlib.util
import json
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
def load(name):
    spec=importlib.util.spec_from_file_location('c08_test_'+name,HERE/(name+'.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
class Setup(unittest.TestCase):
    def test_exact_s05_recipe_and_later_or_targets(self):
        r=load('normal_recipe').load(HERE/'normal_opening_recipe.json','S7PXV521','b_red',8)
        self.assertEqual(r['spec']['filter_info']['native_api_version'],9)
        self.assertEqual(r['spec']['conditional_later_requirements'],[
          {'any_of':['j_brainstorm','j_blueprint'],'by_ante':5},{'key':'j_burnt','by_ante':5}])
        self.assertIsNone(r['spec']['filter_info']['collection_search']['observed_copy_key'])
        self.assertFalse(r['native_search_executed_by_adapter'])
        prior=json.loads((BASE/'C05/registration.json').read_text())
        for name in ('normal_opening_recipe.json','normal_seed_selection.json'):
            self.assertEqual(sha(HERE/name),prior['files'][name])
    def test_worker_explicit_fresh_context(self):
        argv=load('run_attempt8').arguments(HERE)
        self.assertEqual(argv[argv.index('--seed')+1],'S7PXV521')
        self.assertEqual(argv[argv.index('--gold-objective')+1],'synthetic_fresh_all_missing_v1')
        self.assertIn('--episode',argv)
        for token in ('--test-scenario','--replay-trace','--override','--opening-only-actions','--stop-on-opening-complete'):
            self.assertNotIn(token,argv)
    def test_original_adapters_all_unchanged(self):
        rows=json.loads((HERE/'preparation_origins.json').read_text())
        self.assertEqual(len(rows),18)
        for row in rows:
            self.assertFalse(row['changed']);self.assertEqual(sha(HERE/row['file']),row['prepared_sha256'])
            self.assertEqual(row['prepared_sha256'],row['source_sha256'])
            self.assertEqual(sha(BASE/row['source']),row['source_sha256'])
    def test_graph_reuse_binds_identical_adapter_bytes(self):
        graph=json.loads((BASE/'C07/installed_graph_check.json').read_text())
        self.assertEqual(graph['policy_digest'],load('run_attempt8').POLICY)
        self.assertEqual(len(graph['graph']['modules']),49)
        self.assertEqual(len(graph['graph']['connections']),40)
        for name,value in graph['adapter_files'].items():self.assertEqual(sha(HERE/name),value)
        self.assertEqual(sha(BASE/'C07/inert_graph_raw.json'),graph['raw_report_sha256'])
    def test_worker_requires_original_one_use_and_exact_policy(self):
        worker=load('run_attempt8')
        with tempfile.TemporaryDirectory() as temporary:
            p=Path(temporary)/'C08';p.mkdir()
            installed={'version':'2.120.0-alpha','policy':{'policy_digest':worker.POLICY}}
            (p/'installed_policy_record.json').write_text(json.dumps(installed))
            good={'job':'C08','timeout_seconds':180,'metadata':{'maximum_actions':500,'checkpoint':320,
              'seed':'S7PXV521','policy_digest':worker.POLICY,'installed_version':'2.120.0-alpha',
              'retry_context':'disabled_clean','gold_objective_context':worker.GOLD_MODE}}
            def put(value):
                (p/'registration.json').write_text(json.dumps(value))
                (p/'spent.json').write_text(json.dumps({'job':'C08','one_use':True,
                  'registration_sha256':sha(p/'registration.json')}))
            put(good);worker.verify_registration(p)
            for key,value in [('maximum_actions',501),('checkpoint',319),('policy_digest','bad'),('seed','M4BVSY11'),
                              ('retry_context','enabled'),('gold_objective_context','off')]:
                bad=json.loads(json.dumps(good));bad['metadata'][key]=value;put(bad)
                with self.assertRaises(ValueError):worker.verify_registration(p)
            for key,value in [('job','C07'),('timeout_seconds',181)]:
                bad=dict(good);bad[key]=value;put(bad)
                with self.assertRaises(ValueError):worker.verify_registration(p)
            put(good);(p/'record.json').write_text('{}')
            with self.assertRaises(ValueError):worker.verify_registration(p)
    def test_recipe_branch_cannot_be_relabeled_observed(self):
        r=json.loads((HERE/'normal_opening_recipe.json').read_text())
        r['filter_info']['collection_search']['observed_copy_key']='j_blueprint'
        with self.assertRaises(ValueError):load('normal_recipe').validate(r,'S7PXV521','b_red',8)
    def test_registration_readonly_plan_never_calls_cycle_run(self):
        s=(HERE/'register.py').read_text();ast.parse(s)
        self.assertNotIn('cycle.run(',s)
        self.assertIn("cycle.register('C08'",s)
        self.assertIn("assert (BASE/'C07/record.json').exists()",s)
        self.assertIn("expected_policy_digest==POLICY",s)
        self.assertIn("product_execution_ui_bypassed",s)
    def test_python_syntax_and_original_action_cap(self):
        for path in HERE.glob('*.py'):ast.parse(path.read_text(),filename=path.name)
        text=(HERE/'engine_run.lua').read_text()
        self.assertIn('for step=1,500 do',text);self.assertIn('max_checkpoint_reloads=0',text)
if __name__=='__main__':unittest.main()
