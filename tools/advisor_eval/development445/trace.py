"""Read-only attribution from the already verified copied public archive."""
from pathlib import Path
import json, sqlite3, hashlib
H=Path(__file__).resolve().parent;E=H.parent
C=E/'development443/log_copy/captures/001'
def read(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
summary=read(C/'summary.json'); manifest=read(C/'manifest.json')
assert sha(C/'events.sqlite3')==summary['database_sha256']
assert all(sha(C/'logs'/r['name'])==r['sha256'] for r in manifest['segments'])
db=sqlite3.connect((C/'events.sqlite3').as_uri()+'?mode=ro',uri=True)
def event(seq):
    raw,digest=db.execute('SELECT data,raw_sha FROM events WHERE seq=?',(seq,)).fetchone()
    assert hashlib.sha256(raw.encode()).hexdigest()==digest
    return json.loads(raw)
anchors={str(n):event(n) for n in (3510,3511,3512,3515,3518,3519,3520,3522,
    11140,11142,11144,11145,11146,11150,11151,11152,11153,11154,11155,11158,11159,11160,11162)}
cases=[]
for run,obs,advice,end,stage,cause in (
    (1,3518,3519,3522,'candidate admission',
     'Public 13-card hand exceeds former acorn_ordering 12-card guard. No score comparison ran.'),
    (3,11158,11159,11162,'public state transition',
     'Completed play invalidates retained abilities: canonical Bootstraps lacks a qualified stable play/discard transition.')):
    s=anchors[str(obs)]['context']['snapshot'];b=s['public_joker_belief']
    cases.append({'run':run,'observation':obs,'advice_sequence':advice,'retirement':end,
      'first_demonstrated_stage':stage,'cause':cause,'hand_size':len(s['hand']),
      'remaining_hands':s['hands_left'],'remaining_discards':s['discards_left'],
      'inventory_keys':[j['key'] for j in b['inventory']], 'public_worlds':len(b['worlds']),
      'belief_state_valid':b.get('state_valid',False),'value_gap':b.get('value_gap'),
      'advice':anchors[str(advice)]['context']['advice'],
      'actual_terminal':anchors[str(end)]['details']['actual_terminal'],
      'outcome':anchors[str(end)]['details']['outcome'],
      'captured_policy_execution':False,'counterfactual_game_outcome':'Not evaluated or established'})
record={'source':str(C),'source_database_sha256':summary['database_sha256'],
        'source_manifest_sha256':sha(C/'manifest.json'),'cases':cases,'anchors':anchors}
with (H/'TRACE2.json').open('x') as f: json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({'cases':cases,'raw_anchor_count':len(anchors)}))
