"""Independent read-only C07 package review; no adapter imports or execution."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json

ROOT=Path(__file__).resolve().parents[4]
HERE=ROOT/'tools/advisor_eval/development300/complete_attempt7'
BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf8'))
manifest_path=HERE/'preparation_manifest.json'
expected='da55b9f8e11b0bf1b269cf397c15125bc61f0369af7ab68f81e9fadf1a7f7199'
assert sha(manifest_path)==expected
m=read(manifest_path)
assert m['job']=='C07' and m['maximum_actions']==500 and m['outer_seconds']==180
assert m['required_checkpoint']==320 and m['required_version']=='2.120.0-alpha'
assert m['policy_digest'] is None and m['final_installed_graph'] is None
for name,value in m['prepared_files'].items(): assert sha(HERE/name)==value,name
origins=read(HERE/'preparation_origins.json');prior=read(BASE/'C06/registration.json')
for row in origins:
    assert sha(HERE/row['file'])==row['prepared_sha256']
    assert sha(BASE/row['source'])==row['source_sha256']==prior['files'][row['file']]
assert [row['file'] for row in origins if row['changed']]==['engine_run.lua','policy_wiring.lua']
old=(BASE/'C06/engine_run.lua').read_text();new=(HERE/'engine_run.lua').read_text()
assert old.replace('complete installed315 graph','complete installed current graph').replace('missing required315 policy','missing required current policy')==new
old=(BASE/'C06/policy_wiring.lua').read_text();new=(HERE/'policy_wiring.lua').read_text()
assert old.replace('complete_source_policy_wiring_315_v1','complete_source_policy_wiring_c07_v1')==new
selection=read(HERE/'normal_seed_selection.json');recipe=read(HERE/'normal_opening_recipe.json')
assert recipe['seed']==selection['seed']=='M4BVSY11' and recipe['deck']=='b_red' and recipe['stake']==8
assert recipe['discovery']['job']==selection['source_search_job']=='S04'
assert selection['unseen_holdout'] is False and selection['actual_player_profile'] is False
for name,value in selection['search_evidence'].items(): assert sha(BASE/'S04'/name)==value
authority=read(BASE/'authority.json')
assert authority['per_job_caps']['C07']==180 and authority['old_authorities']=='all_closed_no_carry_forward'
assert not (BASE/'C07').exists() and not (BASE/'C07_reservation.json').exists()
register=(HERE/'register.py').read_text();worker=(HERE/'run_attempt7.py').read_text()
assert "record['version'] == '2.120.0-alpha'" in register and "'checkpoint': 320" in register
assert '--expected-policy-digest' in register and "expected_digest == digest(policy['policy_files'])" in register
assert "'installed_version') != read('installed_policy_record.json')['version']" in worker
assert "get('checkpoint') != 320" in worker and "get('timeout_seconds') != 180" in worker
assert "for step=1,500 do" in (HERE/'engine_run.lua').read_text()
result={'schema':1,'reviewer':'gold_search300','timestamp_utc':datetime.now(timezone.utc).isoformat(),
        'status':'no_preparation_blocker; final320 digest and installed graph remain required',
        'preparation_manifest_sha256':expected,'prepared_files_rehashed':len(m['prepared_files']),
        'origins_rehashed':len(origins),'source_adapter_semantic_changes':False,
        'declared_seed':'M4BVSY11','source_search':'S04','deck':'b_red','stake':8,
        'synthetic_profile':'all_unlocked_discovered_v1','gold_context':'synthetic_fresh_all_missing_v1',
        'fresh_initial_history':'natural_empty_loaded_joker_usage; capture must assert150missing0unknown',
        'retry_context':'disabled_clean','one_use_job':'C07','max_actions':500,'outer_seconds':180,
        'authority_sha256':sha(BASE/'authority.json'),'authority_deadline_utc':authority['expires_at_utc'],
        'job_and_reservation_absent_at_review':True,
        'reviewed_boundaries':['Exact S04 recipe bytes and complete prior source-adapter origins retained.',
           'Original500-action loop, fresh initialization and no replay/override flags.',
           'One-use cycle has atomic spent marker and refuses second launch.',
           'Explicit root final320 digest, installed/final/validation and every policy file required.',
           'Exact feature hashes and full inert initialized module-identity graph required.',
           'Source dispatch intentionally excludes runtime UI/execution/retry/player journal.',
           'No startup, cashout, autorun or8x/16x timing qualification is claimed.'],
        'pending':['Root must supply exact final320 policy digest after final verification.',
                   'Final installed graph receipt must be generated and reviewed before registration.'],
        'source_executions':0,'policy_decisions':0,'native_searches':0,'registration_calls':0}
out=Path(__file__).with_suffix('.json')
with out.open('x',encoding='utf8') as f:json.dump(result,f,indent=2)
print(json.dumps({'review_sha256':sha(out),'prepared_files':len(m['prepared_files']),'origins':len(origins),'final320_bound':False}))
