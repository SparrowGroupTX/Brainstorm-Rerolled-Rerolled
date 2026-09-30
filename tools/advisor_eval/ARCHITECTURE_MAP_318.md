# Current architecture —318

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_318.md`
and `.json`. Current work: `NEXT_PRIORITIES_318.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `ANIMATION_SPEED_318.md`.

Unchanged architecture inherits ARCHITECTURE_MAP_317.md. Read current session and
priorities before historical pending items. Current additions:

| Area | Runtime source relative to Brainstorm/ | Tests relative to tests/ | Evidence |
| --- | --- | --- | --- |
| Game speed8x/16x menu | UI/game_speed.lua; Core/Brainstorm.lua loader | advisor_game_speed.lua | ANIMATION_SPEED_318.md; speed318 release records |
| User-confirmed search and cash-out | Core/collection_search_runtime.lua; Advisor/execution.lua/runtime.lua; Core/auto_run_product.lua | advisor_collection_worker_loading.lua; advisor_cashout_button.lua | STARTUP_WORKER_316.md; CASHOUT_BUTTON_317.md; CURRENT_OBJECTIVES_318.md |
| Pending Yorick additive growth correction | No318 runtime change; detached development300/growth318/revision2 | Detached manufactured fixtures | development300/c06_postmortem/POSTMORTEM.md |
| Pending optional third pack policy/history receipt | No318 runtime change; detached development300/pack_five319 | Detached manufactured fixtures | Package manifest when finalized |

The speed wrapper changes only the existing menu control and GAMESPEED selection.
It does not modify EventManager, clocks, scoring, draw worlds or execution
readiness. M13 preserved game_update supplies read-only numeric-speed mechanics;
no new source experiment qualified the rendered menu. Real-time search/auto-run
deadlines remain independent of animation speed. Release tooling and exact-byte
verification are unchanged from317; every fresh installation needs a normal
user restart, regardless of earlier version confirmations.


Preserved earlier navigation: `ARCHITECTURE_MAP_317.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
