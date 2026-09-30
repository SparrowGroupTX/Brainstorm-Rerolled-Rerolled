"""Passive complete-accounting report for the ten registered continuations."""
from pathlib import Path
import json,collections
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
assert read(HERE/'CLOSED.json')['remaining_authority']==0
cases=read(HERE/'cases.json');rows=[]
for key,case in cases.items():
 path=HERE/'results'/f'{key}.json';raw=read(path)if path.exists()else{'status':'not_started'}
 r=raw.get('result',{});s=case['snapshot'];available=s['discards_left'];target=4*available
 completed=r.get('status')in('supported_clear','modeled_failure')and r.get('final_resources_supported')is True
 actions=r.get('steps',[]);discards=[a for a in actions if(a.get('action')or{}).get('kind')=='discard']
 play_with_discards=[a for a in actions if(a.get('action')or{}).get('kind')=='play'and a.get('before_discards',0)>0]
 row={'case':key,'source_sequence':case['sequence'],'ante':s['ante'],'blind':s['blind']['key'],
  'available_discards':available,'target_cards':target,'execution_status':raw['status'],
  'status':r.get('status',raw['status']),'completed_round':completed,'reason':r.get('reason',raw.get('reason')),
  'cards_discarded':r.get('cards_discarded'),'discards_used':r.get('discards'),'discards_left':r.get('remaining_discards'),
  'discard_sizes':[len((a.get('action')or{}).get('indices',[]))for a in discards],
  'shortfall':max(0,target-r['cards_discarded'])if completed else None,
  'benchmark_met':r['cards_discarded']>=target if completed else None,
  'plays_with_discards':[{'remaining':a['before_discards'],'receipt':(a.get('decision')or{}).get('discard_before_clear'),
   'kind':((a.get('decision')or{}).get('play')or{}).get('hand')}for a in play_with_discards],
  'score_evaluations':r.get('score_evaluations'),'seconds':raw.get('seconds')}
 rows.append(row)
completed=[r for r in rows if r['completed_round']];cards=sum(r['cards_discarded']for r in completed)
target=sum(r['target_cards']for r in completed);discards=sum(r['discards_used']for r in completed)
report={'registered':10,'outcomes':dict(collections.Counter(r['status']for r in rows)),
 'completed_rounds':len(completed),'censored_rounds':10-len(completed),'registered_target_cards':sum(r['target_cards']for r in rows),
 'completed_cards':cards,'completed_target_cards':target,'completed_available_discards':sum(r['available_discards']for r in completed),
 'completed_discards_used':discards,'completed_unused_discards':sum(r['discards_left']for r in completed),
 'completed_cards_per_round':cards/len(completed)if completed else None,
 'completed_target_per_round':target/len(completed)if completed else None,
 'completed_cards_per_discard':cards/discards if discards else None,
 'completed_benchmark_met':cards>=target if completed else None,
 'all_ten_benchmark_verified':len(completed)==10 and cards>=target,'rows':rows,
 'scope':'Fixed targeted model continuations, one world per archived round, no baseline pair/full games/population win rate.',
 'unused_experiment_authority':0}
with(HERE/'RESULTS.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
lines=['# Ten targeted round continuations437','',report['scope'],'',
 f"Registered10; completed{len(completed)}; censored{10-len(completed)}. Outcomes: {report['outcomes']}.",
 f"Completed card total{cards}/{target} benchmark; discards used{discards}; unused{report['completed_unused_discards']}.",
 f"Completed cards/round: {report['completed_cards_per_round']}; required: {report['completed_target_per_round']}; cards/discard: {report['completed_cards_per_discard']}.",
 f"All-ten benchmark verified: {report['all_ten_benchmark_verified']}. Unsupported prefixes are not completed rounds or zero-card outcomes.",'',
 '| Case | Outcome | Cards / target | Discard sizes | Remaining |','|---|---|---:|---|---:|']
for r in rows:
 value=str(r['cards_discarded'])if r['completed_round']else'censored ('+str(r['cards_discarded'])+' prefix)'
 lines.append(f"| {r['case']} | {r['status']} | {value} / {r['target_cards']} | {r['discard_sizes']} | {r['discards_left']} |")
lines+=['','## Shortfalls and unresolved transitions','']
for r in rows:
 if not r['completed_round']or r['shortfall']or r['plays_with_discards']:
  lines.append(f"- {r['case']}: {r['reason']}; shortfall={r['shortfall']}; plays with discards={json.dumps(r['plays_with_discards'])}")
lines+=['','All ten remain in the report. No retries/replacements or post-result tuning are included. All remaining capacity is permanently closed. No loaded-game effectiveness or population win-rate claim.']
(HERE/'EXPERIMENT_REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items()if k!='rows'}))
