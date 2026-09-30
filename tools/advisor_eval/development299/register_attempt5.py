"""Preregister the one-use dependent312 complete attempt; never executes it."""
from pathlib import Path
import json,sys
from cycle import ROOT,BASE,register,sha

here=Path(__file__).resolve().parent
draft=here/'drafts/complete_adapter310'
manifest=json.loads((draft/'integration_manifest.json').read_text())
record_path=ROOT/'tools/advisor_eval/runs/perkeo312_installed/record.json'
record=json.loads(record_path.read_text());policy=record_path.parent/'policy'
final=ROOT/'tools/advisor_eval/runs/perkeo312_final/final_verification.json'
assert json.loads(final.read_text())['policy_digest']==record['policy']['policy_digest']
assert json.loads((ROOT/'tools/advisor_eval/runs/perkeo312_installed_validation/report.json').read_text())['passed']
prior=json.loads((BASE/'C03/registration.json').read_text())
files={name:BASE/'C03'/name for name in prior['files'] if not name.startswith('policy/') and name not in ('run_attempt3.py','installed_policy_record.json')}
for item in manifest['adapter_files']:
    source=draft/item['file'];assert sha(source)==item['sha256']
    files[item['file']]=source
files['installed_policy_record.json']=record_path
files['installed_final_verification.json']=final
files['adapter_integration_manifest.json']=draft/'integration_manifest.json'
files['adapter_integration_note.md']=draft/'INTEGRATION.md'
for name in ('audit.json','record.json','registration.json'):files['prior_C03_'+name]=BASE/'C03'/name
files.update({'policy/'+name:policy/name for name in record['policy']['policy_files']})
register('C05',files,[sys.executable,'-B','-u','{job}/run_attempt5.py'],{
 'hypothesis':'Exact installed312 complete pack-survival evidence and source-shaped Certificate capture may alter the previously observed early loss route; fully wired Gold/Perkeo comparisons can be exercised if the attempt reaches their supported states.',
 'attempt_scope':'One fresh180s/500-action selected dependent attempt; no checkpoint, retry, replay, search or player profile. Every loss/error/unsupported/timeout/censored outcome remains.',
 'seed':'S7PXV521','deck':'b_red','stake':8,'selection':'S05/C03 inspected dependent synthetic development, not unseen holdout',
 'opening_jokers':['j_yorick','j_perkeo'],
 'conditional_later_targets':[{'any_of':['j_brainstorm','j_blueprint'],'by_ante':5},{'key':'j_burnt','by_ante':5}],
 'no_perishable_targets':True,'search_cpu_mode':'maximum in historical S05; no new search',
 'profile':'all_unlocked_discovered_v1','qualification':False,'source_access':'ZIP and isolated lua51.dll; never launch Balatro.exe',
 'save_access':'none','native_search_in_attempt':False,'retry_context':'disabled_clean',
 'gold_objective_context':'synthetic_fresh_all_missing_v1; actual capture must verify natural empty loaded history and150missing0unknown before decisions; no fabricated Gold progress',
 'confounding':'C03 Gold objective was disabled; C05 changes both policy and explicit Gold context. No isolated causal effect, win odds or human-superiority claim.',
 'adapter_change':'41 root modules/34 exact graph edges, including Certificate, Bell, pack resource receipts and nonempty Perkeo Planet delivery; inert wiring tests only before this job.',
 'policy_digest':record['policy']['policy_digest'],
 'metrics':['terminal callbacks and actual synthetic Gold deltas','selected-action legality/exact scores/random gaps','pack family completion/choice and receipt scope','cash/acquisition/retention','Yorick discards/Perkeo copies','ordinary/shop/consumable/fastclear calls and computation/action/attempt cost']},
 [Path(p) for p in prior['external_files']])
