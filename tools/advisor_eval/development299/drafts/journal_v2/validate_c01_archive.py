"""Read-only C01 serialization roundtrip through the draft archive and reader.

Four synthetic log envelopes per preserved public snapshot; no source or policy
execution and no claim these envelopes were actual player journal events.
"""
import hashlib
import io
import json
from pathlib import Path

from test_archive import HERE, ROOT, Lua, LuaBytes, Reader


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    run = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C01'
    record = json.loads((run / 'record.json').read_text())
    assert digest(run / 'trace.log') == record['trace_sha256']
    lua = Lua()
    snapshots = 0
    try:
        lua.evaluate("w=archive();seq=0;return 'ready'")
        with (run / 'trace.log').open(encoding='utf-8') as stream:
            for line in stream:
                if not line.startswith('{'):
                    continue
                row = json.loads(line)
                if row.get('type') != 'engine_episode_decision':
                    continue
                snapshots += 1
                lua.evaluate(b's=J.public_snapshot(' + LuaBytes.lua_value(row['snapshot']) + b');'
                             b"for repeat_index=1,4 do seq=seq+1;assert(emit(w,seq,s,'Envelope '..repeat_index))end;return 'recorded'")
        assert snapshots == 225
        result = json.loads(lua.evaluate("return assert(J.encode({events=w.events,physical_bytes=w.physical_bytes,segments=w.segment}))"))
        lua.evaluate('return dump()')
        segments = sorted((k, v) for k, v in lua.outputs.items() if k.endswith('.brj'))
        recovered = 0
        raw_total = 0
        for _, bytes_ in segments:
            for raw, metadata in Reader.records(io.BytesIO(bytes_)):
                assert raw == lua.outputs['original:' + str(metadata['sequence'])]
                recovered += 1
                raw_total += len(raw)
        assert recovered == result['events'] == 900
        assert raw_total > 33554432 and result['physical_bytes'] < 8388608
        report = {'schema': 1, 'kind': 'preserved_C01_archive_serialization_roundtrip',
                  'source_executed': False, 'policy_decisions_executed': 0, 'actual_player_journal': False,
                  'snapshots': snapshots, 'synthetic_envelopes_per_snapshot': 4,
                  'exact_original_events_recovered': recovered, 'original_jsonl_bytes': raw_total, **result,
                  'trace_sha256': record['trace_sha256'],
                  'files': {name: digest(HERE / name) for name in ('player_journal.lua', 'player_log_archive.lua',
                                                                 'read_player_log.py', 'test_archive.py', 'validate_c01_archive.py')},
                  'scope': 'Actual draft public redaction/serialization/archive plus Python zlib and fake filesystem. No game/RNG/policy step or player files.',
                  'limits': 'Selected synthetic C01 size evidence only; no live LOVE codec timing or future-player storage forecast.'}
        with (HERE / 'c01_roundtrip_report.json').open('x', encoding='utf-8') as out:
            json.dump(report, out, indent=2)
            out.write('\n')
        print(json.dumps(report, indent=2))
    finally:
        lua.close()


if __name__ == '__main__':
    main()
