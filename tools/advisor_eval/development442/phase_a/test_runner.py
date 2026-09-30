"""Manufactured control tests; subprocess/policy evaluation is replaced by a stub."""
import importlib.util,json,tempfile,unittest,sys,threading,time
from pathlib import Path
from unittest.mock import patch
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import run as runner
from evidence_reader import restore
def receipt():
 return '\n'.join(json.dumps(x)for x in [
  {'schema':'advisor_evidence_graph_v1','kind':'header','node_count':1,'entry_count':1,'fields_omitted':0,'root':{'kind':'ref','id':1}},
  {'schema':'advisor_evidence_graph_v1','kind':'nodes','first':1,'nodes':[{'id':1,'fields':[{'key':{'kind':'string','value':'status'},'value':{'kind':'string','value':'modeled_failure'}}]}]},
  {'schema':'advisor_evidence_graph_v1','kind':'end','node_count':1,'entry_count':1,'complete':True}])
class Tests(unittest.TestCase):
 def setup_dir(self,p):
  runner.save(p/'manifest.json',{})
  runner.save(p/'jobs.json',{f'job{i}':{}for i in range(20)})
  runner.save(p/'registration.json',{'max_jobs':20,'max_workers':4,'job_seconds':40,'reserved_seconds':800,'overall_seconds':600})
  runner.save(p/'READY.json',{'manifest_sha256':runner.sha(p/'manifest.json')})
 def test_reader_complete(self):self.assertEqual(restore(receipt()),{'status':'modeled_failure'})
 def test_reader_rejects_partial_and_wrong_counts(self):
  rows=receipt().splitlines()
  for raw in ['\n'.join(rows[:-1]),receipt().replace('"entry_count": 1','"entry_count": 2'),receipt().replace('"id": 1','"id": 2')]:
   with self.assertRaises((AssertionError,KeyError,IndexError)):restore(raw)
 def test_twenty_claims_four_workers_and_closed(self):
  with tempfile.TemporaryDirectory()as folder:
   p=Path(folder);self.setup_dir(p);lock=threading.Lock();active=0;maximum=0;calls=[]
   def fake(command,**kwargs):
    nonlocal active,maximum
    self.assertEqual(kwargs['timeout'],40)
    with lock:active+=1;maximum=max(maximum,active);calls.append(command[-1])
    time.sleep(.01);kwargs['stdout'].write(receipt())
    with lock:active-=1
    return type('Result',(),{'returncode':0})()
   with patch.object(runner,'HERE',p),patch.object(runner,'verify',return_value={}),patch.object(runner.subprocess,'run',side_effect=fake):
    self.assertEqual(runner.execute(),0)
    with self.assertRaises(AssertionError):runner.execute()
   self.assertEqual(len(calls),20);self.assertEqual(len(set(calls)),20);self.assertLessEqual(maximum,4)
   self.assertEqual(len(list((p/'ledger').glob('*.started.json'))),20)
   self.assertEqual(runner.read(p/'CLOSED.json')['remaining_authority'],0)
 def test_timeout_not_replaced(self):
  with tempfile.TemporaryDirectory()as folder:
   p=Path(folder);self.setup_dir(p)
   with patch.object(runner,'HERE',p),patch.object(runner,'verify',return_value={}),patch.object(runner.subprocess,'run',side_effect=runner.subprocess.TimeoutExpired('fake',40))as fake:
    self.assertEqual(runner.execute(),0);self.assertEqual(fake.call_count,20)
   for output in (p/'results').glob('*.json'):self.assertEqual(runner.read(output)['status'],'timeout')
 def test_registration_cannot_increase(self):
  with tempfile.TemporaryDirectory()as folder:
   p=Path(folder);self.setup_dir(p);reg=runner.read(p/'registration.json');reg['max_jobs']=21
   (p/'registration.json').write_text(json.dumps(reg))
   with patch.object(runner,'HERE',p),patch.object(runner,'verify',return_value={}):
    with self.assertRaises(AssertionError):runner.execute()
   self.assertFalse((p/'EXECUTION_STARTED.json').exists())
 def test_exclusive_claim(self):
  with tempfile.TemporaryDirectory()as folder:
   p=Path(folder)/'claim.json';runner.save(p,{'one_use':True})
   with self.assertRaises(FileExistsError):runner.save(p,{'one_use':True})
if __name__=='__main__':unittest.main()
