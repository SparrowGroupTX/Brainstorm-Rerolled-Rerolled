"""Extract only already-preserved public journal observations; never evaluate policy."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
INPUT = HERE / 'passive_audit.json'
data = INPUT.read_bytes()
expected = '0aefcae0d9ccc1388e66c41585b772c50ce0ecb927acb910359de9e62e83b1e3'
assert hashlib.sha256(data).hexdigest() == expected
audit = json.loads(data)
sequences = (2195, 2200, 2206, 2212, 2217, 2223, 2228, 2234, 2239, 2242)
by_sequence = {e['anchor']['sequence']: e for e in audit['events']}
events = []
for seq in sequences:
    e = by_sequence[seq]
    row = []
    for position, card in enumerate(e['jokers'], 1):
        row.append({'position': position, **{key: card.get(key) for key in (
            'id', 'key', 'name', 'gold_status', 'ability', 'edition', 'debuff',
            'pinned', 'face_down', 'blueprint_compat', 'cost', 'sell_cost')}})
    events.append({**{key: e.get(key) for key in ('anchor', 'kind', 'at',
        'monotonic_seconds', 'details', 'version', 'seed', 'state', 'advice', 'goal')},
        'row': row, 'inventory_count': len(e['consumeables'])})
report = {
    'schema': 1,
    'scope': 'Read-only extraction from the existing frozen-prefix passive audit. No new journal tail, policy, source function, RNG, save/profile or game-control access.',
    'input': {'path': str(INPUT), 'sha256': expected},
    'events': events,
    'interpretation': {
        'shop_row': 'At 2195 Brainstorm is physically last and Perkeo is first. Every Joker already has Gold.',
        'first_hand_reorder': 'At 2206 the recorded action [4,2,3,1,5,6] puts Caino first, before Yorick. The next recorded snapshot confirms this row. Brainstorm copies Caino, not Yorick.',
        'logged_order_comparison': 'The 2206 advisor text reports Two Pair approximately 48000 versus current-order approximately 12000, with 252 completed bounded order comparisons. These are logged model estimates, not new evaluations or exact source score receipts.',
        'first_actual_play': '2239 plays Flush House after three discard actions, Sun use and a Negative Perkeo sale to disable Leaf. The terminal 2242 original win receipt confirms actual 686952/400000 chips and zero new Gold stickers.',
        'limit': 'The fixed shop-row acquisition family excludes the subsequently observed hand reorder. This is an integration boundary, not proof that an alternate missing-Joker purchase would pass its complete common-world floor or win. Later actual score cannot be attributed to reordering alone.',
        'negative_sale': 'Selling Negative Perkeo reduces the row from six to five and the Joker limit from six to five; it does not create a spare Joker slot.',
    },
}
out = HERE / 'ordering_timeline.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
print(json.dumps({'path': str(out), 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(), 'events': len(events)}))
