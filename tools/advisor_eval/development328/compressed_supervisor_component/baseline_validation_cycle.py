"""One-use execution for the user's fresh six-pair/six-attempt validation batch.

Registers exact bytes before execution. No search, old quota reuse, game process
control or save access. Only isolated Python workers may launch, serially.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'tools/advisor_eval/runs/loss328_validation_20260915'
AUTHORITY_SHA='7bd5086a7de41d3f1150727fb7fad4075dc9fa7f92e4c2b249abaf0e1b7ce0e2'
CAPS={**{f'P{i:02}':30 for i in range(1,7)},**{f'C{i:02}':180 for i in range(1,7)}}
MAX_TRACE_BYTES=268435456


def sha(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def create(path,value):
    with Path(path).open('x',encoding='utf-8') as stream:
        json.dump(value,stream,indent=2,allow_nan=False);stream.write('\n')
def utc():return datetime.now(timezone.utc).isoformat()


@contextmanager
def batch_lock():
    # The OS releases this lock on an abnormal supervisor exit. Retain the
    # lock file itself; neither directory deletion nor a new quota is needed.
    with (BASE/'supervisor.lock').open('a+b') as stream:
        stream.seek(0,2)
        if stream.tell()==0:stream.write(b'0');stream.flush()
        stream.seek(0)
        if sys.platform=='win32':
            import msvcrt
            msvcrt.locking(stream.fileno(),msvcrt.LK_NBLCK,1)
            try:yield
            finally:stream.seek(0);msvcrt.locking(stream.fileno(),msvcrt.LK_UNLCK,1)
        else:
            import fcntl
            fcntl.flock(stream.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
            try:yield
            finally:fcntl.flock(stream.fileno(),fcntl.LOCK_UN)


def command_script(command,folder):
    assert str(Path(command[0]).resolve())==str(Path(sys.executable).resolve())
    args=list(command[1:]);flags=[]
    while args and args[0] in ('-B','-u'):
        flag=args.pop(0);assert flag not in flags;flags.append(flag)
    assert len(args)==1,'Only one frozen script and optional -B/-u flags are allowed'
    script=Path(args[0]).resolve()
    assert script.suffix=='.py' and script.is_relative_to(folder.resolve())
    return script.relative_to(folder.resolve()).as_posix()


def authority():
    path=BASE/'authority.json'
    assert sha(path)==AUTHORITY_SHA and not (BASE/'CLOSED.json').exists(),'Authority changed or closed'
    value=read(path)
    assert value['status']=='ACTIVE' and value['limits']=={
        'detached_comparison_jobs':6,'seconds_per_comparison_job':30,
        'complete_attempt_jobs':6,'seconds_per_complete_attempt':180,
        'total_worker_seconds':1260,'search_jobs':0,'other_source_component_jobs':0}
    return value


def register(job,files,command,metadata,external=()):
    authority();assert job in CAPS
    assert metadata['kind']==('public_state_pair' if job.startswith('P') else 'complete_source_attempt')
    reservations=[read(path) for path in BASE.glob('*_reservation.json')]
    assert sum(item['timeout_seconds'] for item in reservations)+CAPS[job]<=1260
    assert all(item['job']!=job for item in reservations)
    assert str(Path(command[0]).resolve())==str(Path(sys.executable).resolve())
    # Validate every source path before the one-use reservation. No source
    # runtime is initialized by this freezing step.
    folder=BASE/job
    frozen={}
    for relative,source in files.items():
        assert relative and not Path(relative).is_absolute() and '..' not in Path(relative).parts
        assert relative not in ('registration.json','spent.json','record.json','trace.log','registration_error.json')
        (folder/relative).resolve().relative_to(folder.resolve())
        frozen[relative]=sha(source)
    external_hashes={str(Path(p).resolve()):sha(p) for p in external}
    assert str(Path(sys.executable).resolve()) in external_hashes,'Freeze the Python runtime'
    argv=[part.replace('{job}',str(folder.resolve())) for part in command]
    assert command_script(argv,folder) in frozen,'The entry script must be frozen'
    create(BASE/(job+'_reservation.json'),{'job':job,'timeout_seconds':CAPS[job],
        'authority_sha256':AUTHORITY_SHA,'one_use':True,'created_at_utc':utc()})
    folder.mkdir(exist_ok=False)
    try:
        for relative,source in files.items():
            target=folder/relative;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,target);assert sha(target)==frozen[relative]
        value={'schema':1,'kind':'loss328_registered_job','job':job,
            'authority_sha256':AUTHORITY_SHA,'reservation_sha256':sha(BASE/(job+'_reservation.json')),
            'timeout_seconds':CAPS[job],'command':argv,'files':frozen,'external_files':external_hashes,
            'metadata':metadata,'created_at_utc':utc()}
        create(folder/'registration.json',value)
    except Exception as error:
        create(folder/'registration_error.json',{'job':job,'error':str(error),'one_use_reserved':True,'at_utc':utc()})
        raise
    return folder


def _run_locked(job):
    authority();assert job in CAPS
    folder=BASE/job;r=read(folder/'registration.json')
    assert r['job']==job and r['timeout_seconds']==CAPS[job]
    assert r['authority_sha256']==AUTHORITY_SHA
    assert r['reservation_sha256']==sha(BASE/(job+'_reservation.json'))
    for relative,expected in r['files'].items():assert sha(folder/relative)==expected,relative
    for path,expected in r['external_files'].items():assert sha(path)==expected,path
    for marker in BASE.glob('*/spent.json'):
        assert (marker.parent/'record.json').exists(),'Prior worker is active or unaccounted'
        assert read(marker.parent/'record.json').get('worker_reaped') is True,'Prior worker termination is unconfirmed'
    assert command_script(r['command'],folder) in r['files']
    assert str(Path(sys.executable).resolve()) in r['external_files']
    registration_hash=sha(folder/'registration.json')
    create(folder/'spent.json',{'job':job,'registration_sha256':registration_hash,
        'started_at_utc':utc(),'one_use':True})
    started=time.monotonic();process=None;status='error';code=None;reason=None;worker_reaped=False
    trace=folder/'trace.log'
    try:
        with trace.open('xb') as stream:
            process=subprocess.Popen(r['command'],cwd=folder,stdout=stream,stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            while True:
                elapsed=time.monotonic()-started
                # An exited worker still needs to satisfy the outer wall and
                # output bounds; polling completion never bypasses either.
                if elapsed>=CAPS[job]:status='timeout';reason='worker_wall_cap';break
                if trace.stat().st_size>MAX_TRACE_BYTES:status='censored';reason='trace_byte_cap';break
                code=process.poll()
                if code is not None:
                    status='complete' if code==0 else 'error';break
                time.sleep(min(.1,CAPS[job]-elapsed))
    except Exception as error:
        status='error';reason='worker_launch_or_supervision_error: '+repr(error)
    finally:
        try:
            if process is None:worker_reaped=True
            else:
                if process.poll() is None:process.kill();process.wait(timeout=5)
                code=process.poll();worker_reaped=code is not None
        except Exception as error:
            status='error';reason=(reason or '')+'; worker_reap_error: '+repr(error)
    verification_errors=[]
    def checked(path,expected):
        try:return sha(path)==expected
        except Exception as error:
            verification_errors.append({'path':str(path),'error':repr(error)});return False
    try:trace_hash,trace_bytes=sha(trace),trace.stat().st_size
    except Exception as error:
        trace_hash,trace_bytes=None,None;verification_errors.append({'path':str(trace),'error':repr(error)})
    record={'job':job,'status':status,'exit_code':code,'reason':reason,
        'elapsed_seconds':time.monotonic()-started,'timeout_seconds':CAPS[job],
        'registration_sha256':registration_hash,'trace_sha256':trace_hash,
        'trace_bytes':trace_bytes,'one_use_spent':True,
        'worker_pid':process.pid if process is not None else None,'worker_reaped':worker_reaped,
        'frozen_files_unchanged':all([checked(folder/p,h) for p,h in r['files'].items()]),
        'external_files_unchanged':all([checked(p,h) for p,h in r['external_files'].items()]),
        'verification_errors':verification_errors,
        'outcome':'pending_trace_audit','qualification':False}
    create(folder/'record.json',record);print(json.dumps(record))


def run(job):
    with batch_lock():return _run_locked(job)


if __name__=='__main__':
    if len(sys.argv)==3 and sys.argv[1]=='run':run(sys.argv[2])
    else:raise SystemExit('Use run JOB after explicit frozen registration; there is no init/reset operation.')
