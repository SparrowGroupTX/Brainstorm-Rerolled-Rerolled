"""Immutable M06 acquisition-only trace audit, no source execution."""
from pathlib import Path
import hashlib
import json
folder=Path(__file__).resolve().parents[1]/'runs/gold299_20260914/M06'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
record=json.loads((folder/'record.json').read_text());rows=[json.loads(s) for s in (folder/'trace.log').read_text().splitlines() if s.startswith('{')]
assert record['status']=='complete' and record['frozen_files_unchanged'] and record['external_files_unchanged']
assert sha(folder/'trace.log')==record['trace_sha256']
actions=[r for r in rows if r.get('type')=='engine_episode_action']
resolved=[r for r in rows if r.get('type')=='engine_episode_resolved']
setup=[r for r in rows if r.get('type')=='engine_opening_setup_complete']
assert len(actions)==len(resolved)==3 and len(setup)==1
assert [r['action']['kind'] for r in actions]==['skip_blind','choose','choose']
assert all(r['round']==0 and r['ante']==1 and not r['advisor_skipped'] for r in actions)
assert actions[0]['action']['blind']=='Small' and all(r['card_key']=='c_soul' for r in actions[1:])
assert setup[0]['actual_pair']==['j_perkeo','j_yorick'] and setup[0]['decisions']==3
state=setup[0]['snapshot'];held=state['jokers']
assert len(held)==2 and all(not c.get('ability',{}).get('perishable') for c in held)
assert state['phase']=='blind' and state['blind_on_deck']=='Big' and state['round']==0 and state['dollars']==4
assert not any(r.get('type')=='engine_episode_terminal' for r in rows)
stops=[r for r in rows if r.get('type')=='engine_episode_stopped']
assert len(stops)==1 and stops[0]['reason']=='development_opening_setup_complete' and stops[0]['outcome']=='censored'
audit={'schema':1,'status':'passed_opening_acquisition_only','job':'M06','seed':'M4BVSY11','deck':'b_red','stake':8,
       'actions':[{'step':r['step'],'action':r['action'],'card_key':r.get('card_key')} for r in actions],
       'actual_pair':setup[0]['actual_pair'],'retained_jokers':held,'cash':4,'actual_setup_seconds':setup[0]['setup_seconds'],
       'outer_worker_seconds':record['elapsed_seconds'],'source_selected_action_legality':'all three actions passed original callbacks and resolved',
       'scope':'Exact frozen Core/lovely first-Charm hook and frozen300 normal-opening advice; no blind played.',
       'complete_attempts':0,'gameplay_wins':0,'later_Brainstorm_Burnt_acquisition_verified':False,'qualification':False,
       'inference':'Selected synthetic development acquisition, not a complete-run result or a player win-rate cohort.',
       'registration_sha256':sha(folder/'registration.json'),'record_sha256':sha(folder/'record.json'),'trace_sha256':sha(folder/'trace.log')}
with (folder/'audit.json').open('x') as stream:json.dump(audit,stream,indent=2)
print('M06 audited: source acquired Perkeo/Yorick in3 actions, no blind played')
