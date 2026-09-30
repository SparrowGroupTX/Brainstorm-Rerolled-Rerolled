"""S05 preregistration only. Root supplies exact installed301 policy record.

Executing this script spends the S05 reservation; it never dispatches the job.
"""
from pathlib import Path
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'tools/advisor_eval/development299'))
from cycle import BASE, register, read, create, sha
from spec import request, NATIVE_NAME, NATIVE_SHA256

def main():
    if len(sys.argv) != 2:
        raise SystemExit('Usage: register.py EXACT_INSTALLED_301_RECORD.json')
    record_path = Path(sys.argv[1]).resolve()
    record = read(record_path);policy = record_path.parent/'policy'
    q = request()
    native_relative = 'Brainstorm/' + NATIVE_NAME
    if record['policy']['policy_files'].get(native_relative) != NATIVE_SHA256:
        raise ValueError('The supplied frozen policy does not bind the new301 native sidecar')
    prior = BASE/'S04';old = read(prior/'registration.json')
    # Freeze already-audited native sources, dependencies and build provenance.
    # None of the prior worker/request/evidence or spent authority is reused.
    files = {name: prior/name for name in old['files'] if
             name.startswith(('Immolate/', 'build_receipts/', 'bin/')) and not name.endswith('.exe') and
             name != 'bin/Immolate.dll'}
    files['bin/'+NATIVE_NAME] = policy/native_relative
    files.update({'worker.py': HERE/'worker.py', 'spec.py': HERE/'spec.py',
                  'installed_policy_record.json': record_path,
                  'profile_assumption.json': HERE/'profile_assumption.json'})
    # Exact frozen deployed request/facade/runtime are retained as provenance;
    # the native worker does not run Lua or invoke product UI/game callbacks.
    for name in ['Brainstorm/Advisor/collection_search.lua', 'Brainstorm/Core/collection_search_product.lua',
                 'Brainstorm/Core/collection_search_runtime.lua', 'Brainstorm/Core/collection_search_worker.lua']:
        if sha(policy/name) != record['policy']['policy_files'][name]:
            raise ValueError('Frozen product search bytes differ: '+name)
        files['policy/'+name] = policy/name
    create(HERE/'request.json', q)
    files['request.json'] = HERE/'request.json'
    register('S05', files, [sys.executable, '-B', '-u', '{job}/worker.py'], {
        'hypothesis': 'One independently started selected-development query with Blueprint-or-Brainstorm by Ante5 can find a qualifying Yorick/Perkeo Starting Charm and Burnt byAnte5 RedGold route within27 native seconds or1trillion screened indices, whichever ends first.',
        'request': q, 'policy_digest': record['policy']['policy_digest'],
        'profile': 'all_unlocked_discovered_v1', 'profile_consumed_by_native': False,
        'qualification': False, 'static_route': True, 'outer_cap_seconds': 30,
        'serial_worker': True, 'one_native_call': True, 'game_or_save_access': False,
        'selection': 'Prespecified development cursor, not unseen validation; range may overlap prior requested ceilings, whose unexamined remainder is not evidence.',
        'outcomes_preserved': ['found', 'not_found', 'timeout', 'cancelled', 'invalid', 'busy', 'error'],
    }, external=[Path(sys.executable)])
    print(BASE/'S05/registration.json')

if __name__ == '__main__':
    main()
