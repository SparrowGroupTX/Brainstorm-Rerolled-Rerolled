# Final-boss Gold cargo — staged 295 design

The smallest useful goal override is a complete comparison in the shop directly
before a supported final boss. It can buy a neutral missing Joker with an empty
slot, replace a completed Joker with a missing one, or keep a missing Joker that
an otherwise equivalent normal recommendation would sell. Progress is the count
of distinct missing center keys physically present in the paid final row. A
duplicate physical copy adds no additional sticker opportunity. No projected
purchase writes profile progress or claims an awarded sticker.

The actual source `set_joker_win` iterates retained `G.jokers.cards`, records
`wins[G.GAME.stake]`, and has no scoring-contribution or debuff predicate:
`runs/planet_pool_source1/source/functions/misc_functions.lua:1047`. Run
eligibility and actual profile interpretation belong to the separate detached
tracker, not this planner. Its `snapshot.completionist_goal` must have schema1,
goal `gold_stickers`, complete metadata/catalog/held status, and eligible=true.
Every carried or admitted target key must have known complete/missing status.

## API and comparison boundary

`gold_goal.suggest(snapshot, modules, incumbent, shared_context, options)` returns
an optional ordinary strategy-shaped first action plus diagnostics. The runtime
root owns invocation after ordinary shop advice, complete sequences and reroll
selection, before the existing whole-context fallback guard. Only explicit
runtime/test promotion follows tracker294's final release. Drafts remain under
`development294`; the promoted planner and fixture use their ordinary paths.

Use `strategy.shop_sequence_api` and `shop_sequences.transition` for complete
one-buy/one-original-sale endpoints, retaining source cash, Negative slot,
borrowing, hand-size, probability, interest and sequential-price handling.
No uses, packs, rerolls, speculative offers or more complex incumbent sequences
enter this first slice. Exact nonempty incumbent continuations must be present
in the declared family. Known no-slot/unaffordable/unsellable branches are
recorded exclusions. An admitted unsupported transition or comparison aborts
the entire goal override.

The family is hold plus every admitted direct visible Joker buy and both legal
sale→buy and buy→sale sequences for every original sellable victim. At most
three offers and six owned Jokers yield at most40 plans. All comparisons reuse
the current shop context's unchanged50,000-score budget. A prior truncated or
exhausted context declines before goal work. There is no exact independent cost
preflight API; later shared-budget exhaustion retains the caller's whole-decision
fallback instead of publishing partially compared cargo. Once every endpoint
and the exact incumbent have been projected, a family with no possible increase
in distinct missing keys declines before any score call. Its diagnostics mark
projection completion separately from score-evidence completion.

Each endpoint is compared against holding the original row and against the
exact incumbent endpoint. Evidence must have all four matching target openings,
no uncertainty, no temporal scenario, no startup mutation, and no incomplete
marker. Every candidate opening must reach at least125% of the actual target,
and each paired score must be no lower than both references. The returned
minimum delta and the actual before/after score arrays are both checked.
This is a complete declared first-hand composition comparison, not a full-blind
or future-run certificate. Existing shop opening order shortlists are not
claimed exhaustive or equivalent to the user's future draw order. Hand-size
changes split the same four full deck permutations at different prefix lengths;
the visible hands differ, while each compared index remains the same common
composition world. A real-context fixture checks this coupling directly.

Each paid endpoint must retain the entire consumable inventory/capacity/buffer
and playing-card population. Liquidity reserves all still-relevant paid discards
and rental charges, including retained debuffed/perishable rentals. Purchases
cannot fall below the exact post-endpoint borrowing-plus-reserve floor. A
stronger current supported score cannot be sacrificed for sticker count.

Rank only endpoints with strictly more distinct missing keys than the exact
incumbent, then higher supported minimum opening chips, actual remaining cash,
fewer actions, and a deterministic action key. The immediate action is the only
one published for user-clicked Execute. Multi-action receipts explain the paid
endpoint and require fresh advice after the first step. No fixed sticker bonus
is mixed into unrelated strategic ratings.

## Stable retained-row scope

The explicit identity list includes deterministic ordinary scoring, copy,
resource and income Jokers, including Photograph/Hanging Chad, Blueprint/
Brainstorm, Golden, Egg, Cloud9, Satellite, To the Moon and Rocket. Each still
must pass complete nonrandom scoring. Deterministic post-clear counters or
income do not imply that the Joker disappears; no future cashout is spent.

Excluded identities include Dagger/Madness, blind-start or consumable generators,
random changing targets, volatile food, stochastic score/income mechanisms,
and unsupported sale effects. In particular, Gros Michel/Cavendish, Popcorn,
Turtle Bean, Ice Cream and Seltzer can remove themselves. Chaos is excluded
because the reused endpoint helper does not update its free-reroll resource.
The source add/remove rules are in preserved `b_preparation2/source/card.lua`
lines564–696; setting-blind effects around2491–2590; end-round effects
around2874–3040; source edition fields at387–419. These were read as existing
text, never executed again. Source-shaped edition `type` and numeric fields are
accepted; conflicting/unknown edition metadata is excluded. Eternal sales and
Negative slot loss retain their existing exact transition guards. Known
perishable timing can remain eligible because expiration disables effects
without itself removing the physical card; unknown timing is excluded.

Only Violet Vessel and Verdant Leaf are currently supported final bosses in
`shop_scoring.next_blind`. Bell, Heart and Acorn remain unsupported. An unknown
boss or a stronger-scope requirement must not bypass the comparison through an
optimistic fallback. The module is not an all150-Joker retention model.

Midas Mask and Vampire are excluded from this first slice. The scorer models
their before-scoring enhancement changes and physical Joker ordering, but those
effects are not automatically marked uncertain or temporal. Preserved source
`Card:set_ability` also refreshes the affected card's blind debuff; that refresh
is absent from the direct enhancement assignment. No newly verified scoring
failure is claimed here, particularly for the two admitted final bosses. The
static paid-endpoint population guard alone is insufficient to certify their
post-play enhancement preservation. Hiker remains admitted: its mutation adds
permanent chips after each scoring repetition, is included before subsequent
repetitions, and leaves the input unchanged in existing focused scoring tests.

## Evidence and pending release work

`goal_focused2` passed60 checks in0.1169392999727279 seconds. It includes actual
detached Shop.new/Scoring evidence selecting neutral Golden cargo and rejecting
spending that lowers Bull scoring. The latter uses120 score calls.
`goal_focused1` is preserved: its negative test accidentally allowed buying the
stronger Joker while retaining the missing one, a valid better endpoint. Only
that fixture's intended full-slot constraint was corrected.

`goal_focused3` passed 63 checks in 0.12329059996409342 seconds, adding score-array
verification and malformed input guards. `goal_focused4` passed 64 checks in
0.12219779996667057 seconds, including exact-incumbent followup guards.
No original-source component, captured
replay, search, complete run, game/profile/save operation or sticker acquisition
was executed. These tests demonstrate objective/comparison behavior only.

`goal_focused5` passed 81 checks in 0.13179970002966002 seconds. It adds the
complete-family zero-comparison preflight, exact nested-continuation rejection,
Midas/Vampire scope guards, and the actual shared-permutation hand-size test.

After checkpoint 294 closed, the planner was promoted to
`Brainstorm/Advisor/gold_goal.lua`, SHA256
`4ca01a8e455c96d50b2a69789932a2042c97d8c8d145c2c3fd968c8fbfcee134`,
and its fixture to `tests/advisor_gold_goal.lua`, SHA256
`b7cb0dfd64e0fbf9939729bb48392ab434e2f6d4d43cd207db7c76da3c609de2`.
The only fixture promotion change is the runtime module path. Both draft copies
remain. `goal_promoted1/report.json` records 81 passing checks in
0.12506520003080368 seconds against those production bytes.

Independent review found no material blocker. Its defensive compound-incumbent
concern was addressed by rejecting nested followup/sequence fields inside the
replacement buy and declared sequence actions, with separate regression checks.
The root owns integration, candidate and exact-installed full regression,
release versioning, installation and final checkpoint evidence. The focused
receipt alone does not establish release or actual Gold progress.
