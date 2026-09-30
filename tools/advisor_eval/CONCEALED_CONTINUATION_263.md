# Concealed continuation implementation — 2026-09-11

This is a bounded runtime follow-up to 2.62, not measured win evidence. The root
agent owns the final release/version and installation record. No game process,
window, saves or executable launch was used by this work.

## Behavior

`Brainstorm/Advisor/concealed_belief.lua` retains the exhaustive fixed-slot
immediate play comparison (16 common joint composition worlds by default), then
compares its best play with the complete admitted family of up to three public
first-discards through the remaining one to four plays. It uses four common
outer worlds, at most eight public future-play selections, and fresh four-world
conditioned observations whenever concealed composition remains. All immediate
and continuation scoring shares the existing 8,000-score allowance. The first
action alone is returned; future discards and consumable spending are not queued.

Public candidates depend on visible ranks/suits and slot constraints only.
Future observations preserve retained concealment and use source-supported boss
visibility plus an independent challenge flip channel. Exact existing play and
discard transitions carry hands, dollars, hand size, growth, Glass destruction
and permanent population damage. Held consumables remain in scoring, including
Perkeo/Negative/Observatory inventories; no held item is spent by this route.

If a continuation is incomplete, over budget or encounters unsupported score,
generation or transition mechanics, the completed immediate fixed-slot play is
returned with an explicit warning and without a finishing claim. Horizons beyond
four plays fall back likewise. The bounded future candidate family can miss
better plays. It is not a general POMDP or resource optimizer and cannot establish
an actual probability of winning the run. Sampled finishing counts are not score
floors or measured win rates.

## Hidden discard correction found in review

Original `CardArea:emplace` leaves a discarded back on its back. Treating that
identity as observed would let a later policy subtract its actual rank from the
remaining deck. The observation builder now jointly assigns hidden held cards
and hidden nondrawable cards outside hand/deck, with explicit location masks.
Discarded markers are removed from unseen payloads so they cannot reveal which
identity occupies a nondrawable slot. Reconstructed worlds preserve the actual
deck count, unseen outside count and full physical population. Played cards are
revealed; discarded hidden cards remain unknown. Destruction of an unrevealed
hidden discard declines the extended comparison.

The dispatch predicate also catches fully visible held hands when unknown
nondrawable cards remain. Such states cannot escape to ordinary latent-deck
search. The total unseen pool is bounded at 160 cards; current held/deck limits
remain eight and 120. Existing known total-population assumptions persist; this
is direct visibility conditioning, not a history tracker that recovers all
information inferable from past growth/payout observations.

## Final review guards

Business Card and Reserved Parking cannot contribute deterministic future cash
or hand size. Their active physical targets (including copied and name-only
forms) decline the continuation, preserving the completed immediate advice.
This prevents average payouts from crossing Luxury Tax draw-size thresholds even
when no Bull/Bootstraps score warning would otherwise identify uncertainty.

Burnt, Mail-In Rebate, Faceless, Castle and Hit the Road can reveal constraints
on hidden discarded identities through public levels, payouts or growth. The
visibility-only posterior does not reconstruct those signals. A continuation
that creates such unknown outside identities declines; a real snapshot already
containing unknown outside cards and those effects returns explicit unsupported
advice before ordinary search. A current debuff does not erase unmodeled prior
history. Identity-independent Yorick count progress remains supported. These
limits avoid presenting this visibility model as an exact full-history posterior.

## Validation

- `tests/advisor_concealed_belief.lua`: 292 checks, retaining direct hidden-slot
  permutation, joint Mark/challenge weighting, fixed-action and unknown-mechanic
  protections. Old intentional unsupported-horizon expectations now check the
  honest immediate fallback instead.
- `tests/advisor_concealed_continuation.lua`: 602 checks. Actual one/two/three/four
  play comparisons, useful discard selection, complete-decision latent/ID
  invariance, visible-hand/unknown-discard boundary, re-observation, exact
  paid-discard/Yorick/Glass/population transitions, forced slots, budget
  fallback, random-income/history guards and unchanged inventory/global RNG are covered.
- Frozen `runs/concealed263_validation3`: nine fixtures / 1,606 checks pass in
  0.813 seconds inside a hidden 45-second capped worker. Full frozen product and
  selected fixture hashes are in `report.json`; frozen fixture hashes unchanged.
  It includes runtime, exact transition, finishing, safe growth, population and
  fast-clear regressions. `validation1` retains a missing-fixture registration
  error before execution; no simulation budget or experiment was renewed.
- Frozen `runs/concealed263_source3`: 270 source cases / 10,802 comparisons pass
  in 0.137 seconds inside a hidden 30-second capped Lua DLL worker. It reads
  unmodified source functions from the executable ZIP, checks House/Fish/Wheel/
  Mark, Stone/Pareidolia in either inventory, independent challenge flips and
  retained concealment, and confirms discarded backs remain backs. Source,
  harness, module and dependency hashes are preserved. No source episode or
  player-profile qualification is implied.
- Earlier exploration/focus/source artifacts remain present, including the
  superseded pre-review hidden-discard behavior. They are development evidence,
  not an evaluation cohort.

Runtime module SHA256:
`fbcc0a4b72334025ce0dcf52de6f100df0535fc66b2028e254950082e4f57b0d`.

Installation must include this module plus the root-owned Decision wiring that
supplies `draws` and `sampled_outcomes`; no global draw/scoring budgets or defaults
were increased. Root-owned checkpoint and deployment records supersede this
artifact label when assigning the final runtime version.
