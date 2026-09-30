# Bounded hand-copy preflight: implementation proposal

Status: design only, 2026-09-14. No runtime implementation, captured evaluation,
source worker, search, installation or experiment reservation is made by this
document. The original cache remains preferable to either measured replacement:
M19 was slower in both pairs and M20 had mixed timings with a slower pair total.

## Observed problem and useful insertion point

Preserved C04 completed14 hand reorder decisions costing19.362417900003525
advisor seconds and1,336,246 scoring calls before its eventual timeout. Those
figures classify work by the action finally published; they do not establish
that the action was unnecessary or that all of this work can be saved.

Several rows copied Perkeo during an active hand. For example, steps74,96,113,
127,139 and149 selected a move from Perkeo first to Yorick first after133,771,
139,876,139,834,139,986,139,866 and139,986 evaluations respectively. C04 had no
Burnt Joker in those rows. A separate row improvement followed immediately at
step128, so simply copying Yorick is not a proof that the whole row is optimal.
Step86 chose Droll instead, which is another reason to preserve the main order
search. No captured counterfactual was evaluated for this design.

The smallest useful insertion point is inside `search.run`, after the complete
current held-play family has been evaluated and before expensive discard-world
sampling. This reuses the current-order scores. Putting a fresh search at the
very beginning would repeat those scores and complicate the existing70-call
fast-clear path.

An existing shortlist or enumeration clear returns through its existing path
first. The new preflight is considered only when the current held family is
complete, untruncated, and has no supported clear. It can therefore leave the
existing fast-clear conservation, six-call owned development, twelve-call
growth and shared70-call contract unchanged.

## First supported comparison

The initial family has exactly two physical Joker layouts: the original row
and one deterministic legal layout from `phase_copy.target_order` that moves
active copying from Perkeo to an already owned, active Yorick. This is a
mechanics-specific phase rule, with no challenge name, seed or rank preference.
The proposal does not score other copy targets or call this a globally best
Joker arrangement.

Admission is deliberately narrow:

- One through eight fully public held cards and two through eight visible,
  settled vanilla Jokers; fixed hand order and complete public card identities.
  Concealed-hand handling runs first. Shuffling, Amber Acorn, unknown callbacks,
  invalid/pinned arrangements and changed Dagger victims decline the preflight.
- At least one active copy resolves to Perkeo before, fewer resolve to Perkeo
  after, and more resolve to Yorick after. All other resolved copy targets must
  remain identical. The physical row must contain the same exact card objects.
- If an active Burnt Joker still has its first discard available, decline with
  zero additional scoring. The existing complete Burnt/growth comparison keeps
  ownership of this opportunity. No proposed preflight may merely erase it.
- A clean retry context is required for the first version. A marked/reported
  manual checkpoint continuation uses existing retry arbitration without an
  early preflight; no journal mutation or count renewal is introduced.
- Owned consumables are copied structurally, including every Negative card and
  Observatory-relevant Planet. The preflight neither consumes nor synthesizes
  any card. Missing public inventory metadata, unknown hand/scoring callbacks,
  or an unsupported score in either layout rejects the entire comparison.

Before evaluating the new layout, enumerate the same legal physical subsets
of one through five cards for both rows, including forced selections and the
Psychic's minimum size. Reuse only exact current-decision current-row results
with an unchanged full snapshot identity. Score every corresponding candidate
subset; no promising-prefix return and no order-dependent candidate sampling.
At eight held cards there are at most218 subsets per row.

Publish only if the changed layout has at least one exact supported held clear,
every admitted original legal subset is legal in both rows, and every paired
score is non-decreasing. At least one clear must be new. Unknown randomness or
an expected value alone cannot qualify; version1 can simply reject uncertain
scores rather than introduce a second lower-bound comparison mode.

Require separate equality/non-degradation for the scorer's already supported
non-score outcomes on paired same-card plays: physical destruction/Glass
exposure, cash changes, hand development, permanent Joker development and held
card/inventory resources. This cannot be replaced by a scalar utility bonus.
If those fields do not form a complete callback receipt, decline that row
family. Do not declare an unmodeled play/discard effect absent. The actual
preflight action changes only the order; it does not execute any modeled play.

For discards, the first implementation must either obtain exact same-subset
`after_discard` receipts in both layouts for every legal current discard, with
physical order restored and all other fields equal, or decline while discards
remain. The latter is the smallest first slice and keeps Yorick's five-card
growth choices intact. These transition checks must never assume Purple Tarot
generation, Mail/Faceless income or copied growth away. Active first-discard
Burnt remains excluded even if another comparison appears attractive.

## Action and refresh contract

The only published action is the supported Joker reorder, charged as one real
setup action. It receives a diagnostic held-clear witness and complete paired
receipt, not a pending play command. It does not tell the user to end the blind
before using remaining discards. A new public snapshot and ordinary decision
are mandatory after successful reordering; owned-consumable development,
Yorick/Burnt growth, conservation and normal order search still choose what to
do then. The witness cannot authorize Execute on a later state.

Strictly increasing Yorick copying while strictly decreasing Perkeo copying
prevents this preflight from undoing itself. A later ordinary provider may
choose another useful order, as C04 step128 demonstrates. Log that extra action
rather than treating restoration as free. Evaluate total decisions and actual
setup actions when judging performance, not just the first cheap response.

For the initial no-discards scope, a new held clear converts a current-row
nonclear into a possible clear after one setup action. This is a useful local
choice but still does not prove minimal actions over all layouts, better
subsequent blinds, or higher run win probability.

## Budget and fallback

Use the existing per-decision score cache and search evaluation ledger. No new
ordinary reserve, extra cache, score cap or independent module budget appears.
The candidate row adds at most218 score calls; original complete held scoring
adds at most218 plus the existing at-most-four lower-bound calls. Thus the
proposed fully paired success path has at most440 scoring evaluations for this
scope and is an ordinary reorder decision, never labeled a70-call fast clear.
It must still obey a smaller user-supplied cap. Precompute the entire candidate
family cost and decline before evaluation if it cannot fit.

On a complete failure to improve, or a discovered unsupported candidate, keep
the original row and continue the existing search from its existing held-score
cache and deterministic RNG state. All work already spent remains in the same
ledger, reducing the remaining140,000 allowance; specialist25,000 consumable
and other local limits still intersect that remainder. Incomplete candidate
work cannot supply a replacement action. A preflight callback must never call
the normal `finish` helper if that would also trigger cycling evaluation.

The new internal early result needs explicit `reorder_only` handling in
`decision.run`: it bypasses irreversible specialists on that snapshot, passes
through the normal freshness/execution guards, and requires the next full
decision. It must not accidentally call the post-decision phase wrapper again
or stack its30-call allowance on the preflight result. All non-preflight
success/fallback paths retain their existing complete specialist comparisons.

## Concrete implementation and fixture plan

Prefer a detached `hand_copy_preflight.lua` module plus a small callback edge
from decision to search. Expose immutable current held-family results and an
evaluation function that spends the existing ledger; do not export live Card
objects, game callbacks or RNG. Extract only the existing pure phase legality
helpers needed by both modules. Use a narrow transition capability receipt;
do not broaden vanilla identity admission as a substitute for callback support.

Before any captured experiment, routine fixtures must establish:

1. A Perkeo-copy row with no current clear and a supported new copied-Yorick
   clear returns only a reorder after the complete paired family, with equal
   input/cash/inventory/population and exactly counted setup action.
2. First-discard Burnt, remaining unsupported discard effects, mixed/Negative
   inventory metadata gaps, hidden cards, pins, Acorn and changed Dagger victim
   fail closed. Perkeo's copy pool remains physically intact in success too.
3. A high-value subset near the end, an unsupported last subset, or one losing
   paired subset prevents a first-candidate/prefix success. Bell forced card
   and Psychic legality are respected in every corresponding row.
4. Fallback preserves RNG state, held scores and exact cumulative counts; small
   caps finish whole admitted families or decline. Ordinary decisions never
   exceed140,000 and existing fast clears never exceed70.
5. Fresh advice after reorder can still use a consumable, spend Yorick discards
   or prefer a different scoring row. No cached witness becomes a play action,
   no preflight bounce occurs, and marked retry contexts remain untouched.
6. Full lower-bound/cash/development/Glass/Blue/Observatory receipts disagreeing
   in any protected field reject a score-only dominance claim.

Only after a coherent implementation and these fixtures should a separate
one-use captured comparison be proposed. The first registration should include
both a supported success and a fallback at the exact newly installed policy,
complete decisions after any reorder, total setup actions and total scoring
time. C04 is dependent development data; it cannot be an unseen terminal test.
No numerical speedup or survival improvement is projected by this design.
