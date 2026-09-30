"""Prepare immutable notes for the tested nine-card repair; no experiment execution."""
from pathlib import Path
from datetime import datetime, timezone
import json, hashlib
ROOT=Path(__file__).resolve().parents[3]; EVAL=ROOT/'tools/advisor_eval'; HERE=Path(__file__).parent
def read(p): return json.loads(p.read_text())
def ref(p): return {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def write(p,s):
    with p.open('x',encoding='utf-8') as f: f.write(s)
folder=HERE/'nine_release_notes'; folder.mkdir(exist_ok=True)
assert not any(folder.iterdir()), 'Preserve any previously prepared files'
status_path=EVAL/'runs/loss328_validation_20260915/status_nine331.json'; status=read(status_path)
context=read(HERE/'evidence_release_notes/context.json')
context.update(release=331,created_at_utc=datetime.now(timezone.utc).isoformat(),
 summary='Admit nine-card concealed hands within the unchanged 8000-score budget. Certificate produced nine cards in C02 and the former eight-card admission guard stopped before any comparison. All 381 legal subsets across 16 fixed worlds cost6096 calls; aggregate continuation caps remain enforced. No seed or challenge-name recommendation is introduced.',
 outcome_summary='P01-P04 are complete with unchanged inputs. P04 retains the same Sly-to-Blueprint action and40320 calls while now returning complete endpoint evidence. C01/C03 reproduce the Pillar592/600 and Ante5Big18340/37500 losses. C02 clears Pillar616/600 but ends ERROR at a nine-card House hand. C04 passes the prior Ante5Big loss115080/37500 and reaches Ante6 before TIMEOUT. C06 stops UNSUPPORTED before the first concealed Joker decision at Ante8 Acorn. No fresh complete win. C05 is a prospective331 follow-up to the already-spent C02; the original unregistered YAE baseline preparation remains preserved.',
 budget_summary='Original fresh authority is unchanged:6public pairs at30s and6source attempts at180s,1260s total. P01-P04 and C01-C04/C06 are spent and reaped:1020s reserved,605.0300000000279s actual. P05/P06/C05 remain unregistered,240s capacity. No seed search or live control; historical quotas remain CLOSED.',
 counts=status['counts'],complete_attempt_outcomes=status['complete_attempt_outcomes'],verified_complete_win=False,
 remaining_authority_seconds=status['remaining_authority_seconds'])
context['evidence']['outcomes']=ref(status_path); context['evidence']['budget']=ref(status_path)
context['limits_summary']='Selected dependent synthetic-profile attempts are development evidence, not a representative player cohort or unseen holdouts. Preserve exact losses, error, timeout and unsupported outcomes; neither incidental won fields nor intermediate clears prove a terminal win. No verified Jokerless win, numerical player odds, per-challenge50/75percent targets, achievement completion or human superiority. No saves/profile reads for evaluation, search, game control, native changes, training or automation. Current settings, score caps, population, inventory and persistent retry protections remain. Acorn observation/planning is reviewed but remains detached at331. Source attempts retain the same hidden-Joker stop; no private center/ID join may substitute for public activation evidence.'
context['diagnostic_evidence'].update({name:ref(path) for name,path in {
 'nine_component':HERE/'nine_card_component/manifest.json',
 'P04':EVAL/'runs/loss328_validation_20260915/P04/audit.json',
 'C01_C02':EVAL/'runs/loss328_validation_20260915/paired_C01_C02_audit_v2.json',
 'C03_C04':EVAL/'runs/loss328_validation_20260915/paired_C03_C04_audit.json',
 'C03_C04_scaling':EVAL/'runs/loss328_validation_20260915/paired_C03_C04_scaling_details.json',
 'C06':EVAL/'runs/loss328_validation_20260915/C06/audit.json',
 'followup_plan':HERE/'followup_plan_after_C04.json',
 'acorn_review':HERE/'ACORN_INTEGRATION_REVIEW.json'}.items()})
write(folder/'context.json',json.dumps(context,indent=2)+'\n')
write(EVAL/'CONCEALED_NINE_CARDS_331.md','''# Nine-card concealed planning —331

The selected candidate C02 cleared the original Pillar loss616/600 and Ante2
Small/Big, then returned no action at the House. Certificate had made a nine-card
hand; the concealed planner rejected it above eight before checking compute.
This is an ERROR, not a loss or completed win. Original evidence is preserved.

`Brainstorm/Advisor/concealed_belief.lua` now admits at most nine cards in its
immediate and future concealed-hand paths. The existing8000 total score-call cap
is unchanged. Nine cards have381 legal1–5-card subsets;16 fixed worlds require6096
calls. Incomplete continuation work never replaces a complete immediate result.
More than nine cards or an oversized world family remains explicitly unsupported.
Forced selections and population/Glass/resource safeguards are unchanged.

`tests/advisor_concealed_nine_card.lua` checks complete381-subset admission,
unchanged inputs/latent identity invariance, forced selection, aggregate budget
exhaustion and preserved unsupported cases. The detached component has7584 new
checks plus894 existing concealed checks. Full candidate and exact-installed
regression records own final totals; no fixture is a source terminal attempt.

Evidence: `development328/nine_card_component/manifest.json`,
`runs/nine331_candidate/validation/report.json`, `nine331_installed/record.json`,
`nine331_installed_validation/report.json`, `nine331_final/final_verification.json`.
Fresh C05 is planned to retest this precise stoppage on S7PXV521 using exact331;
it is a dependent follow-up to C02, not a renewed baseline or unseen holdout.

Other fresh results: C03 reproduced Ante5Big18340/37500. C04 bought Blueprint,
used eight Negative Venus and passed that blind115080/37500, reaching Ante6 before
its180-second TIMEOUT. That Venus upgrade did not cause the earlier Flush score.
C06 stopped UNSUPPORTED before concealed Joker decisions at Ante8 Acorn.
There is no verified complete win in this fresh batch.
''')
write(folder/'priorities.md','''# Remaining work after331

Use the original remaining C05 slot for exact-installed331 on S7PXV521 after
preregistering the frozen graph/recipe/profile/source/runtime and180-second cap.
P05/P06 remain optional30-second public pairs, not renewed component authority.
Account every attempt and close unused capacity at the stopping point.

Integrate the reviewed Acorn public observer/belief/order components. Infer from
actually rendered effect popups, retain ambiguity and compare complete common
worlds. No hidden keys/IDs across an unseen shuffle. Current source validation
still stops at hidden Jokers and does not qualify that new observer.

Mixed inventory, future hand/discard/consumable development and terminal survival
remain broader work. Preserve cash, Perkeo/Negative/Observatory, all score caps,
population and persistent checkpoint retry limits. Completionist++, Jokerless,
Knife's Edge and the twenty-challenge goals remain unproved.
''')
write(folder/'architecture.md','''# Nine-card planning architecture —331

`Advisor/concealed_belief.lua` admits nine cards only where the complete world ×
subset family fits its existing budget; production fixture is
`tests/advisor_concealed_nine_card.lua`. Prior strategy/evidence navigation is
`ARCHITECTURE_MAP_330.md`, `REPLACEMENT_EVIDENCE_330.md`, `SHOP_COMPARISONS_329.md`
and `PURPLE_CONTINUATION_328.md`.

Current experiment controller and immutable status are under development328 and
runs/loss328_validation_20260915. Compressed source stdout is lossless on complete
capture; timeouts explicitly retain prefixes. C01 uses original raw transport.
Paired C01/C02 and C03/C04 audit reports separate actual scores and unknown gaps.
Detached Acorn components plus ACORN_INTEGRATION_REVIEW remain uninstalled by331.
''')
write(folder/'objective.md',(HERE/'evidence_release_notes/objective.md').read_text())
print(json.dumps(ref(folder/'context.json')))
