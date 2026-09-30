# Lifecycle slice 458 — Booster opening order and prepared source check

**2026-09-30 update:** the user approved execution. The frozen one-use probe
completed with eight source stock agreements and the expected `USED` opening
callback. See [receipt460](../development460/REPORT.md) and
[raw source attempt](source_attempt_001/report.json). The lease is consumed.
The text below records the original preparation delivery on 2026-09-29.

2026-09-29, branch `codex/exact-search-speedups`. Installed451/2.226.0-alpha,
settings, DLLs, public journals, player profiles/saves and the pinned Jackdaw
upstream remain untouched. No Balatro process, original-source Lua worker,
episode, full game, policy test or training job was run.

## Supported repair

Read-only inspection of the exact Balatro archive found that the inner Booster
use path writes `current_round.used_packs[card.ability.booster_pos] = 'USED'`
at `functions/button_callbacks.lua:2242`, before `card:open()` at line 2247.
The slice457 overlay instead marked the slot after the pinned simulator's
opening handler completed. A manufactured callback observer exposed the
stored `p_arcana_normal_1` key in the old path where the source rule requires
`'USED'`.

The [new in-memory overlay](../../advisor_learning/lifecycle_458.py)
validates phase, compact offer index, affordability and physical slot/key,
then marks the slot before the pinned opening handler runs. Invalid actions
leave cash and slot state intact. The previous 457 handler and integration
bytes are preserved exactly under [development457/frozen](../development457/frozen/).
The [manufactured receipt](MANUFACTURED_COMPARISONS.json) records the old
first difference at `events[0].stored_key` and repaired agreement with the
independent [source-rule model](../../advisor_learning/lifecycle_reference_458.py).

## Independent original-source probe prepared

The [acceptance](ACCEPTANCE.md) and [one-use proposal](SOURCE_EXECUTION_PROPOSAL.md)
fix a selected source boundary: exact, unmodified `game.lua:3145-3159`
booster-slot loop and `functions/button_callbacks.lua:2241-2247` inner use
statements. The [preparer](prepare_source_probe.py) read the original archive
as ZIP, verified archive/member/fragment hashes, embedded the exact bytes in
[prepared_source_probe.lua](prepared_source_probe.lua), and froze the eight
case [expected observations](EXPECTED_COMPARISONS.json) plus dependency hashes
in [SOURCE_PROBE_PREPARED.json](SOURCE_PROBE_PREPARED.json). The source worker
has **not** started; `source_attempt_001` does not exist.

The [Lua harness](probe_body.lua) prescribes `get_pack` outcomes and records
draws, persisted physical keys, UI-before-position ordering, materialization,
offers and the key visible to `card:open`. The [strict parser and one-use
runner](run_source_probe.py) require eight ordered STOCK/CASE records and one
complete runner status set; malformed, duplicate, missing and extra records
cannot become an agreement. Four manufactured
[parser tests](test_probe_parser.py) passed, including corrupt records,
wrong physical position and a callback observing the old key. `--check-only`
verified all prepared hashes without invoking Lua.

Focused regression verification passed **68 tests** across lifecycle
453–458, overlay, environment, Lua output capture and probe parser. A focused
read-only review found no blocking source-boundary or parser defect; its one
minor extra-record strictness issue was fixed and rechecked.

## Scope and decision gate

The callback-order repair is manufactured-tested against inspected original
rules. The prepared source probe is **not source-executed evidence**. Its
selected branch will check physical slots and opening-state order only; it
stubs `get_pack`, Card construction, shop UI and `card:open` side effects.
It cannot qualify pack prices, affordability, charging dollars, RNG/pool
distribution, tags, event scheduling, the full `Game:update_shop` or
`G.FUNCS.use_card`, Perkeo shop exit, next blind, full-run fidelity,
optimality or win rate.

The next bounded decision is whether to approve exactly one worker for the
[prepared proposal](SOURCE_EXECUTION_PROPOSAL.md): eight fixed source cases,
one Lua state, at most eight stock-loop and one inner-use invocation, 20-second
worker wall cap, 1 MiB attempt artifacts, no retry. The older 454 and 456
one-use leases remain consumed. This engineering window was not treated as
fresh source-worker authority.
