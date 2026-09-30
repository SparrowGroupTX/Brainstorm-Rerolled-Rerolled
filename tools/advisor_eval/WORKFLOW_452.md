# Practical workflow for the fresh chat

Working directory is the repository root. Shell is PowerShell. Use `rg` first
for files/text; batch independent reads and keep dependent edits/tests/freezes
sequential. Avoid dumping giant JSON manifests or the archived conversation-like
navigation. Extract the few fields needed. Do not execute a tool just because a
command appears in an old document.

## Safe startup

```powershell
git branch --show-current
git status --short --branch
Get-Content tools/advisor_eval/FRESH_CHAT_HANDOFF_452.md
Get-Content ADVISOR_RESUME_PROMPT.md
Get-Content tools/advisor_eval/SIMULATOR_FIDELITY_PLAN_452.md
```

Read the architecture/evidence/strategy modules only for a concrete question.
The user already accepted simulator engineering. Do not ask whether to start.
Select one bounded lifecycle slice and write acceptance before source changes.
No generic goal, automation, new thread/worktree or gameplay is needed merely to
continue in this workspace. User requested documentation for a fresh chat, not
automatic creation of another chat in this turn.

`development452/verify.py` is the read-only verification entry point for this
documentation snapshot. It verifies archived navigation, new document hashes,
installed/candidate runtime, tests/provenance and prior artifacts without running
tests, source callbacks or a policy. After new authorized edits, its exact-state
assertions may intentionally cease matching; record a new baseline rather than
weakening old receipts. Do not rerun old451 candidate-only verify/finalize/release
scripts: some assert the pre-install450 state or one-time file nonexistence.

## Passive process and journal checks

Use successful enumeration, not an error converted to an empty list:

```powershell
@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } |
  Select-Object Id,StartTime) | ConvertTo-Json -Compress
Get-ChildItem -LiteralPath C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2 -Filter *.brj |
  Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 3 Name,Length,LastWriteTimeUtc
```

Passive absence authorizes an otherwise qualified installation; it does not
establish normal exit. Never close or launch the game to obtain the desired state.

Before analysis/release, copy the needed public session into a NEW directory.
Take each source size first, read only that prefix, hash the destination and
verify the source prefix still matches. Record before/after size/process state.
Verify archive frame hashes, cross-segment chain and event sequence. Retain an
incomplete final live frame as such. Source shrink/replacement is not success.

The451 capture scripts are readable examples, not reusable launch commands:
they hardcode a session and installed baseline, and write `LATEST.json`. Both
existing451 capture trees and their LATEST files are sealed. Reusing them would
overwrite closed navigation or point at an old session. Make a new helper/output
for a later capture, and preserve earlier copies. Do not delete source journals.

## Offline decision review

`read_player_log.py` decodes archive data. `review_decisions.py` analyzes immutable
copied journals without executing policy/scoring. Example below names the latest
preserved input but intentionally requires a fresh chosen output directory:

```powershell
python -B tools/advisor_eval/review_decisions.py --copy-dir tools/advisor_eval/development451/install/captures/001/logs --manifest tools/advisor_eval/development451/install/captures/001/manifest.json --output YOUR_NEW_REVIEW_DIRECTORY --max-packets 96 --sample-size 16
```

Do not run this merely to fill a report; the next selected objective is simulator
fidelity. The full CLI/limitations are in [DECISION_REVIEW.md](DECISION_REVIEW.md).
Trust published reports only with `COMPLETE.json` and matching hashes. Read SQLite
with URI `mode=ro`. Source logs may contain actions requested before settlement;
trace observation -> advice -> request -> callback -> settled observation -> terminal.

Flags and enumerated structural subsets are not supervised optimal-action labels.
The screener does not cover every action family and may cap packets. Preserve
coverage counts and unflagged samples rather than declaring zero suspects optimal.

## Manufactured tests and runtime release

Pure manufactured tests should not initialize an Environment, import a launcher
that starts workers, use captured states as fixtures or run original callbacks
under the label "unit test." Inspect test setup/dependencies before execution.
Normal isolated Lua/Python regressions remain useful for supported component edits.

```powershell
python -B tests/run_lua_tests.py tests/advisor_planet_finish451.lua tests/advisor_two_hand_finish.lua
```

This is a relevant example, not an instruction to rerun unchanged451 tests for
simulator documentation. Run tests appropriate to actual changes. Ordinary full
gate uses `validate_checkpoint.py --policy <exact-new-freeze>/policy --output
<new-validation-directory>`. Freeze combined runtime/test/provenance first; wait
for completion before claiming success. The current gate has two Lua DLL workers,
a shared55-second worker deadline and60-second outer command limits. Preserve
all failure output. Do not increase limits or repeat broad tests without cause.

For a runtime release, follow INSTALLATION_POLICY.md, explicit `install_slice.py`
arguments, fresh log preservation and absence, backed files/hashes, actual-installed
freeze and full gate. Do not overwrite user settings, DLLs or saves. No runtime
release is needed for tooling/docs-only simulator qualification work.

## Hazardous entry points to inspect, not launch by default

- `tools/advisor_learning/environment.py`: Environment construction starts an episode.
- `tools/advisor_learning/train.py`, `experiment.py`, `hardware_probe.py`: historical
  training/episode/hardware jobs; no old unused lease remains.
- `engine_probe.py`, `qualify_episode_boundaries.py`, `*_source_parity.py`: may
  extract and execute original code, even without launching a visible game.
- `continuation_adapter.lua`, captured-pair/continuation launchers: may execute
  recorded snapshots through policy/scoring. Closed counts do not reopen.
- Prior install/finalize helpers: one-shot recorded paths and baseline assumptions;
  do not use them as generic recovery commands.

Prepare a concrete new execution manifest when these capabilities are needed.
Keep game process control and player save/profile access prohibited regardless.
No hidden search or synthetic callback win is a real user win.

## Maintaining clean context

Keep the front door small. Update current summaries in place while archiving exact
previous bytes when needed. Put detailed evidence, commands and failure logs in
named immutable slices. Never prepend another thousand-line history to the resume.

Reference exact paths/hashes and proof scope. Distinguish proposed from implemented,
tested from qualified, installed from loaded. After one coherent delivery, report
what changed, how checked, material limitations and next priority, then stop.
Do not invent token/credit costs;452 records byte/word counts, not billing estimates.
