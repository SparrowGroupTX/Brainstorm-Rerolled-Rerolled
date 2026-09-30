# C03: early scoring, nonlinear growth and unsupported acquisition

Frozen302 lost the selected synthetic Red Deck Gold run S7PXV521 at Ante1 Pillar,
592/600 chips. All22 selected actions resolved legally; all six played scores
matched original source exactly. This is a confirmed loss, not a near-win
converted into a win. Its13.5s outer time includes590632 score calls and
10.425215099938226s completed advisor time. No new simulation or rescoring was
performed for this postmortem. Exact provenance is in C03/audit.json; the
contemporaneous evidence excerpt is evidence.json beside this note.

## What happened with information already available

The declared Charm opening acquired Perkeo and Yorick. Both start without an
immediate scoring benefit here: Perkeo had no consumable, and Yorick remainedX1.
The Big Blind required450. The three discards used2,4,1 cards, advancing Yorick
by seven cards. Two exact plays scored292 and288, clearing the blind and producing
a$10 first shop. Choosing a two-card discard instead of five was not arbitrary:
the bounded visible-deck samples estimated a stronger immediate draw. At the last
discard, a complete eight-common-world remaining-blind comparison preferred the
one-card discard over its four-card incumbent; a larger next-hand mean alone
would misdescribe that decision. Those eight samples are not eight complete runs
or calibrated survival odds.

The first shop visibly offered Eternal Rental Hack for$1 and ordinary Faceless
Joker for$4, with Buffoon and Standard packs for$4 and Paint Brush for$10. Opening
Buffoon for$4 was a reasonable attempt to find scoring while the current bounded
forecast still failed some worlds. Its unknown contents were not available before
the opening action. No held Tarot was visible, so a claim that the advisor could
simply have kept an already-owned Perkeo target would be false.

The opened pack revealed ordinary Certificate and ordinary Card Sharp, one free
choice. This is the clearest integration failure. Certificate was assigned the
generic resource-generator score65; Card Sharp's heuristic score was40. The
captured Card Sharp comparison had complete common-world trajectories: the
selected one-discard policy changed from2/4 clearing worlds, mean602 chips,
mean77 shortfall, to4/4 clearing worlds, mean895 chips, zero shortfall. It also
used fewer modeled hands on average,4 to3.5. These observations support further
investigation of the repeat-hand scoring plan. They do not establish an actual
rescued run, or a win probability.

Certificate's random blind-start card generation was outside the supported
forecast. The advisor therefore correctly declined to mix incomplete tactical
results with complete ones, and reverted the whole pack to heuristic ratings.
It chose Certificate. That same unsupported owned effect then disabled later
whole-shop forecasts; the next decision spent$4 on Faceless with explicitly
unverified income opportunity, leaving$2. It departed with an empty consumable
inventory, so Perkeo made no copies. Faceless generated no observed income during
the subsequent boss. No affordable ordinary scoring offer was silently available:
the remaining Hack carried both Eternal and Rental costs, which a counterfactual
must include. Saving cash, buying Hack or picking Card Sharp remain unexecuted
counterfactuals.

Certificate actually generated a visible Purple-sealed7 of Spades at the boss.
The initial nine-card hand contained Kings and three Sevens, including one
Pillar-debuffed Seven. The advisor retained that Full House and used its three
discards on4,3,3 other cards. Its selected exact plays then scored296,144,124,28.
The final Pair was eight chips short after all four hands. Current advice knew
which cards were debuffed; this was not a Pillar identity-visibility error.
Discarding the Purple card could have revealed a Tarot but would sacrifice the
current scoring structure and enter an unknown-generation branch. No particular
Tarot, retained Perkeo target or successful continuation may be imputed.

## Nonlinear effects the current scopes miss

Yorick entered the boss sixteen discarded cards short of its next multiplier.
With only three legal discards of at most five cards each, that threshold was
already unreachable during the boss. It ended six cards short after seventeen
discarded cards across the ante. This is an exact public resource constraint,
not hindsight about hidden draws. Larger earlier discards could have changed
that reachability, but would also change hands, future draws and Big-Blind
survival. A repair should compare complete supported discard policies over the
relevant threshold; a flat five-card preference cannot establish that tradeoff.

There is a second threshold issue in the generic shop adjustment. The complete
Card Sharp comparison improved mean capped progress from0.87166666666667 to1.
The current formula36*log2(progress_ratio)-14 still assigned it a negative
adjustment(-6.8665440470382), even though all four modeled worlds now cleared.
The fixed entry penalty and mean capped progress do not express that local
survival threshold well. Changing that scalar alone would not solve this pack:
Certificate's unsupported comparison still causes the correct whole-family
fallback, which must remain intact.

## Smallest useful next comparisons

1. Complete the scope for resource-generating pack offers, starting with a
   bounded Certificate-versus-supported-score comparison. Account for the
   generated card's legal rank/suit/seal population, the extra initial held card,
   later draw capacity, scoring/held-card effects and cash. A valid lower/upper
   bound or complete admitted outcome family is required. Do not simply ignore
   the generated card, whitelist Certificate, assume a helpful seal, or remove
   the whole-family completeness gate.
2. Within a fully supported family, prioritize observed whole-blind survival and
   resource dominance before small heuristic differences; retain action, cash
   and population costs. A free pack choice should not inherit a purchase entry
   penalty without an explicit reason. This needs synthetic threshold fixtures
   and a separately registered captured comparison before any outcome claim.
3. Extend bounded Yorick planning to the next reachable growth threshold,
   comparing the same complete worlds and remaining hands/discards. Record when
   a current action makes next-blind activation impossible. Preserve survival
   exceptions and the existing aggregate score cap; do not force a named hand.

The last visible play did not expose an obvious missed clearing subset. The
more useful repair targets are the earlier loss of supported shop comparison
and the cross-blind growth threshold. Every proposed counterfactual must be
tested prospectively under fresh one-use authority; none was executed here.
