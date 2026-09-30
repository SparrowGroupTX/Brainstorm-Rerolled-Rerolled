# Reproducible paired development and replay

`paired_policy_audit.py` freezes both complete product manifests and the adapter
files before running anything. It excludes settings and saves, launches only
Python with the original-source Lua DLL, and does not operate the running game.
Each challenge/seed is evaluated for both policies with the same ordinary,
unfiltered start distribution. Pair order alternates A/B and B/A to reduce
systematic startup-order bias. Use a fresh output directory every time.

```powershell
python tools/advisor_eval/paired_policy_audit.py run --incumbent-root PATH_TO_BASELINE_ROOT --candidate-root PATH_TO_CANDIDATE_ROOT --challenges c_omelette_1 c_fragile_1 --seeds ADVISORPAIRA --stop-after-step 3 --timeout 20 --output-dir tools/advisor_eval/runs/paired_example
python tools/advisor_eval/paired_policy_audit.py audit --directory tools/advisor_eval/runs/paired_example
```

Each root must contain `Brainstorm/Advisor` and the other product dependencies.
Use source variants whose scoring/policy changes have passed their focused
tests. The current adapter has no command-line search-parameter override: the
workflow records candidates as frozen source variants and does not pretend that
unapplied tuning metadata changes the actual policy.

The manifest records rules, runtime, adapter, product and start provenance. Each
attempt retains its exact command, monotonic elapsed time, source trace and
digest. The auditor re-reads traces instead of trusting cached outcome labels;
it checks provenance, arguments, duplicate/missing attempts, unlock profiles,
and errors. Reported prefix latency differences cover only matching action
prefixes on the same paired seed. They are development profiling observations,
not time-to-win estimates.

Replay one recorded attempt with the frozen product and adapter:

```powershell
python tools/advisor_eval/paired_policy_audit.py replay --directory tools/advisor_eval/runs/paired_example --pair 0 --role candidate --full-episode --timeout 30 --output-dir tools/advisor_eval/runs/paired_example_command
```

This emits a reviewable command and provenance in `replay.json`. Add `--execute`
with a fresh output directory to run it. The replay verifies the installed rule
and runtime digests first, reproduces the recorded seed/start/product, and checks
the common action prefix. `--full-episode` removes the development action cutoff;
the adapter still stops after 500 actions, and the supplied wall-clock timeout
always applies. Full-episode requests can therefore finish as censored or timed
out. The workflow permits at most 20 paired cells, 500 actions per episode and
300 seconds per process; small bounded probes should remain the default.

For a completely terminal, matched per-challenge cohort, the report can compute
the diagnostic hidden-time retry proxy:

`(sum(all attempt seconds) + retry overhead × failed attempts) / wins`

This includes the duration of failed attempts. `--retry-overhead-seconds` declares
an optional fixed overhead assumption; it is not measured animation or user
click time. A cohort with no wins has no finite estimate. A missing, censored,
timed-out, unsupported, mismatched, duplicated or erroneous attempt prevents
comparison; it cannot be relabeled as a win or loss. Challenges remain separate.

**This adapter remains experimental.** Reports always set
`promotion_allowed=false`, `recommended_policy=null` and qualified win rates to
null. Even a terminal proxy cannot authorize policy promotion or demonstrate
either per-challenge target. The utility is reproducible defect replay, paired
profiling, accurate outcome accounting, and a checked collection path for later
qualified evaluation. Neural/GPU training and automatic promotion are absent.

The 2026-09-10 workflow smoke used the same installed product in both roles:
Fragile, `ADVISORPAIR227`, three actions, 20 seconds per process. Both attempts
were correctly censored (0.72/0.66 seconds), with identical 18 total scoring
calls, a verified matching product and zero provenance errors. Its full-episode
replay matched the original three-action prefix, resolved 70 actions into Ante 4,
and then timed out at decision 71 after 20 seconds. No terminal outcome was
observed. These are collection/replay tests, not a policy improvement estimate.

This initial historical freeze included the installed `config.lua` because the
older product enumerator included every root Lua file. The enumerator is now
fixed and regression-tested: personal settings do not affect new product hashes
and are never copied into new freezes. Historical manifests and their recorded
bytes remain intact and verifiable. No settings or saves were modified.
The corrected collector was then exercised on a fresh installed-product A/A
Fragile `ADVISORPAIR230` pair: one action each, 10-second caps, both censored
(0.40/0.49 seconds), zero audit errors, with `config.lua` confirmed absent from
both frozen products and both policy hash manifests.

Artifacts: `runs/paired_workflow227/report.json` and
`runs/paired_workflow227_fullreplay/replay.json`.
The settings-exclusion smoke is `runs/paired_workflow230/report.json`.
Tests: `python -m unittest discover -s tests -p test_advisor_paired_policy.py`.
