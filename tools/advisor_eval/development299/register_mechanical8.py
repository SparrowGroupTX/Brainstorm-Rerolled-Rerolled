"""M08 draft, freeze one derived terminal fixture variant; do not run worker."""
from pathlib import Path
import json
import sys
from cycle import ROOT,register
here=Path(__file__).resolve().parent
record_path=Path(sys.argv[1]).resolve();record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
files={p.name:p for p in (here/'normal_adapter').iterdir() if p.is_file() and p.suffix in ('.lua','.py')}
files['engine_run.lua']=here/'drafts/held_terminal/engine_run.lua'
files['derivation.json']=here/'drafts/held_terminal/derivation.json';files['qualify_held8.py']=here/'qualify_held8.py'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
register('M08',files,[sys.executable,'-B','-u','{job}/qualify_held8.py'],
    {'hypothesis':'Original normal Gold win processing increments all four retained Yorick/Perkeo/Brainstorm/Burnt Joker records and the deck record in the synthetic profile.',
     'mechanical_boundary':'Read at most6 original controller input methods/60lines each with bound source hash, then one synthetic final-boss resolved state with four original Card instances; zero policy decisions/acquisition/search/full-attempt,30s one-use outer.',
     'retained_jokers':['j_yorick','j_perkeo','j_brainstorm','j_burnt'],
     'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
     'save_access':'none','policy_digest':record['policy']['policy_digest']},[install/'Balatro.exe',install/'lua51.dll'])
