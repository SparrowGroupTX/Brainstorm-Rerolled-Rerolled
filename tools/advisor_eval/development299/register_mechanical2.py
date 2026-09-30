"""Draft M02 registration only. Parent authorizes execution after reviewing scope."""
from pathlib import Path
import json
import sys
from cycle import ROOT,register

here=Path(__file__).resolve().parent
record_path=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT/'tools/advisor_eval/runs/checkpoint299_installed/record.json'
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
files={p.name:p for p in (here/'normal_adapter').iterdir() if p.is_file() and p.suffix in ('.lua','.py')}
files['inspect_terminal.py']=here/'inspect_terminal.py'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
register('M02',files,[sys.executable,'-B','-u','{job}/inspect_terminal.py'],
    {'hypothesis':'Normal Gold source terminal qualification requires actual original deck/Joker progress callbacks and independent loss/threshold checks; GAME.won alone is insufficient.',
     'mechanical_boundary':'Read three source terminal snippets and four synthetic final-boss end-round states only; zero policy decisions, no seed search or complete attempt.',
     'cases':['terminal_win_final','terminal_loss_final','terminal_saved_final','terminal_unsaved_final'],
     'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
     'save_access':'none','policy_digest':record['policy']['policy_digest'],
     'caps':'one-use 30 seconds outer, four fixed cases, no retries or replacement for errors'},
    [install/'Balatro.exe',install/'lua51.dll'])
