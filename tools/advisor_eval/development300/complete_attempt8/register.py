"""Root-only prospective C08 registration; --describe is read-only."""
from pathlib import Path
from datetime import datetime,timezone
import argparse
import hashlib
import importlib.util
import json
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
RUNS=ROOT/'tools/advisor_eval/runs'
BASE=RUNS/'gold299_20260914'
POLICY='e1d66be72a88ccf553811cb7cdb6358fb265ce9ac7e7bd85eaca7e70023b1966'
FINAL='36492dcf2181ac55de9fc6f1c815764fef104cf6f40d870ab013cd35d4c657c3'
GRAPH='986ea16d7fa361b90567b8101d557bffea68aaf01b296de8338fedf6c20954cd'
def sha(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def read(path):return json.loads(Path(path).read_text())
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def plan(installed,expected_policy_digest):
    installed=Path(installed).resolve()
    assert installed==RUNS/'pack320_installed' and expected_policy_digest==POLICY
    record=read(installed/'record.json');policy=record['policy'];pfiles=policy['policy_files']
    assert record['version']=='2.120.0-alpha' and policy['policy_digest']==POLICY==digest(pfiles)
    final_path=RUNS/'pack320_final/final_verification.json';validation_path=RUNS/'pack320_installed_validation/report.json'
    assert sha(final_path)==FINAL
    final=read(final_path);validation=read(validation_path)
    assert final['policy_digest']==validation['policy_digest']==POLICY and final['version']=='2.120.0-alpha'
    assert final['installed_matches'] and final['native_unchanged'] and not final['config_restored_or_modified_by_finalizer']
    assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
    assert final['installed_report']==sha(validation_path)
    for name,value in pfiles.items():assert sha(installed/'policy'/name)==value,name
    for name,value in read(HERE/'required_features.json')['files'].items():assert pfiles[name]==value,name
    authority=read(BASE/'authority.json')
    assert authority['status']=='APPROVED' and authority['per_job_caps']['C08']==180
    assert not (BASE/'CLOSED.json').exists() and not (BASE/'C08').exists() and not (BASE/'C08_reservation.json').exists()
    assert datetime.now(timezone.utc).timestamp()+180<=datetime.fromisoformat(authority['expires_at_utc']).timestamp()
    manifest=read(HERE/'preparation_manifest.json')
    for name,value in manifest['prepared_files'].items():assert sha(HERE/name)==value,name
    regs={job:read(BASE/job/'registration.json') for job in ('C05','C07')}
    assert regs['C07']['metadata']['policy_digest']==POLICY and regs['C07']['metadata']['checkpoint']==320
    for row in read(HERE/'preparation_origins.json'):
        assert sha(HERE/row['file'])==row['prepared_sha256']==row['source_sha256']
        assert sha(BASE/row['source'])==row['source_sha256']==regs[row['source_job']]['files'][row['file']]
    for name in ('gold_objective_context.lua','gold_objective_spec.py'):
        assert sha(HERE/name)==regs['C05']['files'][name],'Fresh synthetic Gold context changed'
    recipe=read(HERE/'normal_opening_recipe.json');selection=read(HERE/'normal_seed_selection.json')
    assert recipe['seed']==selection['seed']=='S7PXV521' and recipe['deck']=='b_red' and recipe['stake']==8
    assert recipe['discovery']['job']==selection['source_search_job']=='S05'
    assert recipe['discovery']['evidence_sha256']==selection['search_evidence']
    for name,value in selection['search_evidence'].items():assert sha(BASE/'S05'/name)==value,name
    assert recipe['conditional_later_requirements']==[{'any_of':['j_brainstorm','j_blueprint'],'by_ante':5},{'key':'j_burnt','by_ante':5}]
    assert read(BASE/'C05/audit.json')['disposition']=='loss'
    # Reuse the frozen final320 graph because adapter, checker and verifier
    # bytes are exactly identical. Raw proof is read from C07's frozen inputs.
    graph_path=BASE/'C07/installed_graph_check.json';graph=read(graph_path)
    assert sha(graph_path)==GRAPH and graph['policy_digest']==POLICY and graph['policy_files']==pfiles
    assert graph['passed'] and graph['source_initializations']==graph['policy_decisions']==0
    assert Path(graph['policy_root']).resolve()==installed/'policy'
    assert graph['graph']['gold_objective_enabled'] and not graph['graph']['retry_enabled']
    for name,value in graph['adapter_files'].items():assert sha(HERE/name)==value,name
    assert set(graph['adapter_files'])=={'engine_run.lua','policy_wiring.lua','test_wiring.lua','check_graph.py'}
    assert sha(BASE/'C07/inert_graph_raw.json')==graph['raw_report_sha256']
    assert sha(BASE/'C07/inert_graph_stdout.log')==graph['stdout_sha256']
    files={name:HERE/name for name in manifest['prepared_files']}
    files.update({'preparation_manifest.json':HERE/'preparation_manifest.json','authority.json':BASE/'authority.json',
      'cycle_orchestrator.py':ROOT/'tools/advisor_eval/development299/cycle.py',
      'installed_policy_record.json':installed/'record.json','installed_final_verification.json':final_path,
      'installed_validation.json':validation_path,'installed_graph_check.json':graph_path,
      'inert_graph_raw.json':BASE/'C07/inert_graph_raw.json','inert_graph_stdout.log':BASE/'C07/inert_graph_stdout.log',
      'source_C07_registration.json':BASE/'C07/registration.json'})
    for job in ('C03','C05'):
        for name in ('record.json','registration.json','audit.json'):files['prior_'+job+'_'+name]=BASE/job/name
    for name in selection['search_evidence']:files['observed_S05_'+name]=BASE/'S05'/name
    for name in pfiles:files['policy/'+name]=installed/'policy'/name
    metadata={'checkpoint':320,'installed_version':'2.120.0-alpha','policy_digest':POLICY,
      'hypothesis':'Observe whether exact320 five-card pack/history and additive-growth integration changes actual Certificate/CardSharp selection, subsequent discards and Pillar progression on previously lost dependent C05 seed S7PXV521.',
      'maximum_actions':500,'outer_seconds':180,'seed':'S7PXV521','deck':'b_red','stake':8,
      'attempt_scope':'One fresh full source initialization; no captured replay, prefix import, checkpoint reload or retry. Preserve every loss/error/unsupported/timeout/censored outcome.',
      'selection':'Exact observed S05 OR-copy recipe previously used by C03/C05; selected dependent development, not unseen validation.',
      'profile':'all_unlocked_discovered_v1','gold_objective_context':'synthetic_fresh_all_missing_v1',
      'profile_semantics':'Naturally empty loaded synthetic Joker history must capture150missing0unknown before decisions; no fabricated prior sticker wins.',
      'retry_context':'disabled_clean','qualification':False,'player_profile_access':False,'save_access':'none',
      'native_search_in_attempt':False,'source_access':'Executable ZIP and isolated lua51.dll only; never launch Balatro.exe',
      'opening_jokers':['j_yorick','j_perkeo'],'conditional_later_targets':recipe['conditional_later_requirements'],
      'no_perishable_targets':True,'search_receipt':selection['search_evidence'],'copy_branch_observed_by_search':False,
      'adapter_change':'No source-adapter change from C07. Only worker/job/known recipe change; complete current graph receipt reused through exact identical adapter/checker hashes.',
      'product_execution_ui_bypassed':True,'ui_scope':'No live startup/search/CashOut/auto-run/logging/checkpoint or8x/16x timing qualification.',
      'confounding':'Multiple policy changes after312; a fresh dependent complete run cannot isolate one intervention or infer player odds/human superiority.',
      'metrics':['terminal consistency/original callbacks/synthetic Gold deltas','selected-action legality/exact scores/supported floors/random gaps',
        'Certificate/CardSharp pack comparison families and actual acquisition','physical discard history/Yorick growth/Perkeo copies/Pillar outcome',
        'cash/inventory/retention and ordinary140000/shop50000/consumable25000/fastclear70 budgets','advice/action/whole attempt seconds'],
      'installed_final_verification_sha256':FINAL,'installed_graph_check_sha256':GRAPH,
      'python_executable':str(Path(sys.executable).resolve()),'python_version':sys.version}
    external=[Path(name) for name in regs['C07']['external_files'] if Path(name).name.lower() in ('balatro.exe','lua51.dll')]
    assert {p.name.lower() for p in external}=={'balatro.exe','lua51.dll'}
    external.append(Path(sys.executable).resolve())
    metadata['prior_external_files']={str(p):regs['C07']['external_files'][str(p)] for p in external}
    return files,metadata,external
def register(installed,expected):
    files,metadata,external=plan(installed,expected)
    assert (BASE/'C07/record.json').exists(),'Serial C08 registration waits for C07 to be reaped'
    files['prior_C07_record.json']=BASE/'C07/record.json'
    previous=read(BASE/'C07/registration.json')['external_files']
    for p in external:assert sha(p)==previous[str(p)],'Source/runtime changed before registration'
    spec=importlib.util.spec_from_file_location('c08_cycle',ROOT/'tools/advisor_eval/development299/cycle.py')
    cycle=importlib.util.module_from_spec(spec);spec.loader.exec_module(cycle)
    return cycle.register('C08',files,[sys.executable,'-B','-u','{job}/run_attempt8.py'],metadata,external=external)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--installed-dir',type=Path,required=True)
    parser.add_argument('--expected-policy-digest',required=True)
    modes=parser.add_mutually_exclusive_group(required=True);modes.add_argument('--describe',action='store_true');modes.add_argument('--register',action='store_true')
    args=parser.parse_args()
    if args.describe:
        files,metadata,external=plan(args.installed_dir,args.expected_policy_digest)
        print(json.dumps({'frozen_file_count':len(files),'extra_at_registration':'prior_C07_record.json',
          'metadata':metadata,'external_paths_not_read':list(map(str,external))},indent=2))
    else:print(register(args.installed_dir,args.expected_policy_digest))
