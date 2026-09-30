"""Freeze preparation tooling after recorded pure validation; never bind policy."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (BASE/'C09').exists() and not (BASE/'C09_reservation.json').exists()
assert not (HERE/'installed_binding.json').exists()
tests=(HERE/'setup_tests.log').read_text();syntax=(HERE/'compile_tests.log').read_text()
assert 'Ran 7 tests' in tests and '\nOK\n' in tests
assert 'C09 syntax: 7 Lua chunks compile' in syntax and '1/1 fixtures passed' in syntax
files={p.name:sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.suffix in ('.py','.lua','.json','.md','.log')}
assert 'preparation_manifest.json' not in files
value={'schema':1,'status':'prepared_unregistered_unreserved_unrun_pending_root_final321_binding','job':'C09',
       'checkpoint':321,'version':'2.121.0-alpha','maximum_actions':500,'outer_seconds':180,
       'policy_digest':None,'final_verification_sha256':None,'installed_binding':False,
       'seed':'M4BVSY11','source_search':'S04','source_adapter_recipe_from':'C07',
       'profile':'all_unlocked_discovered_v1','gold_context':'synthetic_fresh_all_missing_v1','retry_context':'disabled_clean','qualification':False,
       'validation':{'passed':True,'python_setup_tests':7,'lua_compile_only_chunks':7,'new_graph_executions':0,'source_initializations':0,'policy_decisions':0},
       'prepared_files':files,'prepared_at_utc':datetime.now(timezone.utc).isoformat(),
       'registration_calls':0,'reservation_calls':0,'worker_calls':0,'source_or_archive_reads':False,'player_file_reads':False}
with (HERE/'preparation_manifest.json').open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
print(json.dumps({'manifest_sha256':sha(HERE/'preparation_manifest.json'),'files':len(files),'bound':False,'registered':False}))
