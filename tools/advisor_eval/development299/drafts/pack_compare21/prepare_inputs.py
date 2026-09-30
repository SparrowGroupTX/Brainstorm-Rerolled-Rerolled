"""Create-only capture extraction and installed-policy binding; no Lua evaluation.

Run without arguments once to extract C05 step12. After314 exists, use
--candidate-installed <frozen installed314 directory> to bind both whole policies.
This does not register, reserve, spend, launch, or load any runtime.
"""
from pathlib import Path
import argparse
import hashlib
import json
from module_graph import module_setup

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'
C05 = RUNS / 'gold299_20260914/C05'
BASELINE = RUNS / 'perkeo312_installed'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def write(name, value):
    with (HERE / name).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def capture():
    record = json.loads((C05 / 'record.json').read_text())
    audit = json.loads((C05 / 'audit.json').read_text())
    registration = json.loads((C05 / 'registration.json').read_text())
    assert record['trace_sha256'] == audit['trace_sha256'] == sha(C05 / 'trace.log') == '29a061ce19b1a0a9385bdf89215ac685bdbee625b2518eb4ee3fb18b37906ef1'
    assert record['registration_sha256'] == audit['registration_sha256'] == sha(C05 / 'registration.json')
    assert audit['disposition'] == 'loss' and not audit['audit_issues']
    found = {}; origin = {}; provenance = None
    with (C05 / 'trace.log').open('rb') as stream:
        for line_number, line in enumerate(stream, 1):
            if not line.startswith(b'{'):
                continue
            row = json.loads(line)
            if row['type'] == 'engine_probe_provenance':
                assert provenance is None
                provenance = row
            if row.get('step') == 12 and row['type'] in ('engine_episode_decision_started', 'engine_episode_decision', 'engine_episode_action', 'engine_episode_profile', 'engine_episode_resolved'):
                assert row['type'] not in found
                found[row['type']] = row
                origin[row['type']] = {'trace_line': line_number, 'trace_line_sha256': hashlib.sha256(line).hexdigest()}
    assert len(found) == 5
    start = found['engine_episode_decision_started']; decision = found['engine_episode_decision']
    snapshot = start['snapshot']
    assert snapshot == decision['snapshot'] and snapshot['phase'] == 'pack'
    assert snapshot['completionist_goal']['counts'] == {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}
    assert found['engine_episode_action']['action'] == decision['result']['action']
    write('step12.json', {'snapshot': snapshot, 'origin': origin['engine_episode_decision_started']})
    write('historical_step12_receipts.json', {'origin': origin, 'action': found['engine_episode_action']['action'],
          'profile': found['engine_episode_profile'], 'resolved': found['engine_episode_resolved'],
          'pack_diagnostics': decision['result'].get('pack_diagnostics'),
          'note': 'Historical chosen Certificate and root-family rejection; no alternative route result.'})
    for old, new in (('registration.json', 'C05_registration.json'), ('record.json', 'C05_record.json'), ('audit.json', 'C05_audit.json')):
        with (HERE / new).open('xb') as stream:
            stream.write((C05 / old).read_bytes())
    for name in ('policy_wiring.lua', 'engine_contract.lua'):
        assert sha(HERE / name) == registration['files'][name]
    write('input_provenance.json', {'schema': 1, 'kind': 'prepared_M21_captured_inputs', 'source_attempt': 'C05', 'step': 12,
          'source_outcome': 'Ante1 Pillar loss592/600', 'source_files': {name: sha(C05 / name) for name in ('trace.log', 'record.json', 'registration.json', 'audit.json')},
          'origin': origin, 'state_fingerprint': start['state_fingerprint'],
          'snapshot_canonical_sha256': hashlib.sha256(canonical(snapshot)).hexdigest(), 'snapshot_file_sha256': sha(HERE / 'step12.json'),
          'source_provenance': provenance, 'gold_objective_context': audit['gold_objective_context'],
          'qualification': False, 'captured_policy_evaluated': False, 'source_initialized': False,
          'candidate_binding': 'Separate binding.json required after exact installed314 freeze exists.'})
    print('Prepared unchanged C05 step12 and historical provenance; no evaluation or registration')


def bind(candidate):
    candidate = Path(candidate).resolve()
    if candidate.name != 'pack314_installed':
        raise ValueError('Require exact frozen pack314_installed candidate')
    records = {}; bindings = {}
    for role, folder, expected_version in (('baseline', BASELINE, '2.112.0-alpha'), ('candidate', candidate, '2.114.0-alpha')):
        record = json.loads((folder / 'record.json').read_text())
        assert record['version'] == expected_version
        policy = record['policy']; files = policy['policy_files']
        assert hashlib.sha256(canonical(files)).hexdigest() == policy['policy_digest']
        for name, expected in files.items():
            assert sha(folder / 'policy' / name) == expected, name
        setup, omitted = module_setup((folder / 'policy/Brainstorm/Advisor/runtime.lua').read_bytes())
        for edge in (b'A.strategy.pack_survival = A.pack_survival', b'A.snapshot.certificate=A.certificate', b'A.snapshot.perkeo_inventory = A.perkeo_inventory'):
            assert edge in setup
        with (HERE / (role + '_module_setup.lua')).open('xb') as stream:
            stream.write(setup)
        with (HERE / (role + '_record.json')).open('xb') as stream:
            stream.write((folder / 'record.json').read_bytes())
        records[role] = record
        bindings[role] = {'installed_directory': str(folder), 'policy_root': str(folder / 'policy'),
                          'record_sha256': sha(folder / 'record.json'), 'policy_digest': policy['policy_digest'],
                          'runtime_source_sha256': files['Brainstorm/Advisor/runtime.lua'],
                          'module_setup_sha256': sha(HERE / (role + '_module_setup.lua')), 'omitted_product_integrations': omitted}
    left, right = [records[r]['policy']['policy_files'] for r in ('baseline', 'candidate')]
    assert records['baseline']['policy']['policy_digest'] == json.loads((HERE / 'input_provenance.json').read_text())['source_provenance']['policy_digest']
    write('binding.json', {'schema': 1, 'baseline_checkpoint': 312, 'candidate_checkpoint': 314, **bindings,
          'policy_changed_files': [name for name in sorted(set(left) | set(right)) if left.get(name) != right.get(name)],
          'registered': False, 'source_or_policy_evaluation': False,
          'decision_order': [['baseline', 12], ['candidate', 12]], 'per_decision_cap': 50000, 'aggregate_score_cap': 100000, 'outer_seconds': 30,
          'registration_requirement': 'Freeze all draft adapters, capture/provenance, whole baseline/candidate manifests and bytes plus exact Python/lua51 runtime hashes. Original game executable is provenance-only, never an M21 input or external file.'})
    print('Bound whole exact installed312/314 policies; no evaluation or registration')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--candidate-installed', type=Path)
    args = parser.parse_args()
    bind(args.candidate_installed) if args.candidate_installed else capture()
