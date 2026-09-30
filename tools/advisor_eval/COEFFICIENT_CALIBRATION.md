# Bounded coefficient development screen

Latest tooling: `CALIBRATION_FILTER_TOOLING_258.md` documents schema 2 declared
bounds, explicit source profiles and `checkpoint_calibration.py`. Prefer that
workflow for new calibration: it rejects opening prefixes and coefficients with
no recorded opportunity, then rejects unchanged actions. The historical prefix
screen below remains preserved as workflow evidence, not successful fitting.

`Brainstorm/Advisor/policy_weights.lua` schema 1 keeps existing defaults:

| Coefficient | Default | Meaning |
|---|---:|---|
| growth_action_cost | 4 | Utility cost of an extra safe development action |
| growth_utility_scale | 1 | Value of Yorick/Burnt and Death development before costs |
| discard_action_penalty | 0.06 | Redraw override margin, divided by remaining discards |

The existing score safety checks, finishing-card protection, search caps and
final-hand survival priority remain mandatory regardless of coefficient values.
These are utility coefficients, not measured seconds or win probabilities.

Register a JSON grid with one to six named candidates, for example:

```json
[
  {"name": "less_action_cost", "values": {"growth_action_cost": 2}},
  {"name": "more_discard_conservation", "values": {"discard_action_penalty": 0.09}}
]
```

Run `python tools/advisor_eval/calibrate_policy.py --policy-root <stable-root>
--grid <grid.json> --output-dir <new-directory> --seeds COEFFICIENTSCREEN1
--timeout 20 --wall-budget 90 --execute` as one shell command. Omit `--execute`
to register only. Default three-action prefixes are profiling evidence. Request
`--full-episode` only for bounded terminal development attempts. No game process
is launched: the paired workflow uses the hidden Lua DLL source adapter.

Each candidate changes only the registry's delimited numeric block in a frozen
copy. Full product/rules/runtime/adapter provenance is retained. Candidate source
is checked for actual coefficient wiring. Every request is paired against the
same frozen baseline, with each challenge reported separately. A wall budget
that cannot fit the next pair leaves it explicitly missing.

`--audit <screen-directory>` rechecks frozen sources, manifests and traces. The
report exposes terminal retry-time diagnostics only for complete matched cohorts;
errors, unsupported paths, timeouts and prefixes are not classified as losses.
The adapter remains experimental, so the tool always refuses promotion and
reports no qualified win rate. It never writes installed policy, settings or
saves. Held-out qualified episodes and real action/retry timing are required
before accepting new defaults as a time-adjusted policy improvement.

The initial `runs/coefficient_screen239` screen froze installed v2.39 and the
then-current adapter. It ran two numeric variants against the incumbent on one
ordinary Omelette seed, three actions each. All four attempts were correctly
censored (4.72, 4.21, 4.02 and 4.30 seconds), with no provenance errors. Both pairs
chose identical three-action prefixes and used the same scoring-call counts.
This verifies the screening workflow; it does not demonstrate a better policy.
The original default coefficients were retained.

## Verified decision checkpoints (2026-09-10 continuation)

Use `decision_replay.py` for matched decisions after an already recorded source
prefix. It freezes both products and the adapter, checks the source trace and
its frozen producer policy, and skips earlier advisor computations. Every
prefix action still passes the original source legality callbacks, source-state
fingerprints before and after execution, score prediction/parity, and resolved
cash/chips/hand/discard checks. The synthetic unlock profile and rules/runtime/
adapter digests must match. The source policy's separately verified snapshot
module defines canonical replay fingerprints; the candidate's snapshot module
still supplies its actual decision input. This permits a derived-observation
bug fix without silently weakening source-state checks.

Example, after collecting a fresh trace with the current frozen adapter:

```powershell
python tools/advisor_eval/decision_replay.py --source-trace <source.log> --source-policy-root <frozen-source-policy> --candidate-root <stable-candidate> --step 22 --output-dir <new-directory> --timeout 15 --wall-budget 40 --execute
```

The default stops after evaluating the recorded boundary, before executing its
action. The report contains both complete decision results, matched canonical
state fingerprints, actions, all revealed pack offers, skipped advisor counts,
latencies, and explicit missing/error/timeout outcomes. `--full-episode` permits
a bounded continuation after the boundary. `--evaluate-prefix` is a diagnostic
comparator that recomputes and checks every source-policy prefix action; it is
appropriate when the candidate is the same policy. `--audit <directory>` checks
the registration, product/adapter manifests, source/attempt traces, commands and
provenance again. Neither form installs, promotes, or qualifies a policy.

For new source collection, `engine_probe.py --stop-at-decision shop|pack|growth|reroll`
with `--decision-occurrence N` captures a full matching decision before applying
it. Use an outer bounded hidden collector and frozen sources. Growth matches a
decision that actually evaluated growth opportunities, including a decision
that rejected growth. Reroll matches a recommended reroll; shop checkpoints also
retain cases that rejected reroll. `--replay-until-step N` resumes at an actual
recorded action or checkpoint, and `--stop-at-replay-decision` captures it.
Legacy traces without fingerprints and traces from a different adapter are
rejected; generate a fresh source prefix, rather than relaxing provenance.

The selected 2.42-to-2.45 checkpoint comparisons now capture meaningful pack and
shop choices: both choose Devious from the actual Baseball/Devious offers; the
later shop changes from buying Delayed Gratification to saving. These are policy
code comparisons, not fitted coefficients or demonstrated wins. Coefficient
defaults remain unchanged. See `VERIFIED_REPLAY_245.md` for evidence and limits.
