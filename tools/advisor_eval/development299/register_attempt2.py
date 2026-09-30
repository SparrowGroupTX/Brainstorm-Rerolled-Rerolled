"""Fresh dependent C02; frozen C01 adapter, exact installed301 policy."""
from pathlib import Path
import json,sys
from cycle import ROOT,BASE,register
here=Path(__file__).resolve().parent
record_path=ROOT/'tools/advisor_eval/runs/collection301b_installed/record.json'
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
prior=json.loads((BASE/'C01/registration.json').read_text())
files={name:BASE/'C01'/name for name in prior['files'] if not name.startswith('policy/') and name not in ('run_attempt1.py','installed_policy_record.json')}
files['run_attempt2.py']=here/'run_attempt2.py';files['installed_policy_record.json']=record_path
files['baseline_attempt_audit.json']=BASE/'C01/audit.json'
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
register('C02',files,[sys.executable,'-B','-u','{job}/run_attempt2.py'],{
 'hypothesis':'Installed301 aggregate ordinary score allocation can complete the previously won selected RedGold route without exceeding140000 ordinary/50000 shop/25000consumable/70fastclear limits. Observe all decisions and terminal outcome; no win assumed.',
 'attempt_scope':'One fresh dependent180s/500-action attempt; no retries or replay/checkpoints. Same selected seed and exact frozen C01 adapter; only policy301 differs. Not an independent player cohort or unseen holdout.',
 'seed':'M4BVSY11','deck':'b_red','stake':8,'selection':'S04; already used M06/C01 development',
 'opening_jokers':['j_yorick','j_perkeo'],'conditional_later_targets':[{'key':'j_brainstorm','by_ante':5},{'key':'j_burnt','by_ante':5}],
 'no_perishable_targets':True,'search_cpu_mode':'maximum in prior S04, no search in attempt',
 'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll',
 'save_access':'none','native_search_in_attempt':False,'retry_context':'disabled_clean',
 'gold_objective_context':'disabled; survival baseline, no inferred actual player history',
 'policy_digest':record['policy']['policy_digest'],
 'metrics':['exact terminal callback outcome','selected action legality/scores/random gaps','per-decision aggregate score calls','actual cash/acquisition/retention','action/advice/source/attempt timing']},
 [Path(p) for p in prior['external_files']])
