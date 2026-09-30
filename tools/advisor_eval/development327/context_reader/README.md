# Compact public-log inspection

`tools/advisor_eval/inspect_player_log.py` builds a bounded index from explicit stable copies of public observation logs. It reuses the existing validating decoder and timing analyzer; it never discovers log directories or accesses game state, saves, profiles, or the executable. This is tooling and does not change runtime policy.

Default output is valid JSON of at most 16 KiB. Every retained table records its total row count and omitted row count. Large snapshots, fingerprints, before/after states, and error payloads stay in the originals. The index includes event/action counts, reported terminal labels without win inference, error signals, timing receipts, precise inter-event gaps without claiming those are freezes, field sizes, repeated canonical snapshots, and exact event locators. Canonical field value sizes overlap parents; the `count` in that named size table means canonical value bytes. A repeated public snapshot does not establish redundant advisor work or identical hidden RNG.

Example (use actual explicit captured paths):

```powershell
python tools/advisor_eval/inspect_player_log.py inspect captured.brj --output new-summary.json
python tools/advisor_eval/inspect_player_log.py extract captured.brj --input-sha256 FILE_SHA256 --ordinal 123 --output new-event.jsonl
```

Exact extraction requires the full input hash, replays and validates the archive, and writes the selected original JSONL bytes to a new file. The receipt printed to stdout contains hashes and ordinals only. No input or prior output is overwritten. Extraction permits invalid timing semantics for diagnosis if the original JSON/archive integrity still validates. It declines a corrupt or incomplete archive, wrong input hash, absent/duplicate selection, or exceeded input/output cap. It does not silently skip failed records. At most 16 selected events and 4 MiB are written.

`captured_tail_report.json` indexes only root's already-captured stable segments 000011–000014, not the entire session. All 1,071 selected events parsed: 172,716,754 expanded bytes became a 16,001-byte inspection index, with 164 table rows explicitly omitted. The index is not a lossless replacement. Four input hashes and per-event locators remain. There are 755 snapshot observations, 202 distinct canonical snapshots and 553 repeated observations; their repeated canonical value size is 50,951,382 bytes. The selected subset contains one reported loss label and no reported win. Other previously audited outcomes are outside this subset. No new live data was read; originals and captured copies remain unchanged.

The successful copied-tail inspection took 6.5601106 seconds in the command tool, within the root's existing bounded offline analysis scope. Per-file and cumulative stored caps were 16 MiB, four files, 12,000 events, 256 MiB expanded bytes and 12 examples. No source, search, captured gameplay simulation, or complete-attempt authority was consumed or renewed.

Manufactured tests cover bounded summaries/omissions, field and snapshot counts, exact locators, shared existing timing validation, misleading won flags, callback failure signals, independent clocks, compressed snapshot-reference extraction, exact whitespace/Unicode, integrity failures, exclusive output, cap failures, and diagnostic extraction of invalid timing semantics.
