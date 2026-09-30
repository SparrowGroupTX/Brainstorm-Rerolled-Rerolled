# Public journal timing audit324

The newest selected journal declares **Brainstorm v2.123.0-alpha**. Its largest matched action-to-fresh-advice interval is **10.033 seconds**, after opening a Jumbo Arcana Pack. These records establish a delay, but cannot isolate whether animation, advisor work, logging, scheduling or another cause accounts for it. They do not establish a whole-game freeze or a measured release speedup.

The read covered the contiguous tail of session `session-20260915T062915Z-1`, segments9–14, sequence2560–4078, **06:46:17–06:56:24UTC on September15** (01:46:17–01:56:24CDT). It contains1,519 events:14,440,402 physical bytes and280,567,235 reconstructed JSONL bytes, parsed in4.375seconds. Limits were6files,32MiB physical,512MiB reconstructed,6,000events and50seconds. Every selected frame/event checksum, within-file chain and cross-segment sequence/chain passed; all six files were stable during their individual reads. No partial, corrupt or truncated selected frame was found. Earlier segments1–8 and the first selected frame's external predecessor were not read or independently verified. Inputs were not modified.

This is a new session/window beyond the prior loaded321 review ending05:33:18UTC. The selected tail begins after an earlier run's terminal receipt and ends with an explicit `session_stopped: run_limit`, rather than an absent final record. The version is the loaded logger's declaration, not attestation of loaded module hashes or animation speed. No save/profile file, executable, original-source archive or native worker was read or operated; there was no simulation, rescoring, replay, search or gameplay through tools.

## Timing that the records support

All1,519 wall-clock timestamps have one-second precision;1,198 adjacent pairs share a timestamp, and none go backward. These timestamps cannot resolve subsecond callback or disk-write latency. The controller's monotonic times support295 matched action-to-fresh-advice intervals among297 exact matching requests and297 accepted callbacks. The median is1.669seconds, maximum10.033seconds. The two final actions lead to terminal receipts without an action-observed acknowledgment; no missing duration is imputed.

| Recorded action | Matched intervals | Median seconds | Maximum seconds |
|---|---:|---:|---:|
| Play |56|3.824|5.465|
| Select blind |36|3.281|4.572|
| Open pack |16|1.921|10.033|
| Choose pack item |20|1.488|5.553|
| Discard |59|1.483|4.440|
| Cash out |34|1.177|4.671|
| Use consumable |15|0.681|4.524|
| Leave shop |34|0.396|0.512|

At seq3080, RH45AD21 Ante5 shop opens Jumbo Arcana for$6. The callback receipt seq3082 is in the same displayed second,06:50:22. First settled pack observation seq3083 is stamped06:50:32; fresh-advice acknowledgment seq3084 yields10.033090599999923seconds from the original attempt. This is also the largest adjacent event gap. Other gaps occur between the first settled snapshot and fresh advice, such as seq2649→2650 at4 whole seconds. A settled state therefore does not mean advice was already ready, but the gap is still not an isolated CPU measurement.

The largest reconstructed event is593,028bytes at seq3074 (`action_observed`), stored in34,891bytes. Such events retain full before/after fingerprint strings alongside public context. The entire selected tail expands from14.44MB stored to280.57MB reconstructed. This identifies a large serialization payload; it does **not** measure compression/write CPU or prove logging caused a delay. `original_event_bytes` and `wire_frame_bytes` are exact; `snapshot_json_bytes` in the detailed report is only an approximate Python re-serialization size.

## Outcomes within this tail

Two complete run receipts are available and both are consistent losses:

- RH45AD21: Ante5 Big,18,340/37,500,112actions,285.7200298999999seconds.
- YAEARC31: Ante8 Amber Acorn,98,808/400,000,185actions,318.18154389999995seconds. Its incidental `won_field=true` does not change the loss: `GAME_OVER`, zero remaining hands, unmet threshold and the explicit loss receipt agree.

The final session stop declares five runs,802actions and an aggregate1win/4losses. The earlier claimed win and other earlier terminal receipts are outside the selected tail and are **not newly verified** by this audit. Public product outcomes remain separate from all closed synthetic experiment totals; no win rate is inferred.

The existing schema lacks per-decision computation time, score-call/cap counts, frame CPU, compression/write latency and selected game-speed telemetry. Action-to-advice intervals mix those costs with animation and engine settling. The prior321 and current323 windows also use different seeds, routes and actions. They cannot establish a before/after CPU improvement or diagnose the reported freezing by themselves.

Exact paths, input hashes, bounds, integrity checks, terminal consistency and event references are in `summary.json`, with the full compact action table in `report.json` and the fixed parsed projections in `observations.json`. `inventory.json` records the metadata-only selection. No further external log reads were made to prepare this summary.
