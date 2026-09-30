"""Create detached integration draft; never mutate the actual runtime."""
from pathlib import Path
import hashlib, json

ROOT=Path(__file__).resolve().parents[5]
HERE=Path(__file__).resolve().parent
base=ROOT/'Brainstorm/Advisor/gold_goal.lua'
source=base.read_text(encoding='utf-8')
def replace(old,new):
    global source
    assert source.count(old)==1, old
    source=source.replace(old,new)
replace('local function stable_card(card)', 'local function stable_card(card,perkeo)')
replace('not card or not stable[card.key] or type(a)',
        "not card or not (stable[card.key] or perkeo and perkeo.accepts_card(card)) or type(a)")
replace('local function progress(state,goal)', 'local function progress(state,goal,perkeo)')
replace('if not stable_card(card) or ids', 'if not stable_card(card,perkeo) or ids')
replace('  local count=progress(snapshot,g)', '''  local perkeo=modules.gold_perkeo
  local function exit_projection(state)
    if perkeo and perkeo.project then return perkeo.project(state) end
    for _,card in ipairs(state.jokers or {}) do if card.key=='j_perkeo' then
      return nil,'Exact Perkeo shop-exit projection is unavailable.'
    end end
    return state
  end
  local original_exit,exit_reason=exit_projection(snapshot)
  if not original_exit then return no(exit_reason) end
  local count=progress(snapshot,g,perkeo)''')
replace('not c or not stable_card(c) then', 'not c or not stable_card(c,perkeo) then')
replace('    local carried,keys=progress(state,g)', '''    local after_exit,exit_receipt=exit_projection(state)
    if not after_exit then return nil,exit_receipt end
    state=after_exit
    local carried,keys=progress(state,g,perkeo)''')
replace('key=signature(actions),carried=carried,keys=keys}',
        'key=signature(actions),carried=carried,keys=keys,shop_exit=exit_receipt}')
replace("api.kind(c)=='joker' and stable_card(c)", "api.kind(c)=='joker' and stable_card(c,perkeo)")
replace('missing_keys=copy(p.keys),cash_after=p.state.dollars,projection_only=true',
        'missing_keys=copy(p.keys),cash_after=p.state.dollars,shop_exit=copy(p.shop_exit),projection_only=true')
replace('cash_after=p.state.dollars,jokers=copy(p.state.jokers),inventory=copy(p.state.consumeables),',
        'cash_after=p.state.dollars,jokers=copy(p.state.jokers),inventory=copy(p.state.consumeables),shop_exit=copy(p.shop_exit),')
with (HERE/'gold_goal.lua').open('x',encoding='utf-8',newline='\n') as f:f.write(source)
with (HERE/'base.json').open('x',encoding='utf-8') as f:
    json.dump({'file':str(base.relative_to(ROOT)).replace('\\','/'),
               'sha256':hashlib.sha256(base.read_bytes()).hexdigest()},f,indent=2)
