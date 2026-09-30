# Current architecture —325

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_325.md`
and `.json`. Current work: `NEXT_PRIORITIES_325.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `AUTO_RESUME_325.md`.

Unchanged scoring and diagnostic architecture inherits `ARCHITECTURE_MAP_324.md`, `TIMING_324.md`, `PACE_322.md` and `IDLE_CPU_323.md`. Release 325's component note is `AUTO_RESUME_325.md`. Generated checkpoint records own final versions, hashes and candidate/installed validation; this navigation input grants no experiment authority.

| Area | Runtime source | Relevant fixtures | Scope |
| --- | --- | --- | --- |
| Session pause and continuation | `Advisor/auto_run.lua` | `advisor_auto_run.lua` | Retain session counters, configuration, original run/session clocks, pending action, found/starting receipt; distinguish explicit Stop/Resume, input waits and hard halts. |
| Product lifecycle | `Core/auto_run_product.lua` | `advisor_auto_run_product.lua`, `advisor_auto_observation.lua` | Cheap engaged status, non-stopping input notification, overlay settling, fresh execution checks, explicit new search authorization after drain, verified checkpoint continuation. |
| Keyboard and mouse | `Core/Brainstorm.lua` | `advisor_input_ui.lua`, `advisor_collection_core.lua` | Ordinary inputs cannot cancel auto-owned search. Ctrl+A and fast reroll cannot overlap or replace the owned run. Existing independent manual-search cancellation remains. |
| HUD and page controls | `UI/advisor.lua`, `UI/collection_run.lua` | `advisor_input_ui.lua`, `advisor_startup_ui.lua`, `advisor_collection_status.lua`, `advisor_gold_layout.lua`, `advisor_runtime.lua` | Dedicated Stop and Resume; persistent resumable HUD; existing-row page layout; no Start/Execute fallback or extra shared-search cancellation. |
| Advice and settings invalidation | `Advisor/runtime.lua` | `advisor_runtime.lua`, `advisor_input_ui.lua` | Keep stale-token, generation and worker invalidation while preserving engaged auto search. |
| User checkpoint integration | `Core/checkpoint_runtime.lua` | `advisor_checkpoint_runtime.lua`, `advisor_input_ui.lua`, `advisor_auto_run_product.lua` | Existing verified save/load protections; completion notification follows advice invalidation. No retry-count renewal or autonomous checkpoint I/O. |
| Terminal evidence | `Core/auto_terminal.lua` | `advisor_auto_terminal.lua`, `advisor_auto_run_product.lua` | Existing verified callback/threshold evidence; monitor survives explicit Stop. Restored won flags are not new evidence. This file's 325 change is comment-only. |
| Existing timing diagnostics | `Advisor/performance.lua`, `Advisor/player_journal.lua`; `tools/advisor_eval/analyze_player_timing.py` | `advisor_performance.lua`, `advisor_player_journal_timing.lua`, `test_advisor_player_timing.py` | Preserve bounded windows, journal-failure acknowledgment and elapsed-wall semantics. Fresh live analysis remains separate. |

Detached input/UI evidence is under `development325/input_ui/`; controller/product validation and review are under `development325/resume_tests/` and `development325/resume_audit/`. The initial input fixture's CRLF-helper failure remains in `input_ui/failed_fixture1/`. These manufactured tests do not establish player win rates, live activation or full-run savings.


Preserved earlier navigation: `ARCHITECTURE_MAP_324.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
