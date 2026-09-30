"""Pure manufactured JSON/public-projection tests; no worker or policy execution."""
from pathlib import Path
import copy
import gzip
import hashlib
import json
import tempfile
import unittest
import paired_source_audit as A


class PairedAuditTests(unittest.TestCase):
    def snapshot(self):
        card={'id':'p1','rank':13,'suit':'Spades','face_down':False,'ability':{}}
        return {'phase':'hand','ante':1,'round':2,'dollars':2,'chips':0,'hand':[card],
                'deck':[{'id':'p2','rank':2,'face_down':True,'ability':{}},{'id':'p3','rank':3,'face_down':True,'ability':{}}],
                'playing_cards':[card,{'id':'p2','rank':2,'face_down':True,'ability':{}}],
                'jokers':[],'consumeables':[],'shop_forecast':{'rates':{'joker':20}}}
    def entry(self,step,action):
        s,scope=A.public_snapshot(self.snapshot())
        return {'step':step,'phase':'hand','action_phase':'hand','public_sha256':A.digest(s),'projection':scope,
                'state':A.compact(s),'action':action,'resolved':{'chips_delta':10,'dollars_delta':0,'hands_left':3}}
    def test_hidden_identity_and_raw_fingerprints_are_excluded(self):
        s=self.snapshot();s['hand'][0]['face_down']=True;s['state_fingerprint']='MUST NEVER BE DECODED {not-json'
        a,scope=A.public_snapshot(s);t=copy.deepcopy(s);t['hand'][0]['rank']=9;t['state_fingerprint']='another opaque string'
        b,_=A.public_snapshot(t)
        self.assertEqual(A.digest(a),A.digest(b));self.assertEqual(a['hand'],[{'identity_redacted':True}])
        self.assertIn({'identity_redacted':True},a['playing_cards']);self.assertGreater(scope['concealed_card_entries'],0)
        self.assertNotIn('state_fingerprint',a)
    def test_remaining_deck_is_multiset_visible_hand_is_not(self):
        s=self.snapshot();a,_=A.public_snapshot(s);s['deck'].reverse();b,_=A.public_snapshot(s)
        self.assertEqual(A.digest(a),A.digest(b));s['hand'][0]['rank']=12;c,_=A.public_snapshot(s)
        self.assertNotEqual(A.digest(a),A.digest(c));self.assertEqual(len(a['deck']),2)
    def test_first_divergence_requires_full_aligned_prefix(self):
        first=self.entry(1,{'kind':'play','indices':[1]});left={'steps':{1:first,2:self.entry(2,{'kind':'discard','indices':[1]})}}
        right=copy.deepcopy(left);right['steps'][2]['action']={'kind':'play','indices':[1]}
        found=A.first_divergence(left,right)
        self.assertEqual(found['status'],'first_exact_action_difference_after_aligned_public_prefix');self.assertEqual(found['aligned_action_prefix'],[1])
        right['steps'][1]['resolved']['chips_delta']=11
        self.assertEqual(A.first_divergence(left,right)['status'],'same_action_resolved_differently')
    def test_missing_state_unknown_fields_and_phase_decline_proof(self):
        a={'steps':{1:self.entry(1,{'kind':'play'})}};b=copy.deepcopy(a)
        b['steps'][1]['public_sha256']='different'
        self.assertEqual(A.first_divergence(a,b)['status'],'public_states_diverged_before_an_action_difference')
        b=copy.deepcopy(a);b['steps'][1]['projection']['unclassified_top_fields']=['unreviewed']
        self.assertEqual(A.first_divergence(a,b)['status'],'unclassified_public_fields')
        b=copy.deepcopy(a);b['steps'][1]['action_phase']='shop'
        self.assertEqual(A.first_divergence(a,b)['status'],'action_phase_inconsistent')
        self.assertEqual(A.first_divergence(None,b)['status'],'not_auditable_without_full_public_trace_projection')
    def test_observed_acquisitions_do_not_infer_hidden_sales(self):
        a={'actions':[{'step':1,'state':{'jokers':[],'consumables':[]}},
                      {'step':2,'state':{'jokers':[{'key':'j_one'}],'consumables':[{'key':'c_one','negative':True}]}},
                      {'step':3,'state':{'jokers':[{'identity_redacted':True}],'consumables':[{'key':'c_one','negative':True}]}}]}
        changes=A.observed_changes(a)
        self.assertEqual(changes[0]['added'],[{'identity':'j_one','count':1}]);self.assertEqual(changes[1]['added'],[{'identity':['c_one',True],'count':1}])
        self.assertEqual(changes[2]['status'],'concealed_identity_change_unresolved');self.assertNotIn('removed',changes[2])
    def test_streamed_trace_keeps_block_reason_and_prediction_source(self):
        with tempfile.TemporaryDirectory(prefix='advisor-paired-json-fixture-') as folder:
            p=Path(folder);rows=[{'type':'engine_episode_decision_started','step':1,'phase':'hand','snapshot':self.snapshot(),'state_fingerprint':'opaque forbidden string'},
              {'type':'engine_episode_action','step':1,'phase':'hand','action':{'kind':'play','indices':[1]},'prediction_source':'selected_action_rescore'},
              {'type':'engine_episode_resolved','step':1,'chips_delta':50,'dollars_delta':0,'hands_left':3,'discards_left':2,'state':1},
              {'type':'engine_episode_score_verified','step':1,'scope':'deterministic_score','predicted':50,'actual':50},
              {'type':'engine_probe_blocked','reason':'manufactured no action'}]
            raw=b'preserved non-JSON diagnostic\n'+b''.join(json.dumps(row).encode()+b'\n' for row in rows)
            path=p/'trace.log.gz';path.write_bytes(gzip.compress(raw[:20])+gzip.compress(raw[20:]))
            record={'trace_path':path.name,'trace_sha256':A.sha(path),'trace_bytes':path.stat().st_size,'worker_reaped':True,
                    'stdout_drain_completed':True,'decoded_trace_bytes':len(raw),'decoded_trace_sha256':hashlib.sha256(raw).hexdigest()}
            index=A.trace_index(p,record)
            self.assertEqual(index['steps'][1]['prediction_source'],'selected_action_rescore');self.assertEqual(index['steps'][1]['score_check']['actual'],50)
            self.assertEqual(index['blocks'][0]['reason'],'manufactured no action');self.assertEqual(len(index['unparsed_lines']),1)
            self.assertNotIn('state_fingerprint',json.dumps(index));self.assertNotIn('opaque forbidden string',json.dumps(index))


if __name__=='__main__':unittest.main(verbosity=2)
