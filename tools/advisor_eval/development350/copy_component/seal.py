from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
out=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files=[p for p in out.rglob('*')if p.is_file() and p.name!='component_report.json']
report={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
 'status':'staged_only_parent_review_required','component':'Public known Joker order with concealed playing cards',
 'scope':'Manufactured fixtures and static source inspection only; no recorded policy evaluation, original-source component, searches, attempts, save/profile access, installation or game control.',
 'inputs':{str(p.relative_to(out)):sha(p)for p in sorted(files)},
 'validation':{'candidate':'candidate_05.json','candidate_checks':50,'related':'related_02.json','related_checks':8662,
 'before':'before_01.json','before_pass':False,'candidate_pass':True,'related_pass':True},
 'preserved_failure':'candidate_01.json failed a fixture subset-count arithmetic expectation (218 for eight cards, not 381). No failed runtime outcome is relabeled.',
 'merge_note':'Apply only concealed-hook decision.lua changes to current runtime; preserve root\'s newer shop retirement branch.',
 'limitations':['No terminal result or demonstrated improvement to the logged run.',
 'Fixed incumbent slots across sampled conditioned worlds; bounded canonical order family, not global optimization.',
 'Unsupported paired mechanics decline; future draws and other cashout awards are not forecast.',
 'One score evaluation is conservatively charged for every attempted after_play transition, including early unsupported returns.']}
target=out/'component_report.json'
with target.open('x',encoding='utf-8')as f:f.write(json.dumps(report,indent=2)+'\n')
print(json.dumps({'report':str(target),'sha256':sha(target)}))
