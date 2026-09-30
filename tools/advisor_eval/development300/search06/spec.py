"""S06 pure request and result protocol. Importing never registers or searches."""
import copy
import json
import math
import re

DOMAIN = 2318107019761
DIGITS = '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
COEFFICIENTS = (66231629136, 1892332261, 54066636, 1544761, 44136, 1261, 36, 1)
NATIVE_SHA256 = 'ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf'
NATIVE_NAME = 'Immolate-advisor-' + NATIVE_SHA256 + '.dll'
FIELDS = ('voucher pack tag souls observatory observatory_deadline perkeo copymoney retcon bean burglar '
          'custom_filter target_rank target_suit specific_rank_min any_rank_min target_jokers deck '
          'target_locations stake_level reject_perishable_targets interchangeable_copies missing_names '
          'minimum_distinct first_ante last_ante budget_ms').split()

def seed_at(index):
    if type(index) is not int or not 1 <= index < DOMAIN:
        raise ValueError('Invalid native index')
    parts = []
    for coefficient in COEFFICIENTS:
        if index > 0:
            digit = (index - 1) // coefficient
            index -= 1 + digit * coefficient
            parts.append(DIGITS[digit])
    return ''.join(reversed(parts))

def make_request(generation):
    q = generation['query']
    p = generation['product_request']
    first, second = (phase['query'] for phase in generation['phase_templates'])
    goal = generation['goal']
    if (not generation['synthetic'] or generation['native_calls'] != 0 or
        goal['counts'] != dict(total=150, complete=149, missing=1, unknown=0) or
        len(goal['by_key']) != 150 or
        [key for key, row in goal['by_key'].items() if row['status'] != 'complete'] != ['j_caino'] or
        q['primary_legendary_key'] != 'j_caino' or q['missing_names'] != 'Canio' or
        q['minimum_distinct'] != 1 or not q['opening_adapted'] or not q['burnt_fallback'] or
        q['budget_ms'] != 30000 or p['query']['budget_ms'] != 27000 or
        first['budget_ms'] != 9000 or second['budget_ms'] != 18000 or
        second['target_jokers'] != 'Canio\x1fBrainstorm\x1f\x1fPerkeo\x1f' or
        first['target_jokers'] != 'Canio\x1fBrainstorm\x1fBurnt Joker\x1fPerkeo\x1f'):
        raise ValueError('Installed query generation does not match the S06 hypothesis')
    return dict(schema=1, job='S06', start_index=3000000001, start_seed=seed_at(3000000001),
        max_indices_total=1000000000000, outer_cap_seconds=30, original_native_budget_ms=27000,
        phase1_budget_ms=9000, phase2_budget_ceiling_ms=18000, phase_templates=copy.deepcopy([first,second]),
        native_file=NATIVE_NAME, native_sha256=NATIVE_SHA256, cpu='maximum', max_calls=2, max_matches=1,
        only_missing_key='j_caino', profile='synthetic_all_unlocked_discovered_only_canio_missing_v1',
        profile_token=p['profile_token'], actual_player_profile=False, native_profile_input=False,
        source_or_game_access=False, qualification=False,
        selection='Explicit development cursor; not an unseen holdout or representative seed sample.',
        phase2_condition='Only a valid, returned, fully exited phase1 not_found/timeout with remaining original wall/index budget.',
        timing='One monotonic 27s deadline beginning before native loading; phase2 min(18s, remaining original wall time). Outer root timeout30s includes worker overhead.',
        cursor='After returned miss/timeout: start+max(1, actual screened); no inference that parallel counts prove a contiguous scanned interval.',
        limitation='Conditional native route offer only; no source acquisition, survival, terminal outcome, sticker or player win-rate evidence.')

def native_args(q, seed):
    if not re.fullmatch('[1-9A-Z]{1,8}', seed):
        raise ValueError('Invalid seed')
    return [seed] + [q[key] for key in FIELDS]

def _whole(value, low, high):
    return type(value) is int and low <= value <= high

def _pairs(items):
    out = {}
    for key, value in items:
        if key in out:
            raise ValueError('Duplicate native field')
        out[key] = value
    return out

def parse_result(raw, query):
    """Known flat native v9 transport, matching frozen product validation bounds."""
    if not isinstance(raw, bytes) or len(raw) > 4096:
        raise ValueError('Native result exceeds transport limit')
    r = json.loads(raw.decode('ascii'), object_pairs_hook=_pairs,
                   parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
    allowed = {'schema','status','seed','screened','exact_candidates','seconds','budget_ms','threads','route','reason'}
    if type(r) is not dict or not set(r).issubset(allowed) or any(type(v) not in (str,int,float,bool) for v in r.values()):
        raise ValueError('Malformed flat native response')
    if r.get('status') in ('invalid','busy'):
        if set(r) != {'status'}:
            raise ValueError('Unexpected invalid/busy fields')
        return r
    if r == dict(status='not_found', reason='impossible_fixed_deck_counts', screened=0):
        return r
    if (r.get('schema') != 1 or type(r.get('schema')) is not int or 'reason' in r or
        r.get('status') not in ('found','not_found','timeout','cancelled') or
        not _whole(r.get('screened'),0,DOMAIN) or not _whole(r.get('exact_candidates'),0,r['screened']) or
        type(r.get('seconds')) not in (int,float) or not math.isfinite(r['seconds']) or
        not 0 <= r['seconds'] <= query['budget_ms']/1000+5 or
        r.get('budget_ms') != query['budget_ms'] or type(r.get('budget_ms')) is not int or
        not _whole(r.get('threads'),1,256) or r.get('route') != 'conditional_no_reroll_stock_and_buffoon'):
        raise ValueError('Native result does not match its bounded request')
    if r['status']=='found':
        if (not isinstance(r.get('seed'),str) or not re.fullmatch('[1-9A-Z]{1,8}',r['seed']) or
            r['screened']<1 or r['exact_candidates']<1):
            raise ValueError('Found response lacks seed/exact evidence')
    elif r.get('seed')!='':
        raise ValueError('Nonmatching response carries a seed')
    return r

def fallback(request, first, elapsed_seconds):
    """Called only after synchronous phase1 return/free: never while native busy."""
    if first.get('status') not in ('not_found','timeout'):
        return None
    if not math.isfinite(elapsed_seconds) or elapsed_seconds < 0:
        raise ValueError('Invalid elapsed clock')
    remaining_ms = min(request['phase2_budget_ceiling_ms'],
        math.floor(request['original_native_budget_ms'] - elapsed_seconds*1000))
    screened = first.get('screened')
    if not _whole(screened,0,DOMAIN):
        raise ValueError('Missing screened count')
    next_index = request['start_index'] + max(1,screened)
    left = min(request['max_indices_total']-screened, DOMAIN-next_index)
    if remaining_ms < 1 or next_index >= DOMAIN or left < 1:
        return None
    q = copy.deepcopy(request['phase_templates'][1]);q['budget_ms']=remaining_ms
    return dict(query=q, start_index=next_index, seed=seed_at(next_index), max_indices=left)
