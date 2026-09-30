# Auto-run stop and repeated collection choices — 348

## Latest observed stop

The frozen latest session `session-20260916T060145Z-1` records loaded
2.147.0-alpha. Sequence 1854 at 2026-09-16T06:10:58Z (01:10:58 CDT) is an
automatic `session_stopped` event with reason `log_unavailable` and detail
`Controller data must be plain finite values.` The current run, YVYN2Z11, is
unfinished at Ante 6, round 16, with $58, in a Jumbo Celestial Pack. Its advice
is Choose Black Hole; no Black Hole choice request follows. One earlier run
in that session lost. The stopped run is not counted as a loss or a win.

The last accepted action opened the pack (request 1851, accepted 1852), followed
by settled pack observation 1853. The previous successful controller fingerprint
record was 258,571 bytes, only 3,573 below the controller's 262,144-byte generic
string bound. All 16 held Tarot certificates were supported. Advice was complete,
used zero score calls and took about 0.088 seconds. Subsequent frozen events are
performance windows showing the controller inactive and no advisor worker.

`auto_run.lua` emits `action_observed` with the old and new exact state keys.
Its strict copier rejected large strings before `auto_run_product.lua` could
replace those fields with their existing SHA256/length metadata. The error
message also covers nonfinite or otherwise invalid values, but the recorded
branch and field types identify the newly grown fingerprint as the relevant
failure: the prior key is below the limit, the new key is a string, and the
remaining header/token fields are bounded and finite. Its exact rejected size
was not logged. This is source-derived attribution supported by a manufactured
reproduction, not an invented measurement of the discarded key.

## Implemented repair

The controller accepts an optional trusted `project_log` callback. It builds
the event, calls that projection, requires a plain table, then runs its unchanged
bounded copier and journal callback. Projection failure or invalid output still
stops before execution. Exceptions receive a static error message, with no raw
record fallback.

The product supplies its existing fingerprint projection at this earlier
boundary. Top-level fingerprint/before/after and the defined interrupted
checkpoint fingerprint become SHA256/byte-length records. A separate writer
prevents double hashing. Explicit start/resume/terminal logging retains the same
projection wrapper. Missing or failed hash support still exports bounded
unavailable metadata, never the raw key.

Exact raw keys remain in pending-action state, equality comparisons and both
execution freshness gates. No raw key is truncated, no generic copy limit is
raised, and action/session/retry/search/score allowances remain unchanged.
Installation does not retroactively resume the fault-stopped controller.

## Why the Jokers repeat

The current recipe explicitly requests Yorick + Perkeo, Blueprint/Brainstorm by
Ante 5, and preferably Burnt. Their existing Gold stickers do not remove them
from the requested support core. Automatic missing quota requests one reachable
conditional missing offer; the observed session uses Antes 5–8. This proves
neither affordable purchase nor retention to a win. The first Legendary adapts
only after the fixed opening has no reachable missing target.

There is also a separate restart continuity defect. The cursor lives only in
`Brainstorm.collection_search_cursor`; boot recreates the Brainstorm table and
initializes a new cursor from wall time. The preceding loaded 2.146 session and
latest loaded 2.147 session both found M4BVSY11 and then YVYN2Z11. Their first
start cursors differ (WRXG4Y11 versus Y9ZG4Y11), but both rediscovered M4BVSY11.
Both next requests started at N4BVSY11 and found YVYN2Z11. Same-boot match-plus-one
advancement is working; accepted progress is lost across restart. The separate
40-check mocked-facade fixture demonstrates this mechanism without any real
seed search. Persistence is proposed in `development348/cursor_review/README.md`
but is not implemented in this release.

## Why completed Eternal cards were taken

At stop, all six Jokers were already Gold: Caino, Yorick, Cartomancer, Negative
Perkeo, Devious Joker and Brainstorm. Cartomancer and Devious were Eternal.
The frozen log shows they were accepted pack choices, rather than shop buys:
Cartomancer at sequence 1093 (06:08:14Z), Devious at 1135 (06:08:24Z). Both were
already marked complete when chosen, and both advice records explicitly said
their Eternal slot was permanent. Cartomancer was Holographic; Devious ordinary.

Both choices used fallback strategic ratings because pack scoring could not
complete every legal comparison. Their reasons favored recurring consumables
and Chips respectively. The ordinary Joker valuation does not integrate Gold
status and applies only a generic Eternal penalty (8 for a recognized Joker,
20 otherwise). It does not compare the future collection cost of permanently
using those slots. The later bounded missing-Joker policy does use Gold status,
but cannot undo an Eternal choice. This is an objective-integration gap, not
unknown or misread sticker metadata. No blanket prohibition or unvalidated new
strategy weight was added in this logging release.

## Validation and preservation

The extended product fixture starts with an identity below the old limit, then
grows past it on a manufactured pack transition. Installed 347 source fails;
the repair acknowledges the prior action, executes the fresh choose action,
exports compact opaque records, preserves exact internal keys, and handles a
large interrupted checkpoint without resetting counters. Focused controller
tests cover optional-hook compatibility, constructor validation, thrown/nil/
metatable/cyclic/oversized/nonfinite output, rejected journals, no raw fallback
and no repeated execution after failure. Focused combined validation passes
8 fixtures. Previous failures remain preserved.

The projection component's initial `before_01` local copy raced with the root
edit and contains candidate bytes; it is explicitly not baseline evidence.
`baseline347_01` uses the immutable 347 policy and fails the intended case.
The root `before348` receipt separately preserves the old product failure.

Full candidate and exact-install evidence is under `runs/auto348_candidate`,
`runs/auto348_installed`, `runs/auto348_installed_validation`, and
`runs/auto348_final`. Checkpoint/navigation records bind the final counts,
policy/test hashes, backup, current settings and unchanged native dependencies.
Passive evidence is under `development348/log_analysis`: sealed latest/prior
prefixes, original near-stop events, compact summary and `supplemental.json`.

Installed 2.148.0-alpha at 2026-09-16T01:25:37.2787512-05:00. Both full candidate
and exact-installed regressions passed 215 Lua fixtures and 361 Python tests,
with unchanged frozen policy/test hashes. All 87 deployment files and 103 frozen
product/dependency files match repository and installation. Policy digest:
`5a4aed30cb968414f7334f7d6f802f889c0e8698fc6c1c01a7124f9caf3663da`.
Backup: `deployment-backups/advisor-20260916-012536` beneath the installation.
Current settings were preserved at their then-current hash; older settings were
not restored. Every existing native DLL is unchanged. Activation awaits normal
user restart, with no live controller or game manipulation by tools.

No captured-policy replay, original-source component, native search or complete
attempt was launched. Mock callbacks launch no native worker or live action.
No saves/profile files, executable archive or game control were used. All old
experimental allowances remain closed. No live recovery, additional sticker,
terminal rescue or improved numerical win probability is claimed.
