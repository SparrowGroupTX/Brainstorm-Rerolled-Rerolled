# Twenty targeted round continuations439

Candidate2.217 only;20 distinct public round openings;one hypothetical world each;no full-game or population win-rate inference.

Registered20; complete rounds17; censored3. Outcomes: {'supported_clear': 17, 'supported_clear_floor': 3}.
Completed-round averages: 2.8823529411764706 discards, 11.176470588235293 cards, 3.877551020408163 cards per discard.
Completed cards190/216 required; 5 unused discards. Completed benchmark: False.
Entire registered cohort target: 252/20 = 12.6 cards per round. All20 verified: False.
Modeled failures remain in complete-round averages. Censored prefixes are not complete rounds or zero-card outcomes.

| Case | Outcome | Cards / target | Settled discard sizes | Unused |
|---|---|---:|---|---:|
| run01_round01 | supported_clear | 9 / 12 | [4, 3, 2] | 0 |
| run01_round02 | supported_clear | 13 / 12 | [4, 4, 5] | 0 |
| run02_round01 | supported_clear | 14 / 12 | [5, 4, 5] | 0 |
| run02_round06 | supported_clear | 12 / 12 | [4, 4, 4] | 0 |
| run02_round12 | supported_clear_floor | censored (15 prefix) / 12 | [5, 5, 5] | 0 |
| run02_round17 | supported_clear_floor | censored (15 prefix) / 12 | [5, 5, 5] | 0 |
| run02_round23 | supported_clear_floor | censored (15 prefix) / 12 | [5, 5, 5] | 0 |
| run03_round01 | supported_clear | 12 / 12 | [5, 4, 3] | 0 |
| run03_round06 | supported_clear | 14 / 12 | [5, 5, 4] | 0 |
| run03_round12 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run03_round17 | supported_clear | 16 / 16 | [4, 4, 4, 4] | 0 |
| run03_round23 | supported_clear | 0 / 16 | [] | 4 |
| run04_round01 | supported_clear | 8 / 12 | [2, 3, 3] | 0 |
| run04_round08 | supported_clear | 12 / 12 | [4, 4, 4] | 0 |
| run04_round16 | supported_clear | 10 / 12 | [4, 4, 2] | 0 |
| run04_round23 | supported_clear | 9 / 12 | [5, 4] | 1 |
| run05_round01 | supported_clear | 12 / 12 | [5, 4, 3] | 0 |
| run05_round05 | supported_clear | 12 / 12 | [4, 4, 4] | 0 |
| run05_round10 | supported_clear | 14 / 12 | [5, 5, 4] | 0 |
| run05_round16 | supported_clear | 8 / 16 | [3, 2, 1, 2] | 0 |

## Supported prefix accounting

{"rounds": 3, "cards_discarded": 45, "discards_used": 9, "available_discards": 9, "target_cards": 36, "unused_discards": 0, "discards_per_round": 3.0, "cards_per_round": 15.0, "cards_per_discard": 5.0, "target_per_round": 12.0, "aggregate_benchmark_met": true, "individual_rounds_meeting_benchmark": 3}
Prefix action counters count only successfully transitioned discards. Final resources may be unresolved. Their averages are not full-round performance.

## Shortfalls and unresolved transitions

- run01_round01: Actual supported play reaches target; shortfall=3; plays with discards=[{"remaining": 2, "hand": "Flush", "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 316, "needed_score": 450, "reason": "selected_play_does_not_clear", "remaining_discards": 2, "schema": 1, "selected": false, "status": "not_finishing"}, "yorick_review": null}]
- run02_round12: Final transition/resources unresolved: Matador earnings are not modeled for a follow-up hand.; shortfall=None; plays with discards=[]
- run02_round17: Final transition/resources unresolved: Matador earnings are not modeled for a follow-up hand.; shortfall=None; plays with discards=[]
- run02_round23: Final transition/resources unresolved: Matador earnings are not modeled for a follow-up hand.; shortfall=None; plays with discards=[]
- run03_round01: Actual supported play reaches target; shortfall=0; plays with discards=[{"remaining": 1, "hand": "Three of a Kind", "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 180, "needed_score": 450, "reason": "selected_play_does_not_clear", "remaining_discards": 1, "schema": 1, "selected": false, "status": "not_finishing"}, "yorick_review": null}]
- run03_round23: Actual supported play reaches target; shortfall=16; plays with discards=[{"remaining": 4, "hand": "Pair", "receipt": {"category": "public_model_gap", "clear_supported": true, "evaluations": 3, "final_action_kind": "play", "final_play_score": 1505790, "needed_score": 400000, "reason": "Draw or play changes the finishing conditions.", "remaining_discards": 4, "schema": 1, "selected": false, "status": "exception"}, "yorick_review": {"anchor": {"changed": false, "considered": 13, "qualified": 0}, "growth": {"bounded_growth": true, "candidates": 0, "max_evaluations": 12, "reasons": ["Draw or play changes the finishing conditions."]}, "schema": 1}}]
- run04_round01: Actual supported play reaches target; shortfall=4; plays with discards=[{"remaining": 2, "hand": "Flush", "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 284, "needed_score": 450, "reason": "selected_play_does_not_clear", "remaining_discards": 2, "schema": 1, "selected": false, "status": "not_finishing"}, "yorick_review": null}]
- run04_round16: Actual supported play reaches target; shortfall=2; plays with discards=[]
- run04_round23: Actual supported play reaches target; shortfall=3; plays with discards=[{"remaining": 1, "hand": "Four of a Kind", "receipt": {"category": "public_model_gap", "clear_supported": true, "evaluations": 4, "final_action_kind": "play", "final_play_score": 470400, "needed_score": 400000, "reason": "Automatic hand sorting can change scoring-card order.", "remaining_discards": 1, "schema": 1, "selected": false, "status": "exception"}, "yorick_review": {"anchor": {"changed": false, "considered": 16, "qualified": 0}, "growth": {"bounded_growth": true, "candidates": 0, "max_evaluations": 12, "reasons": ["Automatic hand sorting can change scoring-card order."]}, "schema": 1}}]
- run05_round16: Actual supported play reaches target; shortfall=8; plays with discards=[]

All20 registrations are consumed, with no retries or replacements. Candidate2.217 remains uninstalled. The source session was an active prefix; no completed-session or normal-exit inference. No baseline causal comparison. Round rewards/future shops are not modeled. No Acorn or Heart case was selected.
