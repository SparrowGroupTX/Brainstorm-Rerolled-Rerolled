"""Freeze one explicitly configured follow-up slice and preserve closed authority."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,sys
EVAL=Path(__file__).resolve().parent.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version,VERSION_FIELDS
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('xb')as f:f.write(v if isinstance(v,bytes)else v.encode())
cfg=Path(sys.argv[1]).resolve();c=read(cfg);HERE=cfg.parent;n=c['release'];version=f'2.{n-200}.0-alpha'
changed=set(c['changed']);prefix=c['prefix'];previous=c['previous'];pp=c['previous_prefix']
if sys.argv[2]=='prepare':
 prior=read(EVAL/f'runs/{pp}_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)-set(prior['policy_files'])==set(c.get('new',[]))
 assert not set(prior['policy_files'])-set(now)
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 r=read(EVAL/c['focused']);assert r['status']=='passed'and r['inputs_unchanged']
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,version)
 out=EVAL/f'runs/{prefix}_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{p:{'before':prior['policy_files'].get(p),'after':sha(ROOT/p)}for p in sorted(changed)},
  'config':ref(cfg),'game_control':False,'save_reads':False,'new_experiments':0,'all_experiment_authority':'closed'},indent=2)+'\n')
 print(policy['policy_digest'])
elif sys.argv[2]=='context':
 report=EVAL/f'runs/{prefix}_candidate/validation/report.json';r=read(report)
 assert r['passed']and r['policy_unchanged']and r['tests_unchanged']
 prior=EVAL/f'development{previous}/release_final/context.json';v=read(prior)
 assert v['status']=='CLOSED'and v['release']==previous
 for k in ('release_validation','prepared_context_preserved'):v.pop(k,None)
 v.update(release=n,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
  counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},summary=c['summary'],
  outcome_summary=c['outcomes'],limits_summary=c['limits'],historical_closed_context=ref(prior),
  budget_summary=f'{n} used static read-only preserved source/log analysis and manufactured fixture/regression validation only. Zero captured policy evaluations, original-source execution, native search workers or complete attempts. No executable ZIP, saves/profiles, game control or automation. Historical345 authorization remains CLOSED at120seconds reserved/2.3846720000728965actual; no old quota renewed.')
 refs={'integration':HERE/'integration.json','focused':EVAL/c['focused'],'candidate':report,'config':cfg}
 refs.update({k:EVAL/p for k,p in c.get('evidence',{}).items()})
 v['diagnostic_evidence']={k:ref(p)for k,p in refs.items()}
 out=HERE/'release_context';out.mkdir(exist_ok=False);write(out/'context.json',json.dumps(v,indent=2)+'\n')
 for key in ('priorities','architecture'):write(out/(key+'.md'),c[key]+'\n')
 write(out/'objective.md',(EVAL/f'development{previous}/release_context/objective.md').read_bytes())
 print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
