local P=dofile('Brainstorm/Advisor/blind_prep.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
function Event(v) return v end
function HEX(v) return v end
function play_sound() end
function localize() return '' end
function card_eval_status_text() end
local checks=0
for scenario=1,8 do
  local row={
    {key='j_ceremonial',ability={name='Ceremonial Dagger',mult=3},sell_cost=5},
    {key='j_egg',ability={name='Egg'},sell_cost=7},
    {key='j_egg',ability={name='Egg'},sell_cost=10}}
  if scenario==2 then row[2].ability.eternal=true end
  if scenario==3 then row[1].debuff=true end
  if scenario==4 or scenario==5 then row[2].key='j_ceremonial';row[2].ability={name='Ceremonial Dagger',mult=2} end
  if scenario==5 then row[2].ability.eternal=true end
  if scenario==6 then row[2].edition={negative=true} end
  if scenario==7 then row={row[2],row[3],row[1]} end
  if scenario==8 then row[2].ability.eternal=true;row[3].key='j_ceremonial';row[3].ability={name='Ceremonial Dagger',mult=1} end
  local projected=P.project({jokers=row,joker_limit=5},{1,2,3})
  local events={};G={jokers={cards=copy(row)},GAME={joker_buffer=0},C={RED={}},E_MANAGER={}}
  function G.E_MANAGER:add_event(e) events[#events+1]=e end
  for _,c in ipairs(G.jokers.cards) do
    c.juice_up=function() end;c.start_dissolve=function(self) self.removed=true end
    if not c.debuff then source_dagger(c,{setting_blind=true}) end
  end
  for _,e in ipairs(events) do e.func() end
  local survivors={};for _,c in ipairs(G.jokers.cards) do if not c.removed then survivors[#survivors+1]=c end end
  assert(#survivors==#projected.jokers,'population case '..scenario);checks=checks+1
  for i,c in ipairs(survivors) do
    assert(c.key==projected.jokers[i].key,'survivor identity case '..scenario);checks=checks+1
    assert(c.ability.mult==projected.jokers[i].ability.mult,'growth case '..scenario);checks=checks+1
  end
end
print('dagger source parity: 8 scenarios / '..checks..' comparisons passed')
