# Source/test navigation361

- UI/collection_run.lua: standalone brainstorm_collection_clear_logs callback, session/search/execution guards and visible success/failure; teacher batch label now Clear logs + play 10 runs.
- Advisor/player_journal.lua: shared prepare_archive resets writer/link state; clear_logs exits collection mode without enabling recording or starting gameplay. prepare_collection retains explicit identity and teacher behavior.
- Advisor/player_log_archive.lua unchanged: validates owned direct session journals, closes/resets writer, preserves unknown files and reports partial failures.
- tests/advisor_teacher_journal356.lua: real archive with in-memory filesystem, two clear/append cycles, pending receipt and settings protections.
- tests/advisor_collection_status.lua: independent callback, guards, failures and labels; advisor_gold_layout.lua verifies bounded synthetic geometry.
- tests/advisor_teacher_batch356.lua: added ten-loss/zero-win case; existing mixed outcomes/caps/retirement tests retained. Auto-run controller unchanged.
- development361/targeted01.log retains initial layout failure; targeted02.log records corrected layout.
- ARCHITECTURE_MAP_360.md and356 locate unchanged policy budget and teacher/run controller integration.
