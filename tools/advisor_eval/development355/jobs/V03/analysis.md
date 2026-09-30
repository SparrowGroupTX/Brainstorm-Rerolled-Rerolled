# Frozen simulator evaluation audit

Recorded simulator attempts under the same initial collection ledger; not cumulative player campaign awards.

No retail qualification, actual player award, or confidence interval is claimed.

| Policy | Attempts | Verified wins | Unresolved | Observed new Gold | Full-cohort mean | Sample mean bounds | Observed progress prefix |
|---|---:|---:|---:|---:|---:|---|---:|
| heuristic | 32 | 0 | 11 | 0 | unavailable | [0.0000, 31.2812] | 4.2812 (32 observed) |
| learned | 32 | 0 | 2 | 0 | unavailable | [0.0000, 5.6875] | 1.1875 (32 observed) |

Bounds are finite-sample partial-identification bounds, **not confidence intervals**. Each unresolved attempt can contribute between zero and the initial missing-Joker count; missing progress is never replaced with zero.

- heuristic: first two recorded actions sold both starters in 0/32 observed openings; 0 reorder-like actions; maximum consecutive reorder streak 0.
- learned: first two recorded actions sold both starters in 32/32 observed openings; 777 reorder-like actions; maximum consecutive reorder streak 772.

Validated seed pairs: 32. Pairing issues: 0.
Candidate versus reference observed progress: {"all_observed_pairs": {"equal": 6, "higher": 1, "lower": 25}, "fully_terminal_pairs": {"equal": 6, "lower": 14}, "unresolved_pairs": {"higher": 1, "lower": 11}}.
Unresolved-pair progress compares observed prefixes only, not completed-run outcomes.

Reorder counts/streaks are observed action sequences. Exact repeated-state loops are not proved without public-state fingerprints.
