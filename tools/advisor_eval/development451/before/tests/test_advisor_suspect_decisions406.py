"""Invented public observations only: causal joins, qualitative flags and guards."""
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.advisor_eval import flag_suspect_decisions as screen


def card(key, identity=None, **kwargs):
    return {'id': identity or key, 'key': key, 'cost': 4, 'sell_cost': 2,
            'blueprint_compat': True, 'ability': {}, **kwargs}


def state(**kwargs):
    return {'phase': 'pack', 'ante': 2, 'round': 4, 'win_ante': 8, 'dollars': 20,
            'bankrupt_at': 0, 'joker_limit': 5, 'rental_rate': 3, 'pack_choices': 1,
            'next_blind': {'key': 'bl_big', 'ante': 2}, 'blind': {'key': 'bl_big', 'chips': 100},
            'chips': 0, 'discards_left': 3, 'discards_used': 0, 'hands_left': 4,
            'hand': [card('c_base', 'p'+str(i), rank=i+2) for i in range(8)],
            'jokers': [card('j_yorick', ability={'x_mult': 4}), card('j_perkeo')],
            'consumeables': [card('c_death')], 'pack_cards': [card('j_blueprint'), card('j_joker')],
            'shop_jokers': [], **kwargs}


class Journal:
    def __init__(self, cap=200):
        self.screen = screen.Screener(cap)
        self.seq = 0
        self.run = 'r1'
        self.events = []
        self.emit('auto_run', details={'event': 'run_started', 'run_number': 1, 'run_id': 'game:1'})

    def emit(self, kind, context=None, details=None, **extra):
        self.seq += 1
        event = {'schema': 1, 'sequence': self.seq, 'kind': kind,
                 'collection_id': 'c', 'context': {'run_instance': self.run, 'version': 'invented', **(context or {})},
                 'details': details or {}, **extra}
        self.events.append(event)
        anchor = dict(session='s', segment=1, file='invented.brj', ordinal=self.seq, sequence=self.seq,
                      event_sha256=screen.sha(screen.encoded(event)))
        self.screen.feed(event, anchor)
        return self.seq

    def observe(self, s):
        seq = self.seq + 1
        self.obs = self.emit('teacher_observation', context={'snapshot': copy.deepcopy(s)}, observation_id='o'+str(seq))
        return self.obs

    def act(self, action, s=None, receipt=None, status='current', override=None):
        if s is not None:
            self.observe(s)
        a = {'status': status, 'action': action, 'lines': ['Invented advice'], **(receipt or {})}
        advice_seq = self.emit('teacher_advice', context={'advice': a}, observation_id='o'+str(self.obs))
        self.request = self.emit('action_requested', details={'action': 'advisor_execute', 'source': 'auto_run',
                   'input': {'action': action}}, observation_id='o'+str(self.obs), observation_sequence=self.obs,
                   advice_sequence=advice_seq, **(override or {}))
        return self.request

    def settle(self, s):
        self.observe(s)
        self.emit('state_after_actions', details={'action_sequences': [self.request]},
                  observation_id='o'+str(self.obs))

    def flags(self, rule=None):
        return [r for r in self.screen.report()['flags'] if rule is None or r['rule'] == rule]


class DecisionScreen(unittest.TestCase):
    def test_copy_pass_requires_physical_closure(self):
        j = Journal(); s = state()
        j.act({'kind': 'skip_pack'}, s)
        j.settle(s)
        self.assertEqual(j.flags(), [])
        j.observe(state(phase='shop', pack_cards=[]))
        self.assertEqual(len(j.flags('copy_offer_pass')), 1)
        self.assertIsNotNone(j.flags()[0]['anchors']['marker'])

    def test_transient_empty_pack_does_not_mean_pass(self):
        j = Journal(); s = state()
        j.act({'kind': 'skip_pack'}, s)
        j.settle(state(phase='other', pack_cards=[]))
        j.observe(s)
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.report()['unconfirmed_rule_candidates_at_tail'], 1)
        j.observe(state(phase='shop', pack_cards=[]))
        self.assertEqual(len(j.flags('copy_offer_pass')), 1)

    def test_reroll_requires_replacement_row_and_cash_same_round(self):
        s = state(phase='shop', reroll_cost=5, shop_jokers=[card('j_blueprint')])
        for change in ({'phase': 'other', 'shop_jokers': []}, {'dollars': 19}, {'round': 5}):
            j = Journal(); j.act({'kind': 'reroll'}, s)
            after = state(phase='shop', dollars=15, shop_jokers=[card('j_joker', 'new')])
            after.update(change); j.settle(after)
            self.assertEqual(j.flags(), [])
        j = Journal(); j.act({'kind': 'reroll'}, s)
        j.settle(state(phase='shop', dollars=15, shop_jokers=[card('j_joker', 'new')]))
        self.assertEqual(len(j.flags('copy_offer_pass')), 1)

    def test_leave_shop_transient_then_supported_blind(self):
        s = state(phase='shop', shop_jokers=[card('j_blueprint')])
        j = Journal(); j.act({'kind': 'leave_shop'}, s)
        j.settle(state(phase='other', shop_jokers=[])); j.observe(s)
        self.assertEqual(j.flags(), [])
        j.observe(state(phase='blind', shop_jokers=[]))
        self.assertEqual(len(j.flags('copy_offer_pass')), 1)

    def test_choice_cost_zero_even_when_display_cost_exceeds_cash(self):
        s = state(dollars=0, pack_cards=[card('j_blueprint', cost=100), card('j_joker')])
        j = Journal(); j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, s)
        j.settle(state(phase='shop', pack_cards=[], jokers=s['jokers']+[s['pack_cards'][1]]))
        self.assertEqual(j.flags('copy_offer_pass')[0]['evidence']['immediate_cost'], 0)

    def test_second_mega_choice_acquires_copy_no_pass(self):
        j = Journal(); s = state(pack_choices=2)
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, s)
        after = state(pack_choices=1, pack_cards=[s['pack_cards'][0]], jokers=s['jokers']+[s['pack_cards'][1]])
        j.settle(after)
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 1})
        j.settle(state(phase='shop', pack_cards=[], jokers=after['jokers']+[s['pack_cards'][0]]))
        self.assertEqual(j.flags(), [])

    def test_hidden_offer_never_exposes_or_flags_identity(self):
        s = state(pack_cards=[card('j_blueprint', identity_redacted=True)])
        j = Journal(); j.act({'kind': 'skip_pack'}, s); j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])
        self.assertNotIn('key', screen.snapshot_view(s)['pack_cards'][0])

    def test_full_row_unmodeled_sale_and_negative_slot(self):
        s = state(joker_limit=2)
        j = Journal(); j.act({'kind': 'skip_pack'}, s); j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.suppressions['full_row_requires_unmodeled_sale'], 1)
        s['pack_cards'][0]['edition'] = {'negative': True}
        j = Journal(); j.act({'kind': 'skip_pack'}, s); j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(len(j.flags('copy_offer_pass')), 1)

    def test_shop_affordability_and_rental_reserve(self):
        for dollars, ability, reason in ((3, {}, 'unaffordable'), (5, {'rental': True}, 'one_round_rental_reserve_not_met')):
            with self.subTest(reason=reason):
                s = state(phase='shop', dollars=dollars, shop_jokers=[card('j_blueprint', ability=ability)])
                j = Journal(); j.act({'kind': 'leave_shop'}, s); j.settle(state(phase='blind'))
                self.assertEqual(j.flags(), [])
                self.assertEqual(j.screen.suppressions[reason], 1)

    def test_invisible_delayed_engine_opportunity(self):
        s = state(pack_cards=[card('j_invisible', ability={'extra': 2, 'invis_rounds': 0})])
        j = Journal(); j.act({'kind': 'skip_pack'}, s); j.settle(state(pack_cards=[], phase='shop'))
        r = j.flags('invisible_offer_pass')[0]
        self.assertEqual(len(r['evidence']['entire_visible_joker_pool']), 2)
        self.assertEqual(r['classification'], 'review_hypothesis')

    def test_invisible_unsellable_final_horizon_and_expiry_controls(self):
        cases = [({'eternal': True}, {}, 'invisible_unsellable'),
                 ({}, {'ante': 8, 'next_blind': {'key': 'boss', 'boss': True, 'ante': 8}}, 'invisible_insufficient_development_horizon'),
                 ({'perishable': True, 'perish_tally': 2}, {}, 'invisible_expires_before_use')]
        for ability, values, reason in cases:
            with self.subTest(reason=reason):
                s = state(pack_cards=[card('j_invisible', ability=ability)], **values)
                j = Journal(); j.act({'kind': 'skip_pack'}, s); j.settle(state(pack_cards=[], phase='shop'))
                self.assertEqual(j.flags(), [])
                self.assertEqual(j.screen.suppressions[reason], 1)

    def test_tail_callback_is_not_settlement(self):
        j = Journal(); j.act({'kind': 'skip_pack'}, state())
        j.emit('action_callback_result', details={'action_sequence': j.request, 'callback_returned': True})
        j.observe(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.report()['unconfirmed_actions_at_tail'], 1)

    def test_stale_advice_rejected(self):
        j = Journal(); j.act({'kind': 'skip_pack'}, state(), status='computing')
        j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.counts['requests_stale_mismatched_or_noncausal'], 1)

    def test_run_end_blocks_later_menu_evidence(self):
        j = Journal(); j.act({'kind': 'skip_pack'}, state())
        j.emit('auto_run', details={'event': 'run_finished'})
        j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.counts['unconfirmed_actions_run_end'], 1)

    def test_different_run_cannot_settle_prior_request(self):
        j = Journal(); j.act({'kind': 'skip_pack'}, state()); j.run = 'r2'
        j.emit('auto_run', details={'event': 'run_started', 'run_number': 2})
        j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])

    def test_bound_stops_delayed_attribution(self):
        j = Journal(); j.act({'kind': 'skip_pack'}, state())
        for _ in range(screen.LIMITS['effect_events']+1):
            j.emit('other')
        j.settle(state(pack_cards=[], phase='shop'))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.counts['unconfirmed_actions_effect_bound'], 1)

    def pack_receipt(self):
        return {'copy_death_review': {'pack': {'complete': True, 'truncated': False, 'candidates': [
            {'offer_id': key, 'key': key, 'kind': 'choose', 'status': 'complete', 'admitted': True,
             'after_target': 1000, 'score': score} for key, score in [('j_blueprint', 100), ('j_joker', 30)]]}}}

    def test_pack_merit_is_hypothesis_with_missing_arbitration(self):
        j = Journal(); s = state()
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, s, self.pack_receipt())
        j.settle(state(phase='shop', pack_cards=[], jokers=s['jokers']+[s['pack_cards'][1]]))
        r = j.flags('pack_merit_reversal')[0]
        self.assertTrue(r['evidence']['survival_arbitration_missing'])
        self.assertIn('not proven dominance', r['competing_explanation'])

    def test_multi_choice_merit_order_not_called_reversal(self):
        j = Journal(); s = state(pack_choices=2)
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, s, self.pack_receipt())
        after = state(pack_choices=1, pack_cards=[s['pack_cards'][0]], jokers=s['jokers']+[s['pack_cards'][1]])
        j.settle(after)
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 1}, receipt=self.pack_receipt())
        j.settle(state(phase='shop', pack_cards=[], jokers=after['jokers']+[s['pack_cards'][0]]))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.counts['pack_merit_multiple_or_unknown_choices_unassessed'], 1)

    def test_incomplete_truncated_or_other_sale_family_not_ranked(self):
        for mode in ('incomplete', 'truncated', 'sale', 'not_admitted', 'wrong_offer'):
            with self.subTest(mode=mode):
                receipt = self.pack_receipt(); p = receipt['copy_death_review']['pack']
                if mode in ('incomplete', 'truncated'): p[mode] = True
                elif mode == 'sale': p['candidates'][0]['kind'] = 'sell_then_choose'
                elif mode == 'not_admitted': p['candidates'][0]['admitted'] = False
                else: p['candidates'][0]['offer_id'] = 'absent'
                j = Journal(); s = state(); j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, s, receipt)
                j.settle(state(phase='shop', pack_cards=[], jokers=s['jokers']+[s['pack_cards'][1]]))
                self.assertEqual(j.flags('pack_merit_reversal'), [])

    def sale(self, sold=None, choices=1):
        s = state(pack_choices=choices); sold = sold or card('j_egg')
        s['jokers'].append(sold)
        j = Journal(); j.act({'kind': 'sell', 'area': 'jokers', 'index': 3,
            'followup': {'kind': 'choose', 'area': 'pack_cards', 'index': 1}}, s)
        after = copy.deepcopy(s); after['jokers'].pop(); after['dollars'] += sold['sell_cost']
        j.settle(after)
        return j, s, after

    def test_sale_plan_reversal_uses_physical_target(self):
        j, s, after = self.sale()
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2})
        j.settle(state(phase='shop', pack_cards=[], jokers=after['jokers']+[s['pack_cards'][1]]))
        self.assertEqual(j.flags('sale_plan_reversal')[0]['evidence']['offer']['id'], 'j_blueprint')

    def test_multi_choice_sale_followup_order_not_called_reversal(self):
        j, s, after = self.sale(choices=2)
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2})
        first = copy.deepcopy(after); first['jokers'].append(s['pack_cards'][1])
        first['pack_cards'] = [s['pack_cards'][0]]; first['pack_choices'] = 1
        j.settle(first)
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 1})
        j.settle(state(phase='shop', pack_cards=[], jokers=first['jokers']+[s['pack_cards'][0]]))
        self.assertEqual(j.flags(), [])
        self.assertEqual(j.screen.suppressions['sale_plan_multiple_or_unknown_pack_choices'], 1)

    def test_reindex_kept_plan_not_flagged(self):
        j, s, after = self.sale(); after['pack_cards'].reverse()
        j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, after)
        j.settle(state(phase='shop', pack_cards=[], jokers=after['jokers']+[s['pack_cards'][0]]))
        self.assertEqual(j.flags('sale_plan_reversal'), [])
        self.assertEqual(j.screen.counts['sale_followups_kept_plan'], 1)

    def test_replaced_offer_or_changed_cash_breaks_same_plan(self):
        for mode in ('offer', 'cash'):
            j, s, after = self.sale()
            if mode == 'offer': after['pack_cards'][0]['id'] = 'new-physical'
            else: after['dollars'] -= 1
            j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2}, after)
            j.settle(state(phase='shop', pack_cards=[], jokers=after['jokers']+[s['pack_cards'][1]]))
            self.assertEqual(j.flags('sale_plan_reversal'), [])
            self.assertEqual(j.screen.suppressions['sale_plan_context_changed'], 1)

    def test_credit_or_invisible_sale_not_modeled_as_fixed_vacancy(self):
        for key in ('j_credit_card', 'j_invisible'):
            j, s, after = self.sale(card(key, ability={'invis_rounds': 2, 'extra': 2}))
            j.act({'kind': 'choose', 'area': 'pack_cards', 'index': 2})
            j.settle(state(phase='shop', pack_cards=[], jokers=after['jokers']+[s['pack_cards'][1]]))
            self.assertEqual(j.flags('sale_plan_reversal'), [])
            self.assertEqual(j.screen.suppressions['sale_plan_unmodeled_credit_or_random_sale'], 1)

    def test_short_discard_confirmed_with_growth_and_held_hand_context(self):
        j = Journal(); s = state(phase='hand')
        j.act({'kind': 'discard', 'area': 'hand', 'indices': [1, 2, 3]}, s)
        after = copy.deepcopy(s); after['hand'] = s['hand'][3:]; after['discards_left'] -= 1
        j.settle(after)
        r = j.flags('short_discard')[0]
        self.assertEqual(r['evidence']['selected_count'], 3)
        self.assertEqual(len(r['decision_context']['hand']), 8)
        self.assertFalse(r['evidence']['safe_five_card_alternative_established'])

    def test_full_discard_or_unspent_counter_not_short_flag(self):
        for indices, spend in (([1, 2, 3, 4, 5], True), ([1, 2], False)):
            j = Journal(); s = state(phase='hand'); j.act({'kind': 'discard', 'area': 'hand', 'indices': indices}, s)
            after = copy.deepcopy(s); after['hand'] = s['hand'][len(indices):]
            if spend: after['discards_left'] -= 1
            j.settle(after)
            self.assertEqual(j.flags('short_discard'), [])

    def test_unused_discards_needs_confirmed_same_round_clear(self):
        j = Journal(); s = state(phase='hand')
        j.act({'kind': 'play', 'area': 'hand', 'indices': [1]}, s)
        j.settle(state(phase='other', chips=150))
        self.assertEqual(j.flags(), [])
        j.observe(state(phase='round', chips=150))
        r = j.flags('unused_discards_at_clear')[0]
        self.assertEqual(r['evidence']['remaining_discards'], 3)
        self.assertEqual(r['anchors']['request']['sequence'], j.request)

    def test_below_target_new_round_and_zero_discards_not_clear_flags(self):
        for change in ({'chips': 50}, {'round': 5}, {'ante': 3}, {'discards_left': 0}):
            j = Journal(); j.act({'kind': 'play', 'area': 'hand', 'indices': [1]}, state(phase='hand'))
            after = state(phase='round', chips=150); after.update(change); j.settle(after)
            self.assertEqual(j.flags('unused_discards_at_clear'), [])

    def test_boss_cashout_may_advance_ante_with_same_completed_round(self):
        j = Journal(); s = state(phase='hand', blind={'key': 'boss', 'boss': True, 'chips': 100})
        j.act({'kind': 'play', 'area': 'hand', 'indices': [1]}, s)
        j.settle(state(phase='round', chips=150, ante=3))
        self.assertEqual(len(j.flags('unused_discards_at_clear')), 1)

    def test_final_boss_lower_review_priority_not_forced_growth(self):
        j = Journal(); s = state(phase='hand', ante=8, blind={'key': 'boss', 'boss': True, 'chips': 100})
        j.act({'kind': 'play', 'area': 'hand', 'indices': [1]}, s)
        j.settle(state(phase='round', chips=150, ante=8))
        self.assertEqual(j.flags('unused_discards_at_clear')[0]['priority'], 5)

    def test_output_cap_counts_all_flags(self):
        j = Journal(cap=1); s = state(pack_cards=[card('j_blueprint'), card('j_invisible')])
        j.act({'kind': 'skip_pack'}, s); j.settle(state(pack_cards=[], phase='shop'))
        report = j.screen.report()
        self.assertEqual((report['flags_total'], report['flags_retained'], report['flags_omitted']), (2, 1, 1))
        self.assertEqual(j.flags()[0]['rule'], 'copy_offer_pass')
        self.assertEqual(sum(g['count'] for g in report['review_groups']), 2)

    def test_qualified_five_receipt_group_preserves_uncertainty(self):
        j = Journal(); s = state(phase='hand')
        receipt = {'yorick_review': {'risk': {'qualified_five_count': 2}}}
        j.act({'kind': 'discard', 'area': 'hand', 'indices': [1, 2]}, s, receipt)
        after = copy.deepcopy(s); after['hand'] = s['hand'][2:]; after['discards_left'] -= 1
        j.settle(after)
        self.assertEqual(j.flags()[0]['review_family'], 'receipt_mentions_qualified_five')
        self.assertFalse(j.flags()[0]['evidence']['safe_five_card_alternative_established'])

    def test_rule_hit_cap_fails_instead_of_claiming_complete_screen(self):
        j = Journal(); s = state(pack_cards=[card('j_blueprint'), card('j_invisible')])
        j.act({'kind': 'skip_pack'}, s)
        with patch.dict(screen.LIMITS, rule_hits=1):
            with self.assertRaisesRegex(screen.ScreenError, 'Rule-hit cap'):
                j.settle(state(pack_cards=[], phase='shop'))


def wire(events, segment=1, previous='-'):
    output = b''
    for e in events:
        raw = screen.encoded(e)+b'\n'
        body = screen.encoded({'schema': 2, 'session': 's', 'segment': segment,
                              'previous_frame_sha256': previous, 'event_json': raw.decode()})
        frame = f"BRJ2\traw\t{len(body)}\t{len(body)}\t{e['sequence']}\t{screen.sha(body)}\t{screen.sha(raw)}\n".encode()+body+b'\n'
        output += frame; previous = screen.sha(frame)
    return output, previous


class OfflineInput(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.j = Journal(); self.j.act({'kind': 'skip_pack'}, state())
        self.j.settle(state(pack_cards=[], phase='shop'))

    def files(self, chunks):
        entries = []
        for i, raw in enumerate(chunks):
            p = self.folder/f'{i}.brj'; p.write_bytes(raw)
            entries.append({'name': p.name, 'bytes': len(raw), 'sha256': screen.sha(raw)})
        manifest = self.folder/'manifest.json'; manifest.write_text(json.dumps({'segments': entries}))
        return manifest

    def test_hashed_archive_read_only_deterministic(self):
        raw, _ = wire(self.j.events); manifest = self.files([raw])
        one = screen.analyze(self.folder, manifest); two = screen.analyze(self.folder, manifest)
        self.assertEqual(one, two)
        self.assertEqual(one['flags_by_rule']['copy_offer_pass'], 1)
        self.assertEqual((self.folder/'0.brj').read_bytes(), raw)
        self.assertFalse(one['complete_session_claimed'])

    def test_cross_file_chain_checked_and_fragment_predecessor_unknown(self):
        first, h = wire(self.j.events[:3], segment=3, previous='a'*64)
        second, _ = wire(self.j.events[3:], segment=5, previous=h)
        result = screen.analyze(self.folder, self.files([first, second]))
        self.assertEqual(result['events'], len(self.j.events))
        self.assertFalse(result['outside_predecessors_verified'])
        bad, _ = wire(self.j.events[3:], segment=5, previous='b'*64)
        with self.assertRaisesRegex(screen.ScreenError, 'predecessor'):
            screen.analyze(self.folder, self.files([first, bad]))

    def test_regressed_segment_and_duplicate_input_rejected(self):
        first, h = wire(self.j.events[:3], segment=3)
        second, _ = wire(self.j.events[3:], segment=2, previous=h)
        with self.assertRaisesRegex(screen.ScreenError, 'regression'):
            screen.analyze(self.folder, self.files([first, second]))
        manifest = self.files([wire(self.j.events)[0]])
        data = json.loads(manifest.read_text()); data['segments'] *= 2; manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(screen.ScreenError, 'duplicate'):
            screen.analyze(self.folder, manifest)

    def test_hash_tamper_and_path_escape_rejected(self):
        manifest = self.files([wire(self.j.events)[0]])
        (self.folder/'0.brj').write_bytes(b'bad')
        with self.assertRaisesRegex(screen.ScreenError, 'mismatch'):
            screen.analyze(self.folder, manifest)
        data = json.loads(manifest.read_text()); data['segments'][0]['name'] = '../elsewhere.brj'
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(screen.ScreenError, 'Unsafe'):
            screen.analyze(self.folder, manifest)

    def test_event_bound_fails_without_partial_success(self):
        manifest = self.files([wire(self.j.events)[0]])
        with patch.dict(screen.LIMITS, events=2):
            with self.assertRaisesRegex(screen.ScreenError, 'cap reached'):
                screen.analyze(self.folder, manifest)

    def test_decode_stream_hash_bound_even_when_path_restored(self):
        raw, _ = wire(self.j.events); manifest = self.files([raw])
        changed = copy.deepcopy(self.j.events)
        changed[1]['context']['snapshot']['dollars'] = 21
        alternate, _ = wire(changed)
        self.assertEqual(len(alternate), len(raw))
        original = Path.open
        reads = 0
        target = (self.folder/'0.brj').resolve()
        def intercept(path, *args, **kwargs):
            nonlocal reads
            if path == target and args and args[0] == 'rb':
                reads += 1
                if reads == 2:
                    return io.BytesIO(alternate)
            return original(path, *args, **kwargs)
        with patch.object(Path, 'open', intercept):
            with self.assertRaisesRegex(screen.ScreenError, 'Decoded stream'):
                screen.analyze(self.folder, manifest)
        self.assertEqual(target.read_bytes(), raw)


if __name__ == '__main__':
    unittest.main()
