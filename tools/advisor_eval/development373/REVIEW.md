# Read-only speed-menu review — 2026-09-23

One independent read-only reviewer inspected `Brainstorm/UI/game_speed.lua`,
`tests/advisor_game_speed.lua`, both 2.172 version declarations and
`development373/SPEED_OPTIONS.md` after the candidate edit. The frozen
candidate policy digest is
`e3930f89282604d95c0363034406163b7a43a17169c443edc2cd3be84b19814e`.

The reviewer found no release-blocking defect. The added values appear once,
sort numerically, reopen from a persisted numeric setting, retain numeric-string
labels and unfamiliar extra speeds, and save once per valid selection. Invalid
mapping and replaced-game callbacks are refused. This UI module does not touch
auto-run settlement, session caps, event queues or game timers.

The reviewer noted an existing limitation: a callback from an earlier menu
with the same valid index and label can still select that value in a later
menu for the same game. The scope document now states that limited guarantee;
the new options do not introduce a changed mapping for those values. Static
review and menu doubles cannot establish live 128x/256x timing or rendered
behavior. No tests, installation, game control, journal or save inspection was
performed by the reviewer.
