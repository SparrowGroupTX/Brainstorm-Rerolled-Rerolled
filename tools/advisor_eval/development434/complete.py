"""Record the exact passing candidate without changing historical evidence."""
from pathlib import Path
import re,shutil,subprocess
from release import HERE,EVAL,ROOT,CANDIDATE,exact,journals,save,now,processes,read
from benchmark import file_digest

def gate_counts(folder):
 gate=read(folder/'validation/report.json')
 assert all(gate[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
 text=(folder/'validation/lua.log').read_text(encoding='utf-8')
 m=re.search(r'(\d+)/(\d+) fixtures passed',text);assert m and m[1]==m[2]
 py=sum(int(re.search(r'Ran (\d+) tests',(folder/'validation'/name).read_text(encoding='utf-8'))[1])
  for name in ('python.log','python_1.log','python_2.log'))
 result={'lua_fixtures':int(m[1]),'python_tests':py}
 assert result=={'lua_fixtures':310,'python_tests':458}
 for label,count in [('Discard product434',52536),('Acorn continuity434',3240),('Copy reserve434',12),('Burnt stale434',14),('Road433',41),('advisor_yorick_discard382',157)]:
  assert re.search(re.escape(label)+r': '+str(count)+r' ',text),label
 return result

def main():
 base,installed,f,pre=exact();capture,manifest,summary=journals(True)
 counts=gate_counts(CANDIDATE)
 changed_tests={r for r,h in f['test_files'].items()if pre['test_files'].get(r)!=h}
 assert len(changed_tests)==7,sorted(changed_tests)
 for rel,h in pre['before_files'].items():
  if rel not in set(f['changed_runtime_files'])|changed_tests:assert file_digest(ROOT/rel)==h,rel
 branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
 assert branch=='codex/exact-search-speedups'
 record={'created_utc':now(),'revision':434,'version':'2.214.0-alpha','status':'exact_candidate_validated_not_installed',
  'candidate':CANDIDATE.relative_to(ROOT).as_posix(),'policy_digest':f['candidate_policy_digest'],
  'validation_counts':counts,'new_fixture_assertions':55930,'runtime_file_count':len(f['candidate_policy_files']),
  'test_file_count':len(f['test_files']),'changed_runtime_files':f['changed_runtime_files'],
  'changed_test_files':sorted(changed_tests),'installed_baseline':433,'installed_runtime_unchanged':True,
  'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
  'settings_and_seven_dlls_preserved':True,'latest_public_capture':capture.relative_to(ROOT).as_posix(),
  'latest_public_events':summary['events'],'latest_public_outcomes':summary['outcomes'],
  'latest_public_loaded_label':'2.213.0-alpha','latest_public_sources_match':True,'passive_processes':processes(),
  'normal_exit_inferred':False,'confirmation_required':False,'review_cycle_exhausted':True,
  'captured_policy_or_scorer_replay':False,'simulation':False,'game_control':False,'save_profile_access':False,
  'original_game_execution':False,'automation_created':False,'historical_experiments':'CLOSED',
  'loaded_candidate_evidence':False,'all_discard_cases_fixed_claim':False,'win_rate_claim':False,'branch':branch,
  'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in
   [CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json',HERE/'REPORT.md',HERE/'REVIEW.md',capture/'manifest.json',capture/'summary.json']}}
 save(HERE/'FINAL_VERIFICATION.json',record)
 with (HERE/'final_changes.diff').open('xb')as out:out.write((CANDIDATE/'changes.diff').read_bytes())
 print({k:record[k]for k in ('version','policy_digest','validation_counts','new_fixture_assertions','passive_processes')})
if __name__=='__main__':main()
