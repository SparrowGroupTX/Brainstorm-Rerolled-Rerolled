# Tooling checkpoint406 — suspect-decision screening

2026-09-26. The user requested a rigorous automated review queue for qualitative
choices, explicitly including Invisible, Joker packs, short discards and rounds
cleared with unused discards. `SUSPECT_DECISION_SCREEN_406.md` describes the new
offline tool and its limits. `development406/REPORT.md` records the historical
demonstration; `REVIEW.md` records the bounded independent review and repairs.

Full declared Python gate: **452 tests pass**, including39 new manufactured
screening tests. Exact tooling/test/helper provenance is frozen separately in
`development406/validation/manifest.json` and `report.json`.314 current test
files are bound. This is tooling-only; no new Lua runtime gate/install is needed.
Original404 candidate/installed gates and405 evidence remain untouched.

Repository and installation remain exact2.195 checkpoint404,109 dependencies:
`6a7281852e571cbf4b3ff9bedf742fc5bfbe80a8374192aac80cc408cd855cea`.
Settings, native DLLs and all previous work are preserved. No game control,
active-journal audit, saves/profiles, captured-policy/scorer replay, new source
experiment, training or automation occurred. New-session loaded label/outcomes
remain unconfirmed; no win-rate or runtime improvement claim is made.

This screening slice and its one substantive review/one focused recheck are
complete. When the user reports the current session complete, preserve it and
apply the screen alongside the complete cohort audit403 workflow. Flags are
triage hypotheses, not automatic fix requirements. Do not repeat the old cohort
as new gameplay evidence. Existing preservation, execution, budget and release
boundaries remain mandatory.
