# Read-only registered cohort progress report

`cohort_progress.py INPUT.json` prints a JSON report and reads only that normalized
input file and its own bytes for hashing. It cannot run simulations, normalize raw
traces, validate terminal source semantics, grant experiments, or qualify players.
The existing `outcome_validation.py` and `development_report.py` remain unchanged.

This tool is for one previously registered challenge, split, start distribution,
profile, source, adapter and runtime at a time. Policies differ by named frozen
digest; seed pairs share the other exact identities. Separate source attempts on
previously inspected seeds are development cases, not new independent samples.
Historical mixed-policy and checkpoint-dependent attempts must remain in their
original reports. Never rewrite them to satisfy this schema.

## Normalized schema 1

Top-level keys are `schema: 1`, `registration` and `records`. Registration contains:

- `digest`: SHA-256 of the actual preregistration; this reporter does not create one.
- `challenge`, `split` (`development` or `holdout`), unique nonempty `seeds`.
- `provenance`: exact SHA-256 strings under `profile`, `source`, `adapter`, `runtime`,
  and `start_distribution`. Use frozen manifest identities, not friendly names.
- `policies`: two or four variant names mapped to their exact policy SHA-256;
  `baseline` names one of them.
- `initial_state: "fresh_run"`, `retry_context: "disabled_clean"`.
- `sampling`: explicit booleans `independent_seeds`, `prespecified`,
  `fixed_sample_size`, and `previously_uninspected`. These are audit declarations;
  the reporter does not establish their truth. Selected development seeds, reused
  tuning cases, or adaptive stopping do not satisfy all four.
- `milestones`: an explicit list, possibly empty, of objects such as
  `{"ante": 2, "blind": "big", "event": "entered"}`. Ante is 1–8, blind is
  `small`, `big` or `boss`, event is `entered` or `cleared`.
- Optional `factorial`: map `baseline`, `a`, `b`, `ab` to four distinct variants.

Every record repeats `registration_digest`, `challenge`, `split`, `provenance`,
the matching `policy_digest`, `variant`, `seed`, `initial_state: "fresh_run"`,
`retry_context: "disabled_clean"`, and `dependent_attempt: false`. Duplicate
variant/seed records, undeclared seeds, missing identities, mixed provenance and
dependent attempts reject the whole input instead of silently excluding records.
Absent registered records remain `missing` in the full denominator.
Duplicate JSON keys and nonfinite JSON constants are rejected rather than allowing
a later identity value to silently replace an earlier one.

Each record also has:

- `outcome`: `win`, `loss`, `error`, `timeout`, `unsupported`, `censored` or
  `unverified`; and explicit Boolean `terminal_verified`.
- A verified win/loss requires `terminal_audit_digest`, pointing to the frozen
  upstream terminal audit. Unverified claimed wins/losses count as `unverified`,
  retaining their claimed categories separately. Incidental game-won fields are
  never read. The upstream audit must already distinguish actual final completion
  from GAME_OVER with an unmet threshold. Digests and flags here are assertions,
  not a substitute for that audit.
- Optional `milestones`: e.g. `{"ante_2_big_entered": true,
  "ante_2_big_cleared": false}`. Values are Boolean or null. Omitted means unknown;
  neither a high round number nor a win fills missing milestone observations.
- Optional `skipped_blinds`: a complete list of observed skips, e.g.
  `[{"ante": 1, "blind": "small"}]`, or null when that log is incomplete/unknown.
  An empty list means a complete observed log with zero skips. No boss skips,
  repeated skips or simultaneous skipped/entered/cleared claims are accepted.
  For unresolved runs this covers only the observed prefix, not their future.
- Optional finite nonnegative `attempt_seconds`, integer `user_actions`, and
  integer `failure_round` (the last field only for a verified loss).

## Interpretation

The primary endpoint is verified completion against every registered seed.
With W verified wins and U unresolved of N, `[W/N, (W+U)/N]` is a finite-cohort
missing-outcome bound, **not a confidence interval**. Each unresolved category and
unattempted record stays visible. Reaching and clearing each fixed milestone are
separate secondary endpoints, with their own unknown coverage. Skips are recorded
separately rather than increasing a progression score.

Paired comparisons align by seed, report resolved-pair descriptive differences,
and bound the difference over all registered pairs without imputing outcomes.
The resolved subset can be selected by missingness. Optional 2x2 contrast is
`ab - a - b + baseline`; it uses only blocks with all four verified terminal
outcomes and all four observed values for the chosen endpoint. It is descriptive,
reports excluded block counts and has no confidence interval or causal claim.

For fully observed completion endpoints only, when all four sampling declarations
are true, the report adds a conservative pointwise 95% Hoeffding interval for a
bounded independent seed mean. Its radius is
`(upper-lower)*sqrt(log(40)/(2*N))`, clipped to the endpoint's possible range.
Completion uses `[0,1]`; paired differences use `[-1,1]`. Unlike a naive bootstrap,
an all-zero sample does not falsely produce a zero-width interval. Small samples
can yield the entire range. This is pointwise, not simultaneous across variants,
and cannot protect adaptive selection/stopping. Milestones and interactions remain
descriptive; no per-decision observations enter any sample size.

The failure-only mean round is explicitly diagnostic: it can fall as late failures
become wins. Observed costs keep missing coverage and cannot establish expected
real completion time, opening/search costs, retries or human animation/click time.
Player qualification, promotion, expected real completion time and population win
odds remain unavailable regardless of the report's numerical results.
