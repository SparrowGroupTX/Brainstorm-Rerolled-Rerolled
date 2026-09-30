"""C01 preregistration only; root runs the serial worker after M08 is reaped."""
from pathlib import Path
import json
import sys
from cycle import ROOT,register
here=Path(__file__).resolve().parent
record_path=Path(sys.argv[1]).resolve();record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
assert 'Brainstorm/Advisor/normal_opening.lua' in record['policy']['policy_files']
files={p.name:p for p in (here/'normal_adapter').iterdir() if p.is_file() and p.suffix in ('.lua','.py')}
for name in ['run_attempt1.py','normal_opening_recipe.json','normal_seed_selection.json']:files[name]=here/name
files['installed_policy_record.json']=record_path
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
register('C01',files,[sys.executable,'-B','-u','{job}/run_attempt1.py'],
    {'hypothesis':'Installed300 advisor can autonomously acquire its declared Yorick/Perkeo opening, manage actual Red Gold resources and attempt an authentic Ante8 terminal clear while observing conditional Brainstorm/Burnt offers by Ante5.',
     'attempt_scope':'One fresh500-action/180s selected development attempt; every loss/error/unsupported/timeout/censored result retained, no retry/replay or restart.',
     'seed':'M4BVSY11','deck':'b_red','stake':8,'opening_jokers':['j_yorick','j_perkeo'],
     'conditional_later_targets':[{'key':'j_brainstorm','by_ante':5},{'key':'j_burnt','by_ante':5}],
     'no_perishable_targets':True,'search_cpu_mode':'maximum in prior disclosed S04 discovery; no search occurs in this attempt',
     'selection':'S04 deterministic fixed-filter development, already observed in M06, not an unseen holdout',
     'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
     'save_access':'none','native_search_in_attempt':False,'retry_context':'disabled_clean',
     'gold_objective_context':'disabled; fixed-build survival baseline with no inferred player missing-sticker list',
     'metrics':['terminal and original source progress callbacks','blind/round/score','actual observed/acquired/retained targets and cash',
                'selected-action source legality','exact scores vs supported floors vs random gaps','action/advice/attempt seconds'],
     'policy_digest':record['policy']['policy_digest']},[install/'Balatro.exe',install/'lua51.dll'])
