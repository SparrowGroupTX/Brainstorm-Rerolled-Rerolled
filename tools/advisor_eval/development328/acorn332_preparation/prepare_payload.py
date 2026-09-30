"""Create detached review payloads only; never write the production tree."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(relative, data):
    target = HERE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as stream:
        stream.write(data)
    return target

def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)

def main():
    seals = [
        ('tools/advisor_eval/development328/acorn_belief_component',
         '67fcda98924892bac530fc8d0a8148d41c2c12414d5574531b9a51fc7e6f002b'),
        ('tools/advisor_eval/development328/acorn_public_component',
         '69ee2c6beae565b8e82b871cfb194802a956d8901242e357337fc5263bd9bfff'),
    ]
    for directory, expected in seals:
        manifest = ROOT / directory / 'manifest.json'
        assert sha(manifest) == expected
        for relative, entry in json.loads(manifest.read_text())['files'].items():
            assert sha(manifest.parent / relative) == (entry if isinstance(entry, str) else entry['sha256'])
    baseline_path = ROOT / 'tools/advisor_eval/runs/nine331_candidate/freeze.json'
    baseline = json.loads(baseline_path.read_text())
    assert baseline['policy_digest'] == '29f5f3112a7170c7a1181bde7ee91b436aa386ec7ff88145d4ed24b711807983'
    assert len(baseline['policy_files']) == 94
    for relative, expected in baseline['policy_files'].items():
        assert sha(ROOT / relative) == expected, relative
        assert sha(baseline_path.parent / 'policy' / relative) == expected, relative
    validation_path = baseline_path.parent / 'validation/report.json'
    validation = json.loads(validation_path.read_text())
    assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
    tests = {key.replace('\\', '/'): value for key, value in validation['test_files'].items()}
    for relative, expected in tests.items():
        assert sha(ROOT / relative) == expected, relative
    destinations = []

    def payload(relative, data, source=None):
        previous = ROOT / relative
        expected = sha(previous) if previous.exists() else None
        if relative.startswith('Brainstorm/'):
            assert expected == baseline['policy_files'].get(relative), relative
        if relative.startswith('tests/') and previous.exists():
            assert expected == tests[relative]
        target = save('payload/' + relative, data)
        destinations.append({'path': relative, 'before_sha256': expected,
                             'after_sha256': sha(target), 'bytes': len(data),
                             'source': source})

    belief = ROOT / seals[0][0]
    public = ROOT / seals[1][0]
    for name in ['acorn_belief.lua', 'acorn_ordering.lua', 'decision.lua']:
        source = belief / name
        payload('Brainstorm/Advisor/' + name, source.read_bytes(), source.relative_to(ROOT).as_posix())
    for name in ['acorn_public.lua', 'acorn_public_hooks.lua', 'execution.lua',
                 'gold_stickers.lua', 'runtime.lua', 'snapshot.lua']:
        source = public / 'Brainstorm/Advisor' / name
        payload('Brainstorm/Advisor/' + name, source.read_bytes(), source.relative_to(ROOT).as_posix())

    text = (belief / 'test_acorn_belief.lua').read_text()
    text = replace_once(text, "local path='tools/advisor_eval/development328/acorn_belief_component/'",
                        "local path='Brainstorm/Advisor/'")
    text = replace_once(text, "  local old=dofile(path..'acorn_ordering_before_reuse.lua')", """  -- Manufactured fresh-copy reference: current complete production planner,
  -- with a separate scoring input per call. No historical implementation reads.
  local old={suggest=function(s,b,scorer,belief,options)
    return O.suggest(s,b,{score=function(projected,indices)
      return scorer.score(belief.copy(projected),indices)
    end},belief,options)
  end}""")
    text = replace_once(text, "return tostring(checks)..' checks passed'",
                        "print('advisor_acorn_belief: '..checks..' checks passed')")
    assert 'development328' not in text and 'before_reuse' not in text
    payload('tests/advisor_acorn_belief.lua', text.encode('utf-8'), 'converted sealed belief fixture')

    text = (public / 'tests/advisor_acorn_public.lua').read_text()
    text = replace_once(text, "local base='tools/advisor_eval/development328/acorn_public_component/Brainstorm/Advisor/'",
                        "local base='Brainstorm/Advisor/'")
    text = replace_once(text, "local belief=dofile('tools/advisor_eval/development328/acorn_belief_component/acorn_belief.lua')",
                        "local belief=dofile(base..'acorn_belief.lua')")
    assert 'development328' not in text
    payload('tests/advisor_acorn_public.lua', text.encode('utf-8'), 'converted sealed public fixture')

    base_runtime = (ROOT / 'tests/advisor_runtime.lua').read_bytes()
    appended = (public / 'tests/runtime_public_append.lua').read_bytes()
    payload('tests/advisor_runtime.lua', base_runtime + b'\n-- Public Joker belief UI regression.\n' + appended,
            '331 runtime fixture plus sealed four-check UI appendix')

    text = (ROOT / 'tools/advisor_eval/component_profile.lua').read_text()
    text = replace_once(text, "'concealed_belief','work_cost'",
                        "'concealed_belief','acorn_belief','acorn_ordering','work_cost'")
    payload('tools/advisor_eval/component_profile.lua', text.encode('utf-8'),
            'inert pure-module map; no live observer or source adapter binding')

    spec = {
        'schema': 1, 'kind': 'unexecuted_root_integration_preparation',
        'expected_root': str(ROOT),
        'baseline': {'freeze_path': baseline_path.relative_to(ROOT).as_posix(),
                     'freeze_sha256': sha(baseline_path),
                     'policy_root': (baseline_path.parent / 'policy').relative_to(ROOT).as_posix(),
                     'policy_digest': baseline['policy_digest'], 'file_count': 94,
                     'validation_path': validation_path.relative_to(ROOT).as_posix(),
                     'validation_sha256': sha(validation_path)},
        'seals': [{'directory': directory, 'manifest_sha256': digest} for directory, digest in seals],
        'destinations': destinations,
        'protected_unchanged': {relative: sha(ROOT / relative) for relative in [
            'tools/advisor_eval/engine_run.lua', 'tests/run_lua_tests.py',
            'tools/advisor_eval/benchmark.py', 'tools/advisor_eval/install_slice.py']},
        'versions_stamped': False, 'experiments_run': 0, 'production_writes_performed_by_preparation': 0,
        'install_relative_files': [item['path'][len('Brainstorm/'):] for item in destinations
                                   if item['path'].startswith('Brainstorm/')],
    }
    save('spec.json', (json.dumps(spec, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({'prepared_files': len(destinations), 'runtime_files': 9,
                      'new_fixtures': 2, 'existing_fixture_append': 1,
                      'pure_module_map': 1, 'spec_sha256': sha(HERE / 'spec.json'),
                      'production_writes': 0}))

if __name__ == '__main__':
    main()
