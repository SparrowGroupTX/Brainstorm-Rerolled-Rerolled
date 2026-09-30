"""Read-only audit of a prospective follow-up against an already-spent reference."""
import argparse
import json
from pathlib import Path

from paired_source_audit import BASE, first_divergence, load, role_report, sha, trace_index

SAME_METADATA = ('seed', 'deck', 'stake', 'maximum_actions', 'outer_seconds', 'profile',
                 'gold_objective_context', 'retry_context', 'information_scope',
                 'unlock_profile_spec_digest', 'gold_objective_spec_digest',
                 'retry_context_spec_digest', 'synthetic_gold_missing', 'stdout_capture')
SAME_ADAPTER = ('engine_probe.py', 'engine_probe.lua', 'engine_run.lua', 'engine_contract.lua',
                'opening_support.py', 'benchmark.py', 'normal_recipe.py', 'normal_terminal.lua',
                'gold_objective_spec.py', 'gold_objective_context.lua', 'policy_wiring.lua',
                'information_scope.lua', 'run_attempt.py', 'normal_opening_recipe.json',
                'normal_seed_selection.json', 'opening_public_observation.json', 'profile_specs.json')


def verify_followup(reference_name, candidate_name, reference, candidate, reference_hashes):
    before = reference['metadata']
    after = candidate['metadata']
    assert after['comparison_design'] == 'prospective_followup_using_already_spent_dependent_reference'
    assert after['comparison_role'] == 'followup_candidate'
    assert after['prior_comparison_job'] == reference_name and candidate['job'] == candidate_name
    assert after['fresh_reciprocal_pair'] is False
    assert not any(key in after for key in ('pair_id', 'pair_role', 'paired_job'))
    assert after['prior_comparison_policy_digest'] == before['policy_digest']
    for key, expected in reference_hashes.items():
        assert after['prior_comparison_' + key + '_sha256'] == expected, key
    for key in SAME_METADATA:
        assert before[key] == after[key], key
    assert reference['external_files'] == candidate['external_files']
    assert reference['authority_sha256'] == candidate['authority_sha256']
    assert reference['timeout_seconds'] == candidate['timeout_seconds'] == 180
    for name in SAME_ADAPTER:
        assert reference['files'][name] == candidate['files'][name], name
    changed = {name[7:]: {'prior_sha256': reference['files'].get(name), 'candidate_sha256': value}
               for name, value in candidate['files'].items() if name.startswith('policy/')
               and reference['files'].get(name) != value}
    assert changed == after['changed_policy_files']
    assert set(name for name in reference['files'] if name.startswith('policy/')) == set(
        name for name in candidate['files'] if name.startswith('policy/'))
    return {'same_source_runtime_hashes': True, 'same_adapter_and_recipe_hashes': True,
            'same_declared_profile_and_caps': True, 'changed_policy_files': changed}


def report(reference_name, candidate_name):
    before_folder = BASE / reference_name
    after_folder = BASE / candidate_name
    before_reg = load(before_folder / 'registration.json')
    after_reg = load(after_folder / 'registration.json')
    hashes = {name: sha(before_folder / (name + '.json')) for name in ('registration', 'record', 'audit')}
    design = verify_followup(reference_name, candidate_name, before_reg, after_reg, hashes)
    before_audit = load(before_folder / 'audit.json')
    after_audit = load(after_folder / 'audit.json')
    assert before_audit['outcome'] == after_reg['metadata']['prior_comparison_outcome']
    before_trace = trace_index(before_folder, load(before_folder / 'record.json'))
    after_trace = trace_index(after_folder, load(after_folder / 'record.json'))
    boundary = first_divergence(before_trace, after_trace)
    common_prefix = boundary.get('aligned_action_prefix', [])
    stopped_boundary = None
    if boundary['status'] == 'matched_public_state_missing_action':
        step = boundary['step']
        before_step = before_trace['steps'][step]
        after_step = after_trace['steps'][step]
        if 'action' not in before_step and 'action' in after_step:
            stopped_boundary = {'step': step, 'public_sha256': before_step['public_sha256'],
                  'state': before_step['state'], 'reference_action': None,
                  'followup_action': after_step['action'], 'followup_resolved': after_step.get('resolved'),
                  'scope': 'A machine action is present at the exact shared public state where the reference had none. This is not a terminal rescue or proof of an optimal move.'}
    return {'schema': 1, 'kind': 'dependent_reference_followup_readonly_audit',
            'reference': role_report(before_folder, before_audit, before_trace),
            'followup': role_report(after_folder, after_audit, after_trace),
            'prospective_design_verification': design, 'public_prefix_comparison': boundary,
            'aligned_prior_action_count': len(common_prefix), 'reference_stopped_boundary': stopped_boundary,
            'fresh_reciprocal_pair': False, 'reference_selected_before_followup_hypothesis': True,
            'new_source_or_policy_executions': 0, 'new_experiment_jobs': 0, 'raw_fingerprint_decoding': False,
            'reader_sha256': sha(Path(__file__)),
            'public_projection_and_reader_sha256': sha(Path(__file__).with_name('paired_source_audit.py')),
            'limits': ['This follow-up was prospectively registered after the reference error; it is dependent development evidence, not a fresh reciprocal pair or holdout.',
                       'Public-prefix alignment is not hidden RNG/save equivalence; later progress and local legality do not establish optimality or a terminal win.',
                       'Both attempts use a synthetic all-unlocked/discovered profile with all150 Gold Jokers missing, not the actual player profile.',
                       'Preserve recorded errors, timeouts, unsupported/censored outcomes and score gaps. The whole adapter remains unqualified.',
                       'No numerical player win rate, confidence interval, achievement completion or human superiority follows from this selected comparison.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference')
    parser.add_argument('followup')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = report(args.reference, args.followup)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps({'output': str(args.output), 'sha256': sha(args.output),
                      'reference': result['reference']['outcome'], 'followup': result['followup']['outcome'],
                      'aligned_actions': result['aligned_prior_action_count'],
                      'boundary': result['reference_stopped_boundary']}))
