# Ten targeted round continuations437

Fixed targeted model continuations, one world per archived round, no baseline pair/full games/population win rate.

Registered10; completed6; censored4. Outcomes: {'supported_clear': 5, 'unsupported': 4, 'modeled_failure': 1}.
Completed card total61/72 benchmark; discards used15; unused3.
Completed cards/round: 10.166666666666666; required: 12.0; cards/discard: 4.066666666666666.
All-ten benchmark verified: False. Unsupported prefixes are not completed rounds or zero-card outcomes.

| Case | Outcome | Cards / target | Discard sizes | Remaining |
|---|---|---:|---|---:|
| run01_round19 | supported_clear | 15 / 12 | [5, 5, 5] | 0 |
| run02_round23 | unsupported | censored (5 prefix) / 12 | [5] | 2 |
| run03_round23 | unsupported | censored (2 prefix) / 16 | [2] | 3 |
| run04_round2 | supported_clear | 11 / 12 | [4, 4, 3] | 0 |
| run05_round23 | modeled_failure | 10 / 12 | [3, 3, 4] | 0 |
| run06_round23 | unsupported | censored (0 prefix) / 12 | [] | 3 |
| run07_round19 | supported_clear | 12 / 12 | [4, 4, 4] | 0 |
| run08_round23 | unsupported | censored (0 prefix) / 12 | [] | 3 |
| run09_round23 | supported_clear | 0 / 12 | [] | 3 |
| run10_round14 | supported_clear | 13 / 12 | [5, 5, 3] | 0 |

## Shortfalls and unresolved transitions

- run02_round23: Unmodeled Joker debuff resources: Clever Joker; shortfall=None; plays with discards=[{"remaining": 2, "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 189900, "needed_score": 400000, "reason": "selected_play_does_not_clear", "remaining_discards": 2, "schema": 1, "selected": false, "status": "not_finishing"}, "kind": "Two Pair"}]
- run03_round23: Cerulean Bell needs a sampled forced card.; shortfall=None; plays with discards=[]
- run04_round2: Actual supported play reaches target; shortfall=1; plays with discards=[]
- run05_round23: Hands exhausted; shortfall=2; plays with discards=[]
- run06_round23: Concealed Joker belief transitions are not qualified by this adapter.; shortfall=None; plays with discards=[]
- run07_round19: Actual supported play reaches target; shortfall=0; plays with discards=[{"remaining": 2, "receipt": {"evaluations": 0, "final_action_kind": "play", "final_play_score": 69012, "needed_score": 165000, "reason": "selected_play_does_not_clear", "remaining_discards": 2, "schema": 1, "selected": false, "status": "not_finishing"}, "kind": "Full House"}]
- run08_round23: Concealed Joker belief transitions are not qualified by this adapter.; shortfall=None; plays with discards=[]
- run09_round23: Actual supported play reaches target; shortfall=12; plays with discards=[{"remaining": 3, "receipt": {"category": "public_model_gap", "clear_supported": true, "evaluations": 12, "final_action_kind": "play", "final_play_score": 1201200, "needed_score": 1200000, "reason": "The bounded discard proof allowance is exhausted.", "remaining_discards": 3, "schema": 1, "selected": false, "status": "exception"}, "kind": "Pair"}]

All ten remain in the report. No retries/replacements or post-result tuning are included. All remaining capacity is permanently closed. No loaded-game effectiveness or population win-rate claim.
