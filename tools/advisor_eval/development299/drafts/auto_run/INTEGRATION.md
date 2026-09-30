# Explicit-start auto-run controller draft

Status: ready for root integration. This directory is outside deployed runtime
and normal fixture discovery. This component performs no live-game operation,
search, original-source component, save/profile access, or terminal experiment.

## Product wiring

Copy `auto_run.lua` to `Brainstorm/Advisor/auto_run.lua`; copy the synthetic
fixture to `tests/advisor_auto_run.lua` and change its first `dofile` to the
runtime path. Load the module through the existing Advisor loader and manifest.
Create exactly one fresh controller on module load, with no persisted active
flag or restored session. Root owns the native thread, live observation,
terminal evidence, menu, manual-input hooks, and all callback implementation.

The module exports `M.new(deps)`. The returned object supports:

- `start(options) -> accepted, reason`: explicit user click only. This binds the
  current profile and change generations, logs consent, and schedules work. It
  dispatches no search and performs no gameplay in the start call.
- `tick() -> status`: one update step. It may dispatch one search/start or at
  most one action, with reentrancy protection. It must be called from the game
  update after public state and advisor publication can be observed.
- `stop(reason) -> worker_fully_stopped`: stops the session and requests owned
  search cancellation. It never stops, restarts, or otherwise controls the game.
- `status() -> plain copied table`: includes state, active, busy, reason, detail,
  complete, waiting_for, search_draining, cancel_requested/error, log_error,
  runs_started, actions, run_actions, outcomes, profile_id, run_id, search_id,
  session_started_at, search_deadline and pending_action.

Suggested facade: `B.AutoRun.start(options)`, `.stop(reason)`, `.update(dt)`
calling `tick()`, and `.manual(reason)` calling `stop(reason)`. An inactive
controller does no observation or background work except polling an already
owned canceled search until its actual worker exit is confirmed.

## Observation contract

`observe()` returns a fresh plain table. Do not read player files for this;
use currently loaded public game/profile state. The following fields are used:

```lua
{
  profile_id = 1, -- stable loaded-profile identity: integer or nonempty string
  consent_generation = 1,
  settings_generation = 0,
  checkpoint_generation = 0,
  manual_generation = 0, -- all four nonnegative integer change counters required
  run_id = 'game:42', -- stable identity of this actual G.GAME table, not seed
  fingerprint = 'current public-state fingerprint',
  advice_fingerprint = 'same fingerprint used to publish the current advice',
  action_token = 'current published action identity',
  action = {kind='...'}, -- plain current action for the action-time log
  advice = {title='...'}, -- bounded plain current suggestion and rationale
  ready = true, -- settled public state, not animations or queued transitions
  modal = false,
  paused = false,
  advisor_busy = false,
  action_pending = false,
  search_busy = false,
  unsupported = false,
  transition_ready = true,
  goal = loaded_gold_stickers_capture,
  terminal = nil,
}
```

`goal` is a freshly reread `gold_stickers.capture` schema-1 result with
`goal='gold_stickers'`, matching `profile_id`, complete metadata/catalog/stake
statuses, total 150, and consistent complete/missing/unknown counts. Any unknown
records stop further work. Only zero missing **and** zero unknown establishes
collection completion. Holding, buying, or anticipating a Joker does not change
these counts. Goal metadata is reread after terminal observation and before the
next search. Never cache the opening missing set for an entire session.

`ready` must be false during the advisor worker, game event transitions, pack
animations, overlay menus, moving cards, or any pending Execute action.
`search_busy` means an actual running native worker, including cancellation
draining; a retained exited/found receipt alone is not busy. The controller
tracks its own search separately and stops if an external worker appears.

`transition_ready` means it is safe to begin a newly searched run. The controller
may start a run only after a separate fresh observation following search
completion, and starts another search only after a separate fresh observation
following a terminal result. Keep the prior `run_id` stable until controller
`start_run` changes the actual run; unexpected replacement stops the session.

Fingerprint must include actual Joker order, selected action-relevant public
state, cash/inventory and other existing execution safeguards. A fresh action
token at the same fingerprint does not permit a second attempt after Execute.
Only a changed fingerprint, settled state and fresh matching advice clear the
pending-action guard. A reversible ordering action must therefore change the
fingerprint through actual order; merely invalidating advice is insufficient.

## Callback contract

All callbacks are required and must be bounded/nonblocking except tiny local
log append and snapshot assembly. `now()` returns finite monotonic seconds.

`log(event)` accepts a bounded plain schema-1 event, returning nil/true on
success or false/throw on failure. The controller logs before dispatch, startup,
and Execute. Failure prevents the upcoming operation and stops the session.
Action attempts and their contemporaneous advice are separate from observed
state changes and verified terminal outcomes. Wire this to the existing journal
without transforming an action attempt into evidence that it happened.

`search_start(request) -> true | false, reason` dispatches exactly one owned
worker and returns immediately. Request contains:

```lua
{
  request_id = 'auto:<consent>:<session>:<search>',
  recipe = immutable_options_search_request,
  goal = freshly_loaded_gold_capture,
  profile_id = bound_profile,
  consent_generation = bound_generation,
  budget_seconds = 30,
  deadline = monotonic_absolute_deadline,
}
```

An explicit false return must prove **no worker started**. A throw, nil, or any
uncertain return retains worker ownership and requires cancellation/draining.
Do not modify global settings to make the request; use immutable worker inputs.

`search_poll(request_id)` returns `{request_id=..., exited=boolean,
status='running'|'found'|'not_found'|'error'|'cancelled', found={seed='...', ...},
reason=...}`. Results are owned by request identity. Only `exited=true` proves
the worker is no longer active. A stopped session ignores any late found result.

`search_cancel(request_id)` is idempotent and affects only that owned handle.
It must tolerate an uncertain dispatch. Cancellation is requested once; polling
continues until actual exit, including after log/clock/manual/profile failures.
The UI must continue displaying `search_draining`/busy until exit; never pretend
an abandoned handle exited just to permit another search.

`start_run(found, binding) -> true | false, reason` starts the requested result
through product code. Return true only for an accepted single startup request.
Do not restart or retry internally after uncertainty. Ensure the selected normal
deck/stake, unseeded filtered-route metadata, and two-Soul route receipt match
the immutable recipe; do not silently substitute a different deck/stake/seed.
The controller waits for a different run identity and settled public state.

`can_execute(fingerprint, action_token) -> true | false, reason` and
`execute(fingerprint, action_token) -> true | false, reason` wrap the existing
`A.can_execute` and `A.execute` gates. Both must revalidate the matching
published action and all existing guards. Execute gets no special exemption
for unknown mechanics, stale advice, callbacks, modal state, or inventory.
The attempt is consumed before invoking Execute; false/throw stops without a
retry, since the physical result may be uncertain.

## Manual activity and terminal evidence

Increment the relevant generations and call `stop` for external player actions,
checkpoint save/load attempts, profile changes, settings edits, opening a menu,
and manual stop/pause. Checkpoint identity is separate from seed/public-state
identity. Do not increment manual/settings generations for controller-owned
Execute, search request assembly, or run startup. Scope the internal-action
marker tightly around those callbacks; never globally suppress player events.
Starting requires the menu already closed and no pending external activity.

Root must provide terminal receipts from the original progress path, bound to
this actual `run_id`, with a unique nonempty `event_id`:

```lua
terminal = {kind='win', verified=true, run_id='game:42', event_id='win:42',
  source='original_win_callback', -- plus original callback/sticker evidence
}
terminal = {kind='loss', verified=true, run_id='game:42', event_id='loss:42',
  source='GAME_OVER', -- plus original terminal evidence
}
```

The module deliberately rejects `GAME.won` alone, unverified reports, foreign
run callbacks and invalid sources. A verified outcome is preserved even if
the next Gold metadata capture is unknown; unknown metadata blocks subsequent
continuation and never converts the run into achievement completion.

## Bounds and meaning

Options are immutable copied plain data. Integer limits may be lowered:

| Option | Default | Hard maximum |
| --- | ---: | ---: |
| search_seconds | 30 | 30 |
| stall_seconds | 30 | 30 |
| max_actions per run | 500 | 500 |
| run_seconds | 1800 | 1800 |
| max_runs | 25 | 100 |
| session_seconds | 21600 | 21600 |

Root derives a smaller session time from the user deadline when appropriate.
There is no embedded date, class time, schedule or automation. Search uses an
actual clock deadline independently of native estimates and rechecks time after
dispatch/poll to reject late results. Session time includes search/startup;
per-run time includes startup. Missing/unsupported/stalled actions wait at most
the configured 30 seconds; changing incidental fingerprints cannot renew it.
Attempt counts are not verified actions, wins, or acquisition claims.

The pure controller does not choose a strategy, calibrate odds, qualify a worker,
prove native cancellation or progress callbacks, or prove a live full run works.
It preserves existing planner budgets and user-clicked activation boundaries.
Its synthetic tests establish control-flow and failure behavior only. Root must
test the actual callback facade and exact installed bytes separately.

## Synthetic validation

`advisor_auto_run.lua` passes 312 checks under the repository Lua 5.1 fixture
runner. Coverage includes explicit-only startup, no idle monitoring, immutable
recipe/bindings, hard time/action/run bounds, one Execute per fresh observed
state, reentrancy/manual stop, worker cancellation ownership/draining, late
results, uncertain dispatch/start/Execute, logging failures, unsupported states,
changed profiles/settings/checkpoints/manual actions, verified two-run lifecycle,
fresh missing sets, and exact known-zero completion. The fixture forbids game
or global RNG calls and uses injected synthetic callbacks only.
