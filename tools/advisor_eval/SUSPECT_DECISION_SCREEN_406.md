# Suspect-decision screening406

This is an offline review queue for an explicitly supplied, hashed **copy** of
public BRJ2 journals. It automatically identifies decisions worth inspecting;
it does not execute the advisor, reconstruct hidden draws, label expert moves,
change gameplay, or attribute later losses to earlier choices. Runtime remains
installed checkpoint404, version2.195. The new user-started game is unaudited.

Implementation: `flag_suspect_decisions.py`. Manufactured acceptance:
`tests/test_advisor_suspect_decisions406.py`. Exact tooling/test/interpreter
provenance and full452-test Python gate: `development406/validation/`.
Current checkpoint: `TOOLING_CHECKPOINT_406.md`.

## Rules and useful negative controls

| Rule | Trigger after physical effect confirmation | Why the decision might be reasonable |
| --- | --- | --- |
| `copy_offer_pass` | Visible Blueprint/Brainstorm remains unowned when an assessed opportunity closes; direct slot, affordability and one-round rental reserve fit, with a visible watched engine target. | Survival, permanent slots, recurring costs, target usefulness and future purchases still matter. This narrow rule cannot prove a profitable full-row replacement. |
| `invisible_offer_pass` | As above for Invisible, with a sellable card and nominal time to mature before another useful round; retained pool is recorded. | No immediate scoring, random copy pool, $8 opportunity cost, expiration or a future sale can make it inferior. No selected random target or eventual sale is assumed. |
| `pack_merit_reversal` | Final Joker-pack choice acquires a card at least10 merit and20% below another admitted complete direct-choice row for the same target in the same receipt. | Compact receipts omit shared-world identity and survival arbitration. Mean, utility and survival are different quantities; this is not dominance. |
| `sale_plan_reversal` | A confirmed sale explicitly names a physical follow-up offer, but the next purchase chooses another while projected offers, retained row, round, limits and expected cash remain the same. Pack comparison requires one choice left; shop comparison requires one free slot. | A fresh evaluation may legitimately change its mind. The record is a plan inconsistency hypothesis, not proof the original plan was better. |
| `short_discard` | A confirmed discard selected1–4 cards. Records the held hand, growth/copy Jokers, Death, resources, risk/growth receipts and advice. | Retain a clear, a draw structure, held rewards, valuable seals or a Death source. An eight-card hand reserving five scoring cards has only three spares. Five safe legal discards are explicitly **unproved**. |
| `unused_discards_at_clear` | A linked play reaches the same round's cash-out with chips at least the prior blind target and discards remaining. Boss cash-out may advance ante by one. | Growth can be unsafe, costly, mature or useless on the final boss. Finishing with discards is not automatically waste. |

All six produce `review_hypothesis`, never `confirmed_defect`. Each includes
observation, advice, request, marker and physical-effect anchors with archive
session, segment, exact ordinal, sequence and original-event SHA256. Full
recorded advice is retained beside a bounded **projection** of public state;
exact originals remain in the supplied archive. The projection is not a complete
state for replay. Hidden/face-down identities are omitted even if supplied.

## Causal and integrity requirements

An explicit `run_started` must precede an assessed action. Scope includes archive
session, collection ID and public run instance. Requests must bind an earlier
observation and current matching advice by explicit IDs, with the actual
`details.input.action`. Seed equality and array positions never join runs.
Indices in sale plans resolve against the original observation to physical
offer IDs; later reindexing alone does not invalidate the plan.

Callbacks and `state_after_actions` markers are insufficient alone. Acquisition
requires later ownership, discard requires removed physical hand IDs and a
spent discard, and round completion requires the round-evaluation phase and
recorded target clearance. Offer closure requires a supported endpoint:
pack to shop/blind/hand, shop to blind, or a shop reroll with a new nonempty
disjoint row and its visible cash debit. Transient `other`/empty arrays are not
passes. A new action, run end, identity boundary,128-event effect limit or
truncated tail cannot be used as evidence that pending effects succeeded.

First choices in multi-choice packs are outside ranking/plan-reversal scope;
coverage counters record them. Taking the preferred Joker second is therefore
not reported as a missed purchase. Missing/truncated receipts, full-row sales,
missing resource fields, credit-card sale effects and Invisible random-copy
sales are explicitly outside these narrow comparisons. Debuff alone is not
expiration. Pack selection costs zero; opening the pack is a separate decision.

Input admission validates manifest size/hash/path bounds and hashes the exact
consumed decode stream, not just the path before/after. The existing BRJ2 decoder
checks frame bodies, original event hashes and local continuity; this tool also
checks available cross-file sequence, predecessor and segment continuity.
First-fragment predecessors outside the supplied files remain unknown. Successful
parsing never claims the complete session was supplied.

Bounds:64 files,128MiB per file,256MiB physical inputs,1GiB decoded events,
100000 events,128 cached observations and128 cached advice records,128 scopes,
128 cards per projected area,128-event effect windows,10000 rule hits, up to1000
retained ranked flags and64MiB rendered JSON. Default retained flags:200. Reaching
a hard input/work cap fails without a trusted report; ranked output omission is
explicitly counted. No directory discovery, game polling or scheduling occurs.

## Use after preserving a completed public session

From the repository root, supply an existing capture manifest with ordered
`segments` entries containing `name`, `bytes` and `sha256`. The input directory
must be the copied journals, not the live journal directory. Use a new output
directory; existing output is never overwritten.

```powershell
python tools/advisor_eval/flag_suspect_decisions.py --copy-dir COPIED_JOURNAL_DIRECTORY --manifest CAPTURE_MANIFEST.json --output NEW_REVIEW_DIRECTORY --max-flags 1000
```

Outputs are `report.json`, a compact `REPORT.md` queue, and an initially
unreviewed `adjudication.json`. Source hashes, precise inputs, thresholds, rule
version, bounds, suppressions, omitted flags and unresolved tails accompany the
results. The report is deterministic for the same source and inputs.

`requests_in_open_runs` and `linked_current_advisor_requests` describe causal
coverage. Pack receipt counts describe **final-choice** ranking coverage.
Watched-offer closure candidates are not an all-visible-offer denominator.
`unconfirmed_actions_*` means this screen did not confirm its narrow effect
predicate; it is not a claim of callback failure, failed execution, or missing
settlement in the separate complete-session audit. Many actions, such as
consumable use and reorder, have no effect detector here.

## Turn a queue into supported improvements

1. Read coverage first. Rank by inconsistency, useful remaining horizon and
   available public evidence. Review one example per context group before
   inspecting hundreds of similar short discards. Groups are not established
   shared causes, and priority is not a probability or predicted lost win.
2. Extract the exact anchored local episode with `inspect_player_log.py`.
   Trace observation → generated candidates → valuation → admission → budget →
   arbitration → settled physical action. Keep missing stages unknown.
3. Write a competing explanation before deciding. For Invisible, inspect the
   entire retained pool, waiting cost, next-blind security, cash and planned
   later sale. For discards, inspect the retained clear, boss restrictions,
   marginal Yorick/Burnt benefit, Death source, seals, cash and final-ante horizon.
4. Use later public facts only to describe the resource trajectory. They can
   show expiration, cash pressure or a missed later offer; they cannot establish
   the unobserved alternative or justify hindsight-dependent policy advice.
5. Adjudicate as `confirmed_defect`, `reasonable_tradeoff`, or
   `insufficient_evidence`, with a reason and references. Save reviewed results
   separately from the generated initial ledger. Sample unflagged eligible
   decisions too, to check omissions. Track review yield by rule rather than
   treating flag counts as error rate; neither precision nor recall is yet measured.
6. For a supported cause, manufacture a positive and a nearby negative case.
   Repair the smallest complete comparison, then exact-freeze and fully validate
   combined runtime bytes under the existing release boundaries. Measure later
   loaded-game outcomes separately; one corrected local choice proves no win gain.

Do not auto-tune weights from flags, replay captured states through the policy,
or force every discard. Those actions are not part of this tool or authorization.
The next useful input is the user's completed new session, once reported complete
and preserved. Existing closed experiment budgets and all game/save/release
restrictions remain.
