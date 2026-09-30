"""Consolidate immutable completed evidence; no source/policy imports or execution."""
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import math

from paired_source_audit import BASE, ROOT, load, observed_changes, pick, sha

HERE = Path(__file__).resolve().parent
JOBS = ('C01', 'C02', 'C03', 'C04', 'C05', 'C06')
PUBLIC_EFFECTS = {
    'P01': 'Same four-card discard; restores the complete8-world remaining-blind comparison: modeled5/8clears versus3/8play-first. Scores71701→91318. Those samples are not win probabilities.',
    'P02': 'Leave-shop fallback changes to affordable Sly sale then Blueprint purchase; cash52→53→43, calls49956→40320. The selected endpoint evidence was omitted in329; do not reconstruct it from the original-row readiness.',
    'P03': 'Retains Perkeo with ordinary and Negative Mercury instead of selling it for Blueprint; calls16568→11336. No terminal rescue demonstrated.',
    'P04': 'Same Sly-to-Blueprint action and40320calls in329/330; complete existing endpoint evidence is now forwarded without added scoring. This does not retroactively repair P02 evidence.',
}


def ref(path):
    path = Path(path)
    return {'path': path.resolve().relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def verify_job(folder):
    record = load(folder / 'record.json')
    registration = load(folder / 'registration.json')
    assert record['one_use_spent'] and record['worker_reaped']
    assert record.get('stdout_drain_completed', True)
    assert record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert not record['verification_errors']
    assert record['registration_sha256'] == sha(folder / 'registration.json')
    for name, expected in registration['files'].items():
        assert sha(folder / name) == expected, (folder.name, name)
    for name, expected in registration['external_files'].items():
        assert sha(name) == expected, name
    trace = folder / record.get('trace_path', 'trace.log')
    assert sha(trace) == record['trace_sha256']
    return registration, record


def main():
    closure = load(BASE / 'CLOSED.json')
    budget = load(BASE / 'FINAL_BUDGET_332.json')
    assert closure['status'] == budget['status'] == 'CLOSED'
    assert budget['closure_receipt']['sha256'] == sha(BASE / 'CLOSED.json')
    assert closure['remaining_authority_seconds'] == 0 and closure['unused_slots_closed'] == ['P05', 'P06']
    attempts = []
    graphs = {}
    score_counts = Counter()
    source_seconds = 0
    for job in JOBS:
        folder = BASE / job
        registration, record = verify_job(folder)
        audit = load(folder / 'audit.json')
        assert audit['record_sha256'] == sha(folder / 'record.json')
        assert audit['registration_sha256'] == sha(folder / 'registration.json')
        assert audit['trace_sha256'] == record['trace_sha256']
        assert audit['worker_seconds'] == record['elapsed_seconds']
        assert audit['reserved_seconds'] == record['timeout_seconds'] == 180
        metadata = registration['metadata']
        digest = metadata['policy_digest']
        graph = {name[7:]: value for name, value in registration['files'].items() if name.startswith('policy/')}
        if digest in graphs:
            assert graphs[digest] == graph
        graphs[digest] = graph
        assert len(graph) == 94
        score_counts.update(audit['score_scopes'])
        source_seconds += record['elapsed_seconds']
        profiles = audit['profiles']
        last = audit.get('terminal_context') or audit.get('last_started_state')
        plays = []
        for action in audit['actions']:
            if (action.get('action') or {}).get('kind') != 'play':
                continue
            state = action.get('state') or {}
            resolved = action.get('resolved') or {}
            plays.append({'step': action['step'], 'state': pick(state, ['ante', 'round', 'chips', 'hands_left', 'discards_left', 'blind']),
                          'action': action['action'], 'prediction': pick(action, ['expected_score', 'score_bound', 'score_prediction']),
                          'score_check': action.get('score_check'), 'resolved': resolved})
        if audit['outcome'] == 'loss':
            assert audit['terminal_consistency'] is True
            terminal = audit['terminal']
            assert terminal['game_over'] is True and terminal['source_game_won'] is False
            assert terminal['source_profile_completed'] is False
        attempts.append({
            'job': job, 'seed': audit['seed'], 'checkpoint': metadata['checkpoint'], 'version': metadata['installed_version'],
            'policy_digest': digest, 'canonical_audited_outcome': audit['outcome'], 'worker_status': record['status'],
            'worker_seconds': record['elapsed_seconds'], 'reserved_seconds': 180,
            'decisions_with_recorded_profiles': len(profiles), 'decisions_started': audit['decisions'],
            'actions_issued': len(audit['actions']), 'actions_resolved': audit['resolved_actions'],
            'last_observed_state': last, 'terminal': audit.get('terminal'), 'terminal_consistency': audit['terminal_consistency'],
            'stops': audit['stops'], 'information_gaps': audit['information_gaps'], 'errors': audit['errors'],
            'unparsed_lines': audit['unparsed_lines'], 'event_counts': audit['counts'],
            'score_checks': audit['score_scopes'], 'plays': plays,
            'selected_action_legality': {'illegal_action_events': audit['counts'].get('engine_episode_illegal_action', 0),
                                       'resolved_actions': audit['resolved_actions'],
                                       'scope': 'Recorded dispatched/resolved selected actions only; whole adapter and all unselected choices are not qualified.'},
            'observed_ownership_changes': observed_changes(audit),
            'observed_profile_totals': {'score_calls': sum(p.get('score_calls', 0) for p in profiles),
                                       'advisor_seconds': sum(p.get('advisor_seconds', 0) for p in profiles),
                                       'snapshot_seconds': sum(p.get('snapshot_seconds', 0) for p in profiles),
                                       'scope': 'Sums of emitted completed profile rows, not unrecorded work or end-to-end live game time.'},
            'provenance': {'audit': ref(folder / 'audit.json'), 'record': ref(folder / 'record.json'),
                           'registration': ref(folder / 'registration.json'), 'spent': ref(folder / 'spent.json'),
                           'trace': ref(folder / record.get('trace_path', 'trace.log')),
                           'trace_format': record.get('trace_format', 'raw'), 'trace_bytes': record['trace_bytes'],
                           'decoded_trace_bytes': record.get('decoded_trace_bytes', record['trace_bytes']),
                           'decoded_trace_sha256': record.get('decoded_trace_sha256', record['trace_sha256']),
                           'stdout_capture_complete': record.get('stdout_capture_complete'),
                           'stdout_capture_scope': record.get('stdout_capture_scope', 'legacy_raw_trace'),
                           'decoded_verification': audit.get('decoded_verification'),
                           'external_source_runtime_files': registration['external_files'],
                           'frozen_nonpolicy_files': {name: value for name, value in registration['files'].items() if not name.startswith('policy/')},
                           'profile_specification': load(folder / 'profile_specs.json'),
                           'opening_recipe': ref(folder / 'normal_opening_recipe.json'),
                           'installed_record': ref(folder / 'installed_policy_record.json'),
                           'all_registered_files_rechecked': True, 'all_external_hashes_rechecked': True},
            'registered_metadata': metadata,
            'comparison_role_limit': 'C05 is a prospective dependent follow-up to already-spent C02.' if job == 'C05' else
                                     'C06 is a single candidate; its prepared original C05 baseline was superseded before registration and never run.' if job == 'C06' else
                                     'Member of the registered C01/C02 or C03/C04 dependent development pair.',
        })
    public = []
    public_seconds = 0
    for job, effect in PUBLIC_EFFECTS.items():
        folder = BASE / job
        registration, record = verify_job(folder)
        comparison = load(folder / 'comparison.json')
        assert comparison['status'] == 'complete' and comparison['source_execution'] is False
        assert comparison['terminal_evidence'] is False
        endpoints = {}
        for role in ('baseline', 'candidate'):
            summary = load(folder / (role + '_summary.json'))
            assert summary['input_unchanged'] is True
            endpoints[role] = pick(summary, ['action', 'score_calls', 'policy_digest', 'input_unchanged', 'public_input_gaps'])
            endpoints[role]['summary'] = ref(folder / (role + '_summary.json'))
            endpoints[role]['full_result'] = ref(folder / (role + '_result.json'))
        public_seconds += record['elapsed_seconds']
        public.append({'job': job, 'effect': effect, 'endpoints': endpoints,
                       'comparison': ref(folder / 'comparison.json'), 'record': ref(folder / 'record.json'),
                       'registration': ref(folder / 'registration.json'), 'input_sha256': comparison['input_sha256'],
                       'worker_seconds': record['elapsed_seconds'], 'reserved_seconds': 30,
                       'source_execution': False, 'terminal_evidence': False})
    counts = Counter(attempt['canonical_audited_outcome'] for attempt in attempts)
    expected = {'win': 0, 'loss': 3, 'error': 1, 'timeout': 1, 'unsupported': 1, 'censored': 0}
    assert {key: counts.get(key, 0) for key in expected} == expected
    assert all(closure['complete_attempt_outcomes'][key] == value for key, value in expected.items())
    assert math.isclose(source_seconds + public_seconds, closure['actual_worker_seconds'], abs_tol=1e-8)
    assert closure['reserved_worker_seconds'] == 6 * 180 + 4 * 30 == 1200
    evidence = {
        'pair_C01_C02': ref(BASE / 'paired_C01_C02_audit_v2.json'),
        'pair_C03_C04': ref(BASE / 'paired_C03_C04_audit.json'),
        'C03_C04_scaling': ref(BASE / 'paired_C03_C04_scaling_details.json'),
        'followup_C02_C05': ref(BASE / 'followup_C02_C05_audit.json'),
        'followup_C02_C05_note': ref(HERE / 'FOLLOWUP_SOURCE_AUDIT_C02_C05.md'),
        'C03_C04_note': ref(HERE / 'PAIRED_SOURCE_AUDIT_C03_C04.md'),
    }
    followup = load(BASE / 'followup_C02_C05_audit.json')
    result = {'schema': 1, 'kind': 'closed_fresh_loss328_final_source_evidence',
              'created_at_utc': datetime.now(timezone.utc).isoformat(), 'report_checkpoint': 332,
              'source_policy_checkpoints_tested': [327, 329, 331], 'checkpoint332_source_attempts': 0,
              'authority': ref(BASE / 'authority.json'), 'closure': ref(BASE / 'CLOSED.json'),
              'final_budget': ref(BASE / 'FINAL_BUDGET_332.json'), 'status': 'CLOSED',
              'counts': expected, 'complete_attempt_slots_spent': 6, 'public_pair_jobs_spent': 4,
              'source_seconds': source_seconds, 'public_comparison_seconds': public_seconds,
              'all_worker_seconds': closure['actual_worker_seconds'], 'reserved_seconds': 1200,
              'unused_closed_seconds': 60, 'unused_closed_slots': ['P05', 'P06'], 'remaining_authority_seconds': 0,
              'score_checks': dict(score_counts), 'policy_graphs_by_digest': graphs, 'attempts': attempts,
              'public_comparisons_only': public, 'supplementary_evidence': evidence,
              'C02_supplementary_original_trace_blocks': followup['reference']['raw_trace_blocks'],
              'next_concrete_gap': {'job': 'C05', 'shop_steps': [55, 60, 62], 'pack_step': 61,
                                   'reason': 'Nonempty shop-exit Perkeo copying is outside this Certificate family.',
                                   'source': 'Brainstorm/Advisor/certificate.lua:88',
                                   'scope': 'Needs a complete bounded joint inventory/copy/first-draw comparison, not guard removal. No source authority remains.'},
              'verified_complete_win': False, 'qualified_adapter': False, 'representative_cohort': False,
              'numerical_player_win_odds': None, 'unseen_holdout': False, 'new_experiment_jobs_in_this_audit': 0,
              'raw_fingerprint_decoding': False, 'reader': ref(Path(__file__)),
              'limits': ['All six are selected dependent synthetic-profile development attempts, including the later C05 hypothesis on the C02 seed. No representative rate, confidence interval or human-superiority inference.',
                         'All source runs use all_unlocked_discovered_v1 with synthetic_fresh_all_missing_v1:150missing/0complete. The observed player58complete/92missing objective was not imported.',
                         'C01/C03 losses, C02 error, C04 timeout, C05 loss and C06 unsupported are preserved; no imputation or completion claim.',
                         'House forecasts355.875 and323.625 in C05 are sampled expectations, actual270 and30; both remain unverified gaps, not exact scores or floors.',
                         'C06 stops before the first concealed-Joker policy decision at Ante8 Acorn. No hidden-order decision or terminal win was executed there.',
                         'Exact selected scores, supported random floors, unknown/random score gaps, selected legality and terminal consistency are separate; the entire adapter is unqualified.',
                         'C01 raw stdout versus later gzip and policy work differences prevent attributing observed timing solely to compression or policy; source time omits live animations and user actions.',
                         'No source attempt uses the new332 public activation observer. Historical batches remain separate and closed; no quota is renewed.']}
    target = BASE / 'FINAL_SOURCE_EVIDENCE_332.json'
    with target.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps({'path': str(target), 'sha256': sha(target), 'outcomes': expected,
                      'scores': dict(score_counts), 'source_seconds': source_seconds,
                      'public_seconds': public_seconds, 'total_seconds': result['all_worker_seconds']}))


if __name__ == '__main__':
    main()
