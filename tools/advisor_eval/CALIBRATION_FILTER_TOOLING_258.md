# Declared profiles, checkpoint calibration and filtered route selection

Tooling development on 2026-09-10/11. Runtime releases and current checkpoint are
owned by the main implementation ledger. No defaults were fitted or promoted by
these tools. No game process/window, executable launch, live gameplay, settings
or user saves were accessed. Source probes only read the executable ZIP and use
isolated lua51.dll workers with fresh frozen policy/adapter outputs and caps.

## Explicit source populations

`engine_probe.py --unlock-profile source_defaults_v1` preserves original flags.
`--unlock-profile all_unlocked_discovered_v1` sets unlock/discovery flags on the
same original centers, tags, seals and blinds. Both start fresh in-memory progress.
Challenge bans, rarity, prerequisites and other in-run pool gates remain original
source logic. Neither profile claims to match the user's actual save.

`qualify_source_profiles.py --output <fresh>` runs two profile-only workers,
15 seconds each, stopping before challenge setup. `--audit <directory>` rechecks
the registration, frozen adapter, trace hashes, commands, inventory and source
default flags. Exact profiles and full inventory are emitted before episode
execution, preserving them when a later decision times out. Replay and explicit
paired manifests carry the profile declaration and reject mismatches.

`runs/source_profiles254_auditable` passes registration/trace reaudit: 150 original
Joker prototypes, 105 unlocked under source defaults and 150 under the declared
full profile. This qualifies the declared flag transformations only. Episode
adapter, user-population and measured-win-rate qualification remain false.
The earlier `runs/source_profiles254` proof is preserved; the second run adds the
reauditable source-flag/command registration, not a new episode campaign.

## Coefficient-sensitive checkpoint workflow

`checkpoint_calibration.py` accepts one to four full source decision checkpoints
and one to six distinct numeric variants. Example checkpoint registration:

```json
[{"name":"scoring_shop","trace":"C:/fresh/source.log","step":6,"split":"development"}]
```

The grid format remains `calibrate_policy.py`'s named numeric values. Schema 1
and schema 2 bounds are read from the frozen runtime registry. Non-coefficient
code changes, stale producers/adapters/profiles, incomplete fingerprints and
unsupported/truncated comparisons fail admission. Development and holdout cannot
reuse the same challenge/seed trajectory. Every replay still verifies source
legality, score, resources, fingerprints and provenance.

```powershell
python tools/advisor_eval/checkpoint_calibration.py --policy-root <frozen-baseline> --checkpoints <cases.json> --grid <grid.json> --output-dir <fresh> --timeout 8 --wall-budget 36 --execute
```

Without `--execute`, registration leaves all requests explicitly missing.
Execution has a durable one-time lease: resuming cannot renew the cumulative
budget. Per-worker cap is at most 30 seconds and total screen cap at most 180.
Unresolved/unsupported outcomes remain separate; no automatic continuations or
retries occur. `--audit <screen>` rechecks frozen sources, traces and commands.

Opening prefixes and empty decisions are rejected before workers run. Shop
coefficient admission now requires recorded coefficient opportunities. New
runtime nonzero-effect counters take precedence. Older policies can use completed
paired comparisons as an explicitly weaker opportunity check, not proof that a
weight affected merit. `engine_probe.py --stop-at-decision tactical_shop` collects
a shop only after complete paired tactical work. A source shop with zero paired
comparisons cannot screen shop gain or computation weights.

Changed actions establish sensitivity only. An unchanged candidate is reported
`rejected_action_insensitive`; no candidate is called better or installed.
Promising changed actions need fresh bounded continuations, then separate unseen
terminal comparisons. No broad episode or holdout campaign was run here.

## Bounded frozen 2.58 evidence

Both registrations below use `development258_installed/policy` and the explicit
full source profile. They do not evaluate later runtime releases.

- `runs/checkpoint258_shop_sensitivity`: source cap 15 seconds/18 actions; first
  shop captured at step 7 in 3.792 seconds. Chaos ($4), Strength ($3), Telescope
  ($10), and pack offers were retained. Gain 1.5 and computation scale 2 each
  had fully matched six-action-prefix replays, approximately 0.89–0.96 seconds
  per worker. All open the first Buffoon pack. Zero paired tactical comparisons
  showed this was an unsuitable coefficient opportunity; admission was tightened.
  Preserve the negative screen rather than relabeling it as useful tuning.
- `runs/checkpoint258_tactical_sensitivity`: separately preregistered new seed,
  source cap 15 seconds/25 actions, two replay caps of 8 seconds. Step 6 captured
  in 3.738 seconds, with 11 completed paired comparisons. Actual offers were Crafty
  Joker ($6) and Lovers ($3). Both default gain 1 and gain 1.5 buy Crafty after
  five verified prefix actions; workers took 1.147 and 1.133 seconds. The variant
  is rejected as action-insensitive. Legacy completed-comparison metadata does
  not prove a nonzero effect of the weight. No defaults changed or gains claimed.

All source decisions were censored deliberately before the checkpoint action.
No source/replay worker timed out, errored or ran beyond its original cap.
All offers, decision results and frozen provenance remain in the registered
directories. Passing replay or choosing a scoring Joker is not a challenge win.

## Filter choice from retained outcomes and costs

`filtered_route_selection.py --cohort <registered-directory> --output <fresh>`
rechecks existing cohorts; it never searches or plays an episode. It keeps every
miss, acquisition, attrition, timeout and censor. It records the final observed
whole Joker row, allowing sacrificed Legendaries' transferred counters to remain
visible without assigning unmeasured utility to names.

Complete cohorts can produce a diagnostic total-attempt-seconds / recorded-wins
ratio only after every found run terminates and all other requests are resolved
search misses. Source terminal records are re-derived; cached outcome fields
cannot fabricate wins. New filtered collectors retain host exit status/commands
and explicit profile provenance. Historical reports lacking exit status remain
ineligible for terminal estimates; their search cost/attrition stays useful.

Optional `--cost-model <json>` declares action seconds, failed-run restart seconds
and search-invocation overhead. Whole-attempt elapsed time already includes
native search/setup/computation, so components are never added twice. A diagnostic
route comparison additionally requires matching registered starts, complete
terminal data and a recorded win for each route. Runtime promotion remains false.

Optional `--scenario <json>` evaluates one more bounded search followed by using
the found engine, or falling back to the same current engine on a miss. Inputs
are intervals for current/found expected remaining completion time, search time
and hit probability. The extra expected cost is `search + p * (found - current)`.
Only a strict improvement/worsening across every input corner selects a
conditional option; overlapping bounds remain inconclusive. These are declared
assumptions, never measured estimates or authorization to execute a search.

`runs/filtered_route254_existing_evidence` reaudits the four historical 2.52 cells:
all three misses and the acquired-pair attrition/censor remain visible, with
14.4667 total source seconds. Selection is inconclusive. No filter or native
default changed, and no old campaign was repeated. Jokerless remains excluded.

Validation at this tooling checkpoint: all 129 Python tests pass, including
23 added source-profile/checkpoint/filter-selection tests. Runtime tests and
installation are recorded separately by the current release ledger.
