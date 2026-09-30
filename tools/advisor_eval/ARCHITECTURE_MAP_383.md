# 383 64x event-cadence navigation

This delta supplements `ARCHITECTURE_MAP_382.md` and the source inventory in
`development374/FAST_EVENT_CADENCE.md`.

| Question | Source and evidence |
| --- | --- |
| What setting is observed? | `development383/timing_prefix.json` binds three completed public BRJ2 segment hashes, preserved unchanged under `development383/logs1/`; 46 windows are 64x, auto-active, unpaused RUN. The active segment was excluded. |
| What changes the queue rate? | `Brainstorm/Core/event_cadence.lua:target` requests 1/120 at 64x and 128x, 1/240 at 256x only under RUN/ownership guards. `Brainstorm/Core/Brainstorm.lua:Game:update` calls it before the native update. |
| What protects order and other clocks? | The same `event_cadence.lua` release/rebase/debt logic owns only `queue_dt` for a native manager. Original `Game:update` still performs one native pass; REAL timers, screenwipe, controller and frame rendering are unchanged. |
| Where are tests and release? | `tests/advisor_event_cadence374.lua`, `tests/advisor_event_cadence383.lua`, `development383/{SCOPE,REPORT,freeze,release}`, `runs/cadence383_candidate/{freeze.json,validation/}`. Exact-installed evidence is pending a normal game exit. |

The installed Balatro 1.0.1o archive was read statically, never executed.
The 46-window prefix is not a complete outcome or matched speed comparison.
