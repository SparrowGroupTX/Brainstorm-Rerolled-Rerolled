"""Read-only preservation/provenance verification, except this new receipt."""
from datetime import datetime,timezone
from pathlib import Path
import hashlib,json,platform,subprocess,sys
EVAL=Path(__file__).resolve().parents[1];R=EVAL.parents[1];P=Path(__file__).resolve().parent
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def load(p):return json.loads(p.read_text())
out=P/'FINAL_VERIFICATION.json';assert not out.exists()
pre=load(P/'prework.json');checkpoint=load(EVAL/'SESSION_RESET_404.json')
assert policy_hashes(R)==policy_hashes(Path(checkpoint['installed']).parent)==pre['runtime_files']==checkpoint['policy_files']
prior=load(EVAL/'development406/validation/manifest.json')
assert test_manifest()==prior['test_files']
assert provenance()==prior['provenance']
for name,sha in pre['native_repository'].items():assert file_digest(R/name)==sha,name
for name,sha in pre['native_installed'].items():assert file_digest(Path(name))==sha,name
for name,sha in pre['before_files'].items():
 old=P/'before'/name;assert file_digest(old)==sha,name
 assert (R/name).read_bytes().endswith(old.read_bytes()),name
old_receipt=EVAL/'development406/final_verification.json'
assert file_digest(old_receipt)==pre['prior406_verification_sha256']
old_count=0
for name,sha in load(old_receipt)['artifact_hashes'].items():
 if name not in pre['before_files']:
  assert file_digest(R/name)==sha,name;old_count+=1
cap=load(P/'capture/manifest.json');verified=load(P/'capture/verification.json');matches=[]
for e in cap['segments']:
 f=P/'logs1'/e['name'];assert f.stat().st_size==e['bytes'] and file_digest(f)==e['sha256'],e['name']
 source=Path(cap['source'])/e['name'];matches.append({'name':e['name'],'source_present':source.is_file(),
  'matches_copied_capture':source.is_file() and file_digest(source)==e['sha256']})
assert file_digest(P/'events.sqlite3')==verified['database_sha256']
assert not verified['failures'] and verified['events']==22817 and verified['outcomes']=={'win':4,'loss':4,'unsupported':2}
links=load(P/'deep2/links.json');assert len(links)==1929
assert all(all(x[k] for k in ('same_scope','same_observation','causal','current_advice','actual_matches_advice','callback_linked','marker_linked'))for x in links)
summary=load(P/'deep2/summary.json');assert summary['death_confirmed']==2 and summary['buffoon_reveals_confirmed']==26
screen=load(P/'screen/report.json');assert screen['flags_total']==282 and screen['events']==22817
assert screen['screener_sha256']==file_digest(EVAL/'flag_suspect_decisions.py')
assert '21 checks passed' in (P/'manufactured_attempt1.log').read_text()
assert '8 checks passed' in (P/'manufactured_pack_final.log').read_text()
before=(P/'git_status_before.txt').read_text(encoding='utf-8-sig').strip().splitlines()
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=R,capture_output=True,text=True,check=True).stdout
(P/'git_status_after.txt').write_text(status,encoding='utf-8')
# New files live under pre-existing untracked tools/. Every previously listed
# tracked/untracked work entry must still be listed; do not infer byte identity
# for unrelated pre-existing files solely from git status.
assert set(before)<=set(status.strip().splitlines())
commands={
 'capture':'python tools/advisor_eval/development407/capture_logs.py',
 'index':'python tools/advisor_eval/development407/index_public.py',
 'analysis':'python tools/advisor_eval/development407/analyze_public.py',
 'deep_authoritative':'python tools/advisor_eval/development407/deep_audit_v2.py',
 'catalog':'python tools/advisor_eval/development407/audit_catalog.py',
 'followup':'python tools/advisor_eval/development407/followup_audit.py',
 'late_chains':'python tools/advisor_eval/development407/late_chains.py',
 'diagnostic_core':'python tests/run_lua_tests.py tools/advisor_eval/development407/manufactured_diagnostics.lua',
 'diagnostic_pack':'python tests/run_lua_tests.py tools/advisor_eval/development407/manufactured_pack_diagnostics.lua',
 'tables':'python tools/advisor_eval/development407/write_tables.py',
 'navigation':'python tools/advisor_eval/development407/update_navigation.py',
 'verification':'python tools/advisor_eval/development407/verify_delivery.py'}
artifacts=[p for p in P.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name not in ('FINAL_VERIFICATION.json','verify_delivery.log')]
artifacts += [R/n for n in pre['before_files']]+[EVAL/'AUDIT_CHECKPOINT_407.md']
result={'verified_utc':datetime.now(timezone.utc).isoformat(),'status':'completed_passive_cohort_audit',
 'runtime_version':checkpoint['version'],'runtime_digest':checkpoint['policy_digest'],'runtime_files_per_tree':len(pre['runtime_files']),
 'runtime_and_installation_unchanged':True,'native_files_per_tree':len(pre['native_repository']),
 'prior_test_files_unchanged':len(prior['test_files']),'prior_helper_and_runtime_provenance_unchanged':True,
 'prior406_artifacts_verified':old_count,'prior_navigation_bytes_preserved':True,'prior_git_status_entries_preserved':True,
 'current_captured_segments':len(cap['segments']),'source_comparison_at_delivery':matches,'capture_and_index_unchanged':True,
 'public_label':verified['versions'],'outcomes':verified['outcomes'],'linked_policy_actions':1929,'suspect_flags':282,
 'diagnostic_checks':29,'diagnostic_fixture_files':2,'diagnostic_scope':'invented production-module reproductions, not repairs or full-controller acceptance',
 'runtime_full_gate_rerun':False,'new_runtime_freeze_or_install':False,'game_control':False,'save_or_profile_access':False,
 'captured_policy_or_scorer_replay':False,'new_experiment_training_or_automation':False,'configuration_writes':False,
 'passive_process_at_delivery':load(P/'process_at_delivery.json'),'normal_exit_confirmed_for_latest_session':False,
 'commands':commands,'python_version':platform.python_version(),
 'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p) for p in sorted(set(artifacts))}}
out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ('status','runtime_digest','runtime_files_per_tree','prior_test_files_unchanged','prior406_artifacts_verified','current_captured_segments','outcomes','linked_policy_actions','diagnostic_checks','passive_process_at_delivery')}))
print('Original source segment matches:',sum(x['matches_copied_capture'] for x in matches),'/',len(matches))
