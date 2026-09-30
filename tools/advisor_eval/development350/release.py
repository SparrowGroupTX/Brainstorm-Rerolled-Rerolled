"""Freeze standalone expired-rental retirement; no experimental execution."""
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
 with p.open('xb')as f:f.write(v if isinstance(v,bytes)else v.encode())
changed={'Brainstorm/Advisor/'+n+'.lua'for n in ['joker_retirement','strategy','runtime','decision']}
summary='Sell a verified already-Gold expired rental without requiring a replacement when its removal preserves the supported active row, physical copy targets, inventory, capacity and resources. Free the ordinary slot, receive exact proceeds and stop future rent before spending the shop scoring budget.'
if sys.argv[1]=='prepare':
 prior=read(EVAL/'runs/gold349_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)-set(prior['policy_files'])=={'Brainstorm/Advisor/joker_retirement.lua'}
 assert not set(prior['policy_files'])-set(now)
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 r=read(HERE/'root_component/retirement_hardened/report.json');assert r['status']=='passed'and r['inputs_unchanged']
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.150.0-alpha')
 out=EVAL/'runs/shop350_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{n:{'before':prior['policy_files'].get(n),'after':sha(ROOT/n)}for n in sorted(changed)},
  'game_control':False,'save_reads':False,'new_experiments':0,'all_experiment_authority':'closed'},indent=2)+'\n')
 print(policy['policy_digest'])
elif sys.argv[1]=='context':
 report=EVAL/'runs/shop350_candidate/validation/report.json';r=read(report)
 assert r['passed']and r['policy_unchanged']and r['tests_unchanged']
 prior=EVAL/'development349/release_final/context.json';v=read(prior);assert v['status']=='CLOSED'and v['release']==349
 for k in ('release_validation','prepared_context_preserved'):v.pop(k,None)
 v.update(release=350,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
  counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},summary=summary,
  outcome_summary='Passive loaded-2.148 RH45AD21 loss: Ante6 Wheel114658/120000,$154,expiredRentalTrio held through three shops. Zero rerolls across171 run requests and653 session requests. Blueprint copied Perkeo through all four concealed Wheel plays. A separate loaded-2.149 prefix confirms M4BVSY11 lost Ante5Pillar36675/50000,$16, and YVYN2Z11 ongoing at the cutoff. These selected logged losses remain distinct; no new evaluation or rescued-run result is claimed. Later user-reported additional losses have not been assigned terminal identities by this release.',
  limits_summary='Retirement is a narrow zero-score structural comparison, not a blanket disabled-card sale. It preserves missing/unknown targets, temporary debuffs, all Eternals, editions, unsupported global-row/sale/startup effects, copy routing, inventory and resource limits. Held Temperance or Fool copying it must keep its full capped value. Known upcoming Leaf/Heart/Acorn rows remain protected. Current Gold slot guard and all score caps remain. Reroll and concealed-copy fixes are staged separately and not part of350. Existing search cursor persistence gap remains. Activation waits for normal restart; no live game is controlled.',
  budget_summary='350 uses passive public-log prefixes, static source review and manufactured fixtures/regressions only. Zero captured policy evaluations, original-source components, native searches or complete attempts. No executable ZIP, save/profile read, live control or automation. Historical345 authorization remains CLOSED at120seconds reserved/2.3846720000728965actual; all old limits remain closed.',historical_closed_context=ref(prior))
 v['diagnostic_evidence']={n:ref(p)for n,p in {'integration':HERE/'integration.json','focused':HERE/'root_component/retirement_hardened/report.json',
  'passive_summary':HERE/'log_analysis/summary.json','candidate':report}.items()}
 out=HERE/'release_context';out.mkdir(exist_ok=False);write(out/'context.json',json.dumps(v,indent=2)+'\n')
 write(out/'priorities.md','''# Priorities after350

The new exact retirement rule addresses the expired completed rental that stayed
through three shops. It has manufactured/regression evidence, no rescued run.
Continue staged350/reroll_component source-backed no-sticker Gold Stake catalog
mass support, then copy_component concealed public-Joker reorder integration.
Neither staged feature is part of350 until separately tested and installed.
Do not treat old loaded2.148 losses as outcomes of350; newer2.149 losses remain
separate. Additional user-reported losses need passive identification if relevant.

General reroll fallback and narrow full-row candidate gates remain restrictive;
removing source-uncertainty guards or merely spending more is not a valid fix.
Shared score budgets, complete worlds and deterministic sampling must remain.
Earlier collection planning, search cursor persistence, Jokerless/Knife's Edge,
calibration and separately authorized unseen terminal validation remain.
All experiment quotas are closed. Routine fixtures/read-only work are authorized.
''')
 write(out/'architecture.md','''# Expired rental retirement350

- Advisor/joker_retirement.lua: pure exact standalone sale admission; supported
  independent active effects, unchanged physical copy targets and whole inventory.
- Advisor/strategy.lua: shop advice can return retirement without an incoming offer.
- Advisor/decision.lua: the same proved disposal runs before the shop scorer.
- Advisor/runtime.lua: shared module wiring.
- tests/advisor_joker_retirement.lua: manufactured disposal, counterexamples,
  actual transition and zero-score decision integration.
- development350/log_analysis: passive losses, expiry/shop timeline, zero rerolls,
  concealed-copy observations; original state bytes and exact receipts preserved.
- EXPIRED_RENTAL_350.md: scope, testing and release evidence.
- development350/reroll_component and copy_component are staged follow-up work,
  not deployed by350; read their exact subsequent release status before use.

Earlier architecture stays in ARCHITECTURE_MAP_349.md and its linked history.
Navigation grants no experimental authority.
''')
 write(out/'objective.md',(EVAL/'development349/release_context/objective.md').read_bytes())
 print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
