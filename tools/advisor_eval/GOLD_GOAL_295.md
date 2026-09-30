# Gold-sticker shop objective — 295

The opt-in Completionist++ mode can now buy or retain an additional distinct
missing Joker in the shop immediately before a supported final boss. It uses
actual paid endpoints, not a fixed sticker bonus mixed into strategic ratings.
The objective is the number of missing keys still physically carried; duplicates
add no extra opportunity and only the game's eligible win records a sticker.

`Brainstorm/Advisor/gold_goal.lua` enumerates hold, each admitted direct visible
Joker buy, and both buy/sell orders with at most one original sale. At most three
offers, six owned Jokers and forty endpoints are admitted. It reuses
`strategy.shop_sequence_api`, `shop_sequences.transition`, `shop_scoring` and
`liquidity`; no extra score allowance is allocated. Every endpoint must preserve
consumable inventory/capacity/buffer and the pre-play physical population. Cash,
borrowing, Negative capacity, Eternal sales and rental/discard reserves use the
existing transition and liquidity rules. No future payout is spent.

The exact incumbent's complete continuation must occur in the admitted family.
For a strict increase in missing keys, every supported first-hand composition
sample must clear 125% of the known target and have no lower score than both
hold and the incumbent. All four paired worlds must complete with no uncertain,
temporal or startup mutation evidence. Hand-size changes use nested prefixes of
the same four full permutations. Unsupported or truncated comparisons decline
the entire goal override. A complete projection family with no possible count
improvement declines before scoring; projection/evidence completion are distinct.

`decision.lua` invokes the goal after ordinary shop sequences and reroll advice,
before the existing whole-context fallback guard. `runtime.lua` loads the module;
`UI/advisor.lua` explains its scope. Only the first action is published for the
ordinary user-clicked Execute path. Subsequent actions require fresh advice.
Opt-out and standalone source snapshots have no goal override.

Scope is currently Violet Vessel and Verdant Leaf at the winning Ante's final
pre-boss shop. Other final bosses decline. An explicit supported retained-row
list excludes automatic generators/destruction, volatile food and unsupported
random or sale effects. Midas and Vampire are excluded because their scoring
enhancement replacement and source blind-debuff refresh need a stronger joint
model; Hiker's already-supported positive per-repetition chips remain admitted.
This slice does not qualify every Joker, every deck or a full blind/run.

Tests: `tests/advisor_gold_goal.lua` has synthetic full-family, paid cash,
duplicate, retention, Eternal/Negative/Credit Card, rental/perishable, inventory,
unsupported and partial-comparison cases. Real detached Shop.new/Scoring cases
select neutral Golden Joker, reject Bull-weakening spending and verify coupled
hand-size worlds. `tests/advisor_decision_integration.lua` tests opt-out, incumbent
propagation, shared costs, incomplete-result refusal and whole-budget fallback.
Runtime/UI/sequence/liquidity/syntax fixtures and full frozen candidate plus
exact-installed regression use `goal295` receipts.

Read-only mechanics/design navigation: `development294/GOLD_GOAL_295_DRAFT.md`
and `development294/NORMAL_DECK_READONLY_AUDIT.md`; those dated staged statements
are superseded by this installed component and current checkpoint. Original
focused1 fixture failure and all subsequent draft receipts remain preserved.
Source `misc_functions.lua`1047 in the preserved planet_pool_source1 tree awards
held Joker wins regardless of scoring contribution; no new source was executed.

No source component, captured replay, hidden search, terminal run, game control
or save/profile access occurred. Settings and both DLLs are preserved. Sampled
opening margin is a declared heuristic guard, not calibrated win probability,
proof of retained acquisition, Completionist++ speed or stronger-than-human play.
