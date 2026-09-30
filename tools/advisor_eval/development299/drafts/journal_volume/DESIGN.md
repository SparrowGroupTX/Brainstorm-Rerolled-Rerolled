# Bounded journal rotation and lossless snapshot references

Status: read-only sizing and proposed implementation. No runtime/test files were modified. This design requires a new coherent release and its own ordinary validation. It creates no source/search/complete-attempt authority and renews no retry or experiment allowance.

## Measured preserved C01 payloads

`analyze_c01.py` read the immutable C01 trace, checked its recorded hash, and invoked only the current `player_journal.public_snapshot` and `encode` functions in an isolated Lua51 state. It did not load original game code, evaluate policy, replay actions, advance RNG or access player files. All 225 original decision snapshots remained available; Gold objective context was disabled in this run. The JSON report contains the measured module/runtime/trace/script hashes and all per-step byte sizes.

| Serialization scenario | Public snapshot records | Raw bytes | Independent zlib6 payload bytes |
|---|---:|---:|---:|
| One public snapshot per preserved decision | 225 | 18,993,338 | 1,294,986 |
| Existing auto `action_attempt` plus advisor `action_requested` at each decision | 450 | 37,986,676 | 2,589,972 |
| Above plus two settled-state records between decisions, one after the final action | 899 | 75,883,880 | 5,175,869 |

The first scenario has median 85,449 bytes, p95 88,162, maximum 89,165. The second crosses the existing 32 MiB process cap at snapshot record399, before event/advice/envelope overhead. The fuller declared model crosses it at record402. Those record positions refer to the explicit synthetic serialization model, not actual live product timestamps. The actual journal was not active during C01; the next preserved decision is used as a disclosed settled-state proxy.

The fuller model has 1,124 action-related logical events: 225 each of action_attempt, action_requested, callback_result and state_after_actions, plus 224 action_observed events. Startup/search/terminal/overlay events add more. This explains why a 2,048-event process cap also obstructs a long session independently of compression. Nothing here forecasts a player's run length or storage use.

Exact snapshot deduplication leaves 226 unique payloads in the fuller model, including the terminal snapshot; independently compressed they occupy **1,300,621 bytes**. Whole-stream compression without deduplication is 4,409,423 bytes. Every compressed payload was decoded and checked byte-for-byte. These are Python zlib6 size measurements, not timings or proof of LÖVE compression performance.

## Proposed smallest complete format change

Use append-only **v2 framed segments** with an optional injected compressor and an exact snapshot reference. Retain every logical event and its advice/action/context. Compress each frame independently so recovery never needs the last successful frame of a previous file. Do not add general JSON deltas initially: references and independent full snapshots capture the demonstrated repeated payload with a simpler exact reader.

Each logical event frame contains the full existing event envelope and context, replacing only `context.snapshot` with a segment-local reference. If this snapshot differs from the immediately preceding stored public snapshot, the frame also contains its complete canonical public JSON bytes and SHA256. Otherwise it refers to that exact prior snapshot. Advice, action, timestamps, callback outcomes, checkpoint metadata and terminal evidence are always retained per event, even when the snapshot matches. Never deduplicate the whole event merely because its state is identical.

Only the most recent public snapshot bytes/hash need remain in memory. This is sufficient for adjacent duplicate before/after records in the observed sequence and bounds dedup memory to the existing per-event byte limit. Each new segment starts with a complete snapshot when its first event has one. No reference crosses a segment boundary. Checkpoint load or new actual run identity starts a new segment; a later identical public snapshot is not asserted to be the same save/RNG state.

Suggested frame structure: fixed magic/schema, a short canonical header carrying codec, compressed length, decoded length, monotonic logical sequence and SHA256 of the uncompressed frame, followed by exactly the declared payload bytes. Bound every decoded frame to 1 MiB and reject unknown codecs, oversized lengths, invalid hashes, missing references or non-increasing sequences. Compression is optional: raw frames use the same checks and format. Use the same known LÖVE `love.data.compress/decompress` API shape already used by checkpoint storage, behind an injectable codec for fixtures. Compression errors fail closed rather than silently dropping the event.

Append the complete frame in one product write, verify the resulting length and readback/checksum before acknowledging the record. A failed or partial append stops subsequent actions. Preserve the file and all earlier valid frames; the reader reports an explicit invalid/truncated tail without pretending the last event succeeded. Never truncate, overwrite, delete or silently repair an existing player record.

## Rotation and total resource bounds

The v1 limits currently apply per process. A new format should explicitly distinguish segment, run and collection-session limits rather than silently resetting a counter at each file:

- Rotate after a verified original terminal record, after an explicit checkpoint/new-run identity event, or at a declared segment threshold such as 2,048 logical events / 8 MiB encoded bytes. A long run can span segments with monotonic sequence continuity. A new segment is storage continuation, not a new gameplay attempt or retry allowance.
- Preserve an absolute **128 MiB total physical storage cap**, counting **both existing v1 JSONL files and all v2 files**, including failed partial tails. Moving to a new folder must not reset the budget. Existing logs are never deleted automatically.
- Preserve a bounded combined file-count limit (currently 4,096). Segment names must be collision-safe and previously unused. File enumeration and metadata verification should remain bounded; inconsistent metadata fails explicitly.
- Bound the overall explicit collection session by its existing run/action/time limits. If an independent logical-event cap is retained, derive and document it against the configured maximum actions/runs plus control-event overhead; a per-segment reset must not masquerade as a renewed whole-session cap.
- Keep decoded per-event and structure/string limits. Physical compression must not permit unbounded decompression or retained Lua objects. Log progress/status should show actual used physical bytes, active segment and the reason recording stops.

A terminal segment boundary is authorized only by the controller's already verified result, never by `GAME.won` alone. Manual checkpoint/report counts remain in their separate persistent journal and are unchanged. Rotation does not perform save, load, restart or action execution. The existing session is still stopped if logging cannot preserve the next event.

## Required complete reader and validation

Ship a read-only decoder with the writer. It must reconstruct the original logical event shape exactly, resolve only prior same-segment snapshot references, verify each frame, and preserve callback-attempt versus observed-state versus terminal distinctions. Supporting both v1 and v2 in the analysis tool avoids stranding historical logs. The analysis import may report a damaged tail but must not omit it from storage accounting or infer its missing event.

Meaningful synthetic fixtures should cover raw/compressed exact round trips, changed advice on an identical snapshot, concealed-card redaction before deduplication, same public snapshot after checkpoint replacement, independent decoding of later segments, forced event/byte rotation, sequence continuity, v1+v2 combined quota, file-count exhaustion, compression/decompression/hash errors, partial append/readback failures, and restart initialization with no automatic active-session restoration. Verify both on-disk and decoded bounds, preserving all test evidence. A captured C01 serialization fixture can compare every reconstructed event to its input without running its policy or game.

The new format should be judged on actual measured bytes and ordinary codec/writer/reader tests first. Any later complete source attempt or live user session supplies separate evidence; compression, passing tests or a longer log cannot be reported as improved win odds or achievement completion.
