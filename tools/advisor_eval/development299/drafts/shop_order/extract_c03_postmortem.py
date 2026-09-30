"""Extract observed C03 decision evidence only; no rescoring or altered snapshots."""
from pathlib import Path
import json
from audit_c02 import read_trace, indexed, sha, slim

ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C03'
OUT = ROOT / 'tools/advisor_eval/development299/c03_analysis'
OUT.mkdir(exist_ok=True)
rows, parsing = read_trace(SOURCE / 'trace.log')
decisions = indexed(rows, 'decision')
evidence = {'kind': 'read_only_contemporaneous_postmortem', 'source_trace_sha256': sha(SOURCE / 'trace.log'),
            'source_audit_sha256': sha(SOURCE / 'audit.json'), 'new_policy_evaluations': 0,
            'new_source_executions': 0, 'decisions': []}
for step in (5, 6, 7, 11, 12, 13, 14, 16, 17, 18, 19, 20, 21, 22):
    row = decisions[step]; snapshot = row['snapshot']; result = row['result']
    item = {'step': step, 'action': result['action'], 'phase': snapshot['phase'],
            'ante': snapshot['ante'], 'round': snapshot['round'], 'cash': snapshot['dollars'],
            'target': snapshot['blind'].get('chips'), 'chips': snapshot['chips'],
            'discards_left': snapshot['discards_left'], 'hands_left': snapshot['hands_left'],
            'jokers': [dict(slim(c), yorick_discards=c['ability'].get('yorick_discards'),
                            x_mult=c['ability'].get('x_mult')) for c in snapshot['jokers']],
            'owned_consumables': [slim(c) for c in snapshot['consumeables']],
            'hand': [dict(slim(c), debuff=c.get('debuff'), seal=c.get('seal')) for c in snapshot['hand']],
            'play': result.get('play'), 'pack_diagnostics': result.get('pack_diagnostics'),
            'resource_comparison': result.get('resource_comparison'),
            'discard_comparison_complete': result.get('discard_comparison_complete'),
            'discard_alternatives': result.get('discard_alternatives'),
            'strategy_lines': result.get('strategy', {}).get('lines'),
            'strategy_warnings': result.get('strategy', {}).get('warnings')}
    for area in ('shop_jokers', 'shop_booster', 'shop_vouchers', 'pack_cards'):
        item[area] = [dict(slim(c), name=c.get('name')) for c in snapshot.get(area, [])]
    evidence['decisions'].append(item)
with (OUT / 'evidence.json').open('x', encoding='utf-8') as stream:
    json.dump(evidence, stream, indent=2)
print(sha(OUT / 'evidence.json'))
