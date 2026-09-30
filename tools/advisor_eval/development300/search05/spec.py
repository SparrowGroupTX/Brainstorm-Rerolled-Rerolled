"""Pure S05 request construction. Importing never starts or registers a job."""
DOMAIN = 2318107019761
DIGITS = '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
COEFFICIENTS = (66231629136, 1892332261, 54066636, 1544761, 44136, 1261, 36, 1)
NATIVE_SHA256 = 'ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf'
NATIVE_NAME = 'Immolate-advisor-' + NATIVE_SHA256 + '.dll'

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

def request():
    return {
        'schema': 1, 'job': 'S05', 'native_api_version': 9,
        'seed': seed_at(2000000001), 'start_index': 2000000001,
        'max_indices': 1000000000000, 'budget_ms': 27000, 'outer_cap_seconds': 30,
        'targets': ['Yorick', 'Brainstorm', 'Burnt Joker', 'Perkeo', ''],
        'locations': ['soul_pack', 'by_ante_5', 'by_ante_5', 'soul_pack', 'ante_1'],
        'deck': 'Red Deck', 'stake': 8, 'no_perishable_targets': True,
        'copy_alternatives': True, 'minimum_distinct': 0, 'missing_names': [],
        'first_ante': 1, 'last_ante': 8, 'cpu': 'maximum', 'matches': 1,
        'native_sha256': NATIVE_SHA256, 'native_file': NATIVE_NAME,
        'profile': 'all_unlocked_discovered_v1',
        'native_profile_semantics': 'Synthetic complete-unlock/discovery assumption; native API reads no player profile.',
        'selection': 'Explicitly selected development start index; not an unseen holdout or representative seed sample.',
        'range_semantics': 'One bounded parallel query; actual screened count is reported, not inferred from requested index ceiling.',
        'route': 'conditional_no_reroll_stock_and_buffoon',
        'later_requirement': [{'any_of': ['j_brainstorm', 'j_blueprint'], 'by_ante': 5}, {'key': 'j_burnt', 'by_ante': 5}],
        'qualification': False,
    }

def native_args(q, seed=None):
    if q != request():
        raise ValueError('S05 worker accepts only its exact preregistered request')
    return [seed or q['seed'], '', '', 'Charm Tag', 2, False, 0, False, False,
            False, False, False, 'No Filter', 'Kings', 'Any Suit', 0, 0,
            '\x1f'.join(q['targets']), q['deck'], '\x1f'.join(q['locations']),
            q['stake'], True, True, '', 0, 1, 8, q['budget_ms']]
