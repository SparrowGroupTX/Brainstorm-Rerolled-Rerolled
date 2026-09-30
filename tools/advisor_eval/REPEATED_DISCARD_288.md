# Repeated observed-discard planning — 288

The 286 development attempts exposed a missing continuation family. At C1
step58, the existing specialist completed its declared comparison but modeled
at most one later discard. Its aggregate play-first result cleared two of four
worlds versus one for the discard incumbent, while losing a world that the
incumbent cleared. The 274 resource guard correctly vetoed that crossed-world
override. Several losing modeled endpoints still had unused discards. This is
a coverage gap, not proof that the observed first discard was a mistake.

C2 actually discarded at steps50,51 and52 before playing. Its step50 specialist
modeled the initial discard followed by a forced play and at most one later
discard; the baseline left one discard unused in all four losing worlds. The
old family could not represent the observed consecutive-discard schedule. Both
new complete development attempts still lost; this change has no new captured
or complete-attempt result at implementation time.

## Runtime change

`Brainstorm/Advisor/resource_finish.lua` retains the existing never/one-early/
one-final schedules and adds two fixed repeated schedules. The early schedule
can discard again after the fixed first action has executed and its replacement
hand has become visible, including after an initial discard. The final schedule
can repeat discards before the final remaining play. Each next selection uses
only the current observed hand and existing public discard candidate function.
The initial play is always executed before any new repeated action.

Repeated discards stop when the visible best legal play reliably clears, the
declared timing condition does not apply, no candidate remains, the drawable
deck is empty, discards are exhausted, or another discard is unaffordable.
Each successful discard must consume exactly one resource. Unknown transitions
invalidate the whole comparison; no non-consuming transition can create a loop.

All five schedules cross every admitted first action and all four common
worlds. The original nine plans are retained alongside up to six new plans.
The 12,000-score and 150,000-classification limits are unchanged. A cutoff at
any point declines the complete comparison, without selecting favorable partial
results. The 274 common-world override guard remains unchanged: five fixed
schedules and one public discard shortlist are not exhaustive global planning.

## Exact reuse and resource safeguards

A private cache reuses completed best-play evaluations of exactly repeated
observed states, with at most128 entries per comparison. Its identity includes
every state field: ordered deck, hand, full population, cash, hands/discards,
blind history, inventory, hand levels and consumable metadata. Strings use typed
length prefixes, numbers use17 significant digits and table entries are sorted.
Cyclic, nonfinite or unsupported values disable reuse. Supported choices are
copied on return; unsupported or truncated work is never cached. The cache is
neither persistent memory nor a hidden future lookup.

Cash/borrowing limits, actual discard/play transitions, Glass and population
conservation, whole-inventory Blue rewards, boss legality, existing tactical
priority and deterministic sampling remain in force. No score budget, hand
recommendation, seed criterion, native DLL or settings behavior changes.

## Validation and limits

Focused validation passed three Lua fixtures: the existing resource fixture
(841 checks), new repeated-discard fixture (197 checks), and decision integration
(19 checks). The ten-card five-hand Bell fixture still completes every admitted
plan:930 scores and113,040 classifications, below the existing limits. The
nine-card Eye fixture uses547 scores and49,530 classifications. These are
synthetic work counts, not measured player latency or terminal outcomes.

The new mechanical fixture uses actual scoring and card transitions with a
declared fixed toy draw tape. It preserves three Kings through consecutive
observed discards until a fourth King arrives; every original schedule fails
the600-chip target, while a repeated schedule clears it. One route requires
the fixed first discard plus two further discards before any play. Another
executes its fixed first play, uses two later discards, then stops with one
discard unused when the visible Four of a Kind clears. The four toy worlds
share the controlled tape; their clear counts are not statistical win odds.

Negative coverage preserves crossed-world rejection, exact budget cutoff,
unaffordable repeated discards, no input mutation, non-consuming transition
rejection, unknown mechanics, boss constraints and Blue inventory capacity.
No original-source component, preserved-state replay or complete attempt was
run to test288. Actual source validation of a later frozen candidate remains
subject to the current cycle's registered one-use limits.
