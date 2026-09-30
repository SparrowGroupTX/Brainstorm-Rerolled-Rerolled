# Lifecycle slice 454 — plain Golden Joker round end to cash-out evaluation

2026-09-29. Branch `codex/exact-search-speedups`. This is a Python learning-simulator
overlay and an isolated original-source comparison. Installed451/2.226.0-alpha,
its settings, DLLs and public journals were left untouched. The accepted direction
remains Red Deck/Gold Stake Perkeo/Yorick win-first simulator fidelity; these
seven synthetic Golden/Joker rows do not represent that opening or a full run.

## Finding and repair

The original round-end row loop calls each Joker's end callback, rental and
Perishable maintenance. A final-life Perishable Golden Joker becomes debuffed
synchronously; the later cash-out `Card:calculate_dollar_bonus` then returns no
bonus. The pinned Jackdaw helper calculated all dollar bonuses before its
maintenance pass. In the minimal case, the [preserved old comparison](BASELINE_COMPARISONS.json)
first differs at `events[2].dollars`: expected 0, actual 4. The rental variant
and both held-out row orders also fail at the bonus field. The three controls
agree with the pinned candidate.

The [narrow in-memory overlay](../../advisor_learning/lifecycle_454.py) recomputes
the dollar total after maintenance for ordinary-edition rows containing only
Golden Jokers and inert ordinary Jokers, while checking the exact pinned
`game.py` hash. It changes no upstream simulator file or product runtime. The
[source-derived reference](../../advisor_learning/lifecycle_reference_454.py)
is separate from the candidate. The [manufactured receipt](MANUFACTURED_COMPARISONS.json)
preserves all seven repaired comparisons and the wrong-order negative control;
the comparator finds the swapped first event without changing either input.

Original `ease_dollars` queues rental changes. The manufactured per-Joker events
represent settled maintenance projections; they are not callback-frame cash
observations. The receipt's `payment` event is arithmetic using the candidate
earnings total, not execution of the original cash-out payment action.

## Bounded original-source result

After the concrete [one-use proposal](SOURCE_EXECUTION_PROPOSAL.md) was prepared,
the user's “Go for it!” authorized `source_attempt_001`. The runner consumed its
lease before invoking one Lua worker, with seven deterministic fixtures, a
20-second worker timeout and a 1,048,576-byte attempt-artifact cap. It did not
launch Balatro, read a save/profile, run an episode or train a model. The
[prepared manifest](SOURCE_PROBE_PREPARED.json) fixes exact source, Lua runtime,
fixture, candidate, reference, harness and comparator bytes; the
[raw receipt](source_attempt_001/report.json) retains output and comparisons.

The probe executed selected original `Card` methods, `ease_dollars`, the original
end-round Joker row loop and `evaluate_round` in an isolated Lua state. All seven
cases matched the repaired candidate and reference on **settled rental cash,
final ordered Joker IDs/tallies/debuffs, Golden bonus, interest and evaluation
total**. The worker completed in 0.085 seconds; the attempt artifacts occupy
6,785 bytes. The source output confirms that the rental Golden at cash 10
queued one $3 charge, settled at $7, expired, and evaluated to $0 Golden bonus
plus $1 interest. The held-out three-Joker rows in both orders settled at $7,
with $4 active-Golden bonus and $1 interest.

This source probe deliberately used no active blind during expiry and an inert
blind during evaluation. It did not execute queued blind refresh or the cash-out
payment action. It emitted final row state and totals, not intermediate
per-Joker callback frames. Thus the source result qualifies only this isolated
settled/evaluation boundary; it does not prove payment, exact event timing,
general Joker interactions, shop behavior or uninterrupted sequence parity.
`source_attempt_001` is consumed and cannot be retried under this authority.
The integration module subsequently advanced for slice 455; its exact 454 bytes
are retained in [frozen/simulator_patches.py](frozen/simulator_patches.py) with
the hash recorded by the 454 source manifest. The historical receipt is unchanged.

## Qualification and remaining gates

| Mechanic or boundary | Status after 454 | Evidence limit |
|---|---|---|
| Plain Perishable Golden final-life bonus with ordinary Joker/rental rows | Isolated original-source agreement, seven fixtures | Settled cash, final row state, bonus, interest and evaluation total only |
| Tally-two, expired and nonperishable Golden controls; reversed held-out row | Isolated original-source agreement | No callback-frame trace or blind refresh |
| Cash-out payment and resulting paid cash | Manufactured arithmetic only | Original payment action not executed |
| Plain Juggler passive removal from 453 | Manufactured-tested | No original-source execution for that slice |
| Held Gold/Mime repetition, negative edition, general callback mutation/copy, sale/re-add, queued blind refresh | Unsupported or guarded | Separate source and transition qualification needed |
| Shop, Perkeo shop exit, next blind, RNG, whole run and policy improvement | Unsupported | No sequence, distributional or loaded-game evidence |

The learning episode's conservative `fidelity_perishable_expiry_order` guard
still censors near-expiry rows, including this Golden family. The repair cannot
yet support full-game training or a win-rate estimate. Next useful engineering
is the first unqualified adjoining boundary, such as actual cash-out payment
through shop entry, with its own state/event comparison and adverse cases. Any
new source worker, full-game evaluation or training job needs fresh bounded
authority; the older budgets and this one-use lease are closed.

Verification: `python -m unittest tools.advisor_learning.test_lifecycle_454
tools.advisor_learning.test_lifecycle_453 tools.advisor_learning.test_simulator_patches
-v` passed 22 tests. `python -m tools.advisor_eval.development454.run_source_probe
--check-only` verified the prepared bytes before the one execution. The raw
source worker returned `completed`, seven cases, no differences, and an empty
stderr log.
