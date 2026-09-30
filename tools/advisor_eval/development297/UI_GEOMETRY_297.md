# Completionist++ geometry regression

The new ordinary fixture `tests/advisor_gold_layout.lua` reproduces the frozen 296 vertical overflow and staggered pager, then checks the repaired product UI against the same synthetic geometry model. It does not execute original game source or render/control the game. No search, replay, source component, attempt, save or player profile operation ran.

## Model and limits

Read-only topology references: [UI helper definitions](https://github.com/Jofr3/balatro-source/blob/main/functions/UI_definitions.lua) and [UI container sizing](https://github.com/Jofr3/balatro-source/blob/main/engine/ui.lua), inspected 2026-09-14. Freshly authored doubles preserve the button R/C wrappers, toggle checkbox/label padding and scale, option-cycle label/pip/arrow wrappers, central padding/emboss, child orientation, minima, maximum-width text reduction and explicit object dimensions. R children advance vertically; C/text children advance horizontally. The fixture inspects computed button coordinates, not merely the number of definition nodes.

The explicit font envelope is height=scale and monospace character advance=0.40*scale, repeated with both dimensions 8% larger. UTF-8 continuation bytes do not add character cells. Content is limited to 8 width by 5.7 height to leave space for the existing menu controls. This is a regression model, not measured installed-font metrics, exact engine animation/alignment qualification or live visual verification. Long names exercise the UI's maximum-width reduction; this does not prove readability of arbitrary localization strings.

## Final comparisons

Both final receipts bind the same fixture hash `5c32bbbe97d4e8ecfa0ca3a8afaf2cc9901ed07e9d690a3ecc4cf5a5d5607d83`. Each fixture has a 60s outer cap and all bound files stayed unchanged.

| Synthetic case, larger font envelope | Frozen296 | Current297 |
|---|---:|---:|
| All 150 unknown progress |8.3780w x 8.5636h|7.7000w x 4.7822h|
| Prepared Stone/Marble search |8.7754w x 7.2162h|7.7000w x 5.3220h|

- `layoutBaseline3/report.json`: 272 checks passed the expected-defect assertions in 0.09775919996900484s. 81 case/font variants exceeded the reserved content envelope; this count includes repeated pagination cases, not 81 independent defects. Frozen 296 pager buttons and paired search controls occupied different vertical rows.
- `layoutCurrent5/report.json`: 375 checks passed in 0.0967229999951087s. Maximum tracker dimensions 7.7 x 4.7822; maximum search dimensions 7.7 x 5.3220. Pager and prepare/restore buttons share their respective row without horizontal overlap. All 150 target names are reachable through pagination, at most 8 target labels appear on a page, and search uses one no-pip cycle for 150 choices.

Coverage includes all complete/all missing/all unknown progress, carrying and unavailable held status, seeded context, disabled mode, 20 successive Next operations, extended display names, all six unsupported fresh-run prerequisites, Soul/direct routes, Stone prerequisite prepared, restoration and no available targets. Opening/paging is verified write-free; only explicit synthetic prepare/restore calls change the fixture's synthetic settings.

Earlier development evidence remains: `layoutBaseline1`, `layoutBaseline2`, and `layoutCurrent1` through `layoutCurrent4`. `layoutCurrent2` failed a newly added coverage assertion because substring matching counted the name Joker inside Joker Stencil; exact node-text matching fixed that harness error. The geometry envelope was unchanged. `layoutCurrent3` passed but its prepared Stone height 5.6972 nearly consumed the 5.7 allowance; the final UI removed repeated explanatory text. Final source-topology review found missing option-cycle center padding and emboss in the synthetic helper. Those were corrected, and `layoutCurrent5` confirms additional space with the corrected helper. No earlier evidence was rewritten or discarded.
