# Recording status UI — release 326 component

Owned changes are `Brainstorm/UI/advisor.lua` and the new manufactured fixture `tests/advisor_logging_status.lua`. Original UI and the unchanged optional Core product file were backed up before editing under `before/`.

Advisor settings now has a compact readable recording summary and a persistent Recording status control. The control opens the existing overlay without refreshing advice. It shows the underlying error, both v1/v2 log folders, their shared limit, and the current numerical limit read from the loaded archive module. It does not retry, reset, delete, or move recordings.

Recording errors are sanitized and limited to 4096 bytes for display, with explicit truncation. Wrapping preserves UTF-8 boundaries and splits long paths into bounded rows. Pages use the number of actually displayed lines, fixing the old diagnostics pagination that used unrelated advice lines. Full status also includes a persistent recording error even when no search request exists, without refreshing advice or exposing stale card-selection/retry controls. Ordinary advisor and Stop/Resume behavior are retained.

Current owned bytes passed five Lua fixtures: logging status 791 checks, startup UI 33, input UI 98, advisor UI 113, runtime 607; 1642 checks total. Separate earlier runs also passed frame timing 85, gold layout 381 (zero synthetic geometry bound violations), collection search UI 63, challenge opening UI 72. These remain manufactured validation, not live UI or gameplay outcomes.

Three initial fixture-only failures are preserved separately: the reused text helper concatenated toggle booleans, the test expected the wrong settings row count, and an assertion ignored intentional line wrapping. Their exact test files and explanations remain in `failed_fixture1/`, `failed_fixture2/`, and `failed_fixture3/`. No failed source or complete-attempt experiment occurred.

No external player files, saves, source experiments, native jobs, searches, or live game control were used by this component. Root independently owns metadata diagnosis, idle-timing suppression, the user's new 1 GiB storage authorization, final validation, installation and release records.
