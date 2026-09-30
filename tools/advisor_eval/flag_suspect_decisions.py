"""Screen an explicitly supplied, hashed copy of public BRJ2 journals offline.

Flags are review hypotheses, never policy labels, counterfactual wins, or scores.
No game discovery, policy/scorer execution, network, installation, or input writes.
"""
from __future__ import annotations

import argparse
import copy
from collections import Counter, OrderedDict
import hashlib
import json
import math
from pathlib import Path
import sys

try:
    from read_player_log import ArchiveError, parsed, records
except ModuleNotFoundError:
    from tools.advisor_eval.read_player_log import ArchiveError, parsed, records

RULE_VERSION = '443.1'
LIMITS = dict(files=64, file_bytes=134217728, input_bytes=268435456,
              decoded_bytes=1073741824, events=100000, cached_links=128,
              effect_events=128, scopes=128, cards_per_area=128, flags=1000,
              rule_hits=10000, output_bytes=67108864)
WATCH = {'j_blueprint', 'j_brainstorm', 'j_invisible'}
CORE = {'j_blueprint', 'j_brainstorm', 'j_perkeo', 'j_yorick'}
RULES = {
    'copy_offer_pass': 'Visible copy offer closed without acquisition',
    'invisible_offer_pass': 'Visible Invisible Joker opportunity closed',
    'pack_merit_reversal': 'Chosen Joker has lower recorded pack merit',
    'sale_plan_reversal': 'Purchase after sale differs from its explicit plan',
    'short_discard': 'Fewer than five cards discarded',
    'unused_discards_at_clear': 'Round cleared with discards remaining',
    'core_sale_without_plan': 'Durable engine sold without a structured funded continuation',
    'free_planet_skip': 'Revealed free permanent Planet upgrade skipped',
    'unsupported_fool_stock': 'Non-Jupiter Fool stock retained with active Perkeo',
    'pack_score_merit_conflict': 'Selected pack merit conflicts with complete opening-score evidence',
}
CAUTIONS = {
    'copy_offer_pass': 'Survival, permanent slots, rentals and future cash can justify passing; a compatible target is not a guaranteed win.',
    'invisible_offer_pass': 'Invisible takes rounds and a later sale, copies a random eligible Joker and may dilute the scoring row. Inspect the entire target pool.',
    'pack_merit_reversal': 'The compact receipt omits shared-world identity and survival arbitration. Higher merit is not proven dominance.',
    'sale_plan_reversal': 'A fresh evaluation may legitimately change its mind. Inspect both complete receipts and retained resources before calling this a defect.',
    'short_discard': 'Keeping a winning combination, held effects or a Death source may require a short discard. Five legal safe discards are not established by hand size.',
    'unused_discards_at_clear': 'Discards can cost cash, held rewards, survival or time; final-boss growth may have no future value. Unused is not necessarily wasted.',
    'core_sale_without_plan': 'Missing structure is an observability or continuity risk, not proof that the sale was wrong; a complete immediate rescue may justify it.',
    'free_planet_skip': 'Hand history, Fool, Red Card and other pack choices can change value; a free permanent upgrade is not automatically dominant.',
    'unsupported_fool_stock': 'This screen identifies the known non-Jupiter Perkeo capability gap. It does not invent a future copied card or mandate a sale.',
    'pack_score_merit_conflict': 'Opening score is not whole-blind survival or long-term engine value; inspect the competing components rather than trusting either metric alone.',
}


class ScreenError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ScreenError(message)


def obj(value):
    return value if isinstance(value, dict) else {}


def arr(value):
    return value if isinstance(value, list) else []


def num(value):
    return type(value) in (int, float) and math.isfinite(value)


def ident(value):
    return isinstance(value, str) and 0 < len(value) <= 160


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def file_sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


class HashedReader:
    """Hash exactly the bytes decoded, including framing, within declared size."""
    def __init__(self, stream, size):
        self.stream, self.size, self.count = stream, size, 0
        self.hash = hashlib.sha256()

    def take(self, method, size):
        require(type(size) is int and size >= 0, 'Unbounded decode read')
        raw = getattr(self.stream, method)(min(size, self.size - self.count + 1))
        self.count += len(raw)
        require(self.count <= self.size, 'Input grew beyond declared length during decoding')
        self.hash.update(raw)
        return raw

    def read(self, size):
        return self.take('read', size)

    def readline(self, size):
        return self.take('readline', size)


def card_view(card):
    card = obj(card)
    if any(card.get(k) for k in ('unknown', 'identity_redacted', 'identity_unknown', 'face_down')):
        return {'id': card.get('id'), 'unknown': True}
    keys = ('id', 'key', 'rank', 'suit', 'seal', 'debuff', 'edition', 'enhancement', 'blueprint_compat',
            'cost', 'sell_cost', 'pinned')
    result = {k: card[k] for k in keys if k in card}
    a = obj(card.get('ability'))
    result['ability'] = {k: a[k] for k in ('eternal', 'rental', 'perishable', 'perish_tally',
        'invis_rounds', 'extra', 'x_mult', 'yorick_discards', 'name', 'forced_selection') if k in a}
    return result


def snapshot_view(s):
    require(isinstance(s, dict), 'Observation snapshot is not an object')
    keys = ('phase', 'ante', 'round', 'dollars', 'bankrupt_at', 'joker_limit', 'rental_rate',
            'pack_choices', 'hands_left', 'hands_played', 'discards_left', 'discards_used',
            'chips', 'hand_limit', 'win_ante', 'blind', 'next_blind', 'teacher_profile', 'reroll_cost',
            'modifiers', 'round_resets', 'round_bonus', 'last_tarot_planet', 'used_vouchers', 'hand_sort')
    result = {k: s[k] for k in keys if k in s}
    for area in ('hand', 'jokers', 'consumeables', 'pack_cards', 'shop_jokers', 'shop_vouchers'):
        rows = arr(s.get(area))
        require(len(rows) <= LIMITS['cards_per_area'], 'Card-area cap exceeded')
        result[area] = [card_view(c) for c in rows]
    # Selection constraints are public even when a card's identity is hidden.
    # A redacted card without explicit constraint metadata remains UNKNOWN.
    result['hand_selection'] = []
    for raw in arr(s.get('hand')):
        c = obj(raw); a = obj(c.get('ability'))
        hidden = any(c.get(k) for k in ('unknown', 'identity_redacted', 'identity_unknown', 'face_down'))
        known = isinstance(c.get('ability'), dict) and (not hidden or 'forced_selection' in a)
        forced = a.get('forced_selection', False)
        result['hand_selection'].append({'id': c.get('id'),
            'forced': forced if known and type(forced) is bool else None})
    require(len(encoded(result)) <= 65536, 'Projected observation exceeds bound')
    return result


def indexed(s, action):
    rows = arr(s.get(action.get('area')))
    index = action.get('index')
    return rows[index - 1] if type(index) is int and 1 <= index <= len(rows) else None


def ids(rows):
    return {c['id'] for c in rows if ident(c.get('id'))}


def active(card):
    a = obj(card.get('ability'))
    return not card.get('unknown') and not card.get('debuff') and not (
        a.get('perishable') and num(a.get('perish_tally')) and a['perish_tally'] <= 0)


def horizon(s):
    b = obj(s.get('next_blind')) if s.get('phase') in ('shop', 'pack') else obj(s.get('blind'))
    ante, end = b.get('ante', s.get('ante')), s.get('win_ante')
    stage = {'bl_small': 3, 'bl_big': 2}.get(b.get('key'), 1 if b.get('boss') else None)
    if stage is None or not num(ante) or not num(end):
        return None
    return max(0, int(end - ante)) * 3 + stage


def development_context(s):
    jokers = s['jokers']
    return {'active_growth_jokers': [c for c in jokers if active(c) and c.get('key') in
                ('j_yorick', 'j_burnt', 'j_castle', 'j_trading', 'j_hit_the_road')],
            'held_death': [c for c in s['consumeables'] if c.get('key') == 'c_death'],
            'nominal_unskipped_blinds_including_current': horizon(s),
            'possible_cost_jokers': [c for c in jokers if c.get('key') in
                ('j_ramen', 'j_green_joker', 'j_banner', 'j_delayed_grat')],
            'safe_five_card_alternative_established': False}


def review_family(rule, evidence, advice):
    if rule == 'short_discard':
        risk = obj(obj(advice.get('yorick_review')).get('risk'))
        if num(risk.get('qualified_five_count')) and risk['qualified_five_count'] > 0:
            return 'receipt_mentions_qualified_five'
        if evidence['hand_count'] < 5:
            return 'fewer_than_five_cards_in_hand'
        return 'growth_present_five_unproved' if evidence['active_growth_jokers'] else 'no_watched_growth_joker'
    if rule == 'unused_discards_at_clear':
        if evidence['nominal_unskipped_blinds_including_current'] == 1:
            return 'final_boss_no_later_round_growth'
        return 'growth_present_safety_unproved' if evidence['active_growth_jokers'] else 'no_watched_growth_joker'
    return rule


def offer_context(s, card, area):
    """Conservative direct-slot screen; never invent a full-row sale endpoint."""
    a = obj(card.get('ability'))
    if not ident(card.get('id')) or not active(card):
        return None, 'hidden_debuffed_or_expired'
    cap = s.get('joker_limit')
    negative = obj(card.get('edition')).get('negative') is True
    if not num(cap) or len(s['jokers']) >= cap + int(negative):
        return None, 'full_row_requires_unmodeled_sale'
    cost = 0 if area == 'pack_cards' else card.get('cost')
    money, credit = s.get('dollars'), s.get('bankrupt_at')
    if not all(num(v) for v in (cost, money, credit)) or cost < 0:
        return None, 'missing_purchase_resources'
    if cost > money - credit:
        return None, 'unaffordable'
    reserve = (sum(bool(obj(c.get('ability')).get('rental')) for c in s['jokers']) +
               int(bool(a.get('rental')))) * s.get('rental_rate', 3)
    if not num(reserve) or money - cost < reserve:
        return None, 'one_round_rental_reserve_not_met'
    targets = [c for c in s['jokers'] if active(c) and c.get('key') in CORE]
    if card.get('key') != 'j_invisible':
        targets = [c for c in targets if c.get('blueprint_compat') is True]
    if not targets:
        return None, 'no_visible_watched_engine_target'
    remaining = horizon(s)
    if card.get('key') == 'j_invisible':
        if a.get('eternal'):
            return None, 'invisible_unsellable'
        required = a.get('extra', 2)
        mature = a.get('invis_rounds', 0)
        if not num(required) or not num(mature) or remaining is None:
            return None, 'invisible_horizon_unknown'
        wait = max(0, required - mature)
        if remaining <= wait:
            return None, 'invisible_insufficient_development_horizon'
        if a.get('perishable') and (not num(a.get('perish_tally')) or a['perish_tally'] <= wait):
            return None, 'invisible_expires_before_use'
    return {'offer': card, 'area': area, 'immediate_cost': cost, 'cash_after': money - cost,
            'one_round_rental_reserve': reserve, 'nominal_blinds': remaining,
            'watched_engine_targets': targets, 'entire_visible_joker_pool': s['jokers'],
            'future_blueprint_funding_guaranteed': False}, None


class Screener:
    """Bounded causal joins. Later states confirm effects, never score alternatives."""

    def __init__(self, max_flags=200, on_settled=None, on_flag=None):
        require(type(max_flags) is int and 1 <= max_flags <= LIMITS['flags'], 'Invalid flag cap')
        self.max_flags = max_flags
        self.observations, self.advice = OrderedDict(), OrderedDict()
        self.runs, self.pending, self.plans = {}, {}, {}
        self.flags, self.counts, self.suppressions = [], Counter(), Counter()
        self.rule_counts, self.closed_offers, self.groups = Counter(), set(), {}
        self.on_settled, self.on_flag = on_settled, on_flag

    def cache(self, table, key, value):
        require(key not in table, 'Duplicate observation/advice identity')
        table[key] = value
        if len(table) > LIMITS['cached_links']:
            table.popitem(last=False)
            self.counts['cached_links_evicted'] += 1

    def emit(self, p, rule, evidence, priority, effect):
        require(sum(self.rule_counts.values()) < LIMITS['rule_hits'], 'Rule-hit cap reached')
        scope = p['scope']
        token = sha(encoded([scope, p['request']['sequence'], rule, evidence.get('offer', {}).get('id')]))[:20]
        family = review_family(rule, evidence, p['advice'])
        group = self.groups.setdefault((rule, family), {'rule': rule, 'review_family': family, 'count': 0, 'examples': []})
        group['count'] += 1
        if len(group['examples']) < 3:
            group['examples'].append({'id': token, 'request': p['request']})
        row = {'id': token, 'rule': rule, 'priority': priority, 'classification': 'review_hypothesis',
               'review_family': family,
               'run': self.runs[scope], 'scope': list(scope), 'version': p['version'],
               'action': p['action'], 'evidence': evidence, 'competing_explanation': CAUTIONS[rule],
               'anchors': {'observation': p['observation'], 'advice': p['advice_anchor'],
                           'request': p['request'], 'marker': p['marker'], 'effect': effect},
               'decision_context': p['state'], 'recorded_advice': p['advice'],
               'adjudication': {'status': 'unreviewed', 'reason': None, 'paired_fixture': None}}
        self.flags.append(row)
        if self.on_flag:
            self.on_flag(copy.deepcopy(row))
        self.flags.sort(key=lambda r: (-r['priority'], r['anchors']['request']['sequence'], r['id']))
        if len(self.flags) > self.max_flags:
            self.flags.pop()
        self.rule_counts[rule] += 1

    def expire(self, scope, reason):
        if scope in self.pending:
            p = self.pending.pop(scope)
            self.counts['unconfirmed_actions_' + reason] += 1
            self.counts['unconfirmed_rule_candidates'] += len(p['candidates'])
        self.plans.pop(scope, None)

    def feed(self, event, anchor):
        ctx, detail = obj(event.get('context')), obj(event.get('details'))
        scope = (anchor['session'], event.get('collection_id'), ctx.get('run_instance'))
        if not all(ident(v) for v in scope):
            self.counts['events_without_collection_run_identity'] += 1
            return
        seq, kind = event['sequence'], event.get('kind')
        if kind == 'auto_run':
            tag = detail.get('event')
            if tag == 'run_started':
                require(len(self.runs) < LIMITS['scopes'], 'Run scope cap reached')
                require(scope not in self.runs, 'Duplicate explicit run start')
                self.runs[scope] = {k: detail.get(k) for k in ('run_id', 'run_number')}
                self.runs[scope]['ended'] = False
                self.counts['explicit_run_starts'] += 1
            elif tag in ('run_finished', 'run_abandoned') and scope in self.runs:
                self.expire(scope, 'run_end')
                self.runs[scope]['ended'] = True
                self.counts['explicit_run_ends'] += 1
            return
        opened = scope in self.runs and not self.runs[scope]['ended']
        if kind in ('teacher_observation', 'collection_observation'):
            oid = event.get('observation_id')
            if ident(oid):
                state = snapshot_view(ctx.get('snapshot'))
                self.cache(self.observations, (scope, oid), (state, anchor))
                if opened:
                    self.confirm(scope, state, anchor)
            return
        if kind in ('teacher_advice', 'collection_advice'):
            a = obj(ctx.get('advice'))
            require(len(encoded(a)) <= 65536, 'Advice cap exceeded')
            self.cache(self.advice, (scope, seq), (a, event.get('observation_id'), anchor))
            return
        if not opened:
            if kind == 'action_requested':
                self.counts['requests_outside_explicit_open_run'] += 1
            return
        if scope in self.pending and seq - self.pending[scope]['request']['sequence'] > LIMITS['effect_events']:
            self.expire(scope, 'effect_bound')
        if kind == 'state_after_actions' and scope in self.pending:
            p = self.pending[scope]
            if p['request']['sequence'] in arr(detail.get('action_sequences')):
                p['marker'] = anchor
                observation = self.observations.get((scope, event.get('observation_id')))
                if observation:
                    self.confirm(scope, *observation)
            return
        if kind != 'action_requested':
            return
        self.counts['requests_in_open_runs'] += 1
        # Any intervening action ends attribution, including manual/non-advisor actions.
        plan = self.plans.pop(scope, None)
        self.expire(scope, 'next_action')
        if detail.get('source') != 'auto_run' or detail.get('action') != 'advisor_execute':
            self.counts['non_auto_advisor_requests'] += 1
            return
        observation = self.observations.get((scope, event.get('observation_id')))
        advice = self.advice.get((scope, event.get('advice_sequence')))
        action = obj(obj(detail.get('input')).get('action'))
        if not observation or not advice:
            self.counts['requests_missing_explicit_links'] += 1
            return
        s, oanchor = observation
        a, aoid, aanchor = advice
        if (aoid != event.get('observation_id') or event.get('observation_sequence') != oanchor['sequence'] or
            not oanchor['sequence'] < aanchor['sequence'] < seq or a.get('status') != 'current' or
            action != a.get('action')):
            self.counts['requests_stale_mismatched_or_noncausal'] += 1
            return
        self.counts['linked_current_advisor_requests'] += 1
        p = dict(scope=scope, state=s, advice=a, action=action, observation=oanchor,
                 advice_anchor=aanchor, request=anchor, marker=None, candidates=[], version=ctx.get('version'))
        self.pending[scope] = p
        k = action.get('kind')
        chosen = indexed(s, action)
        if k == 'discard':
            self.counts['discard_requests'] += 1
            indices = arr(action.get('indices'))
            if indices and len(set(indices)) == len(indices) and all(type(i) is int and 1 <= i <= len(s['hand']) for i in indices):
                p['selected_ids'] = ids([s['hand'][i - 1] for i in indices])
                if len(indices) < 5 and len(p['selected_ids']) == len(indices):
                    context = development_context(s)
                    context.update(selected_count=len(indices), hand_count=len(s['hand']), unused_capacity_to_five=5-len(indices))
                    p['candidates'].append(('short_discard', context, 35 if context['active_growth_jokers'] else 10))
        elif k == 'play':
            self.counts['play_requests'] += 1
        if k == 'choose' and action.get('area') == 'pack_cards' and chosen and str(chosen.get('key', '')).startswith('j_'):
            self.counts['joker_pack_choice_requests'] += 1
            self.pack_merit(p, chosen)
        if plan:
            self.check_plan(p, plan, chosen)
        if k == 'sell' and action.get('area') == 'jokers' and chosen:
            review = obj(a.get('shop_sequence_review'))
            structured = obj(review.get('plan'))
            steps = arr(review.get('steps'))
            first = obj(steps[0]) if steps else {}
            target408 = next((c for c in s.get(first.get('area'), []) if c.get('id') == first.get('id') and
                              c.get('key') == first.get('key') and c.get('cost') == first.get('cost')), None)
            if (structured.get('complete') is True and ident(structured.get('id')) and target408 and
                    first.get('kind') == 'buy' and ident(target408.get('id'))):
                p['sale_plan'] = dict(target=target408, sold=chosen, followup=first, structured=True, id=structured['id'])
            elif chosen.get('key') in CORE and active(chosen) and not obj(chosen.get('ability')).get('perishable') and not obj(action.get('followup')):
                p['candidates'].append(('core_sale_without_plan', {'sold': chosen, 'receipt': review}, 95))
            follow = obj(action.get('followup'))
            target = indexed(s, follow)
            if target and ident(target.get('id')) and chosen.get('key') not in ('j_credit_card', 'j_invisible'):
                p['sale_plan'] = dict(target=target, sold=chosen, followup=follow)
            elif target:
                self.suppressions['sale_plan_unmodeled_credit_or_random_sale'] += 1
        if k == 'skip_pack' and s.get('phase') == 'pack':
            planets = [c for c in s['pack_cards'] if active(c) and c.get('key') in
                       ('c_pluto','c_mercury','c_uranus','c_venus','c_saturn','c_jupiter','c_earth','c_mars','c_neptune','c_planet_x','c_ceres','c_eris')]
            if planets:
                p['candidates'].append(('free_planet_skip', {'offers': planets, 'immediate_cost': 0,
                    'last_tarot_planet': s.get('last_tarot_planet'), 'receipt': obj(a.get('copy_death_review')).get('pack')}, 65))
        if k == 'leave_shop' and s.get('teacher_profile') == 'perkeo_yorick_win_v1' and s.get('last_tarot_planet') in (
                'c_pluto','c_mercury','c_uranus','c_venus','c_saturn','c_earth','c_mars','c_neptune','c_planet_x','c_ceres','c_eris'):
            fools = [c for c in s['consumeables'] if active(c) and c.get('key') == 'c_fool']
            if fools and any(c.get('key') == 'j_perkeo' and active(c) for c in s['jokers']):
                p['candidates'].append(('unsupported_fool_stock', {'stock': fools,
                    'last_tarot_planet': s['last_tarot_planet'], 'stock_count': len(fools)}, 75))
        area = 'pack_cards' if s.get('phase') == 'pack' else 'shop_jokers'
        closes = (area == 'shop_jokers' and k in ('leave_shop', 'reroll') or area == 'pack_cards' and
                  (k == 'skip_pack' or k == 'choose' and s.get('pack_choices') == 1))
        if closes:
            for card in s[area]:
                if card.get('key') not in WATCH or chosen and card.get('id') == chosen.get('id'):
                    continue
                self.counts['watched_offer_closure_candidates'] += 1
                evidence, reason = offer_context(s, card, area)
                if reason:
                    self.suppressions[reason] += 1
                else:
                    rule = 'invisible_offer_pass' if card['key'] == 'j_invisible' else 'copy_offer_pass'
                    p['candidates'].append((rule, evidence, 60 if rule == 'invisible_offer_pass' else 80))

    def pack_merit(self, p, chosen):
        if p['state'].get('pack_choices') != 1:
            self.counts['pack_merit_multiple_or_unknown_choices_unassessed'] += 1
            return
        pack = obj(obj(p['advice'].get('copy_death_review')).get('pack'))
        if pack.get('complete') is not True or pack.get('incomplete') or pack.get('truncated') or pack.get('attempted_truncated'):
            self.counts['pack_choices_without_complete_receipts'] += 1
            return
        rows = [r for r in arr(pack.get('candidates')) if isinstance(r, dict) and r.get('kind') == 'choose' and
                r.get('status') == 'complete' and r.get('admitted') is True and num(r.get('score')) and
                r.get('objective_admitted') is not False and r.get('legal') is not False]
        visible = {c.get('id'): c for c in p['state']['pack_cards'] if ident(c.get('id'))}
        rows = [r for r in rows if r.get('offer_id') in visible and visible[r['offer_id']].get('key') == r.get('key')]
        own = [r for r in rows if r.get('offer_id') == chosen.get('id')]
        if len(own) != 1 or len({r['offer_id'] for r in rows}) != len(rows):
            self.counts['pack_choices_without_unique_comparable_rows'] += 1
            return
        self.counts['pack_choices_with_comparable_receipts'] += 1
        selected = own[0]
        stronger = [r for r in rows if r.get('offer_id') != selected.get('offer_id') and
                    r.get('complete_finishing') is True and selected.get('complete_finishing') is True and
                    r.get('uncertain') is False and selected.get('uncertain') is False and
                    num(r.get('after_mean')) and num(selected.get('after_mean')) and
                    num(r.get('after_target')) and r.get('after_target') == selected.get('after_target') and
                    r['after_mean'] > max(1, selected['after_mean']) * 1.25 and r['score'] <= selected['score']]
        if stronger:
            p['candidates'].append(('pack_score_merit_conflict', {'selected': selected,
                'stronger_opening': max(stronger, key=lambda r: r['after_mean']), 'durability_unassessed': True}, 65))
        better = [r for r in rows if r['score'] - selected['score'] >= max(10, abs(selected['score']) * .2) and
                  r.get('after_target') == selected.get('after_target') and num(r.get('after_target'))]
        if better:
            best = max(better, key=lambda r: r['score'])
            p['candidates'].append(('pack_merit_reversal', {'selected': selected, 'higher_merit': best,
                'minimum_absolute_gap': 10, 'minimum_relative_gap': .2, 'survival_arbitration_missing': True}, 70))

    def check_plan(self, p, plan, chosen):
        s, before = p['state'], plan['state']
        target, sold, follow = plan['sale_plan']['target'], plan['sale_plan']['sold'], plan['sale_plan']['followup']
        area = follow.get('area')
        if plan['sale_plan'].get('structured'):
            stable = (all(s.get(k) == before.get(k) for k in ('phase','ante','round','next_blind','joker_limit','bankrupt_at')) and
                s.get('dollars') == before.get('dollars', 0) + sold.get('sell_cost', 0) and
                s['jokers'] == [c for c in before['jokers'] if c.get('id') != sold.get('id')] and
                s.get(area) == before.get(area) and
                obj(obj(p['advice'].get('shop_sequence_review')).get('continuation')).get('status') != 'public_context_changed')
            if not stable:
                self.suppressions['sale_plan_context_changed'] += 1
            elif chosen and chosen.get('id') == target.get('id') and p['action'].get('kind') == follow.get('kind'):
                self.counts['sale_followups_kept_plan'] += 1
            elif p['action'].get('kind') in ('buy', 'leave_shop', 'reroll'):
                p['candidates'].append(('sale_plan_reversal', {'offer': target, 'chosen': chosen,
                    'sold': sold, 'plan_id': plan['sale_plan']['id'], 'prior_sale_request': plan['request'],
                    'fresh_receipt': p['advice'].get('shop_sequence_review')}, 95))
            return
        if area == 'pack_cards' and s.get('pack_choices') != 1:
            self.suppressions['sale_plan_multiple_or_unknown_pack_choices'] += 1
            return
        if area == 'shop_jokers' and (not num(s.get('joker_limit')) or s['joker_limit'] - len(s['jokers']) != 1):
            self.suppressions['sale_plan_multiple_or_unknown_free_slots'] += 1
            return
        retained = [c for c in before['jokers'] if c.get('id') != sold.get('id')]
        expected_cash = before.get('dollars', 0) + sold.get('sell_cost', 0)
        stable = (p['action'].get('kind') == follow.get('kind') and p['action'].get('area') == area and
                  all(s.get(k) == before.get(k) for k in ('phase', 'ante', 'round', 'next_blind', 'joker_limit', 'bankrupt_at', 'pack_choices')) and
                  s.get('dollars') == expected_cash and s['jokers'] == retained and
                  sorted(s.get(area, []), key=lambda c: str(c.get('id'))) == sorted(before.get(area, []), key=lambda c: str(c.get('id'))))
        if not stable:
            self.suppressions['sale_plan_context_changed'] += 1
        elif chosen and chosen.get('id') != target.get('id'):
            self.counts['comparable_sale_followups'] += 1
            p['candidates'].append(('sale_plan_reversal', {'offer': target, 'chosen': chosen,
                'prior_sale_request': plan['request'], 'prior_sale_observation': plan['observation'],
                'prior_sale_advice': plan['advice_anchor'], 'sold': sold, 'prior_advice': plan['advice']}, 90))
        else:
            self.counts['sale_followups_kept_plan'] += 1

    def confirm(self, scope, s, anchor):
        p = self.pending.get(scope)
        if not p or not p['marker'] or anchor['sequence'] <= p['request']['sequence']:
            return
        before, action = p['state'], p['action']
        if anchor['sequence'] - p['request']['sequence'] > LIMITS['effect_events']:
            self.expire(scope, 'effect_bound')
            return
        k, chosen = action.get('kind'), indexed(before, action)
        owned = ids(s['jokers'])
        same_round_number = num(before.get('round')) and s.get('round') == before['round']
        same_round = same_round_number and num(before.get('ante')) and s.get('ante') == before['ante']
        confirmed = False
        if k == 'discard':
            confirmed = (same_round and s.get('phase') == 'hand' and
                num(s.get('discards_left')) and num(before.get('discards_left')) and
                s['discards_left'] == before['discards_left'] - 1 and p.get('selected_ids') and
                not p['selected_ids'].intersection(ids(s['hand'])))
        elif k == 'play':
            blind = obj(before.get('blind'))
            target = blind.get('chips')
            # Boss cash-out advances ante while retaining this completed round number.
            cashout_ante = (same_round or same_round_number and blind.get('boss') is True and
                           num(before.get('ante')) and s.get('ante') == before['ante'] + 1)
            confirmed = (s.get('phase') == 'round' and cashout_ante and
                         num(target) and target > 0 and num(s.get('chips')) and s['chips'] >= target)
            if confirmed:
                self.counts['confirmed_round_clears_linked_to_play'] += 1
                if num(s.get('discards_left')) and s['discards_left'] > 0:
                    context = development_context(before)
                    context.update(remaining_discards=s['discards_left'], before_discards=before.get('discards_left'),
                                   recorded_round_chips=s['chips'], previous_blind_target=target)
                    priority = 40 if context['active_growth_jokers'] else 15
                    if context['nominal_unskipped_blinds_including_current'] == 1:
                        priority = 5
                    p['candidates'].append(('unused_discards_at_clear', context, priority))
        elif k in ('choose', 'buy') and chosen:
            confirmed = (same_round and ident(chosen.get('id')) and chosen['id'] in owned and
                         chosen['id'] not in ids(before['jokers']))
            if k == 'buy' and action.get('area') == 'shop_vouchers':
                confirmed = (same_round and num(chosen.get('cost')) and num(before.get('dollars')) and
                    ident(chosen.get('id')) and chosen['id'] not in ids(s['shop_vouchers']) and
                    obj(s.get('used_vouchers')).get(chosen.get('key')) is True and
                    s.get('dollars') == before['dollars'] - chosen['cost'])
        elif k == 'sell' and action.get('area') == 'jokers' and chosen:
            confirmed = (ident(chosen.get('id')) and chosen['id'] not in owned and
                         same_round and s.get('phase') == before.get('phase'))
        elif k == 'leave_shop':
            confirmed = same_round and before.get('phase') == 'shop' and s.get('phase') == 'blind'
        elif k == 'skip_pack':
            confirmed = same_round and before.get('phase') == 'pack' and s.get('phase') in ('shop', 'blind', 'hand')
        elif k == 'reroll':
            cost = before.get('reroll_cost')
            old, new = ids(before['shop_jokers']), ids(s['shop_jokers'])
            confirmed = (same_round and s.get('phase') == before.get('phase') == 'shop' and old and new and
                         old.isdisjoint(new) and num(cost) and cost >= 0 and num(before.get('dollars')) and
                         s.get('dollars') == before['dollars'] - cost)
        if not confirmed:
            return
        if not p.get('observer_delivered'):
            p['observer_delivered'] = True
            self.counts['unique_observer_eligible_settlements'] += 1
            self.counts['eligible_settlement_' + str(k)] += 1
            if self.on_settled:
                # No observer can alter attribution or future comparisons.
                self.on_settled(copy.deepcopy({
                    'scope': p['scope'], 'run': self.runs[scope], 'version': p['version'],
                    'state': p['state'], 'advice': p['advice'], 'action': p['action'],
                    'after': s, 'anchors': {'observation': p['observation'],
                    'advice': p['advice_anchor'], 'request': p['request'],
                    'marker': p['marker'], 'effect': anchor}}))
        remaining = []
        for rule, evidence, priority in p['candidates']:
            if rule in ('copy_offer_pass', 'invisible_offer_pass'):
                offer = evidence['offer']['id']
                if offer in owned:
                    self.counts['watched_offer_acquired_before_closure'] += 1
                    continue
                # Empty arrays during animations/menu transitions are not a closed opportunity.
                pack_still_unsettled = evidence['area'] == 'pack_cards' and s.get('phase') not in ('shop', 'blind', 'hand')
                if offer in ids(s[evidence['area']]) or pack_still_unsettled:
                    remaining.append((rule, evidence, priority))
                    continue
                token = (scope, offer)
                if token in self.closed_offers:
                    continue
                self.closed_offers.add(token)
            self.emit(p, rule, evidence, priority, anchor)
        if remaining:
            p['candidates'] = remaining
            return
        self.counts['physically_confirmed_screened_actions'] += 1
        if 'sale_plan' in p:
            self.plans[scope] = p
        del self.pending[scope]

    def report(self):
        return {'schema': 1, 'rule_version': RULE_VERSION, 'rules': RULES, 'limits': LIMITS,
                'status': 'screened_supplied_records', 'complete_session_claimed': False,
                'policy_executed': False, 'win_rate_or_improvement_claimed': False,
                'counts': dict(self.counts), 'suppressed_or_unmodeled': dict(self.suppressions),
                'flags_by_rule': dict(self.rule_counts), 'flags_total': sum(self.rule_counts.values()),
                'flags_retained': len(self.flags), 'flags_omitted': sum(self.rule_counts.values()) - len(self.flags),
                'unconfirmed_actions_at_tail': len(self.pending),
                'unconfirmed_rule_candidates_at_tail': sum(len(p['candidates']) for p in self.pending.values()),
                'review_groups': list(self.groups.values()),
                'adjudication_statuses': ['unreviewed', 'confirmed_defect', 'reasonable_tradeoff', 'insufficient_evidence'],
                'runs': [{'scope': list(k), **v} for k, v in self.runs.items()], 'flags': self.flags}


def analyze(copy_dir, manifest_path, max_flags=200, *, on_settled=None, on_flag=None):
    folder, manifest_path = Path(copy_dir).resolve(), Path(manifest_path).resolve()
    require(manifest_path.stat().st_size <= 65536, 'Manifest exceeds bound')
    manifest_bytes = manifest_path.read_bytes()
    manifest = parsed(manifest_bytes)
    segments = arr(obj(manifest).get('segments'))
    require(0 < len(segments) <= LIMITS['files'], 'Invalid segment count')
    paths, total = [], 0
    for entry in segments:
        name = obj(entry).get('name')
        require(ident(name) and Path(name).name == name and '/' not in name and '\\' not in name, 'Unsafe segment name')
        path = (folder / name).resolve()
        require(path.parent == folder and path not in paths, 'Escaping or duplicate segment')
        size = path.stat().st_size
        require(0 < size <= LIMITS['file_bytes'] and size == entry.get('bytes') and file_sha(path) == entry.get('sha256'), 'Input length/hash mismatch: ' + name)
        total += size
        require(total <= LIMITS['input_bytes'], 'Input byte cap exceeded')
        paths.append(path)
    screener = Screener(max_flags, on_settled=on_settled, on_flag=on_flag)
    tails, event_count, decoded, links = {}, 0, 0, 0
    for path, entry in zip(paths, segments):
        with path.open('rb') as stream:
            reader = HashedReader(stream, entry['bytes'])
            for ordinal, (raw, meta) in enumerate(records(reader), 1):
                require(meta.get('format') == 2, 'Only identity-bearing BRJ2 archives are supported')
                event_count += 1
                decoded += len(raw)
                require(event_count <= LIMITS['events'] and decoded <= LIMITS['decoded_bytes'], 'Event/decoded-byte cap reached')
                previous = tails.get(meta['session'])
                if previous:
                    require(meta['sequence'] == previous['sequence'] + 1, 'Cross-file sequence gap or duplicate')
                    require(meta['previous_frame_sha256'] == previous['frame_sha256'], 'Cross-file predecessor mismatch')
                    require(path.name == previous['file'] or meta['segment'] > previous['segment'], 'Cross-file segment regression')
                    links += 1
                require(len(tails) < LIMITS['scopes'] or meta['session'] in tails, 'Archive session cap reached')
                tails[meta['session']] = {**meta, 'file': path.name}
                anchor = {k: meta[k] for k in ('session', 'segment', 'sequence')}
                anchor.update(file=path.name, ordinal=ordinal, event_sha256=sha(raw))
                screener.feed(parsed(raw), anchor)
            require(reader.count == entry['bytes'] and reader.hash.hexdigest() == entry['sha256'], 'Decoded stream length/hash differs from manifest')
    # Bind the consumed streams and verify the paths still match before success.
    require(manifest_path.read_bytes() == manifest_bytes, 'Manifest changed during read')
    for path, entry in zip(paths, segments):
        require(path.stat().st_size == entry['bytes'] and file_sha(path) == entry['sha256'], 'Input changed during analysis')
    result = screener.report()
    result.update(inputs=segments, manifest_sha256=sha(manifest_bytes), events=event_count,
                  decoded_bytes=decoded, supplied_frame_links_validated=links,
                  outside_predecessors_verified=False, screener_sha256=file_sha(Path(__file__)))
    return result


def markdown(report):
    lines = ['# Suspect-decision review queue', '',
             'Heuristic review hypotheses, not confirmed mistakes or win estimates.', '',
             f"{report['events']} supplied events; {report['flags_total']} flags; {report['flags_omitted']} omitted by the ranked output cap.", '',
             '| Rule | Flags |', '| --- | ---: |']
    lines += [f'| {RULES[k]} | {report["flags_by_rule"].get(k, 0)} |' for k in RULES]
    lines += ['', 'Review one example per family first; these are context groups, not established common causes.', '',
              '| Rule | Context family | Count | Example action sequences |', '| --- | --- | ---: | --- |']
    lines += [f"| {g['rule']} | {g['review_family']} | {g['count']} | {', '.join(str(x['request']['sequence']) for x in g['examples'])} |" for g in report['review_groups']]
    lines += ['', 'Projected decision contexts, reasons, scope and exact segment/ordinal/hash anchors are in report.json.',
              'Review missing-receipt, suppression and unconfirmed counts before interpreting coverage.', '',
              '| Priority | Run | Action sequence | Rule | Flag ID |', '| ---: | --- | ---: | --- | --- |']
    lines += [f"| {r['priority']} | {r['run'].get('run_number')} | {r['anchors']['request']['sequence']} | {r['rule']} | {r['id']} |" for r in report['flags']]
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--copy-dir', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='New directory; never overwrite')
    parser.add_argument('--max-flags', type=int, default=200)
    args = parser.parse_args()
    try:
        args.output.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        print(str(error), file=sys.stderr)
        return 1
    try:
        report = analyze(args.copy_dir, args.manifest, args.max_flags)
        rendered = json.dumps(report, indent=2) + '\n'
        require(len(rendered.encode('utf-8')) <= LIMITS['output_bytes'], 'Output byte cap reached')
        (args.output / 'report.json').write_text(rendered, encoding='utf-8')
        (args.output / 'REPORT.md').write_text(markdown(report), encoding='utf-8')
        ledger = [{'id': r['id'], 'rule': r['rule'], **r['adjudication']} for r in report['flags']]
        (args.output / 'adjudication.json').write_text(json.dumps(ledger, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({k: report[k] for k in ('status', 'events', 'flags_by_rule', 'flags_total', 'flags_omitted')}))
        return 0
    except (OSError, ArchiveError, ScreenError, TypeError, ValueError, KeyError, RecursionError) as error:
        (args.output / 'error.json').write_text(json.dumps({'status': 'failed_no_trusted_report', 'error': str(error)}) + '\n', encoding='utf-8')
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
