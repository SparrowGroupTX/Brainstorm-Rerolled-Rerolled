"""Root-only M23 plan/registration. Default describe performs no source calls."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
RUNS=ROOT/'tools/advisor_eval/runs';BASE=RUNS/'gold299_20260914'
ADAPTER=ROOT/'tools/advisor_eval/development299/drafts/complete_adapter315'
INSTALLED=RUNS/'copy315_installed'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text())
def plan():
    record=read(INSTALLED/'record.json');policy=record['policy'];manifest=read(ADAPTER/'preparation_manifest.json')
    final_path=RUNS/'copy315_final/final_verification.json';validation_path=RUNS/'copy315_installed_validation/report.json'
    final=read(final_path);validation=read(validation_path)
    assert record['version']==final['version']=='2.115.0-alpha'
    assert policy['policy_digest']==manifest['policy_digest']==final['policy_digest']==validation['policy_digest']
    assert validation['passed']and validation['policy_unchanged']and validation['tests_unchanged']
    assert final['installed_matches']and final['native_unchanged']and final['installed_report']==sha(validation_path)
    adapter_names=['benchmark.py','development_report.py','engine_contract.lua','engine_probe.lua','engine_run.lua',
      'normal_terminal.lua','opening_support.py','policy_wiring.lua']
    files={}
    for name in adapter_names:
        assert sha(ADAPTER/name)==manifest['prepared_files'][name],name
        files[name]=ADAPTER/name
    assert sha(ADAPTER/'engine_probe.py')==manifest['prepared_files']['engine_probe.py']
    from prepare_opening_parser import patched
    assert (HERE/'engine_probe_m23.py').read_text()==patched((ADAPTER/'engine_probe.py').read_text())
    files['engine_probe.py']=HERE/'engine_probe_m23.py'
    for name in ['normal_recipe.py','gold_objective_spec.py','gold_objective_context.lua','normal_opening_recipe.json',
      'normal_seed_selection.json','gold_objective_profile_spec.json','run_opening23.py','preparation_receipt.json']:
        files[name]=HERE/name
    for name in ['INTEGRATION.md','test_alternate_context.lua','test_alternate_recipe.py','test_normal_recipe_legacy.py',
      'prepare_opening_parser.py','prepare_recipe.py','register_m23.py']:
        files['preparation/'+name]=HERE/name
    for name in ['preparation_manifest.json','preparation_origins.json','INTEGRATION.md']:
        files['base_adapter/'+name]=ADAPTER/name
    files.update(installed_policy_record=INSTALLED/'record.json')
    files['installed_policy_record.json']=files.pop('installed_policy_record')
    files['installed_final_verification.json']=final_path;files['installed_validation.json']=validation_path
    for name,expected in policy['policy_files'].items():
        assert sha(INSTALLED/'policy'/name)==expected,name
        files['policy/'+name]=INSTALLED/'policy'/name
    evidence=read(BASE/'S06/audit.json')['evidence_sha256']
    for name,expected in evidence.items():
        assert sha(BASE/'S06'/name)==expected,name
        files['observed_S06/'+name]=BASE/'S06'/name
    files['observed_S06/audit.json']=BASE/'S06/audit.json'
    source_record=read(BASE/'C05/registration.json')
    external=[Path(name)for name in source_record['external_files']]
    assert {p.name.lower()for p in external}=={'balatro.exe','lua51.dll'}
    external.append(Path(sys.executable).resolve())
    metadata=dict(hypothesis='Exact315 source startup can execute observed S06 Canio/Perkeo Soul recipe and classify an explicitly seeded synthetic149Gold/onlyCanio-missing profile before and after exactly three opening actions.',
      maximum_actions=3,outer_seconds=30,policy_version=record['version'],policy_digest=policy['policy_digest'],
      seed='ITKSGS21',deck='b_red',stake=8,opening_pair=['j_caino','j_perkeo'],
      source_search='S06',source_search_audit_sha256=sha(BASE/'S06/audit.json'),
      source_base_adapter_sha256=sha(ADAPTER/'preparation_manifest.json'),
      adapter_overrides=['normal_recipe.py','gold_objective_spec.py','gold_objective_context.lua',
        'engine_probe.py: allow3-step opening cap only with explicit alternateCanio mode; old10/complete500 unchanged'],
      gold_objective='synthetic_only_canio_missing_v1',initial_counts=dict(total=150,complete=149,missing=1,unknown=0),
      profile_spec_sha256=sha(HERE/'gold_objective_profile_spec.json'),
      initial_history='Declared in-memory synthetic149 prior wins[8] rows after natural-empty/catalog verification; not executed wins or player progress.',
      allowed_actions=['skip initial Small','choose displayed Soul','choose displayed Soul'],
      selected_action_legality='Unchanged engine_contract and original callbacks; nonopening actions rejected before execution.',
      receipts=['full source/provenance hashes','engine_gold_objective_context initial empty and postinitialization loadedcounts',
        'engine_episode_before/after selected actions','engine_opening_setup_complete actual pair and ending loadedcounts'],
      source_access='Executable ZIP and isolated lua51.dll only when root dispatches; no game process/player files',
      native_search=False,blind_play=False,purchases=False,terminal_claim=False,qualification=False,
      source_or_policy_execution_during_preparation=False,
      outcomes_preserved=['opening_complete_censored','unsupported','error','timeout','action_limit_censored'])
    return files,metadata,external
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--register',action='store_true');args=parser.parse_args()
    files,metadata,external=plan()
    if not args.register:
        print(json.dumps(dict(status='prepared_not_registered',file_count=len(files),metadata=metadata,
          external=list(map(str,external))),indent=2));return
    spec=importlib.util.spec_from_file_location('cycle',ROOT/'tools/advisor_eval/development299/cycle.py')
    cycle=importlib.util.module_from_spec(spec);spec.loader.exec_module(cycle)
    print(cycle.register('M23',files,[sys.executable,'-B','-u','{job}/run_opening23.py'],metadata,external=external))
if __name__=='__main__':main()
