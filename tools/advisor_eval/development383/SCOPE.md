# 383: 64x event-queue cadence

2026-09-25. The installed checkpoint is 2.180.0-alpha with exact candidate
and installed validation in `SESSION_RESET_382.json`. A later user-started
auto-run is active, so no installation or game control is permitted now.
Three completed, stable BRJ2 segments from its public loaded-label-2.180,
win-first session were
read passively through the existing bounded timing analyzer; the active tail
was excluded. Original stable bytes were copied unchanged to `logs1/`, whose
manifest matches every analyzer input hash. `timing_prefix.json` binds all
three input hashes and reports
46 completed five-second windows, all at game speed 64x, auto-active,
unpaused RUN. Across 27,234
observed frame intervals the mean was 8.477 ms (about 118 frames/s). This
is a partial prefix and does not isolate animation time or terminal outcome.

Static Balatro 1.0.1o source, SHA256
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`,
sets the event-manager default `queue_dt` to 1/60 REAL seconds and permits
one pass per update (`engine/event.lua:117-119,171-194`). The installed
Brainstorm cadence requests 1/120 at 128x and 1/240 at 256x only. Thus the
observed 64x run can be limited to roughly 60 event passes/s despite enough
rendered frames for nearly 120. This is a concrete throughput gap, not proof
that all its long transitions are event-queue limited. Explicit REAL screenwipe
and physical card arrival remain separate unresolved paths.

## Behavioral acceptance

1. In an unpaused RUN at 64x, with no screenwipe or overlay, request 1/120
   only for a native-shaped manager still owned at its default 1/60 cadence.
   Keep exactly one native event-manager pass per `Game:update`, native queue
   order and blocking semantics. Retain 128x/256x behavior.
2. Restore the exact default interval and rebase to the manager's own clock
   on leaving eligibility, pause, overlay, screenwipe or manager replacement.
   Do not seize a foreign cadence or create accumulated catch-up debt.
3. Retain all real-time run/search/inactivity caps, auto-run action freshness
   and settlement, current settings, RNG, score budgets, native DLLs, REAL
   timers, screenwipe and input debounce. Do not promise proportional whole-run
   speedup or treat incomplete timing as a complete cohort.
4. Extend the existing manufactured cadence fixture and add a focused 64x
   fixture for 60/118/120/240/500 FPS, eligibility transitions, same-target
   64↔128 switch, 64↔256 rebase, foreign ownership and low-FPS debt. Run
   targeted and then full frozen candidate regression. A read-only reviewer
   must check the one-pass and transition invariants. Install only after the
   current user-run ends normally; then use explicit-file backup and exact-
   installed validation before declaring release.

This is one speed slice. It does not adjust the `REAL` clock globally,
shorten screenwipe timers, move pack areas, remove animations or start a
gameplay experiment. Future public timing and settled action records are
needed to measure actual wall-time benefit and detect earlier-callback harm.
