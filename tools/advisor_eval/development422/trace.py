"""Read preserved public events descriptively; never invoke game policy/scoring."""
from pathlib import Path
import json,sqlite3,hashlib,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
CAP=HERE/'captures/001';db=sqlite3.connect((CAP/'events.sqlite3').resolve().as_uri()+'?mode=ro',uri=True)
def event(seq):
 row=db.execute('SELECT data FROM events WHERE seq=?',(seq,)).fetchone();assert row;return json.loads(row[0])
def obs(seq):return event(seq)['context']['snapshot']
def action(seq):return event(seq)['details']['input']['action']
before=obs(153);bones=obs(175);after=obs(200)
assert before['dollars']==9 and before['shop_jokers'][0]['key']=='j_blueprint'
assert before['shop_jokers'][0]['cost']==1 and before['shop_jokers'][0]['ability']['rental']
assert action(159)=={'area':'shop_booster','index':1,'kind':'open'}
assert before['shop_booster'][0]['cost']==4 and bones['dollars']==5
assert action(170)=={'area':'pack_cards','index':2,'kind':'choose'}
assert any(c['key']=='j_mr_bones' for c in bones['jokers'])
assert action(182)=={'area':'shop_jokers','index':2,'kind':'buy'}
assert action(195)=={'area':'shop_jokers','index':1,'kind':'buy'}
assert event(196)['details']['action_sequence']==195
assert 195 in event(199)['details']['action_sequences']
assert after['dollars']==1 and any(c['key']=='j_blueprint' for c in after['jokers'])
rows=[]
for seq in (153,156,159,160,165,166,170,171,175,177,179,182,190,192,195,196,199,200,210,220):
 e=event(seq);s=e.get('context',{}).get('snapshot');a=e.get('context',{}).get('advice')
 r={'sequence':seq,'kind':e['kind'],'observation_id':e.get('observation_id')}
 if s:r.update(phase=s.get('phase'),ante=s.get('ante'),cash=s.get('dollars'),jokers=[c['key'] for c in s.get('jokers',[])])
 if a:r.update(action=a.get('action'),status=a.get('status'),title=a.get('title'),lines=a.get('lines'),timing=a.get('timing'),copy_review=a.get('copy_death_review'))
 if e['kind'] in ('action_requested','action_callback_result','state_after_actions'):r['details']=e.get('details')
 rows.append(r)
db.close()
base=json.loads((EVAL/'SESSION_RESET_421.json').read_text());pre=json.loads((HERE/'prework.json').read_text())
assert policy_hashes(ROOT)==policy_hashes(Path(base['installed']).parent)==base['policy_files']==pre['runtime_files']
assert test_manifest()==pre['test_files'] and provenance()==pre['provenance']
assert file_digest(Path(base['installed'])/'config.lua')==pre['config_sha256']
assert {p.name:file_digest(p) for p in Path(base['installed']).glob('*.dll')}==pre['native_files']
for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
for rel,sha in pre['before_files'].items():assert file_digest(ROOT/rel)==sha and file_digest(HERE/'before'/rel)==sha,rel
record={'revision':422,'scope':'passive_report_verification_no_runtime_change','session':'session-20260927T163146Z-1',
 'loaded_version':'Brainstorm v2.205.0-alpha','capture_events':745,'run_outcome':'unended_at_capture',
 'database_sha256':file_digest(CAP/'events.sqlite3'),'blueprint_acquired':True,'mr_bones_from_paid_pack_free_choice':True,
 'reported_missed_blueprint_demonstrated':False,'user_clarification':'User confirmed current run and acknowledged possible observation mistake.',
 'runtime_digest':base['policy_digest'],'runtime_and_tests_unchanged':True,'native_and_config_preserved':True,
 'game_control':False,'policy_replay':False,'original_game_execution':False,'events':rows}
with (HERE/'TRACE.json').open('x',encoding='utf-8') as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({k:record[k] for k in ('loaded_version','blueprint_acquired','reported_missed_blueprint_demonstrated','runtime_and_tests_unchanged','native_and_config_preserved')}))
