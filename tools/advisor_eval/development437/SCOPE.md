# User-directed discard repair and ten-round test

User added a new concrete task during436: fix the discard policy, then simulate
ten runs averaging at least12 discarded cards with3 discards, adding4 for each
extra discard. User clarified: **ten targeted round continuations**.

First close436's exact candidate gate. Then repair demonstrated arbitration and
candidate-admission defects with manufactured fixtures, preserving survival and
budgets. One primary implementer and the same read-only reviewer receive one
437 technical assessment and one focused recheck covering this new scope.

The new experiment will use exactly10 independently registered continuations,
four below-normal local workers at most,40seconds per job,400 total reserved
child wall-seconds and600 overall wall-seconds,16 actions per continuation.
No retries, replacements, resumption, full-game attempts, GPU or paid compute.
Cases/worlds/selection/adapter/policy/runtime must be frozen before evaluation.
Historical435 and earlier experiments remain permanently CLOSED.

Report4*available_discards as a benchmark, actual cards discarded, unused
discards, final modeled clear/failure/unsupported, and censorship. Do not inflate
results by excluding failed or unsupported cases. No population win-rate claim.
Keep live game, original gameplay execution, saves/profiles and journals untouched.
