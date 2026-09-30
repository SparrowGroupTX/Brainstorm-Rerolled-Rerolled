# Checkpoint reliability and optional player observations — 299

The user explicitly requested repairs to the Z+1–5 / X+1–5 checkpoint feature
and recording public game state with advice at actual player actions. Product
hooks implement that scope. Development tools did not open player save/profile
files, launch/control the game, or run source/search/terminal experiments.

## Concrete defects

The old shortcut passed `G.ARGS.save_run` straight to `compress_and_save` without
refreshing it. That table can be absent after restart or describe an earlier
decision. The original compression helper ignores the filesystem write result;
the shortcut always displayed success. Loading deleted the active run before
checking whether the slot existed or could be decoded, then always displayed
success as well.

Read-only source references:

- [save_run in misc_functions.lua](https://raw.githubusercontent.com/Jofr3/balatro-source/main/functions/misc_functions.lua):
  rebuilds the current card areas, tags, GAME, STATE, BLIND and BACK synchronously,
  then assigns `G.ARGS.save_run` and queues ordinary autosave. This public source
  read was not executed as a source experiment.
- [engine/string_packer.lua](https://raw.githubusercontent.com/Jofr3/balatro-source/main/engine/string_packer.lua):
  the original compression helper packs tables and writes compressed bytes,
  without returning the write result. Legacy decoding remains source-compatible.

## Product behavior

`Core/checkpoint_runtime.lua` accepts one operation per number-key press and
requires a settled hand, shop, blind-selection or cash-out screen for saving.
Busy gameplay, overlay/text input, search, held-repeat and conflicting modifiers
do not trigger repeated or partial checkpoint operations. The fresh serializer
must actually produce a current run table; stale or unavailable data is rejected.
This also works when `G.ARGS` is initially absent after restarting the application.
Ordinary autosave is queued by the existing serializer, as it is for game actions.

`Core/checkpoint_store.lua` stores two alternating payload banks beneath each
profile's five slot names (`saveStateN.brainstorm-v2.a/b.jkr`), a commit record
and a write guard. Every write is read back before success. The receipt records
SHA-256, bytes, sequence, profile, seed, deck, stake, ante, round, state, version
and save time. The previous committed payload bank is preserved during the next
write. The original `saveStateN.jkr` legacy file is never overwritten or deleted.

A failed or interrupted new save after its first guard write leaves a pending
guard: a later load refuses to silently substitute the previous bank or legacy
save. Every write failure also blocks loads in the current session, including a
failure of the initial guard write itself. If the filesystem refuses that first
write, no software can persist the new failure marker across restart; the previous
verified slot remains identifiable by its displayed original save timestamp.
A subsequent explicit save
can repair a pending write. Corrupt commit metadata is refused rather than guessed.
Read-back verification is not a guarantee against later disk loss or external
rollback of all checkpoint files.

Load reads, verifies and decodes before calling delete_run/start_run. Existing
legacy slots remain loadable when no v2 slot exists, with their original save time
explicitly unknown. A successful callback reports that restoration is pending.
Only a subsequent settled state matching the requested seed, ante, round and state
reports Loaded and invalidates prior advice. A 15-second verification timeout is
reported as unverified completion. A load request can stop user-started auto-run;
no checkpoint operation starts or resumes it. No retry ledger/counter is changed.
If the source start_run itself raises after deletion, the failure is reported;
this layer cannot roll back partial game-engine side effects.

## Optional JSONL observations

`Advisor/player_journal.lua` defaults `advisor.player_logging` to false only when
the setting was absent; explicit existing settings are preserved. When enabled,
it wraps gameplay callbacks for play, discard, buy, use, sell, reroll, pack skip,
shop exit, cash-out, blind select and blind skip. It records detached pre-action
state and the published advice, labelling advice current/stale/computing/unavailable
at that instant. Selected hand indices and callback/card context are included.
Advisor Execute records its action before invalidating advice and suppresses
duplicate callback logging. Callback return/error and the first subsequent settled
observation are separate linked events; a callback return is not a completed win.
Checkpoint saved/requested/loaded/failed events carry slot and receipt identity.

Ordinary public deck/discard identities remain useful in the log. Genuinely
concealed held/outside identities are redacted consistently across areas; while
concealment exists, exact draw-pile assignments are also redacted to prevent
deduction by subtraction. The policy's sorted remaining deck is never draw order.
The large shop catalog forecast is omitted and this scope is recorded in each
observation. No hidden RNG/save bytes are copied into observation logs.

Logs are new `advisor_player_log_v1/session-TIMESTAMP-N.jsonl` files beneath the
game's normal LÖVE save directory. Existing logs are never overwritten. Bounds:
1 MiB/event, 2,048 events and 32 MiB per session, 128 MiB aggregate journal storage,
and 4,096 journal files. Exceeding a bound or an append failure visibly stops
recording. Append length is verified. Recording failure does not prevent the
player's action and does not silently retry. Arbitrary controller actions from
other mods and manual drag/reorder gestures are not dedicated action hooks; later
recorded snapshots include their resulting visible orders. Source evaluation keeps
recording disabled. No player run was used as a test or assigned a win-rate claim.

## Validation and navigation

Final focused receipt: `development294/checkpoint299b/report.json`; the earlier
passing `checkpoint299a` receipt remains preserved separately.

- `tests/advisor_checkpoint_store.lua`: 27 checks: restart, alternating bank,
  preserved legacy/last-good payload, write/readback/silent-stale failures, guard
  failures, pending repair, corrupt/missing receipt, changed payload.
- `tests/advisor_checkpoint_runtime.lua`: 25 checks: absent/stale serialization,
  fresh state after restart, no delete on bad load, deferred completion, preserved
  retry count, busy-state guards, hotkey repeat/release, receipt/run identity and
  legacy behavior, fake filesystem write failure.
- `tests/advisor_player_journal.lua`: 21 checks: opt-in, JSON escaping/bounds,
  immutable pre-action observation, concealment/ordinary visibility, failure
  notices, callback arguments/nil return tuple/errors, stale advice labels and
  post-action state observations.
- Existing `tests/advisor_runtime.lua`: 463 checks passed with journal integration.

All four focused fixtures passed, frozen bytes unchanged during validation.
Full candidate/exact-installed release evidence is maintained by the root release
workflow. These fixtures use synthetic state/filesystem doubles only; they do not
qualify every actual engine save/load phase or demonstrate a gameplay improvement.
