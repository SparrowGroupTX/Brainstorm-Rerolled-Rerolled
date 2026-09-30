"""Prepare only the reviewed journal335 slice; never install or control the game.

Run --check for a read-only preflight. Root executes the mutation after review.
All output paths must be new; every current policy byte must match release334.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parents[1]
ROOT = EVAL.parents[1]
COMPONENT = HERE.parent / 'runtime_component'
sys.path.insert(0, str(EVAL))
from benchmark import digest, policy_hashes
from install_slice import VERSION_FIELDS
from paired_policy_audit import freeze_product

VERSION = '2.135.0-alpha'
PREFIX = 'journal335'
PREVIOUS_DIGEST = '64b99ea570d39ff9b8f46aff97f8bafa21eb6fe83ade8e8ea58cb72581d1ad14'
EXPECTED = {
    'player_journal.base.lua': 'eae2209780c9c7d97571c123cb5988a496a9b94fcf39345934a6c5c27265699b',
    'player_journal.lua': '1d41e9fe61ee25c4397a8a3b5ce1e598f1410c3a3f7ff5277345301e2455962e',
    'test_journal_work.lua': 'bc592c769b40d5e7d1518625767c546a52a6212af29ab37986d27ddb68e12255',
    'validation.json': '7ff4b1303425de02561a3b8f91e5fc865e5f9e43a326df0328258089b662f0dc',
}
PRODUCTION_TEST_HASH = 'c7b5110783c3b6989f64c15ecdf4b1f82c282c6641279d432e7dee491f511c92'
CHANGED = 'Brainstorm/Advisor/player_journal.lua'
TEST = 'tests/advisor_journal_reuse.lua'
BASELINE = 'tests/fixtures/journal_reuse335/player_journal334.lua'
DEPENDENCIES = 'tests/fixtures/journal_reuse335/hashes.lua'


def sha_bytes(value):
    return hashlib.sha256(value).hexdigest()


def sha(path):
    return sha_bytes(Path(path).read_bytes())


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def exclusive(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as handle:
        handle.write(data)


def production_fixture():
    original = (COMPONENT / 'test_journal_work.lua').read_text(encoding='utf-8')
    before = """local base='tools/advisor_eval/development335/runtime_component/'
local baseline=dofile(base..'player_journal.base.lua')
local candidate=dofile(base..'player_journal.lua')"""
    after = """local baseline=dofile('tests/fixtures/journal_reuse335/player_journal334.lua')
local candidate=dofile('Brainstorm/Advisor/player_journal.lua')"""
    assert original.count(before) == 1, 'Unexpected manufactured fixture imports'
    result = original.replace(before, after).encode('utf-8')
    assert b'development' not in result, 'Production fixture must have frozen test dependencies'
    assert sha_bytes(result) == PRODUCTION_TEST_HASH, 'Production fixture adaptation changed'
    return result


def preflight():
    prior_path = EVAL / 'runs/duplicates334_installed/record.json'
    record = read(prior_path)
    prior = record['policy']
    assert record['version'] == '2.134.0-alpha'
    assert prior['policy_digest'] == PREVIOUS_DIGEST == digest(prior['policy_files'])
    current = policy_hashes(ROOT)
    assert len(current) == 99 and current == prior['policy_files'], \
        'Every current product/dependency byte must match installed334 before any write'
    for name, expected in EXPECTED.items():
        assert sha(COMPONENT / name) == expected, 'Component evidence changed: ' + name
    assert current[CHANGED] == EXPECTED['player_journal.base.lua']
    validation = read(COMPONENT / 'validation.json')
    assert validation['returncode'] == 0 and validation['timeout_seconds'] == 60
    assert '5/5 fixtures passed' in validation['stdout']
    assert '236 checks; avoided detail gathers=9; avoided full fingerprints=16' in validation['stdout']
    assert 'all serialized event bytes equivalent' in validation['stdout']
    changed_bytes = {CHANGED: (COMPONENT / 'player_journal.lua').read_bytes()}
    for relative, pattern in VERSION_FIELDS.items():
        name = 'Brainstorm/' + relative
        original = (ROOT / name).read_bytes()
        matches = list(pattern.finditer(original))
        assert len(matches) == 1 and matches[0].group('version') == b'2.134.0-alpha', name
        start, end = matches[0].span('version')
        changed_bytes[name] = original[:start] + VERSION.encode('ascii') + original[end:]
    active_native = 'Brainstorm/Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll'
    deployment = [path for path in current if path.endswith('.lua') and
                  any(path.startswith('Brainstorm/' + area + '/') for area in ('Advisor', 'Core', 'UI'))]
    deployment += ['Brainstorm/steamodded_compat.lua', active_native]
    assert len(deployment) == len(set(deployment)) == 83
    assert all(path in current for path in deployment)
    fixture = production_fixture()
    dependency_hashes = ("-- Frozen manufactured-fixture dependency metadata; no source game archive.\n"
                         "return {schema=1,source_version='2.134.0-alpha',\n"
                         "  files={['player_journal334.lua']='" + EXPECTED['player_journal.base.lua'] + "'},\n"
                         "  fixture={path='tests/advisor_journal_reuse.lua',sha256='" + PRODUCTION_TEST_HASH + "'}}\n").encode('utf-8')
    additions = {TEST: fixture, BASELINE: (COMPONENT / 'player_journal.base.lua').read_bytes(),
                 DEPENDENCIES: dependency_hashes}
    output = EVAL / ('runs/' + PREFIX + '_candidate')
    for path in [HERE / 'before', HERE / 'integration.json', output, *(ROOT / name for name in additions)]:
        assert not path.exists(), 'Refusing to overwrite existing work: ' + str(path)
    return prior_path, prior, current, changed_bytes, additions, output, deployment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify all inputs without writing anything')
    args = parser.parse_args()
    prior_path, prior, current, changed_bytes, additions, output, deployment = preflight()
    summary = {'version': VERSION, 'prefix': PREFIX, 'previous_policy_digest': PREVIOUS_DIGEST,
               'policy_files': len(current), 'deployment_files': len(deployment),
               'changed_files': {name: sha_bytes(value) for name, value in changed_bytes.items()},
               'added_test_dependencies': {name: sha_bytes(value) for name, value in additions.items()}}
    if args.check:
        print(json.dumps({'read_only_preflight': 'passed', **summary}, indent=2))
        return
    # Preserve ALL prior production and version bytes before any of them change.
    for name in changed_bytes:
        exclusive(HERE / 'before' / name, (ROOT / name).read_bytes())
    assert policy_hashes(ROOT) == current, 'Product changed during pre-integration preservation'
    for name, value in additions.items():
        exclusive(ROOT / name, value)
    for name, value in changed_bytes.items():
        assert sha(ROOT / name) == current[name], 'Concurrent source change: ' + name
        (ROOT / name).write_bytes(value)
    expected = {**current, **{name: sha_bytes(value) for name, value in changed_bytes.items()}}
    assert policy_hashes(ROOT) == expected
    output.mkdir(exist_ok=False)
    frozen = freeze_product(ROOT, output / 'policy')
    assert len(frozen['policy_files']) == 99 and frozen['policy_files'] == expected
    exclusive(output / 'freeze.json', (json.dumps(frozen, indent=2) + '\n').encode('utf-8'))
    receipt = {
        'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
        'kind': 'routine_manufactured_fixture_runtime_slice', **summary,
        'policy_digest': frozen['policy_digest'],
        'previous_installed_record': {'path': prior_path.relative_to(ROOT).as_posix(), 'sha256': sha(prior_path)},
        'changed_runtime': {name: {'before': current[name], 'after': sha(ROOT / name),
                                  'preserved': (HERE / 'before' / name).relative_to(ROOT).as_posix()}
                            for name in changed_bytes},
        'component_inputs': {name: {'path': (COMPONENT / name).relative_to(ROOT).as_posix(), 'sha256': expected_hash}
                             for name, expected_hash in EXPECTED.items()},
        'source_workers': 0, 'captured_replays': 0, 'complete_attempts': 0, 'searches': 0,
        'game_control': False, 'saves_read': False, 'installation_performed': False,
        'experiments': 'all historical allowances remain closed',
    }
    exclusive(HERE / 'integration.json', (json.dumps(receipt, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({'policy_digest': frozen['policy_digest'], **summary}, indent=2))


if __name__ == '__main__':
    main()
