# Revealed pack Fool creation — 2.78, 2026-09-13

Installed 2.78 adds the pending `pack_scoring.lua` Fool projection to the
installed 277 policy. A revealed pack Fool creates one fresh, editionless copy
of the known previous Tarot or Planet in held inventory. It does not apply the
generated card's effect, spend it, change the playing population, or promise a
future use. The source's forced key permits an already-owned duplicate.

The projection requires an available unreserved consumable slot and complete,
unambiguous source catalog metadata. Missing, banned, malformed or unsupported
identities abstain; a banned forced key would fall back to random source
generation. It preserves existing Negative cards and the observed capacity.
Only the used Fool increments Tarot/all usage and becomes `last_tarot_planet`.
Fresh ability/base fields, discount/inflation/Astronomer price and resale are
projected. Temperance receives its settled capped Joker-resale payout field,
without paying money. Its later use remains a separate action.

Active Perkeo, including its copy-Joker arrangements, and Observatory retain
the existing strategic whole-inventory path: the tactical comparison does not
price future copying-pool dilution. Unknown catalog/capacity/history or any
incomplete paired comparison likewise preserves the whole-family fallback.
No scoring budget, candidate allowance, RNG, growth, Glass/population, or owned
Fool-use planner was expanded. The successful full Fool-plus-Empress fixture
uses 2,640 score calls under the existing 50,000 shop ceiling.

## Source inspection

Read-only executable-ZIP excerpts and member hashes are preserved in
`runs/fool276_focus4/source_review.json` and `source_review.txt`. Executable
SHA256 is `0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
Relevant original locations: `card.lua` 1373–1383 (creation ), 1553–1556
(capacity ), 97–143 and 277–337 (fresh metadata),369–384 (price/resale),
4167–4175 (Temperance); `functions/common_events.lua` 2082–2153 (forced
unbanned identity and Joker-only edition roll); `functions/misc_functions.lua`
1184–1226 (usage and deferred last identity). This is source inspection,
not an executed source-parity worker or complete-attempt outcome.

## Validation and installation

`runs/fool276_review1` failed because the synthetic fixture omitted
`Shop.paired_deck`, although production already binds it. The Fool comparison
had completed; the neighboring Empress comparison could not model its changed
deck. `runs/fool276_diagnosis1` preserves that diagnosis. This failure was test
wiring, not a demonstrated runtime defect. `fool276_focus2` named a nonexistent
fixture and ran no tests; its failed command remains preserved.

`runs/fool276_focus4`: six relevant fixtures  / 227 checks pass in 0.5624982s under
a 30s cap, including 61 Fool checks. The stable runtime SHA256 is
`a25282597b6a330872afdaeea729c7f5c4a4f8d751fdbceb324f97c06ea53949`;
the Fool fixture SHA256 is
`f5acf8aa8eac7efaa26ee792e839ac5f771aeb60fd34add083d396c08a08e4bd`.

Installed receipt: `runs/jokerless278_installed/record.json`, installed at
2026-09-13T13:48:02.8601107-05:00. Backup is
`advisor-20260913-134802`. All 51 deployment files were verified; the 66-file
frozen product digest is
`7bb3594f74cbe12b2759891d785007a65e15ebfd7c8872ef3c3cc25bd889c0a0`.
The predecessor 277 digest is
`1b5425735afb8190359949faef16084f8fc5394c041f559e43b83634fbf30a36`.
Settings remain `083f6c62a485cceceae4f0c55708ddde2750d18a0912e39cfcca47fc0e722f6c`.
Native binaries were preserved. Loaded game version remains unknown.

`runs/fool278_full1` independently copies exact installed 278 plus 254 frozen
test/tool support files. Full 111 Lua fixtures and 253 Python tests pass under
separate 60s caps (15.0533s and13.1211s); all frozen policy/support hashes remain
unchanged. The pending `advisor_fast_clear_retention.lua` fixture is explicitly
excluded because its worktree runtime is not part of installed 278. No source
workers, live-game control, save reads/writes, or win/rate claims enter these
tests. Source cohort7–9 stays frozen 277 and does not evaluate this Fool slice.
