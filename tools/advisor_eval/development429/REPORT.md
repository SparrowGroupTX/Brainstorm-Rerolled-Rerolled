# Evaluation429 results:2.209 versus frozen2.210

This is a completed offline counterfactual comparison, using the exact frozen
policies. It made no runtime changes. Candidate2.210 remains uninstalled;
installed2.209 is unchanged. No loaded-game win-rate improvement is established.

## Modeled round metrics

Primary coverage: **12/12 distinct rounds**, each with both
registered hypothetical worlds completed by both policies. These are selected
suspect checkpoints with a shared observed prefix, not fresh complete runs or
a representative sample of all rounds. Two worlds from one round are correlated.

| Metric |2.209 baseline|2.210 candidate|
|---|---:|---:|
| Discards per round, including shared observed prefix |1.167|1.333|
| Cards per discard, including shared observed prefix |3.000|3.094|
| Cards discarded per round |3.500|4.125|
| Discards remaining at supported clear |1.917|1.750|
| Continuation full-five discards, across included worlds |0|1|

All registered continuation statuses (24 branches per policy):
`{"baseline": {"supported_clear": 24}, "candidate": {"supported_clear": 24}}`.
The results retain every censored/unsupported/timeout/unstarted branch. The table
conditions on complete paired supported clears; it is not an unconditional
success estimate. Prefix discard counts all matched public counters. Prefix card
totals derive from request histories; no new independent settlement audit was
performed for this experiment. Earlier audit427 preserved linked settlements.

## Immediate paired decisions

| Selection |Complete pairs|Discard actions, before -> after|Cards/discard, before -> after|Full-five actions, before -> after|
|---|---:|---:|---:|---:|
| old_unused | 60/60 | 0 -> 5 | unavailable -> 4.200 | 0 -> 3 |
| old_short_control | 40/40 | 39 -> 39 | 3.231 -> 3.231 | 0 -> 0 |
| old_full_control | 20/20 | 18 -> 18 | 5.000 -> 5.000 | 18 -> 18 |
| current_reported | 7/7 | 0 -> 3 | unavailable -> 3.333 | 0 -> 1 |
| all | 127/127 | 57 -> 65 | 3.789 -> 3.800 | 18 -> 22 |

Action-kind transitions: `{"None -> None": 7, "discard -> discard": 57, "play -> discard": 8, "play -> play": 55}`.
No-advice abstentions: `{"baseline": {"Concealed-card advice unavailable": 7}, "candidate": {"Concealed-card advice unavailable": 7}}`. A completed
worker means evaluation returned; it does not imply a legal action was available.
All emitted play/discard selections passed the adapter's selection audit.
Changed exact action IDs: `["old-2579", "old-2710", "old-3150", "old-7047", "old-7895", "current-3661", "current-3839", "current-4008"]`.

Older snapshots were recorded under2.208; both2.209 and2.210 are counterfactual
policies on those unchanged inputs. Baseline exact action matches to recorded
actions: 120/127. Public
projection can remove concealed information and runtime context; this is not a
bit-identical reconstruction of historical live execution.

## Qualification and limits

Manifest `42a06a59ed4744c0690d799f412c3beb7a258c9cdb01f03f1810df88847dbafa` was finalized before any captured
evaluation. The single serial below-normal-priority worker processed302
registered jobs in 419.3 seconds: `{"complete": 302, "error": 0, "timeout": 0, "not_started": 0}`.
The allowance is closed, including unused capacity. No retry or replacement.
The sole review cycle is exhausted. Frozen files, source archives, prior work,
installed runtime, settings and DLLs passed final preservation checks.

Invented adapter checks passed; their raw failures and corrections are preserved.
The final invented input is a parity control, not an improvement claim. The
candidate's existing exact full validation remains300 Lua fixtures/458 Python
tests; this tooling-only evaluation did not modify those policy bytes.

Future draws and rank/suit sorting are explicitly hypothetical. Private draw
order was withheld from the policy. Unsupported actions, unknown new draw
identities and uncertain random scoring transitions are censored. Immediate
supported score floors establish modeled round clears only; rewards and later
rounds were not simulated. The separate full-run simulator does not call this
advisor, so using it here would not answer whether this policy improves runs.

Detailed evidence: RESULTS.json, DECISION_PAIRS.json, ROUND_PAIRS.json, results/,
ledger/, manifest.json, PLAN.md, REVIEW.md and FINAL_VERIFICATION.json. No original
game execution, live game control, saves/profile access, training or automation.
