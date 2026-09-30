# Nine-card concealed planning —331

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
