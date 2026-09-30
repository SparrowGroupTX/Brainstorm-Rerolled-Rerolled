"""Summarize the fixed decoded observations; no external journal rereads."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
report=json.loads((HERE/'report.json').read_text(encoding='utf-8'))
observations=json.loads((HERE/'observations.json').read_text(encoding='utf-8'))
events=observations['events'];actions=report['actions']
terminals=[]
for event in report['terminal_or_stop_receipts']:
    if event['details']['event']!='run_finished':continue
    state=event['state'];details=event['details'];proof=details['evidence']
    terminals.append({'sequence':event['sequence'],'seed':event['seed'],'ante':state['ante'],'blind':state['blind'],
        'chips':state['chips'],'run_actions':details['run_actions'],'run_seconds':details['run_seconds'],
        'outcome':details['outcome'],'won_field':event['won_field'],
        'loss_consistent':details['outcome']=='loss' and proof.get('kind')=='loss' and proof.get('source')=='GAME_OVER'
            and proof.get('verified') is True and event['game_over'] is True and state['chips']<state['blind']['chips']
            and state['hands_left']==0})
assert len(terminals)==2 and all(t['loss_consistent'] for t in terminals)
missing=[{'sequence':a['sequence'],'seed':a['seed'],'run_action':a['run_action'],'action':a['action']}
    for a in actions if a['observed_sequence'] is None]
summary={'schema':1,'scope':'Passive public journal tail; no experiment or replay.',
    'report_path':'report.json','report_sha256':sha(HERE/'report.json'),
    'observations_sha256':sha(HERE/'observations.json'),'inputs':report['inputs'],
    'actual':report['actual'],'caps':report['caps'],'errors':report['errors'],
    'window':{'first':report['first'],'last':report['last'],'new_session_vs_prior321_review':True,
        'segments':[9,10,11,12,13,14],'earlier_segments_not_read':[1,2,3,4,5,6,7,8],
        'tail_first_event':'terminal_overlay_close_requested for preceding game:4; its terminal receipt is outside scope',
        'tail_last_event':'explicit session_stopped with run_limit'},
    'loaded_version':'Brainstorm v2.123.0-alpha','loaded_module_hashes_attested':False,
    'wall_clock_resolution':report['wall_clock_stamp_resolution'],'action_timing':report['timing'],
    'largest_action_interval':report['largest_action_intervals'][0],
    'exact_request_matches':report['request_matches'],'accepted_callbacks':report['accepted_callbacks'],
    'actions_without_observed_acknowledgment':missing,'no_missing_duration_imputed':True,
    'terminal_receipts_checked':terminals,
    'session_stopped_aggregate':{'sequence':4078,'reason':'run_limit','runs_started':5,'actions':802,
        'declared_outcomes':{'wins':1,'losses':4},
        'qualification':'Aggregate is recorded, not an independent audit of earlier excluded runs. Earlier claimed win is outside selected tail; do not count it as newly verified.'},
    'size_semantics':{'original_event_bytes':'Exact reconstructed JSONL byte length verified against recorded event SHA.',
        'wire_frame_bytes':'Exact header+stored payload+newline span in selected physical file.',
        'snapshot_json_bytes':'Approximate re-serialization with Python JSON defaults, not exact original snapshot text length.'},
    'largest_original_event':report['largest_events'][0],
    'limitations':report['limitations'],
    'comparison':'Different session, policies, seeds/routes and actions from the prior321 log window; raw interval changes do not establish release speedup or freeze causality.',
}
with (HERE/'summary.json').open('x',encoding='utf-8') as stream:json.dump(summary,stream,indent=2);stream.write('\n')
note='''# Public journal timing audit324

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
'''
with (HERE/'AUDIT.md').open('x',encoding='utf-8') as stream:stream.write(note)
names=['audit.py','finalize.py','inventory.json','observations.json','report.json','summary.json','AUDIT.md']
with (HERE/'manifest.json').open('x',encoding='utf-8') as stream:
    json.dump({'schema':1,'kind':'read_only_public_journal_analysis','files':{name:sha(HERE/name) for name in names},
        'decoder':report['decoder'],'source_workers':0,'policy_evaluations':0,'search_workers':0,
        'gameplay_actions':0,'external_input_reads':len(report['inputs'])},stream,indent=2);stream.write('\n')
print(json.dumps({'manifest_sha256':sha(HERE/'manifest.json'),'summary_sha256':sha(HERE/'summary.json'),
                 'AUDIT_sha256':sha(HERE/'AUDIT.md'),'report_sha256':sha(HERE/'report.json')},indent=2))
