"""Invented settled decisions: qualitative flags remain hypotheses."""
import copy
import unittest
from test_advisor_suspect_decisions406 import Journal, state, card


class RepairScreen(unittest.TestCase):
    def test_core_sale_requires_settled_effect(self):
        j = Journal(); s = state(phase='shop')
        j.act({'kind':'sell','area':'jokers','index':1}, s)
        self.assertEqual(j.flags(), [])
        after = copy.deepcopy(s); after['jokers'].pop(0)
        j.settle(after)
        self.assertEqual(len(j.flags('core_sale_without_plan')), 1)

    def test_perishable_core_is_not_durable_flag(self):
        j = Journal(); s = state(phase='shop', jokers=[card('j_yorick', ability={'perishable':True,'perish_tally':1})])
        j.act({'kind':'sell','area':'jokers','index':1}, s)
        j.settle(state(phase='shop', jokers=[]))
        self.assertEqual(j.flags('core_sale_without_plan'), [])

    def test_free_planet_skip_and_hidden_negative(self):
        for hidden in (False, True):
            j = Journal(); s = state(pack_cards=[card('c_mercury', face_down=hidden)])
            j.act({'kind':'skip_pack'}, s); j.settle(state(phase='shop', pack_cards=[]))
            self.assertEqual(len(j.flags('free_planet_skip')), int(not hidden))

    def test_fool_stock_known_non_jupiter_only(self):
        for history, expected in [('c_mercury',1),('c_jupiter',0),('c_fool',0),(None,0)]:
            j = Journal(); s = state(phase='shop', teacher_profile='perkeo_yorick_win_v1',
                consumeables=[card('c_fool')], last_tarot_planet=history)
            j.act({'kind':'leave_shop'}, s); after=copy.deepcopy(s);after['phase']='blind';j.settle(after)
            self.assertEqual(len(j.flags('unsupported_fool_stock')), expected)

    def test_structured_plan_detects_voucher_diversion_with_multiple_free_slots(self):
        j = Journal(); s = state(phase='shop', shop_jokers=[card('j_joker','offer',cost=4)],
            shop_vouchers=[card('v_telescope','voucher',cost=10)], pack_cards=[])
        receipt={'shop_sequence_review':{'plan':{'id':'plan408','complete':True},
            'steps':[{'kind':'buy','area':'shop_jokers','index':1,'id':'offer','key':'j_joker','cost':4}]}}
        j.act({'kind':'sell','area':'jokers','index':1},s,receipt=receipt)
        after=copy.deepcopy(s);after['jokers'].pop(0);after['dollars']+=2;j.settle(after)
        self.assertEqual(j.flags('core_sale_without_plan'), [])
        j.act({'kind':'buy','area':'shop_vouchers','index':1},after)
        settled=copy.deepcopy(after);settled['shop_vouchers']=[];settled['dollars']-=10;settled['used_vouchers']={'v_telescope':True}
        j.settle(settled)
        self.assertEqual(len(j.flags('sale_plan_reversal')),1)

    def test_pack_score_conflict_does_not_need_merit_reversal(self):
        j=Journal();s=state(pack_cards=[card('j_zany','z'),card('j_joker','j')])
        rows=[{'kind':'choose','status':'complete','admitted':True,'offer_id':x,'key':key,'score':merit,
               'after_mean':score,'after_target':1000,'complete_finishing':True,'uncertain':False}
              for x,key,merit,score in [('z','j_zany',80,100),('j','j_joker',50,200)]]
        j.act({'kind':'choose','area':'pack_cards','index':1},s,
              receipt={'copy_death_review':{'pack':{'complete':True,'candidates':rows}}})
        j.settle(state(phase='shop',pack_cards=[],jokers=s['jokers']+[s['pack_cards'][0]]))
        self.assertEqual(j.flags('pack_merit_reversal'),[])
        self.assertEqual(len(j.flags('pack_score_merit_conflict')),1)


if __name__ == '__main__':
    unittest.main()
