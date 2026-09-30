# Maintenance405 result

Fixed a source-reproduced public-log aggregation defect and stale development
documentation while the user's new game runs. Runtime source and installation
remain exact checkpoint404, version2.195.0-alpha. No new release is needed.

The previous timing/index tools accepted two individually valid same-session
BRJ2 files with adjacent event numbers even when the second file named a
different predecessor. They also accepted reused/regressed segment IDs across
files. This could pool incompatible public evidence into one timing/inspection
scope; no claim is made that any previous actual cohort contained this fault.

`analyze_player_timing.py:Summary.consume` now checks the available frame link
and strict segment increase across files before counting the successor.
`inspect_player_log.py` inherits that admission and exposes the same bounded
integrity receipt. The low-level decoder/extractor remains fragment-compatible:
a standalone later segment can have an unknown outside predecessor. Distinct
sessions are independent; empty segment-number gaps are allowed. Successful
fragment parsing still cannot establish session completeness or terminal wins.

Manufactured acceptance and unchanged regression suites pass:

* 7 new integrity tests; 23 existing player-timing tests; 18 inspection tests.
* Full declared Python suite: **413 tests passed** (402 advisor, 9 teacher timing,
  2 wall-time decomposition), with runtime/test/helper provenance unchanged
  during validation. `validation/manifest.json` and `report.json` bind exact
  inputs, commands, interpreter and original logs.

The initial fixture helper mistakenly held unittest subTest across a generator
yield, causing cleanup errors when the expected product failure occurred.
`fixture_attempt1.py` and `initial_reproduction.log` retain that mistake.
After correcting only the test helper, seven tests ran with three genuine
pre-repair failures and no harness errors (`reproduction_corrected_fixture.log`).
The later passing suite preserves those acceptance assertions.

README previously called2.65 current, left an old16-worker allowance described
as pending, described headless episodes as current work, and instructed
per-feature installs/subjective win estimates. It now points to installed404,
separates historical capabilities from closed experiment authority, and states
the current exact release/normal-exit requirements. Original guide/helper bytes
are preserved under `before/`. `../PUBLIC_LOG_INTEGRITY_405.md` explains the
actual multi-file and standalone-fragment contract, including its limitations.

One substantive read-only review and one focused recheck were completed;
see `REVIEW.md`. This is analysis integrity, not a gameplay speedup or stronger
strategy claim. The new active run's loaded label, decisions and outcomes were
not inspected. No game/process control, save/profile access, live journal writes,
captured policy/scorer replay, source/native search, training or automation ran.

The existing404 Lua/runtime gate is preserved and was not needlessly repeated
for this tooling-only change. Its original helper/test provenance remains
historical;405's separate manifest describes the current analysis-tool bytes.
`../TOOLING_CHECKPOINT_405.md` and `final_verification.json` record final scope
and unchanged installed runtime/native files. No new gameplay result is claimed.
