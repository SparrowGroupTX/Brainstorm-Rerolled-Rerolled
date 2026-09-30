"""Summarize immutable loss evidence and separately freeze a newer version prefix."""
import collections
import hashlib
import io
import json
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/advisor_eval'));from read_player_log import records
def sha(data):return hashlib.sha256(data).hexdigest()
AUDIT=HERE/'passive_audit.json';expected='2d2a0ef4c501c9c5fe9ea65fd9781ec7f2af5e9f9da46bb3c1aa5c4521be9b5f'
assert sha(AUDIT.read_bytes())==expected
a=json.loads(AUDIT.read_bytes());events=a['events'];byseq={e['anchor']['sequence']:e for e in events}
def action(e):return e.get('details',{}).get('input',{}).get('action',{})
def compact_card(c):
 return {**{k:c.get(k) for k in ('id','key','name','cost','sell_cost','edition','debuff','pinned','gold_record')},
   'ability':{k:c.get('ability',{}).get(k) for k in ('eternal','rental','perishable','perish_tally','perma_debuff','pinned','x_mult','extra','type','t_mult')}}
def selected(e):
 return {**{k:e.get(k) for k in ('anchor','at','kind','version','seed','state','goal','advice')},
   'action':action(e),'jokers':[compact_card(c) for c in e['jokers']],
   'shop_jokers':[compact_card(c) for c in e['shop_jokers']],
   'consumeables':[compact_card(c) for c in e['consumeables']]}
run=[e for e in events if e.get('seed')=='RH45AD21' and e['anchor']['sequence']<=3448]
requests=[e for e in run if e['kind']=='action_requested']
all_requests=[e for e in events if e['kind']=='action_requested']
timeline=[];last=None
for e in run:
 c=next((c for c in e['jokers'] if c.get('id')=='card:1020'),None)
 if not c:continue
 ab=c['ability'];flags=(c.get('debuff'),ab.get('perish_tally'),ab.get('perishable'),ab.get('rental'),ab.get('eternal'),ab.get('perma_debuff'))
 if flags!=last:
  timeline.append({**{k:e[k] for k in ('anchor','at','kind','version','seed','state')},'card':compact_card(c)})
  last=flags
shops=[]
for round_number in (14,15,16):
 rs=[e for e in requests if e['state']['phase']=='shop' and e['state']['round']==round_number and e['state']['ante']==6]
 shops.append({'ante':6,'round':round_number,'actions':[selected(e) for e in rs],
   'opening_cash':rs[0]['state']['dollars'],'exit_cash':rs[-1]['state']['dollars'],
   'exit_sequence':rs[-1]['anchor']['sequence'],'visible_offers':[compact_card(c) for c in rs[-1]['shop_jokers']]})
round17=[selected(e) for e in requests if e['state']['round']==17]
wanted={2971,2975,3242,3250,3272,3289,3294,3343,3371,3376,3408,3413,3418,3423,3445,3448}
receipts=[];public_extra={}
for item in a['inputs']:
 data=Path(item['frozen_path']).read_bytes();assert sha(data)==item['sha256'] and len(data)==item['bytes']
 for raw,meta in records(io.BytesIO(data)):
  e=json.loads(raw);seq=e.get('sequence')
  if seq not in wanted:continue
  dest=HERE/('original_event_'+str(seq)+'.json')
  with dest.open('xb') as handle:handle.write(raw)
  receipts.append({'sequence':seq,'path':str(dest),'sha256':sha(raw)})
  s=e.get('context',{}).get('snapshot',{})
  public_extra[str(seq)]={k:s.get(k) for k in ('modifiers','last_tarot_planet','consumeable_usage','consumeable_usage_total','rental_rate','used_vouchers','ordering_safe','jokers_shuffling')}

source=Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2')
prefix='session-20260916T065627Z-1';paths=sorted(source.glob(prefix+'-*.brj'));assert 1<=len(paths)<=8
lengths={p:p.stat().st_size for p in paths};assert sum(lengths.values())<=16*1024*1024
frozen=HERE/'newer_frozen_prefix';frozen.mkdir(exist_ok=False)
new_inputs=[];new_versions=collections.Counter();new_terminal=[];new_count=0;new_last=None;new_errors=[]
for p in paths:
 before=p.stat()
 with p.open('rb') as handle:data=handle.read(lengths[p])
 after=p.stat();assert len(data)==lengths[p];dest=frozen/p.name
 with dest.open('xb') as handle:handle.write(data)
 item={'original_path':str(p),'frozen_path':str(dest),'bytes':len(data),'sha256':sha(data),'append_active':p==paths[-1],
  'stat_unchanged_during_read':(before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns),'original_size_after_read':after.st_size}
 n=0
 try:
  for ordinal,(raw,meta) in enumerate(records(io.BytesIO(data)),1):
   e=json.loads(raw);n+=1;new_count+=1;c=e.get('context',{});d=e.get('details',{})
   if c.get('version'):new_versions[c['version']]+=1
   anchor={'segment':p.name,'ordinal':ordinal,'sequence':e.get('sequence'),'decoded_event_sha256':sha(raw),'stored_frame_sha256':meta.get('frame_sha256')}
   new_last={'anchor':anchor,'at':e.get('at'),'seed':c.get('seed'),'kind':e.get('kind')}
   if d.get('event') in ('run_finished','session_stopped'):
    new_terminal.append({'anchor':anchor,'at':e.get('at'),'version':c.get('version'),'seed':c.get('seed'),
      'details':{k:d.get(k) for k in ('event','outcome','reason','run_id','run_number','evidence','gold_award','gold_progress')}})
 except Exception as exc:new_errors.append({'segment':p.name,'completed_records':n,'error':str(exc)})
 item['event_count']=n;new_inputs.append(item)

end=byseq[3448]
terminals=[]
for e in events:
 if e['details'].get('event')=='run_finished':
  terminals.append({**{k:e[k] for k in ('anchor','at','version','seed','state')},
    'outcome':e['details'].get('outcome'),'evidence':e['details'].get('evidence'),
    'gold_award':e['details'].get('gold_award'),'run_actions':e['details'].get('run_actions')})
final=byseq[3413];inventory=final['consumeables'];sell_sum=sum(c['sell_cost'] for c in final['jokers'])
report={'schema':1,'scope':a['scope'],'audit':{'path':str(AUDIT),'sha256':expected},
 'inputs':a['inputs'],'loaded_versions':a['loaded_versions'],'decode_errors':a['decode_errors'],
 'last_sequence':a['last_sequence'],'last_at':a['last_at'],
 'latest_audited_loss':{**selected(end),'terminal_details':end['details'],
   'classification':'Verified loss; expired Rental Perishable Trio; loaded2.148, not newer2.149.',
   'shortfall':end['state']['blind']['chips']-end['state']['chips']},
 'trio_timeline':timeline,'trio_acquisition':selected(byseq[2971]),'post_expiry_shops':shops,
 'final_round_actions':round17,
 'ordering_gap':{'shop_copy_action_sequence':3408,'shop_exit_sequence':3413,
   'row_all_final_round_actions':[c['key'] for c in byseq[3423]['jokers']],
   'reorder_actions_in_final_round':sum(action(e).get('kind')=='reorder_jokers' for e in requests if e['state']['round']==17),
   'prior_visible_round_reorders':[selected(byseq[i]) for i in (3289,3371)],
   'qualification':'Observed Blueprint stays immediately left of Perkeo on all final Wheel actions; no counterfactual ordering score or saved-run outcome is asserted.'},
 'rerolls':{'latest_loss_run_action_requests':len(requests),'latest_loss_run_reroll_requests':sum(action(e).get('kind')=='reroll' for e in requests),
   'entire_frozen_session_action_requests':len(all_requests),'entire_frozen_session_reroll_requests':sum(action(e).get('kind')=='reroll' for e in all_requests)},
 'final_shop_cleanup_fields':{'sequence':3413,'inventory_count':len(inventory),'inventory_keys':[c['key'] for c in inventory],
   'negative_count':sum(bool((c.get('edition') or {}).get('negative')) for c in inventory),
   'held_temperance_count':sum(c['key']=='c_temperance' for c in inventory),'limit':final['state']['consumable_limit'],
   'buffer':final['state']['consumeable_buffer'],'row_sell_cost_sum':sell_sum,
   'last_tarot_planet':public_extra['3413']['last_tarot_planet'],'last_explicit_held_use':{'sequence':3392,'key':'c_hermit'},
   'modifiers':public_extra['3413']['modifiers'],'rental_rate':public_extra['3413']['rental_rate'],
   'current_perkeo_copy_events':2,'copy_evidence':'3408 advice explicitly records1->2 copy events; exact current row Blueprint immediately before active Perkeo.'},
 'public_extra':public_extra,'original_event_receipts':receipts,'session_terminal_records':terminals,
 'newer_session':{'prefix':prefix,'inputs':new_inputs,'loaded_versions':dict(new_versions),'event_count':new_count,
   'last':new_last,'decode_errors':new_errors,'terminal_or_stop_records':new_terminal,
   'qualification':'Separate newer passive prefix. The RH45AD21 loss above belongs to2.148 and is not attributed to2.149. No unobserved outcome is imputed.'},
 'limits':['No policy was evaluated on these public states.','Visible purchases/reorders are unexecuted alternatives; no rescue or counterfactual scores are inferred.',
   'Numeric heuristic card ratings are not exposed by this journal; advice and compact gold-review diagnostics are preserved without inventing missing ratings.',
   'The Trio is explicitly expired at perish_tally0, not classified from debuff alone. Other transient boss debuffs must remain distinct.',
   'The final shop offered no demonstrated winning purchase. Earlier missing Supernova was visible and affordable after selling the expired Trio, but its resulting score was not evaluated.']}
out=HERE/'summary.json'
with out.open('x',encoding='utf-8') as handle:json.dump(report,handle,indent=2);handle.write('\n')
print(json.dumps({'path':str(out),'sha256':sha(out.read_bytes()),'rerolls':report['rerolls'],'final_shop_cleanup_fields':report['final_shop_cleanup_fields'],
 'newer_versions':dict(new_versions),'newer_events':new_count,'newer_last':new_last,
 'newer_terminal_or_stop_count':len(new_terminal),'newer_decode_errors':new_errors}))
