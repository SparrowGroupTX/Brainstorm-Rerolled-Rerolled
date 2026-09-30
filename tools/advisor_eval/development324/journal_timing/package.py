"""Bind detached journal candidate and manufactured validation; no staging."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
base=sha(HERE/'player_journal.base.lua')
assert sha(ROOT/'Brainstorm/Advisor/player_journal.lua')==base,'Production journal changed before packaging'
files=['player_journal.base.lua','player_journal.lua','test_player_journal_timing.lua',
       'run_candidate.lua','run_archive.py','INTEGRATION.md','package.py']
dependencies=['Brainstorm/Advisor/player_log_archive.lua','tools/advisor_eval/read_player_log.py',
              'tests/advisor_player_journal.lua','tests/test_advisor_player_log_archive.py','tests/run_lua_tests.py']
record={
 'schema':1,'status':'detached_ready_for_review','runtime_changed':False,'experiments':0,
 'integration':[
  {'source':'player_journal.lua','target':'Brainstorm/Advisor/player_journal.lua','base_sha256':base,'sha256':sha(HERE/'player_journal.lua')},
  {'source':'test_player_journal_timing.lua','target':'tests/advisor_player_journal_timing.lua','base_sha256':None,'sha256':sha(HERE/'test_player_journal_timing.lua')}
 ],
 'collector_api':['P:now()','P:record(label, seconds)'],
 'collector_labels':['journal.observe','journal.encode','journal.append','journal.total'],
 'files':[{'path':f,'sha256':sha(HERE/f)}for f in files],
 'dependencies':[{'path':f,'sha256':sha(ROOT/f)}for f in dependencies],
 'validation':[
  {'command':'python tests/run_lua_tests.py tools/advisor_eval/development324/journal_timing/run_candidate.lua','exit_code':0,'new_checks':105,'existing_checks':21},
  {'command':'python tools/advisor_eval/development324/journal_timing/run_archive.py','exit_code':0,'python_tests':16,'new_tests':1,'existing_tests':15}
 ],
 'limitations':['Elapsed wall timing, not process CPU time.','No live timing benefit or freeze diagnosis demonstrated.','Advice performance summary API and root collector flush/acknowledgment integration remain parent-owned.','Existing append/storage/sequence/rotation/retry protections unchanged.']
}
path=HERE/'manifest.json'
with path.open('x',encoding='utf-8',newline='\n')as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({'manifest':path.relative_to(ROOT).as_posix(),'sha256':sha(path),
                  'journal_sha256':sha(HERE/'player_journal.lua'),'fixture_sha256':sha(HERE/'test_player_journal_timing.lua')}))
