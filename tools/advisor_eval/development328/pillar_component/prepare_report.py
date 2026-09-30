"""Read preserved redacted trace and current detached component files only."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[4]
out = Path(__file__).resolve().parent
trace = root / 'tools/advisor_eval/development328/public_trace/run3.json'
events = json.loads(trace.read_text())['events']
selected = {e['sequence']: e for e in events if e['sequence'] in (2662, 2668, 2673, 2700, 2722, 2727, 2732, 2758)}
rows = []
for seq, event in selected.items():
    state = event['state']
    action = event.get('advice', {}).get('action') or {}
    indices = action.get('indices') or []
    yorick = next((j for j in state.get('jokers', []) if j.get('key') == 'j_yorick'), {})
    purple = [{'index': i + 1, 'id': c.get('id'), 'rank': c.get('rank'), 'suit': c.get('suit'),
               'selected': i + 1 in indices} for i, c in enumerate(state.get('hand', [])) if c.get('seal') == 'Purple']
    rows.append({'sequence': seq, 'event_sha256': event['event_sha256'], 'snapshot': event['snapshot'],
                 'kind': event['kind'], 'action': action, 'chips': state.get('chips'),
                 'yorick_remaining': yorick.get('ability', {}).get('yorick_discards'),
                 'yorick_x_mult': yorick.get('ability', {}).get('x_mult'), 'purple': purple,
                 'continuation_warnings': [v for v in event.get('advice', {}).get('lines', [])
                                           if isinstance(v, str) and ('Purple' in v or 'Remaining-blind' in v)]})
files = {
    'Brainstorm/Advisor/search.lua': ('search_before.lua', 'search.lua'),
    'tests/advisor_discard_search.lua': ('advisor_discard_search_before.lua', 'advisor_discard_search.lua'),
    'tests/advisor_purple_continuation.lua': (None, 'test_purple_continuation.lua'),
}
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {'schema': 1, 'root_edits': False, 'files': {}}
for destination, (before, candidate) in files.items():
    manifest['files'][destination] = {'before_sha256': sha(out / before) if before else None,
                                      'candidate': candidate, 'candidate_sha256': sha(out / candidate)}
report = {'schema': 1, 'trace': str(trace.relative_to(root)), 'trace_sha256': sha(trace), 'rows': rows,
          'finding': 'An active retained Purple card globally disabled exact remaining-blind comparisons, although only selected discarded Purple cards can require Tarot generation and the continuation has no later discards.',
          'repair': 'Keep global Purple blocker only without exact after_discard; exact candidate preparation excludes unsupported selected generation before any common-world family is admitted.',
          'manufactured_result': {'prior_action': 'discard', 'candidate_action': 'play', 'target': 800,
                                  'complete_worlds': 8, 'play_clears': 8, 'discard_clears': 0, 'evaluations': 1233,
                                  'hard_cap': 140000, 'counterfactual_claim': 'Manufactured composition, not observed Pillar replay or rescued run.'},
          'validation': {'detached_fixture_checks': 38, 'production_fixture_checks': 36,
                         'related_checks': {'discard_search': 13, 'resource_decisions': 199, 'resource_guard': 45, 'discard_state': 70}},
          'limits': ['No captured-policy evaluation or source/game execution.', 'No complete-attempt result or win-rate improvement.',
                     'Future discard decisions remain omitted; all prior resource overrides, hard caps and complete-family requirements remain.',
                     'Certificate versus Card Sharp pack choice and multi-discard Yorick thresholds are not repaired by this slice.']}
for name, data in [('integration_manifest.json', manifest), ('report.json', report)]:
    with (out / name).open('x', encoding='utf-8') as stream:
        json.dump(data, stream, indent=2)
print(json.dumps({'files': len(files), 'events': len(rows), 'manifest_sha256': sha(out / 'integration_manifest.json')}))
