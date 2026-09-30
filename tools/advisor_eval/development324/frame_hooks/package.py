"""Validate manufactured frame hooks and bind detached package provenance."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path,value):
    path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')


def main():
    command=[sys.executable,'tests/run_lua_tests.py',
             str((HERE/'run_candidate.lua').relative_to(ROOT)),str((HERE/'run_existing.lua').relative_to(ROOT))]
    start=time.monotonic()
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
    output=HERE/'focused_output.txt'
    output.write_text(result.stdout+result.stderr,encoding='utf-8')
    report={'schema':1,'kind':'manufactured_and_existing_fixture_validation_only',
            'status':'passed' if result.returncode==0 else 'failed','exit_code':result.returncode,
            'new_checks':76,'existing_checks':142,'total_checks':218,
            'command':command,'elapsed_seconds':time.monotonic()-start,
            'timestamp_utc':datetime.now(timezone.utc).isoformat(),'output_sha256':sha(output),
            'source_execution':False,'captured_replay':False,'complete_attempt':False,'live_measurement':False}
    dump(HERE/'focused_report.json',report)
    print(result.stdout+result.stderr)
    if result.returncode:raise SystemExit(result.returncode)
    targets=[('Brainstorm.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm.base.lua'),
             ('advisor.lua','Brainstorm/UI/advisor.lua','advisor.base.lua'),
             ('test_advisor_frame_timing.lua','tests/advisor_frame_timing.lua',None)]
    integration=[]
    for source,target,base in targets:
        assert not (ROOT/target).exists() if base is None else sha(ROOT/target)==sha(HERE/base)
        integration.append({'source':source,'target':target,'sha256':sha(HERE/source),
                            'base_sha256':sha(HERE/base) if base else None})
    manifest={'schema':1,'kind':'detached_frame_timing324_integration','status':'ready_for_independent_review',
              'root_runtime_changed':False,'root_tests_changed':False,'new_experiments':0,
              'collector_field':'Brainstorm.Advisor.performance',
              'integration':integration,
              'dependencies':[{'path':p,'sha256':sha(ROOT/p)} for p in
                              ['tests/advisor_collection_core.lua','tests/advisor_ui.lua','tests/run_lua_tests.py']],
              'validation':{'path':'focused_report.json','sha256':sha(HERE/'focused_report.json')},
              'package_files':[{'path':p.name,'sha256':sha(p)} for p in sorted(HERE.iterdir())
                               if p.is_file() and p.name!='manifest.json']}
    dump(HERE/'manifest.json',manifest)
    print(json.dumps({'manifest_sha256':sha(HERE/'manifest.json'),
                      'core_sha256':sha(HERE/'Brainstorm.lua'),'ui_sha256':sha(HERE/'advisor.lua'),
                      'fixture_sha256':sha(HERE/'test_advisor_frame_timing.lua')}))


if __name__ == '__main__':
    main()
