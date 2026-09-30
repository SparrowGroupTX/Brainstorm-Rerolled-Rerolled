"""Invented archives only: causal evidence, structural alternatives and boundedness."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.advisor_eval import flag_suspect_decisions as screen
from tools.advisor_eval import review_decisions as review
from test_advisor_suspect_decisions406 import Journal, state, card, wire


def case(**changes):
    s = state(phase='hand', hand_limit=5)
    s.update(changes)
    return dict(state=screen.snapshot_view(s), action={'kind':'play','indices':[1,2,3]},
                advice={}, scope=['s','c','r'], run={'run_number':1}, version='invented',
                anchors={k:dict(sequence=i+1, event_sha256=str(i)*64) for i,k in enumerate(('observation','advice','request','marker','effect'))})


class StructuralAlternatives(unittest.TestCase):
    def solve(self, c, remaining=32768):
        b = {'remaining':remaining}; before=copy.deepcopy(c)
        r = review.discard_alternatives(c,b)
        self.assertEqual(c,before)
        return r,b

    def test_exhaustive_eight_cards_retains_three_card_play(self):
        r,b=self.solve(case())
        self.assertEqual(len(r['candidates']),218)
        self.assertEqual(b['remaining'],32768-218)
        self.assertEqual(r['maximum_batch_preserving_chosen_play'],5)
        best=[a for a in r['candidates'] if a['cards']==5 and a['retains_chosen_play']]
        self.assertEqual([a['indices'] for a in best],[[4,5,6,7,8]])
        self.assertEqual(r['candidates'][0]['indices'],[4,5,6,7,8])
        self.assertFalse(r['survival_verified']);self.assertFalse(r['strategic_optimality_proven'])

    def test_forced_card_required_and_retention_conflict(self):
        s=state()['hand'];s[0]['ability']['forced_selection']=True
        r,_=self.solve(case(hand=s))
        self.assertTrue(all(1 in a['indices'] for a in r['candidates']))
        self.assertEqual(r['expected_candidates'],99)
        self.assertEqual(r['retained_play_forced_conflict'],[1])
        self.assertEqual(r['maximum_batch_preserving_chosen_play'],0)

    def test_hidden_forced_selection_preserved_without_identity(self):
        hand=state()['hand'];hand[0].update(face_down=True,key='secret',rank=13)
        hand[0]['ability']['forced_selection']=True
        c=case(hand=hand)
        self.assertNotIn('rank',c['state']['hand'][0]);self.assertNotIn('key',c['state']['hand'][0])
        r,_=self.solve(c)
        self.assertTrue(r['complete']);self.assertTrue(all(1 in a['indices'] for a in r['candidates']))
        self.assertIn('concealed_effects_unknown',r['resource_annotations']['1'])

    def test_hidden_missing_constraint_fails_closed(self):
        hand=state()['hand'];hand[0]={'id':'hidden','identity_redacted':True}
        r,b=self.solve(case(hand=hand))
        self.assertFalse(r['complete']);self.assertEqual(r['reason'],'forced_selection_metadata_unknown')
        self.assertEqual(b['remaining'],32768)

    def test_unknown_identity_alias_never_exposes_card_properties(self):
        hand=state()['hand'];hand[0].update(identity_unknown=True,rank=13,key='secret')
        c=case(hand=hand)
        self.assertNotIn('rank',c['state']['hand'][0]);self.assertNotIn('key',c['state']['hand'][0])
        self.assertFalse(self.solve(c)[0]['complete'])

    def test_duplicate_identity_or_missing_limit_refused(self):
        for mutate in ('duplicate','limit'):
            c=case()
            if mutate=='duplicate':c['state']['hand'][1]['id']=c['state']['hand'][0]['id']
            else:c['state'].pop('hand_limit')
            self.assertFalse(self.solve(c)[0]['complete'])

    def test_oversize_hand_never_partially_enumerated(self):
        r,b=self.solve(case(hand=[card('c_base',str(i)) for i in range(13)]))
        self.assertFalse(r['complete']);self.assertEqual(r['candidates'],[]);self.assertEqual(b['remaining'],32768)

    def test_budget_preflight_does_not_claim_partial_optimum(self):
        r,b=self.solve(case(),217)
        self.assertEqual(r['reason'],'enumeration_budget_insufficient_no_partial_optimum')
        self.assertEqual(r['candidates'],[]);self.assertNotIn('maximum_batch_preserving_chosen_play',r)
        self.assertEqual(b['remaining'],217)

    def test_resources_annotated_not_silently_pruned(self):
        hand=state()['hand'];hand[7].update(enhancement='m_steel',seal='Blue')
        r,_=self.solve(case(hand=hand))
        self.assertEqual(len(r['candidates']),218)
        self.assertIn('enhancement:m_steel',r['resource_annotations']['8'])

    def test_discard_anchor_unknown_instead_of_invented(self):
        c=case();c['action']={'kind':'discard','indices':[1]}
        r,_=self.solve(c)
        self.assertIsNone(r['maximum_batch_preserving_chosen_play'])
        self.assertTrue(all(a['retains_chosen_play'] is None for a in r['candidates']))

    def test_no_discard_or_nonhand_action_explained(self):
        self.assertEqual(self.solve(case(discards_left=0))[0]['reason'],'no_discards_available')
        self.assertEqual(self.solve(case(phase='shop'))[0]['reason'],'not_a_hand_decision')


class EvidenceClassification(unittest.TestCase):
    def test_receipt_inconsistency_is_not_strategic_proof(self):
        c=case();c['advice']={'discard_before_clear':{'final_action_kind':'discard','remaining_discards':1}}
        p=review.packet(c,[],'test',{'remaining':32768})
        self.assertEqual(p['confidence'],'established_receipt_inconsistency')
        self.assertFalse(p['strategic_regret_established']);self.assertFalse(p['execution_authorized'])

    def test_qualified_alternative_counts_are_only_a_signal(self):
        c=case();c['advice']={'yorick_review':{'schema':1,'risk':{'qualified_five_count':2,'final_action_kind':'play'}}}
        findings=review.issues(c)
        self.assertEqual(len(findings),1);self.assertEqual(findings[0]['confidence'],'recorded_alternative_signal')
        self.assertIn('Counts alone',findings[0]['next_test'])

    def test_overlapping_rejection_reasons_are_not_added_as_disjoint(self):
        c=case();c['advice']={'yorick_review':{'risk':{'by_size':[{'compared':2,'qualified':1,'survival':2,'utility':2}]}}}
        self.assertEqual(review.issues(c),[])

    def test_impossible_qualified_count_and_incomplete_are_separate(self):
        c=case();c['advice']={'yorick_review':{'risk':{'by_size':[{'compared':1,'qualified':2,'incomplete':1}]}}}
        f=review.issues(c)
        self.assertEqual({x['confidence'] for x in f},{'established_receipt_inconsistency','recorded_coverage_gap'})

    def test_higher_pack_merit_not_certified_superiority(self):
        c=case(phase='pack');c['advice']={'copy_death_review':{'pack':{'complete':True,'candidates':[
            {'offer_id':'j_blueprint','key':'j_blueprint','score':100,'admitted':True},
            {'offer_id':'absent','key':'j_joker','score':1000}]}}}
        rows=review.recorded_alternatives(c)
        self.assertEqual(len(rows['rows']),1);self.assertEqual(rows['unmatched_rows'],1)
        self.assertFalse(rows['strategic_ranking_certified'])

    def test_consistent_exception_is_not_a_bug(self):
        c=case();c['advice']={'discard_before_clear':{'status':'exception','reason':'Cannot preserve survival','final_action_kind':'play'}}
        self.assertEqual(review.issues(c)[0]['confidence'],'recorded_exception')

    def test_reason_groups_cover_all_observed_decisions_with_explicit_cap(self):
        collector=review.Collector()
        with patch.dict(review.LIMITS,finding_groups=1):
            for i,reason in enumerate(('sorting','sorting','unknown effect')):
                c=case();c['anchors']['request']['sequence']=i+1
                c['advice']={'discard_before_clear':{'status':'exception','reason':reason}}
                collector.observe(c)
        group=next(iter(collector.groups.values()))
        self.assertEqual(group['decisions'],2);self.assertEqual(collector.group_omitted,1)
        self.assertFalse(group['common_cause_established'])


class SettledObservers(unittest.TestCase):
    def journal(self, callback):
        j=Journal();j.screen.on_settled=callback;return j

    def test_detached_and_once_across_delayed_closure(self):
        calls=[]
        def observer(c):
            calls.append(copy.deepcopy(c));c['state']['jokers'].clear();c['advice']['action'].clear()
        j=self.journal(observer);s=state()
        j.act({'kind':'skip_pack'},s);j.settle(s);j.observe(s)
        j.observe(state(phase='shop',pack_cards=[]))
        self.assertEqual(len(calls),1);self.assertEqual(len(j.flags('copy_offer_pass')),1)
        self.assertEqual(len(j.flags()[0]['decision_context']['jokers']),2)

    def test_stale_request_and_nonterminal_play_not_sampled(self):
        for stale in (False,True):
            calls=[];j=self.journal(calls.append)
            j.act({'kind':'play','indices':[1]},state(phase='hand'),status='stale' if stale else 'current')
            j.settle(state(phase='hand',chips=20,hands_left=3))
            self.assertEqual(calls,[])

    def test_all_flag_hits_observed_even_when_ranked_away(self):
        j=Journal(cap=1);flags=[];j.screen.on_flag=flags.append
        j.act({'kind':'skip_pack'},state(pack_cards=[card('j_blueprint'),card('j_invisible')]))
        j.settle(state(phase='shop',pack_cards=[]))
        self.assertEqual(len(flags),2);self.assertEqual(len(j.flags()),1)


class VerifiedPipeline(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.folder=Path(self.temp.name)

    def files(self,j):
        raw=wire(j.events)[0];p=self.folder/'0.brj';p.write_bytes(raw)
        manifest=self.folder/'manifest.json';manifest.write_text(json.dumps({'segments':[{'name':p.name,'bytes':len(raw),'sha256':screen.sha(raw)}]}))
        return manifest

    def journal(self):
        j=Journal()
        for number in range(4):
            s=state(phase='hand',hand_limit=5,round=number+1)
            indices=[1,2,3,4,5] if number%2 else [1]
            j.act({'kind':'discard','indices':indices},s)
            after=copy.deepcopy(s);after['hand']=[c for i,c in enumerate(s['hand'],1) if i not in indices];after['discards_left']=2
            j.settle(after)
        return j

    def test_end_to_end_deterministic_caps_and_input_preservation(self):
        j=self.journal();manifest=self.files(j);before=(self.folder/'0.brj').read_bytes()
        a=review.analyze(self.folder,manifest,max_packets=3,sample_size=1)
        b=review.analyze(self.folder,manifest,max_packets=3,sample_size=1)
        self.assertEqual(a,b);self.assertEqual((self.folder/'0.brj').read_bytes(),before)
        self.assertEqual(a['coverage']['eligible_settled_decisions'],4)
        self.assertEqual(a['coverage']['legacy_unflagged_population'],2)
        self.assertEqual(a['coverage']['sample_retained'],1)
        self.assertEqual(len(a['packets']),3);self.assertFalse(a['policy_executed'])
        sample=[p for p in a['packets'] if p['source']=='legacy_unflagged_bottom_k']
        self.assertEqual(len(sample),1);self.assertEqual(sample[0]['flags'],[])

    def test_capped_away_flags_never_enter_unflagged_population(self):
        manifest=self.files(self.journal())
        with patch.dict(review.LIMITS,flags=1):
            r=review.analyze(self.folder,manifest,3,2)
        self.assertEqual(r['coverage']['legacy_flagged_decisions'],2)
        self.assertEqual(r['coverage']['legacy_unflagged_population'],2)
        self.assertEqual(r['coverage']['legacy_flag_rows_omitted'],1)
        self.assertTrue(all(not p['flags'] for p in r['packets'] if p['source']=='legacy_unflagged_bottom_k'))

    def test_late_manifest_failure_never_publishes_report(self):
        manifest=self.files(self.journal());out=self.folder/'out'
        original=screen.Screener.report
        def mutate(s):
            manifest.write_text(manifest.read_text()+' ')
            return original(s)
        # Mutation after first pass's final checks must be caught by the second
        # pass binding, before any packet report is written.
        with patch.object(screen.Screener,'report',mutate),patch.object(__import__('sys'),'argv',[
            'review','--copy-dir',str(self.folder),'--manifest',str(manifest),'--output',str(out)]):
            self.assertEqual(review.main(),1)
        self.assertFalse((out/'report.json').exists());self.assertFalse((out/'COMPLETE.json').exists())
        self.assertTrue((out/'error.json').exists())

    def test_cli_writes_complete_hash_bound_outputs_and_refuses_overwrite(self):
        manifest=self.files(self.journal());out=self.folder/'out'
        args=['review','--copy-dir',str(self.folder),'--manifest',str(manifest),'--output',str(out)]
        with patch.object(__import__('sys'),'argv',args):
            self.assertEqual(review.main(),0)
            self.assertEqual(review.main(),1)
        done=json.loads((out/'COMPLETE.json').read_text())
        self.assertTrue(all(screen.file_sha(out/n)==h for n,h in done['files'].items()))
        queue=json.loads((out/'challenge_queue.json').read_text())
        self.assertTrue(all(not x['execution_authorized'] and not x['experiment_registered'] for x in queue))

    def test_global_subset_budget_reported_without_changing_cases(self):
        manifest=self.files(self.journal())
        with patch.dict(review.LIMITS,subsets_total=218):
            r=review.analyze(self.folder,manifest,4,2)
        self.assertEqual(r['subset_candidates_enumerated'],218)
        self.assertEqual(sum(p['discard_alternatives']['complete'] for p in r['packets']),1)
        self.assertEqual(len(r['packets']),4)


if __name__=='__main__':
    unittest.main()
