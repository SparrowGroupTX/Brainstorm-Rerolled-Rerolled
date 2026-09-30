"""Passive complete accounting; never executes a policy or replaces a case."""
from pathlib import Path
from collections import Counter
import json
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def summarize(rows):
 n=len(rows);cards=sum(r['cards_discarded'] for r in rows);used=sum(r['discards_used'] for r in rows)
 available=sum(r['available_discards'] for r in rows);target=sum(r['target_cards'] for r in rows)
 return {'rounds':n,'cards_discarded':cards,'discards_used':used,'available_discards':available,
  'target_cards':target,'unused_discards':sum(r['discards_left'] for r in rows),
  'discards_per_round':used/n if n else None,'cards_per_round':cards/n if n else None,
  'cards_per_discard':cards/used if used else None,'target_per_round':target/n if n else None,
  'aggregate_benchmark_met':cards>=target if n else None,
  'individual_rounds_meeting_benchmark':sum(r['cards_discarded']>=r['target_cards'] for r in rows)}
def make_row(key,case,raw):
 r=raw.get('result',{});s=case['snapshot'];available=s['discards_left']
 completed=r.get('status') in ('supported_clear','modeled_failure') and r.get('final_resources_supported') is True
 steps=r.get('steps') or [];attempted=[a for a in steps if (a.get('action') or {}).get('kind')=='discard']
 count=r.get('discards');settled=attempted[:count] if count is not None else []
 sizes=[len(a['action']['indices']) for a in settled]
 if count is not None:assert len(sizes)==count and sum(sizes)==r['cards_discarded']
 return {'case':key,'run':case.get('run'),'source_sequence':case['sequence'],'ante':s['ante'],'blind':s['blind']['key'],
  'available_discards':available,'target_cards':4*available,'execution_status':raw['status'],
  'status':r.get('status',raw['status']),'completed_round':completed,'reason':r.get('reason',raw.get('reason')),
  'cards_discarded':r.get('cards_discarded'),'discards_used':count,'discards_left':r.get('remaining_discards'),
  'settled_discard_sizes':sizes,'unsettled_discard_attempts':len(attempted)-len(settled),
  'final_resources_supported':r.get('final_resources_supported',False),'resources_prefix_supported':r.get('resources_prefix_supported'),
  'shortfall':max(0,4*available-r['cards_discarded']) if completed else None,
  'benchmark_met':r['cards_discarded']>=4*available if completed else None,
  'plays_with_discards':[{'remaining':a['before_discards'],'hand':((a.get('decision') or {}).get('play') or {}).get('hand'),
   'receipt':(a.get('decision') or {}).get('discard_before_clear'),'yorick_review':(a.get('decision') or {}).get('yorick_review')}
   for a in steps if (a.get('action') or {}).get('kind')=='play' and a.get('before_discards',0)>0],
  'score_evaluations':r.get('score_evaluations'),'seconds':raw.get('seconds')}
def analyze():
 closed=read(HERE/'CLOSED.json');assert closed['remaining_authority']==0
 cases=read(HERE/'cases.json');assert len(cases)==20
 rows=[make_row(k,c,read(HERE/'results'/f'{k}.json') if (HERE/'results'/f'{k}.json').exists() else {'status':'not_started'}) for k,c in cases.items()]
 completed=[r for r in rows if r['completed_round']];censored=[r for r in rows if not r['completed_round']]
 prefixes=[r for r in censored if all(r[k] is not None for k in ('cards_discarded','discards_used','discards_left'))]
 report={'registered':20,'completed_rounds':len(completed),'censored_rounds':len(censored),
  'outcomes':dict(Counter(r['status'] for r in rows)),'registered_available_discards':sum(r['available_discards'] for r in rows),
  'registered_target_cards':sum(r['target_cards'] for r in rows),'completed':summarize(completed),
  'completed_by_available_discards':{str(d):summarize([r for r in completed if r['available_discards']==d]) for d in sorted({r['available_discards'] for r in rows})},
  'censored_prefixes':summarize(prefixes),'censored_without_counts':len(censored)-len(prefixes),
  'all_twenty_benchmark_verified':len(completed)==20 and summarize(completed)['aggregate_benchmark_met'],
  'all_twenty_average_cards_per_round':summarize(completed)['cards_per_round'] if len(completed)==20 else None,
  'rows':rows,'unused_experiment_authority':0,'scope':'Candidate2.217 only;20 distinct public round openings;one hypothetical world each;no full-game or population win-rate inference.'}
 with (HERE/'RESULTS.json').open('x',encoding='utf-8') as f:json.dump(report,f,indent=2,allow_nan=False);f.write('\n')
 c=report['completed'];lines=['# Twenty targeted round continuations439','',report['scope'],'',
  f"Registered20; complete rounds{len(completed)}; censored{len(censored)}. Outcomes: {report['outcomes']}.",
  f"Completed-round averages: {c['discards_per_round']} discards, {c['cards_per_round']} cards, {c['cards_per_discard']} cards per discard.",
  f"Completed cards{c['cards_discarded']}/{c['target_cards']} required; {c['unused_discards']} unused discards. Completed benchmark: {c['aggregate_benchmark_met']}.",
  f"Entire registered cohort target: {report['registered_target_cards']}/20 = {report['registered_target_cards']/20} cards per round. All20 verified: {report['all_twenty_benchmark_verified']}.",
  'Modeled failures remain in complete-round averages. Censored prefixes are not complete rounds or zero-card outcomes.','',
  '| Case | Outcome | Cards / target | Settled discard sizes | Unused |','|---|---|---:|---|---:|']
 for r in rows:
  value=str(r['cards_discarded']) if r['completed_round'] else f"censored ({r['cards_discarded']} prefix)"
  lines.append(f"| {r['case']} | {r['status']} | {value} / {r['target_cards']} | {r['settled_discard_sizes']} | {r['discards_left']} |")
 lines+=['','## Supported prefix accounting','',json.dumps(report['censored_prefixes']),
  'Prefix action counters count only successfully transitioned discards. Final resources may be unresolved. Their averages are not full-round performance.','',
  '## Shortfalls and unresolved transitions','']
 for r in rows:
  if not r['completed_round'] or r['shortfall'] or r['plays_with_discards']:
   lines.append(f"- {r['case']}: {r['reason']}; shortfall={r['shortfall']}; plays with discards={json.dumps(r['plays_with_discards'])}")
 lines+=['','All20 registrations are consumed, with no retries or replacements. Candidate2.217 remains uninstalled. The source session was an active prefix; no completed-session or normal-exit inference. No baseline causal comparison. Round rewards/future shops are not modeled. No Acorn or Heart case was selected.']
 with (HERE/'EXPERIMENT_REPORT.md').open('x',encoding='utf-8') as f:f.write('\n'.join(lines)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
if __name__=='__main__':analyze()
