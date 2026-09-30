"""C03 preparation: selected S05 OR route and exact coherent302 candidate."""
from pathlib import Path
import json,sys
from cycle import ROOT,BASE,register
here=Path(__file__).resolve().parent
record_path=ROOT/'tools/advisor_eval/runs/autorun302_candidate/candidate_record.json'
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
prior=json.loads((BASE/'C01/registration.json').read_text())
files={name:BASE/'C01'/name for name in prior['files'] if not name.startswith('policy/') and name not in ('run_attempt1.py','installed_policy_record.json','normal_recipe.py','normal_opening_recipe.json','normal_seed_selection.json')}
files['run_attempt3.py']=here/'run_attempt3.py';files['installed_policy_record.json']=record_path
selection=ROOT/'tools/advisor_eval/development300/search05/selection'
for name in ('normal_opening_recipe.json','normal_seed_selection.json'):files[name]=selection/name
files['normal_recipe.py']=ROOT/'tools/advisor_eval/development300/search05/normal_recipe.py'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
register('C03',files,[sys.executable,'-B','-u','{job}/run_attempt3.py'],{
 'hypothesis':'Coherent302 shop-order forecasts and phase copying can attempt a complete RedGold run on a second selected native OR-copy opening under the existing score/action/time limits.',
 'attempt_scope':'One fresh180s/500-action selected development attempt. No checkpoint/retry/replay or search. New S05 seed is not a preregistered unseen holdout; no win rate cohort claim.',
 'seed':'S7PXV521','deck':'b_red','stake':8,'selection':'S05 prior OR-copy search with audited native receipt',
 'opening_jokers':['j_yorick','j_perkeo'],'conditional_later_targets':[{'any_of':['j_brainstorm','j_blueprint'],'by_ante':5},{'key':'j_burnt','by_ante':5}],
 'copy_branch_observed':False,'no_perishable_targets':True,'search_cpu_mode':'maximum in S05; no search in attempt',
 'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
 'save_access':'none','native_search_in_attempt':False,'retry_context':'disabled_clean',
 'gold_objective_context':'disabled; survival baseline without actual player history',
 'adapter_change':'Strict API9/28-field source recipe parser, two-Soul opening receipt separate from conditional later OR offers; remaining adapter bytes frozen C01.',
 'policy_digest':record['policy']['policy_digest'],
 'metrics':['terminal callbacks and observed Gold deltas','source legality/exact scoring/random gaps','cash/acquisition/retention','Yorick discard and Perkeo copy events','score calls/advice/source/action/attempt cost']},
 [Path(p) for p in prior['external_files']])
