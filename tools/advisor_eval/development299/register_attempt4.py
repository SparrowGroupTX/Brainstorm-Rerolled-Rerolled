"""Preregister one fresh dependent Gold-objective attempt, no execution here."""
from pathlib import Path
import json,sys
from cycle import ROOT,BASE,register
here=Path(__file__).resolve().parent
record_path=Path(sys.argv[1]).resolve()
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
prior=json.loads((BASE/'C01/registration.json').read_text())
files={name:BASE/'C01'/name for name in prior['files'] if not name.startswith('policy/') and name not in ('run_attempt1.py','installed_policy_record.json','normal_recipe.py')}
draft=here/'drafts/gold_source'
for name in ('engine_probe.py','engine_run.lua','gold_objective_spec.py','gold_objective_context.lua'):
    files[name]=draft/name
files['run_attempt4.py']=here/'run_attempt4.py'
files['installed_policy_record.json']=record_path
# C01 uses original strict API8 evidence; preserve its corresponding parser.
files['normal_recipe.py']=BASE/'C01/normal_recipe.py'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
register('C04',files,[sys.executable,'-B','-u','{job}/run_attempt4.py'],{
 'hypothesis':'The exact current installed policy can evaluate normal Red Gold with the explicit fresh all-missing Gold objective, including supported final-shop cargo comparisons, on the previously observed C01/C02 development seed.',
 'attempt_scope':'One fresh180s/500-action selected dependent attempt; no replay, retry, checkpoint, search or player profile. Every loss/error/unsupported/timeout/censored outcome is retained.',
 'seed':'M4BVSY11','deck':'b_red','stake':8,'selection':'Observed S04 and C01/C02 development data, not an unseen holdout',
 'opening_jokers':['j_yorick','j_perkeo'],
 'conditional_later_targets':[{'key':'j_brainstorm','by_ante':5},{'key':'j_burnt','by_ante':5}],
 'no_perishable_targets':True,'search_cpu_mode':'maximum in historical S04; no new search',
 'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
 'save_access':'none','native_search_in_attempt':False,'retry_context':'disabled_clean',
 'gold_objective_context':'synthetic_fresh_all_missing_v1; actual frozen capture must verify natural empty loaded Joker history and150missing0unknown before any decision; no manufactured metadata or Gold wins',
 'adapter_change':'Explicit opt-in Gold objective plumbing and provenance; source callbacks alone create progress; default disabled mode unchanged.',
 'policy_digest':record['policy']['policy_digest'],
 'metrics':['terminal callbacks and actual synthetic Gold deltas','selected-action legality/exact scores/random gaps','cash/acquisition/retention','cargo admission/rejection and complete comparison','scorecalls/advice/source/actions/attempt cost']},
 [Path(p) for p in prior['external_files']])
