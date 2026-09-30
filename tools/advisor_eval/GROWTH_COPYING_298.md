# Yorick, Burnt Joker and Perkeo decisions — 298

The user requested flexible full-discard Yorick development, a viable long-term
hand for Burnt's first discard, and preserving a useful Perkeo copy target.
This slice fixes policy gates and valuation; it does not change original-source
effect transitions or add experiment authority.

## Source, tests and component map

| Runtime | Change | Routine fixtures |
|---|---|---|
| `Brainstorm/Advisor/growth.lua` | Reconsider useful Yorick discards after every observed draw/play; Burnt is eligible until the first actual discard; resource-aware batch sizes and rank padding, category/count shortlist plus physical alternatives; retain one-shot Death cycling | `tests/advisor_growth.lua`, `advisor_discard_investment.lua`, `advisor_growth_retained_steel.lua`, `advisor_weighted_growth.lua` |
| `Brainstorm/Advisor/search.lua` | Shared Burnt hand-growth preference includes qualified public rank-pattern availability and absolute base upgrade gain; conditional Joker hand containment and evidence-based main-hand preference | `tests/advisor_burnt_population.lua`, existing search/discard/transition fixtures |
| `Brainstorm/Advisor/strategy.lua` | Owned/free-copy Hermit valuation does not repay old shop price; prospective purchase compares the whole pool at remaining cash; empty-copy-pool shop guidance | `tests/advisor_perkeo_timing.lua`, existing inventory/economy/owned-finish/shop-sequence/Planet fixtures |

Read-only source references are the already-preserved
`runs/diagnostic287_20260913_222344/b_preparation2/source/card.lua`: Hermit
1385–1390, Perkeo2412–2424, Burnt2749–2755, Yorick2788–2802. Burnt checks actual
first discard, independent of earlier plays; Yorick advances per discarded
card without repeating physical growth for Blueprint; Perkeo copies from the
whole consumable inventory on leaving the shop and makes the copy Negative.
Hermit pays from current dollars without repaying its historical purchase cost.
These preserved source lines were read, not executed as new components.

## Yorick and Burnt action selection

The old once-per-blind growth gate suppressed all later Yorick discards and
Burnt after any play. It now applies only to the separate Death-source cycling
investment. A fresh suggestion can use each remaining actual Yorick discard;
Burnt alone stops once `discards_used` is positive, with current-round fallback.
No journal/lease/reset counter is changed or renewed.

Full five-card prefixes prioritize ordinary spare cards ahead of Blue/Gold.
Smaller batches remain eligible; rank-core padding for combined Yorick/Burnt
uses the actual classified discard hand, so three matching cards plus a pair
are Full House rather than an assumed Three of a Kind. Six existing scoring
slots first cover category/count diversity, then additional physical variants
because removing a held Steel card changes the retained score. A review caught
and corrected an intermediate overly aggressive variant deduplication.

Every admitted growth action still needs a known clear with110% initial margin
and an exact supported retained-card finish with105% margin before replacement
draws. Existing visibility, boss, held-effect/order, Glass and Arm guards remain.
The heuristic subtracts paid-discard cash/interest, forgone discard income,
Blue/Gold loss and action cost. It can finish early when growing an already
mature Yorick is not worth the cost or no future development horizon remains.
This does not promise to use five cards on every discard or discard a sole
winning hand to grow a Joker. Advice is recomputed after each user action.

## Burnt hand development

The shared preference formerly emphasized relative printed gain, historical
play counts and the profile's main hand. It did not use whole-deck availability;
the default Pair fallback could also masquerade as evidence of commitment.
Qualified public populations now support an exact finite-population count of
opening-sized samples containing at least two, three or four same-rank cards.
Stone cards occupy sample slots without contributing ranks. This is the
frequency of a rank pattern in one uniform sample, not the probability that
the advisor will make that exact poker category, clear a blind or win a run.

The heuristic combines that availability with existing levels/history/Joker
support and capped absolute base Chips×Mult gain. Thus a concentrated deck can
favor Four of a Kind; a deck with only three copies of every available rank
cannot earn opportunity credit for four matching cards. An ordinary unconsolidated
deck can still favor Pair. Main-hand bonus requires actual history, levels or
conditional Joker evidence; Four of a Kind includes Three-of-a-Kind triggers.

The population model is bounded to200 identified public cards and opening hand
size1–12. Incomplete, concealed, mismatched or unsupported modified populations
fall back without fabricating zero probabilities. Plasma, unsupported capacity
or visibility modifiers and permanent debuffs decline this added model. Existing
boss caution and zero final-blind development horizon remain. Ordinary discard
comparisons retain their survival-first policy and complete common worlds;
the growth value is a small preference, never an override certificate.

The safe-clear path caches each category's valuation, with no extra score calls.
It retains the12-score growth allowance inside the70-score fast-clear budget;
ordinary140000/shop50000/consumable25000 budgets and specialist caps are unchanged.

## Perkeo inventory

Existing logic already values the entire pool, including Negative cards,
Blueprint/Brainstorm copying and Observatory; it can spend surplus while keeping
a useful source, avoid dilution, and allow supported survival uses. The defect
was charging an owned Hermit's old shop price again when valuing future free
copies. At$3 cash with a previously$3 Hermit this incorrectly made the copying
engine valueless and could justify spending its sole source for a visible buy.

Owned-copy utility now treats acquisition as already paid. New purchases pay
once and compare the whole inventory at actual remaining cash, so spending to
zero cannot invent Hermit payouts. An empty active Perkeo pool receives concise
shop guidance without forcing a purchase/reroll. A held Negative Planet is a
valid target; no ordinary Tarot slot is required. This is still bounded utility,
not a universal requirement to retain every last consumable type.

## Evidence and limits

Focused receipts are under `development294`: `growth298Baseline1` preserves
the failing frozen297 regression, and `perkeo298baseline` preserves the old
Hermit defect. Perkeo fixed receipts are `perkeo298fixed1` and `perkeo298fixed2`.
Final integrated and candidate/installed regression use the `growth298` prefix.
All earlier failed/intermediate evidence is retained separately.

`development294/growth298Integrated2/report.json` passes11 relevant fixtures
with unchanged bound bytes (0.3543426999822259s). New fixture checks are64
discard investment,19 retained Steel,208 Burnt population and21 Perkeo timing.
The earlier `growth298Integrated1/preflight_error.json` records a misspelled
fixture-path invocation that stopped before running Lua. The valid replacement
uses fresh evidence rather than overwriting that mistake. Detailed population
method is `development298/BURNT_POPULATION_METHOD.md`; Steel review receipt is
`development294/growth298steelreview/report.json`.

The new tests use synthetic snapshots and exact detached transitions, including
successive five-card discards, preserved Blue/Gold/Steel, actual threshold
remainders, stopping exceptions, independent combinatorial enumeration, changed
deck/level/Joker preferences, first-discard timing and complete pool cash values.
No player profile/save, game process, source component, search, captured replay
or terminal attempt was executed. No win-rate, completion-time or human-superiority
improvement is measured. All experimental budgets remain closed. Installation
preserves current settings and both native DLLs; activation awaits normal restart.

Installed2.98.0-alpha at2026-09-14T10:31:38.0756544-05:00. Candidate and exact
installed regression both passed134 Lua fixtures and299 Python tests with
unchanged frozen policy/test inventories under60s per suite. Policy digest:
`359c7696d5832a1b945e7de12488d0579ad541ec08975ce65f63888d24170452`.
Backup: `deployment-backups/advisor-20260914-103137` beneath installation.
Evidence: `runs/growth298_candidate/validation/report.json`,
`runs/growth298_installed/record.json` and`policy/`,
`runs/growth298_installed_validation/report.json`, and
`runs/growth298_final/final_verification.json`. The installation verified55
deployment files; the frozen product/dependency inventory has70 entries.
No failed final regression, pending source/search worker or scheduled continuation
remains. Current settings hash is
`812572198bf4a7992143fbefff1977221b6a25ca2199df748e84a2603894b1d3`.
