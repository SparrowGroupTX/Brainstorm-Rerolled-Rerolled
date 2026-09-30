"""Record pure C08 preparation provenance; no worker/source/policy execution."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (BASE/'C08').exists() and not (BASE/'C08_reservation.json').exists()
files={p.name:sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.suffix in ('.py','.lua','.json','.md')}
assert 'preparation_manifest.json' not in files
record={'schema':1,'status':'prepared_unregistered_unreserved_unrun_pending_root_review',
 'job':'C08','checkpoint':320,'version':'2.120.0-alpha','maximum_actions':500,'outer_seconds':180,
 'policy_digest':'e1d66be72a88ccf553811cb7cdb6358fb265ce9ac7e7bd85eaca7e70023b1966',
 'final_verification_sha256':'36492dcf2181ac55de9fc6f1c815764fef104cf6f40d870ab013cd35d4c657c3',
 'inherited_final_graph_sha256':'986ea16d7fa361b90567b8101d557bffea68aaf01b296de8338fedf6c20954cd',
 'seed':'S7PXV521','source_search':'S05','source_recipe_from':'C05','source_adapter_from':'C07',
 'profile':'all_unlocked_discovered_v1','gold_context':'synthetic_fresh_all_missing_v1','retry_context':'disabled_clean',
 'qualification':False,'prepared_at_utc':datetime.now(timezone.utc).isoformat(),'prepared_files':files,
 'validation':{'python_setup_tests':8,'lua_compile_only_chunks':7,'passed':True,
   'inherited_graph_checks':2498,'graph_distinct_modules':49,'graph_edges':40,
   'new_graph_or_source_initializations':0,'policy_decisions':0},
 'source_or_archive_reads':False,'native_searches':0,'player_file_reads':False,
 'registration_calls':0,'reservation_calls':0,'worker_calls':0,
 'copy_helper_sha256':sha(HERE.parent/'prepare_complete_attempt8.py')}
out=HERE/'preparation_manifest.json'
with out.open('x',encoding='utf8') as f:json.dump(record,f,indent=2)
print(json.dumps({'manifest_sha256':sha(out),'prepared_files':len(files),'registered':False}))
