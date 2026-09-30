"""Verify unchanged runtime/tests and preserved diagnosis inputs without running policy."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];EVAL=HERE.parent
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((EVAL/'SESSION_RESET_414.json').read_text())
frozen=json.loads((EVAL/'runs/repair414_installed/record.json').read_text())
assert policy_hashes(ROOT)==policy_hashes(Path(base['installed']).parent)==base['policy_files']
assert all(sha(ROOT/p)==v for p,v in frozen['test_files'].items())
nav=json.loads((HERE/'navigation_preservation.json').read_text())
for rel,v in nav.items():
    backup=ROOT/v['backup'];assert sha(backup)==v['before_sha256']
    assert sha(ROOT/rel)==v['after_sha256'] and (ROOT/rel).read_bytes().endswith(backup.read_bytes())
captures=[]
for p in sorted((HERE/'captures').iterdir()):
    m=json.loads((p/'manifest.json').read_text());s=json.loads((p/'summary.json').read_text())
    assert not any(e['classification']=='verification_failure' for e in s['errors'])
    assert all(sha(p/'logs'/v['name'])==v['sha256'] and v['source_prefix_still_matched'] for v in m['segments'])
    assert sha(p/'events.sqlite3')==s['database_sha256']
    captures.append({'capture':p.name,'events':s['events'],'errors':s['errors'],'outcomes':s['outcomes']})
artifacts={p.relative_to(ROOT).as_posix():sha(p) for p in HERE.iterdir() if p.is_file() and p.name!='VERIFICATION.json'}
result={'verified_utc':datetime.now(timezone.utc).isoformat(),'runtime_revision':414,
    'runtime_digest':base['policy_digest'],'runtime_dependencies_unchanged':len(base['policy_files']),
    'frozen_tests_unchanged':len(frozen['test_files']),'navigation_originals_preserved':len(nav),
    'captures':captures,'artifact_hashes':artifacts,'new_runtime_tests_run':False,
    'reason':'Diagnosis and documentation only; exact414 runtime/tests unchanged.',
    'policy_or_scorer_replay':False,'game_control':False,'save_or_profile_access':False}
with (HERE/'VERIFICATION.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2);f.write('\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('captures','artifact_hashes')}))
