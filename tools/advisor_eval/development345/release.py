"""Freeze reviewed 345 repair; does not start experiments."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version,VERSION_FIELDS
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('xb') as f:f.write(v if isinstance(v,bytes) else v.encode())
changed={'Brainstorm/Advisor/'+n+'.lua' for n in ('decision','runtime','player_journal','gold_goal','gold_acquisition','gold_tarot_hold','shop_scoring')}
added={'Brainstorm/Advisor/gold_retention.lua'}
if sys.argv[1]=='prepare':
 prior=read(EVAL/'runs/gold344_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)==set(prior['policy_files'])|added
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 assert read(HERE/'root_component/validation_final.json')['exit_code']==0
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.145.0-alpha')
 out=EVAL/'runs/gold345_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(out/'record.json',json.dumps({'schema':1,'kind':'frozen_candidate','policy':policy},indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{n:{'before':prior['policy_files'].get(n),'after':sha(ROOT/n)} for n in sorted(changed|added)},
  'game_control':False,'save_reads':False,'captured_authority':'Four one-use 30-second decisions; no jobs started by this script'},indent=2)+'\n')
 print(policy['policy_digest'])
else:raise SystemExit('Expected prepare')
