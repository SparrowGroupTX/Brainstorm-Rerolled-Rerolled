# Advisor estimates and update ledger

## v2.19 - 2026-09-10 16:20 CDT

Installed bounded Yorick/Burnt/Death growth and finishing-line safeguards, plus
Bell discard legality, shared Negative slots, Observatory purchase value and
Glass-safe development. 33 Lua fixtures, 24 Python tests and 1,196 source-parity
comparisons passed. Backup `advisor-20260910-162006`; 23 files verified, config
preserved, game undisturbed. Activation on the user's next normal restart.

Two ordinary-opening 3-action smoke runs were correctly censored. One Fragile
clear needed 16 scores (~0.28ms advisor time), with score 1,920 in both the policy
and original source engine. No terminal win/loss sample, qualified simulator,
calibrated win rate or numerical estimate revision. See
[runtime/profiling report](runs/development_profile219final/report.json).

## v2.17 / v2.18 - 2026-09-10

Installed fast reliable clears/Glass conservation (2.17), then Perkeo inventory,
build development and exact discard search transitions (2.18). Thirty and 32 Lua
fixtures passed respectively, plus 16 original-source discard parity cases.
Backups: `advisor-20260910-160611` and `advisor-20260910-161154`; 22 runtime files
verified each time, config preserved, native DLL unchanged, game undisturbed.

No measured win rates or justified numerical estimate revisions. Both individual
challenge milestones remain unproven. One 3-action censored ordinary-opening
Omelette profiling probe is performance evidence only. Historical subjective
ranges below remain uncalibrated and must not be presented as measured capability.

## v2.16.0-alpha — historical batch

See [the six changes, per-challenge estimates and installation record](UPDATE_2.16.md).
The new search intentionally changes the opening distribution. Its conditional
win-rate guesses must not be combined with ordinary fresh-run statistics.
No 50%/75% qualification has been demonstrated. The unwanted hourly automation
has been deleted. That historical batching instruction is superseded: install each tested feature.

## v2.15.0-alpha — 2026-09-10

The three development priorities requested by the user are scoring-backed shop
choices, remaining-blind planning, and short consumable sequences. Before
implementation, the rough potential gains were estimated at +8–20, +5–15, and
+3–10 **percentage points on affected challenges**, respectively. Those are
very-low-confidence forecasts for developing those areas, not measured gains
from this patch; the effects overlap and cannot be added together.

This batch implements a bounded first version of each. Tests demonstrate
specific better decisions, not population win rates. The fresh-run working
guesses below are nudged only where those mechanisms appear particularly
relevant. Unchanged ranges reflect unresolved long-term or special-rule risks.
Every figure is subjective, very low confidence, and may be wrong outside the
stated range. There are still no established 50%/75% qualification results.

| Challenge | Rough fresh-run win chance | Change in judgment |
|---|---:|---|
| The Omelette | 15–40% | Better conditional purchases and ordinary blind continuation |
| 15 Minute City | 20–50% | Measured hand support and cumulative planning |
| Rich get Richer | 25–55% | Cash costs now enter scoring; keep prior broad range |
| On a Knife's Edge | 5–25% | Dagger's long-term sacrifices remain unresolved |
| X-ray Vision | 20–50% | Keep prior range; hidden identities still used |
| Mad World | 20–45% | Existing scoring interactions influence shop comparisons |
| Luxury Tax | 15–40% | Purchase hand-size effects enter supported shop comparisons |
| Non-Perishable | 15–40% | Better filtering of weak permanent scoring commitments |
| Medusa | 20–50% | Marble start-of-blind mutation remains outside shop samples |
| Double or Nothing | 5–25% | Long-run debuff accumulation remains difficult |
| Typecast | 5–25% | Planning the final permanent row remains incomplete |
| Inflation | 15–40% | More selective scoring purchases may save expensive mistakes |
| Bram Poker | 10–35% | Shop Joker purchases absent; most new valuation work does not apply |
| Fragile | 0–15% | Future Glass destruction still limits continuation |
| Monolith | 5–25% | Long-term Obelisk planning remains incomplete |
| Blast Off | 15–40% | Short resource horizon and consumable setup benefit |
| Five-Card Draw | 15–40% | Card Sharp continuation has a concrete regression improvement |
| Golden Needle | 0–15% | Single-hand restriction removes most continuation benefit |
| Cruelty | 10–30% | Efficient scoring purchases matter with three slots |
| Jokerless | 0–15% | Two-consumable rescues help; full deck building remains weak |

### Concrete changes and evidence

- Shop valuation compares four fixed paired samples of the actual owned deck,
  with fresh-round counters, post-purchase cash/resources and supported scoring
  conditions. Strategic income/growth ratings remain. Unknown, copy-Joker and
  certain start-of-blind/later-hand cases fall back. Shared cap: 50,000 scores.
  If it cannot complete, the whole decision discards scoring adjustments.
- A real-scoring all-red deck regression now buys working Popcorn over an
  inactive Blackboard that previously won the generic strategic ranking.
- Remaining-blind comparison is no longer restricted to three resource Jokers.
  A finite-deck regression changes a 135/170 losing discard line to a 174-chip
  clearing play line. A Card Sharp regression changes 255/280 to 294. These are
  deliberately constructed deterministic mechanics cases, not sampled runs.
- At most eight Planet/Black Hole → Tarot pairs fit inside the existing 25,000
  consumable-score budget. Example: High Card scores 16, then 52 with Pluto,
  then 156 with Empress; only the pair clears a 100 target. A separate Jupiter
  → Sun case clears 600 where Sun alone gives 340. Only the first action is
  recommended, and the next state is evaluated again before spending more.
- Integration protects a joint clear from an inferior nonclearing reorder,
  while permitting a later reorder that reaches the target and saves a Tarot.
  Shop comparison runs cooperatively and cannot publish stale/provisional advice.

### Installation and validation

Installed **2026-09-10 14:37:28 America/Chicago**, version **2.15.0-alpha**.
All **16 installed Lua files** match the repository hashes; configuration was
preserved with SHA-256
`08C40F7C6C989F842718323FA6A76CE3F8FB0D0E386C254604EBC1D7D03565C6`.
Backup (including `deployment.json`):
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260910-143728`.
The update becomes active after the next normal game restart.

Final validation: **22/22 Lua fixtures**, **15/15 Python protocol tests**, and
`git diff --check`. New/expanded checks include 62 shop-scoring, 27 shop-decision,
99 consumable-sequence, 9 combined-decision, 199 resource-decision, and 190
runtime checks. The original-engine development check on ADVISOR5 completed
30 actions in 16.514 seconds, then intentionally stopped in the Ante 2 shop.
All five deterministic play estimates matched; four shops used nonzero bounded
scoring comparisons. It did not test a consumable pair or produce a terminal
outcome. The trace records its loaded development policy digest before final
review; see [engine report](engine_probe_report.md).
No GPU training, large campaign, or live game/window control occurred.

### Next priorities

Continue these three areas using concrete counterexamples: support fair
copy-Joker shop comparisons and later-hand effects, extend useful remaining-blind
planning without losing responsiveness, and improve short consumable plans where
the existing shortlist misses a practical rescue. Preserve economics, boss
constraints and execution consistency. Do not interpret these tests or forecasts
as measured win-rate gains; install each useful tested batch as authorized.

## v2.14.0-alpha — 2026-09-10

These are **subjective, very-low-confidence guesses**, not measured win rates
or statistical confidence intervals. They describe a fresh Ante 1 run, using
the deterministic advisor's recommendations throughout, under ordinary vanilla
challenge rules. They do not estimate the user's current run. The real rates
could fall outside these broad ranges. Neither the 50% nor 75% target has been
established for any challenge by the qualification protocol.

The basis is a mechanics/coverage review: current-hand scoring and legal-action
coverage are stronger than long-term deck building, economy and future boss
planning. Search is bounded, stochastic scoring often uses averages, and some
effects remain unsupported. The new Execute button reduces manual work but is
not evidence of stronger strategic play. These initial working ranges are
retained through this batch rather than increased without outcome evidence.

| Challenge | Rough fresh-run win chance | Main uncertainty |
|---|---:|---|
| The Omelette | 10–35% | Egg replacement and spending timing; later scaling |
| 15 Minute City | 15–45% | Converting the starting synergy into a lasting build |
| Rich get Richer | 25–55% | Preserving the cash-supported build while shopping |
| On a Knife's Edge | 5–25% | Long-term Dagger sacrifices and replacement timing |
| X-ray Vision | 20–50% | Draw planning; advisor uses internal hidden identities |
| Mad World | 15–40% | Face-card synergy development and later bosses |
| Luxury Tax | 10–35% | Money versus future hand-size tradeoffs |
| Non-Perishable | 10–35% | Permanent Joker commitments |
| Medusa | 20–50% | Stone-heavy deck development and scaling |
| Double or Nothing | 5–25% | Accumulating debuffs and long-run card management |
| Typecast | 5–25% | Planning the row before later sticker restrictions |
| Inflation | 10–35% | Purchase timing under rising costs |
| Bram Poker | 10–35% | Long-term enhancement and Vampire tradeoffs |
| Fragile | 0–15% | Glass destruction and future deck survival |
| Monolith | 5–25% | Restricted Joker row and later scaling |
| Blast Off | 10–35% | Narrow resource margin and build development |
| Five-Card Draw | 10–35% | Small-hand redraw decisions and consistency |
| Golden Needle | 0–15% | Single-hand survival and discard-trigger uncertainty |
| Cruelty | 5–25% | Boss interactions and restricted resources |
| Jokerless | 0–10% | Planet, enhancement and deck-building dependence |

### Changes in this batch

- Adjacent HUD Execute button commits one displayed recommendation per click
  without opening the panel. It selects and plays/discards, uses targeted
  consumables, buys/sells, chooses/skips packs, rerolls, advances blinds/shops,
  and applies recommended Joker/hand orders. Freshness, game legality and a
  pending-action latch prevent stale or duplicate execution. No autoplay.
- Full Joker-row replacement plans compare a concrete sale and visible upgrade,
  including owned synergies, scaling, credit and Negative-slot consequences.
- Shop money-consumable timing compares actual payouts and follow-up decisions.
- Current-play enumeration supports up to 20 held cards. Larger hands retain
  a bounded legal proposal; enlarged-hand discard/consumable/order searches
  preserve budgets and disclose limits. This fixes Turtle Bean's no-action bug.

### Actual evidence, separate from estimates

- Focused Lua tests check modeled mechanics, legal execution, stale/double-click
  protection, and consistent HUD/panel publication. Passing them does not
  measure whole-run performance.
- Exactly one v2.13 development probe stopped after 17 resolved actions because
  Turtle Bean exceeded the old 12-card search limit. It was not a terminal loss.
- One bounded v2.14 regression on the same development seed passed that point:
  action 18 predicted and scored 640 chips, clearing the Big Blind. It reached
  step 20 and stopped deliberately. All three completed play scores matched
  (260, 60, 640). This is a regression check, not an independent win-rate sample.
- See [engine evidence](engine_probe_report.md) and the retained
  [optional qualification protocol](README.md). No large campaign or GPU
  workload was run for this batch.

### Installation record

Installed **2026-09-10 14:23:24 America/Chicago**, version **2.14.0-alpha**.
All 15 installed Lua files match their repository SHA-256 hashes. The existing
configuration hash was unchanged:
`08C40F7C6C989F842718323FA6A76CE3F8FB0D0E386C254604EBC1D7D03565C6`.

Backup:
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260910-142324`.

Final validation: **18/18 Lua fixtures**, **15/15 Python protocol tests**,
and a clean `git diff --check`. Execution has 313 focused checks, runtime/HUD
integration 183, UI 55, enlarged hands 206, strategy 238, and economy 36.
The bounded source-engine regression above ran on the recorded development
policy digest before final execution/economy review; it specifically establishes
the enlarged-hand fix, not source-engine coverage of every Execute action.
The live window was not launched or controlled for testing.

The backup contains `deployment.json` with version, timestamp, per-file hashes
and the preserved configuration hash. Future batches should
append concrete changes and evidence, and revise these ranges only with an
explicit reason. Installations become active at the next normal game restart.
