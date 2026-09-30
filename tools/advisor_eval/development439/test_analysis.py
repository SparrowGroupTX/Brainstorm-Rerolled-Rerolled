"""Invented accounting inputs only; no policy execution."""
import hashlib,unittest
from analyze import make_row,summarize
CASE={'sequence':1,'snapshot':{'discards_left':3,'ante':1,'blind':{'key':'bl_small'}}}
def result(status,final=True):
 return {'status':'complete','result':{'status':status,'final_resources_supported':final,'discards':1,'cards_discarded':5,'remaining_discards':2,
  'steps':[{'action':{'kind':'discard','indices':[1,2,3,4,5]}},{'action':{'kind':'discard','indices':[1,2,3]}}]}}
class Tests(unittest.TestCase):
 def test_failures_included(self):
  row=make_row('invented',CASE,result('modeled_failure'));self.assertTrue(row['completed_round']);self.assertEqual(summarize([row])['cards_per_round'],5)
 def test_floor_censored(self):self.assertFalse(make_row('invented',CASE,result('supported_clear_floor',False))['completed_round'])
 def test_only_settled_discard_sizes(self):
  row=make_row('invented',CASE,result('unsupported',False));self.assertEqual(row['settled_discard_sizes'],[5]);self.assertEqual(row['unsettled_discard_attempts'],1)
 def test_timeout_unknown_not_zero(self):
  row=make_row('invented',CASE,{'status':'timeout'});self.assertIsNone(row['cards_discarded']);self.assertFalse(row['completed_round'])
 def test_bounded_sha_seed(self):
  raw=int(hashlib.sha256(b'invented-acorn-seed').hexdigest()[:8],16)
  self.assertGreaterEqual(raw,1000000000);self.assertTrue(0<=raw%1000000000<1000000000)
if __name__=='__main__':unittest.main()
