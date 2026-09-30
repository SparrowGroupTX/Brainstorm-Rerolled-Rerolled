# Vanilla Gold sticker mapping correction

The reported `0 Gold / 0 missing / 150 unknown` display is reproduced by giving
the unchanged 296 tracker the ordinary vanilla sticker map. The tracker tested
its eighth value against lowercase `gold`; the game uses the display name
`Gold`. That global verification gate rejected every otherwise-valid Joker row.
The initial synthetic fixture used lowercase names too and concealed this bug.

The runtime correction changes that exact comparison to `Gold`. It does not
remove catalog, stake, profile-history, held-inventory or run-eligibility checks.
The fixture now uses all eight source-shaped title-case display names and also
rejects incorrect capitalization, other colors and malformed/missing values.
Known positive numeric Gold wins, lower-stake-only history, missing entries and
malformed records keep their separate meanings. No progress is inferred from
acquisition, holding a Joker, or a successful fixture.

Source evidence is read-only public `game.lua` text:
<https://raw.githubusercontent.com/Jofr3/balatro-source/main/game.lua>.
The exact retrieved file hash and raw line ranges are bound in
`metadata_source_reference.json`; the `P_STAKES` level/order and stake-pool
structure agree with the existing tracker. The archived
`runs/planet_pool_source1/source/functions/misc_functions.lua` 1034–1069 remains
the source for numeric `joker_usage[key].wins[stake]` and sticker-map lookup.
This is source-text corroboration, not installed-game execution or profile
qualification. No player save/profile file was read.

`metadataBaseline1/report.json` preserves the source-shaped fixture failure
against unchanged 296 runtime bytes (`d0c58b12b81c4a147b61d5824e1570423eb5c8a45331e399976fa2ebe90122ff`).
`metadataFixed1/report.json` preserves 316 passing synthetic checks after the
behavior correction. `metadataFinal1/report.json` binds the final comment-only
source-location cleanup to the same passing checks. Each run is one ordinary
fixture with a 60-second cap; no source component, captured replay, search,
terminal attempt, game control or experiment allowance was used.
