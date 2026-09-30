"""Dummy Python/byte-stream tests in disposable temp folders; no authority access."""
from pathlib import Path
import gzip
import hashlib
import io
import json
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import stdout_transport as T
import validation_cycle as V


class TransportTests(unittest.TestCase):
    def setUp(self):self.temp=tempfile.TemporaryDirectory(prefix='advisor-gzip-fixture-');self.folder=Path(self.temp.name)
    def tearDown(self):self.temp.cleanup()
    def worker(self,source,**options):
        script=self.folder/'dummy.py';script.write_text(source,encoding='utf-8')
        return T.capture([sys.executable,'-u',str(script)],self.folder,options.pop('seconds',3),**options)
    def decoded(self):return gzip.decompress((self.folder/'trace.log.gz').read_bytes())
    def check_capture(self,r):
        self.assertTrue(r['worker_reaped']);self.assertTrue(r['stdout_drain_completed'])
        self.assertLessEqual((self.folder/'trace.log.gz').stat().st_size,r['compressed_byte_cap'])
        raw=self.decoded();self.assertEqual(len(raw),r['decoded_trace_bytes'])
        self.assertEqual(hashlib.sha256(raw).hexdigest(),r['decoded_trace_sha256'])
        T.verify_trace(self.folder/'trace.log.gz',len(raw),r['decoded_trace_sha256'],max_decoded_bytes=r['decoded_byte_cap'])
        return raw
    def test_lossless_binary_multimember_and_stderr(self):
        data=bytes(range(256))*20000
        r=self.worker("import sys\nsys.stdout.buffer.write(bytes(range(256))*20000)\nsys.stdout.flush()\nsys.stderr.buffer.write(b'END\\x00')\n")
        self.assertEqual(r['status'],'complete');self.assertTrue(r['stdout_capture_complete'])
        self.assertEqual(self.check_capture(r),data+b'END\x00');self.assertEqual(r['stdout_read_unpersisted_bytes'],0)
    def test_empty_is_valid_gzip(self):
        r=self.worker('pass\n');self.assertEqual(r['status'],'complete');self.assertEqual(self.check_capture(r),b'')
        self.assertTrue((self.folder/'trace.log.gz').read_bytes().startswith(b'\x1f\x8b'))
    def test_decoded_cap_preserves_exact_prefix(self):
        r=self.worker("import sys\nsys.stdout.buffer.write(b'x'*100000)\n",decoded_cap=9000)
        self.assertEqual(r['status'],'censored');self.assertEqual(r['reason'],'decoded_stdout_byte_cap')
        self.assertFalse(r['stdout_capture_complete']);self.assertEqual(self.check_capture(r),b'x'*9000)
        self.assertEqual(r['stdout_read_unpersisted_bytes'],1)
    def test_exact_decoded_cap_can_complete(self):
        r=self.worker("import sys\nsys.stdout.buffer.write(b'x'*9000)\n",decoded_cap=9000)
        self.assertEqual(r['status'],'complete');self.assertEqual(self.check_capture(r),b'x'*9000)
    def test_compressed_cap_preserves_valid_prefix(self):
        r=self.worker("import sys,random\nr=random.Random(731)\nsys.stdout.buffer.write(bytes(r.randrange(256) for _ in range(100000)))\n",compressed_cap=1000)
        self.assertEqual(r['status'],'censored');self.assertEqual(r['reason'],'compressed_stdout_byte_cap')
        self.assertFalse(r['stdout_capture_complete']);self.check_capture(r)
        self.assertGreater(r['stdout_read_unpersisted_bytes'],0)
    def test_timeout_kills_and_keeps_prefix(self):
        r=self.worker("import sys,time\nprint('before timeout',flush=True)\ntime.sleep(5)\n",seconds=.15)
        self.assertEqual(r['status'],'timeout');self.assertFalse(r['stdout_capture_complete'])
        self.assertEqual(self.check_capture(r),b'before timeout\r\n' if sys.platform=='win32' else b'before timeout\n')
        self.assertLess(r['elapsed_seconds'],1.5)
    def test_nonzero_exit_is_not_complete(self):
        r=self.worker("import sys\nsys.stdout.buffer.write(b'failure evidence')\nsys.exit(7)\n")
        self.assertEqual(r['status'],'error');self.assertEqual(r['exit_code'],7)
        self.assertTrue(r['stdout_capture_complete']);self.assertEqual(self.check_capture(r),b'failure evidence')
    def test_launch_failure_has_receipt(self):
        def fail(*args,**kwargs):raise OSError('manufactured launch failure')
        r=T.capture([sys.executable,'dummy.py'],self.folder,1,popen=fail)
        self.assertEqual(r['status'],'error');self.assertTrue(r['worker_reaped']);self.assertTrue(r['stdout_drain_completed'])
        self.assertFalse(r['stdout_capture_complete']);self.assertIn('launch failure',r['reason'])
    def test_reap_failure_is_unconfirmed(self):
        class Fake:
            pid=999999999
            stdout=io.BufferedReader(io.BytesIO(b'preserved'))
            def poll(self):return None
            def kill(self):raise OSError('manufactured reap failure')
        r=T.capture(['dummy'],self.folder,.03,popen=lambda *a,**k:Fake())
        self.assertEqual(r['status'],'error');self.assertFalse(r['worker_reaped']);self.assertIn('reap failure',r['reason'])
        self.assertTrue(r['stdout_drain_completed']);self.assertEqual(self.decoded(),b'preserved')
    def test_finished_child_late_drain_cannot_complete(self):
        class Slow(io.BufferedReader):
            def read1(self,n):time.sleep(.08);return super().read1(n)
        class Fake:
            pid=999999998
            stdout=Slow(io.BytesIO(b'late'))
            def poll(self):return 0
        r=T.capture(['dummy'],self.folder,.03,popen=lambda *a,**k:Fake())
        self.assertEqual(r['status'],'timeout');self.assertFalse(r['stdout_capture_complete'])
        self.assertTrue(r['worker_reaped']);self.assertTrue(r['stdout_drain_completed']);self.check_capture(r)
    def test_drainer_start_failure_closes_handles(self):
        class FakeThread:
            def __init__(self,**kwargs):pass
            def start(self):raise RuntimeError('manufactured thread start failure')
        r=self.worker('import time\ntime.sleep(5)\n',thread_factory=FakeThread)
        self.assertEqual(r['status'],'error');self.assertTrue(r['worker_reaped'])
        self.assertTrue(r['stdout_drain_completed']);self.assertTrue(r['trace_stream_closed'])
        self.assertIn('thread start failure',r['reason'])
    def test_compressor_error_is_preserved(self):
        original=T.gzip.compress
        def fail_nonempty(data,**kwargs):
            if data:raise OSError('manufactured compression failure')
            return original(data,**kwargs)
        with patch.object(T.gzip,'compress',side_effect=fail_nonempty):r=self.worker("print('preserve error')\n")
        self.assertEqual(r['status'],'error');self.assertTrue(r['worker_reaped']);self.assertTrue(r['stdout_drain_completed'])
        self.assertFalse(r['stdout_capture_complete']);self.assertIn('compression failure',' '.join(r['capture_errors']))
        self.check_capture(r)
    def test_dummy_supervisor_one_use_lock_and_total_timing(self):
        # Inject an entirely separate temporary ledger. No real authority file,
        # registration, source, policy, or experiment slot is accessed.
        script=self.folder/'dummy_source.py';script.write_text("print('dummy controller')\n",encoding='utf-8')
        files={'dummy.py':script,'supervisor_source.py':Path(V.__file__),'stdout_transport.py':Path(T.__file__)}
        metadata={'kind':'complete_source_attempt','stdout_capture':T.CONTRACT,'supervisor_sha256':V.sha(V.__file__)}
        with patch.object(V,'BASE',self.folder),patch.object(V,'authority',lambda:None),patch.object(V,'CAPS',{'C02':3,'C03':3}):
            folder=V.register('C02',files,[sys.executable,'-B','-u','{job}/dummy.py'],metadata,[sys.executable])
            with V.batch_lock():
                with self.assertRaises((OSError,BlockingIOError)):
                    with V.batch_lock():pass
            V.run('C02');r=json.loads((folder/'record.json').read_text())
            self.assertEqual(r['status'],'complete');self.assertTrue(r['worker_reaped']);self.assertTrue(r['stdout_drain_completed'])
            self.assertGreaterEqual(r['elapsed_seconds'],r['capture_elapsed_seconds'])
            self.assertTrue(r['frozen_files_unchanged']);self.assertTrue(r['external_files_unchanged'])
            with self.assertRaises(FileExistsError):V.run('C02')
            with self.assertRaises(AssertionError):V.register('C02',files,[sys.executable,'{job}/dummy.py'],metadata,[sys.executable])
            V.register('C03',files,[sys.executable,'{job}/dummy.py'],metadata,[sys.executable])
            r['worker_reaped']=False;(folder/'record.json').write_text(json.dumps(r))
            with self.assertRaises(AssertionError):V.run('C03')
            self.assertFalse((self.folder/'C03/spent.json').exists())
    def test_streaming_reader_plain_gzip_limits_and_hash(self):
        data=b'{"type":"one","n":1}\n{"type":"two","n":2}\n'
        plain=self.folder/'old.log';plain.write_bytes(data)
        zipped=self.folder/'new.log.gz';zipped.write_bytes(gzip.compress(data[:13])+gzip.compress(data[13:]))
        for path in [plain,zipped]:
            self.assertEqual(list(T.iter_json_lines(path)),[{'type':'one','n':1},{'type':'two','n':2}])
            self.assertEqual(b''.join(T.iter_chunks(path)),data)
            with self.assertRaises(ValueError):list(T.iter_chunks(path,max_decoded_bytes=10))
            with self.assertRaises(ValueError):list(T.iter_json_lines(path,max_line_bytes=4))
            with self.assertRaises(ValueError):T.verify_trace(path,len(data),'bad')
        zipped.write_bytes(zipped.read_bytes()[:-5])
        with self.assertRaises((EOFError,OSError)):list(T.iter_chunks(zipped))
    def test_strict_contract_and_entrypoint(self):
        self.assertFalse(V.compressed_contract('C02',{}));self.assertTrue(V.compressed_contract('C02',{'stdout_capture':T.CONTRACT}))
        with self.assertRaises(AssertionError):V.compressed_contract('P04',{'stdout_capture':T.CONTRACT})
        changed=dict(T.CONTRACT,decoded_byte_cap=T.MAX_DECODED+1)
        with self.assertRaises(AssertionError):V.compressed_contract('C02',{'stdout_capture':changed})
        self.assertEqual(V.command_script([sys.executable,'-B','-u',str(self.folder/'dummy.py')],self.folder),'dummy.py')
        with self.assertRaises(AssertionError):V.command_script([sys.executable,'-c','pass',str(self.folder/'dummy.py')],self.folder)


if __name__=='__main__':unittest.main(verbosity=2)
