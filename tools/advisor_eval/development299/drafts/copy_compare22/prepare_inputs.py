"""Create-only static provenance preparation; never evaluates policy or source Lua."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'
ROLES = {'baseline': 'pack314_installed', 'candidate': 'copy315_installed'}
DIGESTS = {'baseline': '40ce8ca5f3c5860cc377309fe3b4a1bb608a6332f4bed8484ee3e68a482eacc0',
           'candidate': 'e591f83e9b8bdcdbba288ff199836db12d40711d9b38b0df958c350bbbd0228f'}
STEPS = (31, 96)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def write(name, value):
    with (HERE / name).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def module_setup(raw):
    """Keep every installed initialization edge, omit product capture/live/retry integration."""
    text = raw.decode('utf-8')
    boundary = '\nfunction A.defaults()'
    if text.count(boundary) != 1:
        raise ValueError('Unknown installed runtime initialization boundary')
    prefix = text.split(boundary)[0]
    start = prefix.index('local function module(name)')
    end = prefix.index('\nA.snapshot, A.scoring, A.search, A.strategy')
    loader = "local function module(name)\n  assert(package.preload['probe_policy_'..name], 'Missing frozen module '..name)\n  return require('probe_policy_'..name)\nend\n"
    prefix = prefix[:start] + loader + prefix[end:]
    omitted = []
    for line in ("A.execution = module('execution')",
                 "A.retry_memory, A.retry_policy, A.retry_journal = module('retry_memory'), module('retry_policy'), module('retry_journal')",
                 'A.retry_generation, A.state_epoch = 0, 0',
                 'A.opening = Brainstorm.ChallengeOpening',
                 'A.jokerless_opening = Brainstorm.JokerlessOpening'):
        if prefix.count(line) != 1:
            raise ValueError('Unknown frozen product/retry initialization line: ' + line)
        prefix = prefix.replace(line, '-- Detached hand comparison omits: ' + line)
        omitted.append(line)
    if 'function A.defaults' in prefix or 'A.snapshot.capture(' in prefix or 'A.decision.run(' in prefix:
        raise ValueError('Setup reached capture or decision execution')
    return prefix.encode(), omitted


def main():
    prior = RUNS / 'gold299_20260914/C04'
    record = json.loads((prior / 'record.json').read_text())
    audit = json.loads((prior / 'audit.json').read_text())
    trace = prior / 'trace.log'
    assert record['trace_sha256'] == sha(trace)
    assert audit['disposition'] == 'timeout' and audit['completed_runs'] == 0
    setups, policies = {}, {}
    for role, directory in ROLES.items():
        installed = RUNS / directory
        rec = json.loads((installed / 'record.json').read_text())
        policy = rec['policy']
        assert policy['policy_digest'] == DIGESTS[role]
        assert hashlib.sha256(canonical(policy['policy_files'])).hexdigest() == DIGESTS[role]
        for name, expected in policy['policy_files'].items():
            assert sha(installed / 'policy' / name) == expected, name
        prefix, omitted = module_setup((installed / 'policy/Brainstorm/Advisor/runtime.lua').read_bytes())
        (HERE / (role + '_record.json')).open('xb').write((installed / 'record.json').read_bytes())
        (HERE / (role + '_module_setup.lua')).open('xb').write(prefix)
        setups[role] = {'installed_record_sha256': sha(installed / 'record.json'),
                       'runtime_sha256': policy['policy_files']['Brainstorm/Advisor/runtime.lua'],
                       'derived_setup_sha256': sha(HERE / (role + '_module_setup.lua')),
                       'omitted_product_integrations': omitted}
        policies[role] = policy['policy_files']
    (HERE / 'engine_contract.lua').open('xb').write((prior / 'engine_contract.lua').read_bytes())
    (HERE / 'lua_bytes.py').open('xb').write((HERE.parent / 'shop_order/lua_bytes.py').read_bytes())
    starts, completed, profiles, origins = {}, {}, {}, {}
    with trace.open('rb') as stream:
        for line_number, line in enumerate(stream, 1):
            if not line.startswith(b'{'):
                continue
            row = json.loads(line)
            step = row.get('step')
            if step not in STEPS:
                continue
            if row['type'] == 'engine_episode_decision_started':
                assert step not in starts
                starts[step] = row['snapshot']
                origins[step] = {'trace_line': line_number, 'trace_line_sha256': hashlib.sha256(line).hexdigest(),
                                 'state_fingerprint': row['state_fingerprint']}
            elif row['type'] == 'engine_episode_decision':
                completed[step] = row
            elif row['type'] == 'engine_episode_profile':
                profiles[step] = row
    assert set(starts) == set(completed) == set(profiles) == set(STEPS)
    for step, snapshot in starts.items():
        assert snapshot == completed[step]['snapshot'] and snapshot['phase'] == 'hand'
        assert len(snapshot['hand']) == 8
        assert snapshot['completionist_goal']['counts'] == {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}
        keys = [j['key'] for j in snapshot['jokers']]
        assert set(keys) == {'j_perkeo', 'j_yorick', 'j_brainstorm', 'j_droll', 'j_supernova'} and keys[0] == 'j_perkeo'
        assert all(not j.get('edition') and j.get('blueprint_compat') is True for j in snapshot['jokers'])
        result = completed[step]['result']
        assert result['action']['kind'] == 'reorder_jokers' and not result.get('mixed_rescue')
        write(f'step{step}.json', {'snapshot': snapshot, 'origin': origins[step]})
        origins[step].update(snapshot_canonical_sha256=hashlib.sha256(canonical(snapshot)).hexdigest(),
                             snapshot_file_sha256=sha(HERE / f'step{step}.json'), historical_profile=profiles[step],
                             static_selection={'hand_count': 8, 'joker_keys': keys,
                                'discards_left': snapshot['discards_left'], 'historical_action': result['action'],
                                'historical_evaluations': result['evaluations'], 'historical_ordering': result['ordering'],
                                'qualification': 'Static scope evidence only; neither new policy evaluated.'})
    changed = [key for key in sorted(set(policies['baseline']) | set(policies['candidate']))
               if policies['baseline'].get(key) != policies['candidate'].get(key)]
    write('input_provenance.json', {'schema': 1, 'kind': 'prepared_M22_captured_copy_inputs',
        'source_attempt': 'C04', 'source_outcome': 'timeout_censored_no_terminal_result',
        'source_files': {str((prior / name).relative_to(ROOT)): sha(prior / name)
                         for name in ('trace.log', 'record.json', 'registration.json', 'audit.json')},
        'source_policy_digest': audit['policy_digest'], 'source_adapter_digest': audit['provenance']['adapter_digest'],
        'source_runtime_digest': audit['provenance']['runtime_digest'], 'source_rules_digest': audit['provenance']['rules_digest'],
        'gold_objective_context': audit['provenance']['gold_objective_spec'],
        'profile_spec': audit['provenance']['profile_spec'], 'profile_spec_digest': audit['provenance']['profile_spec_digest'],
        'snapshots': origins, 'policy_digests': DIGESTS, 'module_setups': setups, 'changed_policy_files': changed,
        'selection_limit': 'Step185 has12held and is outside315 bound; selected31/96 are dependent development states.',
        'qualification': False, 'captured_policy_evaluated': False, 'source_initialized': False})
    print(json.dumps({'prepared_snapshots': STEPS, 'source_or_policy_evaluation': False,
                      'policy_digests': DIGESTS, 'changed_policy_files': changed}))


if __name__ == '__main__':
    main()
