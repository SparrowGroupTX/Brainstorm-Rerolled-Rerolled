# Active-session analysis and repair 446 — 2026-09-28

Candidate **2.221.0-alpha is fully validated and not installed**. It combines the
uninstalled445 Acorn repairs with two newly supported446 fixes. Installed444 /2.219
remains unchanged while Balatro is running. The live game was never controlled.

## Evidence cutoff and outcomes

The verified public copy is `log_copy/captures/001`, session
`session-20260928T183037Z-1`, through event13,111. All five starts identify loaded
2.219. This is a partial session, not a completed ten-run marathon:

| Run | Status at copied cutoff | Evidence |
|---|---|---|
| 1 | Loss | Ante2 The Club,1,086/2,000 chips; zero hands/discards left, end621 |
| 2 | Win | Amber Acorn,438,152/400,000; zero discards left, end4866 |
| 3 | Win | Amber Acorn,570,570/400,000; three discards left, end8551 |
| 4 | Stalled retirement | Ante5 Small Blind; seventeen consecutive reorders; end10497 |
| 5 | Unfinished game | Ante8 shop at observation13109; no run-ending evidence |

The fourth outcome is an abandoned stall, not a loss or normal game completion.
Neither these outcomes nor manufactured tests establish a population win rate.
Later live events were not silently included in this fixed-cutoff analysis.

## Confirmed defect: Burnt/Yorick order oscillation

Requests10319–10486 contain17 consecutive Joker reorders with no play/discard:
the row repeatedly switches between copying Burnt and restoring Yorick. Hands5,
discards3 and round chips0 remain unchanged. The bot retires for
`semantic_progress_stalled`, with no actual terminal result.

The Burnt arrangement is legal and its recorded retained-finish proof completes.
On the following observation, the normal scoring-order branch uses139,993 of the
140,000-call allowance. Seven calls remain, too few for the paired held-card
comparison plus retained-discard proof. The independent Yorick reorder survives
arbitration. In the opposite row the Burnt proof again fits, causing the loop.
This is a budget/arbitration failure, not evidence that Burnt is a bad purchase.

Repair: reserve at most18 existing calls across search and all specialists for
eligible visible first-discard Burnt copying, including an already correct row.
The phase uses the residual shared12-call growth allowance; earlier optional
growth/development yields priority to that comparison. Small callers retain an
incumbent pass, and only actual fast-clear results get the70 aggregate cap.
There is no larger search budget or stale action commitment. Fresh observation,
complete held-finish/resource proof, pinned/Dagger rules, necessary consumables
and retry arbitration remain binding. Failed phase comparisons now export their
scope, required/remaining/reserved work and growth work for future diagnosis.

Manufactured saturated decisions now prepare Burnt and, on fresh advice, perform
a full five-card discard instead of reversing the order. Physical transition
checks confirm two Burnt levels and one spent discard. Nonwinning fishing and
later Yorick restoration remain covered by unchanged existing fixture420.
This proves the mechanism under fixture conditions, not that the retired run wins.

## Confirmed defect: sale plan promises a reserve-ineligible purchase

Run5 observation11010 shows$9, an offered$10 Brainstorm, a rental Shortcut and a
retained rental Swashbuckler. Request11016 sells Shortcut with advice to buy
Brainstorm. Observation11020 confirms$10 and Shortcut gone. Request11027 leaves
the shop: direct acquisition now reports projected cash$0 against a$3 rental
reserve. The original-row replacement merit admitted the sale, while the fresh
direct comparison would not prioritize its advertised purchase.

Repair: a copy-funding sale with an already vacant Joker slot must satisfy the
same projected raw-cash reserve as direct copy acquisition. Borrowing capacity
does not count as cash. A high original-row merit cannot bypass this endpoint
check. Fully funded sales still produce an actual buy after a fresh observation;
full-row replacement comparisons and core-sale protections are unchanged.
This prevents an inconsistent liquidation. It does not assert that this historical
Brainstorm could safely be bought with$0, or remove the rental requirement.

## Discard accounting and remaining gaps

The qualified settlement screener confirms225 discards and1,038 discarded cards:
174 batches of5,21 of4,25 of3,4 of2 and1 of1; **4.61 cards per discard**. There are
81 qualified round-clearing plays, of which6 leave all3 discards unused (18 total).

Across80 completed rounds with qualified closing evidence and positive initial
discards, there are1,023 discarded cards: **12.79 cards and2.775 discards per
round**, against a12-card target. Fourteen of those rounds fall below target.
Two Water rounds had zero available discards and are excluded. Run2 round14 has
15 confirmed discarded cards but no qualified play-to-cashout join in the screener,
so it is excluded from the round average. The stalled run4 round12 is censored.
These exclusions and the one loss are explicit in METRICS/ACCOUNTING notes;
the aggregate does not hide the unused-discard failures or claim all rounds pass.

The six untouched-discard clears remain unresolved:

| Requests | Recorded blocker | What is still needed |
|---|---|---|
| 7331,7578 | No shortlisted discard retained a supported clear/resources | A concrete safe alternative or an expanded bounded proof; high current score alone is insufficient |
| 7430,11998,12438 | A Joker lacks a monotone public held-card floor | Identify/qualify the exact visible canonical row; do not assume replacement draws preserve Raised Fist or Steel effects |
| 8534 | Complete public Acorn family exceeds12 retained-proof scores | A sound smaller complete certificate within existing bounds |

Five cases occur before later blinds; one is the final boss. They are not claimed
repaired by the Burnt budget change. Astronomer support and dynamic held minima
are next source-level leads, not established optimal discard alternatives.

## Other checked strategy signals

- Four visible copy purchases settle. The run1$10 Brainstorm at$9 was unaffordable
  without a core sale; that is distinct from the run5 funding inconsistency.
- Fifteen of19 observed Buffoon offers are opened. Unopened packs are not all
  automatically mistakes: capacity, current money and retained obligations matter.
- The one pack merit/score conflict chooses Burnt over Greedy Joker (higher
  immediate opening score). Long-horizon first-discard scaling supports the choice;
  the scalar conflict alone is not proved regret. No valuation reversal was made.
- Invisible Joker at2238 appears in a full five-Joker row that already includes
  Blueprint, Yorick and Perkeo. There is no qualified better replacement/duplication
  witness; the pass remains unproven, not automatically corrected.
- Seven Death requests copy three Mult Kings, one plain Ace, one Bonus Jack and
  two Steel9s, replacing weaker base cards. This is directional evidence of useful
  selection, not proof each timing/source was globally optimal. Consumable effects
  are outside the screener's qualified settlement classes and need separate joins.
- The Club loss spent its available hands/discards. The copied evidence does not
  yet prove an earlier shop or discard alternative would have prevented it.

## Screening coverage and validation

Offline review covers469 eligible settlements:58 flagged decisions (51 short
discards,6 unused-discard clears,1 pack conflict),16 independently selected unflagged
examples and74 evidence packets. No flagged decision is omitted; no exported
receipt contradicts the qualified selected action. Ordinary non-clearing plays,
consumable use, pack opening and ordering do not have full screener coverage.
The confirmed order stall came from the separate raw public sequence audit;
absence from the heuristic flags is not evidence that an action is good.

Exact candidate2 digest:
`6ad0eca97a123d2f3e4eff072a035ac9f4fa53265659bfc6517b33bc1dbd5d75`.
**325 Lua fixtures and494 Python tests pass**,110 runtime dependencies and378
frozen test files. Eight runtime files differ from installed444, including the
two version stamps and445's two Acorn modules. The earlier candidate1 failure,
all prior work, raw copied journals, settings and seven DLLs are preserved.
REVIEW.md records the bounded review and corrections; FINAL_VERIFICATION.json
records final preservation and release state. No captured policy/scorer execution,
simulation, game control, save/profile access or reopened experiment occurred.

Installation requires fresh passive process absence, newest-log preservation and
the existing backed deployment/exact-installed qualification procedure. No extra
normal-exit confirmation is required. Loaded2.221 effectiveness is not yet tested.
