# Replacement evidence preservation —330

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
