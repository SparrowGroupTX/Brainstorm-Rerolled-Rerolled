# Red Deck Gold sticker objective audit

Date: 2026-09-16. Scope: static source and repository-code review for Red Deck / Gold Stake runs with a Perkeo + Yorick opening. No game execution, simulator episodes, profile/save reads, archive extraction, or training was performed for this audit. This document does not qualify the external simulator.

The desired outcome is **new distinct Gold Joker stickers per started run**, not merely a win, score, acquisition, or number of physical Jokers. The existing product has a stronger award boundary than the fast simulator: it observes original award callbacks and counter transitions. Preserve that boundary. Use the fast simulator only for an explicitly synthetic objective until separately validated.

## Source provenance and award rule

The retained original [misc_functions.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/planet_pool_source1/source/functions/misc_functions.lua:1049) was read as text; its SHA256 is `c36ed54d8ab441be994a9afc5d38b8ac530f3b93995dfed424ec11f02e633198`. `set_joker_win()` iterates `G.jokers.cards`, requires a `config.center_key` and `ability.set == 'Joker'`, and increments `joker_usage[key].wins[G.GAME.stake]` for each physical card. It creates a missing usage row/wins table. `get_joker_win_sticker()` returns the highest recorded stake's sticker.

Retained original [state-events excerpts](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/gold299_20260914/M02/state_events_source_references.json:9) show `win_game()` calling `set_joker_win()` then `set_deck_win()` only when both `not G.GAME.seeded` and `not G.GAME.challenge` hold. Their registered source hash is `6c86aefb42d0323d737f87aaa84f53e42b755e72cd0bfd163b7d9cca5c0a99a9`; the retained excerpts, rather than a freshly hashed full state-events file, support this finding.

The same excerpts show that final-boss `G.GAME.won` can be set before the game-over branch. A win flag alone is consequently not proof of success or an award. In the surviving branch, the original schedules `win_game()` for round evaluation. Source end-of-round effects, rental/perishable processing, destruction/saving effects, and asynchronous card removal can affect the inventory before the award callback: use its actual inventory/counters, not a hand-start or end-round forecast.

| Condition | Source-grounded consequence |
|---|---|
| Entered seeded run (`seeded == true`) | Normal Joker/deck win callbacks are excluded by `win_game()`, even if the final boss is beaten. |
| Normal run with `seeded == false`, no challenge | May receive normal awards after the original successful win flow. The mere flag values still do not prove an award occurred. |
| Challenge present, even with `seeded == false` | Separate challenge-completion path; normal Joker/deck awards are excluded. |
| Gold stake | The validated vanilla catalog maps stake 8 to Gold. Red Deck is the requested training scope, not an additional condition inside `set_joker_win()`. |
| Joker still held at award callback | Its identity's current-stake counter increments. Buying or using it earlier is insufficient if it has left the row. |
| Debuffed or expired perishable Joker still held | No exclusion in the award function. It can receive the same sticker as an active held Joker. |
| Eternal, rental, negative, foil, holographic, or polychrome Joker | No edition/sticker exclusion in the award function. These properties affect gameplay/ownership, not distinct identity eligibility. |
| Two copies of the same Joker | The same counter can increment twice. Only one previously missing distinct identity becomes complete. |
| Blueprint/Brainstorm copying another Joker | Award their own `center_key`, not the copied effect's identity. |
| Negative consumables produced by Perkeo | They are not held Joker identities and earn no Joker sticker. A negative Joker still earns its own identity's sticker. |
| Previously recorded Gold win for an identity | Another win is zero **new** stickers for that identity. Lower-stake wins alone do not mean Gold is complete. |

These are award semantics, not a statement that every corresponding gameplay mechanic in Jackdaw is faithful. In particular the current overlay censors unresolved perishable-expiry states, despite expired Jokers being award-eligible in the source.

## Filtered starts and target gating

The product deliberately distinguishes an entered seed from a filtered normal start. [collection_search_product.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Core/collection_search_product.lua:405) validates the bound, single-use search result, selects the requested vanilla back, clears seed-entry state, starts `stake=8, seed=found.seed`, then sets `used_filter=true`, the bound `filter_info`, and `seeded=false`. The older [Core/Brainstorm.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Core/Brainstorm.lua:2058) has the same explicit post-start flag behavior. A deterministic RNG seed and the game's achievement-eligibility flag are different facts.

Therefore, do not tell a user that typing one of the supplied seeds into the ordinary seeded-run UI awards stickers. The observed product route intentionally starts a filtered normal run, and an actual award must still be confirmed through the original callbacks. A simulator seed, or changing a simulator Boolean, cannot establish that this product launch happened.

The [normal-opening capture/advice](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Advisor/normal_opening.lua:100) binds deck, stake, RNG seed, recipe, target identities/locations and pack-consumption state. Its Small Blind action requires a visible Charm Tag, no owned Jokers, zero skips, and space for the two Souls; pack choices are rechecked after the actual Legendary appears. It does not promise later search targets were acquired. A two-Soul filter receipt is not a replay or evidence of all future offers.

The current [normal recipe validator](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development328/validation_adapter/normal_recipe.py) has an observed-public opening route requiring Red Deck, Gold, hash-bound opening observations, and actual Perkeo/Yorick acquisition evidence. Its development route is explicitly not an unseen holdout. API 9 copy/Burnt search labels remain `future_acquisition_verified=false`; they should never materialize as free training inventory.

## Reuse the existing actual-award boundary

The relevant implementation is split across `gold_stickers.lua`, `auto_terminal.lua`, and `auto_run.lua`; no `runtime_completionist.lua` file was found in the current working tree.

* [gold_stickers.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Advisor/gold_stickers.lua:51) treats `wins[8]` as Gold complete only after validating the already-loaded history, full vanilla 150-identity catalog, and eight-stake mapping. Malformed/unavailable history is unknown, not missing. It rejects challenge, entered seeded, already-won, non-Gold, or unsupported metadata contexts. It deduplicates held identities and accepts a validated remembered public unordered inventory for concealed cards instead of revealing hidden identities.
* [auto_terminal.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Core/auto_terminal.lua:46) binds one GAME/profile object and run ID, records the final boss context, and wraps the original callbacks. Loss outranks a stray `won` marker. Its successful receipt requires the final winning ante, exact Gold scope, original Joker/deck awards, and score threshold or observed source saving effect.
* [auto_run.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Advisor/auto_run.lua:58) accepts only the verified ordered `set_joker_win`, `set_deck_win` sequence with matching contexts. It confirms an identity only when its original Gold counter changes from zero to positive, deduplicates keys, and separates unknown awards from zero-new wins. These receipts establish actual progress; catalog counts or held candidates alone do not.

No profile or save was read in this audit. An actual deployment should consume this existing validated loaded-state interface, not load profile files or guess the user's remaining targets. A frozen synthetic mask is valid for training, but must be labeled synthetic. The additional authorized public-log evidence below supplies a historical observed mask, which is a different provenance from an invented synthetic mask.

## Authorized public opening and objective evidence

The environment agent extracted bounded existing opt-in public snapshots into [SPECIALIZED_OPENING_SNAPSHOTS.json](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/SPECIALIZED_OPENING_SNAPSHOTS.json), SHA256 `414666da6b32ebb65218473a91057b31bc12c4709477d2bef877a9739ea703ce`. At `YAEARC31` sequence 2201, the public state supplies the post-opening shape: Red/Gold, ante 1, round 0, Small skipped, Big next with state `Select`, one skip, $4, ordered `[Perkeo, Yorick]`, no consumables, no editions/stickers/debuff on the pair, and fresh Yorick Xmult 1 / 23 remaining discards / +1 per 23. This corroborates the proposed minimal visible starting state. It does not establish simulator seed or hidden RNG parity.

[SPECIALIZED_PUBLIC_DATA.json](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/SPECIALIZED_PUBLIC_DATA.json), file SHA256 `c6572dcb8a42db0dbfa81752fc9b65ab926d992ceac4c8bc6c621fdb934237fe`, records the latest decoded public goal at sequence 3408, `2026-09-16T15:10:48Z`: **59 complete, 91 missing, 0 unknown**, with metadata/catalog/stake status complete. Its canonical status-map hash is `f5020ea4d8da7f69811712d21be39792861743f340b3daf2896196cd3484fe5d`. Perkeo, Yorick, Blueprint, Brainstorm and Burnt Joker are all already complete in that observed mask. Retaining those engine pieces can help win, but contributes zero new stickers by itself. Prioritize this frozen observed mask for the user's specialized objective; use synthetic variants only as explicitly separate training augmentation.

The latest snapshot is already won and has unavailable held inventory, so its run eligibility is false. The valid historical status map can define a frozen training objective; it is not permission to treat that ended state as a new eligible run. Refresh the loaded-state gate for actual future product play. These public observations do not themselves establish any new original-callback award.

## Proposed synthetic reward and evaluation contract

For each episode freeze a validated set `M` of missing vanilla Joker identities, with provenance either the observed public mask above or an explicitly synthetic augmentation. Let `H` be distinct held Joker identities at the simulator's qualifying final-boss terminal transition. Define:

`synthetic_new_gold_proxy = 1[qualifying simulated Red/Gold win] * |H intersect M|`

This is a proposed source-inspired terminal objective, **not an observed original award**. Candidate terminal inventory timing and full-game semantics remain unqualified. A later source comparison must check that `H` corresponds to inventory at `set_joker_win()`, including any destruction/removal events. Use `qualification=false`, `actual_profile_award=false`, and explicit curriculum and mask-provenance identifiers in records. A public observed objective mask does not turn an injected simulator episode into real-game award evidence.

Practical requirements:

1. Deduplicate physical copies by vanilla center key; count each missing identity at most once. Count no sold, destroyed, shop, pack, or consumable-only identity. Do not filter held targets on debuff/perishable/rental/edition alone.
2. Unknown target status is not missing. For production the existing validated metadata interface supplies the mask; for training generate explicit synthetic masks. Expose the public missing-status objective to the policy so it can distinguish a valuable passenger from an already-complete identity.
3. Use terminal new-sticker count as the primary optimization/evaluation metric, with win rate, score and held-target forecasts separate. A policy retaining two already-complete Legendary anchors needs to win while carrying other missing identities. Include synthetic masks where Perkeo/Yorick are already complete as well as a fresh-catalog case; all-150-missing alone does not represent repeated completionist runs.
4. Avoid a large arbitrary win bonus that changes the objective from expected new stickers to win rate. If shaping is needed, report unshaped terminal count and keep shaping bounded or potential-based. Do not pay acquisition bonuses as if the sticker had been earned.
5. Loss earns zero. Unsupported, censored, or errored episodes are not successful awards or known losses. Preserve them in the started-run denominator with their separate outcomes, report a conservative observed proxy sum per started run and completion coverage, and do not present supported-only reward as the true expected return. Training must exclude unsupported targets rather than turn unknown transitions into losses or successes.
6. Freeze seed/opening family and synthetic-mask splits before evaluation. Repeated training seeds, selected favorable openings, and injected curricula are development distributions, not unseen normal-run performance. Actual product evaluation ultimately needs verified original callback receipts.

The [current wrapper](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_learning/environment.py:427), as inspected during this audit, still returns scalar `1.0` at a qualifying simulator win; that is a win objective, not the proposed new-sticker objective. It has no original catalog/profile award bridge. A future reward change needs a new experiment freeze and report label; this audit did not alter it or the pinned engine.

## Minimal Perkeo/Yorick curriculum proposal

Use a separately named `synthetic_red_gold_perkeo_yorick_v1` episode family. This is an explicit constructed practice state, never a claim that a supplied seed naturally produced the same run, hidden deck order, RNG counters, pack, or editions.

* Start from the simulator's Red Deck/Gold normal initialization and preserve the whole stake stack. For a post-opening-shaped state, record Small Blind skipped, Big Blind next, ante 1, zero completed rounds/hands, one skip, consumed/closed opening pack, and no residual choices or tag rewards. Confirm all engine phase invariants together. This shape is inferred from the product's two-Soul opening route; it does not reproduce the real Charm/Soul RNG history.
* Add exactly one fresh `j_perkeo` and one fresh `j_yorick` in an explicitly recorded order, ordinary edition, no debuff, no rental/perishable/eternal attributes in this minimal synthetic case. No negative edition, extra slots, copy Joker, Burnt, vouchers, consumables, cash grant, hand upgrades, or pre-grown Yorick. These choices define the synthetic distribution; actual acquired editions/stickers/order must come from public opening evidence if matching a real start.
* Use fresh card initialization rather than a late-run card snapshot. Original [card.lua](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:327) initializes Yorick's remaining discard counter from `ability.extra.discards`; its [growth handler](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:2788) grows only the physical card once per discarded card and resets that counter. The pinned [Yorick center](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/data/centers.json:4741) specifies **23**, not 25, discarded cards and +1 Xmult. Retain fresh Xmult 1 and counter 23; the authorized public opening snapshot now independently corroborates these numeric values.
* Keep consumables empty initially. Original [Perkeo](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:2412) duplicates an existing consumable on leaving shop; empty inventory produces nothing. The agent must acquire a useful consumable before that engine can grow. The source-grounded overlay already permits copy contexts and sequential Negative duplication; this does not provide free initial consumables.
* Bind the synthetic missing mask to the episode record and to public policy features. Separate all-missing practice from later collection stages where the anchors are complete. Never initialize profile win counters merely to manufacture the requested labels.
* Leave RNG mismatch explicit. A future state built from the environment agent's authorized public seed/opening evidence is a separate observed-opening curriculum with its own hash and fidelity status. Matching visible Jokers alone does not qualify hidden draw order, future shops, stakes, or original awards.

The existing [simulator fidelity audit](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/SIMULATOR_FIDELITY_AUDIT.md) remains controlling for known unsupported states. This curriculum changes the learning distribution; it does not repair or bypass those boundaries.
