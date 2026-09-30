"""Create a new release's immutable view of the already closed diagnostic cycle."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
CYCLE = ROOT / 'tools/advisor_eval/runs/diagnostic287_20260913_222344'
version = int(sys.argv[1])
if version not in (290, 291):
    raise ValueError('This document helper covers only these two planned follow-up slices')
value = json.loads((CYCLE / 'context_final289.json').read_text())
assert value['status'] == 'CLOSED' and value['unused_capacity'] == 'closed'
value['summary'] = ('The fresh diagnostic cycle is complete and closed, with all four selected complete attempts lost. '
    'Slices287,288 and289 were tested and installed separately; the two candidate attempts used identical frozen289 bytes. '
    'Follow-up290 adds the ordinary owned-Fool shop copy/hold/use comparison. '
    + ('Follow-up291 adds an unchanged-inventory free-play counterpart to the owned-use first-action family. ' if version == 291 else '')
    + 'Follow-up runtime slices have routine synthetic and full regression evidence only, with no additional source component, captured replay, search or complete-attempt execution. No release inherits a terminal result from a different policy.')
with (CYCLE / ('context_final' + str(version) + '.json')).open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
print('Closed context written for', version)
