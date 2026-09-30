"""Validate manufactured compact diagnostics and existing journal behavior."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
iteration = sys.argv[1] if len(sys.argv) > 1 else '01'
assert iteration.isdigit()
fixture = HERE / 'tests/advisor_gold_journal.lua'
staged = HERE / 'Brainstorm/Advisor/player_journal.lua'
before = HERE / 'before/Brainstorm/Advisor/player_journal.lua'
compatibility = [ROOT / ('tests/' + name + '.lua') for name in (
    'advisor_player_journal', 'advisor_player_journal_timing', 'advisor_journal_reuse')]
paths = [fixture, staged, before, ROOT / 'Brainstorm/Advisor/snapshot.lua',
    ROOT / 'tests/run_lua_tests.py', *compatibility,
    ROOT / 'tests/fixtures/journal_reuse335/player_journal334.lua']
def hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
initial = hashes()
runs = []
for phase, module, fixtures in [('before', before, [fixture]), ('after', staged, [fixture, *compatibility])]:
    wrappers = []
    for index, test in enumerate(fixtures):
        wrapper = HERE / ('run_' + iteration + '_' + phase + '_' + str(index+1) + '.lua')
        text = "local original=dofile\ndofile=function(path)\n"
        text += " if path=='Brainstorm/Advisor/player_journal.lua' then return original('" + module.relative_to(ROOT).as_posix() + "') end\n"
        text += " return original(path)\nend\ndofile('" + test.relative_to(ROOT).as_posix() + "')\n"
        with wrapper.open('x', encoding='utf-8') as handle:
            handle.write(text)
        wrappers.append(wrapper)
    command = [sys.executable, 'tests/run_lua_tests.py', *[str(p.relative_to(ROOT)) for p in wrappers]]
    start = time.monotonic()
    try:
        proc = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0)
        result = {'exit_code': proc.returncode, 'stdout': proc.stdout, 'stderr': proc.stderr}
    except subprocess.TimeoutExpired as exc:
        result = {'exit_code': None, 'timeout': True, 'stdout': str(exc.stdout), 'stderr': str(exc.stderr)}
    result.update({'phase': phase, 'command': command, 'cap_seconds': 60,
        'seconds': time.monotonic()-start, 'expected_exit': 'nonzero manufactured diagnostic mismatch' if phase == 'before' else 'zero',
        'wrapper_hashes': {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in wrappers}})
    runs.append(result)
report = {'schema': 1, 'scope': 'Manufactured journal observations only. No real journal reads, captured evaluations, source component, search, terminal attempt or game control.',
    'input_hashes': initial, 'input_hashes_after': hashes(), 'inputs_unchanged': initial == hashes(), 'runs': runs,
    'passed': runs[0]['exit_code'] == 1 and runs[1]['exit_code'] == 0}
out = HERE / ('validation_' + iteration + '.json')
with out.open('x', encoding='utf-8') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
print(json.dumps(report))
