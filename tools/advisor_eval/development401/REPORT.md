# 401 — Source audit while the user starts a new ten-run session

2026-09-26. The user requested investigation of actual code behavior,
documentation errors and improvement opportunities. This delivery changes
documentation only. Repository and installed **2.194.0-alpha** remain bound to
`SESSION_RESET_400.json`, digest
`97711915fc9705a40f7d0c4f2ac04ed5a6de2210c1efdc34f1eadf9226b61980`.
The new session has not been audited; its outcome, completeness and actual
loaded label are unknown. The user will report when it ends.

## What the system actually does

The product has separate responsibilities, which matter when diagnosing failure:

1. `Core/auto_run_product.lua` connects explicit user start/stop/resume to the
   controller, public journal, native opening search and existing Execute gate.
   Win-first is a fixed ten-start Red Deck/Gold Stake preset, distinct from
   collection-sticker optimization. No active session is restored on relaunch.
2. `Advisor/runtime.lua` captures a detached state, fingerprints it, runs
   `decision.lua` in a coroutine, and publishes only a completed result for the
   current state. A roughly four-millisecond outer resume loop is cooperative,
   not a hard bound on each individual coroutine resume (lines 705–726).
3. `decision.lua` routes shop/pack, ordinary hand, concealed playing-card and
   public concealed-Joker cases. The 140,000 ordinary and 50,000 shop allowances
   are shared by their specialists; their local ceilings are not additive.
   Complete-world and survival admission remain separate from strategic merit.
4. Execution rechecks freshness/legality. `Core/auto_run_settlement.lua:check`
   waits for exact shop debit, departure from stock and entry into inventory;
   a callback alone is not purchase completion. Terminal accounting is a
   different path: `Core/auto_terminal.lua:poll` requires bound original win
   callbacks/accounting or GAME_OVER, never GAME.won alone.
5. `player_journal.lua` projects public observations and compact advice;
   `player_log_archive.lua` writes hashed BRJ2 segments. The module name
   "archive" describes storage/rotation, not backup before the explicit clear.

## Confirmed documentation errors corrected

| Earlier statement | Source-supported correction |
| --- | --- |
| ADVISOR.md: "There is no autoplay." | Explicit product-started collection and ten-run win-first modes exist: `UI/collection_run.lua:128–133,188–190`; `Core/auto_run_product.lua:432–518`. Execute itself remains one action per click. |
| Consumables add 25,000 scores; ordering produces a 195,000 total plus extras. | `decision.lua:410–418,506–550` reserves/charges work inside the 140,000 total. Fast-clear stays 70. Local ceilings are not extra global allowances. |
| Amber Acorn advice is withheld. | `decision.lua:83–171,608–612` has a separate public-belief path, including the incorporated bounded last-hand discard. Unsupported evidence can still withhold action. |
| Death reorders only if no useful legal copy exists. | The current best-directed-pair search can reorder even when a weaker positive legal pair exists. Contextual properties/ranks/suits and safe fishing are documented. |
| A blanket updated-mod folder copy is the release procedure. | Current workspace release uses explicit files, backup, exact freezes/gates, confirmed normal exit, preserved config/DLLs and later normal activation. |
| Recent receipt description implies comprehensive acquisition/Death diagnostics. | Actual projection records successful/selected paths and limited scalars; rejected-family and several Death paths are missing. `development400/REPORT.md` and `ARCHITECTURE_MAP_400.md` now state this limit. |

README's 2.16 feature paragraph is now explicitly historical and links to the
current product controls/checkpoint. ADVISOR.md also documents the real ten-run
limits and destructive old-auto-log clearing, with separate manual retention.
Pre-edit guide/README bytes are preserved in `docs_before/`; other prior
statements remain historical evidence. This was a bounded audit, not a claim
that every older paragraph or historical map has been verified.

## Confirmed gaps to fix in a later runtime/tooling slice

### A401-1 — Lost focused-copy rejection detail (P2)

At `decision.lua:237–240`, focused replacement evidence lives inside
`copy_acquisition_diagnostics.replacements`. `player_journal.lua:558–568`
projects only scalar fields, so that nested evidence is dropped. After ordinary
fallback, `compact_replacement_review` (line 451 onward) reads the ordinary
context instead. Thus a failed focused copy attempt's offer/victim/rejection
cannot be reliably attributed to its stage from the compact public receipt.
Its `complete` flag also means no truncation plus any replacement-family
completion, not necessarily a supported direct-purchase comparison.

Proposed change: separate stage, attempted/completed/supported/admitted status,
reason code, offer/victim physical IDs and charged work. Keep payloads bounded
and exclude scored worlds. A manufactured focused rejection followed by a
different ordinary result should retain both distinct receipts after public
serialization. This is an observability defect, not proof of another missed
copy in the ongoing session.

### A401-2 — Death rejection and tactical/pack receipt gaps (P2)

`player_journal.lua:569–570` reads only `consumable.development` and a selected
growth `death_source`. `growth.lua:582–609` can decline the option for missing
public population or retained last inventory source without structured Death
status; line 792 retains source metadata only for positive selected utility.
The tactical return at `consumables.lua:1157–1158` has action/targets/play but
no development source receipt. Pack targeting is similarly outside this
structured path. Original observations and actions still identify selected
cards; absence of a fishing receipt is not evidence that fishing was considered
and rejected on value.

Proposed change: one bounded Death disposition schema shared by pack, tactical,
optional development and fishing paths. Distinguish not-applicable, no public
population, inventory hold, insufficient work, no positive gain and selected.
Preserve exact physical source/recipient IDs for actual selected actions.
Manufactured serialization cases should cover each disposition, including
reorder followed by reobservation, without exposing draw worlds.

### A401-3 — Two timing suites lie outside the standard Python gate (P2)

`validate_checkpoint.py:21–26,42–44` hashes/discovers only Python filenames
matching `test_advisor_*.py`. Consequently `test_teacher_decision_timing.py`
(nine test methods) and `test_wall_time_decomposition.py` (two) are neither
hashed in `test_files` nor run by that gate. `prework.json` records the exact
excluded files and AST-derived counts without executing them. The reported
392 tests really did pass; the gate does not mean all repository Python tests.
This does not invalidate the exact installed-runtime digest.

Proposed change: declare gate groups explicitly, include these manufactured
timing tests, and fail discovery when a new test file has no declared group.
Keep source-game/experiment entry points excluded by explicit classification,
not by an accidental naming convention. Validate discovery itself with small
manufactured file trees; preserve historical gate receipts and counts.

### A401-4 — Test harness/environment provenance is incomplete (P2)

The gate freezes Lua fixtures and selected Python test modules, but not
`tests/run_lua_tests.py`, imported Python analysis helpers, or the selected
external Lua runtime. `tests/run_lua_tests.py:93–112` resolves LuaJIT/Lua from
PATH before falling back to Balatro's Lua DLL. The log names that runtime;
the report does not bind its bytes/version. `benchmark.py:47–69` correctly
scopes product dependencies; that product hash is not a test-environment hash.

Proposed change: a separate validation-provenance record for runner, helper
dependencies, interpreter/runtime identity, commands, suite manifest and test
files. This makes evidence reuse depend on the actual harness environment as
well as product bytes. Do not replace the existing product digest or pretend
prior reports already had this stronger provenance.

## Redesign proposals requiring measurement or manufactured comparison

### A401-5 — Reserve a complete fallback family after failed copy work

The focused copy family gets the entire remaining allowance at
`decision.lua:230`. Failure correctly debits work at lines 236/244; later
ordinary/retention allocation happens at 275–282. There is **no confirmed cap
overrun**. But expensive unsuccessful copy endpoints can leave zero work for a
different visible rescue purchase. A preflight cost estimate and small complete
fallback reserve could improve this tradeoff. Compare several expensive copy
endpoints plus one cheap supported rescue, enforce total work <=50,000, preserve
complete-family selection, and record why the chosen action won. This is a
proposal, not a reproduced current-run loss or justification to force a copy.

### A401-6 — Make journal preservation and I/O cost explicit

The ten-run start calls `prepare_collection({clear_existing=true})` at
`Core/auto_run_product.lua:486`; `player_log_archive.lua:140–178` validates then
deletes owned auto journals. No verified export precedes it. This behavior is
explicitly labeled in the UI, so it is not an unauthorized-deletion finding.
It remains a data-loss risk for unaudited cohorts, already identified in older
priorities. A future user-facing archive-before-clear flow should copy closed
segments, verify hashes and manifest, and retain the source on partial failure.
Storage accounting, manual separation and the user's clear semantics must stay
explicit; moving files must not silently renew the existing storage budgets.

Separately, every append catalogs all owned log files at
`player_log_archive.lua:196` through `catalog` (79–99), and compression does an
immediate roundtrip (49–52) before append/readback (208–211). This is confirmed
work, **not a measured bottleneck**. First measure manufactured filesystem
operation counts and available passive timing categories; then consider a
verified incremental catalog under clear writer ownership. Preserve external
mutation detection, total-byte/file caps, hashes and append readback. Do not
remove integrity checks based on an unmeasured speed assumption.

## Recommended order and boundaries

After the user reports the current session complete, preserve its public
journals before any next clear and audit every start and relevant copy/Death
action. Prioritize A401-1/2 if missing receipts obstruct that audit. A401-3/4
can form a separate tooling-only provenance slice. A401-5 needs a manufactured
decision comparison before changing allocation. A401-6 is independently useful
for preserving future evidence; performance changes require measurement.

One existing read-only reviewer checked the decision/telemetry contracts and
shop allowance; the primary checked those findings plus product lifecycle,
journal storage, test discovery and docs. No additional reviewer, recursive
delegation, runtime edits, tests, benchmark, native build, installation, game
control, captured-state execution, save/profile access, current-session outcome
audit or automation occurred. The latest previous full gates remain the exact
2.194 gates; no unnecessary repeat was run for documentation edits. All older
experiment budgets remain closed. `verification.json` binds final unchanged
runtime/tests and edited documentation hashes.
