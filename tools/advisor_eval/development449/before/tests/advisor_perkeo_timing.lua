-- Synthetic owned-copy timing regressions; no game or player profile access.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Economy=dofile('Brainstorm/Advisor/economy.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function joker(key,name)
  return {key=key,name=name,ability={name=name,set='Joker'},blueprint_compat=true,sell_cost=3}
end
local function state()
  return {phase='shop',ante=2,win_ante=8,dollars=3,bankrupt_at=0,consumeables={
      {key='c_hermit',name='The Hermit',cost=3,sell_cost=1,ability={set='Tarot',name='The Hermit',extra=20}}},
    consumable_limit=2,consumeable_buffer=0,jokers={joker('j_perkeo','Perkeo')},joker_limit=5,
    playing_cards={},hands={Pair={played=3,level=1,chips=10,mult=2}},modifiers={},
    shop_jokers={{key='j_joker',name='Joker',cost=5,ability={name='Joker',set='Joker',mult=4}}},
    shop_booster={},shop_vouchers={},reroll_cost=5}
end

do
  local s=state()
  local used=assert(Consumables.apply(s,1,{}))
  eq(used.dollars,6,'actual held Hermit doubles current dollars without paying its old price')
  local loss,reason,last=Strategy.preservation_cost(s,used,1)
  check(last and loss>0 and reason:find('Perkeo',1,true),
    'a previously purchased sole Hermit remains a useful Perkeo source at its old purchase price')
  local base=Strategy.advise(s)
  check(not Economy.suggest(s,Strategy,Consumables,base),
    'a visible unaudited purchase does not spend the sole copying source after double charging its old price')
  eq(s.consumeables[1].cost,3,'valuation preserves the captured shop price')
  local free=copy(s);free.consumeables[1].cost=0
  local _,paid_value=Strategy.inventory_value(s)
  local _,free_value=Strategy.inventory_value(free)
  eq(paid_value.future,free_value.future,'Perkeo copies have no acquisition cost regardless of original shop price')
  local in_hand=copy(s);in_hand.phase='hand'
  local _,hand_value=Strategy.inventory_value(in_hand)
  eq(paid_value.future,hand_value.future,'the same cash and owned pool have the same copy value in hand and shop')
  eq(paid_value.future,96,'two bounded copies each retain the existing $3 Hermit utility')

  local buying=state();buying.dollars=4;buying.consumeables[1].cost=9
  local offered=copy(buying.consumeables[1]);offered.cost=2
  local value=Strategy.shop_sequence_api.card_value(buying,offered)
  eq(value,38,'new purchase pays once and values every Hermit copy at the resulting $2 cash')
  eq(buying.dollars,4,'prospective inventory valuation does not spend the input cash')
  offered.cost=4
  eq(Strategy.shop_sequence_api.card_value(buying,offered),0,
    'an offer exhausting current cash does not invent a Hermit payout')

  s.consumeables[2]=copy(s.consumeables[1]);s.consumeables[2].edition={negative=true};s.consumable_limit=3
  local result=Economy.suggest(s,Strategy,Consumables,Strategy.advise(s))
  check(result and result.action.kind=='use','surplus Hermit may finance the purchase while retaining a source')
  local after=assert(Consumables.apply(s,result.action.index,{}))
  eq(#after.consumeables,1,'exact funded endpoint retains one real consumable')
  local _,_,last_after=Strategy.preservation_cost(after,assert(Consumables.apply(after,1,{})),1)
  check(last_after,'retention is recomputed after the surplus use')

  s=state();s.jokers={joker('j_blueprint','Blueprint'),joker('j_perkeo','Perkeo'),joker('j_brainstorm','Brainstorm')}
  local _,copied=Strategy.inventory_value(s)
  eq(copied.effects,3,'ordered copied Perkeo effects remain included')
  eq(copied.future,192,'four-event cap remains unchanged for copied effects')
  s.jokers={joker('j_perkeo','Perkeo')};s.jokers[1].debuff=true
  check(Economy.suggest(s,Strategy,Consumables,Strategy.advise(s)),
    'inactive Perkeo does not force retaining a currently useful Hermit')
  s=state();s.phase='hand';s.ante=8;s.blind={boss=true,key='bl_final_vessel'}
  local _,final=Strategy.inventory_value(s)
  eq(final.events,0,'final-boss use receives no invented future shop copying premium')
end

do
  local s=state();s.consumeables={};s.shop_jokers={}
  local result=Strategy.advise(s,{tactical_consumables=true})
  eq(result.action.kind,'leave_shop','empty-pool guidance never fabricates a purchase or reroll')
  check(table.concat(result.lines,' '):find('Perkeo has nothing to copy',1,true),
    'empty pool is explained even when tactical consumable guidance is enabled')
  s.consumeables={{key='c_venus',edition={negative=true},ability={set='Planet'}}}
  result=Strategy.advise(s,{tactical_consumables=true})
  check(not table.concat(result.lines,' '):find('Perkeo has nothing to copy',1,true),
    'a Negative Planet is a real copy target, without needing an ordinary Tarot')
  s.consumeables={};s.jokers[1].debuff=true
  result=Strategy.advise(s,{tactical_consumables=true})
  check(not table.concat(result.lines,' '):find('Perkeo has nothing to copy',1,true),
    'inactive Perkeo does not issue an active shop-exit copying instruction')
end
print('advisor_perkeo_timing: '..checks..' checks passed')
