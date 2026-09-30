# Prospective M19 cache comparison

Prepared only. Root owns fresh M19 registration and execution under the active
cycle. No captured decision, original-source initialization, search, game action
or selected-action rescore has run during preparation.

The baseline is the exact frozen `certificate309_installed` policy. Candidate
is the same complete product/dependency manifest with only
`Brainstorm/Advisor/score_cache.lua` replaced by the reviewed FIFO draft. Both
use the unchanged8192 default capacity and original decision budgets. Later
Certificate310/front normalization and planned pack311 changes are excluded.

Inputs are exact `engine_episode_decision_started` public snapshots from C04
steps85 and185. Extraction verifies each equals the subsequent completed
decision snapshot, preserves `completionist_goal` including all150 synthetic
missing Jokers, and records raw trace line hashes and canonical snapshot hashes.
C04's original timeout, registration, source/profile/runtime/adapter provenance
and independent audit remain unchanged. These are dependent development states,
not population observations or complete games.

Four fresh isolated Lua states run in this fixed order:

1. Baseline309, step85.
2. FIFO candidate, step85.
3. FIFO candidate, step185.
4. Baseline309, step185.

The driver derives its dependency graph from frozen309 runtime initialization,
preserving Certificate/Bell/Perkeo and complete continuation connections. It
replaces the filesystem loader with registered module preloads and excludes
only live action execution, retry initialization and product opening globals.
The snapshot is supplied directly; no live capture or profile refresh occurs.
Runtime/UI/default settings are never executed. All product files are frozen,
but only Advisor Lua modules are parsed, and only decision dependencies load.

Every decision uses product defaults with no retry option. Its actual scoring
entry point refuses a140001st call. The job-wide maximum is560000 calls, four
decisions, and30 seconds inclusive of compilation/I/O. No compute cap rises.
No per-score timers are installed: only two host monotonic reads and two Lua
`os.clock` reads surround each complete decision. Each state/cache is fresh.

Results preserve full decision semantics, action, evaluated-call count, actual
score-call count, unchanged-input proof, and cache hits/misses/stored/capacity/
evictions when present. Pair comparison removes only the result's top-level
`score_cache` diagnostic object. Every other result field, action, evaluation
count, actual score count and input fingerprint must match. A mismatch is an
error; it is not silently presented as a speed result. The Lua driver preserves
decision exceptions/cap failures as partial receipts, and root's outer timeout
preserves any incomplete result. No failed job is replaced or renewed.

## Parent commands

Review the files and `register.py --describe`. Only root may invoke
`register.py --register`, which uses `cycle.register('M19', ...)` and copies the
complete baseline/candidate manifests, snapshots, provenance, adapter, current
Python and isolated lua51.dll hashes. It does not read or bind Balatro.exe;
historical source hashes come from preserved C04 records.

After registration, root invokes the existing `cycle.py run M19` once. The
worker requires root registration, current authority, an existing root spent
receipt and a create-only comparison marker. It cannot run from this draft
directory or register itself. A30-second timeout is a retained timeout, not
permission to retry in another directory.

## Routine synthetic validation

- One Lua driver fixture passed252 checks, including the140000 hard stop,
  input-mutation evidence, failed-decision preservation, disconnected-module
  rejection and exactly two whole-decision wall-clock callbacks. These use
  manufactured state and inert policy doubles, never captured data.
- Four Python tests passed: exact-only diagnostic exclusion, fixed order/caps,
  one-file candidate difference and frozen runtime-prefix derivation.
- The unchanged compile-safe `lua_bytes.py` passed its five synthetic byte/
  CRLF/large-module/UTF8/nonfinite tests. It emits one escaped literal rather
  than deep concatenations that caused M09's preserved parser failure.

Any eventual timings will cover two states with one ordered pair each. They
cannot establish a general speedup, player win rate or terminal outcome.
