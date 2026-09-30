# 383 64x event-cadence candidate — 2026-09-25

Three stable, completed segments of a user-started public loaded-label-2.180
win-first auto-run were analyzed while the subsequent segment and game were
active. No terminal outcome is asserted. The exact bounded input hashes and
summary are in `timing_prefix.json` (1,550 events, 46 performance windows,
last included sequence 1,550 at 2026-09-25T14:51:14Z). All 46 windows report
64x, auto-active, unpaused RUN. Their 27,234 frame intervals average 8.477
ms, about 118 frames/s. The flags do not count time spent in screenwipe, so
this is not a measurement of eligible queue passes or animation share.
The three unchanged source segments are preserved under `logs1/`; its
`manifest.json` SHA256 is
`a1e7dce15363b1f9f2b4a73ca62a026ef03586bba8956309b93be88b9c95da4e`.

Static inspection of the installed Balatro 1.0.1o archive, SHA256
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`,
shows the native event manager uses a 1/60 REAL-second queue gate and performs
one pass per update. Brainstorm had requested 1/120 only at 128x and 1/240
at 256x. Thus 64x in the observed prefix retained the 60-pass/s ceiling
despite enough frames for nearly 120. That is a source-supported throughput
gap, not an observed causal fraction of the run's wall time.

The 2.181 candidate requests 1/120 at 64x under the existing unpaused RUN,
native-manager, no-screenwipe/no-overlay guards. One native pass per frame,
queue ordering/blocking, manager ownership, clock rebase, debt cap, REAL
timers, input debounce, auto-run freshness/settlement and all real-time caps
remain unchanged. The candidate changes only `Core/event_cadence.lua` and
the two version declarations. It does not accelerate REAL screenwipes or
pack-area movement and does not claim proportional whole-run improvement.

The existing manufactured cadence fixture now includes 64x in its interval
and one-pass rate model, passing 114 checks. New
`tests/advisor_event_cadence383.lua` passes 46 checks for 64↔128 and 64↔256
transitions, pause/overlay/screenwipe/leave-RUN restoration, foreign manager,
replacement manager, 60/118/120/240/500-FPS bounds and low-FPS debt.
The unchanged game-speed and frame-timing fixtures passed 781 and 89 checks.
A single read-only reviewer inspected the source and implementation, then
rechecked the finished behavioral slice; it found no release blocker. This
is a source/fixture correctness review, not a real-game speed measurement.

Frozen candidate digest:
`a602dadd812016ffa890ab33c084b58f5675d35c1b7b0f6be2027ae33848e546`.
`../runs/cadence383_candidate/{freeze.json,validation/report.json}` binds
108 runtime/dependency files, 293 fixture source files and the three changed
runtime files. Full candidate validation passed **253 Lua fixtures and 392
Python tests** with unchanged frozen policy/test hashes.

Balatro was active during this development pass. No installed files,
settings, saves, logs or native DLLs were changed, and the active game was
not controlled. Candidate 2.181 is **not installed or activated**. Its only
release path is a normal user game exit, fresh installed-baseline/config/DLL
verification, explicit-file backed installation and exact-installed gate.
Later public timing and settled-action records are needed to establish any
actual speed gain or earlier-callback harm.
