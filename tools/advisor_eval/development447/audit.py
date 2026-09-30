"""Full fixed public-cohort accounting; no policy or scorer import/execution."""
from pathlib import Path
from collections import Counter,defaultdict
import json,sys
H=Path(__file__).resolve().parent;E=H.parent;sys.path.insert(0,str(E))
import flag_suspect_decisions as screen
def read(p):return json.loads(p.read_text())
def save(name,x):
    with (H/name).open('x')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
C=E/'development446/install/captures/001';cases=[];flags=[]
raw=screen.analyze(C/'logs',C/'manifest.json',256,on_settled=cases.append,on_flag=flags.append)
obs=read(H/'analysis/observations.json');runs=read(H/'analysis/runs.json');decisions=read(H/'analysis/decisions.json')
groups=defaultdict(list)
for c in cases:groups[(c['run']['run_number'],c['state']['round'])].append(c)
closed={k:'clear'for k,v in groups.items()if any(c['action']['kind']=='play'for c in v)}
for r in runs:
 if r['end']['details'].get('outcome')=='loss':closed[(r['run'],r['last_observation']['round'])]='loss'
rounds=[]
for key,outcome in sorted(closed.items()):
 start=next(o for o in obs if(o['run'],o['round'])==key and o['phase']=='hand')
 ds=[c for c in groups[key]if c['action']['kind']=='discard']
 clear=next((c for c in groups[key]if c['action']['kind']=='play'),None)
 rounds.append({'run':key[0],'round':key[1],'outcome':outcome,'ante':start['ante'],'blind':start['blind'].get('key'),
  'initial_discards':start['discards_left'],'used_discards':len(ds),'cards':sum(len(c['action']['indices'])for c in ds),
  'unused_at_clear':clear['after']['discards_left']if clear else None,
  'clear_request':clear['anchors']['request']['sequence']if clear else None})
unclosed=sorted({(o['run'],o['round'])for o in obs if o['run']and o['phase']=='hand'}-closed.keys())
excluded=[]
for key in unclosed:
 ds=[c for c in groups[key]if c['action']['kind']=='discard']
 excluded.append({'run':key[0],'round':key[1],'confirmed_discards':len(ds),'confirmed_cards':sum(len(c['action']['indices'])for c in ds),
  'qualification':'No qualified round-closing play join or terminal loss; not assumed unfinished'})
discards=[c for c in cases if c['action']['kind']=='discard'];clears=[c for c in cases if c['action']['kind']=='play']
eligible=[r for r in rounds if r['initial_discards']>0]
unused=[c for c in clears if c['after']['discards_left']>0]
summary={'session':read(C/'summary.json')['session'],'loaded_version':'2.219.0-alpha','events':28200,
 'starts':10,'endings':10,'outcomes':read(C/'summary.json')['outcomes'],
 'qualified_settlements':len(cases),'confirmed_discards':len(discards),
 'discard_sizes':dict(sorted(Counter(len(c['action']['indices'])for c in discards).items())),
 'cards_discarded':sum(len(c['action']['indices'])for c in discards),
 'cards_per_discard':sum(len(c['action']['indices'])for c in discards)/len(discards),
 'qualified_clears':len(clears),'unused_discard_clears':len(unused),'unused_at_clear':sum(c['after']['discards_left']for c in unused),
 'rounds_with_qualified_closing_evidence_including_losses':len(rounds),
 'positive_discard_qualified_rounds':len(eligible),'positive_discard_cards':sum(r['cards']for r in eligible),
 'positive_discard_uses':sum(r['used_discards']for r in eligible),
 'average_cards':sum(r['cards']for r in eligible)/len(eligible),
 'average_uses':sum(r['used_discards']for r in eligible)/len(eligible),
 'average_target':sum(4*r['initial_discards']for r in eligible)/len(eligible),
 'below_target_rounds':sum(r['cards']<4*r['initial_discards']for r in eligible),
 'by_available_discards':{},'excluded_without_closing_join':excluded,
 'zero_discard_rounds':[r for r in rounds if r['initial_discards']==0],
 'rounds':rounds,'policy_executed':False,'scorer_executed':False,'population_win_rate_claimed':False}
for count in sorted({r['initial_discards']for r in eligible}):
 sub=[r for r in eligible if r['initial_discards']==count]
 summary['by_available_discards'][count]={'rounds':len(sub),'cards':sum(r['cards']for r in sub),
  'average_cards':sum(r['cards']for r in sub)/len(sub),'target':4*count,
  'below_target':sum(r['cards']<4*count for r in sub)}
save('METRICS.json',summary)
save('ALL_FLAGS.json',{'raw_flags':flags,'counts':dict(Counter(f['rule']for f in flags)),
 'flag_rows_omitted':0,'packets_omitted_by_original_128_cap':40,
 'note':'Compact raw flags retained for complete coverage; structural alternative packets retain the existing128 cap.'})
trace=[]
for c in unused:
 s=c['state'];hand=s.get('hand')or[]
 visible=[{'index':i+1,'rank':v.get('rank'),'suit':v.get('suit'),'enhancement':v.get('enhancement')}
  for i,v in enumerate(hand)if v.get('rank')and v.get('suit')and not any(v.get(k)for k in('face_down','unknown','identity_unknown','identity_redacted','concealed'))and v.get('facing')!='back']
 trace.append({'run':c['run']['run_number'],'anchors':c['anchors'],'blind':s['blind'],'ante':s['ante'],'round':s['round'],
  'remaining_discards':c['after']['discards_left'],'jokers':s['jokers'],'visible_cards':visible,
  'action':c['action'],'receipt':c['advice'].get('discard_before_clear'),
  'public_state':s,'advice':c['advice'],'settled_state':c['after']})
save('UNUSED_CLEAR_TRACE.json',trace)
print(json.dumps({k:v for k,v in summary.items()if k not in('rounds','zero_discard_rounds')}))
