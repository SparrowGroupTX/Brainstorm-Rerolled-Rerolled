"""Synthetic lexer/ZIP fixture only. Never opens the actual executable."""
from pathlib import Path
import ast
import hashlib
import json
import time
import zipfile
from inspect_source import excerpt, inspect, function_end

HERE = Path(__file__).resolve().parent
checks = 0

def check(value, message):
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)

def main():
    started = time.perf_counter()
    files = [HERE/'inspect_source.py', HERE/'register.py', HERE/'test_inspector.py', HERE/'inspection_spec.md']
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    for p in files:
        if p.suffix == '.py':
            ast.parse(p.read_text());check(True, 'Python syntax parses without execution')
    raw = b'''--[[
function Game:update_game_over() error("comment") end
]]
local inert=[=[
function Game:update_game_over() error("long string") end
]=]
function Game:update_game_over(dt)
  local s="end function"; local other='if end'
  -- end function
  if ready then
    for i=1,3 do
      while active do active=false end
    end
  elseif fallback then
    do local f=function()return "end"end end
  else
    repeat tick() until finished(function()return true end)
  end
end
function after()error("must not capture")end
'''
    found, body = excerpt(raw, r'function\s+Game:update_game_over\s*\(', 100)
    check(found['status'] == 'found' and not found['truncated'], 'one actual balanced method excludes comment and long-string declarations')
    check(b'must not capture' not in body and body.endswith(b'\nend'), 'method boundary excludes following declaration')
    check(found['full_method_sha256'] == hashlib.sha256(body).hexdigest(), 'full exact byte hash')
    check(found['start_line'] == 7 and found['end_line'] == 20, 'source line positions retained')
    truncated, short = excerpt(raw, r'function\s+Game:update_game_over\s*\(', 3)
    check(truncated['truncated'] and truncated['shown_lines'] == 3 and len(short.splitlines()) == 3, 'fixed excerpt line bound marks truncation')
    check(truncated['full_method_sha256'] == found['full_method_sha256'], 'truncated report retains full-method provenance')
    missing, body = excerpt(raw, r'function\s+missing\s*\(', 10)
    check(missing['status'] == 'not_found' and body == b'', 'missing method preserved')
    ambiguous, body = excerpt(b'function a()end\nfunction a()end', r'function\s+a\s*\(', 10)
    check(ambiguous['status'] == 'ambiguous' and not body, 'ambiguous method preserved')
    for broken in ['function a() if t then end', 'function a() repeat x() end end', 'function a() "broken']:
        try:
            function_end(broken, 0)
        except ValueError:
            check(True, 'unbalanced Lua rejected without execution')
        else:
            check(False, 'accepted malformed source')
    folder = HERE/'synthetic_fixture1';folder.mkdir(exist_ok=False)
    archive = folder/'synthetic_source.zip'
    callbacks = b'\n'.join(('G.FUNCS.'+name+' = function(e) if e then return e end end').encode()
                           for name in ['exit_overlay_menu', 'overlay_menu', 'start_run', 'go_to_menu'])
    with zipfile.ZipFile(archive, 'x') as z:
        z.writestr('game.lua', raw+b'\nself:update_game_over(dt)\n')
        z.writestr('functions/misc_functions.lua', 'function win_game() return "synthetic" end')
        z.writestr('functions/common_events.lua', '-- no match required here')
        z.writestr('functions/UI_definitions.lua', 'function create_UIBox_game_over() return {} end\nfunction create_UIBox_win()return {}end')
        z.writestr('functions/button_callbacks.lua', callbacks)
        z.writestr('private_save_do_not_read.txt', 'unread synthetic sentinel')
    report = inspect(archive, folder/'inspection')
    check(len(report['members']) == 5 and all(v['status'] == 'read' for v in report['members'].values()), 'exact five named synthetic ZIP members')
    check(len(report['methods']) == 8 and all(v['status'] == 'found' for v in report['methods']), 'all eight specified methods located')
    check(report['methods'][1]['source_member'] == 'functions/misc_functions.lua', 'win_game searches correct candidate member first')
    check(len(report['game_update_callsites']) == 1, 'bounded call-site neighborhood recorded')
    check(not (folder/'inspection/private_save_do_not_read.txt').exists(), 'unrelated ZIP entry is never extracted')
    check(all(hashlib.sha256((HERE/name).read_bytes()).hexdigest() == value for name, value in hashes.items()), 'fixture source inputs unchanged')
    result = {'schema': 1, 'status': 'passed', 'checks': checks, 'seconds': time.perf_counter()-started,
              'input_sha256': hashes, 'scope': 'Synthetic text and freshly generated ZIP only; no original source/game/player files or registration.'}
    with (HERE/'synthetic_fixture_report.json').open('x') as stream:
        json.dump(result, stream, indent=2);stream.write('\n')
    print(json.dumps(result))

if __name__ == '__main__':
    main()
