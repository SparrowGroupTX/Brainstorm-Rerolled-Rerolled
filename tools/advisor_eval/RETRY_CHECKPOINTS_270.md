# Manual checkpoint retry memory — 2026-09-12

This note describes the installed 2.70.0-alpha component. SESSION_RESET_270.md
and its JSON own final versions, hashes, full-suite results and activation status. This feature has no measured win-rate or completion-time gain.

## Manual workflow

1. The user creates a checkpoint using their own save/restore workflow. At the
   same settled, supported advisor decision, open the advisor panel and choose
   **Remember this decision**. This records public decision metadata; it does
   not create a save or verify that a save exists.
2. Close the panel and use the existing user-clicked **Execute** for the first
   advised action. Only a successfully accepted first execution at the marked
   public state becomes a pending line. Rejected or uncertain execution is not
   claimed as a recorded line. Later advice and actions proceed normally.
3. If that continuation loses, the user restores the checkpoint themselves.
   Once the game is settled at the matching public state, open the panel and
   choose **I restored after a loss - try another line**. This is an explicit
   user report; the advisor does not detect the loss or perform the restore.
4. Each accepted report spends one of five manual reloads. The advisor either
   offers a supported untried first action or explains why the decision needs
   review. Each offered action still requires the ordinary user click, followed
   by fresh advice after the actual state changes.

The recorded scope is the first executed decision starting a user-reported losing
continuation. There is no whole-continuation search, complete action-suffix log,
automatic replay, RNG exploration or claim that the first move caused the loss.
Later user deviations, later policy choices and random outcomes are not inferred.
Actions performed outside Product Execute are not recorded as line starts.

A restored matching checkpoint with an unconfirmed pending line is review-only:
old advice and selection controls are withheld until the explicit report. The
fifth accepted reload still permits an alternative on that restored attempt;
a sixth report is refused. Re-marking the same decision preserves its pending
and reported history. Marking another checkpoint preserves the run-wide count.

## Public identity and bounded ledger

`Brainstorm/Advisor/retry_memory.lua` is a pure module: it has no filesystem,
clock, save, game or RNG access. `new`, `mark`, `record`, `failed`, `context`,
`export` and `import` use detached bounded plain data. Imported counters must
agree with the run-wide report history and the current checkpoint's attempted,
pending and reported actions. Reports are labeled `reported_line_start` and
`user_reported_public_checkpoint`, never as an unconditional losing action.

The public key includes current public resources/mechanics, ordered visible
areas, and normalized known remaining/full card composition. IDs are used only
to validate the hand/deck/population partition; sorted composition excludes
draw order and arbitrary object addresses. Tooltip caches are excluded. Unknown
or concealed held cards and genuinely concealed nondrawable outside cards cause
abstention before their identity payload enters a key. Ordinary discarded backs
already normalized as public by `snapshot.lua` remain public. Private RNG fields
are outside this projection, and incomplete or inconsistent populations decline.

Exact matching means equality of that supported public projection. It proves
neither identical save bytes nor identical hidden RNG counters or future draws.
The advisor does not inspect save files to strengthen the match.

Runtime identity combines profile, public seed, challenge, deck and stake. It
is separate from scoring observations and deterministic sampling. A fresh run
with the same combination is ambiguous and inherits the existing allowance;
it cannot renew five reloads merely by presenting a new game object. Missing
identity disables checkpoint controls. A genuinely different catalog identity
has its own allowance, while older identities retain their spent counts.

Bounds are five reports per identity, 256 checkpoint marks, 64 attempted action
records in the current checkpoint, 512 cards per observed area, 131,072 bytes
per public-state key and 4,096 bytes per action key. Plain metadata has structural
depth/node limits. `action_key_context` validates one immutable observation once
and supplies the same canonical action serializer without repeating population
serialization for every alternative. It retains only phase/area lengths and is
not persisted or reused across decisions. Ordered plays, discards, targets and
permutations remain distinct. Descriptive sell followups are excluded because
execution performs only the first sale and then replans.

## Durable metadata and failure behavior

`Brainstorm/Advisor/retry_journal.lua` supplies a deterministic non-executable
plain-data codec and an injected storage interface. Runtime binds it only to
these two dedicated files in the LÖVE filesystem:

- `advisor_retry_metadata_v1.dat`
- `advisor_retry_metadata_v1.guard`

These files contain advisor metadata, not save contents or current settings.
The catalog holds at most 64 identities and 16 MiB. Full catalogs refuse a new
stored identity; they do not evict old allowances. Updates cannot decrease
counters, replace earlier reports or silently erase a pending first action.

Each write first writes and reads back a nonempty guard, then writes and verifies
the catalog, then writes and verifies an empty guard. An interrupted update,
read/write/verification failure, malformed/noncanonical data, unknown fields,
oversized data, missing catalog beside an existing guard, or missing guard beside
an existing catalog fails closed. There is no fallback to a lower-count backup
or automatic corruption reset. Only an initially absent pair starts an empty
catalog; read-only access creates no files. Verification does not promise an
atomic transaction or power-loss-proof storage.

The user's manual save restore must leave these metadata files intact. The
journal is local metadata, not tamper-proof storage or proof against external
rollback/deletion of an entire internally consistent file pair. Restoring an old
advisor journal is not an authorized way to renew the reload allowance.

## Retry alternatives and execution safeguards

`retry_policy.lua` runs after the normal decision through `decision.lua`. It adds
no scoring calls, draw samples or search allowance. If the normal first action
has not appeared in this checkpoint's reported lines, ordinary advice remains.
If it has, retry preference uses only complete existing admissible comparison
families. It does not rank an incomplete shortlist as complete evidence.

Current scope is deliberately narrow: no owned Jokers or Observatory engine;
complete revealed-Planet pack choices or supported visible Planet shop sequences;
and complete plain visible hand/discard comparisons within their existing small
hand limits. Shop alternatives retain legal sequence, cash/reserve and whole-
inventory evidence. Matched endpoint checks protect supported clears, population
and finishing rewards. Hand retries decline protected growth, consumable,
ordering/rescue, larger/deeper resource and unsupported effect paths. Random
upside, Arm damage, Glass/population conservation, Perkeo and other inventory
engines are not overridden by an arbitrary untried action.

An untried alternative is selected deterministically using the retained policy
ranking and canonical-key tie break. Final-hand discard comparisons retain their
survival ordering. If evidence is incomplete, every admitted alternative has
already appeared, or the only protected action should remain for review, the
result is review-only with no executable substitute. A reported line does not
invalidate an otherwise supported immediate clear. None of these local branches
is a predicted rescued run or a win-rate estimate.

`runtime.lua` and `Brainstorm/UI/advisor.lua` expose settled-state controls and
metadata status. Public observation, retry generation, state epoch, run identity
and current game object bind callbacks and published advice. Stale menu/HUD
callbacks, replaced game instances, outstanding workers and duplicate execution
are guarded. Only a verified explicit restored-after-loss report can release an
identical-state execution latch. Unavailable or corrupt retry storage leaves
the affected decision review-only. Save-manager hooks are not installed; normal
game save caching is not treated as a checkpoint-restore signal.

## Evidence and boundaries

The frozen `runs/retry_memory270_unit1` record contains **177 passing memory
checks** in 0.1326940999715589 seconds under a 15-second isolated Lua unit cap,
unchanged memory/test hashes and zero source workers. It covers public-key
composition/order/ID invariance, hidden-card abstention, exact counter and pending
behavior, canonical actions, malformed/imported data, prepared-key parity and
absence of filesystem/OS/game/RNG access inside pure operations.

Current root fixtures `tests/advisor_retry_journal.lua`,
`tests/advisor_retry_policy.lua` and `tests/advisor_runtime.lua` contain coverage
for persistence/restart, partial writes and missing-file guards, bounded catalog
retention, complete comparison reuse/protected counterexamples, the five-report
workflow, pending review, UI callbacks, failed execution, stale generations,
same-identity game replacement and storage errors. Runtime tests use detached
fake observations and injected fake metadata IO. Their final check counts and
passing hashes are in runs/development270_installed_validation. The final release
passes 97 Lua fixtures and 221 Python tests; focused checks are memory177,
journal112, policy90 and runtime405. Activation is not yet confirmed.

No tools created, read or restored a game save, executed live gameplay, launched
or controlled Balatro, or ran a new original-source attempt for this component.
The user alone performs any later save/restore/game actions. Existing source
attempt allowances remain spent. Installed activation waits for the user's normal
restart. Synthetic fixture evidence does not qualify measured player odds, the
per-challenge 50%/75% targets, or an expected-time improvement across all 20.
