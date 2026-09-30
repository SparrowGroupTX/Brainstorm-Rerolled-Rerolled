# Faster game-speed choices — 373 candidate

Status: **frozen and validated but superseded before installation** by the
2.173.0-alpha event-cadence candidate in
`development374/FAST_EVENT_CADENCE.md`. This 2.172 evidence is preserved.
Installed checkpoint remains 2.171.0-alpha; activation is unconfirmed. Do
not install, change current settings, or inspect the new cohort before the
user reports completion.

## Behavioral acceptance before editing

1. The existing Game speed cycle offers 128x and 256x after 64x, keeps every earlier choice and unfamiliar extra value, and opens at the numeric persisted choice without modifying the setting. Numeric and numeric-string label forms continue to work.
2. Selecting either new choice sets only `G.SETTINGS.GAMESPEED` and saves settings once. Invalid or mismatched selections, callbacks retained from a replaced game instance, and unfamiliar controls preserve the existing refusal/delegation behavior. A prior menu event with an identical valid index/label is not distinguishable from a fresh menu event.
3. Auto-run action freshness, settlement, real-time run/search/stall caps, journal cap and all score/search budgets remain unchanged. No direct event-queue, game-loop, render-loop or timer replacement is included.
4. Focused manufactured menu fixtures and the full frozen candidate Lua/Python regression pass with unchanged candidate policy/test hashes. Installation and exact-installed validation wait until the active cohort ends; no activation or measured real-game speedup is claimed.

## Source mechanics motivating this boundary

Static read-only inspection of the installed Balatro archive at `C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe` (SHA256 `0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`, embedded version `1.0.1o`) found:

- `game.lua:2489-2498` derives `SPEEDFACTOR` from `GAMESPEED` during a run and advances `G.TIMERS.TOTAL` with it; `game.lua:2610-2633` passes the factor to animation and moveable updates.
- `engine/event.lua:22-24,171-194` defaults event delays to `TOTAL`, but paused/explicit `REAL` events use the real clock. The event manager's queue pass is gated by `queue_dt=1/60` of real time (`event.lua:117-119`) and processes only one pass per update.
- `engine/animatedsprite.lua:78`, `engine/moveable.lua:250-275`, and `engine/text.lua:158-206` contain effects driven by `G.TIMERS.REAL`; the UI has real-time button delays. `main.lua:69-82` updates and renders by frames with its own FPS cap. Thus the numerical speed setting does not speed every animation or remove CPU/frame/event-order bottlenecks.
- `card.lua:1513` uses a delay proportional to `GAMESPEED`, so its `TOTAL`-timer wall delay is roughly constant at a steady speed. `card.lua:1725,1785` use delays proportional to the square root of speed, so those shorten sublinearly in wall time. These deliberate game formulas are left intact.

The prior frozen loaded-public-label 2.169 ten-start wall audit is `development372/PERFORMANCE_AUDIT.md`: 43.8% of measured wall time lies after action callback before first settled state outside decisions, but no `performance_window` events exist to isolate animation from update, render or journal work. Do not treat that share as pure animation time or as a 128/256 speedup prediction.

## Candidate and next gate

Only `Brainstorm/UI/game_speed.lua` plus the matching version declarations in `Core/Brainstorm.lua` and `steamodded_compat.lua` differ from the installed 371 runtime. `tests/advisor_game_speed.lua` covers all ten standard choices, reopening, persistence, numeric-string labels, preexisting 128/256 and higher mod values, malformed mapping, unchanged original arguments, and replacement-game callback refusal: **781 manufactured checks passed**. One independent read-only review found no release-blocking defect and noted that identical valid index/label events from a previous menu cannot be distinguished from fresh ones; this behavior predates the added speeds.

The frozen candidate is `runs/speed373_candidate/policy`, digest `e3930f89282604d95c0363034406163b7a43a17169c443edc2cd3be84b19814e`. `freeze.json` identifies the three changed runtime files and verifies that installed runtime and configuration still match `SESSION_RESET_371.json`. `validation/report.json` and raw logs show **244/244 Lua fixtures and 391/391 Python tests passed**, with policy and test hashes unchanged throughout the gate. No captured game state, Balatro process, experiment worker or new cohort was run.

The later 374 candidate includes this menu change and is the only pending
release path; see `development374/FAST_EVENT_CADENCE.md` for its exact files
and gate. Until installation and the user's normal restart, 128x/256x are
**not available in the current game**. The standing win-first gameplay
backlog remains `NEXT_PRIORITIES_371.md` and `WIN_RATE_RESEARCH.md`.
