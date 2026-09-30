"""Public recorded quantities and exact action links only; never runs a policy."""
from pathlib import Path
from collections import Counter,defaultdict
import json
P=Path(__file__).resolve().parent
E=[json.loads(l)for l in (P/'capture/events.jsonl').read_text(encoding='utf-8').splitlines()]
byseq={e['sequence']:e for e in E};obs={e['observation_id']:e for e in E if 'state'in e}
starts=[e for e in E if e['kind']=='auto_run' and e['details'].get('event')=='run_started']
ends={e['run_instance']:e for e in E if e['kind']=='auto_run' and e['details'].get('event')in('run_finished','run_abandoned')}
settled={};callbacks={}
for e in E:
 if e['kind']=='state_after_actions':
  for q in e['details'].get('action_sequences',[]):settled[q]=e
 if e['kind']=='action_callback_result':callbacks[e['details'].get('action_sequence')]=e
def inv(s):return dict(Counter(c['key']for c in s.get('consumeables')or[]))
def jok(s):return [{k:c.get(k)for k in ['key','ability','edition','debuff']}for c in s.get('jokers')or[]]
def yor(s):return next((c['ability'].get('x_mult')for c in s.get('jokers')or[] if c.get('key')=='j_yorick'),None)
def lv(s):return {k:v.get('level')for k,v in (s.get('hands')or{}).items()if v.get('level',1)>1}
def dump(n,x):(P/n).write_text(json.dumps(x,indent=2,allow_nan=False)+'\n',encoding='utf-8')
actions=[]
for e in E:
 if e['kind']!='action_requested':continue
 a=e['details'].get('input',{}).get('action',{});before=obs.get(e.get('observation_id'));afterevent=settled.get(e['sequence']);after=obs.get(afterevent.get('observation_id'))if afterevent else None
 advice=byseq.get(e.get('advice_sequence'),{}).get('advice',{})
 row={'sequence':e['sequence'],'anchor':e['anchor'],'seed':e['seed'],'run_instance':e['run_instance'],'action':a,'source':e['details'].get('source'),
 'before_sequence':before and before['sequence'],'after_sequence':after and after['sequence'],'settled_group':afterevent and afterevent['details'].get('action_sequences'),
 'callback':callbacks.get(e['sequence'],{}).get('details'),'advice_sequence':e.get('advice_sequence'),'advice':advice}
 if before:
  s=before['state'];row['before']=s
  area=s.get(a.get('area'))or[];idx=a.get('index');row['selected']=area[idx-1]if isinstance(idx,int)and 0<idx<=len(area)else None
 if after:row['after']=after['state']
 actions.append(row)
dump('actions.json',actions)
summary=[];rounds=[]
for start in starts:
 rid=start['run_instance'];end=ends.get(rid);ss=[e for e in E if e.get('state')and e['run_instance']==rid and (not end or e['sequence']<=end['sequence'])]
 aa=[a for a in actions if a['run_instance']==rid];last=ss[-1];s=last['state']
 rr=defaultdict(list)
 for e in ss:
  t=e['state']
  if t['round'] and (t.get('blind')or{}).get('chips',0)>0:rr[t['round']].append(e)
 for r,rows in rr.items():
  hs=[e for e in rows if e['state']['phase']=='hand']
  if not hs:continue
  t0=hs[0]['state'];t1=rows[-1]['state'];cash=[a for a in aa if a['action'].get('kind')=='cash_out' and a.get('before',{}).get('round')==r]
  final=cash[-1]['before'] if cash else t1
  disc=[a for a in aa if a['action'].get('kind')=='discard' and a.get('before',{}).get('round')==r]
  plays=[a for a in aa if a['action'].get('kind')=='play' and a.get('before',{}).get('round')==r]
  rounds.append({'run':start['details']['run_number'],'seed':start['seed'],'round':r,'ante':t0['ante'],'blind':t0['blind']['name'],
    'entry_sequence':hs[0]['sequence'],'exit_sequence':cash[-1]['before_sequence']if cash else rows[-1]['sequence'],
    'cleared':bool(cash),'target':t0['blind']['chips'],'final_chips':final['chips'],'entry_discard':t0['discards_left'],
    'remaining_discards':final['discards_left'],'discard_actions':len(disc),'discard_cards':sum(len(a['action'].get('indices',[]))for a in disc),
    'discard_sizes':[len(a['action'].get('indices',[]))for a in disc],'play_actions':len(plays),'entry_yorick':yor(t0),'exit_yorick':yor(final),
    'entry_cash':t0['dollars'],'exit_cash':final['dollars'],'levels':lv(final),'inventory':inv(final),'jokers':jok(final)})
 shops=[a for a in aa if a['action'].get('kind')=='leave_shop'];uses=[a for a in aa if a['action'].get('kind')=='use'];sales=[a for a in aa if a['action'].get('kind')=='sell']
 handstates=[e for e in ss if e['state']['phase']=='hand'];firstcopy=next((e for e in ss if any(c.get('key')in('j_blueprint','j_brainstorm')for c in e['state']['jokers'])),None)
 milestones=[]
 for ante in range(1,9):
  options=[e for e in handstates if e['state']['ante']==ante]
  if options:
   e=options[0];t=e['state'];milestones.append({'ante':ante,'sequence':e['sequence'],'yorick':yor(t),'cash':t['dollars'],'levels':lv(t),'inventory':inv(t),'jokers':jok(t),'observatory':bool((t.get('used_vouchers')or{}).get('v_observatory'))})
 summary.append({'run':start['details']['run_number'],'seed':start['seed'],'run_instance':rid,'start_sequence':start['sequence'],'end_sequence':end and end['sequence'],
  'outcome':end and end['details'].get('outcome'),'end_details':end and end['details'],'last_state_sequence':last['sequence'],'last_ante':s['ante'],'last_round':s['round'],
  'last_blind':s['blind'],'last_chips':s['chips'],'last_cash':s['dollars'],'last_yorick':yor(s),'last_inventory':inv(s),'last_levels':lv(s),'last_jokers':jok(s),
  'actions':dict(Counter(a['action'].get('kind','other')for a in aa)), 'use_types':dict(Counter((a.get('selected')or{}).get('key','unknown')for a in uses)),
  'sales':[{k:a[k]for k in ['sequence','action','selected']}for a in sales],
  'shop_exits':[{'sequence':a['sequence'],'ante':a['before']['ante'],'cash':a['before']['dollars'],'inventory':inv(a['before']),'observatory':bool((a['before'].get('used_vouchers')or{}).get('v_observatory'))}for a in shops],
  'first_copy':None if not firstcopy else {'sequence':firstcopy['sequence'],'ante':firstcopy['state']['ante']},'milestones':milestones})
dump('runs.json',summary);dump('rounds.json',rounds)
print(json.dumps([{'run':r['run'],'seed':r['seed'],'outcome':r['outcome'],'ante':r['last_ante'],'blind':r['last_blind']['name'],'chips':r['last_chips'],'target':r['last_blind']['chips'],'cash':r['last_cash'],'yorick':r['last_yorick'],'inventory':r['last_inventory'],'levels':r['last_levels'],'copy':r['first_copy']}for r in summary]))
