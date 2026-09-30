"""Freeze and document the Eternal collection-slot admission repair."""
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
changed={'Brainstorm/Advisor/'+n+'.lua' for n in ['strategy','runtime','gold_slot','shop_sequences','gold_goal','player_journal']}
summary='Protect collection capacity across ordinary shop/pack choices, replacements and shop sequences: an eligible already-Gold non-Negative Eternal Joker requires a complete exact four-world immediate-survival exception. Missing, sellable and Negative offers retain existing evaluation. Heuristic fallback and unrelated multi-action improvements cannot waive the guard.'
if sys.argv[1]=='prepare':
 prior=read(EVAL/'runs/auto348_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)-set(prior['policy_files'])=={'Brainstorm/Advisor/gold_slot.lua'}
 assert not set(prior['policy_files'])-set(now)
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 r=read(HERE/'root_component/integration_final/report.json')
 assert r['status']=='passed' and r['inputs_unchanged']
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.149.0-alpha')
 out=EVAL/'runs/gold349_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{n:{'before':prior['policy_files'].get(n),'after':sha(ROOT/n)} for n in sorted(changed)},
  'game_control':False,'save_reads':False,'new_experiments':0,'all_experiment_authority':'closed'},indent=2)+'\n')
 print(policy['policy_digest'])
elif sys.argv[1]=='context':
 report=EVAL/'runs/gold349_candidate/validation/report.json';r=read(report)
 assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged']
 prior=EVAL/'development348/release_final/context.json';v=read(prior)
 assert v['status']=='CLOSED' and v['release']==348
 for k in ('release_validation','prepared_context_preserved'):v.pop(k,None)
 v.update(release=349,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
  counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},summary=summary,
  outcome_summary='Passive loaded-2.148 log sequence 85 selected an already-Gold Eternal Droll for $4 at Ante 1; settled observation 88 confirms cash $5 to $1 and Droll held. Recorded opening scores were 137 to 137; no zero whole-blind benefit claim is made. The frozen prefix has no terminal event. User additionally reported completed Eternal Cartomancer and Devious purchases. This repair has manufactured fixture/regression evidence, no fresh terminal result or demonstrated sticker/win-rate improvement.',
  limits_summary='Protect only eligible verified-complete ordinary Eternal acquisitions. A core search preference is not an exemption. Survival exception uses already-paid complete deterministic shared opening evidence and exact single-card endpoint checks, with four 125% clear floors and a failing hold opening. Unknown mechanics or partial evidence do not waive protection. Sale replacements, resource-changing acquisitions and multi-action rescues are conservatively outside the exception. Missing/unknown-status/sellable/Negative offers keep existing evaluation; unknown is not reclassified. No scores added, caps raised, search/native changes or current configuration changes. Whole-inventory and cash guards remain. In-memory search cursor restart repetition remains unresolved. Activation waits for normal user restart.',
  budget_summary='Release 349 used passive read-only observation prefixes, static code review and manufactured fixture/regression validation only. Zero captured policy evaluations, source components, native seed searches or complete attempts. No executable ZIP, saves/profile files, game control or automation. Historical 345 four-call authorization remains CLOSED with 120 seconds reserved and 2.3846720000728965 seconds actual. All older authority remains closed; no quota is renewed.',historical_closed_context=ref(prior))
 refs={'integration':HERE/'integration.json','focused':HERE/'root_component/integration_final/report.json',
  'candidate_validation':report,'passive_report':HERE/'log_analysis/report.json','settled_purchase':HERE/'log_analysis/settled_purchase.json'}
 v['diagnostic_evidence']={n:ref(p) for n,p in refs.items()}
 out=HERE/'release_context';out.mkdir(exist_ok=False)
 write(out/'context.json',json.dumps(v,indent=2)+'\n')
 write(out/'priorities.md','''# Priorities after 349

After normal restart, review passive actions for collection-aware Eternal
admission. Existing held Eternals cannot be sold and are not retroactively
removed. The new guard has no complete-run validation or measured sticker gain.
Strict survival exceptions cover only direct exact supported acquisitions;
unknown startup, multi-action and replacement cases remain conservative.

The fixed opening still requests Yorick + Perkeo, copy by Ante 5 and preferably
Burnt. Missing Auto predicts offers, not affordable acquisition or retention.
Search cursor persistence remains unresolved: development348/cursor_review
documents repeated matches across nearby restarts with mocked callbacks.
Do not rerun native search under closed historical authority.

Preserve 348 log-size and 347 ordering/preflight repairs. Extend supported
whole-inventory comparisons, free-slot Cartomancer, mixed inventory and final
Heart/Acorn acquisition only through complete mechanical comparisons. Joint
resources, Jokerless, Knife's Edge, calibration and separately registered unseen
terminal validation remain. All experimental quotas are closed; new experiments
need fresh concrete authorization. Routine fixtures/read-only analysis remain allowed.
''')
 write(out/'architecture.md','''# Eternal collection-slot navigation 349

- Advisor/gold_slot.lua: pure protected/admit/endpoint policy and strict
  zero-score survival receipt validation; no seed/Joker whitelist.
- Advisor/strategy.lua: direct shop/pack, sale replacements and ratings fallback
  admission; alternatives ranked after filtering and bounded visible diagnostics.
- Advisor/shop_sequences.lua and gold_goal.lua: final endpoint guard leaves
  mechanical transitions and owned-row utility intact.
- Advisor/runtime.lua: shared module wiring and receipt dependencies.
- Advisor/player_journal.lua: bounded scalar protected-offer count/reason.
- tests/advisor_gold_slot*.lua: manufactured receipt and integration coverage.
- development349/log_analysis: frozen public log prefix and exact Droll action
  versus settled purchase observations; no advisor replay.
- ETERNAL_GOLD_SLOTS_349.md: concrete failure, repair, scope and evidence.

ARCHITECTURE_MAP_348.md preserves log projection and earlier source navigation.
No navigation record grants experimental authority.
''')
 write(out/'objective.md',(EVAL/'development348/release_context/objective.md').read_bytes())
 print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
