"""Freeze a detached manufactured component receipt only; no evaluation."""
from pathlib import Path
import hashlib
import json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
assert sha(HERE/'baseline.lua')==sha(ROOT/'Brainstorm/Advisor/concealed_belief.lua')
value={'schema':1,'kind':'detached_nine_card_concealed_admission','status':'ready_for_root_review',
  'production_source_modified':False,'production_tests_modified':False,'source_baseline_version':'2.130.0-alpha',
  'files':{p.name:sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.name!='manifest.json'},
  'scoring_dependencies':{name:sha(ROOT/'Brainstorm/Advisor'/name) for name in ['scoring.lua','snapshot.lua','draws.lua','sampled_outcomes.lua','decision.lua']},
  'validation':{'new_fixture_checks':7584,'new_fixture_passes':1,'new_fixture_wall_seconds':0.4413214,
    'existing_immediate_checks':292,'existing_continuation_checks':602,'existing_fixture_passes':2,'existing_group_wall_seconds':0.3808803,
    'exit_codes':[0,0],'failed_tests':0,'immediate_candidates':381,'immediate_worlds':16,'immediate_actual_score_calls':6096,
    'complete_future_total_score_calls':6224,'aggregate_score_cap':8000,'future_candidate_cap':8,
    'over_budget_32_world_score_calls':0,'input_unchanged':True,'latent_assignment_invariant':True},
  'captured_policy_decisions':0,'original_source_executions':0,'complete_attempts':0,'search_jobs':0,'new_experiment_jobs':0,
  'limits':'Manufactured and existing fixture evidence only. Exact C02 state not evaluated; no rescued attempt, terminal win or win-rate claim. Root owns integration/full regression/installation.'}
with (HERE/'manifest.json').open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2);stream.write('\n')
print(json.dumps({'manifest_sha256':sha(HERE/'manifest.json'),'candidate_sha256':sha(HERE/'concealed_belief.lua'),'patch_sha256':sha(HERE/'concealed_belief.patch')}))
