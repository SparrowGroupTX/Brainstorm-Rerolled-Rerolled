from pathlib import Path
import json
import sys
from cycle import ROOT,register
here=Path(__file__).resolve().parent
record_path=ROOT/'tools/advisor_eval/runs/growth298_installed/record.json'
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
files={p.name:p for p in (here/'normal_adapter').iterdir() if p.is_file()}
files['inspect_setup.py']=here/'inspect_setup.py'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
register('M01',files,[sys.executable,'-B','-u','{job}/inspect_setup.py'],
    {'hypothesis':'Untouched source start_run can initialize Red Deck Gold resources in isolated in-memory profile.',
     'mechanical_boundary':'initial Small Blind only; not a complete attempt',
     'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
     'save_access':'none','policy_digest':record['policy']['policy_digest']},[install/'Balatro.exe',install/'lua51.dll'])
