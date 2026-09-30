"""Prepare detached controller candidate only; no registration or job launch."""
from pathlib import Path
import difflib

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'validation_cycle.py'
before=SOURCE.read_text(encoding='utf-8')
after=before.replace('from contextlib import contextmanager','from contextlib import contextmanager\nimport stdout_transport')
after=after.replace("ROOT=Path(__file__).resolve().parents[3]", "ROOT=Path(__file__).resolve().parents[3]\nif Path(__file__).resolve().parent.name=='compressed_supervisor_component':ROOT=Path(__file__).resolve().parents[4]")
helper='''def compressed_contract(job,metadata):
    value=metadata.get('stdout_capture')
    if value is None:return False
    assert job.startswith('C') and value==stdout_transport.CONTRACT,'Require exact preregistered C stdout contract'
    return True


def transport_provenance(files,metadata):
    assert files.get('supervisor_source.py')==sha(__file__),'Freeze this exact supervisor'
    assert metadata.get('supervisor_sha256')==sha(__file__),'Bind this supervisor in metadata'
    assert files.get('stdout_transport.py')==sha(stdout_transport.__file__),'Freeze exact gzip transport/reader'


'''
after=after.replace('def register(job,files,command,metadata,external=()):',helper+'def register(job,files,command,metadata,external=()):')
after=after.replace("    assert metadata['kind']==('public_state_pair' if job.startswith('P') else 'complete_source_attempt')", "    assert metadata['kind']==('public_state_pair' if job.startswith('P') else 'complete_source_attempt')\n    compressed=compressed_contract(job,metadata)")
after=after.replace("'record.json','trace.log','registration_error.json'", "'record.json','trace.log','trace.log.gz','registration_error.json'")
after=after.replace("    create(BASE/(job+'_reservation.json'),", "    if compressed:transport_provenance(frozen,metadata)\n    create(BASE/(job+'_reservation.json'),")
after=after.replace("    folder=BASE/job;r=read(folder/'registration.json')", "    folder=BASE/job;r=read(folder/'registration.json')\n    compressed=compressed_contract(job,r['metadata'])\n    if compressed:transport_provenance(r['files'],r['metadata'])")
after=after.replace("        assert read(marker.parent/'record.json').get('worker_reaped') is True,'Prior worker termination is unconfirmed'", "        prior=read(marker.parent/'record.json')\n        assert prior.get('worker_reaped') is True,'Prior worker termination is unconfirmed'\n        assert prior.get('stdout_drain_completed',True) is True,'Prior stdout writer termination is unconfirmed'")
start=after.index("    started=time.monotonic();process=None;status='error'")
end=after.index('    verification_errors=[]',start)
original=after[start:end]
prefix='''    capture_result=None
    if compressed:
        started=time.monotonic();process=None
        capture_result=stdout_transport.capture(r['command'],folder,CAPS[job],
            compressed_cap=MAX_TRACE_BYTES,decoded_cap=stdout_transport.MAX_DECODED)
        status=capture_result['status'];code=capture_result['exit_code'];reason=capture_result['reason']
        worker_reaped=capture_result['worker_reaped'];trace=folder/'trace.log.gz'
    else:
'''
after=after[:start]+prefix+''.join('    '+line if line.strip() else line for line in original.splitlines(True))+after[end:]
after=after.replace("    try:trace_hash,trace_bytes=sha(trace),trace.stat().st_size", "    try:\n        if capture_result and not capture_result['stdout_drain_completed']:raise RuntimeError('Trace writer is unconfirmed; hash is unstable')\n        trace_hash,trace_bytes=sha(trace),trace.stat().st_size")
after=after.replace("    create(folder/'record.json',record);print(json.dumps(record))", "    if capture_result:\n        record.update({key:value for key,value in capture_result.items() if key!='elapsed_seconds'})\n        record['capture_elapsed_seconds']=capture_result['elapsed_seconds']\n        record['elapsed_seconds']=time.monotonic()-started\n    create(folder/'record.json',record);print(json.dumps(record))")
assert after!=before
for name,text in [('baseline_validation_cycle.py',before),('validation_cycle.py',after)]:
    with (HERE/name).open('x',encoding='utf-8',newline='') as stream:stream.write(text)
patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/tools/advisor_eval/development328/validation_cycle.py',tofile='b/tools/advisor_eval/development328/validation_cycle.py'))
with (HERE/'validation_cycle.patch').open('x',encoding='utf-8',newline='') as stream:stream.write(patch)
print('Prepared detached gzip-aware supervisor; existing registrations untouched.')
