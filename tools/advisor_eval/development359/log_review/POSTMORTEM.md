# Loaded 2.158 Yorick / Empress audit

This is passive evidence from a user-started product session, not a new experiment.
The frozen prefix of `session-20260916T191059Z-1` ends at 19:17:59 UTC on
2026-09-16 (14:17:59 CDT), sequence 2512. It confirms **Brainstorm v2.158.0-alpha
was loaded**, seed M4BVSY11. The seed was studied previously and is development
data. No terminal outcome appears in this prefix; the last completed blind is
Ante 8 Small. Do not call its progress a complete win or infer improved odds.

Three original journal prefixes, 5,833,895 bytes, were frozen unchanged under
`logs1/frozen/`. They decode to 2,512 events and 385 observations (42,454,044
decoded bytes), with no decoding or teacher-link validation errors. There are
236 action requests and matching callback results. `logs1/manifest.json` records
original paths, exact lengths, SHA-256 hashes and read stability. No player saves,
profiles, policies, scorers, game executables or worker processes were accessed.

## What the logs actually show

- Of 21 cleared rounds with a recorded cash-out, **11 finish with discards left**;
  32 total discards remained at their last plays. This establishes behavior, not
  that every remaining discard would have been safe or valuable.
- There are **24 Empress uses**: 20 before the first play, nine before the first
  discard. The latter includes two uses against Water, where no discard exists.
- Eighteen of the 24 Empress recommendations explicitly say they develop the deck
  while preserving a supported minimum clear. Six are tactical score upgrades.
- It usually retains a last Empress as a Perkeo template. The problem is therefore
  sequencing and value integration, rather than unconditional exhaustion of the
  copying inventory.

## Concrete action chains

| Round | Recorded sequence | Result / relevant public state |
| --- | --- | --- |
| Ante 3 Small | Discard four, Empress 619, Empress 629, play 639 | Straight Flush predicted 10,935 / 3,200; two discards remain. Yorick X3, 13 cards to next level. Row still starts with Perkeo, so Brainstorm copies Perkeo at this point. |
| Ante 3 Big | Empress 713, Empress 723, then three five-card discards, play 763 | It can use all discards: Yorick grows X3 to X4. This is a useful counterexample to a blanket inability to discard. |
| Ante 3 Fish | Tactical Empress 847, development Empress 857, play 867 | Three of a Kind predicted 10,800 / 6,400; all three discards remain. Yorick X4, countdown 21; Brainstorm copies leftmost Yorick. |
| Ante 5 Small | Tactical Empress 1255, development Empress 1265, play 1275 | Straight predicted 29,304 / 25,000; all four discards remain. Yorick X4, countdown 9; Brainstorm copies Yorick. Second Empress does not increase the advertised current score. |
| Ante 7 Small | Development Empress 2079, play 2089 | Flush predicted 142,846 / 110,000; all four discards remain. Yorick X6, countdown 23; Brainstorm copies Yorick. |
| Ante 8 Small | Play 2495 | Flush predicted 221,130 / 200,000; all four discards remain. Yorick X7, countdown 23; Brainstorm copies Yorick. No Empress use is necessary to observe the remaining growth omission. |

`report.json` includes the exact original segment, record ordinal, raw-record
SHA-256, linked advice sequence and advice hash anchor for every row above.
It also includes each cleared blind's final play, cash-out score and unused
discards. The advertised numbers are recorded predictions, not recomputed scores.

The final plays following development uses finish after very small scoring
budgets: 19 evaluations for sequence 639, 14 for 867, 16 for 1275, 19 for 2089,
and 17 for 2495. The advice contains no growth rejection reason. Source review
is required to distinguish priority suppression, copy-value omission, hand
retention safety and genuinely unprofitable growth; the logs alone do not prove
which counterfactual should have been selected.

## Useful limits and an unresolved budget example

Empress changes permanent cards, so using surplus copies before a safe clear is
not inherently wasteful. Using them before a safe Yorick-growth discard can still
be the wrong ordering. A blanket five-card discard can break a clearing Flush or
Straight and should not replace a complete supported comparison.

At Ante 6 Serpent, play 1933 records 140,000 evaluations and explicitly says the
consumable comparison could not fit one full play comparison at this hand size.
It plays for a predicted 37,240 / 120,000. Later, after the last discard, Empress
1964 and 1974 develop beside a clear, and play 1984 advertises 198,860 against
82,760 remaining. This is the same bounded-allocation limitation previously
identified, not evidence that high-cardinality consumable planning is solved.

No captured public state was run through any policy. No hidden simulation,
search, source component, training or live-game control occurred. These action
records remain fallible demonstrations, not expert labels.
