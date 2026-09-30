# Screening406 result

Built an offline, bounded suspect-decision screener for the user's requested
qualitative review workflow. It covers passed Blueprint/Brainstorm/Invisible
offers, inferior recorded pack merit, sale-plan reversals, short discards and
rounds cleared with discards left. It retains reasons, public context, exact
anchors, uncertainty and coverage counters. Context groups reduce repetitive
review; an adjudication ledger starts unreviewed rather than turning heuristics
into truth labels. See `../SUSPECT_DECISION_SCREEN_406.md` for the contract.

No gameplay policy changed. Repository/installation remain exact2.195 checkpoint404;
the new user-started game and its journals were not audited or controlled.

## Historical demonstration, not new gameplay

Command run against the already-preserved completed403 copy:

```powershell
python tools/advisor_eval/flag_suspect_decisions.py --copy-dir tools/advisor_eval/development403/logs1 --manifest tools/advisor_eval/development403/capture/manifest.json --output tools/advisor_eval/development406/historical403_final --max-flags 1000
```

All28 original files and24,223 events were verified, with2,177 current explicitly
linked advisor actions across10 explicit run starts. The final tool produced
304 review flags in8 context families, with none omitted by the output cap:

| Pattern | Flags | Interpretation |
| --- | ---: | --- |
| Short discard | 218 |214 have watched growth present;3 have fewer than five cards in hand;1 has no watched growth Joker. No safe five-card alternative is established. |
| Discards remaining at confirmed round clear | 82 |77 have growth present;5 are final bosses with no later win-first growth horizon and receive low priority. |
| Invisible pass | 1 |Run5 action9632; see competing explanation below. |
| Sale-plan reversal | 2 |Run6 action13014 and run9 action19922. A plan change alone is not a proven bad decision. |
| Copy offer passed | 1 |Same run9 action19922 as the known Blueprint/Ramen reversal. Two rule hits describe one decision. |
| Recorded pack-merit reversal | 0 |All15 eligible older Joker-pack choices lack the newer complete receipt. This means missing coverage, not perfect pack selection. |

The complete machine-readable report and initial review ledger are under
`historical403_final/`. `historical403_attempt1/` is preserved initial output,
not the authoritative implementation. Both have the same304 historical rule
hits; later manufactured negative controls repaired cases absent from that copy.
Source provenance in the final report matches `validation/manifest.json`.

The known Blueprint control was detected without seed-specific rules or replay:
sale19912 planned Blueprint card2328; fresh choice19922 acquired Ramen card2329.
Public retained row, offers and expected sale cash were comparable. This is the
already diagnosed403/404 issue, not evidence of a new2.195 failure or rescued win.

The Invisible flag is a useful qualitative lead. At action9632, run5 had only
Yorick and Perkeo, a visible$8 Invisible, $9 cash and ample nominal horizon.
The complete visible pool is favorable for development, but buying would leave
$1 and add no immediate scoring. Recorded advice says the next-blind comparison
cleared only some composition worlds. The correct disposition is **insufficient
evidence**, pending a manufactured contextual comparison of survival, liquidity,
waiting cost and target dilution. Do not change the flat30 rating merely because
the flag exists. This older event is not asserted to be the user's new observation.

The other sale reversal,13003→13014, proposed Even Steven but acquired Blue Joker.
Both were temporary rentals; recorded estimated opening scores and heuristic
merit disagree about their appeal. It remains a hypothesis requiring valuation
and arbitration tracing, not a demonstrated strategic defect.

## Validation and preservation

* 39 new manufactured tests cover positive cases and controls for hidden identity,
negative capacity, cash/rental constraints, Invisible timing/eternity/expiry,
same-physical-ID reindexing, changed offers/cash, credit/random-copy sale limits,
multi-choice ordering, stale advice, cross-run/post-terminal attribution,
truncated tails/receipts, marker-only effects, round/ante boundaries, output/work
caps, archive/hash/path integrity and exact decode-stream binding.
* Full declared Python gate: **452 tests pass** (441 advisor,9 teacher timing,
  2 wall-time decomposition), with frozen test/helper/runtime hashes unchanged.
  `validation/manifest.json`, `report.json`, raw logs and copied source bind it.
  There are314 current test files. The prior404 Lua/runtime gate was not repeated
  because runtime is unchanged; it remains valid historical release evidence.
* One substantive read-only review and one focused recheck completed. `REVIEW.md`
  records the three repaired review findings and the primary's boss cash-out
  coverage correction. The earlier30-test and38-test logs remain preserved.
* `prework.json`, `before/`, `git_status_before.txt` and `final_verification.json`
  preserve original navigation and bind unchanged runtime/native/evidence files.
  No install, game control, current-journal read, saved-game/profile access,
  captured-policy/scorer evaluation, training, hidden search or new experiment ran.

The tool is ready for the next completed-session audit. Flag counts are neither
error rates nor win probabilities; review precision/recall is unmeasured. Prioritize
one representative per group, verify the entire decision chain, and create paired
manufactured cases before any runtime repair. This slice is complete; no gameplay
improvement, loaded2.195 outcome or population50% win rate is claimed.
