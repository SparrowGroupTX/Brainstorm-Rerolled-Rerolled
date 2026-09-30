"""M06 draft registration; root supplies coherent frozen300 policy record."""
from pathlib import Path
import json
import sys
from cycle import ROOT,register
here=Path(__file__).resolve().parent
record_path=Path(sys.argv[1]).resolve();record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
assert 'Brainstorm/Advisor/normal_opening.lua' in record['policy']['policy_files'],'Normal route must be in frozen policy'
files={p.name:p for p in (here/'normal_adapter').iterdir() if p.is_file() and p.suffix in ('.lua','.py')}
for name in ['qualify_opening6.py','normal_opening_recipe.json','normal_seed_selection.json']:files[name]=here/name
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
register('M06',files,[sys.executable,'-B','-u','{job}/qualify_opening6.py'],
    {'hypothesis':'Exact frozen normal-route advice and actual Core/lovely two-Soul exception acquire Yorick and Perkeo from S04 selected RedGold Starting Charm before any blind is played.',
     'mechanical_boundary':'Only skip Small and choose visible Souls, maximum10 policy actions/30s outer; stop immediately on acquired pair. Any first blind select/play/discard or other move is refused before execution.',
     'seed':'M4BVSY11','selection':'S04 deterministic fixed-filter development, v9 ORfalse/quota0; not holdout',
     'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
     'save_access':'none','native_search_in_component':False,'policy_digest':record['policy']['policy_digest']},
    [install/'Balatro.exe',install/'lua51.dll'])
