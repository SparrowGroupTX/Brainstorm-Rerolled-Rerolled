"""Lossless bounded gzip stdout capture and streaming audit access.

Each persisted chunk is a complete gzip level-1 member. Concatenated members
are standard gzip: successful captures reproduce stdout exactly; censored
captures preserve a valid, explicitly incomplete prefix. No evidence is trimmed
or transformed within that prefix. This module has no experiment authority.
"""
from contextlib import contextmanager
from pathlib import Path
import gzip
import hashlib
import json
import subprocess
import threading
import time

MAX_COMPRESSED=256*1024**2
MAX_DECODED=2*1024**3
CHUNK_BYTES=64*1024
CONTRACT={'format':'gzip','compression_level':1,'member_decoded_bytes':CHUNK_BYTES,
          'compressed_byte_cap':MAX_COMPRESSED,'decoded_byte_cap':MAX_DECODED,
          'raw_digest':'sha256','lossless_completed_stream':True,
          'censored_scope':'valid_persisted_stdout_prefix'}


def capture(command,folder,seconds,*,compressed_cap=MAX_COMPRESSED,decoded_cap=MAX_DECODED,
            poll_seconds=.02,reap_seconds=5,drain_seconds=5,popen=subprocess.Popen,clock=time.monotonic,
            thread_factory=threading.Thread):
    """One supervised process; injectable small limits are for dummy tests only.

    The caller must hold its authority/one-use lock and validate the command.
    This never registers jobs. All work, including stdout drainage, must finish
    before the same deadline for status complete. Cleanup time is reported too.
    """
    if seconds<=0 or compressed_cap<20 or decoded_cap<1:raise ValueError('Positive capture caps required')
    folder=Path(folder);trace=folder/'trace.log.gz';started=clock();deadline=started+seconds
    cancel=threading.Event();done=threading.Event();process=None;drainer=None;thread_started=False
    state={'raw_bytes':0,'compressed_bytes':0,'read_bytes':0,'stdout_eof':False,
           'limit_reason':None,'capture_errors':[],'stream_closed':False}
    raw_hash=hashlib.sha256();status='error';reason=None;code=None;worker_reaped=False;natural_completion=False
    def drain(pipe,stream):
        try:
            member=gzip.compress(b'',compresslevel=1,mtime=0)
            if stream.write(member)!=len(member):raise OSError('Short empty gzip member write')
            state['compressed_bytes']=len(member)
            while not cancel.is_set():
                if clock()>=deadline:state['limit_reason']='stdout_capture_wall_cap';break
                # Read at most one extra byte at the decoded boundary, solely
                # to distinguish exact EOF from an output-cap violation.
                amount=min(CHUNK_BYTES,max(1,decoded_cap-state['raw_bytes']))
                chunk=pipe.read1(amount)
                if not chunk:
                    state['stdout_eof']=True;break
                state['read_bytes']+=len(chunk)
                if clock()>=deadline or cancel.is_set():
                    state['limit_reason']=state['limit_reason'] or 'stdout_capture_wall_cap';break
                if state['raw_bytes']+len(chunk)>decoded_cap:
                    state['limit_reason']='decoded_stdout_byte_cap';break
                member=gzip.compress(chunk,compresslevel=1,mtime=0)
                if state['compressed_bytes']+len(member)>compressed_cap:
                    state['limit_reason']='compressed_stdout_byte_cap';break
                if clock()>=deadline or cancel.is_set():
                    state['limit_reason']=state['limit_reason'] or 'stdout_capture_wall_cap';break
                written=stream.write(member)
                if written!=len(member):raise OSError('Short gzip member write')
                raw_hash.update(chunk);state['raw_bytes']+=len(chunk);state['compressed_bytes']+=len(member)
            stream.flush()
        except Exception as error:state['capture_errors'].append(repr(error))
        finally:
            try:pipe.close()
            except Exception as error:state['capture_errors'].append('pipe_close: '+repr(error))
            try:stream.close();state['stream_closed']=True
            except Exception as error:state['capture_errors'].append('trace_close: '+repr(error))
            done.set()
    stream=None
    try:
        stream=trace.open('xb',buffering=0)
        process=popen(command,cwd=folder,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                      creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        drainer=thread_factory(target=drain,args=(process.stdout,stream),name='bounded-gzip-stdout',daemon=True)
        drainer.start();thread_started=True
        while True:
            elapsed=clock()-started
            # Both the child and complete drainage must satisfy the deadline.
            if elapsed>=seconds:status='timeout';reason='worker_or_capture_wall_cap';break
            limit=state['limit_reason']
            if limit:
                status='timeout' if limit=='stdout_capture_wall_cap' else 'censored';reason=limit;break
            if state['capture_errors']:status='error';reason='stdout_capture_error';break
            code=process.poll()
            if code is not None and done.is_set():
                if not state['stdout_eof']:status='error';reason='stdout_incomplete_without_cap'
                else:
                    natural_completion=True
                    status='complete' if code==0 else 'error';reason=None if code==0 else 'worker_exit_error'
                break
            time.sleep(min(poll_seconds,seconds-elapsed))
    except Exception as error:status='error';reason='worker_launch_or_supervision_error: '+repr(error)
    finally:
        # Stop accepting chunks once the registered wall/capture boundary hit.
        cancel.set()
        try:
            if process is None:worker_reaped=True
            else:
                if process.poll() is None:process.kill();process.wait(timeout=reap_seconds)
                code=process.poll();worker_reaped=code is not None
        except Exception as error:status='error';reason=(reason or '')+'; worker_reap_error: '+repr(error)
        if thread_started:
            try:drainer.join(timeout=drain_seconds)
            except Exception as error:state['capture_errors'].append('drain_join: '+repr(error))
        else:
            if process is not None:
                try:process.stdout.close()
                except Exception as error:state['capture_errors'].append('pipe_close: '+repr(error))
            if stream is not None:
                try:stream.close();state['stream_closed']=True
                except Exception as error:state['capture_errors'].append('trace_close: '+repr(error))
    drained=not thread_started or not drainer.is_alive()
    if not drained:
        status='error';reason=(reason or '')+'; stdout_drain_termination_unconfirmed'
    if state['capture_errors']:
        status='error';reason=(reason or '')+'; stdout_capture_error'
    complete=natural_completion and drained and state['stdout_eof'] and not state['capture_errors'] and not state['limit_reason']
    if status=='complete' and (clock()>=deadline or not complete):
        status='timeout' if clock()>=deadline else 'error';reason='capture_completion_outside_registered_boundary'
    # An unconfirmed writer cannot yield a stable hash; fail closed instead.
    raw_digest=raw_hash.hexdigest() if drained else None
    return {'status':status,'exit_code':code,'reason':reason,'elapsed_seconds':clock()-started,
            'timeout_seconds':seconds,'worker_pid':process.pid if process is not None else None,'worker_reaped':worker_reaped,
            'trace_format':'gzip','trace_path':'trace.log.gz','stdout_drain_completed':drained,
            'stdout_eof':state['stdout_eof'],'stdout_capture_complete':complete,
            'stdout_capture_scope':'complete_stream' if complete else 'persisted_prefix_only',
            'decoded_trace_sha256':raw_digest,'decoded_trace_bytes':state['raw_bytes'] if drained else None,
            'stdout_read_bytes':state['read_bytes'] if drained else None,
            'stdout_read_unpersisted_bytes':state['read_bytes']-state['raw_bytes'] if drained else None,
            'unread_stdout_bytes':0 if state['stdout_eof'] else None,
            'compressed_trace_bytes':state['compressed_bytes'] if drained else None,
            'trace_stream_closed':state['stream_closed'],'capture_limit_reason':state['limit_reason'],
            'capture_errors':list(state['capture_errors']),'compressed_byte_cap':compressed_cap,'decoded_byte_cap':decoded_cap}


@contextmanager
def open_trace(path):
    """Binary stream for old plain traces and new concatenated-gzip traces."""
    with Path(path).open('rb') as raw:
        magic=raw.read(2);raw.seek(0)
        if magic==b'\x1f\x8b':
            with gzip.GzipFile(fileobj=raw,mode='rb') as stream:yield stream
        else:yield raw


def iter_chunks(path,*,max_decoded_bytes=MAX_DECODED):
    total=0
    with open_trace(path) as stream:
        while True:
            chunk=stream.read(min(CHUNK_BYTES,max_decoded_bytes-total+1))
            if not chunk:return
            total+=len(chunk)
            if total>max_decoded_bytes:raise ValueError('Decoded trace exceeds audit cap')
            yield chunk


def iter_json_lines(path,*,max_decoded_bytes=MAX_DECODED,max_line_bytes=64*1024**2):
    """Bounded streaming JSON lines, with explicit errors rather than skipping."""
    pending=bytearray()
    for chunk in iter_chunks(path,max_decoded_bytes=max_decoded_bytes):
        pending.extend(chunk)
        while True:
            end=pending.find(b'\n')
            if end<0:break
            if end>max_line_bytes:raise ValueError('JSON line exceeds explicit audit line cap')
            line=bytes(pending[:end]);del pending[:end+1]
            if line.strip():yield json.loads(line)
        if len(pending)>max_line_bytes:raise ValueError('JSON line exceeds explicit audit line cap')
    if pending.strip():yield json.loads(pending)


def verify_trace(path,expected_bytes,expected_sha256,*,max_decoded_bytes=MAX_DECODED):
    count=0;digest=hashlib.sha256()
    for chunk in iter_chunks(path,max_decoded_bytes=max_decoded_bytes):count+=len(chunk);digest.update(chunk)
    if count!=expected_bytes or digest.hexdigest()!=expected_sha256:raise ValueError('Decoded trace bytes/hash mismatch')
    return {'decoded_bytes':count,'decoded_sha256':digest.hexdigest(),'verified':True}
