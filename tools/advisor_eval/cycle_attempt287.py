"""Four newly authorized, one-use development attempts; no historical admission.

The only child is a frozen Python source adapter. Balatro.exe is data, never a
command. No save access, native seed search, replay, checkpoint or live control.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
REPOSITORY = HERE.parents[1]
BASELINE_DIGEST = '85cb3c96b767067cf545f9a77ab01ee9a24e797424b557bea23637ab3237cbc3'
BASELINE_RECORD = REPOSITORY / 'tools/advisor_eval/runs/search286_installed/record.json'
STARTS = {
    'TO6O4111': ('10_dependent279_to6o',
        '982dad26064d42c1fca55c51b3c7004a076273849d2ff61c07eaf89a4982eede',
        '3b10baf94fb0e374d19aa517c4de7598993a63ca921d182f48e30daab1bd9b6e'),
    'P83R7111': ('11_dependent280_p83r',
        'b146cadb2a236111c3dbe6ae6342be87efd9375281008a8127e11089a6bb8ea3',
        '15d1db9cfac2a6451e4935724e204cbdc796926b884ef47f09a9da3237ee8943')}
SEEDS = {'C1': 'TO6O4111', 'C2': 'P83R7111', 'C3': 'TO6O4111', 'C4': 'P83R7111'}
ADAPTERS = ('engine_probe.py', 'engine_probe.lua', 'engine_run.lua', 'engine_contract.lua',
            'opening_support.py', 'benchmark.py', 'development_report.py')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'),
                      parse_constant=lambda x: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def create(path, value):
    with Path(path).open('x', encoding='utf-8') as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write('\n')


def authority(path, job, admission=True):
    a = read(path)
    if (a.get('kind') != 'prospective287_authority' or a.get('status') != 'APPROVED'
            or a.get('approved_by') != 'user' or a.get('replacements') != 0
            or not a.get('approval_reference')
            or a.get('serial_only') is not True or job not in SEEDS
            or job not in a.get('allowed_job_ids', []) or a['per_job_caps'].get(job) != 180):
        raise ValueError('Require fresh fixed C1..C4 authority')
    expires = datetime.fromisoformat(a['expires_at_utc'])
    if expires.tzinfo is None:
        raise ValueError('Authority deadline requires a timezone')
    if admission and expires.timestamp() < time.time() + 180:
        raise ValueError('Full attempt cap no longer fits authority deadline')
    if not Path(a['ledger_directory']).is_absolute():
        raise ValueError('Authority ledger must be absolute')
    return a


def modules(folder):
    # Do not accidentally reuse a previously imported worktree/baseline module
    # when registration is called from a Python coordinator more than once.
    names = ('engine_probe', 'benchmark', 'opening_support', 'development_report')
    previous = {name: sys.modules.pop(name, None) for name in names}
    old_path = list(sys.path); old_bytecode = sys.dont_write_bytecode
    try:
        sys.path.insert(0, str(folder)); sys.dont_write_bytecode = True
        from engine_probe import profile_spec, retry_context_spec, selection_record, jokerless_recipe_record, applied_retry_context
        from benchmark import policy_hashes
        from development_report import episode_record, parse_trace
        return {key: value for key, value in locals().items() if key in
                ('profile_spec', 'retry_context_spec', 'selection_record', 'jokerless_recipe_record',
                 'applied_retry_context', 'policy_hashes', 'episode_record', 'parse_trace')}
    finally:
        sys.path[:] = old_path; sys.dont_write_bytecode = old_bytecode
        for name in names:
            sys.modules.pop(name, None)
            if previous[name] is not None: sys.modules[name] = previous[name]


def checked_policy(job, root, record_path, policy_files, ledger):
    root, record_path = Path(root).resolve(), Path(record_path).resolve()
    record = read(record_path); policy_digest = digest(policy_files)
    if root != record_path.parent / 'policy' or record_path.name != 'record.json':
        raise ValueError('Require the exact checkpoint record and its adjacent frozen policy')
    if record.get('policy') != {'policy_files': policy_files, 'policy_digest': policy_digest}:
        raise ValueError('Policy does not match its installed checkpoint')
    if job in ('C1', 'C2'):
        if policy_digest != BASELINE_DIGEST or record_path != BASELINE_RECORD.resolve() or record.get('version') != '2.86.0-alpha':
            raise ValueError('Baseline must be exact installed286 checkpoint record')
    else:
        if policy_digest == BASELINE_DIGEST or record.get('version') in (None, '2.86.0-alpha'):
            raise ValueError('Candidate must be a distinct installed runtime checkpoint')
        if job == 'C4':
            candidate = read(ledger / 'C3/registration.json')
            if (candidate['policy_digest'] != policy_digest or candidate['policy_record'] != str(record_path) or
                    candidate['policy_record_sha256'] != sha(record_path)):
                raise ValueError('C3/C4 must share the same frozen candidate checkpoint')
    return record


def checked_start(seed, recipe, selection):
    folder, recipe_hash, selection_hash = STARTS[seed]
    original = REPOSITORY / 'tools/advisor_eval/runs/jokerless271_push_20260912_214242/source_attempts' / folder
    for supplied, filename, expected in ((recipe, 'opening_recipe.json', recipe_hash),
                                         (selection, 'selection_evidence.json', selection_hash)):
        if Path(supplied).resolve() != original / filename or sha(supplied) != expected:
            raise ValueError('Attempt must preserve its declared original recipe and selection')


def register(args):
    ap = args.authority.resolve(); a = authority(ap, args.job)
    ledger = Path(a['ledger_directory']).resolve(); directory = ledger / args.job
    checked_start(SEEDS[args.job], args.recipe, args.selection)
    if args.job in ('C3', 'C4'):
        # A planned candidate comparison, never a replacement for a spent slot.
        for predecessor in ('C1', 'C2'):
            if not (ledger / predecessor / 'record.json').is_file():
                raise ValueError('Both baseline attempts must be recorded before candidate admission')
    create(ledger / (args.job + '_reservation.json'), {'job_id': args.job, 'authority_sha256': sha(ap),
           'timeout_seconds': 180, 'one_use': True, 'created_at_utc': datetime.now(timezone.utc).isoformat()})
    directory.mkdir(exist_ok=False)
    adapter = directory / 'adapter'; adapter.mkdir()
    for name in ADAPTERS:
        shutil.copyfile(HERE / name, adapter / name)
    shutil.copyfile(Path(__file__), directory / 'cycle_attempt287.py')
    m = modules(adapter); policy_files = m['policy_hashes'](args.policy)
    checked_policy(args.job, args.policy, args.policy_record, policy_files, ledger)
    for relative, expected in policy_files.items():
        target = directory / 'policy' / relative; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.policy / relative, target)
        if sha(target) != expected:
            raise ValueError('Policy changed while freezing')
    policy_digest = digest(policy_files)
    for name, source in [('opening_recipe.json', args.recipe), ('selection_source.json', args.selection)]:
        shutil.copyfile(source, directory / name)
    seed = SEEDS[args.job]
    create(directory / 'selection_evidence.json', {'schema': 1, 'kind': 'declared_selected_development_seed',
           'seed': seed, 'qualification': False, 'source_evidence_digest': sha(directory / 'selection_source.json'),
           'source_evidence_path': str(args.selection.resolve()), 'hypothesis': args.hypothesis,
           'relationship': 'previously studied dependent development seed, no population inference'})
    selection = m['selection_record'](directory / 'selection_evidence.json', seed)
    recipe = m['jokerless_recipe_record'](directory / 'opening_recipe.json', seed)
    install = args.install.resolve()
    command = [sys.executable, '-B', '-u', str(adapter / 'engine_probe.py'), '--episode', '--install', str(install),
               '--policy-root', str(directory / 'policy'), '--challenge', 'c_jokerless_1', '--seed', seed,
               '--unlock-profile', 'all_unlocked_discovered_v1', '--debug-decisions',
               '--seed-selection-evidence', str(directory / 'selection_evidence.json'),
               '--jokerless-opening-recipe', str(directory / 'opening_recipe.json')]
    source_adapter = {name: sha(adapter / name) for name in ADAPTERS if name != 'development_report.py'}
    profile = m['profile_spec']('all_unlocked_discovered_v1'); retry = m['retry_context_spec']()
    r = {'schema': 1, 'kind': 'prospective287_complete_attempt', 'job_id': args.job, 'authority': str(ap),
         'authority_sha256': sha(ap), 'timeout_seconds': 180, 'seed': seed, 'challenge': 'c_jokerless_1',
         'reservation_sha256': sha(ledger / (args.job + '_reservation.json')),
         'hypothesis': args.hypothesis, 'policy_files': policy_files, 'policy_digest': policy_digest,
         'policy_record': str(args.policy_record.resolve()), 'policy_record_sha256': sha(args.policy_record),
         'rules_digest': sha(install / 'Balatro.exe'), 'runtime_digest': sha(install / 'lua51.dll'),
         'adapter_digest': digest(source_adapter), 'profile_spec': profile, 'profile_spec_digest': digest(profile),
         'retry_context_spec': retry, 'retry_context_spec_digest': digest(retry),
         'seed_selection': selection, 'jokerless_opening': recipe,
         'start_distribution': {'kind': 'jokerless_coupon_blue_v1', 'seed_selection': 'declared_development_selection',
                                'selection_evidence_digest': selection['evidence_digest'], 'recipe_digest': recipe['recipe_digest']},
         'command': command, 'frozen_files': {str(p.relative_to(directory)): sha(p) for p in directory.rglob('*') if p.is_file()},
         'full_episode_requested': True, 'adapter_action_cap': 500, 'qualification': False,
         'source_control': 'ZIP only; no executable launch', 'saves': 'none', 'native_seed_search': False,
         'created_at_utc': datetime.now(timezone.utc).isoformat()}
    if args.job != 'C1':
        baseline = read(ledger / 'C1/registration.json')
        for key in ('adapter_digest', 'rules_digest', 'runtime_digest', 'profile_spec_digest', 'retry_context_spec_digest'):
            if r[key] != baseline[key]:
                raise ValueError('Paired attempts must preserve common adapter/source/runtime/profile: ' + key)
    r['registration_digest'] = digest(r)
    create(directory / 'registration.json', r)
    return r


def verify(directory, admission=False):
    directory = Path(directory).resolve()
    r = read(directory / 'registration.json'); unsigned = dict(r); claimed = unsigned.pop('registration_digest')
    if digest(unsigned) != claimed or sha(r['authority']) != r['authority_sha256']:
        raise ValueError('Registration or authority changed')
    a = authority(r['authority'], r['job_id'], admission=admission)
    if directory.resolve() != Path(a['ledger_directory']).resolve() / r['job_id']:
        raise ValueError('Authority is bound to one job directory')
    if sha(directory.parent / (r['job_id'] + '_reservation.json')) != r['reservation_sha256']:
        raise ValueError('One-use authority reservation changed')
    for relative, expected in r['frozen_files'].items():
        path = (directory / relative).resolve(); path.relative_to(directory.resolve())
        if sha(path) != expected:
            raise ValueError('Frozen input changed: ' + relative)
    if sha(r['policy_record']) != r['policy_record_sha256']:
        raise ValueError('Checkpoint record changed')
    if sha(Path(__file__)) != r['frozen_files']['cycle_attempt287.py']:
        raise ValueError('Coordinator differs from its frozen registered bytes')
    if (r['seed'] != SEEDS[r['job_id']] or r['timeout_seconds'] != 180 or
            r['adapter_action_cap'] != 500 or r['challenge'] != 'c_jokerless_1'):
        raise ValueError('Registered seed/challenge/action/time cap changed')
    install = Path(r['command'][r['command'].index('--install') + 1])
    if sha(install / 'Balatro.exe') != r['rules_digest'] or sha(install / 'lua51.dll') != r['runtime_digest']:
        raise ValueError('Source/runtime changed')
    return r


def bounded_process(command, log, started, seconds):
    deadline = started + seconds
    with Path(log).open('x', encoding='utf-8') as stream:
        try:
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            try:
                return process.wait(timeout=max(0, deadline - time.perf_counter()))
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(); return 'timeout'
            except BaseException:
                process.kill(); process.wait(); raise
        except OSError as error:
            stream.write(str(error)); return 'launch_error'


def execute(directory):
    directory = Path(directory).resolve(); r = verify(directory, admission=True)
    create(directory / 'execution.json', {'job_id': r['job_id'], 'registration_digest': r['registration_digest'],
           'one_use': True, 'coordinator_pid': os.getpid(), 'started_at_utc': datetime.now(timezone.utc).isoformat()})
    started = time.perf_counter(); code = bounded_process(r['command'], directory / 'attempt.log', started, 180)
    elapsed = time.perf_counter() - started
    m = modules(directory / 'adapter')
    result = m['episode_record'](directory / 'attempt.log', r['challenge'], r['seed'], code, elapsed, r['command'])
    create(directory / 'raw_record.json', result)
    errors = []
    try:
        verify(directory)
        rows, parse_errors = m['parse_trace'](directory / 'attempt.log')
        p = result['provenance']
        for key in ('challenge', 'seed', 'policy_files', 'policy_digest', 'rules_digest', 'runtime_digest',
                    'adapter_digest', 'start_distribution', 'profile_spec', 'profile_spec_digest',
                    'retry_context_spec', 'retry_context_spec_digest', 'seed_selection', 'jokerless_opening'):
            if p.get(key) != r[key]: raise ValueError('Trace differs from registration: ' + key)
        if parse_errors or sum(row.get('type') == 'engine_probe_provenance' for row in rows) != 1:
            raise ValueError('Incomplete/nonunique trace provenance')
        if p.get('counterfactual') or p.get('followed_advice') is False or p.get('opening_policy_loaded') is not True:
            raise ValueError('Expected autonomous frozen opening advice')
        receipts = [row for row in rows if row.get('type') == 'engine_jokerless_opening_initialized']
        if (len(receipts) != 1 or receipts[0].get('recipe_digest') != r['jokerless_opening']['recipe_digest']
                or receipts[0].get('policy_module_loaded') is not True
                or receipts[0].get('source_catalog_prediction_matched') is not True
                or receipts[0].get('policy_module_digest') != r['policy_files']['Brainstorm/Core/jokerless_opening.lua']):
            raise ValueError('Missing or inconsistent opening activation receipt')
        result['retry_context'] = m['applied_retry_context'](rows, p, r['retry_context_spec'])
        if not result['unlock_profile'] or result['unlock_profile'].get('declared_scope_verified') is not True:
            raise ValueError('Synthetic profile not applied as registered')
    except Exception as error:
        errors.append(str(error))
    if errors and result['outcome'] in ('win', 'loss', 'censored'):
        result.update(observed_outcome=result['outcome'], outcome='error', reason='frozen_provenance_audit_failed')
    result.update(job_id=r['job_id'], audit_errors=errors, provenance_verified=not errors,
                  registration_digest=r['registration_digest'], selected_development=True, qualification=False,
                  worker_deadline_overshoot_seconds=max(0, elapsed - 180))
    create(directory / 'record.json', result)
    return {k: result[k] for k in ('job_id', 'outcome', 'reason', 'elapsed_seconds', 'audit_errors', 'terminal')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('register', 'execute'))
    parser.add_argument('--authority', type=Path); parser.add_argument('--job', choices=tuple(SEEDS))
    parser.add_argument('--policy', type=Path); parser.add_argument('--policy-record', type=Path)
    parser.add_argument('--recipe', type=Path); parser.add_argument('--selection', type=Path)
    parser.add_argument('--install', type=Path); parser.add_argument('--hypothesis')
    parser.add_argument('--directory', type=Path)
    args = parser.parse_args()
    result = register(args) if args.mode == 'register' else execute(args.directory)
    print(json.dumps(result))


if __name__ == '__main__': main()
