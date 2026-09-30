"""Exactly one invented adapter position, no captured case/policy replay."""
from pathlib import Path
import json
import run
from evidence_reader import restore
HERE=Path(__file__).resolve().parent
m=run.read(HERE/'QUALIFICATION_INPUTS.json')
for rel,h in m['files'].items():assert run.sha(HERE/rel)==h
cards=[{'id':f'card{i}','rank':13,'suit':'Clubs','enhancement':'c_base','nominal':10,'ability':{}}for i in range(20)]
s={'phase':'hand','teacher_profile':'perkeo_yorick_win_v1','ante':3,'win_ante':8,'hand':cards[:8],'deck':cards[8:],
 'playing_cards':cards,'jokers':[],'consumeables':[],'hands':{},'blind':{'key':'bl_big','chips':1},'chips':0,
 'dollars':20,'hand_size':8,'hand_limit':5,'hands_left':3,'hands_played':0,'discards_left':3,'discards_used':0,
 'current_round':{},'modifiers':{},'probabilities':{'normal':1},'joker_limit':5,'consumable_limit':2}
job={'mode':'continuation','snapshot':s,'policy_first':True,'world_seed':439,'world':0,'world_order':[c['id']for c in cards[8:]],
 'case':'invented_preflight','role':'policy','action_cap':16,'sorting':'rank'}
raw=run.evaluate(job,m);result=restore(raw)
assert result['status']=='supported_clear'and result['discards']==3 and result['remaining_discards']==0
assert result['cards_discarded']>=12 and result['input_unchanged']and result['full_run']is False
run.save(HERE/'QUALIFIED.json',{'manufactured_only':True,'result':result,'raw_sha256':__import__('hashlib').sha256(raw.encode()).hexdigest(),
 'qualification_inputs_sha256':run.sha(HERE/'QUALIFICATION_INPUTS.json')})
print(json.dumps({'status':result['status'],'cards':result['cards_discarded'],'discards':result['discards'],'no_captured_evaluation':True}))
