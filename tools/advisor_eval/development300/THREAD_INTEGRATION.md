# Runtime integration contract

Implemented bridge draft: `collection_search_runtime.lua`. Call
`attach(B, {native=function() return ensureImmolateLoaded() end,
now=love.timer.getTime})`; it also sets `B.CollectionSearchRuntime`. The returned
API provides dot-called `start(request, seed, profileToken)`, `poll(profileToken)`
(also `update`), `stop(reason)`, `busy()`, `status`, and `last`. `poll` returns a
terminal record once, after actual thread exit. It starts no game and never
retries. A profile token is a nonempty string or positive integer supplied and
refreshed by the caller; no profile access occurs inside this module.

Optional dependency injections: `new_thread(path)`, `channel(name)`, `parse(raw)`,
`on_event(kind, data)`, and `on_result(record)`. Default `decode` is a separate
strict flat JSON parser accepting finite fractional/exponent numbers; the
existing challenge decoder accepts integers only and must not be used for v9.
`validate_result` checks schema, bounded counters, matching requested budget,
threads, route, status and nonempty valid match seeds. NUL-containing native
strings are rejected before FFI rather than silently truncating criteria.

The bridge invalidates queued estimate generations before loading its worker.
Core must still guard both `requestSearchEstimate` and the deferred estimator
event callback, plus normal/challenge search entry points and Ctrl+A, whenever
`B.native_search_busy` is true. Do not clear that latch externally. A worker
whose liveness is unavailable retains exclusion until exit can be verified.

The bridge fixture has 96 synthetic checks covering decimal/exponent parsing,
duplicate keys, invalid JSON/fields/seeds/counters, malformed requests, one-use
delivery, queued-estimate invalidation, completion before thread exit, repeated
cancel/start race, timeout, reversed/unavailable clocks, stale profiles and
generations, late matches, worker/protocol errors, partial starts, unknown
liveness, foreign ownership and unchanged settings. Receipt:
`../development294/collection300bridge2/report.json`. Worker-only fixture has
149 checks; request construction has 29. Product staging still requires root's
full exact-byte validation and native evidence binding.

Draft worker `collection_search_worker.lua` is intended for a new Core file;
`collection_search.lua` is intended for Advisor pure request preparation. Root
owns staging and the surrounding auto-run controller. Do not call the worker
from tools against a running game. Synthetic LOVE/FFI doubles are sufficient to
test message formatting, cleanup and cancellation behavior.

Create unique reply/cancel channel names per generation, clear only those new
channels, then create the worker from the module path and call:

```
thread:start(nativePath, replyName, cancelName, generation,
  seed, q.voucher, q.pack, q.tag, q.souls, q.observatory,
  q.observatory_deadline, q.perkeo, q.copymoney, q.retcon, q.bean, q.burglar,
  q.custom_filter, q.target_rank, q.target_suit, q.specific_rank_min,
  q.any_rank_min, q.target_jokers, q.deck, q.target_locations,
  q.stake_level, q.reject_perishable_targets, q.interchangeable_copies,
  q.missing_names, q.minimum_distinct, q.first_ante, q.last_ante, q.budget_ms)
```

The 28 native arguments are primitive values, never callbacks or live game
objects. The request binds an active loaded profile; no profile/save reads are
performed by this worker. The main runtime must refresh progress and compare its
profile/generation before accepting a result. `minimum_distinct` is a count of
distinct supported missing centers; `first_ante` is inclusive. A UI labeled
“after Ante X” should pass X+1, not X.

Before start, set a controller-owned native-busy latch. `ar_active`, Ctrl+A,
challenge searches, and `requestSearchEstimate` must respect it. Read-only stale
estimate display is fine, but do not run another native query while a worker is
active. A profile change, manual gameplay or stop invalidates the generation.

On stop, push cancellation to its channel, call the main-thread loaded same DLL's
`brainstorm_cancel_v9()`, and keep calling cancellation each update while that
thread still runs. This covers the narrow race between the worker's pre-start
check and v9 clearing prior cancellation. Keep the busy latch until the thread
has actually exited; never overlap an old canceled job with a new search/estimate.
`thread:isRunning()` and `thread:getError()` distinguish response delivery from
thread exit. No spin loop or blocking wait belongs in the game update callback.

Worker replies include generation, status complete/cancelled/error, raw native
JSON and any local error. Decode complete results using the product's existing
JSON decoder. Only apply a nonempty valid seed when both layers report found,
the generation/profile still match, the user explicitly started the controller,
and the transition is currently safe. Log timeout, cancellation, invalid/busy
and errors. Do not reclassify them as “no seed exists” or renew a spent job budget.

Actual v9 deadlines are capped at30,000ms and cooperative between bounded work
units. A deadline can slightly overshoot during the current batch and cleanup.
The product should expose a Stop action and enforce a total session bound. The
native candidate counter is available only on return in this first slice.
Expected waiting time for this new compound OR/quota query is explicitly
unavailable; ordinary v8 estimates are not estimates of this query.

Filter-info route metadata should identify API9 and retain query target names,
deadlines, OR flag, missing-name list, inclusive window, requested quota, budget,
profile binding and native receipt. The lookup is a conditional no-reroll route;
ordinary incidental Joker acquisitions or different pack behavior can change
later offers. It proves no affordability, survival, acquisition or Gold win.
