"""Read-only audit of the already spent P01 public-state comparison."""
from pathlib import Path
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
JOB = ROOT / 'tools/advisor_eval/runs/loss328_validation_20260915/P01'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}

registration, record, comparison = [read(JOB / name) for name in ('registration.json', 'record.json', 'comparison.json')]
snapshot = read(JOB / 'snapshot.json')
origin, spent = read(JOB / 'input_provenance.json'), read(JOB / 'spent.json')
checks = []
def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)

check(record['status'] == 'complete' and record['exit_code'] == 0 and record['worker_reaped'], 'worker completed and was reaped')
check(record['elapsed_seconds'] <= record['timeout_seconds'] == 30, 'shared worker wall cap complied')
check(record['one_use_spent'] and spent['one_use'], 'one-use receipt remains spent')
check(record['registration_sha256'] == sha(JOB / 'registration.json') == spent['registration_sha256'], 'registration hashes match')
check(record['trace_sha256'] == sha(JOB / 'trace.log'), 'trace hash matches')
check(all(sha(JOB / name) == expected for name, expected in registration['files'].items()), 'all frozen file hashes unchanged')
check(all(sha(Path(name)) == expected for name, expected in registration['external_files'].items()), 'registered runtime hashes unchanged')
check(origin['raw_fingerprint_used'] is False and origin['sequence'] == 2722, 'input is exact declared redacted public event')
check(origin['snapshot_sha256'] == sha(JOB / 'snapshot.json') == comparison['input_sha256'], 'input hash matches source provenance and pair')
check(snapshot['phase'] == 'hand' and 'shop_forecast' not in snapshot, 'missing public shop forecast remains missing in hand input')
check(snapshot['hand'][3]['seal'] == 'Purple', 'retained card index4 is Purple')

roles = {}
for role in ('baseline', 'candidate'):
    evidence = read(JOB / (role + '_result.json'))
    summary = read(JOB / (role + '_summary.json'))
    full = evidence['full_result']
    check(summary['status'] == 'complete' and summary['input_unchanged'], role + ' completed on unchanged input')
    check(summary['evidence_sha256'] == sha(JOB / (role + '_result.json')), role + ' full evidence hash matches')
    check(summary['full_result_status'] == 'preserved', role + ' full result preserved despite summary omissions')
    check(summary['input_sha256'] == comparison['input_sha256'], role + ' same exact input')
    check(summary['score_calls'] == full['evaluations'] <= 140000, role + ' actual/reported scores agree within ordinary cap')
    check(summary['action'] == full['action'], role + ' summary preserves full selected action')
    check(summary['wiring']['retry_enabled'] is False, role + ' retries disabled')
    check(len(summary['wiring']['modules']) == 49 and len(summary['wiring']['connections']) == 34, role + ' exact verifier module/identity-edge receipt')
    check(full['discard_comparison_complete'] and not full['truncated'], role + ' complete ordinary discard comparison')
    check(all(4 not in row['indices'] for row in full['discard_alternatives']), role + ' selected Purple alternatives excluded')
    roles[role] = {'full': full, 'summary': summary}

baseline, candidate = roles['baseline']['full'], roles['candidate']['full']
check(baseline['action'] == candidate['action'] == origin['recorded_action'], 'both frozen policies retain recorded discard')
check('resource_comparison' not in baseline, 'baseline has no remaining-blind comparison')
check('Purple Seal' in baseline['search_diagnostics']['continuation_skipped'], 'baseline rejection matches observed blocker')
check('continuation_skipped' not in candidate['search_diagnostics'], 'candidate removes blanket retained-Purple rejection')
resources = candidate['resource_comparison']
check(resources['samples'] == 8 and resources['horizon'] == 4 and resources['full_remaining_horizon'], 'candidate completes eight worlds over four hands')
check(resources['future_discards'] is False, 'future discard omission stays explicit')
rows = {}
for label in ('play', 'prior_discard', 'prior', 'best'):
    branch = resources[label]; worlds = branch['worlds']
    check(len(worlds) == 8, label + ' has eight world receipts')
    wins = sum(world['win'] for world in worlds)
    check(all(world['win'] in (0, 1) and 0 <= world['score'] <= 600 and
              world['win'] == int(world['score'] >= 600) for world in worlds), label + ' world threshold consistency')
    check(math.isclose(branch['probability'], wins / 8, abs_tol=1e-12), label + ' sampled count consistent')
    check(math.isclose(branch['mean'], sum(world['score'] for world in worlds) / 8, abs_tol=1e-9), label + ' mean capped progress consistent')
    rows[label] = {'kind': branch['kind'], 'indices': branch['indices'], 'clears': wins, 'worlds': 8,
                   'mean_capped_chips': branch['mean'], 'mean_hands': branch['mean_hands'],
                   'scores': [world['score'] for world in worlds]}
check(rows['play']['clears'] == 3 and rows['prior_discard']['clears'] == 5, 'complete sample family favors incumbent discard')
check(resources['best'] == resources['prior'] == resources['prior_discard'], 'selected branch retains incumbent')
check(baseline['discard'] == candidate['discard'], 'one-draw incumbent evidence unchanged')
check(sum(r['summary']['score_calls'] for r in roles.values()) == comparison['score_calls'] == 163019, 'aggregate score receipt consistent')

audit = {'schema': 1, 'kind': 'read_only_completed_public_pair_audit', 'job': 'P01', 'status': 'pass',
         'checks': checks, 'input_sequence': 2722, 'phase': 'hand', 'record': ref(JOB / 'record.json'),
         'registration': ref(JOB / 'registration.json'), 'comparison': ref(JOB / 'comparison.json'),
         'input': ref(JOB / 'snapshot.json'), 'input_provenance': ref(JOB / 'input_provenance.json'),
         'results': {role: {'full': ref(JOB / (role + '_result.json')), 'summary': ref(JOB / (role + '_summary.json')),
                           'score_calls': value['summary']['score_calls'],
                           'decision_wall_seconds': value['summary']['decision_wall_seconds'],
                           'decision_cpu_seconds': value['summary']['decision_cpu_seconds'],
                           'policy_digest': value['summary']['policy_digest'],
                           'summary_omissions': value['summary']['omissions']}
                     for role, value in roles.items()},
         'action': candidate['action'], 'actions_unchanged': True, 'branch_comparison': rows,
         'candidate_additional_score_calls': 19617, 'worker_seconds': record['elapsed_seconds'],
         'score_cap_each': 140000, 'score_cap_total': 280000,
         'input_gaps': roles['candidate']['summary']['public_input_gaps'],
         'interpretation': 'The repair restores a complete remaining-blind comparison but retains the same observed discard. This P01 result does not fix the observed terminal loss.',
         'limitations': ['Eight paired composition samples are not a calibrated win probability.',
                        'No future discards are searched in this four-hand family.',
                        'Only the first captured Pillar discard was evaluated; later decisions and terminal outcome were not executed.',
                        'Public shop_forecast is absent and was not reconstructed; hand/deck/objective inputs are present.',
                        'This read-only audit performs zero policy/source execution and consumes no further experiment slot.']}
with (HERE / 'P01_audit.json').open('x', encoding='utf-8') as stream:
    json.dump(audit, stream, indent=2)
print(json.dumps({'status': audit['status'], 'checks': len(checks), 'actions_unchanged': True,
                  'play_clears': 3, 'discard_clears': 5, 'worlds': 8, 'audit_sha256': sha(HERE / 'P01_audit.json')}))
