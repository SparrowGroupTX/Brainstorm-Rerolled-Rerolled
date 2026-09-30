"""Read-only provenance extraction and create-only draft inputs; never evaluates Lua."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def write(name, value):
    with (HERE / name).open('x', encoding='utf-8') as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write('\n')


def module_setup(raw):
    """Preserve installed policy edges; replace only the product filesystem loader."""
    text = raw.decode('utf-8')
    boundary = '\nfunction A.defaults()'
    if text.count(boundary) != 1:
        raise ValueError('Unknown frozen runtime initialization boundary')
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
            raise ValueError('Unknown frozen live/retry line: ' + line)
        prefix = prefix.replace(line, '-- Detached hand comparison omits: ' + line)
        omitted.append(line)
    if 'function A.defaults' in prefix or 'A.snapshot.capture(' in prefix or 'A.decision.run(' in prefix:
        raise ValueError('Module setup reached product capture or evaluation')
    return prefix.encode(), omitted


def main():
    prior = RUNS / 'gold299_20260914/C04'
    record = json.loads((prior / 'record.json').read_text())
    audit = json.loads((prior / 'audit.json').read_text())
    trace = prior / 'trace.log'
    trace_hash = sha(trace)
    assert record['trace_sha256'] == trace_hash
    assert audit['disposition'] == 'timeout' and audit['completed_runs'] == 0
    installed = RUNS / 'certificate309_installed'
    baseline = json.loads((installed / 'record.json').read_text())
    manifest = baseline['policy']['policy_files']
    assert hashlib.sha256(canonical(manifest)).hexdigest() == baseline['policy']['policy_digest']
    for name, expected in manifest.items():
        assert sha(installed / 'policy' / name) == expected, name
    candidate_file = HERE.parent / 'cache_eviction/score_cache.lua'
    change = json.loads((HERE.parent / 'cache_eviction/manifest.json').read_text())
    cache_name = 'Brainstorm/Advisor/score_cache.lua'
    assert manifest[cache_name] == change['base_sha256'] and sha(candidate_file) == change['candidate_sha256']
    changed = dict(manifest, **{cache_name: change['candidate_sha256']})
    write('baseline_record.json', baseline)
    write('candidate_record.json', {'schema': 1, 'kind': 'detached_single_cache_substitution',
          'policy': {'policy_files': changed, 'policy_digest': hashlib.sha256(canonical(changed)).hexdigest()},
          'baseline_installed_record_sha256': sha(installed / 'record.json'),
          'only_changed_file': cache_name, 'installed': False, 'qualification': False})
    (HERE / 'candidate_score_cache.lua').open('xb').write(candidate_file.read_bytes())
    prefix, omitted = module_setup((installed / 'policy/Brainstorm/Advisor/runtime.lua').read_bytes())
    (HERE / 'module_setup.lua').open('xb').write(prefix)
    (HERE / 'engine_contract.lua').open('xb').write((prior / 'engine_contract.lua').read_bytes())
    (HERE / 'lua_bytes.py').open('xb').write((HERE.parent / 'shop_order/lua_bytes.py').read_bytes())
    found, completed, profile, origin = {}, {}, {}, {}
    with trace.open('rb') as handle:
        for number, line in enumerate(handle, 1):
            if not line.startswith(b'{'):
                continue
            row = json.loads(line)
            step = row.get('step')
            if step not in (85, 185):
                continue
            if row['type'] == 'engine_episode_decision_started':
                assert step not in found
                found[step] = row['snapshot']
                origin[step] = {'trace_line': number, 'trace_line_sha256': hashlib.sha256(line).hexdigest(),
                                'state_fingerprint': row['state_fingerprint']}
            elif row['type'] == 'engine_episode_decision':
                completed[step] = row['snapshot']
            elif row['type'] == 'engine_episode_profile':
                profile[step] = row
    assert set(found) == set(completed) == set(profile) == {85, 185}
    for step, snapshot in found.items():
        assert snapshot == completed[step] and snapshot['phase'] == 'hand'
        assert snapshot['completionist_goal']['counts'] == {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}
        write(f'step{step}.json', {'snapshot': snapshot, 'origin': origin[step]})
        origin[step].update(snapshot_canonical_sha256=hashlib.sha256(canonical(snapshot)).hexdigest(),
                            snapshot_file_sha256=sha(HERE / f'step{step}.json'),
                            historical_profile=profile[step])
    write('input_provenance.json', {'schema': 1, 'kind': 'prepared_M19_captured_inputs',
          'source_attempt': 'C04', 'source_outcome': 'timeout_censored_no_terminal_result',
          'source_files': {str((prior / name).relative_to(ROOT)): sha(prior / name)
                           for name in ('trace.log', 'record.json', 'registration.json', 'audit.json')},
          'source_policy_digest': audit['policy_digest'], 'source_adapter_digest': audit['provenance']['adapter_digest'],
          'source_runtime_digest': audit['provenance']['runtime_digest'],
          'source_rules_digest': audit['provenance']['rules_digest'],
          'gold_objective_context': audit['provenance']['gold_objective_spec'],
          'profile_spec': audit['provenance']['profile_spec'], 'profile_spec_digest': audit['provenance']['profile_spec_digest'],
          'snapshots': origin, 'baseline_policy_digest': baseline['policy']['policy_digest'],
          'candidate_policy_digest': hashlib.sha256(canonical(changed)).hexdigest(),
          'module_setup_parent_sha256': manifest['Brainstorm/Advisor/runtime.lua'],
          'module_setup_sha256': sha(HERE / 'module_setup.lua'), 'omitted_product_integrations': omitted,
          'qualification': False, 'captured_policy_evaluated': False, 'source_initialized': False})
    print(json.dumps({'prepared_snapshots': [85, 185], 'module_setup_derived': True,
                      'source_or_policy_evaluation': False, 'trace_sha256': trace_hash}))


if __name__ == '__main__':
    main()
