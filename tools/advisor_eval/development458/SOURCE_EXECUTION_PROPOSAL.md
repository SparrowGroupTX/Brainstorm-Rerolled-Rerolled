# Prepared one-use original booster-slot branch comparison

Status: **prepared only; source worker not authorized or started**. The user's
one-hour engineering window permits this preparation and manufactured tests.
The prior 454/456 source leases are consumed. A fresh explicit approval of
this exact one-use job is required before `run_source_probe.py` may start its
Lua worker. Approval would be recorded in a consumed-before-worker lease.

## Hypothesis and boundary

On the exact eight `development457/fixtures.json` manufactured no-tag cases,
the original verbatim `game.lua:3145-3159` booster loop should match the
source-rule model and repaired Python overlay on prescribed `get_pack` calls,
persisted physical `used_packs[1..2]`, live offer keys/order and
`ability.booster_pos`. On the `used_first_stored_second` case, the verbatim
inner Booster-use statements from `functions/button_callbacks.lua:2241-2247`
should write `'USED'` before `card:open()` observes that slot. An unexpected
draw, callback, card, missing/duplicate case, parse error, timeout, dependency
drift or mismatch is a failure. There is no retry under this proposal.

This executes selected original statements inside a minimal Lua 5.1 stub
environment, not `Game:update_shop`, the whole `G.FUNCS.use_card`, or Balatro.
`get_pack`, card construction, UI and rendering are prescribed/stubbed. Thus
the job cannot qualify pack distribution/RNG, card prices, cash charging,
affordability, shop event timing, tags, full pack opening, Perkeo copying,
next blind, full game, policy strength or win rate.

## Exact inputs and provenance

- Eight fixed states from `development457/fixtures.json`, no player profile,
  saves, hidden run capture, seed search or policy. `first_shop_buffoon=true`;
  no tags, voucher, Joker slots or modified pricing. Prescribed pack outcomes
  come from each fixture's `draws` list, with extra calls rejected.
- Balatro archive read as ZIP only, SHA-256
  `0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
  `game.lua` SHA-256
  `bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912`,
  stock fragment SHA-256
  `0c8c06229c81c70beeb9b0ed1e478af8313be3fe85f07cab878294af05d507e1`.
  `functions/button_callbacks.lua` SHA-256
  `c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101`,
  use fragment SHA-256
  `7a8d594dc42d40754adc797bd60c076f840c1f882a55f52e8a47d2ea2d3c70fa`.
- Balatro `lua51.dll` SHA-256
  `d0039528d0c48acf9e4b93e39f929ecd8def2b08c429971b809d8751aae49fb2`.
  Prepared manifest pins runner, harness, parser, exact source fragments,
  candidate integration and expected manufactured comparisons. Drift stops
  before any lease or worker.

## One-use limits and accounting

- One worker, one Lua state, eight stock-loop invocations, at most sixteen
  prescribed `get_pack` calls and sixteen stub card constructions. One
  selected Booster-use body invocation, at most one `card:open` stub call.
- Worker wall time 20 seconds, coordinator target 30 seconds, one Python/Lua
  worker, numerical thread environment variables one, GPU disabled. No hard
  OS CPU-affinity quota is claimed.
- Maximum 1,048,576 bytes for the attempt directory, including lease, raw
  stdout/stderr and report. Captured output above the reserved raw-output
  allowance is truncated and classified as an artifact-cap failure.
- Only `development458/source_attempt_001` may run. Its directory is created
  with `exist_ok=False`; the lease is written before worker launch. No retry,
  fallback episode, second worker or renamed lease is permitted. Raw failure,
  partial output, timeout, mismatch and parse error remain preserved.

The source test will compare independently parsed records against both the
handwritten source-rule model and a frozen repaired-candidate observation.
Manufactured parser tests and `--check-only` do not execute original source.
