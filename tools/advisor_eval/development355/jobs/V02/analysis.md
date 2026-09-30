# Frozen simulator evaluation audit

Recorded simulator attempts under the same initial collection ledger; not cumulative player campaign awards.

No retail qualification, actual player award, or confidence interval is claimed.

| Policy | Attempts | Verified wins | Unresolved | Observed new Gold | Full-cohort mean | Sample mean bounds | Observed progress prefix |
|---|---:|---:|---:|---:|---:|---|---:|
| heuristic | 32 | 0 | 9 | 0 | unavailable | [0.0000, 25.5938] | 3.1562 (32 observed) |
| learned | 32 | 0 | 4 | 0 | unavailable | [0.0000, 11.3750] | 1.5000 (32 observed) |

Bounds are finite-sample partial-identification bounds, **not confidence intervals**. Each unresolved attempt can contribute between zero and the initial missing-Joker count; missing progress is never replaced with zero.

- heuristic: first two recorded actions sold both starters in 0/32 observed openings; 0 reorder-like actions; maximum consecutive reorder streak 0.
- learned: first two recorded actions sold both starters in 32/32 observed openings; 1564 reorder-like actions; maximum consecutive reorder streak 778.

Validated seed pairs: 32. Pairing issues: 0.
Candidate versus reference observed progress: {"all_observed_pairs": {"equal": 11, "lower": 21}, "fully_terminal_pairs": {"equal": 9, "lower": 13}, "unresolved_pairs": {"equal": 2, "lower": 8}}.
Unresolved-pair progress compares observed prefixes only, not completed-run outcomes.

Reorder counts/streaks are observed action sequences. Exact repeated-state loops are not proved without public-state fingerprints.
