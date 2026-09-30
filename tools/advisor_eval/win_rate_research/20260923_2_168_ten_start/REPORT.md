# Loaded 2.168 win-first ten-start cohort — 2026-09-23

This is the user-started `session-20260923T061952Z-1`, cut off at
2026-09-23T07:04:28Z / sequence 18770. The 26 original journal segments
(43,531,171 bytes) are frozen unchanged under `capture/frozen`; hashes,
contiguity, and source addresses are in `capture/manifest.json` and
`capture/events.jsonl`. `review_summary.json` records the clean converter,
callback settlement, profile and 105-file runtime checkpoint checks.
There was no captured-state policy/scorer evaluation, game control, original
source execution, hidden search or simulation in this audit.

The public journal stamps say `Brainstorm v2.168.0-alpha` and all 2,934 recorded
states select `perkeo_yorick_win_v1`, without a collection objective. Version
stamps are evidence of the loaded label, not proof of loaded-byte identity.
The repository and installed 2.168 runtime matched the frozen manifest at the
audit start. Search found the normal conditional Charm opening ten times; all
ten starts skipped the actual tagged Small Blind, then selected two visible
Soul cards yielding Yorick and Perkeo. Search used the recorded 9,000 ms cap
and 32 native threads, with no additional tool-started search. Ten distinct
seeds were used, disjoint from the prior audited 2.166 batch. Twelve
`player_callback` entries have empty action payloads; the 1,753 gameplay
actions were `auto_run` sourced. Empty callbacks are not evidence of a
strategic manual override. No other intervention was established.

## Operational outcomes

| Start | Seed | Outcome | Last blind and chips / target | First copy Joker |
|---:|---|---|---|---|
| 1 | 7RM1C3QV | win | Verdant Leaf 426,780 / 400,000 | Ante 2 Blueprint |
| 2 | EDOXL8QV | loss | Ante 6 Big 52,932 / 90,000 | none |
| 3 | XIE6E9QV | loss | Ante 5 Small 24,601 / 25,000 | none |
| 4 | OEJVL9QV | loss | Ante 1 Manacle 536 / 600 | none |
| 5 | R1QBBRQV | loss | Ante 3 Window 3,060 / 6,400 | none; engine destroyed |
| 6 | 7P8I1XQV | win | Verdant Leaf 408,960 / 400,000 | Ante 3 Blueprint |
| 7 | 8MV6GYQV | win | Violet Vessel 1,861,470 / 1,200,000 | Ante 3 Blueprint |
| 8 | N7F6CZQV | loss | Ante 5 Mark 40,020 / 50,000 | none |
| 9 | Q3QIB1RV | win | Crimson Heart 416,812 / 400,000 | Ante 2 Blueprint; Ante 5 Brainstorm |
| 10 | RQT8M2RV | win | Crimson Heart 433,554 / 400,000 | Ante 3 Brainstorm |

Operational yield is **5 wins / 10 starts**. All ten have terminal win/loss
classifications; zero error, unsupported, timeout or interrupted outcomes.
This selected cohort is not a calibrated win rate or a causal test of 2.168
against 2.166. The five wins all acquired a copy Joker by Ante 3; none of the
five losses did. This correlation makes copy acquisition a high-value
diagnostic question, not a command to buy any visible Blueprint at any cost.

## Backward trace of the losses

**Run 5 is a confirmed avoidable decision-class defect.** At observation
6717 the Ante 3 Spectral pack offers Hex and Ouija. Publicly visible row:
Fortune Teller and Perkeo ordinary; Banner and To Do List Eternal; Yorick
Foil, ordinary, x2. Advice 6720 chooses Hex with a warning only, zero
evaluations, and action 6723 executes it. At settled observation 6728 only
Polychrome Eternal Banner and Eternal To Do List remain. Yorick, Perkeo and
Fortune Teller were destroyed. The run then loses the Ante 3 Window
3,060/6,400. The exact action raw-record SHA256 is
`d9e8bf3bef3897c7c33cabcad82ccdcf2ec68de611a491ff7b85f83a745f878d`;
the segment is `...-000011.brj`, ordinal 734. `strategy.lua` gave Hex a
generic positive rating even though `pack_scoring.lua` has no exact Hex
transition. This does not prove that skipping Hex would have won the run, but
the loss of the engine was predictable from the public row. Ankh shares the
warning-only valuation path; the recorded Ankh offers did not execute.

**Run 2 had a weak late scoring engine, but no proved rejected upgrade.**
Yorick reached x4 and the row never acquired Blueprint/Brainstorm. At Ante 5
shop exit 4184 an affordable Brainstorm required replacing a full-row Joker.
The receipt compared the visible supported one-sale endpoints and rejected
them on build merit even where four sampled opening worlds favored the new
row (e.g. Popcorn replacement ratio 1.621). Those samples are uncertain and
the full-run effect of selling Popcorn is unknown. The final Ante 6 Big used
all discards and hands: High Card 60, Straight 49,248, Flush 2,592, Pair
1,032. Two Hermits remained at $1. The Hermits could have yielded cash if
used earlier, but the record does not show a purchasable winning use of that
cash. Perkeo's Lovers pool was used repeatedly earlier, not simply hoarded.

**Run 3 was close, with unused earlier growth but no certified safe
counterfactual.** At Ante 3 exit 5179, rental Eternal Blueprint was affordable
at $1 but the full five-Joker row required a sale; the complete receipt gave
each supported replacement negative merit, including Odd Todd replacement
at ratio 1.125 over four uncertain worlds. Death was copied and used through
Antes 2–4; none remained in the final blind. Eight cleared Ante ≤3 rounds
retained 18 discards total while Yorick stayed x1 until Ante 3. The final
Ante 5 Small used all discards and four hands, ending 399 chips short. A
different earlier discard might have grown Yorick or might have lost a clear;
the public logs alone do not certify one.

**Run 4 died to an early boss before a durable scoring row formed.** The
searched opening worked. An Ante 1 Buffoon choice added rental Zany Joker,
whose +Mult requires Three of a Kind. The next pre-Manacle shop exit 5883
retained $4; complete paired samples in the advice said only some composition
worlds cleared the boss. All three discards were spent in the Manacle and the
four hands scored 248, 32, 200, 56, leaving a 64-chip deficit. The journal
does not establish an affordable, supported alternative that would clear.

**Run 8 lost under public concealment.** The row had Yorick x3 and no copy
Joker. Ante 3 Blueprint appeared with $4 against a $10 cost and a full row;
only selling Perkeo made it immediately affordable, and that endpoint's
build merit was strongly negative despite a twofold sampled opening score.
The player-observable Mark hand advice explicitly used concealed-card
sampling. Its final four plays yielded 5,814, 19,260, 12,240, 2,706, ending
9,980 short with no discards or hands. Hidden card identities were never
recovered from later events; the record cannot certify a superior sequence.

Across all ten runs, 34 of 72 cleared Ante ≤3 rounds retained at least one
discard, 77 retained discards total. Winners also retained early discards.
This measures possible investment exposure, not 77 safe growth actions.
There were 44 consumable sales, proving the stock manager was active. There
were 47 Ante ≥6 shop exits, 33 with multiple held consumables, but no
Observatory snapshot. Copy-pool quality and action cost remain context
questions, especially in losing run 2. `deep_dive.json`, `rounds.json`,
`actions.json`, `copy_opportunities.json`, and `replacement_receipts.json`
contain the compact action-linked evidence.

## Diagnosis and repair scope

Rank 1 is the supported Hex/Ankh destructive-pack admission defect. Rank 2
is the source-proven final pre-boss Perkeo copy-horizon overcount (WR-008):
the stock evaluator valued two shop exits at an Ante 8 Boss shop where only
the current exit can occur before the win objective. Four wins in this cohort
reached such an exit with active Perkeo and stock; this is exposure, not a
demonstrated harmful action. Rank 3 is copy-Joker acquisition and resource
allocation: missed offers in runs 2, 3 and 8 warrant a calibrated
replacement study, but current receipts and uncertain sampled worlds do not
justify a blanket threshold reduction. Rank 4 is early discard investment;
an eligible safe alternative is not established from retained counts. Rank 5
is joint concealed-hand and consumable planning; no execution mismatch or
hard stop was found in the recorded batch. WR-007 terminal generator rescue
did not appear in these five terminal losses, so this cohort adds no support
for promoting it to a release fix.

The repaired source now rejects Hex/Ankh when any publicly possible survivor
would destroy an owned non-Eternal Joker, including the batch-shaped Yorick /
Perkeo row. Known safe single-Joker and all-Eternal cases remain selectable.
It also caps the win-first final pre-boss shop's projected copy events to the
current visible Perkeo effect count. Manufactured fixtures reproduce the
decision classes; they do not demonstrate that either change raises full-run
yield. Ouija's random rank consolidation and hand-size cost, copy-replacement
valuation, and terminal-generator chance remain unresolved comparisons.

Release 369 (`2.169.0-alpha`) is installed with exact 89-file deployment and
105-file runtime/dependency matches. Frozen candidate and exact-installed
gates each passed 240 Lua fixtures and 391 Python tests; configuration and
all seven existing native DLLs were preserved. No loaded 2.169 observation
or post-repair run has been recorded in this audit.
