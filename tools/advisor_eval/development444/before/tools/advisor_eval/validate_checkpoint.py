"""Bounded regression logs tied to an unchanged frozen installed policy."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import subprocess
import sys
import time
import shutil
from benchmark import file_digest, policy_hashes, digest

ROOT=Path(__file__).resolve().parents[2]

PYTHON_GROUPS=('test_advisor_*.py','test_teacher_decision_timing.py','test_wall_time_decomposition.py')

def test_manifest(root=ROOT):
    directory=root/'tests'
    declared={p for pattern in PYTHON_GROUPS for p in directory.glob(pattern)}
    unknown=set(directory.rglob('test_*.py'))-declared
    if unknown: raise ValueError('Unclassified Python tests: '+', '.join(str(p.relative_to(root)) for p in sorted(unknown)))
    paths=declared|set(directory.rglob('*.lua'))
    return {p.relative_to(root).as_posix():file_digest(p) for p in sorted(paths) if p.is_file()}

def provenance(root=ROOT):
    helpers={root/'tests/run_lua_tests.py',Path(__file__).resolve(),Path(sys.executable)}
    for directory in ('tools/advisor_eval','tools/advisor_learning'):
        helpers.update((root/directory).glob('*.py'))
    runtime=shutil.which('luajit') or shutil.which('lua')
    if runtime:
        runtime=Path(runtime);lua_args=['--lua',str(runtime)]
    else:
        runtime=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
        if not runtime.is_file(): raise ValueError('No qualified Lua runtime available')
        lua_args=['--lua-library',str(runtime)]
    helpers.add(runtime)
    return {'python_version':sys.version,'lua_arguments':lua_args,
        'files':{str(p.resolve()):file_digest(p) for p in sorted(helpers)}}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--policy',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    expected=policy_hashes(a.policy)
    if policy_hashes(ROOT)!=expected: raise ValueError('Worktree runtime differs from the frozen policy before validation')
    a.output.mkdir(parents=True,exist_ok=False)
    tests=test_manifest();environment=provenance()
    report={'created_utc':datetime.now(timezone.utc).isoformat(),'policy_digest':digest(expected),
            'policy_files':expected,'test_files':tests,'validation_provenance':environment,
            'python_groups':PYTHON_GROUPS,'qualification':False,'runs':[]}
    commands=[('lua',[sys.executable,'tests/run_lua_tests.py',*environment['lua_arguments']])]
    commands.extend(('python' if i==0 else 'python_'+str(i),
        [sys.executable,'-m','unittest','discover','-s','tests','-p',pattern])
        for i,pattern in enumerate(PYTHON_GROUPS))
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
    current_tests=test_manifest()
    report['tests_unchanged']=current_tests==tests
    report['provenance_unchanged']=provenance()==environment
    report['passed']=report['policy_unchanged'] and report['tests_unchanged'] and report['provenance_unchanged'] and all(r['status']=='passed' for r in report['runs'])
    (a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ('policy_digest','runs','policy_unchanged','tests_unchanged','passed')}))
    return 0 if report['passed'] else 1

if __name__=='__main__': sys.exit(main())
