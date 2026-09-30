"""Descriptive public receipt extraction only; never invoke a policy/scorer."""
from pathlib import Path
import json, sqlite3
HERE=Path(__file__).resolve().parent
db=sqlite3.connect((HERE/'captures/001/events.sqlite3').resolve().as_uri()+'?mode=ro',uri=True)
events={seq:json.loads(raw) for seq,raw in db.execute('select seq,data from events order by seq')}
def compact_snapshot(seq):
    e=events[seq];s=e['context']['snapshot']
    return {'sequence':seq,'phase':s.get('phase'),'ante':s.get('ante'),'round':s.get('round'),
      'chips':s.get('chips'),'target':s.get('blind',{}).get('chips'),'discards_left':s.get('discards_left'),
      'discards_used':s.get('discards_used'),'hands_left':s.get('hands_left'),
      'consumables':[c.get('key') for c in s.get('consumeables',[])],
      'hand_enhancements':[{'id':c.get('id'),'enhancement':c.get('enhancement'),'bonus':c.get('ability',{}).get('bonus')} for c in s.get('hand',[])],
      'jokers':[{'key':j.get('key'),'x_mult':j.get('ability',{}).get('x_mult'),'yorick_discards':j.get('ability',{}).get('yorick_discards')} for j in s.get('jokers',[])]}
traces=[]
for advice_seq in (1210,1223,1236,1639,1652,1665):
    e=events[advice_seq];a=e['context']['advice']
    request=next(v for v in events.values() if v['kind']=='action_requested' and v.get('advice_sequence')==advice_seq)
    callback=next(v for v in events.values() if v['kind']=='action_callback_result' and v['details'].get('action_sequence')==request['sequence'])
    settled=next(v for v in events.values() if v['kind']=='state_after_actions' and request['sequence'] in v['details'].get('action_sequences',[]))
    before=compact_snapshot(e['observation_sequence']);after=compact_snapshot(settled['observation_sequence'])
    assert before['discards_left']==after['discards_left']==3
    traces.append({'advice_sequence':advice_seq,'before':before,'action':a['action'],'title':a['title'],
      'yorick_review':a.get('yorick_review'),'discard_before_clear':a.get('discard_before_clear'),
      'timing':a.get('timing'),'requested_sequence':request['sequence'],'callback_sequence':callback['sequence'],
      'callback':callback['details'],'settlement_sequence':settled['sequence'],'settlement_scope':settled['details']['observation'],'after':after})
result={'session':'session-20260927T173551Z-1','loaded_version':'2.207.0-alpha',
 'capture':'captures/001','trace_kind':'passive_public_receipts_no_policy_or_scorer_execution',
 'confirmed':'Optional Hierophant development displaced admitted five-card search discard; subsequent recorded clear left3 discards.',
 'mechanism':'Repeated enhancement reduces the neutral-growth bonus; unsupported retained-order proof then leaves no admitted discard.',
 'causal_limit':'No counterfactual gameplay or claim that a repaired action wins the unseen continuation.',
 'traces':traces}
with (HERE/'TRACE.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2);f.write('\n')
print(json.dumps({'traced_actions':len(traces),'loaded':'2.207.0-alpha','rounds':[9,13],'settled_unused_discards':3}))
