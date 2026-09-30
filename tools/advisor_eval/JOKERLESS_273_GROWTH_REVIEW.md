# Jokerless Blue and growth review — 2026-09-13

This is a read-only review of already completed source attempts
`03_coupon273_wfi` and `04b_coupon273_to6o` under
`runs/jokerless271_push_20260912_214242/source_attempts`. Both audited records
remain losses. `runs/jokerless273_blue_growth_review1/review.json` contains a
bounded projection of relevant public snapshots and decision fields, bound to
the exact record and trace hashes. No source worker, detached decision rerun,
save access, game control or additional evaluation lease was used.

The WFI attempt did not reveal a simple Blue seal preservation defect. On step
19, both acquired Blue cards remained in the public draw population; neither
was held. The 630-point Pillar clear against 600 did not satisfy the existing
10% safety margin for optional investment. Changing that guard would be an
unsupported relaxation, so it was preserved. On step 29 the discard explicitly
retained the drawn Blue Jack. Step 30 used The Star to make the available
1,176-point Straight Flush against 800; step 31 needed the unique Blue Jack in
that scoring hand. Both consumable slots were empty, so blocked capacity was
not the reason no Planet appeared. A Blue 2 was held on step 42, but the blind
was not cleared. The final play used the Blue Jack in its ordinary scoring
choice. These observations do not establish that a different multi-action
policy could not preserve a seal, only that a free immediate reward was not
being ignored.

The same trace's step 26 Death choice initially appeared weak because the
opening-hand mean stayed 354.25. Its **complete blind policy did improve**:
mean capped progress rose from 0.736875 to 0.79375, the selected policy used
zero discards rather than one, and the clearing world used three hands rather
than four. Hierophant produced 0.7321875 and Justice 0.736875. The Death
choice is not a demonstrated mistake. Permanent development and Glass
population safeguards remain unchanged.

Step 34 has a separate explicit limitation: revealed Fool has no supported
pack transition, causing the correct whole-pack fallback to discard all partial
enhancement comparisons. Fool's publicly known previous consumable offers an
opportunity for a future exact inventory-generation mechanic, with source
validation and inventory safeguards. This review did not implement it, bypass
the complete-comparison fallback, or claim that supporting it would rescue this
attempt.

The stronger TO attempt's Pillar loss did not involve growth investment or held
reward scoring. No Blue Steel card was in the actual hand at any reviewed
Pillar decision from step 19 through 25. Step 19's 16-point High Card came from
ordinary search: four-world extra-card cycling reported 173 to 347 next-hand
mean, then eight-world remaining-blind comparison preferred playing
(482.75 capped score, six clearing worlds) over the prior discard (431.125,
five clearing worlds). The recorded continuation explicitly omitted future
discards. No growth/consumable override or Blue reward entered that decision.
These are synthetic bounded comparison outputs, not measured success odds.
Search's remaining-resource policy coverage is the relevant next investigation;
the growth and finish-reward code has no demonstrated omission here.

No runtime files changed during this review. The completed 2.73 equal-history
Planet improvement and its 47-check full-entry fixture are described separately
in `PLANET_HISTORY_TIES_273.md`.
