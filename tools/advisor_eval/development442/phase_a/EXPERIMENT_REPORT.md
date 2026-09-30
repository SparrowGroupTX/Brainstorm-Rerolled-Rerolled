# Twenty targeted round continuations442 phase A

Candidate2.218; matched historical439 control;20 distinct public round openings;one hypothetical world each;no full-game or population win-rate inference.

Registered20; complete rounds20; censored0. Outcomes: {'supported_clear': 20}.
Completed-round averages: 3.15 discards, 12.8 cards, 4.063492063492063 cards per discard.
Completed cards256/252 required; 0 unused discards. Completed benchmark: True.
Entire registered cohort target: 252/20 = 12.6 cards per round. All20 verified: True.
Modeled failures remain in complete-round averages. Censored prefixes are not complete rounds or zero-card outcomes.

| Case | Outcome | Cards / target | Settled discard sizes | Unused |
|---|---|---:|---|---:|
| run01_round01 | supported_clear | 10 / 12 | [4, 3, 3] | 0 |
| run01_round02 | supported_clear | 13 / 12 | [4, 4, 5] | 0 |
| run02_round01 | supported_clear | 14 / 12 | [5, 4, 5] | 0 |
| run02_round06 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run02_round12 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run02_round17 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run02_round23 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run03_round01 | supported_clear | 12 / 12 | [5, 4, 3] | 0 |
| run03_round06 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run03_round12 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run03_round17 | supported_clear | 17 / 16 | [4, 4, 4, 5] | 0 |
| run03_round23 | supported_clear | 8 / 16 | [5, 1, 1, 1] | 0 |
| run04_round01 | supported_clear | 8 / 12 | [2, 3, 3] | 0 |
| run04_round08 | supported_clear | 12 / 12 | [4, 4, 4] | 0 |
| run04_round16 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run04_round23 | supported_clear | 12 / 12 | [5, 4, 3] | 0 |
| run05_round01 | supported_clear | 12 / 12 | [5, 4, 3] | 0 |
| run05_round05 | supported_clear | 12 / 12 | [4, 4, 4] | 0 |
| run05_round10 | supported_clear | 13 / 12 | [5, 5, 3] | 0 |
| run05_round16 | supported_clear | 8 / 16 | [3, 2, 1, 2] | 0 |

## Supported prefix accounting

{"rounds": 0, "cards_discarded": 0, "discards_used": 0, "available_discards": 0, "target_cards": 0, "unused_discards": 0, "discards_per_round": null, "cards_per_round": null, "cards_per_discard": null, "target_per_round": null, "aggregate_benchmark_met": null, "individual_rounds_meeting_benchmark": 0}
Prefix action counters count only successfully transitioned discards. Final resources may be unresolved. Their averages are not full-round performance.

## Shortfalls and unresolved transitions

- run01_round01: Actual supported play reaches target; shortfall=2; plays with discards=[{"remaining": 2, "hand": "Flush", "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 316, "needed_score": 450, "reason": "selected_play_does_not_clear", "remaining_discards": 2, "schema": 1, "selected": false, "status": "not_finishing"}, "yorick_review": null}]
- run03_round01: Actual supported play reaches target; shortfall=0; plays with discards=[{"remaining": 1, "hand": "Three of a Kind", "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 180, "needed_score": 450, "reason": "selected_play_does_not_clear", "remaining_discards": 1, "schema": 1, "selected": false, "status": "not_finishing"}, "yorick_review": null}]
- run03_round23: Actual supported play reaches target; shortfall=8; plays with discards=[]
- run04_round01: Actual supported play reaches target; shortfall=4; plays with discards=[{"remaining": 2, "hand": "Flush", "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 284, "needed_score": 450, "reason": "selected_play_does_not_clear", "remaining_discards": 2, "schema": 1, "selected": false, "status": "not_finishing"}, "yorick_review": null}]
- run05_round16: Actual supported play reaches target; shortfall=8; plays with discards=[]

All20 registrations are consumed, with no retries or replacements. Candidate2.217 remains uninstalled. The source session was an active prefix; no completed-session or normal-exit inference. No baseline causal comparison. Round rewards/future shops are not modeled. No Acorn or Heart case was selected.
