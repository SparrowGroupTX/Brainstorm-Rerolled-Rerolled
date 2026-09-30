# 304 Gold search and auto-run startup repair

The user reported that both **Start auto-run + logging** and **Search and start
new run** closed the menu without rerolling. The automatic HUD remained at
"waiting for the menu to close." That status precedes native search; revealing
the existing run was not evidence that a searched seed lacked its Charm Tag.

M13's bounded read-only inspection of seven original Lua ZIP members identified
two shared readiness mistakes. `boot_timer` retains `G.LOADING={font=Font}` as
display cache, rather than clearing an active-loading flag. `Game:main_menu`
calls `prep_stage(MAIN_MENU,MENU,true)`, which sets `STATE_COMPLETE=false`, and
the original `Game:update_menu` is empty. Requiring truthy state completion in
the actual settled main menu prevented startup there independently of the cache.

`Brainstorm/Core/collection_search_product.lua` and `auto_run_product.lua` now
recognize only the plain font-only boot-cache shape as inactive. Boolean true,
unknown shapes and metatables still block loading. Only exact MAIN_MENU/MENU
bypasses STATE_COMPLETE; unfinished run states, splash/demo screens, overlays,
pauses, screen wipes, controller/frame locks, text entry, dragging, played cards,
pending card actions and checkpoint/save operations retain their guards.

Pending manual and automatic starts expose their actual waiting reason. The
search still starts on a separate settled update, with the same one-use receipt,
profile/run binding, cancellation and30-second maximum. No native DLL changes,
seed search, player state manipulation or automatic activation accompanies this
repair. Optional Burnt fallback and adaptive missing-target quotas remain separate
work and are not claimed in304.

The integrated focused run `development294/startup304a/report.json` passed five
fixtures:154 product checks,111 auto facade checks,29 Core checks,30 terminal
checks and470 advisor runtime checks. It includes persistent cache and actual
main-menu shape regressions while retaining active-loading and input guards.
The initial detached fixture's mistaken checkpoint-queue expectation is preserved
under `development300/startup_loading_fix/failed_fixture1.json`.

Source evidence: `runs/gold299_20260914/M13/inspection/inspection.json`,
`functions_misc_functions__saving_loading_1.lua`, `game__state_complete_1.lua`,
`game__menu_state_4.lua`, `game__state_complete_18.lua` and `controller_update.lua`
in that inspection directory. The original members, complete-method hashes,
truncation flags and bounded neighborhoods remain separate from synthetic tests.
M13 ran no Lua/game source, search or policy decisions and read no player files.

Candidate digest:
`e553ec3b04ba3e020e4c5c7b690b1939ae686faa95b77f77de3c60591d764d8c`.
Exact candidate/installed regression and installation are recorded under
`runs/startup304_candidate/`, `startup304_installed/`,
`startup304_installed_validation/` and `startup304_final/`. Installation alone
does not activate this code; the user's normal restart is required. No live
automatic run or achievement completion is established by these tests.
