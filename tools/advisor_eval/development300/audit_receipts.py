"""Record interpretation of existing output; no new evaluations."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
notes={
 'S02':('empty_response_unqualified','No match returned. Requested traversal is not verified completed traversal; invalid versus not-found is unresolved.'),
 'S04':('audited_selected_native_match','Found M4BVSY11 under the literal requested four targets, no perishable targets, maximumCPU. Completed chunk counters are not a contiguous coverage claim. Conditional future offers do not establish purchases or survival.'),
 'M07':('audited_active_native_cancellation','The intentionally nonmatching two-thread search returned cancelled after the explicit cancel request. This qualifies that bounded cancellation mechanism, not whole-product timing or gameplay.'),
}
for name,(status,note) in notes.items():
    folder=BASE/name;target=folder/'audit.json'
    if target.exists():continue
    refs=['registration.json','record.json','trace.log']
    if name=='M07':
        refs.append('validation/cancellation.json');result=read(folder/refs[-1])
        assert result['status']=='passed' and result['native_result']['status']=='cancelled' and not result['worker_still_running']
    elif name=='S04':
        refs.append('result.json');assert read(folder/'result.json')['seed']=='M4BVSY11'
    record=read(folder/'record.json');assert record['frozen_files_unchanged']
    target.write_text(json.dumps({'schema':1,'job':name,'status':status,'interpretation':note,
      'complete_attempts':0,'qualification':False,'player_progress':False,
      'evidence':{p:sha(folder/p) for p in refs}},indent=2)+'\n')
    print(target)
