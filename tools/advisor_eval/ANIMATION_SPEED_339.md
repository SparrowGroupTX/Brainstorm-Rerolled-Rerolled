# Game speed 32x and 64x - 339

The user requested 32x and 64x choices in addition to the existing speeds.
`Brainstorm/UI/game_speed.lua` extends the existing extra-values list from
8/16 to 8/16/32/64. The value-based sorting, duplicate detection, selection
mapping and native settings persistence are unchanged. Existing additional mod
speeds remain available. Opening the menu does not change the current setting.

`tests/advisor_game_speed.lua` now covers all eight standard choices, saved
selection at 32/64, both string labels, extra speeds and existing 32/64 labels,
exactly one save per selection, invalid input, native argument/return forwarding,
unchanged layout and stale-game rejection. Its 549 checks passed in the
full candidate regression. Final records own the full candidate/exact-installed
suite counts and hashes. Read-only independent review found no additional
runtime integration needed; the previously invalid index7/value32 fixture was
updated because that combination is now valid.

Source/fixture baselines are retained under `development339/before/`.
Evidence: `runs/speed339_candidate/validation/report.json`,
`runs/speed339_installed/record.json`,
`runs/speed339_installed_validation/report.json`, and
`runs/speed339_final/final_verification.json`.

Relevant existing speed mechanics and implementation boundaries remain in
`ANIMATION_SPEED_318.md`. Native event/timer behavior, real clocks, advisor
budgets and auto-run gates are unchanged. The test uses settings/menu doubles;
the actual rendered menu and original-game timing at 32/64 are unverified.
Numeric speed does not promise proportional whole-run speedup. No game control,
save/profile read, source experiment, search or complete attempt occurred.
All experiment allowances stay closed. Current settings, logs and native DLLs
are preserved, and activation waits for the user's normal restart.
