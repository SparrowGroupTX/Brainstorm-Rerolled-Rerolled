"""Freeze the pre-copy opaque log projection repair; no experimental workers."""
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
changed={'Brainstorm/Advisor/auto_run.lua','Brainstorm/Core/auto_run_product.lua'}
summary='Project exact internal freshness keys to opaque SHA256/byte-length log records before the controller bounded copier. Keep the full exact keys for action freshness and execution, all existing copy limits and fail-stop behavior, and the same bounded observation events.'
if sys.argv[1]=='prepare':
 prior=read(EVAL/'runs/gold347_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)==set(prior['policy_files'])
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 r=read(HERE/'root_component/integration_final/report.json')
 assert r['status']=='passed' and r['inputs_unchanged']
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.148.0-alpha')
 out=EVAL/'runs/auto348_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{n:{'before':prior['policy_files'][n],'after':sha(ROOT/n)} for n in sorted(changed)},
  'game_control':False,'save_reads':False,'new_experiments':0,'all_experiment_authority':'closed'},indent=2)+'\n')
 print(policy['policy_digest'])
elif sys.argv[1]=='context':
 report=EVAL/'runs/auto348_candidate/validation/report.json';r=read(report)
 assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged']
 prior=EVAL/'development347/release_final/context.json';v=read(prior)
 assert v['status']=='CLOSED' and v['release']==347
 for k in ('release_validation','prepared_context_preserved'):v.pop(k,None)
 v.update(release=348,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
  counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},summary=summary,
  outcome_summary='Latest frozen passive prefix confirms loaded 2.147. At 2026-09-16T06:10:58Z, sequence 1854, the second run YVYN2Z11 stopped unfinished at Ante 6 round 16 in a Jumbo Celestial Pack, with $58 and advice to choose Black Hole. Stop reason log_unavailable; detail Controller data must be plain finite values. The previous accepted fingerprint was 258,571 bytes, near the 262,144 string limit. Source control flow and manufactured reproduction identify the pre-hash copy limit as the failure; the precise rejected runtime key length is not logged. The session records one earlier loss and no wins; the stopped run is not imputed as a loss. It held six already-Gold Jokers, including Eternal Cartomancer and Devious Joker; collection counts were 59 complete and 91 missing. No fresh terminal validation or new Gold award is demonstrated by this repair.',
  limits_summary='The repair moves the existing opaque log projection before the unchanged strict copier. Exact internal keys, action-token binding, execution checks, logging rejection stops, retry/session limits and score budgets stay unchanged. Hash failure still records bounded unavailable metadata without a raw-key fallback. Fixed Yorick/Perkeo/copy/Burnt search preferences, the in-memory-only seed cursor and early generic Eternal buying remain separate unresolved collection-planning gaps; this release does not change search, native DLLs, strategy weights or current configuration. Activation waits for normal user restart. The old stopped controller is not retroactively resumed by installation.',
  budget_summary='Release 348 used passive read-only observation prefixes, static code review and manufactured fixture/regression validation only. Zero captured policy evaluations, source components, native seed searches or complete attempts. Mock search callbacks in cursor/controller fixtures launch no real worker and are not search experiments. No executable ZIP, saves/profile files, game control or automation. The historical 345 four-call authorization remains CLOSED with 120 seconds reserved and 2.3846720000728965 seconds actual; all older authority remains closed and no quota is renewed.',
  historical_closed_context=ref(prior))
 refs={'integration':HERE/'integration.json','focused':HERE/'root_component/integration_final/report.json',
  'before':HERE/'root_component/before348/report.json','candidate_validation':report,
  'passive_summary':HERE/'log_analysis/summary.json','cursor_review':HERE/'cursor_review/README.md'}
 supplement=HERE/'log_analysis/supplemental.json'
 if supplement.exists():refs['supplemental_passive']=supplement
 v['diagnostic_evidence']={n:ref(p) for n,p in refs.items()}
 out=HERE/'release_context';out.mkdir(exist_ok=False)
 write(out/'context.json',json.dumps(v,indent=2)+'\n')
 write(out/'priorities.md','''# Priorities after 348

After normal restart, check passive observation for large inventory/pack
transitions without the former pre-hash string rejection. Installation does
not resume the previously fault-stopped controller. No live recovery is proved.

The user questioned repeated completed Eternal purchases. Confirmed gap:
strategy.card_value uses a generic Eternal penalty but ordinary early buys and
pack selections do not integrate Gold status or the cost of a permanently lost
collection slot. Later guarded acquisition/retention cannot sell an Eternal.
Design bounded whole-build collection-capacity comparisons with survival and
cash, not a blanket ban on completed support Jokers or a renamed heuristic.

The fixed opening still requests Yorick + Perkeo, copy by Ante 5 and preferably
Burnt. Missing Auto adds one conditional missing offer in the chosen window;
the observed setting counted Antes 5–8. Offers do not prove purchases/retention.
The first Legendary adapts only when the fixed route has no reachable target.

The search cursor is memory-only and restarts from wall time. Mocked facade
fixtures demonstrate repeated distant matches across nearby restarts while
same-boot match+1 advancement is correct. Persist validated deterministic
continuity, without replaying old search authority or resetting on profile or
query changes; assess durable reservation/accepted receipt ordering first.
See development348/cursor_review/README.md. No persistence fix was installed.

Preserve 347 ordering/preflight and 346 constructor improvements. Remaining
work from NEXT_PRIORITIES_347.md includes free-slot Cartomancer, mixed inventory,
final Heart/Acorn acquisition, earlier collection planning and joint resources.
Jokerless, Knife's Edge, calibration and unseen terminal validation remain.
All experimental quotas are closed; new experiments require fresh concrete
prospective authorization. Routine fixtures and read-only analysis remain allowed.
''')
 write(out/'architecture.md','''# Auto-run logging boundary navigation 348

- Advisor/auto_run.lua: optional trusted project_log callback runs before the
  existing bounded plain-data clone; exact pending keys remain internal.
- Core/auto_run_product.lua: existing SHA256/length projection supplied at that
  boundary; separate journal writer prevents double hashing. Explicit product
  start/resume/terminal event paths keep the same projection wrapper.
- tests/advisor_auto_run_product.lua: manufactured growing identity crosses
  256 KiB at pack observation; next action, opaque logs, exact freshness and
  interrupted checkpoint identity remain correct.
- tests/advisor_auto_log_projection.lua: projection failure, malformed/large
  output, journal failure and unchanged consumed-action protections.
- development348/log_analysis: frozen passive prefixes, original near-stop
  events, compact summary and supplementary seed/purchase observations.
- development348/cursor_review: read-only cursor analysis and mock-only
  restart continuity reproduction; no persistence implementation.
- AUTO_LOG_PROJECTION_348.md: causal audit and release limits.
- ARCHITECTURE_MAP_347.md: unchanged ordering/acquisition/retention and scalar
  Gold-review logging navigation, linked onward to prior mechanics.

Navigation grants no experiment authority.
''')
 write(out/'objective.md',(EVAL/'development347/release_context/objective.md').read_bytes())
 print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
