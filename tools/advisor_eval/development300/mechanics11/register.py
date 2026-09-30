"""M11 preregistration only. Root dispatches serially through cycle.py run M11."""
from pathlib import Path
import sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'tools/advisor_eval/development299'))
from cycle import register

def main():
    archive = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe').resolve()
    folder = register('M11', {'inspect_source.py': HERE/'inspect_source.py',
        'inspection_spec.md': HERE/'inspection_spec.md', 'synthetic_fixture_report.json': HERE/'synthetic_fixture_report.json'},
        [sys.executable, '-B', '-u', '{job}/inspect_source.py'], {
            'hypothesis': 'Original Game:update_game_over and UI/callback source establish the actual loss overlay lifecycle, its settled-state markers and safe owned dismissal before an explicit new run.',
            'mechanical_scope': 'Read at most five named executable ZIP members, each<=4MiB; bounded balanced-method excerpts and source hashes. No source Lua or product policy execution.',
            'source_archive': str(archive), 'outer_cap_seconds': 30, 'one_use': True,
            'members': ['game.lua', 'functions/misc_functions.lua', 'functions/common_events.lua',
                        'functions/UI_definitions.lua', 'functions/button_callbacks.lua'],
            'callbacks': ['Game:update_game_over', 'win_game', 'create_UIBox_game_over', 'create_UIBox_win',
                          'exit_overlay_menu', 'overlay_menu', 'start_run', 'go_to_menu'],
            'excerpt_limits': {'update_game_over': 160, 'win_game': 140, 'game_over_ui': 220, 'win_ui': 160,
                               'exit_overlay_menu': 60, 'overlay_menu': 100, 'start_run': 80, 'go_to_menu': 60},
            'game_update_context': 'At most four13-line neighborhoods around self:update_game_over calls.',
            'outcomes': 'Missing/ambiguous methods and truncation remain explicit; inspection does not qualify a full adapter or gameplay outcome.',
            'profile': 'none; no profile or save input', 'policy': 'none; no policy execution',
            'runtime': 'Frozen Python standard library lexer/ZIP reader only; lua51.dll is not loaded.',
            'qualification': False, 'source_execution': False, 'game_process_access': False,
        }, external=[archive, Path(sys.executable)])
    print(folder/'registration.json')

if __name__ == '__main__':
    main()
