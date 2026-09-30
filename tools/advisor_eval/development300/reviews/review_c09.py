"""Independent final-bound C09 review; no registration, source or policy execution."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
HERE = ROOT / 'tools/advisor_eval/development300/complete_attempt9'
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'

def read(path):
    return json.loads(path.read_text(encoding='utf8'))

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

parser = argparse.ArgumentParser()
parser.add_argument('--expected-manifest', required=True)
parser.add_argument('--expected-policy', required=True)
parser.add_argument('--expected-final', required=True)
args = parser.parse_args()
manifest_path = HERE / 'preparation_manifest.json'
assert sha(manifest_path) == args.expected_manifest
manifest = read(manifest_path)
assert manifest['job'] == 'C09' and manifest['validation']['passed']
for name, expected in manifest['prepared_files'].items():
    assert sha(HERE / name) == expected, name
old = read(BASE / 'C07/registration.json')
origins = read(HERE / 'preparation_origins.json')
assert len(origins) == 16
for row in origins:
    name = row['file']
    assert sha(HERE / name) == row['source_sha256'] == row['prepared_sha256'] == old['files'][name]
    assert (HERE / name).read_bytes() == (BASE / 'C07' / name).read_bytes()
old_worker = (BASE / 'C07/run_attempt7.py').read_text()
expected_worker = old_worker.replace('C07', 'C09').replace('2.120.0-alpha', '2.121.0-alpha').replace('!= 320', '!= 321').replace("'previous_same_seed_attempt': 'C06'", "'previous_same_seed_attempt': 'C07'")
assert (HERE / 'run_attempt9.py').read_text() == expected_worker

binding = read(HERE / 'installed_binding.json')
assert binding['job'] == 'C09' and binding['checkpoint'] == 321 and binding['version'] == '2.121.0-alpha'
assert binding['policy_digest'] == args.expected_policy and binding['final_verification_sha256'] == args.expected_final
assert binding['registered'] is False and binding['reserved'] is False and binding['worker_executed'] is False
installed = Path(binding['installed_dir'])
record = read(installed / 'record.json')
assert sha(installed / 'record.json') == binding['installed_record_sha256']
assert record['version'] == binding['version']
pfiles = record['policy']['policy_files']
assert digest(pfiles) == record['policy']['policy_digest'] == args.expected_policy
for name, expected in pfiles.items():
    assert sha(installed / 'policy' / name) == expected, name
assert pfiles['Brainstorm/Advisor/growth.lua'] == binding['reviewed_growth_sha256'] == 'd0de330671d31888fb49c886326cc470274552645d616836ad3fb588c139d688'
for name, expected in binding['reviewed_feature_files'].items():
    assert pfiles[name] == expected
final_path = Path(binding['final_verification'])
assert sha(final_path) == args.expected_final
final = read(final_path)
validation_path = Path(binding['validation_report'])
validation = read(validation_path)
assert sha(validation_path) == binding['validation_sha256'] == final['installed_report']
assert final['version'] == binding['version'] and final['policy_digest'] == args.expected_policy
assert final['installed_matches'] and final['native_unchanged'] and final['config_restored_or_modified_by_finalizer'] is False
assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
assert validation['policy_digest'] == args.expected_policy and validation['policy_files'] == pfiles

graph = read(HERE / 'installed_graph_rebinding.json')
source_graph = read(BASE / 'C07/installed_graph_check.json')
assert sha(BASE / 'C07/installed_graph_check.json') == old['files']['installed_graph_check.json'] == graph['source_graph_receipt_sha256']
assert graph['source_registration_sha256'] == sha(BASE / 'C07/registration.json')
assert sha(BASE / 'C07/inert_graph_raw.json') == graph['raw_report_sha256'] == source_graph['raw_report_sha256']
assert sha(BASE / 'C07/inert_graph_stdout.log') == graph['stdout_sha256'] == source_graph['stdout_sha256']
assert graph['graph'] == source_graph['graph'] == read(BASE / 'C07/inert_graph_raw.json')
assert graph['kind'] == 'c09_static_graph_rebinding_v1' and graph['passed']
assert len(graph['graph']['modules']) == 49 and len(graph['graph']['connections']) == 40
assert graph['source_initializations'] == graph['policy_decisions'] == graph['new_inert_graph_executions'] == 0
assert graph['policy_digest'] == args.expected_policy and graph['policy_files'] == pfiles
assert graph['adapter_files'] == source_graph['adapter_files']
for name, expected in graph['adapter_files'].items():
    assert sha(HERE / name) == expected == old['files'][name]
runtime_name = 'Brainstorm/Advisor/runtime.lua'
old_runtime = (BASE / 'C07/policy' / runtime_name).read_bytes()
new_runtime = (installed / 'policy' / runtime_name).read_bytes()
marker = b'function A.defaults()'
assert old_runtime.count(marker) == new_runtime.count(marker) == 1
prefix = new_runtime.split(marker)[0]
assert prefix == old_runtime.split(marker)[0]
assert hashlib.sha256(prefix).hexdigest() == graph['runtime_prefix_sha256']
assert len(prefix) == graph['runtime_prefix_bytes'] and graph['runtime_prefix_equal']
old_files = source_graph['policy_files']
assert set(old_files) == set(pfiles)
changed = [name for name in pfiles if old_files[name] != pfiles[name]]
assert set(changed) == {'Brainstorm/Advisor/growth.lua', 'Brainstorm/Core/Brainstorm.lua',
                        'Brainstorm/steamodded_compat.lua'}, changed
for name in changed:
    if name != 'Brainstorm/Advisor/growth.lua':
        old_text = (BASE / 'C07/policy' / name).read_text()
        new_text = (installed / 'policy' / name).read_text()
        assert old_text.replace('2.120.0-alpha', '2.121.0-alpha').replace('2.120', '2.121') == new_text

authority = read(BASE / 'authority.json')
assert authority['status'] == 'APPROVED' and authority['per_job_caps']['C09'] == 180
assert authority['expires_at_utc'] == '2026-09-14T22:40:00+00:00'
deadline = datetime.fromisoformat(authority['expires_at_utc']).timestamp()
review_time = datetime.now(timezone.utc)
authority_expired = review_time.timestamp() + 180 > deadline
assert authority_expired, 'Final disposition is specifically the prepared but expired package'
assert not (BASE / 'C09').exists() and not (BASE / 'C09_reservation.json').exists()
assert all((path.parent / 'record.json').exists() for path in BASE.glob('*/spent.json'))
selection = read(HERE / 'normal_seed_selection.json')
recipe = read(HERE / 'normal_opening_recipe.json')
assert recipe['seed'] == selection['seed'] == 'M4BVSY11'
assert recipe['deck'] == 'b_red' and recipe['stake'] == 8
assert recipe['discovery']['job'] == selection['source_search_job'] == 'S04'
for name, expected in selection['search_evidence'].items():
    assert sha(BASE / 'S04' / name) == expected
prior_refs = read(HERE / 'prior_audits.json')
for job, row in prior_refs.items():
    path = Path(row['original_path'])
    assert path.resolve() == (BASE / job / row['filename']).resolve()
    assert sha(path) == row['sha256']
    audit = read(path)
    assert audit['disposition'] == row['disposition']
    assert not audit['audit_issues'] and not row['audit_issues']
    for name in ('record', 'registration'):
        assert sha(BASE / job / (name + '.json')) == row[name + '_sha256'] == audit[name + '_sha256']
    assert read(BASE / job / 'record.json')['trace_sha256'] == row['trace_sha256'] == audit['trace_sha256']
    if row['selected_pointer_path']:
        pointer = Path(row['selected_pointer_path'])
        assert sha(pointer) == row['selected_pointer_sha256']
        selected = read(pointer)
        assert selected['filename'] == row['filename'] and selected['sha256'] == row['sha256']
    del audit
assert prior_refs['C07']['disposition'] == 'timeout' and prior_refs['C08']['disposition'] == 'loss'

receipt = {'schema': 1, 'kind': 'independent_c09_final_bound_package_review',
           'created_utc': datetime.now(timezone.utc).isoformat(),
           'conclusion': 'package_checks_pass_but_authority_expired_do_not_register_or_run',
           'preparation_manifest_sha256': args.expected_manifest,
           'policy_digest': args.expected_policy, 'final_verification_sha256': args.expected_final,
           'installed_binding_sha256': sha(HERE / 'installed_binding.json'),
           'graph_rebinding_sha256': sha(HERE / 'installed_graph_rebinding.json'),
           'prepared_file_count': len(manifest['prepared_files']), 'unchanged_C07_origins': len(origins),
           'installed_policy_file_count': len(pfiles), 'changed_policy_files_from_C07': changed,
           'worker_diff': 'Only job/version/checkpoint guards and previous-attempt label.',
           'prior_audits': 'Compact references rehashed against original authoritative C07/C08 audits, records, registrations and selected C08 pointer; no prior states enter the worker.',
           'source_dispatch': 'Exact unchanged C07 adapter; new Lua state and original start_run, fixed 500 loop, no replay/scenario/native search arguments.',
           'graph_scope': 'Existing49-module40-edge inert graph statically rebound under exact initialization-prefix and adapter/checker equality; no new graph or source execution.',
           'experiment_limits': {'job': 'C09', 'outer_seconds': 180, 'max_actions': 500,
                                 'seed': 'M4BVSY11', 'deck': 'b_red', 'stake': 8,
                                 'fresh_synthetic_missing': 150, 'retry_enabled': False},
           'authority_status': {'expired': authority_expired, 'deadline_utc': authority['expires_at_utc'],
                                'checked_at_utc': review_time.isoformat(),
                                'registered': False, 'reserved': False, 'attempt_result': None},
           'independent_validation': {'python_setup_tests': 7, 'compile_only_Lua_chunks': 7,
                                      'source_policy_or_graph_executions': 0,
                                      'first_review_deadline_check': 'Failed the required full-cap-before-deadline assertion; no receipt or experiment was created. This receipt preserves that blocking condition.'},
           'restrictions': ['No registration, reservation, worker, policy or source execution by this review.',
                            'Selected dependent development; no isolated causal, win-rate, unseen or product-UI qualification.',
                            'C09 remains a prepared package with no attempt result. The expired allowance must not be reused or renewed.']}
target = Path(__file__).with_suffix('.json')
with target.open('x', encoding='utf8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print(json.dumps({'receipt': target.relative_to(ROOT).as_posix(), 'sha256': sha(target),
                  'prepared_files': len(manifest['prepared_files']), 'policy_files': len(pfiles),
                  'changed_policy_files': changed, 'conclusion': receipt['conclusion']}))
