# Gold progress compatibility and menu fit — 297

The user's screenshot showed all150 Jokers unknown and a Completionist++ page
extending below the menu's Back button. Both were implementation defects, despite
the earlier passing fixtures. The metadata fixture used the same incorrect
lowercase assumption as the product, while UI fixtures replaced real nested
helper wrappers with flat nodes and checked counts rather than occupied space.

`Brainstorm/Advisor/gold_stickers.lua` now requires vanilla `sticker_map[8] ==
'Gold'`, replacing the incorrect lowercase comparison. Source-shaped synthetic
tables reproduce all150-unknown against frozen296; the corrected tracker passes
316 checks. No mapping/history/profile/held/run safeguards were removed, and
unknown records are never reclassified as missing merely to fill the screen.
Source URL, exact hash, lines, failed baseline and fixed receipts are in
`development297/METADATA_FIX_297.md` and `metadata_source_reference.json`.

`Brainstorm/UI/advisor.lua` now uses eight entries in four explicit two-column
rows, compact spacing, a smaller tracking toggle, and a conditional Enable
button. Pagination requests column wrappers from UIBox_button and uses a column
for the page count, so Previous/Next align horizontally. Redundant explanatory
text was removed; Find a missing Joker remains available. Metadata failures now
name the failing global category/reason instead of the former generic message.
Gold search also uses compact controls, an unlabelled selector, paired action
buttons and shorter wrapped instructions, preserving explicit click and backup
behavior. No other menu page or tactical policy was reworked.

The read-only source helper contract is
<https://raw.githubusercontent.com/Jofr3/balatro-source/main/functions/UI_definitions.lua>:
UIBox_button returns a row by default and a column for `col=true`; toggle and
option-cycle helpers add their own padding/minimum dimensions. The attached
screenshot is user-provided visual evidence, not permission to control the game.
No source UI function or engine was executed as an experiment.

Tests: `tests/advisor_gold_stickers.lua`, existing `advisor_ui.lua`, and new
`advisor_gold_layout.lua`. The geometry fixture uses freshly authored helper
models with source-shaped wrappers, orientation, minimum dimensions, padding,
emboss and an explicit synthetic font envelope, including an8% larger case. It
checks the8x5.7 content budget, button alignment, all150 reachable target labels,
eight entries per page and search/disabled/unknown/prepared states. Frozen296
reproduces overflow and staggered buttons. This is a useful regression model,
not a live screenshot or qualification of arbitrary fonts/scales/mods.

Focused integration evidence: `development294/fix297Integrated1`; original
metadata reproduction and all geometry receipts remain under `development297`.
The geometry fixture's substring-based false failure is preserved separately;
the assertion was corrected to compare exact label nodes, without reducing
the geometry bounds. Final frozen candidate/installed/full regression and
preservation records use the `fix297` prefix. The prior guide is retained
byte-for-byte at `development297/COMPLETIONIST_PLUS_PLUS_GUIDE_296.md`.

No search, captured-state replay, source component, terminal attempt, game
control or actual profile/save-file access occurred. Source inspection and
routine fixtures/regressions used no historical experiment allowance. Current
settings and both DLLs are preserved; activation waits for the user's normal
restart. Actual player sticker counts and live layout after this update have
not been observed by tools. No win, speedup or human-superiority claim follows.
