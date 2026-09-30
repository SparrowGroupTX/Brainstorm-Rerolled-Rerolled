"""Read-only post-error audit of four preserved M10 decisions. Never executes Lua."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[5]
FOLDER = ROOT / 'tools/advisor_eval/runs/gold299_20260914/M10'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
record = json.loads((FOLDER / 'record.json').read_text())
registration = json.loads((FOLDER / 'registration.json').read_text())
results = {(role, step): json.loads((FOLDER / f'{role}_step{step}_result.json').read_text())
           for role in ('baseline300', 'candidate') for step in (138, 139)}
snapshots = {step: json.loads((FOLDER / f'step{step}.json').read_text())['snapshot'] for step in (138, 139)}
assert record['status'] == 'error' and record['one_use_spent']
assert all(sha(FOLDER / name) == expected for name, expected in registration['files'].items())


def projection(result):
    return result['result']['shop_diagnostics']['sequences']['best_by_first_action']['leave_shop::']['readiness']


def trajectories(ready):
    normalized = []
    finishing = ready['finishing']
    assert finishing['complete'] and finishing['supported'] and finishing['samples'] == 4
    assert len(finishing['policies']) == 2
    for policy in finishing['policies']:
        assert len(policy['worlds']) == 4
        normalized_worlds = []
        for world in policy['worlds']:
            setups = [action for action in world['actions'] if action['kind'] == 'reorder_jokers']
            assert len(setups) == world.get('setup_actions', 0) == ready['ordering']['action_count'] <= 1
            assert len(world['actions']) == world['hands_used'] + world['discards_used'] + len(setups)
            assert world['action_count'] == len(world['actions'])
            if setups:
                assert world['actions'][0] == setups[0] and setups[0]['projected']
                assert setups[0]['order'] == ready['ordering']['order']
            normalized_worlds.append({key: value for key, value in world.items()
                                      if key not in ('actions', 'action_count', 'setup_actions')})
            normalized_worlds[-1]['actions'] = [action for action in world['actions']
                                               if action['kind'] != 'reorder_jokers']
        assert policy['mean_setup_actions'] == ready['ordering']['action_count']
        normalized.append({'name': policy['name'], 'worlds': normalized_worlds})
    return normalized


base = [projection(results['baseline300', step]) for step in (138, 139)]
candidate = [projection(results['candidate', step]) for step in (138, 139)]
same_trajectories = trajectories(candidate[0]) == trajectories(candidate[1])
assert same_trajectories
assert candidate[0]['cumulative_mean'] == candidate[1]['cumulative_mean'] == 55104
for step in (138, 139):
    left, right = results['baseline300', step], results['candidate', step]
    assert left['input_unchanged'] and right['input_unchanged']
    assert left['input_fingerprint'] == right['input_fingerprint']
    assert left['legality_audit']['score_calls'] == right['legality_audit']['score_calls'] == 0
    assert right['score_calls'] <= 50000 and right['result']['evaluations'] <= 50000
orders = [{ 'step': step,
           'physical_ids': [snapshots[step]['jokers'][index - 1]['id'] for index in ready['ordering']['order']],
           'keys': [snapshots[step]['jokers'][index - 1]['key'] for index in ready['ordering']['order']],
           'setup_actions': ready['ordering']['action_count']}
          for step, ready in zip((138, 139), candidate)]
output = {
    'status': 'audited_error_after_four_decisions', 'job_status_remains': 'error',
    'job': 'M10', 'one_use_spent': True, 'elapsed_seconds': record['elapsed_seconds'],
    'record_sha256': sha(FOLDER / 'record.json'),
    'registration_sha256': sha(FOLDER / 'registration.json'),
    'trace_sha256': record['trace_sha256'],
    'result_sha256': {f'{role}_step{step}': sha(FOLDER / f'{role}_step{step}_result.json')
                      for role, step in results},
    'frozen_files_unchanged': True, 'source_execution': False, 'decisions_completed': 4,
    'failure': 'Preregistered exact fixed physical Joker order identity equality was false.',
    'reason': 'The bounded order family contains the current row plus target arrangements. Candidate138 selects its already useful zero-action current row; candidate139 selects a different useful one-action target arrangement. The distinct filler placements both copy Yorick and produce identical complete sampled non-setup trajectories. The identity strings correctly describe different physical rows; they are not volatile-index mismatches.',
    'candidate_orders': orders,
    'candidate_same_physical_order': False,
    'candidate_same_all_eight_nonsetup_world_trajectories': same_trajectories,
    'candidate_setup_counts_and_projected_first_actions_valid': True,
    'baseline_opening_means': [value['opening_mean'] for value in base],
    'baseline_cumulative_means': [value['cumulative_mean'] for value in base],
    'candidate_opening_means': [value['opening_mean'] for value in candidate],
    'candidate_cumulative_means': [value['cumulative_mean'] for value in candidate],
    'inputs_unchanged_same_policy_input_per_step': True,
    'decisions': [{'role': role, 'step': step, 'action': result['action'],
                   'score_calls': result['score_calls'], 'evaluations': result['result']['evaluations'],
                   'seconds': result['decision_elapsed_seconds']} for (role, step), result in results.items()],
    'interpretation': 'All four observed decisions remain usable local development evidence. The preregistered job remains failed and is not relabeled passed. No rerun, replacement, policy evaluation, extra scoring, terminal outcome, acquisition/retention, player Gold award or win-rate inference.',
}
with (FOLDER / 'audit.json').open('x') as stream:
    json.dump(output, stream, indent=2)
print(json.dumps({'status': output['status'], 'audit_sha256': sha(FOLDER / 'audit.json'),
                  'same_eight_trajectories': same_trajectories,
                  'baseline_means': output['baseline_cumulative_means'],
                  'candidate_means': output['candidate_cumulative_means'], 'candidate_orders': orders}))
