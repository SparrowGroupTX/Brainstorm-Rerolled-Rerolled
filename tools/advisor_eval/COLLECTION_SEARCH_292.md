# Stone Joker collection search helper — 292

The user requested Medusa seed search to obtain the final undiscovered Stone
Joker. Medusa is already an admitted challenge for the separate Legendary
opening search, but challenge purchases cannot add collection discoveries.
The Collection wiki states this limitation, and preserved original source
`runs/diagnostic287_20260913_222344/b_preparation2/source/functions/common_events.lua`
lines1879–1880 confirms that `discover_card` returns for seeded or challenge runs.
No executable ZIP, player profile or save was read for this task.

The user was asked whether to prefer a normal collection route or Medusa anyway.
After allowing time for the optional preference, implementation followed the
stated collection goal. No Medusa Stone-target engine was added or represented
as a way to complete the collection. The existing Medusa Legendary search and
challenge rules remain intact.

## Existing search gap

The normal Joker selector lists Stone Joker, but native fresh-run locks exclude
it (`Immolate/src/functions.hpp`, `Instance::initLocks`). The native timeline
does not model Tower use or Marble's Stone creation. Acquiring Marble in that
timeline therefore does not open Stone Joker's eligibility. Selecting Stone,
including after a Marble target, can search fruitlessly under this unsupported
route. The UI listing alone does not establish a supported search target.

`Brainstorm/Core/Brainstorm.lua` now rejects that normal Stone target before
search/estimation, explains the missing prerequisite model and suggests Marble
first. This guard applies to each target slot and timing/edition, preserving
the separate challenge validator. It does not change native code, unlocks,
discovery or seeded flags, or the current configured target on loading.

## User workflow

After a normal restart activates 292, use Options → Brainstorm → Collection:

1. Click **Use early Marble preset**. This configures the existing normal-run
   search; it does not start it or replace the current run.
2. Use a normal deck and the existing auto-reroll control (default Ctrl+A).
   Play Small and Big
   without skips or shop rerolls. Inspect the first two shops and their Buffoon
   packs, avoiding other Joker acquisitions and Joker-generating cards until
   Marble is found.
3. Buy Marble and select a subsequent blind so it adds a Stone Card. Stone Joker
   can then appear in the actual run; find and buy it normally.
4. **Restore previous search filters** restores the saved filter configuration.

The preset targets **Marble Joker / Ante 1 Early / Any Edition** only. It removes
Soul, skip-tag, pack, voucher, rank-count, later-special and other Joker
requirements for this explicit selection. It does not add perishable/edition
constraints. Existing unrelated filter metadata, CPU preference, advisor/retry
settings and challenge/Jokerless settings are preserved. A deep saved copy of
the previous `ar_filters` survives repeated preset clicks; only an explicit
restore consumes that copy. Both actions refuse changes during active auto-reroll.
Rendering/loading never writes settings or triggers a search.

The existing native early route checks four ordinary stock polls in two size-two
shop windows, then the first four displayed pack types and their Buffoon contents.
The normal filtered-reroll path already marks `used_filter=true` and sets
`seeded=false`;292 preserves this established mod behavior without extending it
to challenges or editing collection records. Manually typing a seed is a different
base-game workflow and still carries its seeded-run restriction.

This is an opening **Marble offer** filter. It does not guarantee affordable
acquisition, survival, a later Stone Joker offer or a completed discovery. No
new seed search or actual run was executed; no search-yield, timing or discovery
success measurement is claimed. Stone eligibility/source guards are documented
from existing code, not a newly qualified native route experiment.

## Validation and release

- `tests/advisor_normal_stone_filter.lua`:30 checks across slots, timing,
  editions, Marble/Showman combinations, settings preservation and challenge
  dispatch. Its bounded receipt is under `runs/stone_validation_development/`.
- `tests/advisor_collection_search_ui.lua`:61 synthetic checks for rendering,
  explicit actions, exact configuration restoration, repeat-click protection,
  active-search protection, route text and selector reachability. No native
  search, source execution, actual overlay or game operation is invoked.
- The initial combined focused receipt is
  `development291/collection_ui292/report.json`; it reuses a generic older
  fixture runner and includes unrelated291 hashes. Candidate/exact-installed
  validation below binds the complete current runtime and test inventory.
- Initial candidate and installed regressions both passed, but the installer
  normalized eight LF-only lines inside the otherwise CRLF Core file while
  stamping its already-correct version. The exact candidate/installed hash
  comparison correctly failed. Normalizing CRLF to LF makes both contents
  identical; this was byte drift, not a runtime behavior change. Original
  evidence remains under `runs/collection292_candidate/`,
  `runs/collection292_installed/` and `runs/collection292_installed_validation/`.
- The installer now preserves unrelated bytes when stamping versions and
  skips an unchanged write, with focused regression coverage. It changes no
  installed runtime behavior and needs no additional runtime release.
  `runs/collection292_byte_drift.json` preserves the original mismatch;
  `runs/collection292_installer_fix/report.json` records all 11 installer tests
  passing, including three new version-stamping cases and a mocked-staging
  preservation check. Source: `install_slice.py`; tests:
  `tests/test_advisor_install_slice.py` at repository root.
- Final evidence re-freezes the actual installed runtime bytes and includes
  the new installer tests: `runs/collection292verified_candidate/`,
  `runs/collection292verified_installed/`,
  `runs/collection292verified_installed_validation/` and
  `runs/collection292verified_final/`. The finalizer requires matching candidate
  and installed digests and the complete unchanged test inventory.

Two runtime files change: `Brainstorm/Core/Brainstorm.lua` and
`Brainstorm/UI/ui.lua`, plus the ordinary version metadata. Both native DLLs and
current installed configuration are preserved. The feature writes its settings
only when the user clicks its controls after activation. Product search and all
gameplay remain user initiated; the running game was left undisturbed.

All previous experiment allowances remain closed. This slice is implementation,
read-only analysis and routine synthetic/regression validation only. No source
component, captured replay, search worker, complete attempt or automation ran.
Jokerless outcomes and the strategy limits of checkpoint291 are unchanged.
