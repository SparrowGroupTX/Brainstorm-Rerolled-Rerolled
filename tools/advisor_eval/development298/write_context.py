"""Append a zero-experiment release context; never change old receipts or limits."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[3]
folder = root / 'tools/advisor_eval/runs/diagnostic287_20260913_222344'
before = folder / 'context_final297.json'
value = json.loads(before.read_text(encoding='utf-8'))
value['summary'] += (' Slice298 refines flexible Yorick/Burnt development and Perkeo copying: '
    'repeat useful actual discards, value Burnt rank opportunities from qualified public populations, '
    'and correct owned/free-copy Hermit and prospective purchase cash valuation. '
    'Routine synthetic fixtures/regressions and read-only preserved-source inspection only; '
    'zero additional source components, captured replays, searches or terminal attempts. '
    'All prior counts, outcomes and closed budgets remain unchanged.')
with (folder / 'context_final298.json').open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
    stream.write('\n')
source = folder / 'b_preparation2/source/card.lua'
receipt = {'kind': 'read_only_preserved_source_reference',
    'path': str(source.relative_to(root)), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'lines': {'Hermit': [1385, 1390], 'Perkeo': [2412, 2424], 'Burnt': [2749, 2755], 'Yorick': [2788, 2802]},
    'original_source_executed': False, 'new_experiment_jobs': 0,
    'scope': 'Read-only mechanics references for routine detached policy fixes; no executable ZIP, game process or save/profile access.'}
with (Path(__file__).parent / 'source_reference.json').open('x', encoding='utf-8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print('Created context_final298.json with unchanged counts, outcomes and CLOSED authority; wrote read-only source reference.')
