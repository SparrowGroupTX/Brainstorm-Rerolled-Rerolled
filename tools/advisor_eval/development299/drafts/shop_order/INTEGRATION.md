# Fixed scoring order in shop finishing forecasts

Ready for root integration; draft-only implementation. No runtime file was
edited, no source replay/component/search worker ran, and no installation or
terminal experiment was performed by this component author.

## Observed integration defect

Read-only inspection of preserved C01 step138/139 found that `snapshot.jokers`
was the only changed snapshot field. Step138's physical row began with Yorick;
the actual phase-copy action moved Perkeo first before the intended shop exit.
Step139 then proposed selling Perkeo for Flower Pot. Opening mean remained
15972 with six layouts, but whole-blind baseline mean changed 55104 to 17588.5.
The sale endpoint mean remained 59374. Its paired adjustment changed from
-12.814160507197 to +35. These are the already-preserved selected source
trajectory's diagnostics, not a new experiment or evidence that a sale causes
a loss or win.

Cause: ordinary `shop_scoring.profile` evaluated every shortlisted layout for
opening scores, but retained only `order_index==1` for the complete finishing
worlds. A temporary Perkeo shop-exit arrangement therefore lost copied Yorick
scoring throughout the forecast, despite the existing legal scoring reorder.

## Implemented comparison

`shop_scoring.lua` now reuses the already fully scored opening family to choose
one fixed arrangement by aggregate opening mean across all four common worlds.
Ties use stable full physical-row identity. It does not select a different
successful layout per future world. Opening summaries and continuation worlds
refer to the same chosen arrangement. No additional scoring calls or enlarged
layout/score limits are used. Existing startup/destruction preparation keeps its
separate executable single-setup path.

Each ordinary world retains its original physical row and a concrete
`setup_action={kind='reorder_jokers',area='jokers',order=...}` when necessary.
`blind_finishing.lua` validates and applies that exact permutation before using
its opening score. It preserves every physical Joker and pinned position and
rejects hidden, moving, malformed, duplicate-member and no-op setup claims.
The actual projected reorder is the first recorded action in both complete
fixed policies. Per-world `setup_actions`/`action_count` and policy mean counts
include it. Forecasts do not mutate the shop state or create queued actions.
The actual advisor must still publish and execute its fresh legal hand order.

Paired utility charges the difference in projected setup actions at the existing
two utility units per action (existing illustrative duration: 1.5 seconds).
This remains an uncalibrated cost assumption. Sequence completion/dominance
validation now accepts one verified first reorder and requires its action count;
it does not treat that restoration as free. Existing cash, inventory, growth,
population, paid-discard and common-world guards are preserved.

## Merge instructions

`runtime.patch` contains the three runtime diffs. `integration_base_sha256.json`
records the exact shared-file bytes from which the draft was made. Apply only
these changes; do not overwrite intervening root edits with whole draft copies.

Copy `advisor_shop_order.lua` into `tests/advisor_shop_order.lua`, changing its
first `prefix` to `Brainstorm/Advisor/`. No new runtime module or loader/manifest
entry is required. Do not copy the baseline reproduction or regression wrappers
into normal tests; the one new fixture already tests all new behavior. Run the
new fixture and relevant existing fixtures after merging, then root's full
candidate/exact-installed validation and explicit installer procedure.

## Ordinary synthetic evidence

Six fixtures passed against the draft modules in
`tools/advisor_eval/development294/shoporderdraft301a/report.json`: new shop
ordering103 checks, blind finishing41, blind start49, shop scoring60, shop
sequences55 and paired deck104. Wrapper fixtures redirect only the three changed
module paths; the old tests execute unchanged. The initial compilation error
and correction are retained in `fixture_failure_01.txt`.

A fresh synthetic deck with a C01-shaped Yorick/Perkeo/Droll/Brainstorm/Scary
Face row reproduced the integration failure: baseline cumulative mean8276
became2114 after moving Perkeo first. The repair yields8276 in both arrangements,
with equal score/progress/hand/discard resources in every policy/world. It
preserves distinct setup action cost. The baseline source copies and reproduction
fixture remain here only as historical development evidence.

The new fixture also constructs conflicting visible opening worlds: independently
maximizing each world would claim100 everywhere. The fixed global arrangement
retains the actual100/40 worlds and mean70. Additional checks cover existing
arrangement/no extra action, pinned rows, illegal/hidden/duplicate/no-op setups,
unchanged input, shared-cap refusal, actual action utility and sequence rejection
when a reorder is omitted from the action count.

This proves a bounded forecasting consistency repair. It does not establish
the best whole-run strategy, the best global order among all permutations,
future callback/Perkeo timing value, future wins, or any percentage improvement.
No captured C01 state was replayed under this draft. C01 is development data.
