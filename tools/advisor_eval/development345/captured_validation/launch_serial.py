"""Root-invoked serial outer watchdog. Preparation/import starts no workers."""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

from policy_eval import JOB_IDS,LIMITS,HERE,checked,read,sha,verify,write

def utc(): return datetime.now(timezone.utc).isoformat()
def ref(path): return {'path':str(path.resolve()),'sha256':sha(path),'bytes':path.stat().st_size}
def bytes_once(path,data):
    with path.open('xb') as stream: stream.write(data)
def error_text(error): return type(error).__name__+': '+str(error)

def preflight(ledger):
    manifest_path=ledger/'registration_manifest.json';manifest=read(manifest_path)
    authority_path=checked(manifest['authority']);authority=read(authority_path)
    if (authority_path!=ledger/'authority.json' or authority.get('kind')!='gold345_captured_shop_authority' or
        authority.get('status')!='AUTHORIZED' or authority.get('approved_by')!='user' or
        not authority.get('approval_text') or not authority.get('approval_reference') or
        authority.get('limits')!=LIMITS or authority.get('job_ids')!=list(JOB_IDS) or
        authority.get('serial_only') is not True or authority.get('no_replacements') is not True or
        Path(authority.get('ledger_directory','')).resolve()!=ledger or
        manifest.get('total_reserved_seconds')!=120 or manifest.get('workers_started')!=0):
        raise ValueError('Exact fresh four-job authority and prospective registration manifest required')
    if checked(manifest['launcher'])!=Path(__file__).resolve(): raise ValueError('Run exact prospectively hashed launcher')
    jobs=manifest['jobs']
    if [job.get('job_id') for job in jobs]!=list(JOB_IDS): raise ValueError('Four exact serial jobs required')
    for job in jobs:
        name=job['job_id'];folder=ledger/name;reg_path=checked(job['registration']);reg=read(reg_path)
        if (reg_path!=folder/'registration.json' or reg.get('job_id')!=name or
            reg.get('timeout_seconds')!=30 or reg.get('one_use') is not True or
            reg.get('authority')!=manifest['authority'] or reg.get('command')!=job.get('command') or
            job.get('reserved_seconds')!=30 or
            checked(reg['adapter_files']['launch_serial.py'])!=Path(__file__).resolve()):
            raise ValueError('Changed job, launcher or prospective limits')
        expected=[str(Path(sys.executable).resolve()),str(HERE/'policy_eval.py'),str(reg_path)]
        if reg['command']!=expected: raise ValueError('Unexpected worker command')
        if any((folder/name).exists() for name in ('spent.json','worker_started.json','launcher_receipt.json','stdout.bin','stderr.bin')):
            raise ValueError('One-use job already spent or output exists: '+job['job_id'])
    if any((ledger/name).exists() for name in ('launcher_started.json','CLOSED.json')):
        raise ValueError('This ledger has already started or closed; no retry or reset is allowed')
    return manifest,jobs

def run_job(ledger,job,authority_ref):
    name=job['job_id'];folder=ledger/name;reg_path=Path(job['registration']['path'])
    # Spending precedes verification, process creation and all possible failures.
    write(folder/'spent.json',{'kind':'gold345_captured_policy_spent','job_id':name,'one_use':True,
          'registration_sha256':job['registration']['sha256'],'authority_sha256':authority_ref['sha256'],
          'reserved_seconds':30,'spent_at_utc':utc(),'launcher_sha256':sha(Path(__file__))})
    start=time.perf_counter();deadline=start+30;started_at=utc()
    process=None;stdout=b'';stderr=b'';status='error';failure=None;returncode=None
    try:
        reg,_,_,_,_=verify(reg_path) # Hash verification only; does not load Lua.
        remaining=deadline-time.perf_counter()
        if remaining<=0: raise subprocess.TimeoutExpired(reg['command'],30)
        process=subprocess.Popen(reg['command'],cwd=str(folder),stdin=subprocess.DEVNULL,
          stdout=subprocess.PIPE,stderr=subprocess.PIPE,
          creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        remaining=max(0,deadline-time.perf_counter())
        try:
            stdout,stderr=process.communicate(timeout=remaining)
        except subprocess.TimeoutExpired:
            process.kill()
            stdout,stderr=process.communicate()
            raise
        returncode=process.returncode
        status='completed' if returncode==0 else 'error'
    except subprocess.TimeoutExpired as error:
        status='timeout';failure=error_text(error)
        if process is not None: returncode=process.returncode
    except BaseException as error:
        failure=error_text(error)
        if process is not None and process.poll() is None:
            process.kill();stdout,stderr=process.communicate();returncode=process.returncode
        if isinstance(error,(KeyboardInterrupt,SystemExit)): status='interrupted'
    actual=time.perf_counter()-start
    bytes_once(folder/'stdout.bin',stdout);bytes_once(folder/'stderr.bin',stderr)
    evidence={name:ref(folder/name) for name in ('worker_started.json','result.json','summary.json','worker_error.json') if (folder/name).is_file()}
    policy_status=None;collection_diagnostics=None
    if (folder/'summary.json').is_file():
        try:
            summary=read(folder/'summary.json');policy_status=summary.get('status')
            collection_diagnostics={key:summary[key] for key in ('gold_acquisition_diagnostics','gold_final_diagnostics') if key in summary}
            if policy_status=='timeout': status='timeout'
        except Exception as error: failure=(failure+'; ' if failure else '')+'Summary read: '+error_text(error)
    elif (folder/'worker_error.json').is_file():
        try:
            if read(folder/'worker_error.json').get('status')=='timeout': status='timeout'
        except Exception as error: failure=(failure+'; ' if failure else '')+'Worker error read: '+error_text(error)
    receipt={'schema':1,'kind':'gold345_outer_worker_receipt','job_id':job['job_id'],'one_use':True,
      'status':status,'policy_status':policy_status,'returncode':returncode,'error':failure,'collection_diagnostics':collection_diagnostics,
      'reserved_seconds':30,'actual_seconds':actual,'watchdog_seconds':30,
      'watchdog_termination_overhead_seconds':max(0,actual-30),
      'started_at_utc':started_at,'finished_at_utc':utc(),'process_created':process is not None,
      'command':job['command'],'registration':job['registration'],'spent_receipt':ref(folder/'spent.json'),
      'stdout':ref(folder/'stdout.bin'),'stderr':ref(folder/'stderr.bin'),'worker_evidence':evidence,
      'source_execution':False,'action_dispatch':False,'retry_allowed':False,
      'scope':'One registered detached policy process, with verification and process lifetime under the outer 30-second watchdog. Actual elapsed time includes termination overhead rather than truncating it.'}
    write(folder/'launcher_receipt.json',receipt)
    print(json.dumps({key:receipt[key] for key in ('job_id','status','policy_status','returncode','actual_seconds')}),flush=True)
    return receipt

def main():
    if len(sys.argv)!=2: raise ValueError('Supply one exact preregistered ledger directory')
    ledger=Path(sys.argv[1]).resolve();manifest,jobs=preflight(ledger)
    write(ledger/'launcher_started.json',{'kind':'gold345_serial_launcher_started','one_use':True,
      'started_at_utc':utc(),'launcher_sha256':sha(Path(__file__)),
      'registration_manifest_sha256':sha(ledger/'registration_manifest.json'),'authority':manifest['authority']})
    receipts=[];fatal=None
    try:
        for job in jobs:
            receipt=run_job(ledger,job,manifest['authority']);receipts.append(receipt)
            if receipt['status']=='interrupted': break
    except BaseException as error: fatal=error_text(error)
    finally:
        completed={r['job_id'] for r in receipts};unstarted=[]
        for job in jobs:
            if job['job_id'] not in completed:
                folder=ledger/job['job_id'];spent=(folder/'spent.json').exists()
                unstarted.append({'job_id':job['job_id'],'spent':spent,'status':'incomplete_receipt' if spent else 'unstarted_closed','reserved_seconds':30,
                  'actual_seconds':None if spent else 0,'reason':fatal or 'Interrupted serial launcher; unused allowance closed.'})
        spent_jobs=sum((ledger/job/'spent.json').exists() for job in JOB_IDS)
        closure={'schema':1,'kind':'gold345_captured_validation_closure','status':'CLOSED','closed_at_utc':utc(),
          'authority':manifest['authority'],'registration_manifest':ref(ledger/'registration_manifest.json'),
          'launcher':ref(Path(__file__)),'total_reserved_seconds':120,'spent_reserved_seconds':30*spent_jobs,
          'unused_reserved_seconds_closed':120-30*spent_jobs,'actual_seconds_recorded':sum(r['actual_seconds'] for r in receipts),
          'actual_total_complete':not any(x['spent'] for x in unstarted),
          'registered_jobs':4,'spent_jobs':spent_jobs,'processes_created':sum(r['process_created'] for r in receipts),
          'outcome_counts':{key:sum(r['status']==key for r in receipts) for key in ('completed','error','timeout','interrupted')},
          'job_receipts':[ref(ledger/r['job_id']/'launcher_receipt.json') for r in receipts],
          'unstarted_or_incomplete':unstarted,'fatal_error':fatal,'replacement_jobs':0,
          'source_jobs':0,'search_jobs':0,'complete_attempt_jobs':0,'qualification':False,'terminal_evidence':False,
          'scope':'Four one-use dependent recorded public policy evaluations only. Errors/timeouts/unsupported diagnostics remain explicit; unused capacity is permanently closed.'}
        write(ledger/'CLOSED.json',closure)
    return 0 if fatal is None and len(receipts)==4 and all(r['status']=='completed' for r in receipts) else 2

if __name__=='__main__': raise SystemExit(main())
