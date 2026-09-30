import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime, timedelta, timezone

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/advisor_eval'))
import jokerless_push as push
from engine_probe import selection_record,jokerless_recipe_record

class PushAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.authorization=self.root/'authorization.json'
        self.spec={'kind':'new_user_authorized_jokerless_push','retry_evaluation':False,
            'worker_deadline_utc':(datetime.now(timezone.utc)+timedelta(hours=1)).isoformat(),
            'allowances':{'source_adapter_agent':{'complete_attempt_workers':2,'per_attempt_seconds':180,
                'attempt_seconds_total':360,'source_mechanical_workers':3,
                'per_mechanical_seconds':15,'mechanical_seconds_total':45}}}
        self.authorization.write_text(json.dumps(self.spec))
        self.output=self.root/'source_attempts'/'one'
    def tearDown(self): self.temp.cleanup()
    def lease(self,name,timeout=180):
        p=self.root/'source_attempts'/name;p.mkdir(parents=True)
        r={'timeout_seconds':timeout,'seed':name};r['registration_digest']=push.digest(r)
        (p/'registration.json').write_text(json.dumps(r));return p
    def test_initial_admission_is_one_full_fixed_lease(self):
        _,timeout,earlier=push.admission(self.authorization,self.output)
        self.assertEqual(timeout,180);self.assertEqual(earlier,[])
    def test_registered_lease_is_spent_even_without_result(self):
        self.lease('old');_,_,earlier=push.admission(self.authorization,self.output)
        self.assertEqual(len(earlier),1)
        self.lease('second')
        with self.assertRaisesRegex(ValueError,'already registered'):push.admission(self.authorization,self.output)
    def test_changed_existing_timeout_cannot_create_budget(self):
        self.lease('bad',-180)
        with self.assertRaisesRegex(ValueError,'inconsistent'):push.admission(self.authorization,self.output)
    def test_changed_registration_is_preserved_and_blocks_admission(self):
        p=self.lease('old');r=json.loads((p/'registration.json').read_text());r['seed']='changed'
        (p/'registration.json').write_text(json.dumps(r))
        with self.assertRaisesRegex(ValueError,'inconsistent'):push.admission(self.authorization,self.output)
    def test_existing_directory_cannot_be_reused(self):
        self.output.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError,'fresh'):push.admission(self.authorization,self.output)
    def test_deadline_never_extends_to_fit_worker(self):
        self.spec['worker_deadline_utc']=(datetime.now(timezone.utc)+timedelta(seconds=30)).isoformat()
        self.authorization.write_text(json.dumps(self.spec))
        with self.assertRaisesRegex(ValueError,'deadline'):push.admission(self.authorization,self.output)
    def test_output_cannot_escape_authorized_attempts_directory(self):
        with self.assertRaisesRegex(ValueError,'direct child'):
            push.admission(self.authorization,self.root/'elsewhere'/'one')
    def test_retry_ledger_scope_is_not_implicitly_authorized(self):
        self.spec['retry_evaluation']=True;self.authorization.write_text(json.dumps(self.spec))
        with self.assertRaisesRegex(ValueError,'unsupported retry'):push.admission(self.authorization,self.output)
    def test_mechanical_lease_uses_separate_shared_fixed_cap(self):
        self.lease('full')
        folder=self.root/'source_probes';folder.mkdir()
        r={'timeout_seconds':15,'seed':'prior'};r['registration_digest']=push.digest(r)
        old=folder/'old';old.mkdir();(old/'registration.json').write_text(json.dumps(r))
        _,timeout,earlier=push.admission(self.authorization,folder/'new',mechanical=True)
        self.assertEqual(timeout,15);self.assertEqual(len(earlier),1)
        self.assertEqual(len(push.admission(self.authorization,self.output)[2]),1)
    def test_mechanical_leases_cannot_escape_to_attempt_count(self):
        with self.assertRaisesRegex(ValueError,'direct child'):
            push.admission(self.authorization,self.output,mechanical=True)
    def test_selected_seed_evidence_is_explicit_and_bound(self):
        p=self.root/'selected.json'
        spec={'schema':1,'kind':'declared_selected_development_seed','seed':'SEED1234','qualification':False}
        p.write_text(json.dumps(spec));record=selection_record(p,'SEED1234')
        self.assertEqual(record['spec'],spec);self.assertEqual(record['evidence_digest'],push.file_digest(p))
        self.assertFalse(record['selection_executed_by_adapter']);self.assertFalse(record['qualification'])
    def test_selected_seed_cannot_be_reused_for_another_request(self):
        p=self.root/'selected.json';p.write_text(json.dumps({'schema':1,'kind':'declared_selected_development_seed','seed':'ONE','qualification':False}))
        with self.assertRaisesRegex(ValueError,'inconsistent'):selection_record(p,'TWO')
    def test_selected_seed_cannot_claim_qualification(self):
        p=self.root/'selected.json';p.write_text(json.dumps({'schema':1,'kind':'declared_selected_development_seed','seed':'ONE','qualification':True}))
        with self.assertRaisesRegex(ValueError,'qualification'):selection_record(p,'ONE')
    def test_opening_recipe_cannot_change_requested_seed(self):
        p=self.root/'recipe.json';p.write_text(json.dumps({'schema':1,'mode':'jokerless_coupon_blue_v1','qualification':False,'recipe':{'seed':'ONE'}}))
        self.assertEqual(jokerless_recipe_record(p,'ONE')['execution'],'frozen_product_advice_with_public_validation')
        with self.assertRaisesRegex(ValueError,'inconsistent'):jokerless_recipe_record(p,'TWO')
    def test_opening_recipe_cannot_claim_qualification(self):
        p=self.root/'recipe.json';p.write_text(json.dumps({'schema':1,'mode':'jokerless_coupon_blue_v1','qualification':True,'recipe':{'seed':'ONE'}}))
        with self.assertRaisesRegex(ValueError,'qualification'):jokerless_recipe_record(p,'ONE')
    def test_opening_target_binding_preserves_legacy_recipe(self):
        p=self.root/'recipe.json'
        spec={'schema':1,'mode':'jokerless_coupon_blue_v1','qualification':False,'recipe':{'seed':'ONE'}}
        p.write_text(json.dumps(spec));self.assertEqual(jokerless_recipe_record(p,'ONE')['spec'],spec)
        for planet,hand in [('c_mars','Four of a Kind'),('c_jupiter','Flush'),('c_saturn','Straight')]:
            spec['recipe'].update(target_planet=planet,target_hand=hand)
            p.write_text(json.dumps(spec));self.assertEqual(jokerless_recipe_record(p,'ONE')['spec'],spec)
    def test_opening_target_binding_rejects_hidden_or_inconsistent_planets(self):
        p=self.root/'recipe.json'
        for fields in [{'target_planet':'c_mars'}, {'target_hand':'Flush'},
                {'target_planet':'c_mars','target_hand':'Flush'},
                {'target_planet':'c_planet_x','target_hand':'Five of a Kind'}]:
            p.write_text(json.dumps({'schema':1,'mode':'jokerless_coupon_blue_v1','qualification':False,
                'recipe':dict(seed='ONE',**fields)}))
            with self.assertRaisesRegex(ValueError,'binding'):jokerless_recipe_record(p,'ONE')

class DependentComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.prior=self.root/'source_attempts'/'old';self.prior.mkdir(parents=True)
        self.trace=self.prior/'attempt.log';self.trace.write_text('frozen synthetic test trace\n',encoding='utf-8')
        self.evidence=self.root/'repair.json';self.evidence.write_text('{"observed_action_changed":true}',encoding='utf-8')
        self.profile=push.profile_spec('all_unlocked_discovered_v1')
        self.recipe={'recipe_digest':'recipe'}
        self.previous={'registration_digest':'registered','policy_digest':'old-policy','adapter_digest':'adapter',
            'seed':'TO6O4111','challenge':'c_jokerless_1','full_episode_requested':True,
            'profile_spec':self.profile,'retry_context_spec':push.retry_context_spec(),'jokerless_opening':self.recipe,
            'policy_files':{'Brainstorm/Advisor/search.lua':'old','Brainstorm/Core/Brainstorm.lua':'version1'},
            'command':['python','frozen_engine.py','--seed','TO6O4111']}
        self.old={'registration_digest':'registered','provenance_verified':True,'audit_errors':[],
            'outcome':'loss','reason':'game_over','trace_digest':push.file_digest(self.trace),
            'command':self.previous['command'],'exit_code':0,'elapsed_seconds':10,'terminal':{'outcome':'loss'},
            'provenance':{'seed':'TO6O4111'}}
        self.write_records()
        self.product={'policy_files':{**self.previous['policy_files'],'Brainstorm/Advisor/search.lua':'new'},'policy_digest':'new-policy'}
    def tearDown(self):self.temp.cleanup()
    def write_records(self):
        for name in ('record.json','raw_record.json'):(self.prior/name).write_text(json.dumps(self.old),encoding='utf-8')
    def run_comparison(self,product=None,profile=None,recipe=None,seed='TO6O4111',evidence=True):
        with patch.object(push,'verify',return_value=self.previous),patch.object(push,'episode_record',return_value=self.old):
            return push.dependent_comparison(self.prior,product or self.product,seed,profile or self.profile,
                recipe or self.recipe,self.evidence if evidence else None)
    def test_changed_hand_policy_is_explicitly_dependent_and_costs_new_lease(self):
        result=self.run_comparison()
        self.assertEqual(result['changed_hand_modules'],{'Brainstorm/Advisor/search.lua':{'before':'old','after':'new'}})
        self.assertFalse(result['independent_rate_sample']);self.assertFalse(result['qualification'])
        self.assertEqual(result['execution'],'fresh_original_initialization_no_replay_or_restore')
        self.assertIn('new_single_use_180',result['budget'])
    def test_unchanged_hand_policy_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'changed hand-policy'):
            self.run_comparison(product={'policy_files':self.previous['policy_files'],'policy_digest':'old-policy'})
    def test_version_only_changes_cannot_create_a_dependent_request(self):
        files={**self.previous['policy_files'],'Brainstorm/Core/Brainstorm.lua':'version2','Brainstorm/steamodded_compat.lua':'version2'}
        with self.assertRaisesRegex(ValueError,'version, UI or adapter'):
            self.run_comparison(product={'policy_files':files,'policy_digest':'new-version'})
    def test_ui_only_changes_cannot_create_a_dependent_request(self):
        files={**self.previous['policy_files'],'Brainstorm/UI/advisor.lua':'newUI'}
        with self.assertRaisesRegex(ValueError,'changed hand-policy'):
            self.run_comparison(product={'policy_files':files,'policy_digest':'newUI'})
    def test_exact_preblind_runtime_action_module_is_in_scope(self):
        files={**self.previous['policy_files'],'Brainstorm/Advisor/blind_prep.lua':'exact-prep-action'}
        result=self.run_comparison(product={'policy_files':files,'policy_digest':'new-prep'})
        self.assertIn('Brainstorm/Advisor/blind_prep.lua',result['changed_hand_modules'])
    def test_strategy_only_changes_are_still_outside_this_protocol(self):
        files={**self.previous['policy_files'],'Brainstorm/Advisor/strategy.lua':'new-strategy'}
        with self.assertRaisesRegex(ValueError,'changed hand-policy'):
            self.run_comparison(product={'policy_files':files,'policy_digest':'new-strategy'})
    def test_repair_needs_concrete_evidence(self):
        with self.assertRaisesRegex(ValueError,'concrete detached'):self.run_comparison(evidence=False)
    def test_profile_seed_and_recipe_remain_identical(self):
        for kwargs in ({'profile':push.profile_spec('source_defaults_v1')},{'recipe':{'recipe_digest':'changed'}},{'seed':'OTHER'}):
            with self.subTest(kwargs=kwargs),self.assertRaisesRegex(ValueError,'preserve seed'):
                self.run_comparison(**kwargs)
    def test_prior_raw_trace_tampering_is_rejected(self):
        self.trace.write_text('changed trace',encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'unchanged audited prior'):self.run_comparison()
    def test_prior_failed_audit_is_not_admitted(self):
        self.old['provenance_verified']=False;self.write_records()
        with self.assertRaisesRegex(ValueError,'unchanged audited prior'):self.run_comparison()
    def test_prior_win_is_not_an_error_repair_request(self):
        self.old['outcome']='win';self.write_records()
        with self.assertRaisesRegex(ValueError,'unchanged audited prior'):self.run_comparison()
    def test_prior_raw_record_command_tampering_is_rejected(self):
        raw={**self.old,'command':['changed']};(self.prior/'raw_record.json').write_text(json.dumps(raw),encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'unchanged audited prior'):self.run_comparison()

if __name__=='__main__':unittest.main()
