from pathlib import Path
from datetime import datetime,timezone
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];EVAL=ROOT/'tools/advisor_eval';HERE=Path(__file__).parent
def read(p):return json.loads(p.read_text())
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def write(p,text):
 with p.open('x',encoding='utf-8') as f:f.write(text)
folder=HERE/'evidence_release_notes';folder.mkdir(exist_ok=False)
status_path=EVAL/'runs/loss328_validation_20260915/status_evidence330.json';status=read(status_path)
context=read(HERE/'shop_release_notes/context.json')
context.update(release=330,created_at_utc=datetime.now(timezone.utc).isoformat(),
 summary='Replacement advice now forwards its already-computed paired scoring evidence, matching ordinary purchases. The shared shop/pack helper adds no calculation or action. A manufactured transport/parity fixture passes156checks. P02 exposed the prior omission; past receipts remain unchanged and cannot gain the missing endpoint worlds retroactively.',
 outcome_summary='Fresh P01 restores an8-world remaining-blind comparison but keeps the same four-card discard:5/8 modeled clears versus3/8 for play-first;71701 to91318calls. P02 changes cap fallback into affordable Sly-to-Blueprint replacement, ending at43dollars:49956 to40320calls. P03 keeps Perkeo with ordinary and Negative Mercury instead of selling it for Blueprint:16568 to11336calls. All inputs unchanged. P02/P03 omit shop_forecast and remain limited public comparisons. Fresh baseline C01 reproduces Pillar loss592/600 with22resolvedactions and6exact-score checks; no candidate terminal result yet. Historical gold299 outcomes stay separate and CLOSED.',
 budget_summary='Same fresh authority:6public pairs at30s and6complete attempts at180s,1260s total. At this checkpoint P01-P03 and C01 are spent:270s reserved,33.48400000005495s actual. Three public pairs and five complete slots remain,990s unreserved. No search, source-only component or live control. Existing old quotas remain CLOSED.',
 counts=status['counts'],complete_attempt_outcomes=status['complete_attempt_outcomes'],verified_complete_win=False,
 remaining_authority_seconds=status['remaining_authority_seconds'])
context['evidence']['outcomes']=ref(status_path);context['evidence']['budget']=ref(status_path)
context['diagnostic_evidence']={name:ref(path) for name,path in {
 'component':HERE/'replacement_evidence_component/manifest.json','P01':HERE/'P01_audit.json',
 'P02':HERE/'p02_blueprint_audit/audit.json','P03':HERE/'P03_PUBLIC_AUDIT.json',
 'C01':EVAL/'runs/loss328_validation_20260915/C01/audit.json',
 'planet_count_correction':HERE/'MIDRUN_PLANET_ASSESSMENT.md'}.items()}
context['limits_summary']+=' User now requests inference and iterative ordering from actually displayed Joker activations. Detached implementation is in progress; no hidden identity/order joins may stand in for public observation. No such new runtime path is installed by330.'
write(folder/'context.json',json.dumps(context,indent=2)+'\n')
component='''# Replacement evidence preservation —330

`strategy.lua` now returns `scoring_evidence=sale.scoring_evidence` from the shared
shop/revealed-pack replacement advice helper. This forwards the existing paired
endpoint evidence without rescoring, copying it or changing the selected action.
`tests/advisor_replacement_evidence.lua` checks direct and Decision paths,
complete endpoint worlds and inventory, identical old fields/actions/counts,
input immutability and explicit missing evidence (156 manufactured checks).

P02 showed why this is needed: its returned result preserved an advice sentence
and original-row readiness, but omitted the selected replacement's paired endpoint
object. The old P02 result remains as recorded. Future decisions can retain it.
This is evidence transport, not an additional strategic improvement or a rescued
run. Full candidate and exact-installed validation own final counts and hashes.

Evidence: `development328/replacement_evidence_component/manifest.json`,
`runs/evidence330_candidate/validation/report.json`, `evidence330_installed/record.json`,
`evidence330_installed_validation/report.json`, `evidence330_final/final_verification.json`.
The fresh loss batch still compares frozen327/329; installing330 does not replace
those policy bytes or renew any slot. At the330 snapshot P01-P03 and C01 are spent.
C01 is a source-verified loss, not a candidate result. No player win odds follow.

Count correction from exact public data: run4 event3344 holds eight Negative
Venus plus one ordinary Hermit (nine consumables total), not nine Venus plus
Hermit. Earlier wording is historical; the precise correction is in
`development328/MIDRUN_PLANET_ASSESSMENT.md`.

The user additionally requested identifying hidden Jokers through visible
activations and iteratively arranging them. The detached observer/belief work
is in progress. A hidden center key or a stable-ID join across an unseen shuffle
is not public evidence. Existing frozen validation stops at that boundary.
'''
write(EVAL/'REPLACEMENT_EVIDENCE_330.md',component)
write(folder/'priorities.md','''# Remaining work after330

Continue the already-authorized loss328 batch under its one-use ledger; three
public pair slots and five complete attempts remain at this snapshot. Compare
frozen327 and329 on the declared dependent seeds; preserve all outcomes. No search.

Implement the user's public activation inference request: remember only a
public unordered inventory before hiding, constrain possible slot assignments
from actually rendered effects, retain ambiguity, and compare complete supported
ordering choices. No hidden identity/order/ID joins. Detached components under
development328/acorn_public_component and acorn_belief_component are in progress.

Continue useful mixed-inventory Planet and hand/discard development comparisons.
The exact late run4 inventory is8NegativeVenus+1Hermit; consuming Venus alone is
not a rescue when the terminal hand lacks3OAK. Preserve Perkeo/Negative/Observatory,
all current score caps, population and persistent retry/session protections.

No complete candidate improvement has yet been demonstrated. Completionist++,
Jokerless, Knife's Edge and the broader20-challenge objectives remain open.
''')
write(folder/'architecture.md','''# Evidence forwarding architecture —330

`Brainstorm/Advisor/strategy.lua` shared `replacement_sale_advice` now forwards
the selected comparison object. `tests/advisor_replacement_evidence.lua` verifies
shop/pack and Decision transport without changed actions/computation. Existing
logger/archive code retains returned results under its unchanged bounds.

Prior strategic fixes and navigation: `ARCHITECTURE_MAP_329.md`,
`SHOP_COMPARISONS_329.md`, `PURPLE_CONTINUATION_328.md`. Public audits P01/P02/P03,
fresh baseline C01, and status_evidence330.json live under development328 and
runs/loss328_validation_20260915. Original evidence stays immutable.

Detached hidden-order work: observer in acorn_public_component, belief/ordering
in acorn_belief_component. These are not installed by330. The source validation
adapter's identical concealed-Joker stop remains in effect for frozen327/329.
''')
write(folder/'objective.md',(HERE/'shop_release_notes/objective.md').read_text()+
 '\nThe user additionally requests inference from visible Joker effect activations and iterative ordering under hidden-order bosses. Public observations must constrain beliefs; hidden identities/order cannot be used.\n')
print(json.dumps(ref(folder/'context.json')))
