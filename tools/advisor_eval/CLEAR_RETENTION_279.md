# Safe clearing-play substitutions — installed2.79, 2026-09-13

Original-source6 had two supported growth misses. Step37 played a BlueSteel
DiamondJack in a Flush when a sixth Diamond could replace it; step70 played a
Holographic BlueSteel5 in a Straight despite an ordinary5. Source8step21 exposed
another case: The Psychic demanded five cards, but a different five-card Pair
could clear while preserving the BlueJack. A bare Pair is illegal there; the
initial read-only inference omitting that boss rule was corrected before execution.

Search conservation now adds at most8 distinct single-card exchanges inside the
existing16-evaluation conservation allowance. Same-rank or Flush-suit substitutes
are prioritized, then other exactly scored alternatives. Existing removals and
Glass-saving proposals remain first. Every candidate receives actual legality,
reliable-score, population, Glass, Arm and whole-inventory finish-reward comparisons.
No sample RNG, future outcome, global score ceiling or70-call fast-clear cap changed.
No later discard/round is forced and no extra action is taken to chase a Planet.

New retention fixture74checks includes Straight/Flush/Four/Five-kind, five-card
Psychic, insufficient-score control, forced/debuff/full-slot/final-boss controls,
real Perkeo/Observatory/Negative valuation and Glass conservation. Exact installed
277 fails the intended regression; candidate focused fixtures pass. All failures
and corrected fixture setup are preserved in runs/fast_clear_retention*.

Root mechanical leases3 and4 (oneuse15s each) used complete exported source
observations with baseline actions reproducing exactly. Component3:0.25s, source6
step37 score276->366,18->20calls, one predicted BluePlanet instead ofzero; step70
3450->2925 against705remaining,20->21calls, onePlanet. Component4:0.188s, source8
Psychic104->44 against18remaining,13->16calls, legalfivecards and onePlanet.
Inputs/frozen policies unchanged; these are detached decisions, not rescued runs.
Evidence under runs/jokerless271_push_20260912_214242/root_component03_blue_retention
and root_component04_psychic_retention (registration/report/worker logs retained).

Full final candidate runs/jokerless279_candidate2/validation:112 Lua fixtures and
253 Python tests pass,11.796s/11.094s, unchanged policy/tests. Candidate1 also passed
before the Psychic expansion; candidate2 supersedes it. Installed279 record verifies
all51deployment and66frozen product/dependency files match repo/installation. Both
DLLs/current settings unchanged. Product Execute user-clicked; game untouched.
