"""Root-only M13 registration preparation. Does not dispatch the worker."""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'tools/advisor_eval/development299'))
from cycle import register


def main():
    archive = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe').resolve()
    files = {'inspect_source.py': HERE/'inspect_source.py',
             'source_lexer.py': HERE.parent/'mechanics11'/'inspect_source.py',
             'spec.md': HERE/'spec.md', 'synthetic_fixture_report.json': HERE/'synthetic_fixture_report.json'}
    folder = register('M13', files, [sys.executable, '-B', '-u', '{job}/inspect_source.py'], {
        'hypothesis': 'Original startup/controller fields reveal which persistent sentinel or presentation lock prevents the explicit auto-run request from leaving its menu-wait phase.',
        'source_archive': str(archive), 'outer_cap_seconds': 30, 'one_use': True,
        'source_scope': 'At most seven named ZIP Lua members, each<=4MiB; no Lua/policy execution.',
        'methods': 'Controller:init first240 lines, Controller:update first320, Game:update first220, original exit/overlay callbacks60/100; full method hashes and truncation recorded.',
        'neighborhoods': '15-line byte-exact neighborhoods of SAVING/LOADING, frame locks, controller aggregate lock, Controller:update call, MAIN_MENU/MENU, and STATE_COMPLETE assignment, with per-pattern/per-member caps28/20/20/8/20/28.',
        'combined_output_cap_bytes': 280000, 'profile': 'none; no player or synthetic profile input',
        'policy': 'none; no policy execution', 'runtime': 'Frozen Python standard-library byte lexer/ZIP reader',
        'qualification': False, 'native_search': False, 'source_execution': False,
        'player_file_access': False, 'game_process_access': False,
        'limitations': 'Read-only mechanics diagnosis; truncated method excerpts and capped neighborhoods are explicitly incomplete. No game or achievement outcome.'
    }, external=[archive, Path(sys.executable)])
    print(folder/'registration.json')


if __name__ == '__main__':
    main()
