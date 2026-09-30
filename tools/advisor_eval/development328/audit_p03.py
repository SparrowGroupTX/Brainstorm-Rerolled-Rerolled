"""Read-only audit of one already-spent public comparison; no policy runs."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
folder=ROOT/'tools/advisor_eval/runs/loss328_validation_20260915/P03'
def read(name):return json.loads((folder/name).read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
s=read('snapshot.json');before=read('baseline_result.json')['full_result'];after=read('candidate_result.json')['full_result']
assert before['action']=={'area':'jokers','followup':{'area':'shop_jokers','index':1,'kind':'buy'},'index':1,'kind':'sell'}
assert after['action']=={'kind':'leave_shop'}
assert s['jokers'][0]['key']=='j_perkeo' and s['shop_jokers'][0]['key']=='j_blueprint'
assert s['dollars']==3 and s['jokers'][0]['sell_cost']==10 and s['shop_jokers'][0]['cost']==10
assert [c['key'] for c in s['consumeables']]==['c_mercury','c_mercury']
value={'kind':'spent_public_pair_audit','job':'P03','sequence':3829,
 'evidence':{name:sha(folder/name) for name in ('registration.json','spent.json','record.json','snapshot.json','baseline_result.json','candidate_result.json','baseline_summary.json','candidate_summary.json')},
 'baseline':{'action':before['action'],'calls':before['evaluations'],'cash_after_purchase':3},
 'candidate':{'action':after['action'],'calls':after['evaluations'],'cash_retained':3},
 'observed_change':'Retains Perkeo and both ordinary/Negative Mercury rather than selling Perkeo to fund Blueprint.',
 'input_unchanged':all(read(role+'_summary.json')['input_unchanged'] for role in ('baseline','candidate')),
 'no_cap_fallback':not any(read(role+'_result.json')['full_result']['shop_diagnostics']['truncated'] for role in ('baseline','candidate')),
 'limits':['Single dependent public state, not a source continuation or terminal rescue.',
 'Snapshot shop_forecast is absent and remains absent.',
 'Both roles report next-blind readiness unsupported because random scoring is unresolved.',
 'Existing copy_source metadata declines exact copy normalization for these cards; the retained-value heuristic is not an exact future copy or win receipt.',
 'Baseline advice reports paired scoring improvement but does not retain the selected replacement scoring evidence object.'],
 'qualification':False,'terminal_result':None,'executed_new_policy_or_source':False}
output=Path(__file__).with_name('P03_PUBLIC_AUDIT.json')
with output.open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2);stream.write('\n')
print(json.dumps({'output':str(output),'sha256':sha(output),'baseline_calls':before['evaluations'],'candidate_calls':after['evaluations']}))
