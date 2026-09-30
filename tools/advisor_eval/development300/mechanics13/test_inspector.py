"""Synthetic ZIP only; no actual executable, Lua, native search or profile access."""
from pathlib import Path
import ast
import importlib.util
import json
import sys
import zipfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('source_lexer', HERE.parent/'mechanics11'/'inspect_source.py')
lexer = importlib.util.module_from_spec(spec); sys.modules['source_lexer'] = lexer; spec.loader.exec_module(lexer)
from inspect_source import inspect, MEMBERS, sha


def main():
    checks = 0
    def check(value):
        nonlocal checks
        checks += 1; assert value
    for name in ('inspect_source.py', 'register.py', 'test_inspector.py'):
        ast.parse((HERE/name).read_text(encoding='utf-8')); checks += 1
    body = b'function Controller:init()\r\n self.locks={}\r\n self.locked=false\r\nend\r\nfunction Controller:update(dt)\r\n self.locks.frame_set=nil\r\n self.locks.frame=false\r\nend\r\n'
    archive = HERE/'synthetic_source.zip'
    with zipfile.ZipFile(archive, 'x') as z:
        for name in MEMBERS:
            content = body if name == 'engine/controller.lua' else b'-- synthetic only\nG.SAVING={}\nG.LOADING=false\nG.STATE_COMPLETE=true\n'
            z.writestr(name, content)
    result = inspect(archive, HERE/'synthetic_inspection')
    check(result['job'] == 'M13' and result['status'] == 'complete')
    check(result['members']['engine/controller.lua']['sha256'] == sha(body))
    init = next(row for row in result['methods'] if row['name'] == 'controller_init')
    check(init['status'] == 'found' and init['truncated'] is False)
    check((HERE/'synthetic_inspection'/init['excerpt_file']).read_bytes().startswith(b'function Controller:init()\r\n'))
    rows = [row for row in result['neighborhoods'] if row['name'] == 'saving_loading' and row['matches']]
    check(len(rows) == 6 and all(row['matches'] == 2 for row in rows))
    check(result['combined_output_bytes'] < 280000)
    check(all(not row['truncated'] for row in result['neighborhoods']))
    with (HERE/'synthetic_fixture_report.json').open('x', encoding='utf-8') as stream:
        json.dump({'schema': 1, 'checks': checks, 'passed': True, 'source_archive': 'Synthetic ZIP only',
            'original_source_access': False, 'source_execution': False, 'registration': False}, stream, indent=2); stream.write('\n')
    print(f'M13 synthetic inspection checks: {checks} passed; no original source access.')


if __name__ == '__main__':
    main()
