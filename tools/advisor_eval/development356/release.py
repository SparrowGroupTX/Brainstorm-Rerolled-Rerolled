"""Freeze reviewed runtime bytes or write context; never start a game or experiment."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import policy_hashes
from paired_policy_audit import freeze_product
from install_slice import stamp_version, VERSION_FIELDS

CHANGED = ['Brainstorm/' + name for name in (
    'Advisor/auto_run.lua', 'Advisor/player_journal.lua', 'Advisor/player_log_archive.lua',
    'Advisor/snapshot.lua', 'Advisor/runtime.lua', 'Advisor/decision.lua',
    'Core/auto_run_product.lua', 'UI/collection_run.lua')]

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('xb') as f:
        f.write(value if isinstance(value, bytes) else value.encode('utf-8'))

def ref(p):
    return {'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}

if sys.argv[1] == 'prepare':
    prior = read(EVAL / 'runs/growth354_installed/record.json')['policy']
    current = policy_hashes(ROOT)
    assert current.keys() == prior['policy_files'].keys()
    for name, expected in prior['policy_files'].items():
        if name not in CHANGED:
            assert current[name] == expected, name
    for name in VERSION_FIELDS:
        path = ROOT / 'Brainstorm' / name
        write(HERE / 'before/Brainstorm' / name, path.read_bytes())
        stamp_version(path, name, '2.156.0-alpha')
    out = EVAL / 'runs/teacher356_candidate'
    out.mkdir(exist_ok=False)
    policy = freeze_product(ROOT, out / 'policy')
    write(out / 'freeze.json', json.dumps(policy, indent=2) + '\n')
    write(HERE / 'integration.json', json.dumps({
        'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
        'previous_policy_digest': prior['policy_digest'], 'policy_digest': policy['policy_digest'],
        'changed_runtime': {n: {'before': prior['policy_files'][n], 'after': policy['policy_files'][n]} for n in CHANGED},
        'game_control': False, 'save_reads': False, 'new_experiments': 0,
    }, indent=2) + '\n')
    print(policy['policy_digest'])
elif sys.argv[1] == 'context':
    candidate = read(EVAL / 'runs/teacher356_candidate/validation/report.json')
    assert candidate['passed'] and candidate['policy_unchanged'] and candidate['tests_unchanged']
    summary = 'Prepare an explicit ten-match real-game teacher collection: win-first Perkeo/Yorick profile, current-ante public blind context, referenced state-change records and bounded safe abandonment.'
    context = {'schema': 1, 'kind': 'checkpoint_experiment_context', 'status': 'CLOSED',
        'release': 356, 'created_utc': datetime.now(timezone.utc).isoformat(), 'summary': summary,
        'outcome_summary': 'No 356 games, searches, GPU jobs or log purges were executed by development tools. The ten-match product pilot is prepared, not started. No new win, strategy gain or numerical win probability is demonstrated. The rejected355 neural policy and its failed simulator outcomes remain preserved and are not deployed.',
        'limits_summary': 'Teacher actions remain unreviewed heuristic demonstrations. Real-game records reduce simulator mismatch but do not establish optimality, reconstruct hidden RNG or make failures negative labels for every action. Thirty-second retirement waits for safe settled actions; search/log/profile errors can stop early. Legacy355 80/530-vector models do not consume the new public-context schema. No live game control or save/profile file access occurred.',
        'budget_summary': 'Development used only routine manufactured fixtures/regression and source review. Product preset: at most10 starts,500 actions/1800seconds perrun,30seconds persearch,21600seconds session. Observation cap1GiB. User explicitly starts the prepared product batch after normal restart; cleanup occurs then. All historical detached/source/search/training allowances remain closed.',
        'counts': {k: 0 for k in ('source_components','captured_pair_jobs','captured_policy_evaluations','search_workers','complete_attempts')},
        'complete_attempt_outcomes': {k: 0 for k in ('win','loss','error','timeout','unsupported','censored','running','not_started')},
        'verified_complete_win': False, 'unused_capacity': 'closed',
        'product_pilot': read(HERE / 'OUTCOMES.json'),
        'evidence': {k: ref(HERE / name) for k, name in {
            'authority': 'AUTHORITY.md', 'outcomes': 'OUTCOMES.json', 'budget': 'BUDGET.json', 'limits': 'AUTHORITY.md'}.items()}}
    write(HERE / 'context.json', json.dumps(context, indent=2) + '\n')
    print(json.dumps(ref(HERE / 'context.json')))
else:
    raise SystemExit('Expected prepare or context')
