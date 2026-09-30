"""Read preserved C01 snapshots; run only public redaction/JSON serialization.

No game source, policy decision, RNG, save/profile, search, or episode executes.
The local Lua51 runtime only loads player_journal.lua to reproduce exact bytes.
"""
from collections import Counter
import ctypes
import hashlib
import importlib.util
import json
from pathlib import Path
import statistics
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUN = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C01'
JOURNAL = ROOT / 'Brainstorm/Advisor/player_journal.lua'
DLL = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def distribution(values):
    ordered = sorted(values)
    return dict(count=len(values), total=sum(values), minimum=min(values),
                median=statistics.median(values), p95=ordered[(95 * len(values) + 99) // 100 - 1], maximum=max(values))


class Serializer:
    def __init__(self):
        self.library = load('fixture_runtime', ROOT / 'tests/run_lua_tests.py').LuaLibrary(DLL).library
        self.library.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        self.library.luaL_loadstring.restype = ctypes.c_int
        self.library.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.library.lua_settop.restype = None
        self.state = self.library.luaL_newstate()
        self.library.luaL_openlibs(self.state)
        self.evaluate(b"J=dofile('Brainstorm/Advisor/player_journal.lua');return 'ready'")

    def evaluate(self, code):
        status = self.library.luaL_loadstring(self.state, code)
        if status == 0:
            status = self.library.lua_pcall(self.state, 0, 1, 0)
        length = ctypes.c_size_t()
        ptr = self.library.lua_tolstring(self.state, -1, ctypes.byref(length))
        value = ctypes.string_at(ptr, length.value) if ptr else b''
        self.library.lua_settop(self.state, 0)
        if status:
            raise RuntimeError(value.decode('utf-8', 'replace'))
        return value

    def close(self):
        self.library.lua_close(self.state)


def main():
    lua = load('exact_lua_bytes', HERE.parents[0] / 'shop_order/lua_bytes.py')
    record = json.loads((RUN / 'record.json').read_text())
    trace = RUN / 'trace.log'
    assert digest(trace.read_bytes()) == record['trace_sha256']
    decisions = []
    terminal = None
    with trace.open(encoding='utf-8') as stream:
        for line in stream:
            if line.startswith('{'):
                row = json.loads(line)
                if row.get('type') == 'engine_episode_decision':
                    decisions.append(row)
                elif row.get('type') == 'engine_episode_terminal_context':
                    terminal = row['snapshot']
    assert len(decisions) == 225 and [x['step'] for x in decisions] == list(range(1, 226)) and terminal
    payloads = []
    per_step = []
    serializer = Serializer()
    try:
        for row in decisions:
            raw = serializer.evaluate(b'return assert(J.encode(J.public_snapshot(' + lua.lua_value(row['snapshot']) + b')))')
            zipped = zlib.compress(raw, level=6)
            assert zlib.decompress(zipped) == raw
            payloads.append(raw)
            per_step.append(dict(step=row['step'], phase=row['snapshot']['phase'], public_json_bytes=len(raw),
                                 independent_zlib6_bytes=len(zipped), public_json_sha256=digest(raw)))
        terminal_bytes = serializer.evaluate(b'return assert(J.encode(J.public_snapshot(' + lua.lua_value(terminal) + b')))')
    finally:
        serializer.close()
    # These are explicit serialization scenarios, not captured live journal events.
    # The pair at action entry is the current facade's action_attempt and existing
    # advisor action_requested. The fuller model adds both settled-state records
    # except final action_observed, which terminal handling supersedes.
    entry_pair = [value for raw in payloads for value in (raw, raw)]
    settled_model = []
    for index, raw in enumerate(payloads):
        settled_model += [raw, raw]
        after = payloads[index + 1] if index + 1 < len(payloads) else terminal_bytes
        settled_model.append(after)
        if index + 1 < len(payloads):
            settled_model.append(after)
    def scenario(values):
        total = 0
        first_overflow = None
        for index, value in enumerate(values, 1):
            total += len(value)
            if total > 33554432 and first_overflow is None:
                first_overflow = index
        return dict(public_snapshot_records=len(values), public_snapshot_bytes=total,
                    first_snapshot_record_exceeding_32MiB=first_overflow,
                    independent_zlib6_payload_bytes=sum(len(zlib.compress(x, 6)) for x in values),
                    whole_stream_zlib6_bytes=len(zlib.compress(b''.join(values), 6)),
                    unique_snapshot_count=len(set(values)),
                    unique_snapshot_zlib6_payload_bytes=sum(len(zlib.compress(x, 6)) for x in set(values)))
    report = dict(schema=1, kind='preserved_C01_public_serialization_only', qualification=False,
                  original_source_executed=False, policy_decisions_executed=0, actual_player_journal=False,
                  trace_sha256=record['trace_sha256'], journal_sha256=digest(JOURNAL.read_bytes()),
                  lua_runtime_sha256=digest(DLL.read_bytes()), serializer_sha256=digest(Path(__file__).read_bytes()),
                  source_policy_digest=json.loads((RUN / 'audit.json').read_text())['policy_digest'],
                  missing_gold_context='C01 disabled; no synthetic Gold context added to these preserved snapshots',
                  snapshots=distribution([len(x) for x in payloads]),
                  independent_compressed_snapshots=distribution([len(zlib.compress(x, 6)) for x in payloads]),
                  compression='Python zlib level6 lossless byte roundtrip; size experiment only, not product performance',
                  terminal_public_snapshot_bytes=len(terminal_bytes),
                  action_entry_pair_only=scenario(entry_pair),
                  two_settled_records_model=scenario(settled_model),
                  event_count_model={'action_attempt': 225, 'action_requested': 225,
                                     'action_callback_result': 225, 'state_after_actions': 225,
                                     'action_observed_before_next_action': 224,
                                     'action_related_total': 1124,
                                     'excluded': 'startup/search/terminal/overlay/manual events; actual timing may merge settled observations'},
                  limitations=['Snapshot bytes omit envelope, advice, action details and timestamp overhead.',
                               'C01 source snapshots are not an actual player journal or timing trace of its callbacks.',
                               'Settled model reuses the next preserved decision snapshot as a declared proxy.',
                               'Compression and dedup size arithmetic does not prove live throughput or future session storage.',
                               'No source or experiment lease was consumed or renewed.'], per_step=per_step)
    with (HERE / 'report.json').open('x', encoding='utf-8') as out:
        json.dump(report, out, indent=2)
        out.write('\n')
    print(json.dumps({k: report[k] for k in ('snapshots', 'independent_compressed_snapshots',
                                           'action_entry_pair_only', 'two_settled_records_model', 'event_count_model')}, indent=2))


if __name__ == '__main__':
    main()
