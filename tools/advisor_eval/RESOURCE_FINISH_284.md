# Bounded joint hand/discard policies — 284

This slice addresses a concrete comparison gap identified by read-only reviews
of preserved development failures: Bell step226 had five hands and one discard,
while Eye step75 had four hands and nine held cards. Neither state fits the old
two/three-hand specialist. The preserved decisions have not been replayed by
this slice; no alternative continuation or rescued run is demonstrated.

## Complete declared family

`Brainstorm/Advisor/resource_finish.lua` compares the incumbent play, incumbent
discard, and an actually legal play of the same cards proposed for discard.
Duplicate first actions are merged. Each first action is crossed with three
fixed continuation policies: play only; one discard at the first later
nonclearing observation; and one discard before the final hand. A later discard
requires at least one actual play first and is chosen from the observed hand
before seeing its replacement cards. There is at most one later discard in
addition to an incumbent first discard.

All admitted policies receive all four deterministic common worlds. Policy
selection occurs across those four worlds, never by choosing whichever policy
wins separately in each world. Root cards, deck composition and physical card
identities determine the sampling; the real remaining-deck order is not used.
Future scoring choices use ordinary public-state scores. Only the selected
action receives private Lucky/Glass outcomes, including the final play. A mean
score alone cannot produce a clearing outcome.

Each policy runs through its remaining-hand horizon until a modeled clear,
hand/card exhaustion, or a known absence of any legal observed category under
the declared policy. The last case records `policy_exhausted=no_legal_play`,
remaining resources and per-policy/total exhaustion counts. This is **declared
policy exhaustion, not source GAME_OVER, an observed loss, a source
counterfactual, or a claim that all remaining hands were spent**. An allowed
discard is considered before that stop. Unknown or unsupported scoring,
transitions, concealed observations and incomplete work abort the whole
comparison; they are not assigned losses or estimated scores.

The search274 resource override guard remains required. With additional
discard schedules still omitted, a discard-to-play proposal cannot regress a
paired world's win or capped progress solely because its aggregate is better.
A meaningful clearing-sample improvement must also cover explicit extra-action
and paid-discard thresholds before a first action changes.

## Admission, work and structural coverage

The module is limited to no owned Jokers, no Observatory, two to five hands,
at most ten visible held/future cards and120 drawable cards. Physical identities
must belong to a complete unique playing-card population. Known ordinary rank,
suit and enhancement composition is required. Finite cash/credit and integer
hand/discard resources are checked; optional discards respect the existing
signed borrowing-limit guard.

`admits` routes only formerly unsupported scopes: four/five hands; three hands
with current/future size above six; two hands above eight; or an ordinary Lucky
card in the held/drawable composition. Other small two/three-hand states retain
the existing owned-Planet specialist. Reliable current finishes, tactical
actions and growth investment retain priority. No consumable is used by this
slice; all owned inventory is carried unchanged through its resource policies.

Every observed subset of one to five cards is structurally classified: at most
637 subsets for ten cards. Known category, forced-selection and hand-size
restrictions are applied before shortlisting. Each available category gets up
to two observed structural representatives, at most24 total. This includes Two
Pair and Full House, absent from `search.obvious_candidates`. Structural power
accounts approximately for nominal/bonus Chips, additive Mult/Lucky, Red
repetitions, Glass/Polychrome and retained Steel; the alternative representative
protects held Blue/Gold and Glass exposure. These proxies do not establish the
best physical variant or card order. Normal scoring remains legality authority.

The specialist replaces the existing specialist slot, with unchanged maximum
12,000 score calls. A separate150,000 classification-call ceiling prevents
structural enumeration from becoming unbounded; both counters yield every64
calls. Partial work never changes the action. Ordinary search retains its
140,000 allowance, consumables25,000 and shop50,000; these are separate existing
module limits, not a single140,000 whole-decision cap. Reliable fast clear keeps
its existing70-score ceiling.

Exact play/discard transitions carry cash, used hands and boss history, card
population and Glass loss. Finishing comparisons retain Arm/population costs and
held Gold/Blue rewards against actual inventory capacity and final hand type.
Reward and population value conversions remain heuristics. Full action/resource
records expose private sampled-score labels and actual remaining resources.

## Validation and limits

`tests/advisor_resource_finish.lua` uses synthetic real-scoring Bell/Eye states
and controlled policy fixtures. It covers deterministic composition sampling,
category/enhancement representation, actual final scoring, supported Lucky,
Eye used-hand restrictions, known policy exhaustion, full-family cutoffs,
unknown effects, paid discards/credit, unchanged input/population/inventory,
Blue slot accounting and the274 crossed-world guard.

The synthetic Bell family completed at752 score calls and107,174 structural
classifications; the synthetic Eye family at506 and53,721. These are bounded
fixture work counts, not source-action parity, win percentages or evidence of a
stronger terminal outcome. Focused fixture receipts are under
`runs/resource284_development/`; earlier failed fixture/harness results remain
preserved separately. The parent release records own frozen full regression,
installation and exact-installed verification.

No original-source component, captured replay, seed search, complete attempt,
game control, save access or scheduled continuation was performed for this
slice. No neural or coefficient training ran. Existing closed experiment budgets
remain closed. No verified Jokerless win or numerical odds improvement is shown.

Remaining gaps include broader discard schedules, targeted consumable timing,
opening/boss integration beyond this resource family, better structural
representatives and independently authorized outcome calibration. Retrospective
Bell/Eye cases remain development data. This complete declared family is not a
globally optimal game planner.

Release verification: installed2.84.0-alpha at2026-09-13T15:37:33.3163680-05:00; all52deployment/67frozen files match. Candidate2 and exact-installed regression pass116Lua/275Python with unchanged frozen files/tests. The first full candidate failed only a root UI default-horizon regression (missing horizon displayed2 instead of two); corrected without changing the planner. That failed freeze/log remains in runs/resource284_candidate. Passing evidence is runs/resource284_candidate2 and runs/resource284_installed_validation. Both native DLLs and current settings were preserved; the latest configuration was protected even though the user had changed it since283. Loaded-game activation remains unconfirmed.
