# Prospective isolated original cash-out qualification 456

Chosen before source execution. Reuse the six fixed manufactured fixtures in
`../development455/fixtures.json` and the already-tested development455
candidate receipt. The hypothesis is that executing the original
`G.FUNCS.cash_out`, `ease_dollars` and `reset_blinds` on those prescribed
states produces the same **settled** cash, SHOP phase, current-round counters,
cleared flags and preserved `previous_round` fields as the repaired candidate.
Any differing field, missing/extra case, unexpected queue event, callback
error, timeout or artifact cap falsifies this bounded claim.

The original callback is extracted unchanged from the installed archive and
run in Lua 5.1. Its event manager is a bounded FIFO double that enqueues
permitted immediate callbacks and drains them only after the cash-out
function returns. Record the state before draining and after each of the
three expected callbacks: shop-entry reset, dollar mutation, and
previous-round dollar capture. These frames test the harness's source path;
they are **not** claimed as candidate frame parity or a reproduction of all
game event-manager timing. Delays, animation and `ease_chips(0)` are inert
stubs. Deck shuffle is a recorded call with exact `cashout<ante>` key, not
RNG equivalence. Use non-Boss, no-tag fixtures and stop before
`Game:update_shop`, whose UI, tags and stock generation remain outside scope.

Compare the source's settled fields to both the independent source-derived
reference and the actual development455 `CashOut()` adapter receipt. Check
that a second source `cash_out` call after removal of `round_eval` cannot pay
again. Do not use this as proof of shop stock, event timing, Boss/tag paths,
full-game fidelity, policy strength or win rate.

The one-use job may have one worker, one Lua state, exactly six cases, six
initial source cash-out calls and six guarded repeat calls, at most 18 queued
event callbacks, a 20-second worker wall limit and 1,048,576-byte attempt
artifact cap. Python numerical thread settings are one; no GPU or game
process. The lease is consumed before the worker. No retry or renamed lease
is allowed. Prepare exact source/candidate/harness hashes and the final
proposal before the one execution; no historical allowance is renewed.

Read-only original archive SHA-256:
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
Relevant member hashes: `functions/button_callbacks.lua`
`c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101`,
`functions/common_events.lua`
`522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`,
`engine/event.lua`
`98d4e954397b9ddc81c6ec8eadae257960d1cc0ba10e9993f4b241c5dd15159e`,
and excluded shop update `game.lua`
`bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912`.
