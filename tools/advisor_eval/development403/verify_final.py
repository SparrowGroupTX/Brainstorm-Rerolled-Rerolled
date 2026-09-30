"""Close a passive public audit; hashes only, no policy or scorer execution."""
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
from collections import Counter
import json
import sqlite3
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / 'final_verification.json'
assert not OUT.exists(), 'Preserve an existing verification receipt'

def digest(path):
    h = sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

release = read(ROOT / 'tools/advisor_eval/SESSION_RESET_400.json')
freeze = read(ROOT / 'tools/advisor_eval/runs/copydeath400_candidate2/freeze.json')
installed = Path(release['installed'])
mismatches = []
runtime = []
for relative, expected in freeze['candidate_policy_files'].items():
    assert release['policy_files'][relative] == expected
    candidate = ROOT / relative
    deployed = installed / Path(relative).relative_to('Brainstorm')
    hashes = {'repository': digest(candidate), 'installed': digest(deployed)}
    runtime.append({'path': relative, 'expected': expected, **hashes})
    if any(value != expected for value in hashes.values()):
        mismatches.append(relative)
tests = []
for relative, expected in freeze['test_files'].items():
    actual = digest(ROOT / relative)
    tests.append({'path': relative, 'expected': expected, 'actual': actual})
    if actual != expected:
        mismatches.append(relative)
native = []
for name, expected in release['native_files_preserved'].items():
    hashes = {'repository': digest(ROOT / 'Brainstorm' / name),
              'installed': digest(installed / name)}
    native.append({'path': name, 'expected': expected, **hashes})
    if any(value != expected for value in hashes.values()):
        mismatches.append(name)
assert not mismatches, mismatches
assert (len(runtime), len(tests), len(native)) == (109, 305, 7)

manifest = read(HERE / 'capture/manifest.json')
source = Path(manifest['source'])
copies = []
for entry in manifest['segments']:
    copy = HERE / 'logs1' / entry['name']
    assert copy.stat().st_size == entry['bytes']
    assert digest(copy) == entry['sha256']
    original = source / entry['name']
    copies.append({'name': entry['name'], 'bytes': entry['bytes'],
                   'sha256': entry['sha256'],
                   'source_still_matches_at_close': original.is_file()
                   and digest(original) == entry['sha256']})

summary = read(HERE / 'analysis2/summary.json')
runs = read(HERE / 'analysis2/runs.json')
outcomes = Counter(r['end']['details']['outcome'] for r in runs)
assert outcomes == {'win': 5, 'loss': 4, 'unsupported': 1}
assert summary['actions_with_policy_action'] == 2177
assert all(summary[k] == 0 for k in ('missing_observation_links',
    'missing_advice_links', 'missing_callbacks', 'missing_settlement_markers'))
offers = read(HERE / 'analysis2/copy_opportunities.json')
assert len(offers) == 11 and sum(bool(o['first_owned_sequence']) for o in offers) == 9
deaths = read(HERE / 'analysis2/death_settlement_checks.json')
assert len(deaths) == 23 and all(d['first_matching_public_observation'] for d in deaths)
packs = read(HERE / 'analysis2/pack_reveal_checks.json')
assert len(packs) == 30 and all(p['first_pack_reveal'] for p in packs)

db = sqlite3.connect('file:' + str(HERE / 'events.sqlite3') + '?mode=ro', uri=True)
indexed = db.execute('SELECT count(*),min(seq),max(seq) FROM events').fetchone()
assert indexed == (24223, 1, 24223)
anchors = {}
for seq in (10029,10037,11056,13176,13180,13183,13192,16314,16317,
            16320,19906,19912,19916,19922,20590,20665,20675,20680,
            20905,20917,21134,21222,21320,24222,24223):
    segment, ordinal, raw = db.execute(
        'SELECT segment,ordinal,raw_sha FROM events WHERE seq=?', (seq,)).fetchone()
    anchors[seq] = {'segment': segment, 'ordinal': ordinal, 'raw_sha256': raw}
db.close()

process = subprocess.run(['powershell', '-NoProfile', '-Command',
    'Get-Process -Name Balatro -ErrorAction SilentlyContinue | '
    'Select-Object Id,ProcessName | ConvertTo-Json -Compress'],
    capture_output=True, text=True)
assert not process.stderr.strip(), process.stderr
passive_process = json.loads(process.stdout) if process.stdout.strip() else []

navigation = ['ADVISOR_START_HERE.md', 'ADVISOR_RESUME_PROMPT.md',
    'ADVISOR_HANDOFF.md', 'tools/advisor_eval/NEXT_PRIORITIES_400.md',
    'tools/advisor_eval/ARCHITECTURE_MAP_400.md', 'tools/advisor_eval/WIN_RATE_RESEARCH.md']
artifacts = {str(p.relative_to(ROOT)).replace('\\', '/'): digest(p)
             for p in sorted(HERE.rglob('*'))
             if p.is_file() and 'logs1' not in p.parts and '__pycache__' not in p.parts
             and p.name != 'final_verification.log'}
support = ['tests/run_lua_tests.py', 'tools/advisor_eval/read_player_log.py',
           'tools/advisor_eval/ANALYSIS_PLAN_403.md',
           'tools/advisor_eval/SESSION_RESET_400.json',
           'tools/advisor_eval/runs/copydeath400_candidate2/freeze.json']
provenance = {relative: digest(ROOT / relative) for relative in support}
lua = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Balatro\lua51.dll')
provenance[str(lua)] = digest(lua)
provenance[sys.executable] = digest(Path(sys.executable))
result = {
    'verified_utc': datetime.now(timezone.utc).isoformat(),
    'kind': 'passive_public_analysis_and_manufactured_diagnosis_no_runtime_change',
    'policy_digest': freeze['candidate_policy_digest'],
    'runtime_files_per_tree': len(runtime), 'frozen_tests': len(tests),
    'native_files_per_tree': len(native), 'mismatches': mismatches,
    'runtime_checks': runtime, 'test_checks': tests, 'native_checks': native,
    'copied_public_segments': copies,
    'public_source_inventory_at_close': sorted(p.name for p in source.glob('*.brj')),
    'all_source_segments_still_match': all(c['source_still_matches_at_close'] for c in copies),
    'indexed_events': indexed[0], 'outcomes': dict(outcomes),
    'policy_action_links_complete': 2177,
    'copy_offers': 11, 'copy_acquisitions_confirmed': 9,
    'buffoon_offers': 44, 'buffoon_reveals_confirmed': 30,
    'death_transformations_confirmed': 23,
    'loaded_public_label': 'Brainstorm v2.194.0-alpha',
    'loaded_exact_process_bytes': 'not attested',
    'normal_exit_of_current_session': 'not confirmed; process absence is insufficient',
    'passive_process_at_close': passive_process,
    'diagnostic_fixture': {'attempts': 2, 'initial_api_assertion_failure_preserved': True,
        'final_fixtures_passed': 1, 'final_assertions': 15,
        'meaning': 'reproduces existing gaps, not a repair or full release gate'},
    'primary_anchor_map': anchors, 'artifact_hashes': artifacts,
    'navigation_hashes': {relative: digest(ROOT / relative) for relative in navigation},
    'support_provenance_at_close': provenance, 'python_version': sys.version,
    'game_control': False, 'captured_policy_or_scorer_replay': False,
    'saved_game_or_profile_access': False, 'runtime_or_installation_changes': False,
    'settings_or_native_changes': False, 'new_experiment_or_automation': False,
}
OUT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: result[k] for k in ('runtime_files_per_tree', 'frozen_tests',
    'native_files_per_tree', 'mismatches', 'indexed_events', 'outcomes',
    'all_source_segments_still_match', 'passive_process_at_close')}))
