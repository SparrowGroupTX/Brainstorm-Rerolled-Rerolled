"""Manufactured worker accounting and isolated Lua states; no game access."""
from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fixture_workers444',ROOT/'tests/run_lua_tests.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)


class FixtureWorkers(unittest.TestCase):
    def paths(self,n):return [ROOT/'tests'/f'invented{i}.lua' for i in range(n)]

    def test_partition_complete_disjoint_and_deterministic(self):
        for n in (1,2,3,322):
            paths=self.paths(n);batches=runner.fixture_batches(paths,2)
            self.assertEqual(sum(map(len,batches)),n)
            self.assertEqual(set().union(*map(set,batches)),set(paths))
            if len(batches)==2:self.assertTrue(set(batches[0]).isdisjoint(batches[1]))
            self.assertEqual(batches,runner.fixture_batches(paths,2))
        with self.assertRaises(ValueError):runner.fixture_batches(self.paths(1)*2,2)

    def execute(self,callback,n=4):
        output=io.StringIO()
        with patch.object(runner.subprocess,'run',side_effect=callback),redirect_stdout(output):
            result=runner.run_parallel(self.paths(n),runner.BALATRO_DLL)
        return result,output.getvalue()

    def test_workers_have_bounded_deadline_and_no_recursive_parallelism(self):
        calls=[]
        def child(cmd,**kw):
            calls.append((cmd,kw))
            self.assertEqual(cmd[cmd.index('--workers')+1],'1')
            self.assertGreater(kw['timeout'],0);self.assertLessEqual(kw['timeout'],55)
            self.assertIn('--lua-library',cmd)
            return subprocess.CompletedProcess(cmd,0,'2/2 fixtures passed\n','')
        result,text=self.execute(child)
        self.assertEqual(result,0);self.assertEqual(len(calls),2)
        self.assertEqual(text.count('fixtures passed'),1);self.assertIn('4/4 fixtures passed',text)
        self.assertEqual(sorted(str(p) for p in self.paths(4)),sorted(p for cmd,_ in calls for p in cmd if p.endswith('.lua')))

    def test_missing_duplicate_or_wrong_completion_fails(self):
        for footer in ('','1/1 fixtures passed\n','2/2 fixtures passed\n2/2 fixtures passed\n','1/2 fixtures passed\n'):
            with self.subTest(footer=footer):
                self.assertEqual(self.execute(lambda cmd,**kw:subprocess.CompletedProcess(cmd,0,footer,''))[0],1)

    def test_nonzero_exit_even_with_success_footer_fails(self):
        self.assertEqual(self.execute(lambda cmd,**kw:subprocess.CompletedProcess(cmd,1,'2/2 fixtures passed\n','bad'))[0],1)

    def test_timeout_and_spawn_failure_cannot_pass(self):
        for error in (subprocess.TimeoutExpired('invented',55,output=b'partial\n'),OSError('spawn failed')):
            def child(cmd,**kw):raise error
            self.assertEqual(self.execute(child)[0],1)

    def test_expired_shared_deadline_does_not_spawn(self):
        with patch.object(runner.time,'monotonic',side_effect=[0,56,57]),patch.object(runner.subprocess,'run')as call,redirect_stdout(io.StringIO()):
            self.assertEqual(runner.run_parallel(self.paths(4),runner.BALATRO_DLL),1)
            call.assert_not_called()

    @unittest.skipUnless(runner.BALATRO_DLL.is_file(),'Qualified Lua library unavailable')
    def test_actual_isolated_workers_success_and_assertion_failure(self):
        with tempfile.TemporaryDirectory(prefix='fixture444-')as directory:
            folder=Path(directory);a=folder/'a.lua';b=folder/'b.lua'
            a.write_text('assert(_G.worker444==nil); _G.worker444=true')
            b.write_text('assert(_G.worker444==nil)')
            with redirect_stdout(io.StringIO()):self.assertEqual(runner.run_parallel([a,b],runner.BALATRO_DLL),0)
            b.write_text('error("manufactured worker failure")')
            with redirect_stdout(io.StringIO()):self.assertEqual(runner.run_parallel([a,b],runner.BALATRO_DLL),1)


if __name__=='__main__':unittest.main()
