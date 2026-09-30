# Current checkpoint — 2.67.0-alpha, 2026-09-11

Read ADVISOR_START_HERE.md, this file, then NEXT_PRIORITIES_267.md. This supersedes
the current-state and pending-pilot wording in 266 and earlier records. The full
266 architecture/source map remains the reference for unchanged components;
read only its relevant navigation/source-map sections and named component notes.
Unless qualified otherwise, `runs/` means `tools/advisor_eval/runs/` and component
notes live in `tools/advisor_eval/`.

## Installed and verified

2.67 installed at **2026-09-11T11:09:30.7610684-05:00**. Backup:
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260911-110930`.
Only `Advisor/score_cache.lua` and the two version stamps changed. All **46
deployment files and 61 frozen product/dependency files** match repository and
installation. Freeze: `runs/development267_installed/policy`.

Exact installed validation in `runs/development267_installed_validation` passes
**88 Lua fixtures and 192 Python tests**, under separate hidden 60-second suite
caps, with unchanged policy/test hashes. No runtime installation or failed final
regression is pending. Both native DLLs remain unchanged. Loaded game version and
normal-restart activation are still unknown; do not interact with the game.

Settings were hash-verified unchanged during this installation:
`377417c6426b1e506765bdf3e9ecbaaf7f489ccb55c66dcad7e26908597d98c1`.
This differs from the earlier 266 setting hash. Preserve current configuration;
never restore a historical settings hash. No saves were accessed for evaluation.
Normal user activity can subsequently change configuration. The final read-only
audit observed the earlier3404c2... hash again; no agent restored it. Installation
and final-observation hashes are recorded separately in final_verification.json.

Installed policy digest:
`6476fc3f97de5b3d777ccf471737b111a9e627b8cd67b8f5527706b33be3e03d`.
Source adapter digest:
`fc5020779fe1aa386d59562dd1655b8224546ac7823af92346f2d3a13571b216`.
Cache SHA256:
`de0dc33f23b287f835b4934b149410269647f274eeacb8b3eb4ad44ed282783e`.
Full exact hashes and evidence are in SESSION_RESET_267.json and
`runs/development267_installed/record.json`, plus final_verification.json there.

## Runtime change and limits

`CACHE_KEYS_267.md` documents exact numeric classification-cache keys replacing
per-score table/string construction. Five ordered rank/suit-mask/Stone tokens and
the rule prefix fit below 2^49, exactly representable in Lua doubles. Larger or
nonstandard numeric-rank inputs fall back to raw classification. Cache capacity,
immutable-state assumptions, sampling, complete comparisons, all scoring effects,
140,000 ordinary-search cap and 70-score fast-clear allowance are unchanged.

Focused evidence: `runs/cache267_focus1` has 8 fixtures, including 3574 cache
checks, full sampled-decision parity, population/Glass, inventory, growth,
concealed and finishing protection. The pre-stamp candidate digest was
`5389e85fe2eae350068d574179b664718c7f5743d3f89d6f89338c8a695b823a`.

One captured development decision, Rich pair0/candidate step75 from the 266
pilot, was checked with product-default options in
`runs/rich267_step75_components2`: input unchanged, same discard [5,6,7,8], same
131,713 evaluations and score calls, no search truncation. Worker wall 2.0947264s;
instrumented decision 1.806s, classification 0.219s. These are component
diagnostics, **not a measured speedup or a full paired-source-result comparison**.
The baseline profiler failed on generated Lua syntax before its decision; its
error is preserved in `runs/rich266_step75_components1`, never retried. The first
candidate registration was superseded before execution after the syntax repair.
Both authorized component workers are now spent; see
`runs/snapshot_profile267_register1/allowance_final.json`. Do not renew them.

## Complete-attempt pilot: executed once, allowance spent

The historical `runs/weakness263_requests` still contains only its original
plan.json and requests.json, unchanged. Its deferred allowance was consumed by
the fresh registration `runs/weakness266_current_pilot1`, comparing frozen **2.62
against 2.66**, not 2.67. Both products, adapter, auditors, original ZIP source,
Lua runtime and synthetic all_unlocked_discovered_v1 profile were frozen.

All 16 sequential requested workers ran with registered 80-second hard worker
timeouts and a 1320-second cumulative workflow cap. Timeout receipts include
process-termination overhead. Recorded worker wall total: **729.6207304s**.
Final audit: 16 records, zero audit errors, unchanged provenance. The outcome
execution lease is spent and must never be removed, reset or re-registered.
Unused seconds do not authorize another worker. All logs and missing/error
categories remain preserved; no worker or simulation is still running.

| Split | Frozen 2.62 | Frozen 2.66 |
|---|---|---|
| Development, four requests | 1 loss, 3 unsupported | 2 losses, 2 timeouts |
| Holdout, four requests | 1 loss, 2 timeouts, 1 unsupported | 2 losses, 1 timeout, 1 unsupported |

Total: **6 source losses, 5 timeouts, 5 unsupported; no observed wins**. Censors
and unsupported attempts are not losses. No win rate, retry-time estimate,
current/projected odds or per-challenge 50%/75% claim follows. Source profiles
remain synthetic and unqualified for player populations. Action 1.5s/retry 5s
are declared timing scenarios, not measured user timing. Wall time already
includes source startup/compute; do not add those twice.

Registration digest:
`8fca1f9db4e977ae76e7d9cf3c1e05225a5c5a3fb1ed8d6bfeb6e4df20b79407`.
Pilot manifest digest:
`c825d1886903bd6fc37211434534648ec0e79d443259eb8db49ad5a3a9cb3a83`.
Read outcome_report.json/completion_ledger.json there for exact cohorts and costs.
Only development pairs0–3 informed repair selection. Holdout outcomes were
accounted separately; their detailed decisions were not used for tuning.

`FAILURE_EVIDENCE_266.md` records development symptoms and first divergences:
Rich timeout at step110/Ante5 hand; Five-Card Draw loss step122/Ante6;
Golden Needle timeout step93/Ante5 shop; X-ray loss step15/Ante1 Big Blind.
No development illegal-action or score-mismatch event was observed. Explicit
random/concealed prediction gaps remain; terminal outcomes do not qualify those
forecasts. Earlier baseline concealment refusals do not reopen the fixed ordinary
discard-display bug.

## Evaluator repairs and new tools

- `engine_contract.lua`, `engine_run.lua`: original forced selections can no
  longer duplicate a retained card or silently retain an omitted forced card.
  Targeted consumables verify exact selections; zero-target use preserves forced
  cards. Original Card:check_use prevents full-row Ankh no-op acceptance.
- `engine_run.lua`, `development_report.py`: flushed pre-decision snapshots and
  fingerprints preserve the expensive input on hard timeout. Pending decisions
  do not inherit an older action. Current context is set before computation.
- `outcome_validation.py`: actual profile validation precedes admitted outcome
  records; rejected metadata/costs remain explicitly unverified. Missing attempts
  and unequal trace endings are distinguished from actual action divergences.
- `snapshot_component_profile.py/.lua`: register one captured development input,
  freeze source and optional candidate separately, then spend one hidden <=15s
  default-options worker. Original frozen adapter dependency wiring is reused;
  no source episode or prefix is replayed. Holdouts are rejected by admission.
  This tool diagnoses components, not terminal outcomes or general speedups.

Evidence: continuation266_selection_source1 has one original-source Bell fixture
(0.4374499s under a one-use 5s cap), including exact discard and 52-card
conservation. continuation266_selection_unit1 has 40 Lua checks/8 Python tests;
outcome_reporting266_final_20260911_105402 has 21 tests;
continuation266_timeout_report_unit has 16 tests; the final profiler compile-fix
fixtures are in snapshot_profile266_compilefix_20260911_110744. Initial failing
reproductions and malformed-generator logs remain preserved.

Tests changed/added: tests/advisor_engine_contract.lua,
test_advisor_episode_boundaries.py, test_advisor_outcome_validation.py,
test_advisor_development.py, advisor_score_cache.lua,
advisor_snapshot_component_profile.lua, test_advisor_snapshot_component_profile.py.
The default source-boundary request matrix now lists47 cases; only the new
forced-selection case was executed here, not the historical full46 matrix.

## Unchanged product scope and next gaps

The 2.65/2.66 tactical pack/shop replacements, conditional economy/shared
liquidity, bounded survival/finishing/concealed continuations, deterministic
sampling, safe growth and inventory valuation remain installed. Ordinary
discarded display backs remain publicly known; true concealment remains guarded.
The two-Legendary opening plus optional one Rare offer by Ante2–8 remains
conditional and does not guarantee affordability, acquisition, retention or
survival. Source episode CLI still supports only opening-only filtered behavior;
no full v2 acquisition/retention episode or new native search occurred.

Concrete unfinished development work is prioritized in NEXT_PRIORITIES_267.md:
safe owned-generator revelation before a certified losing last hand; expensive
shop/search components; concealed continuation admission; meaningful calibration;
explicit expanded-filter source-route support. The generator diagnosis has a
local mechanics ceiling, not a general installed ceiling API or a demonstrated
rescue. Do not repeat completed batches or infer gains from feature/test counts.

## Operating rules

Preserve ALL tracked/untracked work on codex/exact-search-speedups. No commits,
reset, clean, deletion of existing work, PR, neural/GPU training or automations.
Never launch Balatro.exe, control/foreground/fullscreen/restart/stop the game or
execute live gameplay. Never read/modify saves for evaluation. ZIP-source reads
and isolated hidden lua51.dll workers are allowed; preserve every outcome and
use fresh bounded registrations. Product Execute stays user-clicked.

Install each tested coherent runtime slice promptly with install_slice.py,
backups and current settings protection; unchanged native DLLs remain in place.
Changed native work requires the sidecar/evidence gate. After installation run
checkpoint_record.py then validate_checkpoint.py against exact installed bytes.
Tooling/docs alone need no runtime release. Do not rerun old finalize_record.py
or session finalizers merely to refresh context; they write historical text.

Current entry points: ADVISOR_START_HERE.md, SESSION_RESET_267.md/.json,
NEXT_PRIORITIES_267.md, ADVISOR_RESUME_PROMPT.md. Historical reset documents and
handoff sections are superseded where this record provides later status.
