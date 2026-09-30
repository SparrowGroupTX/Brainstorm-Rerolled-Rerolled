"""Read already-audited C01 trace; no policy/source/game execution."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[5]
HERE=Path(__file__).resolve().parent
folder=ROOT/'tools/advisor_eval/runs/gold299_20260914/C01'
raw=(folder/'trace.log').read_bytes()
digest=hashlib.sha256(raw).hexdigest()
record=json.loads((folder/'record.json').read_text())
assert record['trace_sha256']==digest
rows=[json.loads(line) for line in raw.decode().splitlines() if line.startswith('{')]
starts={r['step']:r for r in rows if r['type']=='engine_episode_decision_started'}
actions={r['step']:r for r in rows if r['type']=='engine_episode_action'}
exits=[]
for step,row in actions.items():
    s=starts[step]['snapshot']
    if row['action']['kind']!='leave_shop' or s.get('consumeables') or not any(c['key']=='j_perkeo' for c in s['jokers']):continue
    after=starts[step+1]['snapshot']
    assert not after.get('consumeables')
    exits.append({'step':step,'ante':s['ante'],'round':s['round'],'owned_jokers':[
        {'key':c['key'],'id':c['id'],'debuff':c.get('debuff'),
         'perishable':c.get('ability',{}).get('perishable'),
         'perish_tally':c.get('ability',{}).get('perish_tally')}
        for c in s['jokers']],
        'before_count':0,'after_count':0,'capacity_before':s['consumable_limit'],
        'capacity_after':after['consumable_limit'],
        'before_state_fingerprint':starts[step]['state_fingerprint'],
        'next_state_fingerprint':starts[step+1]['state_fingerprint']})
result={'schema':1,'kind':'read_only_preserved_trace_observations','source':str(folder.relative_to(ROOT)).replace('\\','/'),
        'trace_sha256':digest,'policy':'installed300','seed':'M4BVSY11',
        'experiments_executed':0,'observations':exits,
        'limit':'Selected synthetic development observations support zero generation at these empty exits. They do not qualify all source mechanics or the new policy.'}
with (HERE/'c01_empty_exit_observations.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
print('Read-only verified empty Perkeo exits:',len(exits))
