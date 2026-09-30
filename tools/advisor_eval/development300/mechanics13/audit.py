"""Audit completed M13 source inspection only; never dispatch an experiment."""
from pathlib import Path
import hashlib
import json
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    folder = Path(sys.argv[1]).resolve()
    record = json.loads((folder/'record.json').read_text(encoding='utf-8'))
    registered = json.loads((folder/'registration.json').read_text(encoding='utf-8'))
    manifest = json.loads((folder/'inspection/inspection.json').read_text(encoding='utf-8'))
    assert record['job'] == registered['job'] == manifest['job'] == 'M13'
    assert record['status'] == 'complete' and record['exit_code'] == 0
    assert record['registration_sha256'] == sha(folder/'registration.json')
    assert record['trace_sha256'] == sha(folder/'trace.log')
    assert all(sha(folder/name) == value for name, value in registered['files'].items())
    for row in manifest['methods']:
        if row.get('excerpt_file'):
            assert sha(folder/'inspection'/row['excerpt_file']) == row['excerpt_sha256']
    for row in manifest['neighborhoods']:
        for excerpt in row['excerpts']:
            assert sha(folder/'inspection'/excerpt['excerpt_file']) == excerpt['sha256']
    evidence = ['functions_misc_functions__saving_loading_1.lua', 'functions_misc_functions__saving_loading_2.lua',
        'game__state_complete_1.lua', 'game__menu_state_4.lua', 'game__state_complete_18.lua', 'controller_update.lua']
    audit = {'schema': 1, 'job': 'M13', 'status': 'read_only_mechanics_verified',
        'record_sha256': sha(folder/'record.json'), 'inspection_sha256': sha(folder/'inspection/inspection.json'),
        'worker_seconds': record['elapsed_seconds'], 'one_use_spent': record['one_use_spent'],
        'frozen_and_excerpt_hashes_verified': True,
        'findings': [
            'Original boot_timer creates and retains G.LOADING={font=...} as display cache. Treating every truthy G.LOADING as active loading blocks both product startup paths.',
            'prep_stage sets STATE_COMPLETE=false; main_menu enters MAIN_MENU/MENU; update_menu is empty. That exact menu state must not depend on the gameplay completion latch.',
            'Original Controller:update consumes frame_set, schedules removal of frame after0.1 UPTIME seconds, and rebuilds its aggregate locked flag. Keep these real presentation/input gates.',
        ], 'supporting_excerpts': {name: sha(folder/'inspection'/name) for name in evidence},
        'limitations': 'Seven inspected source members only. Game:update method excerpt is truncated at220 of282 lines; bounded field neighborhoods have explicit counts. No original-source execution, player-state inspection or full-autoplay qualification.',
        'source_execution': False, 'native_search': False, 'player_file_access': False, 'qualification': False}
    with (folder/'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2); stream.write('\n')
    print(json.dumps({'status': audit['status'], 'worker_seconds': audit['worker_seconds'], 'findings': audit['findings']}))


if __name__ == '__main__':
    main()
