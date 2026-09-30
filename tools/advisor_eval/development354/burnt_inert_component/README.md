# Post-first-discard Burnt support in the paired Yorick proof

This staged component changes only the Burnt exclusion in `Growth.pair_scope`. A known, supported Burnt Joker can be treated as inert for the next two discards only when the top-level and current-round discard-used counters are explicit, bounded, positive integers and agree. The existing identity, ability-shape, physical-population, inventory, scoring, and resource guards remain in force. Missing or inconsistent counters do not receive this support.

The baseline is the frozen 353 entry-margin candidate (`before/growth.lua`), preserving its 105% entry requirement. It does not use the concurrently changing shared Growth implementation. The staged change neither raises budgets nor relaxes the existing first-discard Burnt restrictions. The ordinary, shop, consumable, and fast-clear budgets are unchanged.

The preserved `runs/planet_pool_source1/source/card.lua` pre-discard branch checks `current_round.discards_used <= 0`; the supported scorer uses the same gate and increments both counters after a discard. Positive, agreeing counters therefore exclude Burnt activation in both projected transitions. This is static source grounding plus manufactured validation, not a new original-source component experiment.

## Validation

Every fixture was an isolated Lua 5.1 invocation with a 60-second outer cap. The fixtures poison `math.random`, `math.randomseed`, and `pseudorandom`. Before/after dependency hashes were unchanged for every invocation. Full logs, input fixtures, commands, runtime hashes, elapsed times, and report hashes are retained in their individual receipt directories.

- `baseline01`: preserved expected failure before the final RNG poison was added.
- `baseline02`: the final fixture fails against the frozen 353-margin baseline at the new post-first-discard Burnt admission assertion. No other baseline file was changed.
- `candidate01`: 48,363 checks passed, including 2,160 complete finite-population draw orders across three physical Joker layouts. Both later discards leave all hand levels/history and physical Burnt fields unchanged. Brainstorm and Blueprint copying Burnt do not add levels; only the same physical Yorick crosses its countdown threshold.
- `pair01`: the prior paired-Yorick fixture, with its obsolete blanket post-first Burnt rejection replaced by a missing-counter rejection, passes 18,630 checks across 720 complete draw orders and 24 complete count families.
- `margin01`: the existing 353 margin fixture passes 108 checks, including four production decisions and 48 score evaluations.

The new fixture also rejects first-discard, absent, fractional, negative, string, or disagreeing counters; unknown Burnt identities/effects/fields; modified arithmetic; unsupported editions; debuffed, expired, or concealed Burnt; insufficient finite populations or discards; Purple generation; and bosses. It verifies zero/one-score caps, fresh-state reevaluation for the second discard, exact reported versus actual scoring work, whole Negative inventory and population conservation, and the unchanged 70-score fast-clear limit.

## Promotion scope and limits

The files intended for review and promotion are `Brainstorm/Advisor/growth.lua`, `tests/advisor_yorick_pair.lua`, and `tests/advisor_burnt_pair_inert.lua` beneath this component directory. No shared runtime or tests were edited by this component task. `component_receipt.json` binds staged files and the preserved validation results.

This demonstrates a narrowly supported local planning extension. It does not demonstrate a rescued historical loss, a complete win, new Gold stickers, improved win probability, or performance on player populations. No captured-policy evaluation, seed search, complete attempt, save/profile access, original-source execution, or live-game control was performed.
