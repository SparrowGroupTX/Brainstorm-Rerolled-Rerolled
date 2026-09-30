from pathlib import Path
import json,hashlib
p=Path(__file__).resolve().parents[3]/'tools/advisor_eval/runs/loss328_validation_20260915/P04'
def read(name):return json.loads((p/name).read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
b=read('baseline_result.json')['full_result'];c=read('candidate_result.json')['full_result']
assert b['action']==c['action'] and b['evaluations']==c['evaluations']==40320
assert 'scoring_evidence' not in b['strategy'];e=c['strategy']['scoring_evidence']
assert e['samples']==4 and e['complete_finishing'] and not e['uncertain']
assert e['common_worlds']['world_ids']==[1,2,3,4]
out={'job':'P04','kind':'evidence_transport_public_audit','baseline':'2.129','candidate':'2.130',
 'unchanged_action':c['action'],'unchanged_score_calls':40320,'input_unchanged':all(read(r+'_summary.json')['input_unchanged'] for r in ('baseline','candidate')),
 'actual_upcoming_blind':'Ante5 Small,25000chips; snapshot is the shop after Ante4boss,not after Ante5Small.',
 'before_opening_mean':e['before_mean'],'after_opening_mean':e['after_mean'],'paired_worlds':e['samples'],
 'before_target':e['before_target'],'after_target':e['after_target'],
 'finishing':{},'evidence':{n:sha(p/n) for n in ('registration.json','record.json','snapshot.json','baseline_result.json','candidate_result.json')},
 'limits':['New spent follow-up; original P02 still omits these endpoint worlds.',
 'Four selected composition worlds and supported continuation families are not win probabilities or a source continuation.',
 'One common copy-order shortlist is modeled; no omniscient per-world layout.',
 'Future-play action counts include modeled preparation but are not whole-run wall-time measurements.','No terminal rescue demonstrated.'],'qualification':False}
for role in ('before','after'):
 f=e[role+'_finishing'];selected=f['selected'];worlds=selected['worlds']
 assert f['complete'] and f['supported'] and f['known_mechanics']
 assert [w['composition_world_id'] for w in worlds]==[1,2,3,4]
 assert sum(bool(w['clear']) for w in worlds)==selected['clearing_samples']
 out['finishing'][role]={k:selected.get(k) for k in ('name','clearing_samples','mean_score','mean_action_count','mean_hands_used','mean_discards_used')}
 out['finishing'][role]['worlds']=[{k:w.get(k) for k in ('composition_world_id','clear','score','action_count','hands_used','discards_used','dollars_after')} for w in worlds]
target=p/'audit.json'
with target.open('x',encoding='utf-8') as f:json.dump(out,f,indent=2);f.write('\n')
print(json.dumps({k:out[k] for k in ('job','unchanged_action','unchanged_score_calls','before_opening_mean','after_opening_mean','finishing')}))
