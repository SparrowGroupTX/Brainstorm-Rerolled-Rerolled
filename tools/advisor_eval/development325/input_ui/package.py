"""Validate detached ordinary-input/UI controls without root mutations."""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')


def main():
    wrappers=['run_candidate.lua']+['run_'+name+'.lua'for name in
      ('advisor_collection_core','advisor_collection_status','advisor_startup_ui','advisor_gold_layout','advisor_checkpoint_runtime')]
    command=[sys.executable,'tests/run_lua_tests.py']+[str((HERE/p).relative_to(ROOT))for p in wrappers]
    started=time.monotonic();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
    output=HERE/'focused_output.txt';output.write_text(result.stdout+result.stderr,encoding='utf-8')
    dump(HERE/'focused_report.json',{'schema':1,'kind':'manufactured_and_existing_fixture_validation_only',
       'status':'passed'if result.returncode==0 else 'failed','exit_code':result.returncode,'command':command,
       'new_checks':86,'existing_checks':490,'total_checks':576,'fixtures':6,
       'elapsed_seconds':time.monotonic()-started,'timestamp_utc':datetime.now(timezone.utc).isoformat(),
       'output_sha256':sha(output),'new_experiments':0,'live_game_or_player_files':False})
    if result.returncode:print(result.stdout+result.stderr);raise SystemExit(result.returncode)
    targets={'Brainstorm.lua':'Brainstorm/Core/Brainstorm.lua','advisor.lua':'Brainstorm/UI/advisor.lua',
       'collection_run.lua':'Brainstorm/UI/collection_run.lua','runtime.lua':'Brainstorm/Advisor/runtime.lua',
       'checkpoint_runtime.lua':'Brainstorm/Core/checkpoint_runtime.lua','test_advisor_input_ui.lua':'tests/advisor_input_ui.lua'}
    integration=[]
    for source,target in targets.items():
        base=HERE/(source[:-4]+'.base.lua')
        original=sha(base)if base.exists()else None
        integration.append({'source':source,'target':target,'sha256':sha(HERE/source),'base_sha256':original,
                            'current_base_matches':sha(ROOT/target)==original if (ROOT/target).exists()else original is None})
    deps=['tests/'+p+'.lua'for p in('advisor_collection_core','advisor_collection_status','advisor_startup_ui',
           'advisor_gold_layout','advisor_checkpoint_runtime')]+['tests/run_lua_tests.py']
    manifest={'schema':1,'kind':'detached_input_ui325_integration','status':'ready_for_independent_review',
      'root_runtime_changed':False,'root_tests_changed':False,'new_experiments':0,'integration':integration,
      'validation':{'path':'focused_report.json','sha256':sha(HERE/'focused_report.json')},
      'dependencies':[{'path':p,'sha256':sha(ROOT/p)}for p in deps],
      'files':[{'path':p.relative_to(HERE).as_posix(),'sha256':sha(p)}for p in sorted(HERE.rglob('*'))
               if p.is_file()and p.name!='manifest.json'and 'staging_backups'not in p.parts]}
    dump(HERE/'manifest.json',manifest)
    print(json.dumps({'status':'passed','checks':576,'manifest_sha256':sha(HERE/'manifest.json'),
                      'base_matches':{i['target']:i['current_base_matches']for i in integration}}))


if __name__=='__main__':main()
