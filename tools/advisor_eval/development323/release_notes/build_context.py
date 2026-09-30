"""Build detached323 CLOSED navigation inputs; no runtime/current-doc mutation."""
from __future__ import annotations
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    previous_path = ROOT / 'tools/advisor_eval/development322/release_notes/context.json'
    previous = read(previous_path)
    assert previous['status'] == 'CLOSED' and previous['counts_scope'] == 'historical_closed_cycle'
    for binding in previous['evidence'].values():
        assert sha(ROOT / binding['path']) == binding['sha256']
    assert not any(previous['release_counts'].values()) and previous['remaining_authority_seconds'] == 0
    closure_path = ROOT / previous['evidence']['budget']['path']
    closure = read(closure_path)
    assert closure['status'] == 'CLOSED' and closure['active_workers'] == 0 and len(closure['closed_unused_slots']) == 22
    assert 'C09' in closure['closed_unused_slots']
    limits = read(ROOT / previous['evidence']['limits']['path'])
    limits['kind'] = 'release323_closed_historical_limits'
    limits['prior_evidence']['release322_context'] = ref(previous_path)
    limits['prior_evidence']['release322_final'] = ref(ROOT / 'tools/advisor_eval/runs/pace322_final/final_verification.json')
    limits['prior_evidence']['release322_reset'] = ref(ROOT / 'tools/advisor_eval/SESSION_RESET_322.json')
    limits['release_scope'] = 'Routine manufactured/regression validation and read-only repository/preserved-source audit only. Zero source/captured/search/complete jobs. No executable, game control, save/profile file, or new public-log read.'
    limits['public_observations']['reuse_only_no_new_log_read'] = True
    limits['cpu_scope'] = 'Demonstrated mechanical unnecessary drag capture, blocked observation and HUD-key invalidation paths. No live CPU percentage, latency or full-run saving measured. Fresh Gold metadata and required worker/execution checks remain.'
    limits['known_inactive_proposal'] = 'development323/journal/player_journal.lua is an untested unstaged action-time sketch; not release work or authority.'
    dump(HERE / 'limits.json', limits)
    context = dict(previous)
    context.update(release=323, created_at_utc=datetime.now(timezone.utc).isoformat())
    context['summary'] = 'Release323 introduces zero source, captured, search or complete experiments. It reduces avoidable metadata work during actual dragging and blocked auto-run frames and excludes a display-only HUD aggregate from scoring keys, using manufactured/regression validation and preserved-source read-only analysis. The original gold299 cycle remains CLOSED; its counts below are historical, not new323 jobs.'
    context['outcome_summary'] = previous['outcome_summary'].replace('Policies321 and322', 'Policies321,322 and323').replace('or322 outcomes', 'or322/323 outcomes')
    context['limits_summary'] = previous['limits_summary'].replace('new322 activation', '322/323 activation') + ' No new public journal was read for323; no actual CPU percentage, measured idle frequency or complete-run speedup is claimed. The journal action-time sketch remains an untested inactive proposal.'
    context['budget_summary'] = previous['budget_summary'].replace('Release322 adds zero', 'Release323 adds zero')
    context['evidence'] = dict(previous['evidence'], limits=ref(HERE / 'limits.json'))
    dump(HERE / 'context.json', context)
    spec = importlib.util.spec_from_file_location('release323_context_validator', ROOT / 'tools/advisor_eval/finalize_runtime_checkpoint.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    validated = module.experiment_context(HERE / 'context.json')
    session, budget = module.experiment_json(validated)
    assert session['new_experiments'] == 0 and session['complete_win'] is False
    assert session['historical_verified_complete_win'] is True
    assert session['historical_counts'] == previous['counts']
    assert all(budget[key] == 0 for key in ('new_source_components','captured_pair_jobs','captured_policy_evaluations','searches','complete_attempts'))
    dump(HERE / 'validation.json', {'schema': 1, 'kind': 'read_only_context_reference_validation', 'status': 'passed',
        'context': ref(HERE / 'context.json'), 'historical_counts': context['counts'], 'release_counts': context['release_counts'],
        'complete_attempt_outcomes': context['complete_attempt_outcomes'], 'new_experiments': 0,
        'new_release_complete_win': False, 'historical_verified_complete_win': True,
        'finalizer_main_executed': False, 'runtime_or_current_navigation_changed': False})
    print(json.dumps({'context': ref(HERE / 'context.json'), 'validation': ref(HERE / 'validation.json')}))


if __name__ == '__main__':
    main()
