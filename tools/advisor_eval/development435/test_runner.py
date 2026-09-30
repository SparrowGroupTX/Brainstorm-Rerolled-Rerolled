"""Manufactured scheduling/serialization controls; no captured evaluation."""
import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import run
class Controls(unittest.TestCase):
 def test_diagnostic_censorship(self):
  for status in ('timeout','error','not_started'):
   v=run.binding_value('invented',{'status':status,'reason':'specific cause'},'fake')
   self.assertFalse(v['admitted']);self.assertEqual(v['diagnostic_status'],status);self.assertEqual(v['diagnostic_reason'],'specific cause')
  v=run.binding_value('invented',{'status':'complete','result':{'admitted':False,'reason':'no_complete_legal_five'}},'fake')
  self.assertFalse(v['admitted']);self.assertEqual(v['diagnostic_reason'],'no_complete_legal_five')
 def test_budget(self):
  reg={'job_seconds':15,'aggregate_reserved_seconds':795,'overall_seconds':900}
  with patch.object(run.time,'monotonic',return_value=0):
   b=run.Budget(reg)
   for _ in range(5):self.assertTrue(b.reserve(1))
   for _ in range(24):self.assertTrue(b.reserve(2))
   self.assertEqual(b.reserved,795);self.assertFalse(b.reserve(1))
 def test_pair_needs_both_caps(self):
  with patch.object(run.time,'monotonic',return_value=0):b=run.Budget({'job_seconds':15,'aggregate_reserved_seconds':795,'overall_seconds':900})
  with patch.object(run.time,'monotonic',return_value=875):self.assertFalse(b.reserve(2));self.assertTrue(b.reserve(1))
 def test_claim_is_exclusive(self):
  with tempfile.TemporaryDirectory(prefix='manufactured435_')as d:
   p=Path(d)/'claim';run.save(p,{'one_use':True})
   with self.assertRaises(FileExistsError):run.save(p,{'one_use':False})
   self.assertEqual(run.read(p),{'one_use':True})
 def test_literal(self):
  self.assertEqual(run.literal('x\r\n"\\'),b'"x\\013\\010\\034\\092"')
  self.assertEqual(run.lua({'a':[False,None,2]}),b'{["a"]={false,nil,2}}')
 def test_registration(self):
  # Passive structure assertions only; no snapshots are passed into a policy.
  reg=run.read(run.HERE/'registration.json');jobs=run.read(run.HERE/'jobs.json')
  self.assertEqual(len(jobs),53);self.assertEqual(reg['max_workers'],4)
  order=reg['diagnostics']+[k for p in reg['pairs']for k in p]
  self.assertEqual(len(set(order)),53);self.assertEqual(set(order),set(jobs))
  for pair in reg['pairs']:
   a,b=(jobs[k]for k in pair)
   for field in ('case','world','world_seed','world_order','sorting','action_cap'):self.assertEqual(a[field],b[field])
   self.assertNotEqual(a['role'],b['role']);self.assertEqual(a['action_cap'],16)
if __name__=='__main__':unittest.main()
