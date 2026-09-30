"""Root-only prospective M16 registration. Subagents must not run this file."""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval/development299'))
from cycle import register


def main():
    archive = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe').resolve()
    files = {'inspect_source.py': HERE / 'inspect_source.py',
             'source_lexer.py': ROOT / 'tools/advisor_eval/development300/mechanics11/inspect_source.py',
             'spec.md': HERE / 'spec.md', 'synthetic_fixture_report.json': HERE / 'synthetic_fixture_report.json'}
    folder = register('M16', files, [sys.executable, '-B', '-u', '{job}/inspect_source.py'], {
        'hypothesis': 'Exact first-hand dispatch, generated-card side effects and Perkeo Negative copying/capacity/pricing determine whether bounded complete Certificate and homogeneous owned-consumable projections are possible. Additional Game:main_menu inspection resolves the remaining source initialization gap for later start-button validation.',
        'source_archive': str(archive), 'outer_cap_seconds': 30, 'one_use': True,
        'source_scope': 'Only game.lua, card.lua, functions/common_events.lua, functions/misc_functions.lua ZIP members; each at most4MiB; at most20000 archive entries.',
        'combined_output_cap_bytes': 160000,
        'methods': 'Nine exact first-draw/main-menu/generated-card/copy/edition/cost/capacity methods; bounded lines and bytes; balanced original full-method/excerpt hashes. Missing, ambiguous, oversized, malformed and truncated explicitly labeled.',
        'neighborhoods': 'Perkeo3x7000, ending_shop3x3000, first_hand_drawn4x3000, playing_card effects4x3000 maximum; same160000-byte global cap; raw contexts are not execution evidence.',
        'profile': 'none', 'policy': 'none',
        'runtime': 'Frozen Python standard-library ZIP reader plus existing byte lexer; no Lua interpreter',
        'qualification': False, 'source_execution': False, 'native_search': False,
        'player_file_access': False, 'game_process_access': False,
        'limitations': 'Source text only. No callback, action, run, seed search, terminal outcome or live UI interaction. No unseen terminal validation or adapter qualification.'
    }, external=[archive, Path(sys.executable)])
    print(folder / 'registration.json')


if __name__ == '__main__':
    main()
