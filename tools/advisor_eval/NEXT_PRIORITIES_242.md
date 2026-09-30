# Next priorities after v2.42 - planning audit, 2026-09-10

The user asked what to do next and for current/projected win-rate estimates.
This audit is read-only with respect to product code; no new implementation,
installation or simulation was performed. The following six changes are proposed.

The later documentation-only context reset is SESSION_RESET_242.md, with a fresh
deployment hash record in SESSION_RESET_242.json. It adds concrete acceptance
criteria, contracts, reproduction commands and evidence paths for the proposals
below. No proposal was implemented during that reset. The root-level
ADVISOR_RESUME_PROMPT.md is the saved continuation prompt for the user's new chat.

## Win-rate forecasts, explicitly unmeasured

For v2.42, ordinary starts across all20 challenges with equal challenge weight:
central planning estimate35%, broad judgment range20–50%. After the six proposed
changes and useful policy calibration:45%, broad judgment range30–60%.
For useful supported filtered openings only:45% now (30–60%) and55% afterward
(40–70%). These are subjective forecasts, not observed rates or statistical
confidence intervals. They do not apply to each challenge individually, and
the hardest challenges could remain well below50%.

This is more conservative than the earlier projected50% ordinary average. The
last implementation batch established mechanics and some latency improvement;
the actual calibration prefixes selected no different actions. No representative
terminal win sample exists. Feature counts and passing tests do not establish a
win-rate increase. Focus on weak challenges because their retries dominate the
time needed to finish all20.

## Ranked next interventions

1. **Reuse tactical build scoring for revealed Buffoon choices.** Decision creates
   the shop comparison only in shop phase (decision.lua:14); pack choices rely on
   generic strategic ratings. Reuse the scorer for the actual offered Jokers,
   including opportunity to replace a weak owned Joker. Relatively small scope.
2. **Require a credible next-blind scoring plan when buying or saving.** Current
   purchases combine a relative opening-score adjustment with a generic purchase
   threshold. Detect structural score deficits and prioritize affordable flat
   Mult, appropriate Planets or necessary rerolls over slow speculative growth.
   Use actual hand/discard rules and feasible deck composition, not challenge IDs.
3. **Price conditional income and growth by trigger frequency and payback.** Avoid
   giving every income Joker the same low-cash urgency bonus; evaluate whether its
   condition fits the build and whether the payout arrives before the next danger.
4. **Make verified replay cheap and calibrate on decisions that can change.**
   engine_run.lua runs the advisor before replacing replay-prefix actions. A
   fingerprint-verified fast prefix would allow more late-state counterfactuals.
   Include shop/growth/reroll decision cases, bounded complete episodes and unseen
   validation seeds. Three opening actions that never change are only a plumbing
   check, not a policy optimization experiment.
5. **Reduce repeated nonclear and shop work.** Profile by component, reuse only
   unchanged state comparisons, and add conservative pruning with complete paired
   comparisons. Current expensive nonclears take roughly87k–116k scoring calls.
   Measure real decision latency separately from game actions/retry overhead.
6. **Select filtered openings by retained engine and setup cost.** Use fresh
   registered search starts, retain misses/time, and continue past acquisition.
   Pair names alone do not predict retained scoring/copying engines or completion.

Deeper mixed play/discard horizons, concealed-card belief policies and random
Tarot/growth coverage remain useful follow-ons; rank them using failure frequency
instead of presuming they beat the above early-decision fixes.

## Concrete evidence and cautions

Final Golden Needle trace entered Ante2 Small (800 chips) with Credit Card,
Devious, unscaled Spare Trousers, unscaled Square, and Delayed Gratification.
All hand levels were1 and all52 cards were unenhanced. Its maximum ordinary
Straight was724 and Four Aces with Square's first growth756; a Straight Flush
was effectively necessary. This supports a build-readiness hypothesis rather
than proving that deeper redraw search would rescue it.

Step22 spent the last$4 on Delayed Gratification; six paid discards followed in
the next blind, ending in loss. The purchase's conditional income was not modeled
well by the generic rating, but saving that$4 has not been shown to save the seed.
Step6 selected Devious from a pack with zero scoring evaluations; rejected offers
were not preserved, so a better available alternative has not been established.
Source: strategy.lua:351,359,919,1223,1503; shop_scoring.lua:547;
runs/development_final242/golden_episode/000_c_golden_needle_1_ADVISORCOVERAGE332.log
and the matching .failure.json.

The v2.40 Omelette45s timeout does NOT establish a stalled Boss transition:
completed advisor work37.325s plus source transitions7.161s already totaled44.486s.
The report's source_transition_timeout labels the interruption location. Future
diagnostics should distinguish cumulative-budget expiry from an actual stall.
The previous single matched Golden Needle replay was41.01s→31.38s with identical
31 actions and the same loss; no general speedup or win gain is established.
