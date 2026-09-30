"""Freeze/document bounded physical shop ordering. No experimental execution."""
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
changed={'Brainstorm/Advisor/'+n+'.lua' for n in ('gold_acquisition','gold_retention','gold_order','shop_scoring','runtime','decision','player_journal')}
added={'Brainstorm/Advisor/gold_order.lua'}
summary='Compare bounded physical copy-target shop rows before buying or retaining a missing Gold Joker. Deliver any required reorder as an actual first action, then refresh before paid actions or leaving. Preflight the complete fixed-row score cost before scoring; use the smaller current-row family only when the expanded family does not fit, before observing any scores. Log bounded scalar ordering and preflight diagnostics without projected states, candidate arrays or extra events.'
if sys.argv[1]=='prepare':
 prior=read(EVAL/'runs/gold346_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)==set(prior['policy_files'])|added
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 r=read(HERE/'root_component/integration_final2/report.json')
 assert r['status']=='passed' and r['inputs_unchanged']
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.147.0-alpha')
 out=EVAL/'runs/gold347_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{n:{'before':prior['policy_files'].get(n),'after':sha(ROOT/n)} for n in sorted(changed)},
  'game_control':False,'save_reads':False,'new_experiments':0,'all_experiment_authority':'closed'},indent=2)+'\n')
 print(policy['policy_digest'])
elif sys.argv[1]=='context':
 report=EVAL/'runs/gold347_candidate/validation/report.json';r=read(report)
 assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged']
 prior=EVAL/'development346/release_final/context.json';v=read(prior)
 assert v['status']=='CLOSED' and v['release']==346
 for k in ('release_validation','prepared_context_preserved'):v.pop(k,None)
 v.update(release=347,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
  counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},summary=summary,
  outcome_summary='The last audited loaded 2.145 run won Verdant Leaf with 686,952/400,000 chips, $98 and zero new Gold stickers; collection progress remained 59/150. Its shop row copied Perkeo while its later hand row copied Caino. This is read-only motivation, not an alternate purchase score or rescue. Release347 uses manufactured public-state fixtures: actual reorder then refreshed sale/buy adds a missing Joker where the fixed original row fails the sampled opening margin; a retention fixture reorders then leaves with the missing Joker. These are local implementation checks, not live awards, complete attempts or win-rate evidence. No new captured policy comparison, search, source component or terminal experiment ran. Numerical win odds and achievement-time improvement remain unknown.',
  limits_summary='The family is current row plus one canonical compatible-copy-count maximizer per active already-owned physical non-copy target: at most6 rows and720 legal permutations, without scoring during enumeration. It is not every scoring arrangement. Only real pre-purchase reorders are used; paid transitions append/remove physical cards exactly. All original consumables remain unused, Perkeo copies are counted for each resulting row, unknown mechanics stay unsupported, and the winning-Ante Small/Big/Vessel/Leaf scope and125% margin across4 public composition samples are unchanged. These samples do not guarantee clears. Shop50000 and retention8000 score limits are unchanged. Free-slot Cartomancer, mixed Tarot/Planet copying, final Heart/Acorn acquisition, collection rerolls, earlier-Ante acquisition and joint later-hand resource planning remain unfinished. Activation waits for normal user restart.',
  budget_summary='Release347 used manufactured fixtures and ordinary regressions only, plus read-only inspection of preserved code/evidence. Zero new captured policy evaluations, source components, seed searches or complete attempts; no executable archive, save/profile reads, game control or automation. The separately authorized345 four-job cycle remains CLOSED:120 seconds reserved,2.3846720000728965 seconds actual, four completed calls with unchanged paired actions and unsupported collection diagnostics. Historical counts and receipts remain preserved; no unused quota is renewed.',
  historical_closed_context=ref(prior))
 refs={'integration':HERE/'integration.json','focused':HERE/'root_component/integration_final2/report.json',
  'candidate_validation':report,'order_component':HERE/'order_component/README.md',
  'preflight_component':HERE/'preflight_component/validation_02.json',
  'journal_component':HERE/'journal_component/README.md',
  'retention_component':HERE/'retention_component/component_report.json',
  'passive_motivation':EVAL/'development346/log_analysis/ordering_timeline.json'}
 v['diagnostic_evidence']={n:ref(p) for n,p in refs.items()}
 out=HERE/'release_context';out.mkdir(exist_ok=False)
 write(out/'context.json',json.dumps(v,indent=2)+'\n')
 write(out/'priorities.md','''# Priorities after347

After normal restart, inspect new passive gold_review diagnostics and actual
eligible newGold awards. Local ordering and constructor tests do not establish
live sticker progress. All experimental quotas remain closed.

347 closes a bounded part of the shop-order gap: it can actually reorder before
buying or retaining a missing Joker, then refresh advice. Canonical target rows
are stable across refresh. It does not enumerate every scoring row, optimize an
exit-copy row jointly with a later pre-hand reorder, or use future consumables.

Remaining strategic gaps: free-slot Cartomancer with explicit public catalog
closure; qualified mixed Tarot/Planet inventory including Observatory; final
Heart/Acorn acquisition; useful collection rerolls and earlier acquisitions;
joint hands/discards/owned-consumable planning. Preserve complete comparisons
and budget bounds instead of forcing a buy.

Remaining computation opportunities from static review: repeated immutable
profile preparation, repeated whole-inventory certification, and duplicate
fixed-hold scoring across acquisition and retention. Full-profile sharing needs
identical root-world keys, floor/order contracts and one cumulative allowance;
ordinary mean scores cannot replace reliable floors. No pointer-only cache.

Jokerless, Knife's Edge, calibration and unseen terminal validation remain.
Fresh experiments require explicit concrete prospective authorization.
''')
 write(out/'architecture.md','''# Physical shop ordering navigation347

- Advisor/gold_order.lua: pure<=720 legal physical permutations,<=6 canonical
  current/copy-target rows; stable-ID ties, pinned/visibility/copy-cycle guards,
  detached actual reorder projection and stale-receipt rejection.
- Advisor/gold_acquisition.lua: exact reorder/sale/buy projection, whole-family
  preflight and current-row budget fallback before scoring; actual reorder as
  first action with fresh advice before any paid continuation.
- Advisor/gold_retention.lua: complete paid incumbent versus current/canonical
  held rows; zero-action current hold first, actual reorder otherwise.
- Advisor/shop_scoring.lua: context:preflight_family exact prepared-key cost,
  up to128states, successful cache reuse and explicit failed-cache rejection.
- Advisor/runtime.lua and decision.lua: dependency wiring and protection of
  qualified retained reorder/exit from unrelated phase-copy postprocessing.
- Advisor/player_journal.lua and tests/advisor_gold_journal.lua: bounded flat
  row counts, actual arrangement count, complete cost and fallback diagnostics;
  candidate arrays and receipts stay outside observation events.
- tests/advisor_gold_order.lua, advisor_shop_family_preflight.lua,
  advisor_gold_acquisition_order.lua, advisor_gold_retention_order.lua and
  advisor_gold_retention_order_runtime.lua: manufactured mechanics/accounting
  and actual Decision integration; no captured player replay.
- development347/{order_component,preflight_component,retention_component,
  root_component}: staged changes, immutable receipts and preserved failures.
- GOLD_SHOP_ORDER_347.md: scope, evidence and exact release limitations.
- ARCHITECTURE_MAP_346.md: constructor validation/source-shaped inventory
  navigation; prior architecture maps remain available through it.

Navigation is not experimental authority.
''')
 write(out/'objective.md',(EVAL/'development346/release_context/objective.md').read_bytes())
 print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
