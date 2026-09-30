"""Preserve the first candidate, then add exact per-call nominal reuse."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
candidate = HERE / 'scoring.lua'
source = candidate.read_bytes()
assert hashlib.sha256(source).hexdigest() == '547b4977cf310be54cf35df3f955cc747f54ee3fad6231b4ac414da8586fa686'
for name in ('scoring.lua', 'test_scoring_reuse.lua', 'findings.md'):
    with (HERE / ('before_nominal_' + name)).open('xb') as stream:
        stream.write((HERE / name).read_bytes())
old = b"local function nominal(c) return num(c.nominal or (c.base or {}).nominal, rank(c) == 14 and 11 or min(rank(c), 10)) end"
new = (b"local function nominal(c)\r\n"
       b"    local value=c.nominal or (c.base or {}).nominal\r\n"
       b"    if type(value)=='number' then return value end\r\n"
       b"    local r=rank(c)\r\n"
       b"    return r == 14 and 11 or min(r, 10)\r\n"
       b"end")
assert source.count(old) == 1
source = source.replace(old, new)
candidate.write_bytes(source)
record = {'prior_candidate_sha256': '547b4977cf310be54cf35df3f955cc747f54ee3fad6231b4ac414da8586fa686',
          'candidate_sha256': hashlib.sha256(source).hexdigest(),
          'change': 'Return explicit numeric nominal immediately; otherwise resolve rank once per call.'}
with (HERE / 'nominal_extension.json').open('x', encoding='utf-8') as stream:
    json.dump(record, stream, indent=2)
    stream.write('\n')
print(json.dumps(record, indent=2))
