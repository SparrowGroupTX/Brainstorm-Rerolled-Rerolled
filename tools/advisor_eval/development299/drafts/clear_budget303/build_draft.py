"""Create detached303 draft files only; no runtime edits or experiment execution."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sources = {}


def read(name):
    path = ROOT / 'Brainstorm/Advisor' / name
    raw = path.read_bytes()
    sources[str(path.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
    return raw.decode().replace('\r\n', '\n')


def replace(text, before, after):
    assert text.count(before) == 1, before
    return text.replace(before, after)


def create(name, text):
    with (HERE / name).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(text)


search = read('search.lua')
search = replace(search, 'local function conserve()', 'local function conserve(search_path)')
search = replace(search, 'conservation_evaluations=evaluations-start,clear_found_at=start}',
                 "conservation_evaluations=evaluations-start,clear_found_at=start,search_path=search_path,\n        aggregate_limit=search_path=='shortlist' and 70 or 140000}")
assert search.count('return conserve()') == 2
search = search.replace('return conserve()', "return conserve('shortlist')", 1)
search = search.replace('return conserve()', "return conserve('enumeration')", 1)
search = replace(search, 'if fast_diagnostics then result.fast_clear=fast_diagnostics end',
                 """if fast_diagnostics then
      -- A reliable clear can also stop later enumeration. Only the initial
      -- shortlist has the seventy-score whole-decision fast-clear contract.
      if fast_diagnostics.search_path=='shortlist' then result.fast_clear=fast_diagnostics
      else result.clear_shortcut=fast_diagnostics end
    end""")
create('search.lua', search)

decision = read('decision.lua')
decision = replace(decision, """  if result.fast_clear then
    result.fast_clear.development_limit=6
    result.fast_clear.growth_limit=12
    result.fast_clear.post_clear_limit=34""", """  local clear_shortcut=result.fast_clear or result.clear_shortcut
  if clear_shortcut then
    local ceiling=result.fast_clear and 70 or 140000
    local function available(limit)
      return math.min(limit,math.max(0,ceiling-(result.evaluations or 0)))
    end
    clear_shortcut.development_limit=6
    clear_shortcut.growth_limit=12
    clear_shortcut.post_clear_limit=34
    clear_shortcut.aggregate_limit=ceiling""")
decision = replace(decision, 'max_development_evaluations=6,arm_cost=modules.search.arm_cost',
                    'max_development_evaluations=available(6),arm_cost=modules.search.arm_cost')
decision = replace(decision, 'result.play,{max_evaluations=12})',
                    'result.play,{max_evaluations=available(12)})')
decision = replace(decision, 'result.fast_clear.specialists_skipped=true',
                    'clear_shortcut.specialists_skipped=true')
create('decision.lua', decision)

retry = read('retry_policy.lua')
retry = replace(retry, 'not plain_hand(s) or r.truncated or r.fast_clear then',
                'not plain_hand(s) or r.truncated or r.fast_clear or r.clear_shortcut then')
create('retry_policy.lua', retry)

phase = read('phase_copy.lua')
phase = replace(phase, '  local ceiling=result.fast_clear and 70 or s.phase',
                "  -- Later enumeration clears carry clear_shortcut, and retain the ordinary\n  -- allowance; only the initial shortlist carries the fast_clear contract.\n  local ceiling=result.fast_clear and 70 or s.phase")
phase = replace(phase, '  updated.phase_copy_diagnostics=diagnostics',
                '  diagnostics.aggregate_limit=ceiling;diagnostics.remaining_before=remaining\n  updated.phase_copy_diagnostics=diagnostics')
create('phase_copy.lua', phase)

for name in ('advisor_fast_clear.lua', 'advisor_fast_clear_retention.lua', 'advisor_phase_copy.lua',
             'advisor_finish_integration.lua', 'advisor_retry_policy.lua'):
    text = (ROOT / 'tests' / name).read_text()
    for module in ('search', 'decision', 'retry_policy', 'phase_copy'):
        text = text.replace('Brainstorm/Advisor/' + module + '.lua',
                            'tools/advisor_eval/development299/drafts/clear_budget303/' + module + '.lua')
    if name == 'advisor_fast_clear.lua':
        text = replace(text, "r.fast_clear and r.evaluations<218,'fallback stops at first reliable clear'",
                        "r.clear_shortcut and not r.fast_clear and r.evaluations<218,'fallback is an ordinary clear shortcut'")
        text = replace(text, "r.fast_clear.conservation_evaluations<=16,'fallback conservation stays bounded'",
                        "r.clear_shortcut.conservation_evaluations<=16,'fallback conservation stays bounded'")
    if name == 'advisor_retry_policy.lua':
        text = replace(text, "{'fast clear budget',function(s,r) r.fast_clear={} end},",
                        "{'fast clear budget',function(s,r) r.fast_clear={} end},\n  {'later enumeration clear',function(s,r) r.clear_shortcut={} end},")
    create('regression_' + name, text)
create('integration_base_sha256.json', json.dumps(sources, indent=2) + '\n')
print('Created detached303 draft; shared runtime and tests unchanged.')
