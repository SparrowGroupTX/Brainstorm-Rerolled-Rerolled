"""Write compact detached review receipts only; no policy execution or staging."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def write(name, value):
    (HERE / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

write('preparation_error.json', {
    'schema': 1, 'kind': 'preparation_only', 'evaluation_started': False,
    'command': 'python -B tools/advisor_eval/development323/auto_observation/prepare.py',
    'exit_code': 1,
    'error': "prepare.py line43: assert prefix.endswith('end\\n'); AssertionError",
    'correction': 'Assert prefix.rstrip().endswith("end") to accept the existing fixture separator.',
    'earlier_detached_outputs': ['base/auto_run_product.lua', 'auto_run_product.lua'],
    'root_runtime_or_tests_modified': False,
})
write('validation.json', {
    'schema': 1, 'kind': 'routine_manufactured_lua_fixtures', 'exit_code': 0,
    'command': 'python -B tests/run_lua_tests.py tools/advisor_eval/development323/auto_observation/detached_test.lua tools/advisor_eval/development323/auto_observation/existing_fixtures.lua',
    'elapsed_tool_wall_seconds': 0.1885061, 'fixtures_passed': 2, 'fixtures_failed': 0,
    'checks': {'advisor_auto_observation': 301, 'advisor_auto_run_product': 202, 'advisor_auto_run': 312},
    'total_checks': 815,
    'runtime': 'C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll',
    'source_initialization': False, 'captured_replay': False, 'gameplay': False,
    'native_search': False, 'live_performance_measured': False,
})
base = json.loads((HERE / 'base_manifest.json').read_text(encoding='utf-8'))
assert all(sha(ROOT / name) == digest for name, digest in base['files'].items())
names = ['auto_run_product.lua', 'advisor_auto_observation.lua', 'focused_cases.lua',
         'fixture_prefix.lua', 'detached_test.lua', 'existing_fixtures.lua',
         'prepare.py', 'finalize.py', 'COMPONENT_NOTE.md', 'base_manifest.json',
         'base/auto_run_product.lua', 'validation.json', 'preparation_error.json']
write('integration_manifest.json', {
    'schema': 1, 'scope': 'detached prospective323; unstaged',
    'files': {name: sha(HERE / name) for name in names},
    'production_mapping': {
        'auto_run_product.lua': 'Brainstorm/Core/auto_run_product.lua',
        'advisor_auto_observation.lua': 'tests/advisor_auto_observation.lua',
    },
    'production_test_must_be_absent_before_stage': 'tests/advisor_auto_observation.lua',
    'dependencies_unchanged_at_finalization': True,
    'root_runtime_or_tests_modified': False,
    'experiments': 0,
})
print(json.dumps({'integration_manifest_sha256': sha(HERE / 'integration_manifest.json'),
                  'candidate_sha256': sha(HERE / 'auto_run_product.lua'),
                  'fixture_sha256': sha(HERE / 'advisor_auto_observation.lua')}))
