# Idle and drag work — release 323

The user reported high CPU during auto-run and suspected recalculation without an action, especially while dragging a Joker across intermediate positions. Read-only runtime inspection found three avoidable paths. No live CPU measurement, player-log read, gameplay, executable/source worker, search, captured replay or complete-attempt experiment was used for this slice.

## Runtime drag coalescing

Previously `Advisor/runtime.lua` captured and fingerprinted a complete snapshot on every drag frame. Hand/shop workers were created but not resumed until dragging ended; blind/pack/round decisions could run synchronously from refresh. Thus it would be inaccurate to say every crossing always completed a hand search, but provisional positions did cause unnecessary state construction and some planning.

Refresh and update now defer that work while the controller reports a dragged card. Existing active/gameplay readiness checks still run first. A `drag_pending` gate blocks Select and Execute through release until a fresh full snapshot/key/retry-context check succeeds. The first released update bypasses the normal 0.3-second idle interval. An unchanged final arrangement reuses the detached worker/result; a changed arrangement invalidates it before any worker resumes. Cash, game-instance, settings-generation, hard-lock and failed/unsupported-capture safeguards remain intact. No old observation is used to authorize execution.

`tests/advisor_runtime.lua` uses the actual runtime/capture with manufactured decisions: 120 drag frames plus explicit refresh calls cause zero captures, fingerprints or new decisions in hand/shop/blind phases. Returning to the same arrangement avoids a repeat decision; a changed final arrangement creates one. Paused workers resume once or are abandoned before publication when actual inputs change. Failed/unsupported release captures stay blocked, and settings/gameplay locks still invalidate old work. These are deterministic call counts, not a game CPU benchmark.

## HUD-only snapshot identity

`Advisor/snapshot.lua` omits only `current_round.current_hand` from the copied round. The preserved original `functions/common_events.lua` `update_hand_text` function writes its chips, mult, handname, chip_total and hand_level display fields. No Brainstorm production policy reads that aggregate. Actual hand levels, accumulated blind chips, remaining resources, card order/identity, owned inventory, all other current-round fields and Gold progress remain captured independently.

The captured aggregate previously made HUD preview/animation changes alter the full decision key. The new manufactured capture fixture verifies unchanged keys for all five display fields while gameplay mutations still change them; runtime integration verifies an existing yielded worker and completed result survive preview churn. This deliberately changes deterministic input/sample keys to exclude presentation metadata. Previous recorded snapshots and policies remain untouched; no captured state was rescored. Exact preserved source hashes and detached validation are in `development323/snapshot_idle/manifest.json` and its note. The initial capture-only audit is preserved separately under `development323/capture_key_audit/`.

## Blocked auto-run observations

`Core/auto_run_product.lua` checks its existing game/worker/execution/search readiness before constructing the full action snapshot, fingerprint and copied advice. Blocked animation, drag, pending action and worker frames omit those data. There is no cross-frame snapshot cache. Fresh Gold metadata, profile identity, generations, terminal observations, cancellation/draining and watchdog clocks remain active; exact pre-execution recaptures are retained.

Ready unsupported endpoints still receive a full snapshot so an accepted preceding action can be acknowledged even if the next recommendation has no action. Root review caught that distinction in the first detached proposal; `development323/auto_observation/prior_v1/` preserves it. Revision 2 adds a regression that acknowledges the settled action once and then follows the existing unsupported timeout instead of incorrectly timing out the earlier action. No rejected proposal was installed.

Auto-off already returned before observation. The public journal also already avoids captures/encoding/compression/writes on idle frames with no pending action; its per-frame hook reference checks remain. Two untested journal optimizations were excluded as low-value for this issue and are preserved under `development323/journal/` as inactive proposals, not pending work or authority.

## Validation and limits

Runtime drag/HUD integration: `tests/advisor_runtime.lua` (573 checks). Snapshot identity: `tests/advisor_snapshot_idle.lua` (52 new checks), with existing snapshot/Gold/Perkeo suites. Auto observation: `tests/advisor_auto_observation.lua` (317 new checks), with 202 existing auto-product and 312 controller checks. Full candidate and exact-installed validation, independent review, hashes, versions and preservation are bound by `runs/idle323_*` and the generated checkpoint records. `development323/root_fixture_history.json` preserves one corrected test-double/title expectation; the auto package separately preserves its preparation and review history.

These changes remove demonstrated redundant work; actual CPU percentage, live frequency and whole-run time savings are unmeasured. Necessary decision calculations and fresh state checks while a worker is active remain. All 150 Gold records still rebuild on active auto ticks. Existing 140000 ordinary/50000 shop/25000 consumable and 70-score fast-clear ceilings remain. No scoring weights, strategic routes, retry counts, native CPU preferences or animation speeds change.

All historical source/search/captured/complete-attempt budgets remain CLOSED. Release323 creates no new experiment authority and inherits no win. Keep prior pace322 behavior and broader Completionist++/Jokerless/Knife's Edge work; no player win rate, complete Jokerless win or stronger-than-human performance is established. New installation activation waits for the user's normal restart, with the running game undisturbed and all settings/native DLLs preserved.

## Installed evidence

Installed **2.123.0-alpha**, 2026-09-15T01:24:54.4390187-05:00, using exactly `Advisor/runtime.lua`, `Advisor/snapshot.lua`, `Core/auto_run_product.lua` and both version files. Backup: `C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260915-012453`. All 77 deployment and 93 frozen product/dependency files match the repository and installation. Policy digest: `a8b4febde8df4d2af5adbfc1c2e43add71d8a89f9db349a315c7c4051881f30b`.

Both complete candidate and exact-installed regressions passed **173 Lua fixtures / 318 Python tests**, with unchanged frozen policy/test hashes under the existing 60-second-per-suite bound. Candidate suite times were 26.985/14.906 seconds; installed suite times were 28.875/13.797 seconds. These are regression timings, not a CPU or whole-game benchmark. No failed final regression or installation remains pending. Evidence: `runs/idle323_candidate/validation/report.json`, `runs/idle323_installed/record.json` and `policy/`, `runs/idle323_installed_validation/report.json`, and `runs/idle323_final/final_verification.json`.

Current settings were preserved at `fee73ac0064a63d31a4ddafda56f732ca5843bd41e4c60fbe324ad417d45514e`; the different earlier322 settings hash was not restored. Every existing native DLL is unchanged, including active `Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll`. Independent review `development323/reviews/review_cpu323.json` accepted all three final components and reran 1,992 manufactured checks; SHA256 `165ac16e5a40dbcaf787201a191bc12a215833ce551424e0c716ab4bed3eee21`.
