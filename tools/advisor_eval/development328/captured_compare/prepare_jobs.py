"""Prepare frozen-input maps only. Never registers, reserves or executes a job."""
from pathlib import Path
import hashlib
import json
import sys
from module_graph import module_setup
from compare_public import canonical, sha, read, write, validate_snapshot, MAX_ROLE_BYTES, MAX_TOTAL_BYTES

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EVAL = ROOT / 'tools/advisor_eval'
ROLES = {'baseline': EVAL / 'runs/log327_installed', 'candidate': EVAL / 'runs/shop329_installed'}
RECIPE = [('P01', 3, 2722), ('P02', 4, 3282), ('P03', 5, 3829)]
REQUIRED = ('compare_public.py', 'driver.lua', 'module_graph.py', 'lua_bytes.py', 'policy_wiring.lua', 'engine_contract.lua')

def main():
    destination = HERE / 'prepared'
    destination.mkdir(exist_ok=False)
    frozen = {}
    for role, installed in ROLES.items():
        record = read(installed / 'record.json'); policy = record['policy']
        assert hashlib.sha256(canonical(policy['policy_files'])).hexdigest() == policy['policy_digest']
        policy_root = installed / 'policy'
        for name, expected in policy['policy_files'].items():
            assert sha(policy_root / name) == expected, role + '/' + name
        setup, omitted = module_setup((policy_root / 'Brainstorm/Advisor/runtime.lua').read_bytes())
        with (destination / (role + '_module_setup.lua')).open('xb') as stream:
            stream.write(setup)
        frozen[role] = {'root': policy_root, 'policy': policy, 'record': installed / 'record.json', 'omitted': omitted}
    for job, run, sequence in RECIPE:
        trace_path = EVAL / ('development328/public_trace/run%d.json' % run)
        trace = read(trace_path)
        event = next(item for item in trace['events'] if item['sequence'] == sequence)
        assert event['kind'] == 'action_attempt'
        snapshot_path = trace_path.parent / event['snapshot']
        snapshot = read(snapshot_path); cap = validate_snapshot(snapshot)
        origin = {'schema': 1, 'kind': 'redacted_public_snapshot328', 'raw_fingerprint_used': False,
                  'sequence': sequence, 'run_number': run, 'snapshot_sha256': sha(snapshot_path),
                  'snapshot_canonical_sha256': hashlib.sha256(canonical(snapshot)).hexdigest(),
                  'source_snapshot_path': snapshot_path.relative_to(ROOT).as_posix(),
                  'source_trace_path': trace_path.relative_to(ROOT).as_posix(), 'source_trace_sha256': sha(trace_path),
                  'event_sha256': event['event_sha256'], 'recorded_action': event['advice'].get('action'),
                  'source_execution': False, 'snapshot_transformations': [],
                  'scope': 'Exact redacted context.snapshot; no missing public field or hidden fingerprint state reconstructed.'}
        provenance_path = destination / (job + '_input_provenance.json'); write(provenance_path, origin)
        files = {name: str(HERE / name) for name in REQUIRED}
        files.update({'authority.json': str(EVAL / 'runs/loss328_validation_20260915/authority.json'),
                      'snapshot.json': str(snapshot_path), 'input_provenance.json': str(provenance_path)})
        policies = {}
        for role, value in frozen.items():
            files[role + '_record.json'] = str(value['record'])
            files[role + '_module_setup.lua'] = str(destination / (role + '_module_setup.lua'))
            for name in value['policy']['policy_files']:
                files[role + '/' + name] = str(value['root'] / name)
            policies[role] = {'root': role, 'record': role + '_record.json', 'setup': role + '_module_setup.lua',
                              'policy_digest': value['policy']['policy_digest']}
        metadata = {'kind': 'public_state_pair', 'decision_order': ['baseline', 'candidate'],
                    'source_execution': False, 'action_dispatch': False, 'selected_action_rescore': False,
                    'input': {'path': 'snapshot.json', 'sha256': origin['snapshot_sha256'],
                              'phase': snapshot['phase'], 'sequence': sequence},
                    'policies': policies, 'score_caps': {role: cap for role in ROLES}, 'total_score_cap': cap * 2,
                    'max_output_bytes_per_role': MAX_ROLE_BYTES, 'max_output_bytes_total': MAX_TOTAL_BYTES,
                    'hypothesis': {2722: 'Retained-Purple admission permits supported remaining-blind comparison without inventing Tarot outcomes.',
                                   3282: 'Compare revised shop ratings on supplied public Blueprint offer; missing shop_forecast remains missing.',
                                   3829: 'Compare whole-inventory shop replacement safeguards before recorded Perkeo sale; missing forecasts remain missing.'}[sequence],
                    'limitations': 'Single dependent redacted public state; no source initialization, action dispatch, later continuation or terminal evidence.'}
        spec = {'job': job, 'files': files, 'metadata': metadata,
                'command': [str(Path(sys.executable).resolve()), '{job}/compare_public.py'],
                'external': [str(Path(sys.executable).resolve()), 'C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll'],
                'preparation_only': True}
        write(destination / (job + '_registration_inputs.json'), spec)
    write(destination / 'manifest.json', {'schema': 1, 'preparation_only': True, 'registered_jobs': 0, 'executed_jobs': 0,
          'files': {p.relative_to(HERE).as_posix(): sha(p) for p in sorted(destination.iterdir()) if p.is_file()},
          'adapter_files': {name: sha(HERE / name) for name in REQUIRED},
          'test_harness': sha(HERE / 'test_harness.py')})
    print(json.dumps({'prepared_jobs': [r[0] for r in RECIPE], 'registered': 0, 'executed': 0,
                      'manifest_sha256': sha(destination / 'manifest.json')}))

if __name__ == '__main__':
    main()
