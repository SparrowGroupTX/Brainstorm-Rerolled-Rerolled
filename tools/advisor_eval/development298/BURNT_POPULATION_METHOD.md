# Burnt first-discard population preference — 298

This is a routine synthetic implementation check, not a source component,
captured-state replay, seed search or terminal experiment. All historical
experiment budgets remain closed. No game process or player files were used.

## Observed gap

`search.lua` previously valued an upgraded hand through its relative base
Chips × Mult increase, played history, the profile's preferred hand and exact
equality with a conditional Joker's hand type. It did not account for the
public deck's ability to produce that rank pattern. The profile also defaults
to Pair in a fresh run; that fallback received the same preference as an
evidenced commitment. A large relative increase on a weak undeveloped hand
could crowd out a larger absolute upgrade to a sustainable rank hand.

`growth.lua` already owns the exact first-discard transition and the retained
clearing-hand check. This change does not qualify a speculative discard that
destroys the only proven clearing hand. It does not change the existing
ordinary sampled-survival comparison or its small capped future-growth term.

## Bounded comparison

For Pair, Three of a Kind and Four of a Kind, count the exact frequency of a
uniform opening-sized subset containing at least two, three or four cards of
one rank. The input is the complete public `playing_cards` population, not
remaining-deck-only data or hidden RNG. A generating-function complement
counts subsets with fewer than the required number at every rank; Stone
cards consume subset slots without contributing a rank. Bounds are 200
public cards, 12 held cards, 13 ranks and a legal selection limit up to five.
This uses arithmetic only and zero score evaluations.

This frequency describes a standardized rank opportunity. It is not the
probability of the next actual hand, a successful discard policy, a clear or
a win. It omits future discard retention, future deck changes and scoring
interactions. Five of a Kind and combined rank/suit hands are outside this
population adjustment; their previous preference remains available.

The existing relative-growth preference is weighted by the square root of
that frequency. An additional square-root-scaled absolute base Chips × Mult
upgrade term is capped at two utility units and reduced with the remaining
development horizon. These scale choices are explicitly uncalibrated
preferences. Terminal development horizon returns zero. Played history,
owned levels and conditional-Joker containment remain relevant. An unevidenced
default Pair profile no longer creates commitment by itself.

Missing/duplicate identities, inconsistent current hand/deck membership,
unknown or concealed cards, unsupported enhancements, permanent debuffs,
unsupported capacities, active unrecognized modifiers and Plasma scoring
fall back to the historical preference. Ordinary public-population backs
remain known. Supported normal Gold Stake shop-sticker modifiers do not
invalidate public rank mechanics. Existing only-hand boss caution remains.

## Verification

`tests/advisor_burnt_population.lua` passes 208 checks, including exhaustive
unordered-opening enumeration on small populations as an independent oracle
for the generating-function calculation. It covers overlapping rank groups,
Stone cards, early uncommitted Pair, sustainable Three/Four of a Kind,
established levels/history, conditional Joker containment, boss/horizon
limits, invalid-population fallbacks and deterministic nonmutation.

Two end-to-end `Growth.suggest` fixtures preserve identical held choices,
levels, history and an independent clearing Ace. Changing only the complete
public population switches the first discard from an established Three of
a Kind in the ordinary population to Four of a Kind in a concentrated rank
population. Both actual selected transitions retain a clear without a
replacement draw, preserve the input and use at most the unchanged twelve
growth score evaluations. This demonstrates a contextual policy change,
not optimality or a measured long-run benefit.

Focused command:

```
python -B tests/run_lua_tests.py tests/advisor_burnt_population.lua tests/advisor_growth.lua
```

The new fixture and the existing growth fixture pass. Root owns the complete
candidate/final installed regression and release records; this note does not
claim those have run at the time of the independent implementation check.
