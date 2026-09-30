# Collection product facade draft

`collection_search_product.lua` is a Core module draft. It is not automatically
loaded or installed from this directory. Root owns staging, native sidecar
qualification, exact-byte regression and installation. No live game, player
save/profile file or original-source experiment was used to develop this facade.

Call `module.attach(B, deps)`. It returns and sets `B.CollectionSearchProduct`.
All public methods are dot-called. `api.status` is a user-facing status string.

Dependencies:

- `game()` defaults to the already-loaded global G.
- `runtime` defaults to B.CollectionSearchRuntime, using the separate bounded
  LOVE-thread bridge. `query` defaults to B.CollectionSearch, the pure request
  builder. Inject the builder explicitly if its product export differs.
- `gold` and `stickers` default to Advisor.gold_search and Advisor.gold_stickers.
  `progress()` optionally replaces the default `stickers.capture(G,{enabled=true})`;
  it must return a freshly detached capture of the active loaded profile. No file
  reading belongs here. Gold search validates all 150 rows and counts, vanilla
  catalog and stake identity, and zero unknown records.
- `input_token()` defaults to B.collection_search_input_generation (or zero).
  Root must either increment it on physical intervention or call `stop` directly,
  including key/mouse, filter-option changes and checkpoint operations.
- `pending(g)` optionally adds known save/transition state to the built-in guards.
  Built-in guards cover Checkpoints.pending/saving, B.save_pending/checkpoint_busy,
  G.SAVING/LOADING, ar_active, STATE_COMPLETE, overlays, pause, screenwipe, STOP_USE,
  controller dragging/text/locks and cards still on the played area.
- `exit_overlay()` must be the original UI callback; fallback is G.FUNCS.exit_overlay_menu.
  `back(center)` defaults to Back. `delete_run(g)` and `start_run(g,args)` default
  to the original G instance methods; dependency injection can retain references
  before adding manual-input hooks. Never use forced-generation replacements.
- `wall_time()` defaults to os.time, solely for independent seed cursor initialization.
  `on_event(kind,data)` optionally replaces protected Advisor.player_log:event calls.

Public contract:

1. `prepare(options)` returns a bound request or `nil, reason`. Preparing starts
   nothing. The object contains `request_id`, `profile_id`, `profile_token`,
   `query`, and `requested_budget_ms`. Only an original unmodified prepared object
   is accepted by `begin`. Native budget is `min(requested_budget_ms,27000)`;
   the advertised maximum remains30 seconds, reserving3 seconds for cancellation
   and cleanup. The separate bridge retains its generic30-second upper bound.
2. `can_begin()` returns true or `nil, reason` when game state/search ownership
   is unsuitable. The auto controller should wait here before spending a request.
3. `begin(request, ownerId)` is the explicit dispatch authorization boundary. It
   returns request_id or `nil, reason`, consumes the request before dispatch and
   starts only the worker. `ownerId` is a nonempty string up to128 characters.
   Call it only from an already user-armed controller; prepare is not consent.
4. `poll(ownerId)` returns the retained owned record
   `{request_id,generation,exited,status,found,reason}`. A running record has
   exited=false; no found result exists until actual worker exit. Terminal
   `found={seed,request_id,generation,profile_token,receipt}` is bound to its exact
   request, active profile/missing population, input token and starting public
   run identity. Other owners cannot retrieve its result.
5. `launch(found,ownerId)` returns true, or `nil, reason, retryable`. A transient
   unsettled screen/native-busy condition can retry the same receipt. A changed,
   cancelled or consumed receipt cannot launch. The original found object must
   remain unmodified, including its nested receipt. It is marked consumed before
   any run mutation; exceptions cannot replay delete/start.
6. `cancel(ownerId,reason)` rejects other owners, revokes a found receipt and
   requests cooperative cancellation. `stop(reason)` also revokes any pending
   manual UI start. Neither clears the bridge's native-busy latch prematurely.
7. `start_manual(options)` explicitly closes the current overlay, waits for it
   to settle, dispatches one search, and starts one normal run on a valid result.
   It does not autoplay or loop. `update()` advances this nonblocking manual
   state machine and drains an owned worker after cancellation. Product update
   can run every Game:update; the separate auto controller can also call poll.

Launch selects the existing vanilla Red or Zodiac back, clears viewed_back and
challenge setup, and calls delete_run/start_run with stake8 and the actual found
seed. It preserves the normal searched-run used_filter=true/seeded=false behavior.
The API9 filter receipt contains all28 exact native arguments, the explicit
normal_two_soul_v1 opening recipe, canonical Yorick/Burnt/Brainstorm/Perkeo target
identities, one-use two-Soul marker, optional copy alternatives and native search
receipt. The existing normal_opening parser accepts the recipe; its live action
logic still observes real Soul acquisitions. Nothing awards or forces a Joker.
Future target offers remain conditional, not affordable acquisition, survival,
retention or a win. Advisor.settings_changed is called after successful start.
Root's auto controller must retain its executing guard around launch so original
callbacks/settings refresh are not misclassified as physical intervention.

Cursor is B.collection_search_cursor, using Immolate seed.hpp's variable-length
enumeration (domain2318107019761). Dispatch reserves at least one index before
calling native. A match advances to max(current,matchIndex+1); other parsed
results advance to max(current,start+max(1,screened)). Exhaustion stops instead
of wrapping. Cursor is independent of game RNG and remains in memory across
runs. Parallel screened counts are completed chunks, not a contiguous resume
watermark after interruptions. Receipts explicitly retain this limitation;
some previously examined chunks may be revisited. No-disjointness or unique
coverage claim is made, and errors/timeouts/cancellations never auto-retry.

Relevant validation: `collection_product_fixture.lua`121 synthetic checks, plus
the29 query,96 bridge and149 worker checks. The final staging run must execute
fixtures against actual product paths and freeze the new module bytes. Earlier
focused receipts under development294 hash fixture paths and existing product
files, but do not automatically hash draft module dependencies in this directory.
