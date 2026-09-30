# Detached complete hand-copy preflight

Prepared for parent review; not staged, installed, registered or source-tested.
The315 directory label is prospective. Exact release numbering belongs to the
parent. Existing runtime files and old experiments were not modified.

## Behavior

The advisor can currently finish expensive discard/continuation search before
deciding to move copying away from Perkeo during an active hand. This draft
considers one reversible Perkeo-to-Yorick copy setup after the existing full
current-hand score family and before that expensive continuation work.

It admits only Perkeo, Yorick, Blueprint, Brainstorm, Droll Joker and Supernova,
with ordinary Joker editions, public settled identities, complete population
and inventory metadata, a legal physical order and supported deterministic
playing-card effects. Pins and existing phase-order legality still apply. The
actual resolved copy routes must change from Perkeo to Yorick; all other copy
routes stay identical. Other Jokers, including Burnt, are outside this slice.

The entire legal held-play family is paired in both rows. Every original score
must agree with its reused score, all changed scores must be non-decreasing,
and at least one previously nonclearing subset must become a supported clear.
Every paired `after_play` state and effect receipt must be structurally equal
after restoring physical Joker order and normalizing only accumulated chips.
Cash, hand levels/history, physical Yorick counters, every owned consumable and
its metadata, Blue/Gold-held card identities, deck/population and destruction
are all retained. Missing/unknown/uncertain outcomes reject the whole shortcut.

With discards remaining, every legal current discard also has to produce equal
full `after_discard` states/effects after restoring only Joker order. Yorick's
counter grows once per physical discarded card in both rows. This is not a
predicted replacement draw. Possible unprovided Purple Tarot generation is
rejected before comparison; a genuinely full loaded inventory can qualify
because the exact source-matched transition generates nothing in either row.
The first-discard Burnt strategy is never bypassed because Burnt is excluded.

The published action is only a Joker reorder. It costs one actual setup action
and requires a new snapshot and fresh advice before any play, discard or use.
The diagnostic held-clear witness is not an executable continuation. The real
growth provider can still select a full five-card Yorick discard after that
refresh, as the focused fixture verifies. Strictly moving copies off Perkeo
prevents this preflight from bouncing itself back on the next decision.

## Source and model scope

The existing preserved `planet_pool_source1/source/card.lua` matches the M15/M16
original member SHA5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453.
Read-only review used its Perkeo ending-shop branch around2413, Yorick's physical
discard guard around2788, ordinary main-score XMult/typed-Mult around3653,
Supernova around3731 and copying routing. No executable ZIP was opened for this
work and no original-source code was executed.

`scoring.after_play` provides the already implemented deterministic state before
replacement draws; `after_discard` provides its state before replacement draws.
The six-key admission avoids unmodeled later generator/growth callbacks. The
state comparisons protect the entire existing metadata rather than deleting
fields to obtain equality. Hook, Crimson Heart, hidden/unknown hands, unsupported
editions and random Glass/Lucky outcomes remain outside this draft.

This is complete for the declared current-card/current-layout family. It is not
all Joker permutations, all future hands, end-of-blind cashout, remaining-blind
survival, a source-qualified whole adapter or a higher run win probability.
Unknown mechanics are not assigned zero cost. All current owned consumables,
including Negative cards and Observatory Planets, stay physically present.

The complete incoming snapshot must be plain acyclic data with finite numeric
values, no metatable (including a locked false metatable), callable value or
userdata/thread. Limits are32768 value nodes, depth12,4096 bytes per string/key,
512KiB aggregate string/key bytes,128 population cards,128 deck cards and32
owned consumables. Repeated acyclic aliases count on each traversal, matching
the cost of detached copying. Oversized input declines as a whole; no owned card
or metadata is removed to fit. Resource equality has its own depth/node/cycle
guards, so malformed returned states cannot make comparison recurse forever.
Known deck keys and an explicit supported modifier boundary reject undeclared
modded effects; the actual Gold scaling/shop flags and no-Small-reward metadata
remain admitted.

`C04_INPUT_SIZE_REVIEW.json` records a read-only scan of198 preserved completed
observations: at most9001 value nodes, depth7,92-byte strings,79163 combined
string/key bytes,52 population/deck cards and five owned consumables. Hand
observations peaked at7008 nodes. Some recorded hands had14 cards and remain
outside the explicit eight-card preflight scope. These are source-data shape
counts, not a replay or a finding that all those states qualify. New312 copy
metadata can differ; larger observations safely use the ordinary advisor.

## Bounded work and accounting

At most218 legal subsets exist for eight cards played up to five at a time.
The original hand search scores at most218, plus its existing at-most-four
lower-bound calls. The preflight adds two `after_play` transitions per legal
subset, each calling the scorer once, for at most436 new scores and658 total.
The fixture's ordinary eight-card case uses exactly654 actual/report-counted
scores. It is an ordinary decision under140,000, not a70-call fast clear.

The whole candidate scoring cost must fit before the first paired transition.
Every attempted call remains charged on success or failure. The original RNG
and held-score cache are reused on fallback; no independent reserve or reset is
introduced. Existing25000 consumable and other specialist limits still intersect
the shared remainder. Successful reorder-only results skip the later specialist
and phase wrappers; a new decision owns their next use.

Supported remaining discards add at most436 explicitly counted non-scoring
transitions. `after_discard` does not score for these six keys. The row excludes
Burnt's classification branch and all random generation. It yields periodically
without consuming RNG. This extra allocation/transition cost is real work,
separately visible in diagnostics; no timing improvement has been measured.
In particular, `after_play` clones the full detached state, so cost on large
source snapshots may differ materially from these small synthetic fixtures.

Existing shortlist/enumeration clear handling happens before this path. The
existing70-score fast-clear allowance, conservation and owned development/growth
paths therefore remain intact. Lower user caps decline incomplete families.
The prepared classification-cache counters do not include the internal raw
`after_play` scoring calls; the ordinary evaluation ledger and outer raw scorer
counter do include them, and the new diagnostics report those calls explicitly.

## Files and integration

- Add `Brainstorm/Advisor/hand_copy_preflight.lua` from this directory.
- Merge the small `search.lua` callback immediately before the ordinary
  discard/continuation entry. It returns only after the complete paired family,
  and its local `after_play` function charges the existing score ledger.
- Merge `decision.lua`: prepare the eligible family, pass the callback into
  search, return a proven reorder-only result, and skip the post-decision phase
  wrapper for that result. Clean retry metadata remains allowed; matched,
  pending, unavailable and active retry contexts use their existing path.
- Add only `A.hand_copy_preflight = module('hand_copy_preflight')` after loading
  phase_copy in `runtime.lua`. The full runtime draft is a review aid. If its
  recorded base hash differs from current runtime, merge that single load line
  instead of replacing newer runtime work.
- Stage `test_preflight.lua` as a discoverable fixture, updating its module paths
  from this detached directory to the actual runtime. The legacy wrapper is
  preparation-only; the actual existing fixtures will exercise installed code.
- A future source adapter must additionally load `modules.hand_copy_preflight`
  and include it in its graph verifier. No module-local wiring is required;
  `prepare` receives the shared modules table. Existing C05 remains frozen312.

The manifest names exact draft and base hashes. Parent owns full regression,
release/installation/installed-byte verification and any new captured/source
experiment registration. Nothing here authorizes another experiment.

## Relevant routine validation

Two fixture entry points passed:205 new checks plus416 checks in seven existing
fixture bodies redirected only to the detached search/decision files. Coverage
includes exact work accounting, full/late resource failure, incomplete/duplicate
families, real post-refresh five-card Yorick growth, unchanged inventory metadata,
supported full-Purple-pool behavior, first-Burnt exclusion, Psychic five-card and
known Bell forced-card families, retry guards and the original70-call path.
Malformed/cyclic/oversized/nonfinite/metatable inputs are rejected before any
score, and a cyclic returned resource state is rejected within the bound.

No captured decision, source attempt, seed search, terminal result, installed
activation or player achievement progress was produced by this draft.
