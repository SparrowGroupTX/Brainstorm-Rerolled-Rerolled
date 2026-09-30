"""Root-only C09 --describe/--register. Never launches or resumes a worker."""
from pathlib import Path
from datetime import datetime,timezone
import argparse
import importlib.util
import json
import sys
from bind_installed import sha,read,check_binding,HERE,ROOT,RUNS,BASE

def selected_audit(job):
    folder=BASE/job;pointer_path=folder/'selected_audit.json'
    if pointer_path.exists():
        pointer=read(pointer_path);name=pointer['filename']
        assert Path(name).name==name and name.startswith('audit') and name.endswith('.json'),'Audit pointer must be a contained audit basename'
        path=folder/name;assert sha(path)==pointer['sha256'],'Selected audit digest differs'
    else:path=folder/'audit.json'
    audit=read(path);record=read(folder/'record.json')
    assert not audit['audit_issues'] and audit['record_sha256']==sha(folder/'record.json')
    assert audit['trace_sha256']==record['trace_sha256'] and audit['registration_sha256']==sha(folder/'registration.json')
    return path,audit,pointer_path if pointer_path.exists() else None

def prior_audit_receipts():
    receipts={}
    for job in ('C07','C08'):
        path,audit,pointer=selected_audit(job)
        receipts[job]={'original_path':str(path.resolve()),'filename':path.name,'sha256':sha(path),
                       'selected_pointer_path':str(pointer.resolve()) if pointer else None,
                       'selected_pointer_sha256':sha(pointer) if pointer else None,
                       'record_sha256':sha(BASE/job/'record.json'),'registration_sha256':sha(BASE/job/'registration.json'),
                       'trace_sha256':audit['trace_sha256'],'disposition':audit['disposition'],'audit_issues':audit['audit_issues'],
                       'scope':'Provenance reference only; no full audit, future state or continuation is a policy input.'}
    return receipts

def plan(expected_policy_digest,expected_final_sha256):
    binding=read(HERE/'installed_binding.json')
    assert binding['job']=='C09' and binding['checkpoint']==321 and binding['version']=='2.121.0-alpha'
    assert binding['policy_digest']==expected_policy_digest and binding['final_verification_sha256']==expected_final_sha256
    checked,graph=check_binding(binding['installed_dir'],expected_policy_digest,expected_final_sha256,binding['reviewed_growth_sha256'])
    assert all(binding[k]==v for k,v in checked.items() if k!='bound_at_utc')
    assert graph==read(HERE/'installed_graph_rebinding.json'),'Bound graph changed'
    authority=read(BASE/'authority.json')
    assert authority['status']=='APPROVED' and authority['expires_at_utc']=='2026-09-14T22:40:00+00:00' and authority['per_job_caps']['C09']==180
    assert not (BASE/'CLOSED.json').exists() and not (BASE/'C09').exists() and not (BASE/'C09_reservation.json').exists()
    assert datetime.now(timezone.utc).timestamp()+180<=datetime.fromisoformat(authority['expires_at_utc']).timestamp()
    assert all((p.parent/'record.json').exists() for p in BASE.glob('*/spent.json')),'All preceding workers must be reaped'
    manifest=read(HERE/'preparation_manifest.json')
    assert manifest['job']=='C09' and manifest['validation']['passed']
    for name,value in manifest['prepared_files'].items():assert sha(HERE/name)==value,'Prepared input changed: '+name
    recipe=read(HERE/'normal_opening_recipe.json');selection=read(HERE/'normal_seed_selection.json')
    assert recipe['seed']==selection['seed']=='M4BVSY11' and recipe['deck']=='b_red' and recipe['stake']==8
    assert recipe['discovery']['job']==selection['source_search_job']=='S04'
    assert recipe['discovery']['result_sha256']==selection['search_evidence']['result.json']
    prior=read(BASE/'C07/registration.json')
    for name in ('normal_opening_recipe.json','normal_seed_selection.json'):
        assert sha(HERE/name)==prior['files'][name]
    for name,value in selection['search_evidence'].items():assert sha(BASE/'S04'/name)==value,name
    installed=Path(binding['installed_dir']);pfiles=read(installed/'record.json')['policy']['policy_files']
    files={name:HERE/name for name in manifest['prepared_files']}
    files.update({'preparation_manifest.json':HERE/'preparation_manifest.json','installed_binding.json':HERE/'installed_binding.json',
      'installed_graph_rebinding.json':HERE/'installed_graph_rebinding.json','authority.json':BASE/'authority.json',
      'cycle_orchestrator.py':ROOT/'tools/advisor_eval/development299/cycle.py',
      'installed_policy_record.json':installed/'record.json','installed_final_verification.json':Path(binding['final_verification']),
      'installed_validation.json':Path(binding['validation_report']),'source_C07_registration.json':BASE/'C07/registration.json',
      'source_C07_installed_graph_check.json':BASE/'C07/installed_graph_check.json',
      'inert_graph_raw.json':BASE/'C07/inert_graph_raw.json','inert_graph_stdout.log':BASE/'C07/inert_graph_stdout.log'})
    audits=prior_audit_receipts()
    assert read(HERE/'prior_audits.json')==audits,'Compact prior audit binding differs from original selected evidence'
    for job in ('C07','C08'):
        for name in ('record.json','registration.json','AUDIT.md'):files['prior_'+job+'_'+name]=BASE/job/name
        pointer=BASE/job/'selected_audit.json'
        if pointer.exists():files['prior_'+job+'_selected_audit.json']=pointer
    assert audits['C07']['disposition']=='timeout' and audits['C08']['disposition']=='loss'
    for name in selection['search_evidence']:files['observed_S04_'+name]=BASE/'S04'/name
    for name in pfiles:files['policy/'+name]=installed/'policy'/name
    metadata={'checkpoint':321,'installed_version':'2.121.0-alpha','policy_digest':expected_policy_digest,
      'hypothesis':'Observe whether the narrow played-Steel additive exception and complete two-discard Yorick threshold plan change actual growth actions and terminal progression on dependent M4BVSY11. Whole-policy development comparison, not isolated causal evidence or an unseen holdout.',
      'maximum_actions':500,'outer_seconds':180,'seed':'M4BVSY11','deck':'b_red','stake':8,
      'attempt_scope':'One fresh full original-source initialization; no captured replay, prefix import, continuation, checkpoint reload or retry. Preserve every loss/error/unsupported/timeout/censored outcome.',
      'selection':'Exact observed S04 fixed-target recipe previously used by C01/C02/C04/C06/C07; dependent synthetic development.',
      'profile':'all_unlocked_discovered_v1','gold_objective_context':'synthetic_fresh_all_missing_v1',
      'profile_semantics':'Naturally empty loaded synthetic history must capture150missing0unknown before decisions; no fabricated prior sticker wins.',
      'retry_context':'disabled_clean','qualification':False,'player_profile_access':False,'save_access':'none','native_search_in_attempt':False,
      'source_access':'Executable ZIP and isolated lua51.dll only; never launch Balatro.exe',
      'opening_jokers':['j_yorick','j_perkeo'],'conditional_later_targets':[{'key':'j_brainstorm','by_ante':5},{'key':'j_burnt','by_ante':5}],
      'no_perishable_targets':True,'search_receipt':selection['search_evidence'],
      'adapter_change':'No source-adapter change from C07. Worker/job/version guards updated; complete current graph statically rebound only under exact runtime initialization-prefix and adapter/verifier/checker equality.',
      'product_execution_ui_bypassed':True,'ui_scope':'No live startup/search/cashout/auto-run/logging/checkpoint or animation-speed qualification.',
      'confounding':'Multiple policy changes and prior dependent study; no imputed terminal improvement, player odds or human superiority.',
      'metrics':['terminal consistency/original callbacks/synthetic Gold deltas','selected-action legality/exact scores/supported floors/random gaps',
                 'actual growth recommendations/actions, physical discards and Yorick thresholds','comparison with exact recorded C07 public inputs',
                 'cash/inventory/retention/Perkeo generation','ordinary140000/shop50000/consumable25000/fastclear70 budgets and advice/action/whole-attempt cost'],
      'installed_final_verification_sha256':expected_final_sha256,'installed_binding_sha256':sha(HERE/'installed_binding.json'),
      'installed_graph_rebinding_sha256':sha(HERE/'installed_graph_rebinding.json'),'reviewed_feature_files':binding['reviewed_feature_files'],
      'prior_selected_audits':audits,'python_executable':str(Path(sys.executable).resolve()),'python_version':sys.version}
    external=[Path(name) for name in prior['external_files'] if Path(name).name.lower() in ('balatro.exe','lua51.dll')]
    assert {p.name.lower() for p in external}=={'balatro.exe','lua51.dll'}
    external.append(Path(sys.executable).resolve())
    metadata['prior_external_files']={str(p):prior['external_files'][str(p)] for p in external}
    return files,metadata,external

def register(expected_policy_digest,expected_final_sha256):
    files,metadata,external=plan(expected_policy_digest,expected_final_sha256)
    prior=read(BASE/'C07/registration.json')['external_files']
    for path in external:assert sha(path)==prior[str(path)],'Source/runtime changed before registration'
    spec=importlib.util.spec_from_file_location('c09_cycle',ROOT/'tools/advisor_eval/development299/cycle.py')
    cycle=importlib.util.module_from_spec(spec);spec.loader.exec_module(cycle)
    return cycle.register('C09',files,[sys.executable,'-B','-u','{job}/run_attempt9.py'],metadata,external=external)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--expected-policy-digest',required=True);p.add_argument('--expected-final-sha256',required=True)
    mode=p.add_mutually_exclusive_group(required=True);mode.add_argument('--describe',action='store_true');mode.add_argument('--register',action='store_true')
    a=p.parse_args()
    if a.describe:
        files,metadata,external=plan(a.expected_policy_digest,a.expected_final_sha256)
        print(json.dumps({'frozen_file_count':len(files),'metadata':metadata,'external_paths_not_read':list(map(str,external))},indent=2))
    else:print(register(a.expected_policy_digest,a.expected_final_sha256))
