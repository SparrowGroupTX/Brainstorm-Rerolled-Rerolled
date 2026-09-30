"""Freeze and document the source-shaped constructor repair. No experiment execution."""
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
changed={'Brainstorm/Advisor/gold_tarot_hold.lua','Brainstorm/Advisor/perkeo_inventory.lua'}
if sys.argv[1]=='prepare':
 prior=read(EVAL/'runs/gold345_installed/record.json')['policy'];now=policy_hashes(ROOT)
 assert set(now)==set(prior['policy_files'])
 for name,h in prior['policy_files'].items():
  if name not in changed:assert now[name]==h,name
 assert read(HERE/'root_component/after346/report.json')['status']=='passed'
 for name in VERSION_FIELDS:
  p=ROOT/'Brainstorm'/name;write(HERE/'before'/'Brainstorm'/name,p.read_bytes());stamp_version(p,name,'2.146.0-alpha')
 out=EVAL/'runs/gold346_candidate';out.mkdir(exist_ok=False)
 policy=freeze_product(ROOT,out/'policy');write(out/'freeze.json',json.dumps(policy,indent=2)+'\n')
 write(HERE/'integration.json',json.dumps({'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
  'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
  'changed_runtime':{n:{'before':prior['policy_files'][n],'after':sha(ROOT/n)} for n in sorted(changed)},
  'game_control':False,'save_reads':False,'new_experiments':0,'all_experiment_authority':'closed'},indent=2)+'\n')
 print(policy['policy_digest'])
elif sys.argv[1]=='context':
 report=EVAL/'runs/gold346_candidate/validation/report.json';r=read(report)
 assert r['passed'] and r['policy_unchanged'] and r['tests_unchanged']
 prior=EVAL/'development345/release_final/context.json';v=read(prior)
 assert v['status']=='CLOSED' and v['release']==345
 for k in ('release_validation','prepared_context_preserved'):v.pop(k,None)
 v.update(release=346,created_at_utc=datetime.now(timezone.utc).isoformat(),previous_checkpoint_context=ref(prior),
  counts_scope='historical_closed_cycle',release_counts={k:0 for k in v['counts']},
  summary='Accept the source-native cosmetic bypass_back sprite coordinates and Boolean viewed_back selector in ordinary Tarot and Planet copy-constructor parameters. Preserve the complete parameter table in certificates, with strict plain finite nonnegative integer x/y shape and no additional back-position fields. Keep unknown constructor fields and physical playing-card identities unsupported. Tarot capture now reports the specific failing validation stage. Update the shared manufactured Tarot factory to include native discovery flags and selected-back coordinates, so production acquisition, Cartomancer and retention fixtures exercise the actual constructor shape. No strategy thresholds, world families, score caps or native DLLs changed.',
  outcome_summary='The latest passive session confirms loaded 2.145 and another real Verdant Leaf win on YVYN2Z11: 686,952/400,000 chips, $98, five already-Gold Jokers at the finish, zero new stickers, and 59/150 unchanged. All newly logged Tarot certificates were unsupported, including every one of the 26 final-shop Tarots. Preserved source shows create_card always supplies bypass_back and copy_card retains it, while both constructor validators wrongly rejected that key. Raw params were not present in failed snapshots, so the exact rejected raw field is source-derived rather than directly observed. With a source-shaped manufactured factory, all three prior production-wired acquisition/Cartomancer/retention fixtures fail against 2.145 and pass after the repair. This proves the constructor and local policy integration repair, not that the observed run would acquire or retain a new sticker. No fresh captured comparison or terminal experiment was run; live benefit and numerical odds remain unknown.',
  limits_summary='Activation waits for normal user restart. This slice removes an invalid constructor rejection and improves failure diagnostics; it does not remove the existing full-inventory-only Cartomancer restriction, supported-boss restrictions, complete common-world comparisons, whole-inventory guards or 125% sampled opening threshold. Acquisition remains bounded to the documented winning-Ante Small/Big/Vessel/Leaf family. Free-slot Cartomancer, final Heart/Acorn acquisition, joint exit and later scoring arrangements, collection rerolls and broader earlier-Ante planning remain unfinished. Passing source-shaped fixtures does not qualify arbitrary mod callbacks or demonstrate a terminal rescue or new Gold award.',
  budget_summary='Release 346 used passive read-only logs, already-preserved mechanic source and manufactured fixture/regression validation only. Zero new captured policy evaluations, source components, seed searches or complete attempts. No executable archive, save/profile files, game control or automation. The separately authorized 345 four-job cycle remains CLOSED: 120 seconds reserved, 2.3846720000728965 seconds actual, four completed calls with unchanged paired actions and unsupported collection diagnostics. All older allowances remain closed; no unused capacity was renewed.',
  historical_closed_context=ref(prior))
 refs={'integration':HERE/'integration.json','before_regression':HERE/'root_component/before345/report.json',
  'after_regression':HERE/'root_component/after346/report.json','candidate_validation':report,
  'passive_summary':HERE/'log_analysis/summary.json','public_failure_fields':HERE/'log_analysis/public_failure_fields.json',
  'certificate_census':HERE/'log_analysis/certificate_census.json','ordering_timeline':HERE/'log_analysis/ordering_timeline.json',
  'constructor_component':HERE/'constructor_component/component_report.json'}
 for p in (HERE/'shape_audit').glob('*.json'):refs['shape_'+p.stem]=p
 v['diagnostic_evidence']={n:ref(p) for n,p in refs.items()}
 out=HERE/'release_context';out.mkdir(exist_ok=False)
 write(out/'context.json',json.dumps(v,indent=2)+'\n')
 write(out/'priorities.md','''# Priorities after 346

Loaded 2.145 again won with zero new Gold stickers. 346 fixes the source-native
deck-back parameter rejected by both Tarot and Planet copy-constructor guards.
The shared fixtures now include this ordinary source field; the earlier
three production-wired failures and repaired passes are preserved.

After normal restart, inspect new passive constructor-stage and gold_review
diagnostics and actual newGold awards. Do not treat certificate admission or a
local fixture purchase as verified achievement progress. All experiment
allowances remain closed, including the four calls from 345.

Remaining concrete gaps: Cartomancer with free inventory space, final
Heart/Acorn acquisition, complete exit/pre-hand ordering policies, worthwhile
collection rerolls, and earlier acquisition/retention. Preserve complete
common-world comparisons and explicit uncertainty instead of forcing a buy.

The latest observed final shop row points Brainstorm at Perkeo; the actual
first-hand reorder instead points it at Caino. Subsequent discards, Sun and a
Leaf-disabling sale also intervene before the winning Flush House. A current-row
opening floor therefore omits actions the actual winning continuation used.
Do not impute an alternate purchase score or terminal rescue from that fact.

Static follow-ups: a free-slot Cartomancer hold floor needs an explicit public
Tarot catalog-closure proof; mixed Tarot/Planet inventory needs original
Observatory preservation and explicit bounds for unknown copies. Mechanically
unsupported endpoints could be excluded from a declared family before scoring,
without letting partial scoring select a winner. These are not implemented.

Jokerless, Knife's Edge, calibration and unseen terminal validation remain.
''')
 write(out/'architecture.md','''# Constructor repair navigation 346

- Advisor/gold_tarot_hold.lua: accept a plain cosmetic selected-back position
  in copied constructor params; separate failure-stage reasons; all prior
  visibility, identity, physical, edition, inventory and copy guards remain.
- Advisor/perkeo_inventory.lua: the same cosmetic-back parameter support for
  qualified homogeneous Planet copying; all prior scope and capacity guards.
- tests/fixtures/gold_tarot_hold_support.lua: native create_card parameter
  shape, used by production acquisition/Cartomancer/retention tests.
- development346/constructor_component: source references, before/after
  files, manufactured constructor tests and immutable component receipt.
- development346/shape_audit and log_analysis: read-only public-field census;
  raw params are not logged, so source attribution remains explicit.
- GOLD_CONSTRUCTOR_REPAIR_346.md: current causal audit, repair and evidence.
- ARCHITECTURE_MAP_345.md: unchanged acquisition, retention, budget and phase
  copying behavior; earlier component navigation remains preserved.

Navigation grants no experiment authority.
''')
 write(out/'objective.md','''Minimize real time to earn the remaining Gold Joker stickers and finish all
twenty challenges, including retries, search, computation and user actions.
Prioritize actual missing-sticker acquisition and retention over excess score;
count new eligible Gold awards separately from run wins. Preserve public-state
legality, complete bounded comparisons, deterministic sampling, cash reserves,
population/Glass, Blue generation, Perkeo/Negative/Observatory inventory and the
persistent checkpoint retry cap. Jokerless and Knife's Edge remain unfinished.
Local fixes and fixtures do not establish win odds, achievement completion,
global optimality or superiority over a good human player.
''')
 print(json.dumps(ref(out/'context.json')))
else:raise SystemExit('Expected prepare or context')
