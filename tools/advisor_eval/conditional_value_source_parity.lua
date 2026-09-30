local Value=dofile(PROBE_MODULE)
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v)
  if type(v)~='table' then return v end
  local result={};for k,x in pairs(v) do result[k]=copy(x) end;return result
end
local noop=function() end
Event=function(e) return e end
localize=function() return 'test' end
card_eval_status_text=noop;Card.add_to_deck=noop;Card.remove_from_deck=noop
Card.set_cost=noop;Card.juice_up=noop
ease_dollars=function(n) G.GAME.dollars=G.GAME.dollars+n end
math.random=function() return 100 end -- source Stone ID is an arbitrary negative number
local names={j_golden='Golden Joker',j_rocket='Rocket',j_cloud_9='Cloud 9',
  j_satellite='Satellite',j_delayed_grat='Delayed Gratification',j_egg='Egg',j_gift='Gift Card'}
local function run(key,extra,changes)
  cases=cases+1;changes=changes or {}
  local c={key=key,cost=4,ability={set='Joker',name=names[key],extra=copy(extra),extra_value=0}}
  for k,v in pairs(changes.ability or {}) do c.ability[k]=v end
  c.debuff=changes.debuff
  local s={phase='shop',dollars=20,ante=2,win_ante=8,jokers={},consumeables={},
    next_blind={key=changes.boss and 'bl_plant' or 'bl_small',boss=changes.boss},
    playing_cards={{rank=9,base={id=9},ability={}},{rank=9,base={id=9},debuff=true,ability={}},
      {rank=9,base={id=9},enhancement='m_stone',ability={effect='Stone Card'}},{rank=8,base={id=8},ability={}}},
    consumeable_usage={a={set='Planet',count=8},b={set='Planet',count=1},c={set='Tarot',count=1}},
    round_resets={hands=1,discards=changes.discards or 3},modifiers={},rental_rate=changes.rental_rate or 3}
  local r={supported=true,status=changes.used and 'sampled_deficit' or 'sampled_safe',
    hands=1,discards=s.round_resets.discards}
  local predicted=Value.assess(s,c,{base_value=55,readiness=r})
  G={C={MONEY={},FILTER={}},GAME={dollars=s.dollars-4,rental_rate=s.rental_rate,blind={boss=changes.boss},
      current_round={discards_left=r.discards,discards_used=changes.used and 1 or 0},
      consumeable_usage=copy(s.consumeable_usage)},jokers={cards={}},consumeables={cards={}}}
  local original=copy(c);setmetatable(original,{__index=Card});original.area=G.jokers;G.jokers.cards={original}
  if key=='j_cloud_9' then
    original.ability.nine_tally=0
    for _,v in ipairs(s.playing_cards) do
      setmetatable(v,{__index=Card})
      if v:get_id()==9 then original.ability.nine_tally=original.ability.nine_tally+1 end
    end
  end
  local cash=G.GAME.dollars
  original:calculate_joker({end_of_round=true,game_over=false})
  original:calculate_rental();original:calculate_perishable()
  local actual=original:calculate_dollar_bonus() or 0
  eq(cash-G.GAME.dollars,predicted.rental,key..' rental timing')
  eq(actual,predicted.cash_end_round,key..' cashout payout')
  eq(actual-(cash-G.GAME.dollars),predicted.net_cash,key..' net cash')
  if key=='j_egg' or key=='j_gift' then eq(original.ability.extra_value,predicted.resale_growth,key..' resale before perish') end
end
for _,case in ipairs({{'j_golden',4},{'j_rocket',{dollars=2,increase=2}},
  {'j_cloud_9',1},{'j_satellite',2},{'j_delayed_grat',2}}) do
  run(case[1],case[2])
  run(case[1],case[2],{ability={perishable=true,perish_tally=1}})
  run(case[1],case[2],{ability={perishable=true,perish_tally=2,rental=true},rental_rate=4})
  run(case[1],case[2],{debuff=true,ability={rental=true}})
end
run('j_rocket',{dollars=2,increase=2},{boss=true})
run('j_delayed_grat',2,{used=true})
run('j_delayed_grat',2,{discards=0})
run('j_delayed_grat',2,{discards=6})
run('j_egg',3,{ability={perishable=true,perish_tally=1}})
run('j_gift',1,{ability={perishable=true,perish_tally=1}})
print('conditional source parity: '..cases..' cases, '..checks..' comparisons')
