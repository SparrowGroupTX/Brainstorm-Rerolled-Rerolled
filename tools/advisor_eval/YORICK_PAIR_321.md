# Canonical played Steel and paired Yorick threshold — 321

An already verified physical clearing hand can now support a bounded two-discard Yorick investment when the first discard alone does not reach its next increment. Both action and cash costs are charged. Only the first discard is recommended; the advisor must observe the actual draw and decide again before a second action. The existing single-discard behavior remains available outside this new narrow proof.

The motivating preserved C06 step89 had three spare cards, three remaining discards, Yorick at X3 with six cards to its next increment, and a reliable five-card Flush. Its39 remaining deck cards were all unsealed Base/Mult; the two Steel cards were part of the selected play. Three cards alone had existing utility 80×3/23/3=3.47826087, below the unchanged 4 action cost. Two batches can reach the actual threshold. Separately, the prior additive sorting guard rejected canonical played Steel. This diagnosis uses recorded development data;321 has no new captured-decision or complete-attempt result yet.

## Mechanics and complete proof

`Brainstorm/Advisor/growth.lua` now admits canonical unsealed, uneditioned Steel among reserved played cards, with played multiplier exactly1 and held multiplier exactly1.5. Its held factor is ignored when played. The source interpretation is grounded in already preserved `runs/planet_pool_source1/source/card.lua`, SHA256 `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`: `get_chip_x_mult` at line 999 returns zero for values≤1; held XMult is separate at line 1011. No new source archive inspection was performed.

The pair requires a full hand, at least one playable hand and two discards, canonical Small/Big Blind and a known normal deck. It excludes Burnt, draw/forced-card mutators, concealment, hand-size tax, cash-capped scoring, unknown modifiers/vouchers and immediate end-round Yorick expiry. The bounded known Joker row has only nonnegative supported scoring effects and physical count-only Yorick growth. Copying Jokers do not repeat physical growth.

Every hand/deck ID must match its complete population record in all fields. Every nonreserved population card must be canonical unsealed, uneditioned Base/Mult/Bonus with identity held effects and no income, generation or size effect. Blue, Gold, Purple, unknown identities and disposable Steel are excluded from the new pair. Ordinary deck backs remain public known identities. The whole known owned inventory, including Negative consumables and Observatory Planets, remains intact.

All legal first/second count pairs are compared, at most 25 classes. Physical subsets in one class have identical relevant effects within this narrow current-blind scope. The actual first `after_discard` transition still runs. Requiring at least the sum of both discard counts in the current deck proves both refills and the second batch's capacity for every draw order without recycling discards. The future receipt records exact scalar Yorick/cash endpoints; it does not fabricate drawn card identities or a future snapshot.

The existing exact first-transition retained-clear score is a floor for the second: replacement held effects are identity, the same reserved cards have order-independent scoring, and Yorick only increases a nonnegative multiplier. Existing110% entry /105% retained-clear margins, Glass exposure and Arm-cost guards remain. Direct cash costs, forgone unused-discard rewards, interest-threshold changes and both action costs are charged. Nonnegative remaining cash is required. All utility weights are unchanged and uncalibrated.

The guarantee concerns retaining this blind's clear and the availability of the second discard. It does not establish future-blind success, shuffle outcomes, a generally optimal strategy, time savings or win odds.

## Bounds and fixtures

No scoring cap increases: six existing discard shortlist scores, 12 overall growth scores, 70 fast-clear scores and the ordinary 140000 ceiling remain. No new runtime module or graph edge is introduced.

A plain-input guard now precedes **all** growth's recursive detached transitions, including prior single-discard and Death-cycle paths. It preserves complete data or rejects it: cycles, metatables, functions, nonfinite values, overlarge/deep inputs and malformed/hybrid/sparse arrays decline. Bounds are 65536 visited nodes, depth 16,4096 bytes per string,1048576 total string/key bytes, hand12/deck200/population256/inventory64/Jokers128. Pair admission retains its narrower canonical eight-Joker limit.

`tests/advisor_yorick_pair.lua` contributes 18630 manufactured checks. Together with five unchanged growth suites, 21310 checks pass. Coverage includes 720 distinct full draw orders, 120 mixed Steel/Mult played-card permutations, 24 complete first/second subset-count families, exact physical discarded-history markers, whole Negative/Observatory inventory, cash/interest/reward costs, unsupported mechanics, numeric/plain-input bounds and the actual `Decision.run` score ledger. Independent review reran the same checks. These fixtures are not source-executed alternate routes or population calibration.

## Exact integration and release evidence

- Detached package: `development300/yorick_pair321/manifest.json`, SHA256 `a58495db2ab8e0e471ad9b6e840d218e655f29146e07853acc8a684559aac466`.
- Runtime growth bytes: `d0de330671d31888fb49c886326cc470274552645d616836ad3fb588c139d688`.
- New fixture bytes: `b7aa6401a64516fd56ef94ae0b2c8ded21ac9f1435cb7d85c20c7c22acef4a7b`.
- Independent review: `development300/reviews/review_yorick_pair321.json`, SHA256 `3ad6746598ba3ab7bf5a44c9f8267f71675c9d2c9525c85028124a2275c35de7`.
- Focused receipts, preserved development-fixture corrections, base bytes and guarded staging backup are under `development300/yorick_pair321/`.
- Whole candidate 321 digest: `fd5c42031000f79ecba48ceee72f000aa3d1b7a0c51ed54895d36cfab53e4da5`, under `runs/pair321_candidate/`.

Installed **2.121.0-alpha** on 2026-09-14 at 16:29:45.8083749-05:00. Both full candidate and exact-installed regressions passed **170 Lua fixtures and 315 Python tests**, with frozen policy/test hashes unchanged. All 77 deployment files and 93 frozen product/dependency files matched; backup `advisor-20260914-162945` is beneath the installation's `deployment-backups` directory. Current configuration SHA256 `545ec2c3f0681562eb66a6fe61175cd77cda12410948f0e09eff33d302065fb1` was preserved, as were all existing native DLLs.

Actual release receipts: `runs/pair321_candidate/validation/report.json`, `runs/pair321_installed/record.json` and `runs/pair321_installed_validation/report.json`. The last report's SHA256 is `fd9bc430798f3a6a135abcebe4438595ba2d6e499f630b851a27b43d1980ce65`. The final context ledger is compiled separately and retains its superseded summary evidence. Activation waits for the user's normal restart; the loaded game version is unknown. The 318 8x/16x speed menu likewise has no new live activation/timing confirmation.

## Latest completed development attempts

Policy 320 C07 timed out after 164 legal resolved actions and 180.03099999995902 seconds. All163 shared completed public inputs/actions match C06. It adds no growth action or terminal benefit. Policy 320 C08 lost Ante 1 Pillar at592/600 after 22 legal actions in 23.09299999999348 seconds; all 22 actual inputs/actions match C05. The altered pack comparison still declines Card Sharp because successful-world Yorick/cash/hand-development predicates fail. See the compact `runs/gold299_20260914/C07/AUDIT.md` and `C08/AUDIT.md`.

C08's authoritative audit is the hash-bound file selected by `C08/selected_audit.json`. Earlier audit-tool errors and superseded audit files remain preserved. Neither attempt is an unseen holdout, a player-rate cohort or evidence of a Jokerless win. C09 is only a proposed dependent investigation being prepared; no registration, lease or result is asserted here.
