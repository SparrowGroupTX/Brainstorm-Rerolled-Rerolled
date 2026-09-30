# Packed classification keys — installed 2.67, 2026-09-11

The runtime slice changes only `Brainstorm/Advisor/score_cache.lua`. It replaces
per-subset string/table key construction with an exact numeric key for the
existing bounded classification cache. Installed at11:09:30CDT with backup
advisor-20260911-110930. All46 deployment/61 frozen product files match;
88Lua fixtures/192Python tests pass against exact installed bytes. See
SESSION_RESET_267.md/.json and runs/development267_installed_validation.

## Motivation and scope

The frozen 2.66 Rich development attempt in
`runs/weakness266_current_pilot1/000_candidate.log` reports **131,713 scoring
calls/evaluations** at hand decision step75, taking 3.124974800 advisor seconds.
That is recorded repeated work motivating cheaper classification-key construction,
not evidence of a gain from this change. The complete attempt subsequently
timed out at step110; its exhausted allowance has not been renewed.

The cache still reuses only classification, scoring-row and rule-flag components.
It does not memoize complete scores or carry state across decisions. All scoring
effects, legality, cash, growth, held inventory and population transitions still
run through their existing paths. This change does not alter sampling, candidate
families, comparison completeness, selected-action ranking or score budgets.

## Exact key construction

Each selected card retains the existing classification token semantics:

`token = 32 * rank + 2 * flush_suit_mask + stone_bit`.

For admitted inputs, rank is an integer from 0 through 14, the mask is 0 through
15, and the Stone bit is 0 or 1. Stone normalizes rank/mask to zero. Nondebuffed
Wild cards have all four suit bits; debuffed Wild cards use their ordinary suit
semantics. Smeared Joker maps suits to their red/black compatibility masks. These
are the same normalized properties used by the former string key and by the raw
classifier's flush/Stone logic.

The initial key is `1 + FourFingers + 2*Shortcut + 4*Splash`, with each rule flag
represented by zero or one. Each selected card then appends one base-512 digit:

`key = key * 512 + token`.

The encoding is collision-free within its admitted domain:

- `2*mask + stone_bit` is in 0–31, so each rank/mask/Stone tuple has a unique
  token. Every token is at most 479, below the 512 digit base.
- The initial prefix is 1–8 and uniquely represents the three classification
  rule flags. Smeared requires no additional prefix bit because its classification
  effect is fully represented by each card's flush mask.
- Appending base-512 digits preserves card order, including relative tie order.
  For length `n`, the key lies in `[512^n, 9*512^n)`. These ranges are disjoint
  across lengths because `9 < 512`; the nonzero prefix prevents leading-zero
  ambiguity, even for rank-zero cards.
- At most five tokens are packed, so the largest key is below
  `9 * 512^5 = 9 * 2^45 < 2^49`. Every intermediate and final integer is exactly
  representable by the Lua double-number runtime, below its 53-bit integer limit.

Selections longer than five cards, missing selected objects, or numeric ranks
outside 0–14/fractional/nonfinite ranks use the raw classifier before cache
lookup. Stone's irrelevant rank remains normalized as before. Nonnumeric/missing
rank normalization to zero also matches the unchanged raw classifier. This is a
generic fallback, with no seed, example or challenge-specific condition.

Per-object token, row and flag caches retain their existing weak-key tables and
immutable detached-state contract. Changing a card's rank, suit, enhancement or
debuff in place within a cache scope remains unsupported; transformed candidate
states must retain the existing copying discipline. No new mutation assumption
or cache lifetime is introduced. Relative scoring positions are still remapped
to each current selection, and public classification output copies remain intact.

## Bounds and focused validation

Cache capacity remains 8192 by default, hard-clamped to 16384, with raw
classification continuing when storage is full. The ordinary search cap remains
140,000 score evaluations; the existing 70-score fast-clear allowance is unchanged.
No additional scoring evaluations or partial candidate comparisons are admitted.

`runs/cache267_focus1/record.json` freezes the pre-install candidate/test bytes and
records **8/8 Lua fixtures passed** in 0.766 seconds under a hidden 60-second cap.
Its policy/test hashes were unchanged across validation. Coverage includes:

- Classification and full-score parity, ordered/physical-index remapping,
  rule flags, Wild/Stone/debuff distinctions, packed-key fallbacks and complete
  sampled/whole-decision comparisons: **3574 cache checks**.
- Fast clears, ordinary and Glass population conservation, whole-inventory
  development, growth, concealed continuations and two/three-hand finishing.

Pre-install candidate policy digest:
`5389e85fe2eae350068d574179b664718c7f5743d3f89d6f89338c8a695b823a`.
Changed cache file SHA256:
`de0dc33f23b287f835b4934b149410269647f274eeacb8b3eb4ad44ed282783e`.
After version stamping the installed policy digest is
`6476fc3f97de5b3d777ccf471737b111a9e627b8cd67b8f5527706b33be3e03d`.
The cache source hash is unchanged from the focused/component checks.

## Performance evidence limitations

A separately bounded baseline component attempt failed while parsing generated
Lua, **before the advisor decision executed**. That failed attempt is retained
and will not be rerun under its spent registration. The corrected candidate-only
15-second check completed in runs/rich267_step75_components2:2.0947264s worker
wall,1.806s instrumented decision,0.219s classification; same source action,
131713evaluations/score calls, unchanged input and no truncation. It supplies no
paired baseline/candidate speed comparison or full-result comparison. The old
candidate registration was superseded before execution. The final allowance
ledger in runs/snapshot_profile267_register1 records2workers spent/0remaining.

The focused fixture's single raw/prepared timing is only a diagnostic; it does
not establish a speedup. There is currently no measured overall speedup or
paired full-source result for this slice, and no win-rate or percentage-point
gain claim. Passing parity tests establishes their bounded functional coverage,
not broad adapter qualification or the user's per-challenge 50%/75% objectives.

Both native DLLs and current personal settings remain outside this source slice.
Activation follows the user's normal restart; no game launch, process/window
control, live gameplay, save access or automatic restart is part of this work.
