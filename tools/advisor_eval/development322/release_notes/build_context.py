"""Write detached CLOSED release322 context inputs from immutable prior evidence.

No runtime, game, player file, installed tree or current navigation is touched.
Only the existing finalizer's read-only validation/helper functions are called.
"""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CYCLE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'


def read(path: Path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ref(path: Path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def dump(path: Path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    latest_path = CYCLE / 'status321closed/context.json'
    original_path = CYCLE / 'release321final/context.json'
    closure_path = CYCLE / 'CLOSED.json'
    status_path = ROOT / 'tools/advisor_eval/SESSION_STATUS_321_CLOSED.json'
    latest, original, closure, status = map(read, (latest_path, original_path, closure_path, status_path))
    assert latest['status'] == closure['status'] == status['status'] == 'CLOSED'
    assert sha(latest_path) == status['context']['sha256']
    assert sha(closure_path) == status['evidence']['closed_cycle']['sha256'] == latest['evidence']['closed_cycle']['sha256']
    assert sha(CYCLE / 'authority.json') == closure['authority_sha256'] == original['evidence']['authority']['sha256']
    assert latest['remaining_authority_seconds'] == 0
    assert latest['C09'] == 'never_registered_reserved_or_run'
    assert closure['active_workers'] == 0 and closure['unused_capacity'] == 'closed'
    assert len(latest['jobs']) == len(closure['completed_job_records']) == latest['budget']['spent_jobs'] == 38
    records = {item['job']: item for item in closure['completed_job_records']}
    for item in latest['jobs']:
        assert records[item['job']]['record_sha256'] == item['record_sha256']
        assert records[item['job']]['registration_sha256'] == item['registration_sha256']
    decimals = json.loads(closure_path.read_text(encoding='utf-8-sig'), parse_float=Decimal)
    total = sum((item['actual_seconds'] for item in decimals['completed_job_records']), Decimal(0))
    assert str(total) == latest['budget']['actual_worker_seconds_decimal'] == '1012.71499999973457357'
    assert closure['spent_reserved_seconds'] == latest['budget']['spent_reserved_seconds'] == 2340
    assert set(closure['closed_unused_slots']) == set(latest['unused_slots_closed']) == set(latest['budget']['unused_slots'])
    assert len(closure['closed_unused_slots']) == 22 and 'C09' in closure['closed_unused_slots']
    counts = original['counts']
    assert counts == {'source_components': 18, 'captured_pair_jobs': 6, 'captured_policy_evaluations': 18,
                      'search_workers': 6, 'complete_attempts': 8}
    outcomes = dict(latest['complete_attempt_outcomes'], running=0,
                    not_started=sum(job.startswith('C') for job in closure['closed_unused_slots']))
    assert outcomes == original['complete_attempt_outcomes']
    zero = {key: 0 for key in counts}
    public_note = ROOT / 'tools/advisor_eval/development322/PUBLIC_LOG_REVIEW.md'
    public_report = ROOT / 'tools/advisor_eval/development322/public_run_report_final.json'
    limits = {
        'schema': 1, 'kind': 'release322_closed_historical_limits', 'status': 'CLOSED',
        'counts_scope': 'historical_closed_cycle', 'release_counts': zero,
        'historical_counts': counts, 'historical_complete_attempt_outcomes': outcomes,
        'original_cycle_expires_at_utc': closure['expires_at_utc'],
        'closure_written_at_utc': closure['closed_at_utc'], 'remaining_authority_seconds': 0,
        'C09': 'never_registered_reserved_or_run', 'closed_unused_slots': closure['closed_unused_slots'],
        'prior_evidence': {'latest_closed_status': ref(latest_path), 'original_release_context': ref(original_path),
                           'closed_cycle': ref(closure_path), 'current_status': ref(status_path)},
        'historical_budget': latest['budget'],
        'public_observations': {'kind': 'separate_read_only_opt_in_public_log_review_not_source_experiments',
                               'note': ref(public_note), 'report': ref(public_report)},
        'release_scope': 'Manufactured fixture/regression implementation and read-only repository/public-log analysis only. No source executable read or source/captured/search/complete evaluation. No save/profile files or live game control.',
        'limits': 'Historical C01 policy300 alone has one selected synthetic win. Later policies inherit none. No player odds, unseen holdout, general adapter qualification, current322 terminal result, verified Jokerless win or human superiority. Incomplete public-log prefixes are not source timeouts or terminal outcomes.'}
    dump(HERE / 'limits.json', limits)
    context = {
        'schema': 1, 'kind': 'checkpoint_experiment_context', 'status': 'CLOSED',
        'created_at_utc': datetime.now(timezone.utc).isoformat(), 'release': 322,
        'summary': 'Release322 introduces no new source, captured, search or complete experiment. The original gold299 cycle is CLOSED; every count below belongs to that historical cycle. This checkpoint neither reopens unused slots nor grants new authority.',
        'outcome_summary': 'Historical complete-attempt totals remain1 selected synthetic win (C01, frozen policy300 only),3 losses (C03/C05/C08),4 timeouts (C02/C04/C06/C07),0 errors,0 unsupported and0 separately labeled censored outcomes. C01 won RedGold final Cerulean Bell705600/400000 in172.14000000001397s, with225 actions/28 exact plays; its13 ordinary score-cap overruns remain preserved. C07 policy320 timed out with all163 shared C06 inputs/actions unchanged. C08 policy320 lost Ante1 Pillar592/600 with all22 C05 inputs/actions unchanged; its corrected selected-audit pointer preserves earlier audit-tool errors. Policies321 and322 have no complete-attempt result. C09 was never registered, reserved or run. Separately, the read-only loaded321 public journal review records one Ante8 Big loss277272/300000 and one continuing prefix; these are not new synthetic experiments or322 outcomes.',
        'limits_summary': 'Historical attempts are selected dependent synthetic all_unlocked_discovered_v1 development observations, not player odds, unseen holdouts, an actual achievement, general source-adapter qualification or human superiority. There is no verified complete Jokerless win or demonstrated50%/75% per-challenge target. Runtime fixtures and fixed composition/forced-card comparisons do not establish full-run speed or win improvement. The public journal declares loaded2.121, without attesting loaded hashes or animation speed; new322 activation waits for the user normal restart. Existing errors/timeouts/unsupported/censored evidence and player retry caps remain intact.',
        'budget_summary': 'The original cycle expired2026-09-14T22:40UTC and is CLOSED. Of60 original slots/5400s maximum authority,38 jobs spent2340s of registered caps and exactly1012.71499999973457357s from decimal recorded worker times (closure float1012.7149999997346). The22 unused slots, including C09 and3060s unused cap, are closed; remaining authority is zero. Original job counts are18 source components,6 captured-pair jobs/18 policy evaluations,6 search workers and8 complete attempts. Release322 adds zero to every count. No replacement, renewal, source worker, search or scheduled continuation is pending; future experiments require fresh authorization and frozen one-use provenance.',
        'counts_scope': 'historical_closed_cycle', 'counts': counts, 'release_counts': zero,
        'complete_attempt_outcomes': outcomes, 'verified_complete_win': True,
        'verified_complete_win_scope': 'historical_C01_policy300_only',
        'unused_capacity': 'closed', 'remaining_authority_seconds': 0,
        'evidence': {'authority': ref(CYCLE / 'authority.json'), 'outcomes': ref(latest_path),
                     'budget': ref(closure_path), 'limits': ref(HERE / 'limits.json')}}
    dump(HERE / 'context.json', context)
    source = ROOT / 'tools/advisor_eval/finalize_runtime_checkpoint.py'
    spec = importlib.util.spec_from_file_location('release322_context_validator', source)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    validated = module.experiment_context(HERE / 'context.json')
    session, budget = module.experiment_json(validated)
    assert session['new_experiments'] == 0 and session['complete_win'] is False
    assert session['historical_verified_complete_win'] is True
    assert all(budget[key] == 0 for key in ('new_source_components', 'captured_pair_jobs',
        'captured_policy_evaluations', 'searches', 'complete_attempts'))
    assert session['historical_counts'] == counts and budget['complete_attempt_outcomes'] == outcomes
    result = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_advisor_checkpoint_context.py'],
                            cwd=ROOT, capture_output=True, text=True, timeout=60)
    dump(HERE / 'validation.json', {'schema': 1, 'kind': 'read_only_context_validation_and_manufactured_python_tests',
        'status': 'passed' if result.returncode == 0 else 'failed', 'exit_code': result.returncode,
        'tests_output': result.stdout + result.stderr, 'context': ref(HERE / 'context.json'),
        'finalizer': ref(source), 'test': ref(ROOT / 'tests/test_advisor_checkpoint_context.py'),
        'historical_jobs': len(latest['jobs']), 'release_new_experiments': session['new_experiments'],
        'new_release_complete_win': session['complete_win'], 'historical_complete_win': session['historical_verified_complete_win']})
    if result.returncode: raise SystemExit(result.returncode)
    print(json.dumps({'status': 'inputs_ready', 'context': ref(HERE / 'context.json'),
                      'validation': ref(HERE / 'validation.json')}))


if __name__ == '__main__':
    main()
