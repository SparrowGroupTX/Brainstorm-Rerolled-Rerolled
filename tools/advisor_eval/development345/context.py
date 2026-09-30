"""Close release evidence and prepare navigation, never run experiments."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('x',encoding='utf-8') as f:f.write(v)
ledger=EVAL/'runs/gold345_captured_validation';closed=read(ledger/'CLOSED.json')
assert closed['status']=='CLOSED' and closed['registered_jobs']==4
observations=[]
for job in ('B2070','C2070','B2192','C2192'):
 folder=ledger/job;receipt=read(folder/'launcher_receipt.json')
 summary=read(folder/'summary.json') if (folder/'summary.json').exists() else {}
 observations.append({'job':job,'status':receipt['status'],'policy_status':summary.get('status'),
  'action':summary.get('action'),'score_calls':summary.get('score_calls'),
  'reported_evaluations':summary.get('reported_evaluations'),'input_unchanged':summary.get('input_unchanged'),
  'full_result_status':summary.get('full_result_status'),'input_gaps':summary.get('public_input_gaps'),
  'acquisition':summary.get('gold_acquisition_diagnostics'),'final':summary.get('gold_final_diagnostics'),
  'summary':ref(folder/'summary.json') if summary else None,'receipt':ref(folder/'launcher_receipt.json')})
outcomes={'schema':1,'scope':'Four dependent single-decision evaluations, two recorded public shop pairs. Not complete attempts.',
 'observations':observations,'closure':ref(ledger/'CLOSED.json'),'rescued_run':False,'terminal_evidence':False,
 'qualification':False,'original_input_and_constructor_certificates_unchanged':True}
write(ledger/'outcomes.json',json.dumps(outcomes,indent=2)+'\n')
prior=EVAL/'development344/release_final/context.json'
value={'schema':1,'kind':'checkpoint_experiment_context','status':'CLOSED','release':345,
 'created_at_utc':datetime.now(timezone.utc).isoformat(),'previous_checkpoint_context':ref(prior),
 'summary':'Repair collection admission and retention. Accept the source-native unset pinned field; qualify all22 vanilla Tarot identities when held unused, using public constructor evidence and a broader canonical supported Joker-row roster. Cartomancer is admitted only when its next-blind generation cannot occur because inventory is exactly full with no buffer. The fixed-row acquisition family now covers winning-Ante Small/Big and final Violet Vessel/Verdant Leaf. New bounded retention compares a complete ordinary sale-and-buy sequence against keeping strictly more missing-sticker identities, with four common-world score floors,125% next-blind margin and cash reserves. Protected exits keep the scored current row; phase-copy cannot substitute an unproved reorder. Acquisition, ordinary advice and retention share50000 scores; retention reserves at most8000 within that cap. Current-only compact logs record retention reasons.',
 'outcome_summary':'The passive loaded 2.144 run YVYN2Z11 won Verdant Leaf with 686,952/400,000 chips and $98 but gained zero Gold stickers; progress remained 59/150. It passed missing Loyalty Card before Small and missing Eternal Crafty Joker before Leaf. Cartomancer blocked early collection admission, while unsupported Temperance/Sun/Moon/Wheel/HangedMan inventories and the old final inventory cap were additional blockers. Manufactured production-wired fixtures now demonstrate the supported final-Leaf sale then fresh missing-Joker purchase and retention against an ordinary resale. All four newly authorized recorded public decisions completed with unchanged inputs and full results preserved. Neither paired action changed: both policies open Celestial Pack at 2070 and leave shop at 2192, with zero score calls each. Candidate 2192 passed the newly supported full Cartomancer row and then rejected old unsupported Tarot certificates; candidate 2070 still rejects Cartomancer with one free slot. No counterfactual action improvement or rescued run was demonstrated by these comparisons. No terminal attempt was run; current/projected numerical win odds remain unknown.',
 'limits_summary':'The first-hand comparison is conditional local evidence, not a survival guarantee. Earlier preSmall Cartomancer with one free consumable slot remains unsupported; no random generated Tarot is inferred. Old captured constructors are not retroactively certified. New capture can qualify ordinary/Negative held Tarots under strict constructor and whole-inventory guards, but non-Tarot Perkeo inventories remain outside this added family. Retention covers one declared sale followed by one or two visible Joker buys and may deliberately forgo extra Perkeo copies to keep its proved fixed-row exit. Acquisition still bounds three offers, six owned Jokers,22 endpoints,64 held Tarots and four deterministic public-composition worlds. Final Heart/Acorn collection acquisition, collection-oriented paid rerolls, general earlier-Ante planning and calibrated unseen terminal validation remain unfinished. No verified live2.145 sticker improvement or Jokerless win is claimed.',
 'budget_summary':f"Fresh explicit user authority registered four one-use detached captured policy jobs at30 seconds each,120 seconds reserved. Spent jobs:{closed['spent_jobs']}; processes:{closed['processes_created']}; recorded actual seconds:{closed['actual_seconds_recorded']}; outer outcomes:{closed['outcome_counts']}. Zero original-source components, seed searches or complete attempts. No executable archive, save/profile files or live game control. All four slots and any unused time are permanently CLOSED. Historical loss328 and all earlier allowances remain closed and unchanged.",
 'counts':{'source_components':0,'captured_pair_jobs':2,'captured_policy_evaluations':closed['spent_jobs'],'search_workers':0,'complete_attempts':0},
 'complete_attempt_outcomes':{k:0 for k in ('win','loss','error','timeout','unsupported','censored','running','not_started')},
 'verified_complete_win':False,'unused_capacity':'closed','remaining_authority_seconds':0,
 'evidence':{'authority':ref(ledger/'authority.json'),'outcomes':ref(ledger/'outcomes.json'),
  'budget':ref(ledger/'CLOSED.json'),'limits':ref(ledger/'registration_manifest.json')},
 'historical_closed_context':ref(prior),
 'diagnostic_evidence':{name:ref(HERE/path) for name,path in {
  'integration':'integration.json','root_validation':'root_component/validation_final.json',
  'passive_audit':'log_analysis/passive_audit.json','passive_summary':'log_analysis/summary.json',
  'pin':'pin_component/component_report.json','tarot_scope':'tarot_scope_component/component_report.json',
  'row_scope':'row_component/component_report.json','cartomancer':'cartomancer_component/validation3.json',
  'retention':'retention_component/component_report.json','budget_integration':'retention_component/budget_integration_report.json',
  'retention_runtime':'retention_runtime_component/validation1.json'}.items()}}
out=HERE/'release_context';out.mkdir(exist_ok=False)
write(out/'context.json',json.dumps(value,indent=2)+'\n')
write(out/'priorities.md','''# Priorities after345

Loaded2.144 really won with no new stickers. 345 repairs observed admission
blockers and adds a bounded keep-versus-resale comparison. Do not mistake
manufactured local purchases for measured achievement improvement.

Inspect new passive gold_review acquisition/retention reasons after normal
restart and verify actual newGold awards. All newly authorized four captured
jobs are CLOSED; no new replay/source/search/terminal authority remains.

Concrete unfinished gaps: Cartomancer with free inventory space; final
Heart/Acorn collection acquisition; useful paid collection rerolls; earlier
acquisition/retention; non-Tarot Perkeo inventory and joint exit/pre-hand ordering.
Avoid buying missing cargo only to sell it on a later unsupported policy path.
Use new public constructor observations, never infer missing old certificates.

Broader Jokerless/Knife's Edge survival, Acorn resource planning, calibration and
separately registered unseen terminal validation remain. Historical allowances
stay closed; existing failed evidence and current player settings are preserved.
''')
write(out/'architecture.md','''# Gold collection repair navigation345

- Advisor/gold_tarot_hold.lua: raw nil pin default,22 unused vanilla Tarot
  identities, public constructor guards and canonical supported Joker row names;
  fixed-hold Perkeo score equivalence, no Tarot use or unknown generated value.
- Advisor/gold_goal.lua: state-dependent full-inventory Cartomancer predicate.
- Advisor/gold_acquisition.lua: complete fixed-row missing purchases before
  Small/Big/Vessel/Leaf, exact paid endpoints and common-world floors.
- Advisor/shop_scoring.lua: narrow Cartomancer exception only in fixed-row
  opening context; ordinary startup mechanics stay explicitly unsupported.
- Advisor/gold_retention.lua: keep missing identities versus complete declared
  one-sale/one-or-two-buy incumbent, unchanged inventory/population and cash.
- Advisor/decision.lua and runtime.lua: shared50000 budget, at most8000 reserved
  inside it, actual work charging, fixed-row protected exits, retry guards intact.
- Advisor/player_journal.lua: flat current-only retention diagnostics.
- tests/advisor_gold_{cartomancer,retention,retention_runtime,retention_budget}.lua,
  advisor_gold_tarot_{hold_pin,hold_scope,rows}.lua, acquisition/runtime and
  journal fixtures: manufactured integration with actual production dependencies.
- GOLD_COLLECTION_REPAIR_345.md; development345/*_component: source references,
  exact manifests and preserved failed harnesses; captured_validation adapter
  and runs/gold345_captured_validation: four closed one-use public policy jobs.
- ARCHITECTURE_MAP_344.md: earlier unchanged architecture and component map.

Navigation grants no experiment authority.
''')
write(out/'objective.md','Acquire and retain missing Gold Jokers with supported survival margins; count actual newly awarded stickers separately from run wins and surplus score.\n\n'+(EVAL/'development344/release_context/objective.md').read_text(encoding='utf-8'))
print(json.dumps(ref(out/'context.json')))
