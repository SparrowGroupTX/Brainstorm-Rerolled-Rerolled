"""Prepare/register a fresh evidence-transport comparison on the same public state."""
from pathlib import Path
import json,sys
import validation_cycle as v
HERE=Path(__file__).parent;EVAL=HERE.parent
s=v.read(HERE/'captured_compare/prepared/P02_registration_inputs.json')
s['job']='P04'
s['metadata']['hypothesis']='On the same dependent public shop state, evidence-only330 must preserve the329 action and score-call count while returning the actual selected paired replacement evidence. This is a new one-use follow-up, not a rerun or replacement of P02.'
for role,prefix in (('baseline','shop329'),('candidate','evidence330')):
 folder=EVAL/'runs'/f'{prefix}_installed';r=v.read(folder/'record.json')
 s['files'][role+'_record.json']=str((folder/'record.json').resolve())
 for name in r['policy']['policy_files']:s['files'][role+'/'+name]=str((folder/'policy'/name).resolve())
 s['metadata']['policies'][role]['policy_digest']=r['policy']['policy_digest']
assert (EVAL/'runs/shop329_installed/policy/Brainstorm/Advisor/runtime.lua').read_bytes()==(EVAL/'runs/evidence330_installed/policy/Brainstorm/Advisor/runtime.lua').read_bytes()
path=HERE/'P04_registration_inputs.json';v.create(path,s)
print(v.register(**{k:s[k] for k in ('job','files','command','metadata','external')}))
