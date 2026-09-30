# Public-log inspection integrity405

These tools read explicitly supplied stable public-log copies. They do not
discover the active game's files, execute advice, inspect saves/profiles or
classify a terminal label as a verified win. Runtime remains installed2.195
checkpoint404;405 changes analysis tooling and documentation only.

## Supplied fragments and whole sessions

`read_player_log.py:records` validates each BRJ2 file's frames, checksums,
same-segment identity, sequence and internal predecessor chain. Each file can
be decoded independently: its first predecessor may refer outside the input.
`extract` likewise verifies the selected file and its expected full-file hash
before writing exact selected events; it is not a cohort audit.

`analyze_player_timing.py` and `inspect_player_log.py inspect` aggregate supplied
files. For the same declared BRJ2 session they now require:

* Adjacent logical event sequences and nonregressing precise timestamps.
* Every supplied successor's predecessor hash equals the prior supplied frame's
  hash, including across files.
* Strictly increasing segment IDs when moving to a different supplied file.
  IDs need not differ by one: the writer can consume an empty rotation number.
  Supply original segment files; deliberately split pieces of one segment
  should be inspected independently, not merged as different original segments.

The first supplied fragment can start at a later sequence/segment with an
unknown outside predecessor. Other sessions keep independent clocks, sequence
numbers and chains, even when their files are interleaved. Legacy JSONL files
remain independent scopes because they lack the BRJ2 session/chain metadata.

The report's `archive_integrity.supplied_frame_links_validated` counts accepted
within- and cross-file links. `outside_predecessors_verified` remains false.
`complete_session_claimed` remains false even if every supplied link is valid:
an earlier prefix or final tail may be missing. A complete cohort audit still
requires an expected inventory, start/end identities and terminal evidence.
Matching hashes prove consistency of supplied bytes, not truth of gameplay
claims or authenticity of an externally modified journal.

Broken links or reused/regressed segment IDs produce an incomplete report and
nonzero CLI status before that event changes counters or timing aggregates.
Accepted-prefix evidence and the source files remain; no damaged tail is
removed. A report's prefix hash can include the bytes read to discover an
invalid record; `complete_prefix_events` separately states how many were accepted.

## Bounded usage

```powershell
python tools/advisor_eval/inspect_player_log.py inspect copied-segment-1.brj copied-segment-2.brj --output new-index.json
python tools/advisor_eval/inspect_player_log.py extract copied-segment-2.brj --input-sha256 EXPECTED_FILE_SHA256 --ordinal 12 --output new-event.jsonl
```

Use stable explicit copies and unused output paths. Existing byte/event/file
caps, timing semantics, exact extraction, bounded summary omissions and input
preservation still apply. A valid fragment report is not an invitation to run
a captured state through a policy or scorer.

## Validation and limits

`tests/test_advisor_log_integrity405.py` uses fabricated raw and compressed
BRJ2 bytes with independently constructed checksums. It covers correct and
wrong links, reused/regressed segment IDs, empty-rotation gaps, unknown earlier
predecessors, interleaved independent sessions and exclusive report creation.
Existing player-timing and inspection suites retain malformed/truncated input,
caps, JSONL independence, exact extraction and timing validation coverage.

Before repair, the corrected new fixture had three failing tests: incompatible
files were reported as parsed and the CLI returned success. Initial fixture
generator cleanup errors were corrected separately and preserved, not counted
as product defects. `development405/` contains original bytes, failure logs,
review, validation and final provenance. Current session outcomes are unaudited.
