"""Bounded regression logs tied to an unchanged frozen installed policy."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import subprocess
import sys
import time
from benchmark import file_digest, policy_hashes, digest

ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--policy',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    expected=policy_hashes(a.policy)
    if policy_hashes(ROOT)!=expected: raise ValueError('Worktree runtime differs from the frozen policy before validation')
    a.output.mkdir(parents=True,exist_ok=False)
    tests={str(f.relative_to(ROOT)):file_digest(f) for f in sorted((ROOT/'tests').rglob('*'))
           if f.is_file() and (f.suffix=='.lua' or f.name.startswith('test_advisor_') and f.suffix=='.py')}
    report={'created_utc':datetime.now(timezone.utc).isoformat(),'policy_digest':digest(expected),
            'policy_files':expected,'test_files':tests,'qualification':False,'runs':[]}
    commands=[('lua',[sys.executable,'tests/run_lua_tests.py']),
              ('python',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_advisor_*.py'])]
    for name,command in commands:
        start=time.monotonic()
        try:
            result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,
                                  creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            output=result.stdout+'\n'+result.stderr
            entry={'name':name,'command':command,'status':'passed' if result.returncode==0 else 'failed','exit_code':result.returncode}
        except subprocess.TimeoutExpired as error:
            output=str(error.stdout or '')+'\n'+str(error.stderr or '')
            entry={'name':name,'command':command,'status':'timeout','timeout_seconds':60}
        entry['seconds']=time.monotonic()-start
        (a.output/(name+'.log')).write_text(output,encoding='utf-8')
        report['runs'].append(entry)
        (a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    report['policy_unchanged']=policy_hashes(ROOT)==expected==policy_hashes(a.policy)
    current_tests={str(f.relative_to(ROOT)):file_digest(f) for f in sorted((ROOT/'tests').rglob('*'))
                   if f.is_file() and (f.suffix=='.lua' or f.name.startswith('test_advisor_') and f.suffix=='.py')}
    report['tests_unchanged']=current_tests==tests
    report['passed']=report['policy_unchanged'] and report['tests_unchanged'] and all(r['status']=='passed' for r in report['runs'])
    (a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ('policy_digest','runs','policy_unchanged','tests_unchanged','passed')}))
    return 0 if report['passed'] else 1

if __name__=='__main__': sys.exit(main())
