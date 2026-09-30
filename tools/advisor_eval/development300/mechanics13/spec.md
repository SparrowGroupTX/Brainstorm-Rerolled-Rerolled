# M13: original startup and menu/controller safety fields

The reported HUD is the pending facade's “waiting for the menu” state, which precedes any seed search or new-run start. Inspect the original source to identify whether a persistent initialization table or controller sentinel is being mistaken for active work.

Read only `game.lua`, `globals.lua`, `engine/controller.lua`, `main.lua`, `functions/button_callbacks.lua`, `functions/misc_functions.lua` and `functions/common_events.lua` inside the executable ZIP. Never execute the executable or source Lua; never inspect the running game or player files.

Preserve member hashes and bounded exact method excerpts for Controller initialization/update, Game update, exit-overlay and overlay creation. Also preserve bounded neighborhoods for SAVING/LOADING, frame/frame_set lock handling, aggregate controller.locked, controller update dispatch, main-menu state, and STATE_COMPLETE assignments. Match counts and truncation remain explicit; total output is capped at 280,000 bytes.

Root must register and dispatch the fresh M13 one-use 30-second source-mechanics lease. Existing M11 inspection evidence and prior worker authority are not reused. The resulting diagnosis must retain meaningful active-save/input/transition protections and identify precise blockers; it must not simply ignore all locks.
