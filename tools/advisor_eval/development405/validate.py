"""Freeze and regression-test405 tooling only; never install or evaluate gameplay."""
from datetime import datetime,timezone
from pathlib import Path
import json,re,shutil,subprocess,sys,time

EVAL=Path(__file__).resolve().parents[1];ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import PYTHON_GROUPS,test_manifest,provenance

def main():
    out=Path(__file__).resolve().parent/'validation';out.mkdir(exist_ok=False)
    before=json.loads((out.parent/'prework.json').read_text())
    base=json.loads((EVAL/'SESSION_RESET_404.json').read_text())
    installed=Path(base['installed'])
    assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']==before['runtime_files']
    tests=test_manifest();environment=provenance()
    sources=['tools/advisor_eval/analyze_player_timing.py','tools/advisor_eval/inspect_player_log.py',
             'tests/test_advisor_log_integrity405.py']
    for rel in sources:
        target=out/'sources'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,target)
    snapshot={'created_utc':datetime.now(timezone.utc).isoformat(),'scope':'tooling_only_manufactured_python_regression',
       'installed_runtime_digest':base['policy_digest'],'runtime_files':base['policy_files'],
       'test_files':tests,'provenance':environment,'changed_source_files':{r:file_digest(ROOT/r) for r in sources}}
    (out/'manifest.json').write_text(json.dumps(snapshot,indent=2)+'\n',encoding='utf-8')
    report={'started_utc':datetime.now(timezone.utc).isoformat(),'manifest_sha256':file_digest(out/'manifest.json'),'runs':[]}
    for i,pattern in enumerate(PYTHON_GROUPS):
        command=[sys.executable,'-m','unittest','discover','-s','tests','-p',pattern]
        started=time.monotonic()
        try:
            result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,
               creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            log=result.stdout+'\n'+result.stderr
            count=re.search(r'Ran (\d+) tests',log)
            entry={'pattern':pattern,'command':command,'exit_code':result.returncode,
               'tests':int(count.group(1)) if count else None,'passed':result.returncode==0 and count is not None}
        except subprocess.TimeoutExpired as error:
            log=str(error.stdout or '')+'\n'+str(error.stderr or '')
            entry={'pattern':pattern,'command':command,'passed':False,'timeout_seconds':60}
        entry['seconds']=time.monotonic()-started
        name=f'python_{i}.log';(out/name).write_text(log,encoding='utf-8')
        entry['log']=name;entry['log_sha256']=file_digest(out/name);report['runs'].append(entry)
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    report['runtime_unchanged']=policy_hashes(ROOT)==policy_hashes(installed.parent)==before['runtime_files']
    report['tests_unchanged']=test_manifest()==tests
    report['provenance_unchanged']=provenance()==environment
    report['passed']=all(r['passed'] for r in report['runs']) and all(report[k] for k in ('runtime_unchanged','tests_unchanged','provenance_unchanged'))
    report['total_python_tests']=sum(r.get('tests') or 0 for r in report['runs'])
    report['no_runtime_release']=True
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='runs'}))
    return int(not report['passed'])

if __name__=='__main__':raise SystemExit(main())
