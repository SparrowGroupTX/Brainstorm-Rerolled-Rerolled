# Cooperative observation hooks — 333

The journal and public Joker observer each checked only whether its own callback
wrapper was outermost. Their per-frame installation alternated wrappers around
the same game callbacks. This retained a longer callback chain on every update,
even with recording disabled. A later action traversed all of those wrappers,
repeating public observation and full journal capture for one source callback.

A manufactured reproduction of the old modules used 30 alternating installation
updates. One source action produced 30 snapshot captures, 60 journal entries and
31 observer begin-action notifications. The different initial counts come from
the fixture's installation order, not multiple game actions. The frozen baseline
modules and the corrected reproduction remain under
`development333/logger_component`; its first fixture count assertion error is
preserved separately. The joint observer fixture covers both installation orders
and repeated updates with the repaired modules.

`callback_hooks.lua` now records the parent of each product-owned wrapper in a
shared registry with weak keys and values. The journal and public observer recognize their hook
anywhere in that recorded ancestry and leave the existing chain intact. Genuine
callback or callback-table replacement is still wrapped. The registry does not
inspect private upvalues or assume knowledge of arbitrary third-party wrappers.
Its bounded traversal is not a guarantee for an unqualified external chain.
`runtime.lua` creates the registry before the journal attaches and supplies the
same instance to the observer.

The repair preserves the original callback's arguments, nil-bearing return
tuples, explicit rejections and exceptions. It retains one requested-action
observation, its linked result and the later settled-state observation. Public
Joker inference, action legality, score caps, archive encoding, compression,
append readback verification and retention limits retain their existing scope.
This slice does not discard logged information or change the archive format.

## What the player's compact timing capture establishes

The copied segment contains 78 complete compact performance windows, occupying
120,593 stored bytes and 435,636 decoded bytes. Its SHA-256 is
`a19bc8bb2775f0fc904e0cf3c42dcc9d52f1ed92c8720da92731e8eaca0de686`.
There are no action or loaded-version records in this capture. It cannot establish
the running version, duplicate action counts or a complete session tail.

The last window, ending at monotonic 1404.4820358 seconds, contains six frames.
Their mean interval is 0.8915426 seconds; the measured original game-update mean
is 0.89478145 seconds. Its one measured journal event took 0.0063389 seconds.
The window reports paused=true, advisor_worker=false and auto_active=false.
The timings substantiate severe frame stalls. They do not attribute those stalls
solely to synchronous logging, which is much smaller in this window. Nested
timings overlap and must not be summed as independent CPU costs.

The retained wrapper chain is a confirmed code defect and a plausible source of
allocation and garbage-collection pressure. Live garbage-collector time, live memory growth
and the fraction of the observed game-update stall caused by this defect have
not been measured. The existing compact capture remains useful without expanding
full historical logs into model context. Root's `captured_log/timing.json` and
`stall_index.json` preserve the bounded read-only analysis.

## Source, tests and installation evidence

| Responsibility | Source / evidence |
| --- | --- |
| Shared owned-wrapper ancestry | `Brainstorm/Advisor/callback_hooks.lua`; observer component manufactured registry and joint installation fixture |
| Journal installation and action linkage | `Brainstorm/Advisor/player_journal.lua`; logger component 17 new checks, 130 existing Lua checks and 17 existing archive Python tests |
| Passive public-effect hooks | `Brainstorm/Advisor/acorn_public_hooks.lua`; observer component joint fixture and existing public-observation checks |
| Registry lifetime and wiring | `Brainstorm/Advisor/runtime.lua`; root candidate and exact-installed regression |
| Actual compact timing evidence | `development333/captured_log/timing.json`, `stall_index.json` and preserved segment |

The detached logger manifest is
`development333/logger_component/manifest.json`, SHA-256
`b4dc7c888a279d6ff5acd4de8133b3bebf91b04c5b9ce5a0929f3e4c6aab4b36`.
Root's final candidate, installed-policy and final-verification records own the
release-wide test counts, installed hashes, version and backup. Component checks
do not substitute for that exact-installed validation. No restored frame rate or
live activation result has yet been demonstrated.

Copying new files cannot remove wrappers retained by the already-running Lua
process. Activation requires the user's normal restart, which tools must not
perform. Turning recording off may reduce duplicate snapshot/write work in the
old process, but it does not repair the old installers' chain growth. Existing
logs, current settings, saves, retry journal protections and every native DLL are
preserved. No archive cleanup or unrelated archive optimization is part of this
slice.

This work uses read-only analysis and routine manufactured/regression tests. No
source component, source attempt, seed search or new experiment lease was run.
The loss328 validation batch and all earlier allowances remain closed. Its six
source outcomes remain three losses, one error, one timeout and one unsupported
result, with zero wins; 1,200 seconds reserved and 685.3740000000689 actual worker
seconds. Four public comparison jobs were spent and the remaining two closed.
These historical results are not results of release 333 and their unused
capacity is not renewed. There is no claim of a rescued run, achievement
completion, numerical win odds or superiority over a human player.

Production joint regression is `tests/advisor_callback_hooks.lua` (60 checks,
including forced garbage collection on every idle tick). Journal linkage and
replacement regression is `tests/advisor_logger_hooks.lua` (17 checks).
The joint1000-tick workload keeps zero additional wrappers instead of16000.
Runtime creates one shared registry before journal attachment and injects it
into observer attachment. All other strategic modules remain byte-identical.

Release evidence: `runs/hooks333_candidate/validation/report.json`,
`runs/hooks333_installed/record.json` and `policy/`,
`runs/hooks333_installed_validation/report.json`,
`runs/hooks333_final/final_verification.json`.
