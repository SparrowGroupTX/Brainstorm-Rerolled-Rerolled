"""Prepare a detached blocked-observation candidate; never stage or evaluate it."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
source = ROOT / 'Brainstorm/Core/auto_run_product.lua'
raw = source.read_bytes()
text = raw.decode('utf-8')
old = '''    local snapshot=A.snapshot.capture(g)
    local fingerprint=snapshot and A.snapshot.fingerprint(snapshot)
    local action=result and result.action
    local action_key=action and A.snapshot.fingerprint(action)
'''
new = '''    local ready=not busy(g,overlay~=nil) and (ended~=nil or not A.worker and not A.execution_key)
    local searching=search_busy()
    -- A blocked observation cannot dispatch or acknowledge an action. Keep
    -- terminal, profile, generation, goal and watchdog checks fresh, but build
    -- public action data only when those existing readiness gates permit it.
    -- Never reuse a snapshot or token from a prior frame; matches() still
    -- recaptures the live state separately at both exact execution gates.
    local action=result and result.action
    -- A ready unsupported endpoint can still acknowledge the prior action.
    -- Its fresh fingerprint must survive even when no next action is offered.
    local snapshot_needed=ready and not searching and not ended
    local action_ready=snapshot_needed and action~=nil
    local snapshot=snapshot_needed and A.snapshot.capture(g) or nil
    local fingerprint=snapshot and A.snapshot.fingerprint(snapshot)
    local action_key=action_ready and A.snapshot.fingerprint(action) or nil
'''
assert text.count(old) == 1
text = text.replace(old, new)
text = text.replace('    if result and action and (not advice_token', '    if action_ready and (not advice_token', 1)
text = text.replace('advice_fingerprint=A.published_key,action_token=action and advice_token and advice_token.id,',
                    'advice_fingerprint=A.published_key,action_token=action_ready and advice_token and advice_token.id,', 1)
text = text.replace("action=copy(action),advice={title=A.display and A.display.title,lines=copy(A.lines)},\n      ready=not busy(g,overlay~=nil) and (ended~=nil or not A.worker and not A.execution_key),",
                    "action=action_ready and copy(action) or nil,\n      advice=action_ready and {title=A.display and A.display.title,lines=copy(A.lines)} or nil,\n      ready=ready,", 1)
text = text.replace('search_busy=search_busy(),', 'search_busy=searching,', 1)
assert text != raw.decode('utf-8')
(HERE / 'base').mkdir(exist_ok=True)
(HERE / 'base/auto_run_product.lua').write_bytes(raw)
(HERE / 'auto_run_product.lua').write_text(text, encoding='utf-8', newline='\n')
original_fixture = (ROOT / 'tests/advisor_auto_run_product.lua').read_text(encoding='utf-8')
prefix = original_fixture.split('\ndo\n  local x=fixture();x.api:update();')[0]
assert prefix.rstrip().endswith('end')
(HERE / 'fixture_prefix.lua').write_text(prefix, encoding='utf-8', newline='\n')
(HERE / 'advisor_auto_observation.lua').write_text(prefix + '\n' +
    (HERE / 'focused_cases.lua').read_text(encoding='utf-8'), encoding='utf-8', newline='\n')
(HERE / 'detached_test.lua').write_text("""local original=dofile
dofile=function(path)
  if path=='Brainstorm/Core/auto_run_product.lua' then
    return original('tools/advisor_eval/development323/auto_observation/auto_run_product.lua')
  end
  return original(path)
end
original('tools/advisor_eval/development323/auto_observation/advisor_auto_observation.lua')
""", encoding='utf-8', newline='\n')
(HERE / 'existing_fixtures.lua').write_text("""local original=dofile
dofile=function(path)
  if path=='Brainstorm/Core/auto_run_product.lua' then
    return original('tools/advisor_eval/development323/auto_observation/auto_run_product.lua')
  end
  return original(path)
end
original('tests/advisor_auto_run_product.lua')
original('tests/advisor_auto_run.lua')
""", encoding='utf-8', newline='\n')
files = ['Brainstorm/Core/auto_run_product.lua', 'Brainstorm/Advisor/auto_run.lua',
         'Brainstorm/Core/auto_terminal.lua', 'Brainstorm/Advisor/snapshot.lua',
         'Brainstorm/Advisor/gold_stickers.lua', 'tests/advisor_auto_run_product.lua',
         'tests/advisor_auto_run.lua', 'tests/run_lua_tests.py']
(HERE / 'base_manifest.json').write_text(json.dumps({
    'schema': 1, 'scope': 'detached manufactured fixture development only; no experiment',
    'files': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files},
}, indent=2) + '\n', encoding='utf-8')
