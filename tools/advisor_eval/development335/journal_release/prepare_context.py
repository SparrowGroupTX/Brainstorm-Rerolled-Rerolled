"""Bind routine journal335 evidence and preserve the explicitly closed334 ledger.

Root runs this after candidate validation, before final binding/verification.
It writes only new component/context files, never an installation or live state.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parents[1]
ROOT = EVAL.parents[1]
COMPONENT = HERE.parent / 'runtime_component'
sys.path.insert(0, str(EVAL))
from benchmark import policy_hashes
from finalize_runtime_checkpoint import experiment_context

EXPECTED_PRIOR = 'dc26e81463a1e2cd2e2dbb233f1ab105a734b163753682f3d804c757a0298f32'
EXPECTED_FIXTURE = 'c7b5110783c3b6989f64c15ecdf4b1f82c282c6641279d432e7dee491f511c92'
EXPECTED_BASELINE = 'eae2209780c9c7d97571c123cb5988a496a9b94fcf39345934a6c5c27265699b'
EXPECTED_CANDIDATE = '1d41e9fe61ee25c4397a8a3b5ce1e598f1410c3a3f7ff5277345301e2455962e'
EXPECTED_RECEIPT = '7ff4b1303425de02561a3b8f91e5fc865e5f9e43a326df0328258089b662f0dc'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}


def exclusive(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as handle:
        handle.write(value)


def main():
    prior_path = EVAL / 'development334/release_final/context.json'
    assert sha(prior_path) == EXPECTED_PRIOR
    value = read(prior_path)
    assert value['release'] == 334 and value['status'] == 'CLOSED'
    assert value['remaining_authority_seconds'] == 0 and value['unused_capacity'] == 'closed'
    # Validate referenced CLOSED evidence without executing any of its workflows.
    experiment_context(prior_path)
    assert sha(ROOT / 'Brainstorm/Advisor/player_journal.lua') == EXPECTED_CANDIDATE
    assert sha(ROOT / 'tests/advisor_journal_reuse.lua') == EXPECTED_FIXTURE
    assert sha(ROOT / 'tests/fixtures/journal_reuse335/player_journal334.lua') == EXPECTED_BASELINE
    assert sha(COMPONENT / 'validation.json') == EXPECTED_RECEIPT
    candidate_path = EVAL / 'runs/journal335_candidate/validation/report.json'
    report = read(candidate_path)
    frozen = read(EVAL / 'runs/journal335_candidate/freeze.json')
    assert report['passed'] and report['policy_unchanged'] and report['tests_unchanged']
    assert report['policy_digest'] == frozen['policy_digest']
    assert report['policy_files'] == frozen['policy_files'] == policy_hashes(ROOT)
    assert len(report['policy_files']) == 99
    test_inventory = {key.replace('\\', '/'): expected for key, expected in report['test_files'].items()}
    for path, expected in {
        'tests/advisor_journal_reuse.lua': EXPECTED_FIXTURE,
        'tests/fixtures/journal_reuse335/player_journal334.lua': EXPECTED_BASELINE,
        'tests/fixtures/journal_reuse335/hashes.lua': sha(ROOT / 'tests/fixtures/journal_reuse335/hashes.lua'),
    }.items():
        assert test_inventory[path] == expected, 'Frozen test dependency mismatch: ' + path
    for key in ('release_validation', 'prepared_context_preserved'):
        value.pop(key, None)
    value.update(
        release=335, created_at_utc=datetime.now(timezone.utc).isoformat(),
        previous_checkpoint_context=ref(prior_path), counts_scope='historical_closed_cycle',
        release_counts={key: 0 for key in value['counts']},
        preparation_status='passed_candidate_validation_exact_installed_validation_bound_separately',
        summary='Avoid journal work whose result cannot be used. Callback request details are gathered only when recording can accept an event. A fresh public snapshot is fingerprinted for advice status only when a publication exists for the same game. Every full observation, settled-state event, callback result/error and exact runtime/autoplay invalidation gate remains intact. The prior adjacent-equivalent-consumable reduction and cooperative observer-hook repair are preserved.',
        outcome_summary='Release 335 uses manufactured fixtures and routine regression only. Its 236-check differential journal fixture preserves complete serialized event bytes and counters across nine recorder/advice states plus nested suppression, registered hooks, replacements and enable transitions. In those manufactured cases it removes nine unused request-detail collections and sixteen full fingerprints while retaining every full snapshot. The component run passes five fixtures with 443 combined checks, including unchanged journal, timing and shared-hook regressions. Full candidate and exact-installed suite totals belong to their bound receipts. Historical closed loss328 outcomes remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331; they are not 335 validation.',
        limits_summary='The saved-work counts describe manufactured callbacks and observations, not live timing. No cross-frame snapshot cache, advice/execution invalidation relaxation, retry change, scoring change, inventory change, archive-format change, event suppression or log deletion is introduced. Timing metrics continue to count actual work, so skipped fingerprints naturally remove their metric samples. Activation of the earlier 333/334 installations and restored live FPS remain unconfirmed; 335 activation likewise waits for the user normal restart. No terminal rescue, achievement completion, numerical win odds or stronger-than-human performance follows from this fixture. Preserve all logs, current settings, native dependencies and dirty/untracked work.',
        budget_summary='All experiment allowances remain CLOSED. Release 335 runs zero source components, captured-state policy replays, searches and complete attempts. It reads no source executable archive, player saves or profiles, and does not control the game. Only manufactured Lua fixtures and relevant full regressions run, with 60-second per-suite caps. Historical loss328 used four public pairs and six source attempts, 1,200 seconds reserved and 685.3740000000689 seconds actual; unused P05/P06 and 60 seconds remain closed. No source worker, source attempt, search or scheduled continuation is pending. Separate scoring, inventory and economy redundancy audits are ordinary unfinished development until separately reviewed and released.',
    )
    value['diagnostic_evidence'] = {name: ref(path) for name, path in {
        'previous_checkpoint': prior_path,
        'before_module': HERE / 'before/Brainstorm/Advisor/player_journal.lua',
        'candidate_module': COMPONENT / 'player_journal.lua',
        'manufactured_fixture': COMPONENT / 'test_journal_work.lua',
        'component_validation': COMPONENT / 'validation.json',
        'production_fixture': ROOT / 'tests/advisor_journal_reuse.lua',
        'frozen_baseline': ROOT / 'tests/fixtures/journal_reuse335/player_journal334.lua',
        'fixture_dependency_hashes': ROOT / 'tests/fixtures/journal_reuse335/hashes.lua',
        'integration': HERE / 'integration.json',
        'candidate_validation': candidate_path,
    }.items()}
    value['manufactured_work_counts'] = {
        'fixture_checks': 236, 'component_fixtures': 5, 'component_checks': 443,
        'avoided_request_detail_collections': 9, 'avoided_complete_fingerprints': 16,
        'full_snapshots_preserved': True, 'serialized_event_bytes_equivalent': True,
        'measured_live_fps': False,
    }
    output = HERE / 'release_context'
    component_note = EVAL / 'JOURNAL_UNUSED_WORK_335.md'
    assert not output.exists() and not component_note.exists(), 'Preserve existing release work'
    texts = {name: (HERE / 'notes' / (name.upper() + '_DRAFT.md')).read_text(encoding='utf-8')
             for name in ('component', 'priorities', 'architecture', 'objective')}
    output.mkdir(exist_ok=False)
    exclusive(output / 'context.json', json.dumps(value, indent=2) + '\n')
    experiment_context(output / 'context.json')
    exclusive(component_note, texts['component'])
    for name in ('priorities', 'architecture', 'objective'):
        exclusive(output / (name + '.md'), texts[name])
    print(json.dumps({'context': ref(output / 'context.json'), 'component': ref(component_note)}, indent=2))


if __name__ == '__main__':
    main()
