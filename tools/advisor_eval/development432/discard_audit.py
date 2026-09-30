"""Public causal joins and descriptive discard/round counts; no policy execution."""
from pathlib import Path
from collections import Counter,defaultdict
import json,sqlite3
P=Path(__file__).resolve().parent;OUT=P/'discard';OUT.mkdir(exist_ok=False)
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
ds=read(P/'analysis/decisions.json');fs=read(P/'suspects/report.json')['flags'];runs=read(P/'analysis/runs.json')
db=sqlite3.connect((P.parent/'development430/captures/002/events.sqlite3').as_uri()+'?mode=ro',uri=True)
def event(seq):return json.loads(db.execute('SELECT data FROM events WHERE seq=?',(seq,)).fetchone()[0])
def snapshot(d):return event(d['observation_sequence']).get('context',{}).get('snapshot',{})
def act(d):return d['action']or{}
def brief(d):
 s=d['before']or{};a=d['advice'];after=d.get('after')or{}
 return {'request':d['sequence'],'observation':d['observation_sequence'],'advice_sequence':d['advice_sequence'],
  'settlement':d['settlement'],'action':act(d),'title':a.get('title'),'lines':a.get('lines'),
  'before':{k:s.get(k)for k in ('ante','round','chips','hands_left','discards_left','dollars','blind','jokers','consumeables','hand_levels')},
  'after':{k:after.get(k)for k in ('phase','chips','hands_left','discards_left','jokers')},
  'discard_before_clear':a.get('discard_before_clear'),'yorick_review':a.get('yorick_review')}
discards=[d for d in ds if act(d).get('kind')=='discard'];sizes=Counter(len(act(d)['indices'])for d in discards)
counts=[]
for d in discards:
 b=d['before']or{};a=d['after']or{}
 counts.append({'request':d['sequence'],'run':d['run'],'cards':len(act(d)['indices']),
  'resource_delta_matches':a.get('discards_left')==b.get('discards_left',0)-1,
  'used_delta_matches':a.get('discards_used')==b.get('discards_used',0)+1})
unused=[];reason_counts=Counter();byrun=defaultdict(lambda:{'rounds':0,'unused':0})
for f in fs:
 if f['rule']!='unused_discards_at_clear':continue
 d=next(d for d in ds if d['sequence']==f['anchors']['request']['sequence']);s=snapshot(d)
 reason=(d['advice'].get('discard_before_clear')or{}).get('reason','no reason');reason_counts[reason]+=1
 row={'run':d['run'],'remaining':f['evidence']['remaining_discards'],'reason':reason,
  'nominal_blinds_remaining':f['evidence']['nominal_unskipped_blinds_including_current'],
  'public_effect_anchor':f['anchors']['effect'],'selected_cards':[s['hand'][i-1]for i in act(d).get('indices',[])],**brief(d)}
 unused.append(row);byrun[d['run']]['rounds']+=1;byrun[d['run']]['unused']+=row['remaining']
groups=defaultdict(list)
for d in ds:
 if(d['before']or{}).get('phase')=='hand'and act(d):groups[(d['run'],d['before']['round'])].append(d)
terminal=[]
for r in runs:
 if r['end']['details']['outcome']!='loss':continue
 members=groups[(r['run'],r['last_hand']['round'])];last_play=[d for d in members if act(d).get('kind')=='play'][-1]
 terminal.append({'run':r['run'],'end':r['end'],'last_hand_observation':r['last_hand']['sequence'],
  'last_play_settled':brief(last_play),'round_actions':[brief(d)for d in members],
  'prior_unused_clears':[u for u in unused if u['run']==r['run']],
  'earlier_rounds':[{'round':rnd,'first':brief(items[0]),'discard_requests':[d['sequence']for d in items if act(d).get('kind')=='discard'],
    'discard_cards':sum(len(act(d)['indices'])for d in items if act(d).get('kind')=='discard')}
    for(run,rnd),items in groups.items()if run==r['run']and rnd<r['last_hand']['round']]})
tarot_chains=[];deferred=[];continuation=Counter();short_receipts=Counter()
for d in ds:
 a=d['advice'];risk=(a.get('yorick_review')or{}).get('risk')or{}
 if risk.get('development_deferred_for_discard'):deferred.append({'run':d['run'],'request':d['sequence'],'action':act(d),
  'callback':d['callback'],'settlement':d['settlement'],'risk':risk})
 for line in a.get('lines',[]):
  if 'Remaining-blind comparison unavailable:'in line:continuation[line]+=1
 if act(d).get('kind')=='discard'and len(act(d)['indices'])<5:
  short_receipts['total']+=1
  if risk.get('compared'):
   short_receipts['risk_compared']+=1
   if risk.get('compared_five_count',0)>0:short_receipts['five_compared']+=1
   if risk.get('qualified_five_count',0)>0:short_receipts['five_qualified']+=1
   if risk.get('sampled_clears')==risk.get('samples'):short_receipts['best_sampled_all_clear']+=1
 b=d['before']or{}
 if b.get('phase')=='hand'and act(d).get('kind')in ('use','choose')and b.get('discards_left',0)>0:
  round_ds=groups[(d['run'],b['round'])];later=[x for x in round_ds if x['sequence']>d['sequence']]
  clear=next((u for u in unused if u['run']==d['run']and u['before']['round']==b['round']and u['request']>d['sequence']),None)
  if clear and not any(act(x).get('kind')=='discard'for x in later if x['sequence']<clear['request']):
   tarot_chains.append({'run':d['run'],'card':d['selected_card'].get('key'),'use':brief(d),'clear_request':clear['request'],
     'clear_reason':clear['reason'],'remaining_at_clear':clear['remaining'],'safe_alternative_established':False})
burnt=[]
for d in discards:
 b=d['before'];s=snapshot(d)
 if b.get('discards_used',0)!=0 or not any(j.get('key')=='j_burnt'and not j.get('debuff')for j in b.get('jokers',[])):continue
 selected=[s['hand'][i-1]for i in act(d)['indices']]
 after=d['after']or{};changes={k:(h.get('level'),(after.get('hand_levels')or{}).get(k,{}).get('level'))for k,h in b.get('hand_levels',{}).items()
  if(after.get('hand_levels')or{}).get(k,{}).get('level')!=h.get('level')}
 burnt.append({'run':d['run'],'request':d['sequence'],'indices':act(d)['indices'],'cards':selected,
  'level_changes':changes,'row':[j.get('key')for j in b.get('jokers',[])],'receipt':d['advice'].get('yorick_review')})
summary={'discard_actions':len(discards),'discarded_cards':sum(k*v for k,v in sizes.items()),'discard_size_counts':dict(sizes),
 'cards_per_discard':sum(k*v for k,v in sizes.items())/len(discards),
 'discard_resource_mismatches':[c for c in counts if not(c['resource_delta_matches']and c['used_delta_matches'])],
 'unused_clear_count':len(unused),'unused_total':sum(x['remaining']for x in unused),'unused_by_run':dict(byrun),
 'unused_reasons':dict(reason_counts),'final_boss_unused_clears':sum(x['nominal_blinds_remaining']==1 for x in unused),
 'hand_rounds_observed':len(groups),'short_receipts':dict(short_receipts),
 'development_deferred':len(deferred),'development_deferred_then_non_discard':sum(act(d).get('kind')!='discard'for d in deferred),
 'enhancement_then_clear_without_discard':len(tarot_chains),'continuation_unavailable':dict(continuation),
 'burnt_first_discards':len(burnt),'terminal_losses':len(terminal)}
for name,value in {'summary':summary,'discard_counts':counts,'unused':unused,'terminal':terminal,'tarot_chains':tarot_chains,
 'deferred':deferred,'burnt':burnt}.items():(OUT/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2))
