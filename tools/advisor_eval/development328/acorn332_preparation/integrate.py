"""Root-owned one-use Acorn332 composition. No versioning, tests, install or experiments.

Default: read-only preflight. Pass --apply for the reviewed thirteen-file change.
Every sealed component, frozen331 file, existing test and destination is checked
before any production writes. Existing work is backed up and never deleted.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SPEC_SHA256 = 'c6745c6d4e500adbd24cc163eebcbdeb3e2cc259e4f44edd328a0c5e32197b72'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def contained(base, relative):
    relative = relative.replace('\\', '/')
    p = Path(relative)
    if p.is_absolute() or p.drive or '..' in p.parts:
        raise RuntimeError('Unsafe relative path: ' + relative)
    resolved = (base / p).resolve()
    if not resolved.is_relative_to(base.resolve()):
        raise RuntimeError('Path escapes intended root: ' + relative)
    return resolved

def verify(path, expected):
    if not path.is_file() or sha(path) != expected:
        raise RuntimeError('Hash mismatch or missing file: ' + str(path))

def check_destination(item):
    path = contained(ROOT, item['path'])
    if item['before_sha256'] is None:
        if path.exists():
            raise RuntimeError('New destination already exists; preserving work: ' + str(path))
    else:
        verify(path, item['before_sha256'])
    return path

def preflight():
    verify(HERE / 'spec.json', SPEC_SHA256)
    spec = json.loads((HERE / 'spec.json').read_text())
    if ROOT != Path(spec['expected_root']).resolve():
        raise RuntimeError('Unexpected repository root')
    for seal in spec['seals']:
        directory = contained(ROOT, seal['directory'])
        manifest_path = directory / 'manifest.json'
        verify(manifest_path, seal['manifest_sha256'])
        manifest = json.loads(manifest_path.read_text())
        for relative, item in manifest['files'].items():
            expected = item if isinstance(item, str) else item['sha256']
            verify(contained(directory, relative), expected)
    baseline = spec['baseline']
    freeze_path = contained(ROOT, baseline['freeze_path'])
    verify(freeze_path, baseline['freeze_sha256'])
    freeze = json.loads(freeze_path.read_text())
    calculated = hashlib.sha256(json.dumps(freeze['policy_files'], sort_keys=True,
                                          separators=(',', ':')).encode()).hexdigest()
    if calculated != baseline['policy_digest'] or freeze['policy_digest'] != calculated:
        raise RuntimeError('Frozen331 policy digest mismatch')
    if len(freeze['policy_files']) != baseline['file_count']:
        raise RuntimeError('Frozen331 file count mismatch')
    policy_root = contained(ROOT, baseline['policy_root'])
    for relative, expected in freeze['policy_files'].items():
        verify(contained(policy_root, relative), expected)
        verify(contained(ROOT, relative), expected)
    validation_path = contained(ROOT, baseline['validation_path'])
    verify(validation_path, baseline['validation_sha256'])
    validation = json.loads(validation_path.read_text())
    if not all(validation.get(key) is True for key in ['passed', 'policy_unchanged', 'tests_unchanged']):
        raise RuntimeError('Frozen331 regression receipt is not passing and immutable')
    if validation['policy_files'] != freeze['policy_files']:
        raise RuntimeError('Regression and freeze policy manifests differ')
    for relative, expected in validation['test_files'].items():
        verify(contained(ROOT, relative), expected)
    for relative, expected in spec['protected_unchanged'].items():
        verify(contained(ROOT, relative), expected)
    paths = set()
    for item in spec['destinations']:
        if item['path'] in paths:
            raise RuntimeError('Duplicate destination: ' + item['path'])
        paths.add(item['path'])
        payload = contained(HERE / 'payload', item['path'])
        verify(payload, item['after_sha256'])
        if payload.stat().st_size != item['bytes']:
            raise RuntimeError('Payload size mismatch: ' + item['path'])
        check_destination(item)
    return spec

def write_json(path, record, exclusive=False):
    with path.open('x' if exclusive else 'w', encoding='utf-8', newline='\n') as stream:
        json.dump(record, stream, indent=2)
        stream.write('\n')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    spec = preflight()
    if not args.apply:
        print(json.dumps({'status': 'preflight_passed', 'production_writes': 0,
                          'destinations': [item['path'] for item in spec['destinations']]}))
        return
    evidence = HERE / 'root_integration_evidence'
    # Exclusive directory is the one-use latch. Never remove or reuse it.
    evidence.mkdir()
    record = {'schema': 1, 'status': 'reserved_after_complete_preflight',
              'created_utc': datetime.now(timezone.utc).isoformat(),
              'one_use': True, 'spec_sha256': SPEC_SHA256,
              'script_sha256': sha(Path(__file__).resolve()),
              'baseline_policy_digest': spec['baseline']['policy_digest'],
              'completed': [], 'backups': {}, 'experiments_run': 0,
              'version_stamping': False, 'installation': False}
    receipt = evidence / 'receipt.json'
    write_json(receipt, record, exclusive=True)
    try:
        for item in spec['destinations']:
            destination = check_destination(item)
            if item['before_sha256'] is not None:
                backup = contained(evidence / 'before', item['path'])
                backup.parent.mkdir(parents=True, exist_ok=True)
                with backup.open('xb') as stream:
                    stream.write(destination.read_bytes())
                verify(backup, item['before_sha256'])
                record['backups'][item['path']] = backup.relative_to(HERE).as_posix()
        write_json(receipt, record)
        # Repeat the complete read-only gate after backup construction.
        preflight()
        for item in spec['destinations']:
            destination = check_destination(item)
            payload = contained(HERE / 'payload', item['path']).read_bytes()
            mode = 'xb' if item['before_sha256'] is None else 'wb'
            with destination.open(mode) as stream:
                stream.write(payload)
            verify(destination, item['after_sha256'])
            record['completed'].append(item)
            write_json(receipt, record)
        record['status'] = 'composed_not_stamped_tested_or_installed'
        record['completed_utc'] = datetime.now(timezone.utc).isoformat()
        write_json(receipt, record)
    except BaseException as error:
        record['status'] = 'error_preserved_no_automatic_rollback'
        record['error'] = {'type': type(error).__name__, 'message': str(error)}
        write_json(receipt, record)
        raise
    print(json.dumps({'status': record['status'], 'production_files_written': len(record['completed']),
                      'receipt': str(receipt), 'experiments_run': 0}))

if __name__ == '__main__':
    main()
