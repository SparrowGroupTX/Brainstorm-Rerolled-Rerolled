"""Immutable M08 callback-effect audit after root has reaped the source job."""
from pathlib import Path
import hashlib
import json
folder=Path(__file__).resolve().parents[1]/'runs/gold299_20260914/M08'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
record=json.loads((folder/'record.json').read_text());rows=[json.loads(s) for s in (folder/'trace.log').read_text().splitlines() if s.startswith('{')]
assert record['status']=='complete' and record['frozen_files_unchanged'] and record['external_files_unchanged']
assert sha(folder/'trace.log')==record['trace_sha256']
assert not any(r.get('type')=='engine_episode_action' for r in rows)
terminals=[r for r in rows if r.get('type')=='engine_episode_terminal'];assert len(terminals)==1
t=terminals[0];assert t['outcome']=='win' and t['decisions']==0 and not t['game_over']
e=t['normal_progress'];assert e['threshold_met'] and e['deck_progress'] and e['joker_progress'] and not e['source_saved']
callbacks=e['callbacks'];assert [c['name'] for c in callbacks]==['set_joker_win','set_deck_win']
keys=['j_yorick','j_perkeo','j_brainstorm','j_burnt'];joker=callbacks[0];deck=callbacks[1]
assert set(joker['before']['jokers'])==set(keys)==set(joker['after']['jokers'])
assert all(joker['before']['jokers'][key]==0 and joker['after']['jokers'][key]==1 for key in keys)
assert deck['before']['deck_wins']==0 and deck['after']['deck_wins']==1 and deck['after']['stake']==8
references=json.loads((folder/'controller_input_source_references.json').read_text())
assert len(references['references'])<=6 and all(len(r['text'].splitlines())<=60 for r in references['references'])
audit={'schema':1,'job':'M08','status':'passed_nonempty_original_gold_progress_callbacks',
       'source_callback_joker_increments':{key:{'before':0,'after':1,'stake':8} for key in keys},
       'source_callback_deck_increment':{'deck':'b_red','stake':8,'before':0,'after':1},
       'terminal_fixture':t,'profile':'synthetic all_unlocked_discovered_v1','source_controller_sha256':references['sha256'],
       'controller_reference_file_sha256':sha(folder/'controller_input_source_references.json'),
       'policy_decisions':0,'complete_attempts':0,'gameplay_wins':0,'qualification':False,
       'scope':'Injected held row and final chip total; exact original progress callback effects, not autonomous acquisition, survival, player profile or complete-run evidence.',
       'trace_sha256':sha(folder/'trace.log'),'registration_sha256':sha(folder/'registration.json'),'record_sha256':sha(folder/'record.json')}
with (folder/'audit.json').open('x') as stream:json.dump(audit,stream,indent=2)
print('M08: all four original Gold Joker counters0to1 and RedGold deck0to1; synthetic fixture only')
