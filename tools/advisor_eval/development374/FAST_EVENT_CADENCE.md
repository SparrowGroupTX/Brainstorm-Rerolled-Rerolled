# Coordinated high-speed event cadence — 374 candidate

**2026-09-23 release update:** The user-confirmed marathon ended before
installation. This unchanged speed/cadence implementation was combined with
the bounded WR-013 copy-rating repair and installed as **2.174.0-alpha**
under `SESSION_RESET_375.md/.json`. Candidate and exact-installed gates each
passed 246 Lua fixtures and 391 Python tests; all 91 deployment and 107
runtime/dependency files match. Its own 2.173 freeze, validation and review
remain valid intermediate evidence but were never installed separately.
Normal user restart is needed for 2.174 activation. No whole-run acceleration
has been measured. The original pending status and instructions below describe
the state at the 374 candidate freeze and are superseded by this update.

Status: **frozen and full-candidate-validated repository candidate
2.173.0-alpha; uninstalled.** The installed checkpoint is 2.171; the
user-started newer marathon may still be active. Do not inspect it, change
active settings, install or control the game. The validated but uninstalled
2.172 speed-menu candidate in development373 is preserved as superseded
intermediate evidence.

## Source and observed constraint

The installed Balatro 1.0.1o archive SHA256 is
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
Static inspection only: `game.lua:2495-2498` advances TOTAL game time by
GAMESPEED, but `engine/event.lua:118,171-194` gates queue passes by a real
1/60-second `queue_dt`. Each blocking event stops later blockable events for
that pass even when it completes, so raising GAMESPEED alone cannot remove
the pass-rate floor. `game.lua:2509-2638` performs state, movement, UI and
controller updates between passes. Do not run multiple event passes inside a
single frame or rewrite event delays.

The prior frozen loaded-label-2.169 ten-start audit found 1,140.198 seconds
post-callback-to-first-settled outside decision intervals, including 655.681
seconds for play actions (`development372/PERFORMANCE_AUDIT.md`). These are
not proven event-manager or animation costs; no frame performance windows were
recorded. This candidate tests a source-supported throughput bottleneck,
not a measured speedup or new win-rate hypothesis.

## Behavioral acceptance

1. At exactly 128x/256x, during an unpaused RUN with no overlay or screenwipe,
   and only for a native-shape manager still using its default 1/60 cadence,
   request 1/120 or 1/240 second between native event passes respectively.
   Keep exactly one native pass per `Game:update`, all queue ordering/blocking,
   REAL/TOTAL timers and gameplay callbacks untouched.
2. Capture the original manager cadence per manager identity; restore it on
   pause, overlay, screenwipe, other speed, leaving RUN, and manager replacement.
   An unfamiliar or externally changed cadence must not be overwritten.
   Rebase only against the manager's own `queue_timer`. Bound accumulated
   scheduler debt so a later high-FPS period cannot turn a nominal 120/240
   cadence into an unlimited catch-up burst.
3. Keep auto-run readiness, settlement, one-action freshness, real-time run/
   search/stall caps, journals, settings, score budgets, search recipe, RNG
   and native DLLs unchanged. Existing 128/256 menu behavior remains, with a
   distinct version label and no automatic selection of a faster speed.
4. Manufacture fixture contrasts for eligible/blocked phases, all transitions,
   manager replacement, external ownership, debt bounding and simulated frame
   rates. Full frozen candidate Lua/Python regression is required. No original
   game source or captured state is executed. Installation/exact-installed
   gate wait until the user reports the current marathon complete.

## Other unaccelerated paths and limits

The installed archive's explicit `timer = 'REAL'` event assignments occur in
`functions/button_callbacks.lua` (screenwipe), `functions/UI_definitions.lua`
(unlock/overlay presentation), `functions/common_events.lua` (recurring card
juice) and `functions/state_events.lua` (tutorial), in addition to the event
constructor's paused-state default. This is a static assignment inventory,
not measured contribution to the marathon wall time.

| Remaining path | Source-supported behavior | Safe next treatment and evidence needed |
|---|---|---|
| REAL screenwipe | `button_callbacks.lua:3129-3202` schedules coordinated 0.3/0.55/1.1/1.2 s REAL events, including removal and a blocking tail. `game.lua:2495` deliberately returns SPEEDFACTOR to 1 during a wipe. | A separate bounded screenwipe-local shortening could preserve the relative order, removal and blocked-tail release. It needs transition fixtures and a measured active-run share. Global REAL scaling would also alter pause-created events. |
| Physical arrival and pack materialization | `game.lua:2618-2632` calls `Moveable:move` with unscaled real dt, then `Moveable:update` with speed factor. `card.lua:1785-1793` waits for pack-area position before emplacement. Other pack/explosion delays use `sqrt(GAMESPEED)` or proportional `GAMESPEED`. | Measure the actual arrival wait, then accelerate only a proven visual transit while retaining the geometry gate and card-generation/RNG order. Shortening timer literals or skipping the position check is not qualified. |
| UI and input timing | `engine/ui.lua:456-457,681,943-968` uses REAL button delay and click debounce; `game.lua:2638` updates the controller with real dt. | Preserve duplicate-input protection and auto-run settlement. Any automatic-only bypass needs an explicit one-action freshness proof and fixtures. |
| Cosmetic REAL effects | `engine/text.lua:158-206`, `engine/animatedsprite.lua:78`, `engine/moveable.lua:250-275` use REAL for letter motion, sprite frames and juice; other REAL references color/shader effects. | Optional cosmetic reduction could save drawing/update work, but changing these clocks alone may have no wall-time benefit. Profile first and isolate from gameplay position or readiness. |
| CPU, draw and storage | Native search, Lua scoring, frame update/draw, VSync/FPS and journal I/O all consume real work. `main.lua:81-82` already caps at 500 FPS, while actual frame rate is unknown. | Use public frame timing/profiling and optimize the measured dominant function or rendering cost. GAMESPEED and event cadence cannot multiply CPU throughput. |

At <=60 rendered updates per second, this cadence change may provide no
benefit. It processes no more than one native event pass per frame and does
not make all animation 128x/256x faster. Exact full-run speedup needs a later
user-started observation with version/speed provenance, never a claim from
the manufactured fixtures alone.

## Validated candidate and release boundary

`Brainstorm/Core/event_cadence.lua` requests 1/120 or 1/240 only under the
guards above; `Core/Brainstorm.lua:1766,1890` attaches it before the native
update. `UI/game_speed.lua` retains the 128x/256x control. Focused fixtures:
`advisor_event_cadence374.lua` **101 checks**, `advisor_game_speed.lua`
**781 checks**, and `advisor_frame_timing.lua` **89 checks**. The independent
read-only source review and one focused recheck found no ordering violation
in this one-pass approach, while emphasizing that real-game timing/outcome
invariance remains unproven and no manager multi-pass should be added.

`runs/speed374_candidate2/freeze.json` and `validation/report.json` bind
four changed runtime files, digest
`7fc4d97b90fabc62707a327ad7948f0991d456c42b8dc9a930a7b6376a761334`,
and **245/245 Lua fixtures plus 391/391 Python tests passed** with unchanged
policy/test hashes. The installed 2.171 runtime, current configuration and
seven native DLLs still matched `SESSION_RESET_371.json` at freeze. The
initial candidate under `runs/speed374_candidate/` also passed its full
gate, then was superseded before release by an added malformed-queue guard;
retain both evidence sets.

After the user confirms the running marathon has ended, verify repository
against this exact frozen policy and perform explicit-file backed installation
of `Core/Brainstorm.lua`, `Core/event_cadence.lua`, `UI/game_speed.lua` and
`steamodded_compat.lua`, preserving settings, journals, saves and all seven
native DLLs. Freeze and validate exact installed bytes. Installation still
requires the user's normal restart for activation. No measured whole-run
speedup or improved win rate is claimed.

Read-only source context: [Steamodded Event Manager guide](https://github.com/Steamodded/smods/wiki/Guide-%E2%80%90-Event-Manager) describes blocking/timer semantics; [HandyBalatro](https://github.com/SleepyG11/HandyBalatro) and [Nopeus](https://github.com/MathIsFun0/JensBalatroCollection) show other mods expose high-speed/animation-skip controls, but their claims and compatibility are not validation of this local candidate. The installed source and preserved runtime gates above determine the scope.
