"""Read-only shape audit of preserved synthetic C04 observations; no policy run."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
TRACE = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C04/trace.log'


def metrics(value):
    stack = [(value, 0)]
    nodes = depth = longest = text = tables = 0
    while stack:
        item, level = stack.pop()
        nodes += 1
        depth = max(depth, level)
        if isinstance(item, (dict, list)):
            tables += 1
            if isinstance(item, dict):
                for key, child in item.items():
                    longest = max(longest, len(key.encode()))
                    text += len(key.encode())
                    stack.append((child, level + 1))
            else:
                stack.extend((child, level + 1) for child in item)
        elif isinstance(item, str):
            longest = max(longest, len(item.encode()))
            text += len(item.encode())
    return dict(nodes=nodes, depth=depth, max_string_bytes=longest,
                total_string_bytes=text, tables=tables)


def main():
    maxima, rows = {}, []
    for line in TRACE.open(encoding='utf-8'):
        if not line.startswith('{'):
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if record.get('type') != 'engine_episode_decision':
            continue
        snapshot = record['snapshot']
        row = metrics(snapshot)
        row.update({key: len(snapshot.get(key, [])) for key in
                    ('playing_cards', 'deck', 'consumeables', 'hand')})
        row.update(step=record['step'], phase=snapshot.get('phase'))
        rows.append(row)
        for key, value in row.items():
            if key not in ('step', 'phase') and (key not in maxima or value > maxima[key]['value']):
                maxima[key] = dict(value=value, step=row['step'], phase=row['phase'])
    result = dict(schema=1, kind='read_only_C04_input_shape_audit',
                  observed_at_utc=datetime.now(timezone.utc).isoformat(),
                  source_trace=str(TRACE.relative_to(ROOT)),
                  source_sha256=hashlib.sha256(TRACE.read_bytes()).hexdigest(),
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  completed_observations=len(rows), maxima=maxima,
                  largest_hand_observations=sorted((r for r in rows if r['phase']=='hand'),
                                                  key=lambda r: -r['nodes'])[:3],
                  interpretation='Shape counts only, not policy replay, timing, feasibility or a terminal result.',
                  limits='C04 selected synthetic development; completed decisions before preserved timeout; new312 metadata can differ.',
                  source_execution=False, scoring=False, captured_decision_evaluation=False)
    with (HERE / 'C04_INPUT_SIZE_REVIEW.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({'observations': len(rows), 'maxima': maxima}))


if __name__ == '__main__':
    main()
