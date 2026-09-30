"""Audit frozen public records and source hashes; no policy/scorer execution."""
from pathlib import Path
from collections import Counter
import json, hashlib, subprocess
P=Path(__file__).resolve().parent; ROOT=P.parents[3]
def read(n): return json.loads((P/n).read_text())
def save(n,x): (P/n).write_text(json.dumps(x,indent=2)+'\n',encoding='utf-8')
E=[json.loads(x) for x in (P/'capture/events.jsonl').read_text().splitlines()]
A=read('actions.json'); R=read('runs.json'); M=read('capture/manifest.json'); S=read('capture/summary.json')
checks={'contiguous':not M['gaps'],'decode_clean':not M['errors'],'stable_capture':all(x['stable'] for x in M['inputs']),
 'frozen_hashes':all(hashlib.sha256((ROOT/x['frozen']).read_bytes()).hexdigest()==x['sha256'] for x in M['inputs']),
 'ten_starts':len(R)==10,'all_classified':all(x['outcome'] in ('win','loss','unsupported') for x in R),
 'converter_clean':S['converter_error'] is None,'all_callbacks':S['converter']['actions_without_callback']==0,
 'all_accepted_settled':S['converter']['accepted_callbacks_without_settled_observation']==0,
 'teacher_projection':all(x['state']['teacher_profile']=='perkeo_yorick_win_v1' and x['state']['collection_progress_present'] and not x['state']['completionist_goal_present'] for x in E if 'state' in x)}
release=json.loads((ROOT/'tools/advisor_eval/SESSION_RESET_365.json').read_text())['installed']
bad=[]
for name,expected in release['policy']['policy_files'].items():
 for role,f in [('repository',ROOT/name),('installed',Path(release['installed'])/Path(name).relative_to('Brainstorm'))]:
  if not f.exists() or hashlib.sha256(f.read_bytes()).hexdigest()!=expected:bad.append({'role':role,'path':str(f)})
checks['runtime_hashes']=not bad
save('checkpoint.json',{'version':release['version'],'policy_digest':release['policy']['policy_digest'],
 'files_checked':len(release['policy']['policy_files']),'mismatches':bad,'loaded_version':S['versions'],
 'limitation':'Public version stamp is not loaded-byte attestation. Settings files not read.',
 'git_status':subprocess.check_output(['git','status','--short','--branch'],cwd=ROOT,text=True)})
receipts=[{'sequence':x['sequence'],'run_instance':x['run_instance'],'action':x['action'],'receipt':x['advice']['replacement_review']} for x in A if x.get('advice',{}).get('replacement_review')]
save('replacement_receipts.json',receipts)
selected=[x for x in A if x['sequence'] in (6504,12654,12250,12281,6656,6678,6689,6700)]
save('focused_actions.json',selected)
old=json.loads((P.parent/'20260922_ten_start/runs.json').read_text())
shops=[x for r in R for x in r['shop_exits']]
summary={'checks':checks,'outcomes':dict(Counter(x['outcome'] for x in R)),
 'same_seed_order': [x['seed'] for x in R]==[x['seed'] for x in old],
 'receipts':len(receipts),'receipt_reasons':dict(Counter(x['receipt']['reason'] for x in receipts)),
 'shop_exits':len(shops),'shop_exits_with_inventory':sum(bool(x['inventory']) for x in shops),
 'late_shop_exits':sum(x['ante']>=6 for x in shops),'late_multiple_inventory':sum(x['ante']>=6 and sum(x['inventory'].values())>=2 for x in shops),
 'comparison':[{'run':n['run'],'seed':n['seed'],'old_outcome':o['outcome'],'new_outcome':n['outcome'],'old_blind':o['last_blind']['name'],'new_blind':n['last_blind']['name'],'old_ante':o['last_ante'],'new_ante':n['last_ante']} for o,n in zip(old,R)],
 'scope':'User-started completed diagnostic batch. No new experiments, gameplay, replay or policy/scorer calls.'}
save('review_summary.json',summary)
print(json.dumps(summary))
assert all(checks.values()),checks
