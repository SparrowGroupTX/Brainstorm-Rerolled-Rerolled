# Pinned simulator fidelity audit

Date: 2026-09-16. Jackdaw commit: `92df18c27e26e6d324132942905e41242e4e24bf`.

**Conclusion:** the pinned external engine contains concrete mechanics errors in strategically important cases already handled by the repository's source-grounded logic. It is a candidate for cheaper training experience, not a more authoritative rules implementation. The narrow repairs below and manufactured regression checks do **not** establish full-game fidelity, complete Gold Stake support, or a comparable win rate.

This audit read preserved source files and candidate Python code. It did not open the game executable/archive, read saves/profiles, run preserved Lua, initialize simulator episodes, or launch training. The authorized regression checks executed only manufactured cards, contexts, and one isolated shop-mutation helper.

## Reference provenance

The retained original `card.lua` was read from [preserved card source](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua). Its SHA256 was checked again and equals `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`, matching [earlier source evidence](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development328/acorn_public_component/source_evidence.json). Retained round-end excerpts are in [state-events source references](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/gold299_20260914/M02/state_events_source_references.json), registered with source hash `6c86aefb42d0323d737f87aaa84f53e42b755e72cd0bfd163b7d9cca5c0a99a9`. Those excerpts are evidence of the displayed source, not a fresh full-file hash verification.

The overlay verifies these candidate file hashes before modifying Python objects in memory:

| Candidate file | SHA256 |
|---|---|
| `jackdaw/engine/jokers.py` | `9b4c7ec916ea3e0a72a9e836be085dae6ac09606d187ff8abbc4d6e902e98fc7` |
| `jackdaw/engine/card.py` | `690a7b50f294f9429e6b76a7ee9e37b96da9c24db6328b3903a02d605bda9486` |

Pinned upstream files remain unchanged. The overlay is a separate experiment-owned file, so both original dependency and local corrections can be frozen and audited.

## Confirmed discrepancies and repairs

### Burnt Joker: copies suppressed and trigger moved to the wrong phase

Original `card.lua:2749–2755` handles Burnt under `context.pre_discard`, requires the first discard and `not context.hook`, and uses `context.blueprint_card or self`. It deliberately does **not** exclude Blueprint contexts. [Original trigger](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:2749).

Pinned `_burnt` instead requires `ctx.discard and not ctx.blueprint`, firing on the last individual card. This suppresses Blueprint/Brainstorm copies. It also selects the per-card fallback in `game.py`, whose hand evaluation omits the current Joker list, whereas the existing pre-discard evaluation includes it. Four Fingers/Smeared/Shortcut interactions therefore have an additional route to mismatch. [Pinned handler](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/jokers.py:2583), [discard call sites](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py:901).

**Minimal counterexample:** active row `[Blueprint, Burnt Joker, Brainstorm]`, first ordinary discard. Source performs three hand-level increases. Pinned handlers return only the physical Burnt increase, at the per-card phase.

**Repair:** replace the registered Burnt handler with the source pre-discard condition and permit copy contexts. The caller already invokes pre-discard once per Joker, in row order, before per-card discard effects. The replacement returns no Burnt effect during per-card discard, preventing duplicate growth. Hook and subsequent-discard exclusions remain.

The repository already counts phase-specific copies and models Burnt before individual discard effects. [Repository phase copying](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Advisor/phase_copy.lua:42), [repository discard scoring](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Advisor/scoring.lua:922).

### Perkeo: copies suppressed on leaving the shop

Original `card.lua:2412–2424` allows copied Perkeo effects, checks for at least one consumable, and schedules a negative copy. Pinned `_perkeo` requires `not ctx.blueprint`, suppressing those effects. [Original Perkeo](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:2412), [pinned handler](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/jokers.py:2619).

**Minimal counterexample:** `[Blueprint, Perkeo, Brainstorm]` with one held consumable. Source schedules three copies; pinned code schedules one.

**Repair:** allow copy contexts and require nonempty inventory. The existing shop loop produces descriptors in Joker order, then the mutation helper applies them sequentially. Each later copy samples the already-grown inventory, and negative copies increase consumable capacity. A manufactured regression verifies pool sizes `1,2,3`, three negative copies, capacity growth, and independent ability dictionaries. [Mutation application](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py:3044).

The repository's Perkeo reordering logic already reasons about the increased number of copy events, while retaining its separate unsupported-transition guards. [Repository Perkeo handling](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Brainstorm/Advisor/phase_copy.lua:134).

### Gold Stake sticker compatibility and mutual exclusion

Original `set_eternal` checks `center.eternal_compat` and absence of Perishable. Original `set_perishable` checks `center.perishable_compat` and absence of Eternal. Pinned setters assign booleans without either gate, while the shop factory invokes them after the sticker roll. [Original setters](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:506), [pinned setters](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/card.py:407).

**Counterexamples:** candidate catalog marks Gros Michel Eternal-incompatible and Green Joker Perishable-incompatible, but the pinned setters still apply those stickers. Direct setter calls can also give one Joker both stickers.

**Repair:** consult the candidate's existing center metadata, enforce compatibility and exclusion, and keep its top-level/ability sticker fields consistent. The five-round default is supported; nondefault `perishable_rounds` is an explicit unsupported boundary. This patch does not claim that every catalog entry has been compared with original source.

### Expired Perishable can be revived

Original `Card:set_debuff` first checks whether Perishable has expired; such a card stays debuffed even if the caller requests clearing its debuff. Pinned `set_debuff(False)` simply clears it. The candidate Crimson Heart path clears every Joker this way, so an expired Joker can become active again. [Original latch](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:526), [pinned Crimson Heart reset](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/blind.py:381).

**Repair:** preserve the expired-perishable debuff latch. The broader passive-effect transition remains unsupported as described below.

## Confirmed remaining boundaries

### Passive effects and interleaved round-end processing

Original `set_debuff` removes a Joker's passive deck contribution when it becomes debuffed and restores it when appropriate. Pinned setter changes only a boolean. Its perishable maintenance similarly sets `joker.debuff=True` without passive removal. Thus an expiring Juggler can leave its extra hand-size contribution in state. Credit Card, Oops! All 6s, Troubadour and other passive effects require the same state-aware treatment. [Pinned expiration](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/round_lifecycle.py:115).

The source round-end loop also performs Joker callback, rental, and perishable processing **for each Joker in order**, with `calc_dollar_bonus` later during cash-out evaluation. Candidate `_joker_end_of_round_effects` first evaluates all callbacks and dollar bonuses and later processes all rentals/expirations. A Golden Joker on its final perishable round is therefore counted in the candidate's precomputed dollar bonus before becoming debuffed, whereas source checks its debuff when calculating the later cash-out bonus. Fixing only a per-card decrement is insufficient. [Candidate round-end orchestration](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py:1903), [candidate precomputed bonuses](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/jokers.py:406), [source dollar-bonus guard](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/runs/chicot_order_source1/source/card.lua:1656).

**Conservative boundary:** the overlay latches `fidelity_perishable_expiry_order` as soon as any owned Perishable reaches tally <=1, before a subsequent possibly incorrect round. This deliberately censors more than the exact failing case. A currently debuffed Joker with an implemented passive add/remove contribution also triggers `fidelity_debuff_passive_side_effects`. These are unsupported/truncated episodes, never ordinary losses or wins. They make broad Gold Stake evaluation incomplete, not qualified.

### Mime held-card end-of-round repetition

The preserved state-events excerpt contains held-card repetition and Joker evaluation before applying effects. The candidate's `_round_won` explicitly comments that Mime repetitions are unimplemented; it directly pays held Gold and creates Blue Seal planets. A normal Mime plus held Gold Card is a direct mismatch. [Candidate omission](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py:2036).

**Boundary:** active Mime plus a held Gold effect or Blue Seal triggers `fidelity_mime_round_end_repetition`. The check rejects the whole episode rather than altering policy candidates. Red Seal repetition on a Gold Card is already handled by this candidate path; a card cannot simultaneously have Red and Blue seals.

These audit guards may inspect simulator-private state solely to reject an episode. They must not expose hidden identities, select actions, or change a surviving candidate set based on hidden knowledge. Censoring itself changes the evaluated population and must be reported.

## Reviewed mechanics without a confirmed mismatch in this bounded audit

- **Yorick:** source and candidate decrement once per discarded card, exclude Blueprint mutation, reset the counter on crossing, and allow copies of accumulated scoring xMult. A manufactured five-card example starts at counter2/x1 and ends at counter20/x2; all three `[Blueprint,Yorick,Brainstorm]` scoring effects are x2.
- **Blueprint/Brainstorm targets:** candidate uses the immediate right neighbor and literal leftmost Joker respectively, refuses self-copy, propagates the copy context, and limits cycles. The identified failures were in copied target handlers, not these basic target rules. This is not an exhaustive interaction audit.
- **Rental main path:** source charges rent regardless of debuff. Candidate `process_round_end_cards` also does so and subtracts before cash-out interest. Its separate `calculate_round_earnings` function additionally reads `ability.rental`, while factory rentals normally occupy a top-level field; imported states with both populated warrant a separate double-charge check. No rental-field synchronization repair was made here.
- **Terminal win:** source excerpts show that `G.GAME.won` alone is unsafe: it is set at the target boss before the loss branch. The existing source adapter requires the terminal/callback/threshold-or-save evidence. Candidate play handling sends under-target final-hand failures to GAME_OVER and permits its `saved` exception. Candidate `_round_won` uses ante >= win_ante, versus source equality; ordinary fresh runs should stop at the first verified target-boss finish. The wrapper must reject early/malformed win flags and preserve genuine saved outcomes. No complete terminal-path equivalence was established.

References: [candidate Yorick](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/jokers.py:1882), [candidate copy handlers](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/jokers.py:1452), [repository terminal evidence](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development328/validation_adapter/normal_terminal.lua:1), [candidate win comparison](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py:2142).

## Implemented overlay and validation

[simulator_patches.py](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_learning/simulator_patches.py) exposes `apply_patches(sim_root)` and `audit_state_boundary(gs)`. The patch identifier is `development355-source-fidelity-v1`. The environment integration must call the former before initialization and the latter before observations and around transitions, with unsupported handling ahead of terminal reward assignment.

[test_simulator_patches.py](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_learning/test_simulator_patches.py) passed **13 manufactured checks** using `python -m unittest tools.advisor_learning.test_simulator_patches -v`. They cover copy counts, Burnt timing and exclusions, copy loops, Perkeo sequential copying, Yorick growth, sticker rules, permanent debuff, conservative boundaries, idempotence and target-root validation. No simulator episode or preserved-source execution was part of those checks.

Passing these checks means the stated local repairs behave as asserted. It does not prove retail seed parity, all Joker interactions, all boss semantics, complete original-source adapter fidelity, or an unbiased Gold Stake win rate. The trusted comparison remains the original rules within the repository's explicitly verified scope; the external engine's role remains a disclosed throughput experiment.
