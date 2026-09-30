# Game-speed menu extension — 318

The user confirmed search startup and round-to-shop progression now work, then
requested 8x and 16x game animation speed choices. This slice extends the existing
Game speed option cycle. It preserves the current setting until the user changes
it, all prior choices, existing additional numeric mod speeds, localization,
layout and focus. Choices persist through the game's existing save_settings path.

## Runtime and validation

- Brainstorm/UI/game_speed.lua: narrow create_option_cycle wrapper for
  change_gamespeed. Clones arguments/options, inserts 8/16 once and recomputes the
  selected index from the current numeric G.SETTINGS.GAMESPEED. Numeric and
  numeric-string labels are supported. An unfamiliar control delegates intact.
- Selection requires agreement between current_option and the exact offered
  to_val, sets numeric GAMESPEED and invokes G:save_settings once. Stale game
  objects and invalid selections are refused. Merely building the menu saves
  nothing and changes no settings.
- Brainstorm/Core/Brainstorm.lua loads the module after existing UI installation.
  Core and steamodded_compat.lua carry 2.118.0-alpha.
- tests/advisor_game_speed.lua: 361 manufactured checks covering every speed,
  reopened selection, persistence, native layout/argument/return forwarding,
  string labels, extra speeds, malformed input and bounded inspection.
- Independent review found no blocking defect, bound to UI module SHA256
  f4ee6c5643adaa3d1d9487a9a80352627e1393bd193921b6d3378bff9897d536
  and fixture f64ecea34e3390c76f5908acb8416459c1ad853e75b252dea044c05088dfb0ad.

Existing callback interface precedent is UI/ui.lua option callbacks using to_val
and cycle_config.current_option. This slice owns the extended control's callback
to avoid assuming an uninspected original callback's index mapping.

Read-only existing mechanics: gold299_20260914/M13/inspection/game_update.lua
uses numeric GAMESPEED for SPEEDFACTOR, TOTAL time, animation and update steps.
chicot_order_source1/source/engine/event.lua retains normal event queues and
REAL/TOTAL timing. Some game delays themselves include GAMESPEED or use real time;
the numeric setting therefore does not imply a proportional whole-run speedup.
No new executable ZIP inspection, source evaluation, search, attempt or live
game control was performed for this slice. The fixture does not exercise the
actual rendered menu or original settings persistence.

The event engine, real clocks, auto-run readiness/single-action gates, search
deadline and computation budgets are unchanged. Auto-run and collection search
continue to use love.timer.getTime. No skip-animation or event deletion was added.

Candidate and exact-installed regression evidence is under speed318_candidate,
speed318_installed, speed318_installed_validation and speed318_final in runs/.
Those immutable receipts provide actual tests, hashes, backup and settings
preservation. This installation activates on the user's next normal restart;
8x/16x live behavior and timing have not been confirmed.
