# M23 proposed source inspection: input and settings callbacks

New proposal only. The separate unregistered Canio opening proposal is on hold;
it has not consumed a lease and is not this experiment. Root must review and
register this exact inspection before running it once with a30s outer cap.

Hypothesis: actual original mouse/key dispatch and queued controller callbacks
may cause the initial Start click, a held key, or programmatic queue to reach
the installed315 cancellation hooks. Alternatively a persistent settings/menu
flag may still block readiness. The inspection establishes callback mechanics;
it cannot identify the running game's version or prove which cause occurred.

Only four exact ZIP members are read: main.lua, engine/controller.lua, game.lua,
engine/ui.lua. The first three names/hashes are established by preserved M13
inspection metadata; engine/ui.lua is the explicit UIElement module candidate
and a missing/ambiguous member remains an explicit unsupported result. M16's
complete Game:main_menu is retained as existing provenance; it is not reread.
Each member is capped at4MiB, archive inventory at20,000 entries. Nothing is
extracted except at most twelve declared method excerpts totaling50,000 bytes.

Methods: love.mousepressed, mousereleased, mousemoved, keypressed;
Controller.queue_L_cursor_press, queue_R_cursor_press, L_cursor_press,
button_press_update, update, key_press_update; Game.save_settings;
UIElement.click. The reviewed lexer ignores quoted strings/comments and finds
balanced complete methods. Full original-method hashes and positions are
recorded; any missing, ambiguous or output-truncated method is explicitly
incomplete. No neighboring unbounded text, fallback member search or follow-up
execution is permitted.

Current315 complete frozen policy and its final verification, original archive
hash, Python runtime and inspected source-member provenance are registered.
The worker uses Python ZIP/byte parsing only. It does not load Lua, execute
policy/source, search seeds, touch profiles/saves or control any game process.
