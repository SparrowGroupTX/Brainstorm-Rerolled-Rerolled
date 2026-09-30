# Ready v2 player journal integration

The detached package is ready for root review/staging. No deployed runtime, user log, save, profile, DLL or retry metadata was modified. This is a runtime slice and needs the normal candidate/install/exact-installed validation and ledger sequence.

Stage these exact files:

| Draft file | Destination |
|---|---|
| `player_log_archive.lua` | `Brainstorm/Advisor/player_log_archive.lua` |
| `player_journal.lua` | `Brainstorm/Advisor/player_journal.lua` |
| `read_player_log.py` | `tools/advisor_eval/read_player_log.py` |
| `test_player_log_archive.py` | `tests/test_player_log_archive.py` |

In `Brainstorm/Advisor/runtime.lua`, immediately before loading/attaching `player_journal`, add `A.player_log_archive = module('player_log_archive')`. The existing `player_journal.attach(A,Brainstorm)` then receives that module through A. No Core/game/checkpoint control changes are required. The product defaults to zlib compression; setting `advisor.player_log_compression=false` selects raw frames. Do not overwrite the user's existing settings file or enable recording merely by installing. No new UI preference is necessary for this first coherent storage repair.

The module uses existing LÖVE APIs and no external runtime library. Current checkpoint code already uses `love.data.compress`, `decompress` and `hash`; the official [compression API](https://love2d.org/wiki/love.data.compress) accepts the container/format/raw/level arguments, and the [format documentation](https://love2d.org/wiki/CompressedDataFormat) identifies `zlib` as a supported framed DEFLATE format. The new archive chooses `love.data.compress('string','zlib',raw,6)` and matching decompression. Compression is roundtrip-checked before the write. This is source/API documentation plus injected-codec fixture evidence, not live LÖVE timing validation.

## Storage and preservation

Logical event schema1 is preserved exactly. A v2 binary frame carries the original event's SHA256 and a lossless prefix/public-snapshot/suffix representation. Adjacent duplicate public snapshots reuse the last same-segment snapshot; every timestamp, advice, action, callback result, selected index, checkpoint receipt and terminal event stays separate. Redaction occurs in the unchanged public snapshot function before hashing or storage. UTF-8 chunk boundaries are preserved for large encoded JSON strings.

Frames are individually raw or zlib compressed, with bounded explicit lengths and hashes. Every accepted append verifies file length and exact byte readback using bounded seek/read of only the appended frame. Failed/partial/corrupt writes remain on disk and stop further recording/actions; no tail is removed or repaired. A complete physically written but unacknowledged action-request record remains merely a request, never proof an action executed.

New files live in `advisor_player_log_v2`. Each segment is at most **8 MiB encoded / 2048 logical events** and each reconstructed original event remains at most **1 MiB** (plus JSONL newline). The separately bounded representation wrapper is at most3 MiB. A process can record at most **300000 logical events**, without resetting that cap on rotation. This replaces the old process-wide 2048-event/32-MiB stopping point only for the new archive path; the injected legacy append path retains the old bounds for compatibility.

The combined **128 MiB physical cap** and **4096-file cap** include every existing file in both owned v1 and v2 directories, including unknown names and damaged tails. A new directory/file/run/session never resets those totals. Directory entries and lengths are rescanned before each append for exact accounting; this is bounded by the file cap, though its cost with many files should be measured separately. Current segment size changes outside this writer fail explicitly. No old log is deleted, compacted or rewritten.

Segments rotate on actual GAME/profile table identity changes, after checkpoint events, after an authenticated auto-run `run_finished` event, and at segment limits. Logical sequence and frame predecessor hashes continue across those boundaries. A new segment has its own complete initial snapshot and can be decoded independently. Rotation does not start a run, restore a save, grant a retry, renew an experiment lease or alter checkpoint journals. Recording failure remains a stop condition for auto-run.

## Reader and audit

`python -B tools/advisor_eval/read_player_log.py <files in order> --output <new-file.jsonl>` produces exact ordinary JSONL records for standard tools. It accepts old v1 JSONL and new v2 `.brj` files. Input files are read-only; an existing output is never overwritten. On invalid/truncated data, valid records already emitted and the damaged input are preserved, with an explicit error and nonzero exit.

The reader enforces per-frame checksum/length/codec, original-event checksum, bounded decompression, same-segment snapshot references, within-segment sequence and predecessor continuity. It does not infer missing earlier segments when decoding a selected fragment: original logical sequence numbers and predecessor metadata remain available through its `records()` API. Complete cross-file cohort auditing must require the expected segment inventory/order; successful fragment decoding is not a claim the whole session is present.

## Validation

`test_archive.py` passed **15 tests** using the actual draft Lua writer/journal, fake filesystem, injected SHA256/Python zlib and the exact decoder. Coverage includes compressed/raw roundtrip, changed advice on an identical snapshot, event/byte/run/profile/checkpoint rotation, independent later-segment decoding, old-v1 plus new total/file limits, partial and same-length corrupt appends, readback failure, externally changed segment size, restart collision avoidance, nonrenewing process count, large UTF-8 chunks, bounded decompression/hash/reference failures, concealed identity redaction and actual journal callback/settled-state linkage. `test_player_log_archive.py` is the integration-ready equivalent with deployed module/tool paths and a self-contained exact Lua-literal helper.

The original player-journal fixture was run against the detached new journal and passed **21 checks**, preserving existing opt-in, callback arguments/return tuples, failure and concealment behavior.

`c01_roundtrip_report.json` separately verifies all225 preserved C01 public snapshots under an explicit four-envelope-per-snapshot serialization scenario: **900 original events**, **76190036 raw JSONL bytes**, reconstructed byte-for-byte from **1792346 physical bytes in one segment**. No policy, game source, RNG, original-source worker or player files were accessed for it. These are selected synthetic C01 storage observations, not actual player events, live codec throughput, future storage forecasts or evidence of better win odds.

After staging, run the new deployed-path Python test and ordinary relevant Lua/regression checks, freeze/install exact bytes, and retain earlier sizing/report evidence. The reader is tooling-only and need not be copied into the game installation; the two Advisor modules and runtime wiring do.
