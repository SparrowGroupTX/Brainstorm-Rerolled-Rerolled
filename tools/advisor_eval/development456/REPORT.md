# Isolated original cash-out comparison 456

2026-09-29. Branch `codex/exact-search-speedups`. The user's “Go for it”
authorized one new bounded source comparison of the six development455
cash-out fixtures. The one-use [proposal](SOURCE_EXECUTION_PROPOSAL.md),
[prepared manifest](SOURCE_PROBE_PREPARED.json) and
[consumed lease](source_attempt_001/LEASE.json) fix the scope and exact bytes.
Installed451/2.226.0-alpha, settings, DLLs, public journals and all older
source receipts remain untouched. No Balatro process, save/profile read,
episode, full game, policy run or training was used.

## Result and parser failure

The single Lua worker executed the original `G.FUNCS.cash_out`, original
queued `ease_dollars`, and original `reset_blinds` on all six fixtures. It
exited 0 and reported `1/1 fixtures passed`. Its [raw stdout](source_attempt_001/stdout.log)
contains 18 queued-state frames and six `CASE` prefixes, one with its line
split by the runner status output. The original
[runner receipt](source_attempt_001/report.json) remains **`parse_error`**:
the runner's `PASS ...` and `1/1 fixtures passed` status lines landed inside
the held-out record's `discards_used=1` field. It did not record a clean
six-case pass.

The separate [offline recovery](offline_recovery/OFFLINE_RECOVERY.json) verifies
the immutable raw log and original receipt hashes, finds that exact status
marker once at the documented split, removes only those status lines, and
rejoins `discards_u` with `sed=1`. It invokes the frozen comparison parser on
the recovered text without starting Lua. All **six** recovered source cases
agree with both the independent source-derived model and the repaired
candidate on settled cash, SHOP phase, reset hands/discards/purchase count,
cleared shop flags, preserved `previous_round` fields and unchanged other
round fields. The source-specific queued frames also match the declared
three-callback sequence. The negative-payment case settled from $2 to -$1;
the held-out zero-payment case retained its non-dollar previous-round field.

This is **offline-recovered isolated source agreement**, with the primary
runner failure preserved. There was one source worker, no retry, and no
additional source execution for recovery. The worker took 0.094 seconds;
raw attempt artifacts total 6,136 bytes, below the 1,048,576-byte cap.

## Supported boundary

The source code was read from the exact original archive as ZIP, then selected
functions were executed in Lua 5.1. The event-manager double enqueued three
permitted immediate callbacks per case and drained them to settlement. It
rejected unexpected queue/front insertion, extra callbacks and non-immediate
triggers. The source state remained at initial cash and ROUND_EVAL before
draining, then recorded shop entry, payment and previous-round capture. A
guarded second call after `round_eval` removal added no payment. These are
source-harness observations; candidate callback-frame timing was not compared.

The fixture prescribes `current_round.dollars` and has no Boss defeat or tags.
Delay, sound, HUD, `ease_chips(0)` and deck randomness were stubbed or recorded
outside the compared state. `Game:update_shop` was not called. Therefore this
does **not** qualify real shop stock, tag effects, shuffle/RNG equivalence,
actual event-manager timing, full round/shop sequence, Red Deck/Gold Stake
opening distribution, Perkeo shop exit, win rate or policy optimality.

## Qualification matrix and next gate

| Boundary | Status after 456 | Limit |
|---|---|---|
| Plain Golden final-life cash-out evaluation (454) | Seven isolated source cases agreed | No payment action in 454 |
| Prescribed cash-out payment and shop-entry bookkeeping (455/456) | Six isolated original-source cases agreed through offline recovery | Primary runner parse error retained; settled fields only |
| Source queued callback frames | Source-only harness checked | No candidate frame timing or full event-manager parity |
| Shop stock/tags, Boss reset, shuffle/RNG, Perkeo exit, next blind | Unsupported | Requires new separate qualification |
| Full game, training readiness, loaded-game performance | Unsupported | No episode or win-rate evidence |

The conservative near-expiry learning-episode guard remains active. The 456
lease is consumed. The next coherent engineering slice is actual shop stock
and tag generation with prescribed outcomes and exact legal offers, followed
by Perkeo shop exit. Any further original-source worker needs a new concrete
one-use registration and fresh user authorization.
