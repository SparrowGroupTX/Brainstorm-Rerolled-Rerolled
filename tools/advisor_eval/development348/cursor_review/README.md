# Collection search cursor restart review

Read-only review of installed-checkpoint 2.147 product code, with a manufactured
fixture using the actual Lua product facade and mocked runtime receipts. No
native search library, real search/worker, captured policy, original game source,
gameplay, save/profile access, or current-settings write was used. The standard
fixture runner uses the existing isolated Lua 5.1 runtime as usual.

## Source finding

`Brainstorm/Core/Brainstorm.lua:5` creates a fresh `Brainstorm = {}` at boot.
`loadConfig` at line 1606 restores only `Brainstorm.config`; `writeConfig` at
line 1625 serializes only that configuration table. The product module is loaded
at line 1751. The only `collection_search_cursor` references in product code are
inside `Brainstorm/Core/collection_search_product.lua`:

- Lines 208–215: if the in-memory field is nil, initialize it from whole wall
  seconds modulo the native seed domain, plus one. There is no restore path.
- Line 239: consume the prepared request and reserve `start_index + 1` before
  dispatch, including partially started failures.
- Line 297: the optional Burnt fallback reserves its new initial index in the
  same way.
- Lines 346–348: an accepted receipt with valid screened count advances to the
  found seed's native index plus one, or to `start_index + max(1, screened)` for
  other outcomes, retaining the larger in-memory value.
- Line 367: logging correctly states that interrupted parallel screened counts
  are not a claim of contiguous coverage.

Nothing persists this cursor, so restarting discards the accepted progress.
Wall time changes by one index per second; a rare qualifying opening may lie
many more indices ahead. Two close restart origins can therefore return the same
first qualifying seed. This is a deterministic continuity gap, not evidence of
bad randomness. It does not prove the cause of the user's latest repeated core
or repeated seed without the separate passive-log comparison.

Within a single boot, the existing match-plus-one behavior is correct for a
validated accepted match. A cancelled/stale receipt does not advance from its
untrusted screened count; only the already-consumed initial index remains spent.
Neither existing nor proposed persistence proves a contiguous enumeration of
interrupted native parallel work. Search conditions may also legitimately keep
producing the same requested core Jokers on different seeds.

## Manufactured fixture

`tests/advisor_collection_cursor_review.lua` passes **40 checks** in
`validation1.json` / `validation1.log` against the exact source hashes recorded
there. The mock runtime performs no seed enumeration; its receipts are supplied
explicitly by the fixture.

Two fresh facades at wall seconds 1,900,000,000 and 1,900,000,120 start at native
indices 1,900,000,001 and 1,900,000,121. Both accept the same explicitly mocked
qualifying seed at index 1,900,100,000. The second request in the first facade
starts at 1,900,100,001 and accepts a different mocked match. A separate fresh
facade supplied that explicit restored cursor does the same without consulting
wall time. This demonstrates the consequence of current control flow; these
numbers are manufactured and say nothing about real match frequency or timing.

The fixture also checks exact accepted miss/timeout advancement, zero-count
receipts, cancellation, stale receipts, dispatch failure, request reuse,
unchanged settings, and domain exhaustion without wrapping. No fixture failure
occurred. Native search code was never loaded; the receipt's original
`native_loaded: false` field means native **search** code, not the normal Lua
fixture runtime DLL.

## Proposed persistence gate — no implementation in this component

Restore deterministic continuity rather than randomizing each boot. Preserve
the existing one global cursor semantics; profile/query ownership remains a
separate per-request binding. A cursor should not reset when sticker population,
deck, core target, or wall time changes.

Use a dedicated small sidecar under the mod's own data location, separate from
current settings, observation logs, profiles, game saves, checkpoints and retry
memory. A bounded two-slot record (at most 1 KiB per slot) could contain schema,
seed-domain/enumeration version, monotonic sequence, next index, and integrity
check. Parse plain bounded data without executable Lua. Accept only exact finite
integers within the domain, including a distinguished exhausted sentinel. Load
once during initialization; do not perform disk I/O every update or animation.

Before dispatch, durably save and read back the consumed initial reservation.
Failure must prevent dispatch and show an explicit status rather than silently
falling back to memory-only operation. After an accepted matching receipt,
durably save its monotonic cursor advance before exposing the match for launch.
Keep at least one prior valid record while replacing the other slot, with
write/readback validation and the highest valid generation chosen at startup.
Do not discard or overwrite an unreadable/corrupt record during recovery. Both
slots absent is first initialization; malformed existing persistence is an
explicit recovery condition, not permission to restart from the wall clock.

The gate must not wrap an exhausted domain, trust stale/cancelled receipts, or
claim progress over unverified parallel ranges. New persistence should not
change native search caps, worker ownership, request consumption, cancellation,
or searched-run provenance. It does not provide stronger openings, missing
Joker acquisition, retention, Gold awards, or a measured win-rate improvement.

Useful implementation fixtures would inject an in-memory persistence backend
and test two real facade lifecycles, all write/readback failures, malformed and
oversized records, older/newer slot selection, late receipts, exhaustion, and no
settings/save writes. This review implemented no persistence or runtime change.
