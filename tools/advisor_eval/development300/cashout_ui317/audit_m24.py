"""Independent frozen-file/excerpt audit. Never reopen the game ZIP or run Lua."""
from pathlib import Path
import hashlib
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT/'tools/advisor_eval/runs/gold299_20260914'
JOB = BASE/'M24'
REG = 'f96bb8f9dc95da8f0df59fdf4c4bf5373a2bfd76602ec3f38a6bb4f6036dc24d'
TRACE = '9234828576e033b7721b043370f8345db50821e58ae4f49feecabf4db8b05517'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def main():
    r, record, spent = [read(JOB/name) for name in ('registration.json', 'record.json', 'spent.json')]
    reservation = read(BASE/'M24_reservation.json')
    assert sha(JOB/'registration.json') == record['registration_sha256'] == spent['registration_sha256'] == REG
    assert sha(JOB/'trace.log') == record['trace_sha256'] == TRACE
    assert r['job'] == record['job'] == spent['job'] == reservation['job'] == 'M24'
    assert r['timeout_seconds'] == record['timeout_seconds'] == reservation['timeout_seconds'] == 30
    assert spent['one_use'] and record['one_use_spent'] and reservation['one_use']
    assert r['reservation_sha256'] == sha(BASE/'M24_reservation.json')
    assert r['authority_sha256'] == reservation['authority_sha256'] == sha(JOB/'authority.json')
    assert record['status'] == 'complete' and record['exit_code'] == 0 and 0 <= record['elapsed_seconds'] <= 30
    assert record['frozen_files_unchanged'] and record['external_files_unchanged']
    for name, expected in r['files'].items():
        assert sha(JOB/name) == expected, name
    policy = read(JOB/'installed_policy_record.json')['policy']
    final, validation = read(JOB/'installed_final_verification.json'), read(JOB/'installed_validation.json')
    assert digest(policy['policy_files']) == policy['policy_digest'] == r['metadata']['policy_digest']
    assert final['policy_digest'] == validation['policy_digest'] == policy['policy_digest']
    assert final['version'] == r['metadata']['policy_version'] == '2.116.0-alpha'
    assert final['installed_matches'] and final['native_unchanged']
    assert sha(JOB/'installed_validation.json') == final['installed_report']
    for name, expected in policy['policy_files'].items():
        assert r['files']['policy/'+name] == expected
    metadata = r['metadata']
    assert metadata['kind'] == 'cashout_ui_ownership_source_inspection_v1'
    for flag in ('source_execution', 'policy_execution', 'lua_runtime_loaded', 'native_search',
                 'game_process_access', 'player_file_access'):
        assert metadata[flag] is False
    assert metadata['maximum_members'] == 3 and metadata['maximum_methods'] == 6
    assert metadata['combined_output_cap_bytes'] == 40000 and metadata['source_excerpt_cap_bytes'] == 33000
    archive = metadata['source_archive']
    assert r['external_files'][archive] == metadata['expected_source_sha256']
    old = read(JOB/'prior_M23/registration.json')
    assert old['external_files'][archive] == metadata['expected_source_sha256']
    assert r['files']['source_lexer.py'] == old['files']['source_lexer.py']
    python_paths = [p for p in r['external_files'] if Path(p).name.lower() == 'python.exe']
    assert len(python_paths) == 1 and len(r['external_files']) == 2
    assert sha(Path(python_paths[0])) == r['external_files'][python_paths[0]]
    assert Path(r['command'][0]).resolve() == Path(python_paths[0]).resolve()
    assert r['command'][1:3] == ['-B', '-u'] and Path(r['command'][3]).resolve() == (JOB/'inspect_source.py').resolve()
    spec = importlib.util.spec_from_file_location('frozen_m24_lexer', JOB/'source_lexer.py')
    lexer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(lexer)
    inspection = read(JOB/'inspection/inspection.json')
    assert inspection['job'] == 'M24' and inspection['status'] == 'complete'
    assert inspection['complete_methods'] == len(inspection['methods']) == 6
    assert set(inspection['members']) == set(metadata['source_members'])
    methods, total = [], 0
    for method in inspection['methods']:
        assert method['complete_method'] and not method['truncated'] and method['status'] == 'found'
        path = JOB/'inspection'/method['excerpt_file']
        raw = path.read_bytes()
        assert len(raw) == method['shown_bytes'] == method['full_method_bytes']
        assert sha(path) == method['excerpt_sha256'] == method['full_method_sha256']
        boundary, body = lexer.excerpt(raw, method['declaration_pattern'], 1000000)
        assert boundary['status'] == 'found' and not boundary['truncated'] and body == raw
        assert method['end_line']-method['start_line']+1 == len(raw.splitlines())
        total += len(raw)
        methods.append({key: method[key] for key in ('name', 'source_member', 'start_line', 'end_line',
                                                     'full_method_bytes', 'full_method_sha256')})
    assert total == inspection['output_bytes'] == 6159 and total <= 33000
    output_total = sum(p.stat().st_size for p in (JOB/'inspection').iterdir())+(JOB/'trace.log').stat().st_size
    assert output_total <= 40000
    trace = read(JOB/'trace.log')
    assert trace['status'] == 'complete' and trace['complete_methods'] == 6 and trace['output_bytes'] == total
    for flag in ('source_execution', 'policy_execution', 'lua_runtime_loaded', 'native_search', 'game_or_save_access'):
        assert trace[flag] is False
    prior_ui = read(JOB/'prior_M23/inspection/inspection.json')['members']['engine/ui.lua']['sha256']
    prior_callbacks = read(JOB/'prior_M13_inspection.json')['members']['functions/button_callbacks.lua']['sha256']
    assert inspection['members']['engine/ui.lua']['sha256'] == prior_ui
    assert inspection['members']['functions/button_callbacks.lua']['sha256'] == prior_callbacks
    constructor = ROOT/'tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua'
    expected_constructor = read(JOB/'prior_M13_inspection.json')['members']['functions/common_events.lua']['sha256']
    assert sha(constructor) == expected_constructor
    result = dict(schema=1, job='M24', status='audited_complete_static_source_inspection',
                  registration_sha256=REG, trace_sha256=TRACE, record_sha256=sha(JOB/'record.json'),
                  elapsed_seconds=record['elapsed_seconds'], timeout_seconds=30, one_use_spent=True,
                  frozen_file_count=len(r['files']), policy_file_count=len(policy['policy_files']),
                  policy_digest=policy['policy_digest'], version='2.116.0-alpha',
                  inspection_sha256=sha(JOB/'inspection/inspection.json'), source_excerpt_bytes=total,
                  combined_output_bytes=output_total, complete_methods=methods, members=inspection['members'],
                  original_archive_provenance=dict(path=archive, sha256=metadata['expected_source_sha256'],
                      parent_record_pre_post_hashes_unchanged=True, independently_reopened_for_audit=False),
                  retained_constructor=dict(path=constructor.relative_to(ROOT).as_posix(), sha256=expected_constructor,
                                            start_line=1065, end_line=1093),
                  runtime_python_sha256=r['external_files'][python_paths[0]],
                  counts=dict(source_executions=0, policy_decisions=0, lua_states=0, native_searches=0, game_actions=0),
                  qualification=False,
                  limits=['Static source bytes only; no live resolver action or cash-out result.',
                          'Node.remove was not captured; no REMOVED-field or cascading detached-box cleanup proof.',
                          'get_UIE_by_ID searches its root children/embedded object trees; it does not search the global UIBox registry.',
                          'cash_out uses e.config.button, not e.UIBox; it removes G.round_eval in a queued callback.'])
    with (JOB/'audit.json').open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({'status': result['status'], 'audit_sha256': sha(JOB/'audit.json'),
                      'source_excerpt_bytes': total, 'combined_output_bytes': output_total}))


if __name__ == '__main__':
    main()
