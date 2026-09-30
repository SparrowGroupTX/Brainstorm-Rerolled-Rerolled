"""Final-bound read-only independent review; no source or policy execution."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json

ROOT=Path(__file__).resolve().parents[4]
HERE=ROOT/'tools/advisor_eval/development300/complete_attempt7'
RUNS=ROOT/'tools/advisor_eval/runs'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf8'))
expected='e1d66be72a88ccf553811cb7cdb6358fb265ce9ac7e7bd85eaca7e70023b1966'
final=RUNS/'pack320_final/final_verification.json'
graph=HERE/'final320_graph.json'
assert sha(final)=='36492dcf2181ac55de9fc6f1c815764fef104cf6f40d870ab013cd35d4c657c3'
assert sha(graph)=='986ea16d7fa361b90567b8101d557bffea68aaf01b296de8338fedf6c20954cd'
manifest=HERE/'preparation_manifest.json'
assert sha(manifest)=='da55b9f8e11b0bf1b269cf397c15125bc61f0369af7ab68f81e9fadf1a7f7199'
for name,value in read(manifest)['prepared_files'].items(): assert sha(HERE/name)==value
policy=read(RUNS/'pack320_installed/record.json')['policy'];files=policy['policy_files']
assert hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest()==expected==policy['policy_digest']
for name,value in files.items(): assert sha(RUNS/'pack320_installed/policy'/name)==value,name
g=read(graph);f=read(final);validation=read(RUNS/'pack320_installed_validation/report.json')
assert g['policy_digest']==f['policy_digest']==validation['policy_digest']==expected
assert g['policy_files']==files and f['version']=='2.120.0-alpha'
assert f['installed_matches'] and f['native_unchanged'] and not f['config_restored_or_modified_by_finalizer']
assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
assert f['installed_report']==sha(RUNS/'pack320_installed_validation/report.json')
assert g['graph']['checks']==2498 and len(g['graph']['modules'])==49 and len(g['graph']['connections'])==40
assert g['source_initializations']==g['policy_decisions']==0
assert g['graph']['gold_objective_enabled'] and not g['graph']['retry_enabled']
for name,value in g['adapter_files'].items(): assert sha(HERE/name)==value
raw=Path(g['scratch'])/'raw.json';std=Path(g['scratch'])/'stdout.log'
assert sha(raw)==g['raw_report_sha256'] and sha(std)==g['stdout_sha256']
for name,value in read(HERE/'required_features.json')['files'].items(): assert files[name]==value
base=RUNS/'gold299_20260914'
assert not (base/'C07').exists() and not (base/'C07_reservation.json').exists()
receipt={'schema':1,'reviewer':'gold_search300','timestamp_utc':datetime.now(timezone.utc).isoformat(),
  'disposition':'accepted_for_root_prospective_C07_registration; no blocking findings',
  'preparation_review_sha256':sha(Path(__file__).with_name('c07_preparation_review.json')),
  'preparation_manifest_sha256':sha(manifest),'policy_digest':expected,
  'installed_policy_record_sha256':sha(RUNS/'pack320_installed/record.json'),
  'installed_final_verification_sha256':sha(final),'installed_graph_sha256':sha(graph),
  'rehashed_policy_files':len(files),'planned_frozen_files':138,
  'exact_feature_count':len(read(HERE/'required_features.json')['files']),
  'graph':{'inert_checks':2498,'distinct_modules':49,'actual_edges':40},
  'describe_readonly_exit_code':0,'worker_calls':0,'registration_calls':0,'reservation_calls':0,
  'source_executions':0,'native_searches':0,'policy_decisions':0,
  'job_absent_at_review':True,'job':'C07','maximum_actions':500,'outer_seconds':180,
  'scope':'Unchanged S04 M4BVSY11 RedGold, naturallyfresh synthetic150missing/retryoff, selected dependent development.',
  'limitations':['Not unseen or representative and cannot isolate one policy intervention.',
    'No startup UI, cashout, logging, checkpoint, autorun or8x/16x timing qualification.',
    'Root registration must still recheck source/runtime hashes and original one-use/deadline authority.',
    'No run or outcome has occurred under this review.']}
out=Path(__file__).with_suffix('.json')
with out.open('x',encoding='utf8') as stream: json.dump(receipt,stream,indent=2)
print(json.dumps({'review_sha256':sha(out),'policy_files':len(files),'accepted':True}))
