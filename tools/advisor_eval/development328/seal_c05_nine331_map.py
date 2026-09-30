"""Seal existing C05 preparation after installed331 verification; never register/run."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = ROOT / 'tools/advisor_eval/runs/loss328_validation_20260915'
PREPARED = HERE / 'validation_adapter/prepared'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    source = PREPARED / 'C05_nine331_prospective_v2.json'
    source_sha = sha(source)
    assert source_sha == 'ebb1c0aecf5fa31269e9ddd459bfd3b69ecc2aecea71e21d5d8e6e9108efdaff'
    value = read(source)
    assert value['status'] == 'prospective_map_pending_root_installed331_verification_and_seal'
    assert not (BASE / 'C05').exists() and not (BASE / 'C05_reservation.json').exists()
    for relative, expected in value['expected_files'].items():
        assert sha(value['files'][relative]) == expected, relative
    for path, expected in value['external_sha256'].items():
        assert sha(path) == expected, path
    files = value['files']
    installed = read(files['installed_policy_record.json'])
    validation = read(files['installed_validation.json'])
    final = read(files['installed_final_verification.json'])
    graph = read(files['installed_graph_check.json'])
    digest = value['expected_policy_digest']
    assert installed['version'] == final['version'] == value['metadata']['installed_version'] == '2.131.0-alpha'
    assert installed['policy']['policy_digest'] == validation['policy_digest'] == final['policy_digest'] == graph['policy_digest'] == digest
    assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
    assert all(run['status'] == 'passed' and run['exit_code'] == 0 for run in validation['runs'])
    assert final['installed_matches'] and final['native_unchanged']
    assert final['installed_report'] == sha(files['installed_validation.json'])
    assert final['candidate_report'] == sha(files['candidate_validation.json'])
    assert graph['policy_files'] == installed['policy']['policy_files']
    assert len(graph['policy_files']) == 94
    assert graph['passed'] and graph['source_initializations'] == 0 and graph['policy_decisions'] == 0
    for name, expected in installed['policy']['policy_files'].items():
        assert sha(files['policy/' + name]) == expected
        # Read product files only. This never reads settings, profiles or saves.
        relative = Path(name).relative_to('Brainstorm')
        assert sha(Path(installed['installed']) / relative) == expected, name
    assert sha(value['superseded_preparation_only']['path']) == value['superseded_preparation_only']['sha256']
    value['status'] = 'sealed_not_registered_reserved_or_run'
    value['sealed_at_utc'] = datetime.now(timezone.utc).isoformat()
    value['prospective_map_sha256'] = source_sha
    value['files']['prospective_input_map.json'] = str(source)
    value['files']['seal_c05_nine331_map.py'] = str(Path(__file__).resolve())
    value['expected_files'] = {name: sha(path) for name, path in value['files'].items()}
    for relative, key in [('installed_policy_record.json', 'installed_policy_record_sha256'),
                          ('installed_validation.json', 'installed_validation_sha256'),
                          ('installed_final_verification.json', 'installed_final_verification_sha256')]:
        value['metadata'][key] = value['expected_files'][relative]
    value['pending_root_seal_files'] = []
    value['installed_validation'] = {'version': installed['version'], 'policy_digest': digest,
          'whole_policy_files': 94, 'actual_installed_product_hashes_checked': 94,
          'source_initializations': 0, 'policy_decisions': 0,
          'installed_policy_record_sha256': value['metadata']['installed_policy_record_sha256'],
          'installed_validation_sha256': value['metadata']['installed_validation_sha256'],
          'installed_final_verification_sha256': value['metadata']['installed_final_verification_sha256']}
    value['root_seal_requirements'] = ['Completed: exact installed331 product, record, full regression and final verification bound. Root alone may register C05 once and launch it under the remaining existing180second allowance.']
    target = PREPARED / 'C05_nine331_sealed.json'
    with target.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')
    assert sha(source) == source_sha
    print(json.dumps({'path': str(target), 'sha256': sha(target), 'files': len(value['files']),
                      'policy_digest': digest, 'external_files_checked': len(value['external_sha256']),
                      'source_initializations': 0, 'policy_decisions': 0, 'reservations': 0, 'launches': 0}))


if __name__ == '__main__':
    main()
