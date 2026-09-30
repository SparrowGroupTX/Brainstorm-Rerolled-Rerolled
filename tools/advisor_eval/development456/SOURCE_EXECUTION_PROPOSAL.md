# One-use original cash-out source comparison 456

The user said “Go for it” after the plan to prepare and run a fresh bounded
original-source comparison of slice 455. This registration fixes that job
before execution. The 454 lease and all older source/episode budgets remain
closed. This is isolated Lua source execution, not a Balatro launch, full
game, policy evaluation or training run.

## Hypothesis and stop rule

For the six exact `development455/fixtures.json` cases, executing the
original `G.FUNCS.cash_out`, original queued `ease_dollars` and original
`reset_blinds` should agree with the repaired candidate and independent
handwritten model on settled cash, SHOP phase, reset hand/discard/purchase
counters, cleared shop flags, preserved `previous_round` fields and unchanged
other round fields. The source must queue exactly three permitted immediate
callbacks. Before draining, cash and phase must remain at their initial
values; the recorded callbacks must produce shop entry, payment, then
previous-round capture. A second `cash_out` call after `round_eval` removal
must add no payment. Any disagreement, unexpected event, missing/extra case,
timeout, source error or artifact overflow stops the job without a pass claim.

## Inputs and provenance

- Exactly six manufactured states; no seed search, hidden deck order, player
  save/profile or captured policy. Prescribed `earnings_total` is mapped to
  original `current_round.dollars`; no round evaluation is rerun. Cases have
  no Boss defeat or tags.
- Source archive is read as ZIP only: `Balatro.exe` SHA-256
  `0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
  Relevant exact members: `functions/button_callbacks.lua`
  `c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101`,
  `functions/common_events.lua`
  `522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`,
  `engine/event.lua`
  `98d4e954397b9ddc81c6ec8eadae257960d1cc0ba10e9993f4b241c5dd15159e`,
  and excluded `game.lua` shop path
  `bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912`.
- Lua runtime is the installed `lua51.dll`, SHA-256
  `d0039528d0c48acf9e4b93e39f929ecd8def2b08c429971b809d8751aae49fb2`.
  The development455 candidate, six-case manufactured receipt, original
  source functions, harness and runner hashes are fixed in
  `SOURCE_PROBE_PREPARED.json`. Dependency drift stops before the worker.

## Isolation, limits and accounting

- One worker, one Lua state, six deterministic cases. At most six initial
  source cash-out calls, six guarded repeat calls and 18 queued callbacks.
- Worker wall time 20 seconds; coordinator target 30 seconds. One Python/Lua
  worker, numerical thread environment variables set to one, no GPU. There
  is no hard OS CPU-affinity quota.
- Attempt-artifact cap 1,048,576 bytes, including raw stdout/stderr, lease
  and report. Excess output is truncated and classified as a cap failure.
- Only `development456/source_attempt_001` may run. The runner creates its
  directory with `exist_ok=False` and writes a consumed lease before the
  worker starts. No retry, renamed lease, fallback episode or extra worker.
  It preserves success, mismatch, partial output, timeout and error states.

The event-manager double enqueues permitted immediate callbacks and drains
FIFO; it rejects other triggers/queue insertion and bounds execution. This
is a **settled-order abstraction**. `delay`, rendering, sound and
`ease_chips(0)` are inert; shuffle is a recorded call with exact key, not
an RNG result. Original `Game:update_shop` is not called, so this result
cannot qualify real stock, tags, animation timing, Boss/reset-blind changes,
full sequence, loaded game behavior or a win rate. Installed advisor451,
settings, DLLs and public journals are left unchanged.
