"""Map-only C05 follow-up preparation; does not import a worker or supervisor."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = ROOT / 'tools/advisor_eval/runs/loss328_validation_20260915'
ADAPTER = HERE / 'validation_adapter'
DIGEST = '29f5f3112a7170c7a1181bde7ee91b436aa386ec7ff88145d4ed24b711807983'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    old_prepared = ADAPTER / 'prepared/C05.json'
    original_prepared_hash = sha(old_prepared)
    prior = BASE / 'C02'
    registration = read(prior / 'registration.json')
    record = read(prior / 'record.json')
    assert record['worker_reaped'] and record['status'] == 'error'
    assert record['registration_sha256'] == sha(prior / 'registration.json')
    assert not (BASE / 'C05').exists() and not (BASE / 'C05_reservation.json').exists()
    graph_path = ADAPTER / 'graph_candidate331.json'
    graph = read(graph_path)
    candidate = ROOT / 'tools/advisor_eval/runs/nine331_candidate'
    freeze = read(candidate / 'freeze.json')
    assert graph['passed'] and graph['source_initializations'] == 0 and graph['policy_decisions'] == 0
    assert graph['policy_digest'] == freeze['policy_digest'] == DIGEST
    assert graph['policy_files'] == freeze['policy_files']
    for relative, expected in freeze['policy_files'].items():
        assert sha(candidate / 'policy' / relative) == expected
    for relative, expected in registration['files'].items():
        assert sha(prior / relative) == expected
    plan = HERE / 'followup_plan_after_C04.json'
    assert read(plan)['authority_sha256'] == registration['authority_sha256']
    installed = ROOT / 'tools/advisor_eval/runs/nine331_installed'
    files = {key: str(prior / key) for key in registration['files'] if not key.startswith('policy/')}
    files.pop('prepared_registration_inputs.json', None)
    files.update({
        'prior_prepared_registration_inputs.json': str(prior / 'prepared_registration_inputs.json'),
        'installed_policy_record.json': str(installed / 'record.json'),
        'installed_validation.json': str(ROOT / 'tools/advisor_eval/runs/nine331_installed_validation/report.json'),
        'installed_final_verification.json': str(ROOT / 'tools/advisor_eval/runs/nine331_final/final_verification.json'),
        'installed_graph_check.json': str(graph_path),
        'inert_graph_raw.json': str(Path(graph['scratch']) / 'raw.json'),
        'inert_graph_stdout.log': str(Path(graph['scratch']) / 'stdout.log'),
        'inert_graph_wrapper.lua': str(Path(graph['scratch']) / 'run.lua'),
        'candidate_freeze.json': str(candidate / 'freeze.json'),
        'candidate_validation.json': str(candidate / 'validation/report.json'),
        'nine_card_component_manifest.json': str(HERE / 'nine_card_component/manifest.json'),
        'followup_plan_after_C04.json': str(plan),
        'prior_C02_registration.json': str(prior / 'registration.json'),
        'prior_C02_record.json': str(prior / 'record.json'),
        'prior_C02_audit.json': str(prior / 'audit.json'),
        'supervisor_source.py': str(HERE / 'validation_cycle.py'),
        'stdout_transport.py': str(HERE / 'stdout_transport.py'),
        'audit_definition.py': str(HERE / 'audit_attempt.py'),
        'prepare_c05_nine331_map.py': str(Path(__file__).resolve()),
    })
    files.update({'policy/' + name: str(installed / 'policy' / name) for name in freeze['policy_files']})
    expected = {key: sha(path) for key, path in files.items() if Path(path).exists()}
    expected.update({'policy/' + name: value for name, value in freeze['policy_files'].items()})
    # Installation records are deliberately left to root's post-install seal.
    pending = ['installed_policy_record.json', 'installed_validation.json', 'installed_final_verification.json']
    for name in pending:
        expected.pop(name, None)
    metadata = dict(registration['metadata'])
    for name in ('pair_id', 'pair_role', 'paired_job', 'preregistered_pair_order'):
        metadata.pop(name, None)
    metadata.update({
        'hypothesis': 'Test whether exact tested331 admits a complete nine-card concealed comparison within the unchanged8000-score cap and continues past C02 step47 House. Use the identical S7PXV521 opening, source adapter, synthetic profile and concealed-Joker stop. Preserve every later error, timeout, unsupported result or terminal result; no terminal rescue is assumed.',
        'checkpoint': 331, 'installed_version': '2.131.0-alpha', 'policy_digest': DIGEST,
        'comparison_design': 'prospective_followup_using_already_spent_dependent_reference',
        'comparison_role': 'followup_candidate', 'prior_comparison_job': 'C02',
        'prior_comparison_outcome': 'error', 'prior_comparison_policy_digest': registration['metadata']['policy_digest'],
        'prior_comparison_registration_sha256': sha(prior / 'registration.json'),
        'prior_comparison_record_sha256': sha(prior / 'record.json'),
        'prior_comparison_audit_sha256': sha(prior / 'audit.json'),
        'fresh_reciprocal_pair': False,
        'pairing_limit': 'C02 was already spent before this hypothesis was formed. No fresh reciprocal baseline or unseen holdout exists. Public first divergence can be inspected read-only only while preceding public state/action/effect prefixes align; hidden RNG/save equivalence is not claimed.',
        'policy_change_from_reference': '331 changes only the immediate/future concealed held-card size guards8 to9;330 forwards already-computed replacement evidence with no added scoring or action change. Other changed product files contain checkpoint version strings. No score cap, sample count, native code, source adapter or opening recipe changed.',
        'changed_policy_files': {name: {'prior_sha256': registration['files'].get('policy/' + name), 'candidate_sha256': value}
                                 for name, value in freeze['policy_files'].items()
                                 if registration['files'].get('policy/' + name) != value},
        'followup_plan_sha256': sha(plan),
        'installed_graph_check_sha256': sha(graph_path),
        'inert_graph_policy_location': 'candidate331 frozen bytes; must match the exact installed331 policy before registration',
        'installed_final_verification_sha256': None,
        'installed_policy_record_sha256': None,
        'installed_validation_sha256': None,
        'supervisor_sha256': sha(HERE / 'validation_cycle.py'),
        'prospective_audit_sha256': sha(HERE / 'audit_attempt.py'),
        'transport_comparison_limit': 'C02 and C05 use the same lossless gzip contract. Isolated source-worker time is not live game animation/user time; changed policy work is not a compression speedup.',
    })
    for path, expected_hash in registration['external_files'].items():
        assert sha(path) == expected_hash
    out = {'schema': 1, 'kind': 'unregistered_complete_attempt_input_map',
           'status': 'prospective_map_pending_root_installed331_verification_and_seal',
           'job': 'C05', 'timeout_seconds': 180, 'authority_sha256': registration['authority_sha256'],
           'files': files, 'expected_files': expected, 'pending_root_seal_files': pending,
           'expected_policy_digest': DIGEST,
           'command': [registration['command'][0], '-B', '-u', '{job}/run_attempt.py'],
           'metadata': metadata, 'external': list(registration['external_files']),
           'external_sha256': registration['external_files'],
           'superseded_preparation_only': {'path': str(old_prepared), 'sha256': original_prepared_hash,
                'scope': 'Original unused YAEARC31 baseline preparation stays intact; it was never a reservation or executed attempt.'},
           'source_initializations': 0, 'policy_decisions': 0, 'searches': 0,
           'reservations_created': 0, 'workers_launched': 0,
           'root_seal_requirements': [
               'Confirm331 installation and exact-installed validation/final receipt; hash all three pending files into a fresh sealed map.',
               'Confirm installed policy digest and all94 file hashes equal candidate freeze/inert graph.',
               'Hash/check every mapped adapter/provenance/supervisor/transport/runtime file before registration.',
               'Bind the sealed map as prepared_registration_inputs.json when registering C05 once under the existing authority; never alter prior jobs.',
           ]}
    target = ADAPTER / 'prepared/C05_nine331_prospective_v2.json'
    with target.open('x', encoding='utf-8') as stream:
        json.dump(out, stream, indent=2, allow_nan=False)
        stream.write('\n')
    assert sha(old_prepared) == original_prepared_hash
    print(json.dumps({'path': str(target), 'sha256': sha(target), 'files': len(files),
                      'pending_root_seal_files': pending, 'inert_graph': graph['graph']['checks'],
                      'source_initializations': 0, 'policy_decisions': 0, 'reservations': 0, 'launches': 0}))


if __name__ == '__main__':
    main()
