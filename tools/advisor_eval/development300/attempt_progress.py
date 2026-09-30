"""Read at most4MiB of an already registered trace. Progress is not an audit."""
from pathlib import Path
import argparse
import json

p = argparse.ArgumentParser()
p.add_argument('job', choices=['C07', 'C08'])
args = p.parse_args()
folder = Path(__file__).resolve().parents[1] / 'runs/gold299_20260914' / args.job
assert (folder / 'spent.json').is_file(), 'No active/spent job to observe'
path = folder / 'trace.log'
with path.open('rb') as stream:
    size = path.stat().st_size
    offset = max(0, size - 4 * 1024 * 1024)
    stream.seek(offset)
    if offset: stream.readline()
    data = stream.read(4 * 1024 * 1024)
latest = None
for line in data.splitlines(keepends=True):
    if not line.startswith(b'{') or not line.endswith(b'\n'): continue
    try: row = json.loads(line)
    except (UnicodeDecodeError, json.JSONDecodeError): continue
    if row.get('type') == 'engine_episode_decision_started':
        s = row.get('snapshot', {})
        latest = {'step': row.get('step'), **{k: s.get(k) for k in ('ante', 'round', 'phase', 'dollars')}}
print(json.dumps({'job': args.job, 'worker_record_exists': (folder / 'record.json').is_file(),
                  'last_observed_decision_start': latest, 'audited_outcome': False}))
