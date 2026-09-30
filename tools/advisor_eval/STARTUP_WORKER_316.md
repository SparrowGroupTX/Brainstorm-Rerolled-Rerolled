# Search worker loading and visible diagnostics —316

The user's explicit Start auto-run request reached search startup but failed
before a native search began. Its opt-in public log declared loaded2.115 and
recorded `search_start_failed`: LOVE could not open the installed absolute
`Core/collection_search_worker.lua` path. The file exists; the filename overload
uses LOVE's virtual filesystem. This was not evidence of mouse self-cancellation.

Read-only diagnostic source:
`C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2/session-20260914T195043Z-1-000001.brj`,
18525bytes, SHA256
`393662fbb30c5af0012ce64763658e26a456cf9180d176ee991aea768f1c53fe`.
Six records were decoded with the existing bounded archive reader; only startup
event/reason/error/version fields were used. No player save/profile access,
policy evaluation or game control. Helper: `development299/read_startup316.py`.
M23 independently inspected input dispatch order under its new one-use lease;
all12 methods are complete. `runs/gold299_20260914/M23/audit.json` and
`SOURCE_EVIDENCE.md` preserve exact provenance. M23 was spent on this inspection,
not the earlier unregistered alternate-Canio proposal. M18's search stand-in did
not cover the actual production worker factory, explaining the earlier gap.

`Core/collection_search_runtime.lua` now reads the installed script with
`require('nativefs').read`, validates nonempty string bytes at most64KiB, creates
an in-memory FileData and gives that object to `love.thread.newThread`. The size
check follows the native read. Injected test factories, native DLL path,32 ABI
arguments, maximum-CPU setting, one-use wall budget and ownership/cancel/drain
protocol are unchanged. There is no fallback search or silent retry. LOVE's
[thread documentation](https://www.love2d.org/wiki/love.thread) supports FileData;
[newFileData documentation](https://www.love2d.org/wiki/love.filesystem.newFileData)
documents construction from in-memory contents and a name.

`Core/collection_search_product.lua` and `auto_run_product.lua` expose pure
request/busy/phase/owner/text observations. Existing readiness conditions now
name the specific wait, with bounded loading/control field names. Reading
status never starts, polls or cancels work, and no guard is relaxed.

`UI/advisor.lua` and `UI/collection_run.lua` show the loaded version, readable
wrapped search status, full diagnostics and a dedicated manual-search Stop.
Explicit search status is visible in the main-menu HUD even if ordinary advice
is inactive. Failed/stopped HUD notices expire after15seconds; ordinary advice
then resumes. Full status remains available explicitly. A stale Stop click
cannot become Execute. Overlay/paused visibility and user-input cancellation
remain intact; no mouse-movement cancellation was added.

Fixtures: `tests/advisor_collection_worker_loading.lua` exercises the actual
production factory with inert nativefs/FileData/Thread doubles, reproduces the
old absolute-filename failure, verifies exact worker bytes/32arguments and
ownership, and covers nine early failures plus a partially running start.
`advisor_collection_runtime.lua` and `advisor_collection_worker.lua` retain
protocol coverage. `advisor_collection_product.lua`, `advisor_auto_run_product.lua`,
`advisor_startup_ui.lua`, `advisor_collection_status.lua`, `advisor_runtime.lua`
and existing menu geometry fixtures cover status, expiry, Stop and layout.
Detached reviewed packages and earlier failed fixture evidence remain under
`development300/start_status316` and `development299/drafts/startup_ui316`.

Candidate/exact-installed regression and hashes: `runs/startup316_candidate`,
`startup316_installed`, `startup316_installed_validation` and `startup316_final`.
The initial candidate regression is preserved under `validation`:164/165 Lua
fixtures passed; one existing UI fixture expected the old unversioned title.
The fixture now checks the loaded-version title and unchanged normal/challenge
subtitle. Runtime bytes were unchanged; the fresh full result is `validation2`.
The finalizer explicitly selects this report without replacing failed evidence.
This release fixes a diagnosed startup defect; it does not establish a live
successful search, source acquisition, autonomous win or achievement. Normal
user restart and explicit Start are still needed to observe actual activation.
The running game, settings, saves and all existing native DLLs stay undisturbed.
