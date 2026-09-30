"""M05 preregistration draft, no source/worker execution."""
from pathlib import Path
import json
import sys
from cycle import ROOT,register
here=Path(__file__).resolve().parent
record_path=Path(sys.argv[1]).resolve()
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
files={p.name:p for p in (here/'normal_adapter').iterdir() if p.is_file() and p.suffix in ('.lua','.py')}
files['inspect_terminal5.py']=here/'inspect_terminal5.py'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
register('M05',files,[sys.executable,'-B','-u','{job}/inspect_terminal5.py'],
    {'hypothesis':'Providing a display-only cursor Moveable permits original win overlay setup, while recording the original end_round context before Ante advances correctly binds normal Gold progress callbacks to the final blind.',
     'mechanical_boundary':'Read cursor/overlay/end_round source references and run four fixed synthetic terminal states; zero advisor decisions, search or complete attempts.',
     'cases':['terminal_win_final','terminal_loss_final','terminal_saved_final','terminal_unsaved_final'],
     'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
     'save_access':'none','policy_digest':record['policy']['policy_digest'],
     'caps':'one-use30s outer/four cases/no retries; M02 error preserved, this is distinct registered qualification'},
    [install/'Balatro.exe',install/'lua51.dll'])
