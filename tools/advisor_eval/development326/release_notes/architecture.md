The unchanged policy and control architecture inherits `ARCHITECTURE_MAP_325.md`, `AUTO_RESUME_325.md`, `TIMING_324.md`, `IDLE_CPU_323.md` and `PACE_322.md`. Release 326's component note is `LOG_STORAGE_326.md`. Generated checkpoint records own final versions, hashes and candidate/installed validation; this navigation input grants no experiment authority.

| Area | Runtime source | Relevant fixtures | Scope |
| --- | --- | --- | --- |
| Observation archive | `Advisor/player_log_archive.lua` | `test_advisor_player_log_archive.py` | Combined v1/v2 allowance of 1,073,741,824 bytes; existing event, segment, file and session guards remain. |
| Journal and alerts | `Advisor/player_journal.lua` | `advisor_player_journal.lua`, `advisor_player_journal_timing.lua` | Matching legacy total allowance; short alert points to persistent Recording status; sticky errors stay explicit. |
| Persistent status UI | `UI/advisor.lua` | `advisor_logging_status.lua`, existing advisor UI/runtime fixtures | Recording status button and bounded, paginated UTF-8 details; Full status includes recording failures. |
| Idle periodic timing flush | `Advisor/performance.lua`, `Core/Brainstorm.lua` | `advisor_performance.lua`, `advisor_frame_timing.lua` | Positively known idle main menu defers periodic summaries while retaining bounded memory; active work and explicit events remain recorded. |
| Preserved auto-run control | `Advisor/auto_run.lua`, `Core/auto_run_product.lua`, input/checkpoint/UI hooks | `advisor_auto_run.lua`, `advisor_auto_run_product.lua`, `advisor_input_ui.lua` | Ordinary input waits, explicit in-memory Stop/Resume, original limits and verified checkpoint continuation remain unchanged. |

`development326/storage_metadata.json` records metadata only, with no decoded observation contents. `development326/log_cleanup.json` records the explicitly authorized deletion of 53 prior public-log files and empty-directory verification. These external originals are deleted; existing repository log audits and experimental receipts remain. The cleanup does not read or modify saves, checkpoints or profile data and supplies no authority for future deletion.

The prepared documentation inputs and reference validation are in `development326/release_notes/`. Final runtime evidence belongs to generated `storage326` candidate, installed and final records. No live activation, terminal result or measured speedup is inferred from these paths.
