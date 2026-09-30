# Runtime and journal redundancy audit for 335

Only candidate files in this directory changed. Production source, existing
tests and navigation documents remain untouched by this component. All source,
captured-state, game-control and save/profile authority remains closed.

## Candidate

`player_journal.lua` makes two local changes to the current 334 journal module:

- Journal observation still captures and detaches the complete public state on
  every event. Before fingerprinting, it checks whether a published key exists
  and belongs to the current game. Absent publication or a different game already
  proves that advice is not current. Matching and mismatching keys for the same
  game continue to receive fresh complete fingerprints.
- Callback request fields are collected only when recording is enabled, is not
  suppressed by its owning action, and has no previous recorder error. Without
  that gate, selected-card scans and input-table construction run before
  `before()` discovers there can be no event. Every callback retains its existing
  protected call, argument forwarding, exact return tuple and exception path.
  Logging eligibility is checked on each invocation; nothing is cached.

The manufactured differential fixture compares complete serialized event bytes,
sequence links, settled observations and journal counters against the preserved
334 baseline. Its nine cases cover disabled, suppressed, stopped, no-key,
different-game, mismatching-key, current, computing and unavailable states.
Separate cases cover an owned outer wrapper, repeated hook installation,
callback replacement, nested owner suppression and enable transitions. Fixed
manufactured clocks make byte comparisons deterministic. Timing collection and
archive encoding/writing code are unchanged; fewer real fingerprint invocations
naturally produce fewer fingerprint metric samples. This is measured avoided
work, not a live FPS claim.

## Deliberately retained work

`runtime.lua` recaptures and fingerprints before each worker slice and at final
selection/execution gates. These calls protect against stale publication after
card order, visible ability, resource, phase, run and profile changes between
frames. The 0.3-second idle interval and all those invalidation gates are intact.

`auto_run_product.lua` already avoids public snapshot construction while busy,
searching or terminal. Its settled unsupported endpoint still needs a fresh
fingerprint to acknowledge the prior action. Its execution gates intentionally
recapture because intervening logging/callback work can change public state.
Cross-frame reuse without a complete source of mutation notifications is unsafe.

`retry_journal.lua` already caches its loaded catalog. Re-importing its current
ledger preserves its validation boundary; this component makes no retry change.

`public_snapshot()` currently copies the shop forecast before omitting it. That
copy looks avoidable, but skipping it would also skip its existing cycle, depth,
node and value validation, changing recorder-failure behavior. No change was
made because the small local gate improvements above have a cleaner equivalence
argument and preserve the existing observation structure checks.
