"""Parent-only fresh M24 registration. --describe does not reserve or launch."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RUNS = ROOT/'tools/advisor_eval/runs'
BASE = RUNS/'gold299_20260914'
INSTALLED = RUNS/'startup316_installed'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def plan():
    record = read(INSTALLED/'record.json')
    final = RUNS/'startup316_final/final_verification.json'
    validation = RUNS/'startup316_installed_validation/report.json'
    verified = read(final)
    assert record['version'] == verified['version'] == '2.116.0-alpha'
    assert record['policy']['policy_digest'] == verified['policy_digest']
    assert verified['installed_matches'] and verified['native_unchanged']
    assert verified['config_restored_or_modified_by_finalizer'] is False
    assert sha(validation) == verified['installed_report']
    assert read(HERE/'synthetic_fixture_report.json')['passed']
    files = {name: HERE/name for name in ('inspect_source.py', 'source_lexer.py', 'register.py',
        'spec.md', 'test_inspector.py', 'synthetic_fixture_report.json', 'prior_read_only_binding.json',
        'preparation_manifest.json')}
    manifest = read(HERE/'preparation_manifest.json')
    for name, expected in manifest['adapter_files'].items():
        assert sha(HERE/name) == expected, 'Prepared adapter changed: '+name
    files['authority.json'] = BASE/'authority.json'
    for name, expected in record['policy']['policy_files'].items():
        assert sha(INSTALLED/'policy'/name) == expected, name
        files['policy/'+name] = INSTALLED/'policy'/name
    files['installed_policy_record.json'] = INSTALLED/'record.json'
    files['installed_final_verification.json'] = final
    files['installed_validation.json'] = validation
    for name in ('registration.json', 'record.json', 'inspection/inspection.json'):
        files['prior_M23/'+name] = BASE/'M23'/name
    files['prior_M13_inspection.json'] = BASE/'M13/inspection/inspection.json'
    old = read(BASE/'M23/registration.json')
    assert sha(HERE/'source_lexer.py') == old['files']['source_lexer.py']
    archive = next(Path(p) for p in old['external_files'] if Path(p).name.lower() == 'balatro.exe')
    metadata = dict(kind='cashout_ui_ownership_source_inspection_v1',
        hypothesis='Cash Out is a separate original UIBox anchored to the current round evaluation. Exact registry, ownership and removal fields can support a unique visible button lookup and delayed-readiness gate.',
        source_archive=str(archive), expected_source_sha256=old['external_files'][str(archive)],
        policy_version=record['version'], policy_digest=record['policy']['policy_digest'],
        outer_cap_seconds=30, one_use=True, maximum_members=3, maximum_methods=6,
        combined_output_cap_bytes=40000, source_excerpt_cap_bytes=33000,
        profile='none', native_search=False, source_execution=False, policy_execution=False,
        lua_runtime_loaded=False, game_process_access=False, player_file_access=False,
        runtime='Frozen Python standard-library ZIP/byte lexer only; no Lua runtime',
        source_members=['engine/ui.lua', 'functions/button_callbacks.lua', 'engine/moveable.lua'],
        existing_constructor='Prior retained common_events.lua1065–1093 has exact M13-matching hash; no duplicate archive read of that member.',
        limitations='Static ownership/readiness mechanics only. Missing, ambiguous, over-budget or incomplete methods remain explicit. No live action, cash-out, policy decision or terminal result.',
        prior_jobs='M23 was input-hook inspection; M24 has a distinct cash-out UI ownership purpose. Historical budgets remain closed; no replacement or retry.',
        qualification=False)
    return files, metadata, [archive, Path(sys.executable)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--describe', action='store_true')
    mode.add_argument('--register', action='store_true')
    args = parser.parse_args()
    files, metadata, external = plan()
    if args.describe:
        print(json.dumps(dict(files=len(files), metadata=metadata,
                              external=list(map(str, external))), indent=2))
        return
    assert sha(external[0]) == metadata['expected_source_sha256'], 'Original archive changed'
    spec = importlib.util.spec_from_file_location('cycle', ROOT/'tools/advisor_eval/development299/cycle.py')
    cycle = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cycle)
    print(cycle.register('M24', files, [sys.executable, '-B', '-u', '{job}/inspect_source.py'],
                         metadata, external=external))


if __name__ == '__main__':
    main()
