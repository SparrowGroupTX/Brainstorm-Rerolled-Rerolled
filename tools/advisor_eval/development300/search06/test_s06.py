"""Pure protocol and deadline tests. Never loads native or game source."""
from pathlib import Path
import copy
import json
import unittest
from spec import make_request,native_args,parse_result,fallback,seed_at,DOMAIN
from worker import execute
HERE=Path(__file__).resolve().parent

class S06Tests(unittest.TestCase):
    def setUp(self):
        self.generation=json.loads((HERE/'query_generation.json').read_text())
        self.request=make_request(self.generation)
        self.q=self.request['phase_templates'][0]

    def raw(self,status='not_found',q=None,**kwargs):
        q=q or self.q
        result=dict(schema=1,status=status,seed=seed_at(3000000101)if status=='found'else'',
          screened=500,exact_candidates=2,seconds=.1,budget_ms=q['budget_ms'],threads=32,
          route='conditional_no_reroll_stock_and_buffoon')
        result.update(kwargs);return json.dumps(result).encode()

    def simulation(self,statuses,durations=None):
        elapsed=[0.];calls=[];events=[]
        durations=durations or [1]*len(statuses)
        def call(phase):
            i=len(calls);calls.append(copy.deepcopy(phase));elapsed[0]+=durations[i]
            if statuses[i]=='malformed':return b'{"status":"bad"}'
            if statuses[i] in ('invalid','busy'):return json.dumps(dict(status=statuses[i])).encode()
            return self.raw(statuses[i],phase['query'])
        result=execute(self.request,call,lambda:elapsed[0],lambda kind,data:events.append((kind,data)))
        return result,calls,events

    def test_generation_is_actual_missing_canio(self):
        self.assertEqual(self.generation['goal']['counts'],dict(total=150,complete=149,missing=1,unknown=0))
        self.assertEqual(self.q['primary_legendary_key'],'j_caino')
        self.assertEqual(self.q['missing_names'],'Canio')
        self.assertEqual(self.q['minimum_distinct'],1)
        self.assertTrue(self.q['reject_perishable_targets'])
        self.assertTrue(self.q['interchangeable_copies'])
        self.assertEqual(self.q['souls'],2)
        self.assertEqual(self.q['tag'],'Charm Tag')
        self.assertEqual(self.q['stake_level'],8)
        self.assertEqual(self.q['deck'],'Red Deck')

    def test_abi_values_and_trailing_empty(self):
        args=native_args(self.q,self.request['start_seed'])
        self.assertEqual(len(args),28)
        self.assertEqual(args[17].split('\x1f'),['Canio','Brainstorm','Burnt Joker','Perkeo',''])
        self.assertEqual(args[19].split('\x1f'),['soul_pack','by_ante_5','by_ante_5','soul_pack','ante_1'])
        self.assertEqual(args[23:28],['Canio',1,1,8,9000])

    def test_found_stops_one_call(self):
        result,calls,_=self.simulation(['found'])
        self.assertEqual(len(calls),1);self.assertEqual(result['found']['phase'],1)
        self.assertEqual(result['reserved_native_ms'],9000)

    def test_miss_then_found_serial_actual_cursor(self):
        result,calls,events=self.simulation(['not_found','found'])
        self.assertEqual(len(calls),2);self.assertEqual(calls[1]['start_index'],3000000501)
        self.assertEqual(calls[1]['seed'],seed_at(3000000501))
        self.assertEqual(calls[1]['max_indices'],1000000000000-500)
        self.assertEqual(calls[1]['query']['budget_ms'],18000)
        self.assertEqual(calls[1]['query']['primary_legendary_key'],'j_caino')
        self.assertEqual(calls[1]['query']['target_jokers'],'Canio\x1fBrainstorm\x1f\x1fPerkeo\x1f')
        self.assertEqual(result['reserved_native_ms'],27000)
        self.assertEqual([e[0]for e in events],['phase_started','phase_raw','phase_complete']*2)
        self.assertTrue(result['phases'][0]['fully_exited'])

    def test_timeout_phase_one_uses_original_remaining(self):
        result,calls,_=self.simulation(['timeout','not_found'],[9.25,1])
        self.assertEqual(calls[1]['query']['budget_ms'],17750)
        self.assertEqual(result['reserved_native_ms'],26750)
        self.assertEqual(result['status'],'not_found')

    def test_no_third_call(self):
        result,calls,_=self.simulation(['not_found','timeout'])
        self.assertEqual(len(calls),2);self.assertEqual(result['status'],'timeout')

    def test_no_fallback_after_invalid_busy_cancelled(self):
        for status in ('invalid','busy','cancelled'):
            with self.subTest(status=status):
                result,calls,_=self.simulation([status]);self.assertEqual(len(calls),1)
                self.assertEqual(result['status'],status);self.assertIsNone(result['found'])

    def test_malformed_first_is_error_not_fallback(self):
        with self.assertRaises(ValueError):self.simulation(['malformed'])

    def test_late_found_is_preserved_but_not_accepted(self):
        result,calls,_=self.simulation(['found'],[27])
        self.assertEqual(result['status'],'timeout');self.assertIsNone(result['found'])
        self.assertEqual(result['phases'][0]['result']['status'],'found')
        self.assertEqual(len(calls),1)

    def test_late_miss_never_falls_back(self):
        result,calls,_=self.simulation(['not_found'],[28])
        self.assertEqual(result['status'],'timeout');self.assertEqual(len(calls),1)

    def test_budget_clock_and_range_boundaries(self):
        result=json.loads(self.raw())
        self.assertIsNone(fallback(self.request,result,27))
        self.assertEqual(fallback(self.request,result,26.999)['query']['budget_ms'],1)
        for value in (-1,float('nan'),float('inf')):
            with self.assertRaises(ValueError):fallback(self.request,result,value)
        result['screened']=self.request['max_indices_total']
        self.assertIsNone(fallback(self.request,result,1))
        for index in (0,True,DOMAIN,-1):
            with self.assertRaises(ValueError):seed_at(index)
        self.assertTrue(seed_at(DOMAIN-1))

    def test_protocol_rejects_invented_or_mismatched_receipts(self):
        for changes in [dict(threads=0),dict(budget_ms=18000),dict(screened=True),
            dict(exact_candidates=501),dict(route='other'),dict(seed='MISMATCH'),dict(extra=1),dict(seconds=float('inf'))]:
            with self.subTest(changes=changes),self.assertRaises(ValueError):parse_result(self.raw(**changes),self.q)
        for raw in [b'{"status":"busy","status":"invalid"}',b'{"status":"busy"} trailing',
                    b'{"status":{}}',b'{"status":"busy","seed":""}',b' '*4097]:
            with self.subTest(raw=raw[:80]),self.assertRaises(ValueError):parse_result(raw,self.q)

    def test_profile_and_query_input_unchanged(self):
        before=copy.deepcopy(self.request);generation_before=copy.deepcopy(self.generation)
        self.simulation(['not_found','found'])
        self.assertEqual(self.request,before);self.assertEqual(self.generation,generation_before)
        changed=copy.deepcopy(self.generation);changed['goal']['counts']['unknown']=1
        with self.assertRaises(ValueError):make_request(changed)

    def test_setup_does_not_renew_deadline(self):
        result=execute(self.request,lambda phase:self.fail('Native call must not start'),
          lambda:20,lambda kind,data:None,started=0)
        self.assertEqual(result['status'],'timeout');self.assertEqual(result['search_calls'],0)

    def test_second_phase_template_changes_only_declared_fields(self):
        first,second=self.request['phase_templates']
        difference={key for key in first if first[key]!=second[key]}
        self.assertEqual(difference,{'target_jokers','target_locations','budget_ms','burnt_required'})

if __name__=='__main__':unittest.main(verbosity=2)
