local M=dofile(PROBE_ROOT..'/shop_sequences.lua')
local S=dofile(PROBE_ROOT..'/strategy.lua')
local C=dofile(PROBE_ROOT..'/consumables.lua')
local Shop=dofile(PROBE_ROOT..'/shop_scoring.lua')
local modules={strategy=S,consumables=C,shop_scoring=Shop}
local cases,checks=0,0
local function copy(v) if type(v)~='table' then return v end local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local noop=function() end
local funcs=G.FUNCS
Event=function(e)return e end
discover_card=noop;check_for_unlock=noop;play_sound=noop;inc_career_stat=noop;remove_nils=noop;ease_discard=noop
stop_use=noop;delay=noop;Card.juice_up=noop
Card.start_dissolve=function(self) self:remove_from_deck();self.area:remove_card(self) end
Card.is=function() return true end
find_joker=function(name)
  local found={};for _,j in ipairs(G.jokers.cards) do if not j.debuff and j.ability.name==name then found[#found+1]=j end end
  return found
end
ease_dollars=function(n) G.GAME.dollars=G.GAME.dollars+n end
local names={j_joker='Joker',j_popcorn='Popcorn',j_credit_card='Credit Card',j_to_the_moon='To the Moon',
  j_stuntman='Stuntman',j_astronomer='Astronomer',j_troubadour='Troubadour',c_mercury='Mercury'}
local function area(limit)
  return {cards={},config={card_limit=limit},emplace=function(self,c) self.cards[#self.cards+1]=c;c.area=self end,
    remove_card=function(self,c) for i,x in ipairs(self.cards) do if x==c then table.remove(self.cards,i);break end end;c.area=nil end}
end
local function card(key,cost,a,edition)
  a=copy(a or {});a.name=names[key];a.set=key=='c_mercury' and 'Planet' or 'Joker';a.h_size=a.h_size or 0;a.d_size=a.d_size or 0
  if key=='c_mercury' then a.consumeable={} end
  local c={key=key,ability=a,base_cost=cost,edition=copy(edition),children={},facing='front',
    config={center={key=key,name=names[key],set=a.set,discovered=true}},sort_id=key}
  setmetatable(c,{__index=Card});return c
end
local function run(key,cost,a,config)
  cases=cases+1;config=config or {}
  local queue={}
  G={FUNCS=funcs,SETTINGS={tutorial_complete=true},P_CENTERS={e_base={discovered=true},e_negative={discovered=true},e_foil={discovered=true}},
    GAME={dollars=20,bankrupt_at=0,interest_amount=1,discount_percent=config.discount or 0,inflation=config.inflation or 0,
      round_resets={hands=4,discards=3,ante=2},current_round={jokers_purchased=0},round_scores={cards_purchased={amt=0}},
      modifiers={inflation=config.inflate}},jokers=area(5),consumeables=area(2),shop_jokers=area(2),I={CARD={}},
    CONTROLLER={locks={},save_cardarea_focus=noop,recall_cardarea_focus=noop},C={GOLD={}},
    E_MANAGER={add_event=function(_,e)queue[#queue+1]=e end}}
  G.hand={config={card_limit=8},change_size=function(self,n) self.config.card_limit=self.config.card_limit+n end}
  local first=card(key,cost,a,config.edition)
  local second=card('c_mercury',3,{})
  if config.coupon then first.ability.couponed=true end
  G.shop_jokers:emplace(first);G.shop_jokers:emplace(second);G.I.CARD={first,second}
  first:set_cost();second:set_cost()
  local function snapshot(c)
    return {key=c.key,name=c.ability.name,cost=c.cost,base_cost=c.base_cost,sell_cost=c.sell_cost,ability=copy(c.ability),edition=copy(c.edition)}
  end
  local s={phase='shop',ante=2,dollars=20,bankrupt_at=0,interest_amount=1,joker_limit=5,consumable_limit=2,
    hand_size=8,round_resets=copy(G.GAME.round_resets),current_round={},modifiers=copy(G.GAME.modifiers),
    shop_forecast={discount_percent=G.GAME.discount_percent,inflation=G.GAME.inflation},
    jokers={},consumeables={},shop_jokers={snapshot(first),snapshot(second)}}
  local predicted,reason=M.transition(s,{kind='buy',area='shop_jokers',index=1},modules)
  assert(predicted,reason)
  funcs.buy_from_shop({config={ref_table=first}})
  local i=1;while i<=#queue do queue[i].func();i=i+1 end
  eq(predicted.dollars,G.GAME.dollars,key..' purchase cost before queued repricing')
  eq(predicted.bankrupt_at,G.GAME.bankrupt_at,key..' borrowing allowance')
  eq(predicted.interest_amount,G.GAME.interest_amount,key..' interest amount')
  eq(predicted.hand_size,G.hand.config.card_limit,key..' hand size')
  eq(predicted.round_resets.hands,G.GAME.round_resets.hands,key..' round hands')
  eq(predicted.round_resets.discards,G.GAME.round_resets.discards,key..' round discards')
  eq(predicted.joker_limit,G.jokers.config.card_limit,key..' Joker slots')
  eq(predicted.consumable_limit,G.consumeables.config.card_limit,key..' consumable slots')
  eq(predicted.shop_jokers[1].cost,second.cost,key..' remaining visible price')
  eq(predicted.shop_jokers[1].sell_cost,second.sell_cost,key..' remaining visible resale')
  local own=key=='c_mercury' and predicted.consumeables[1] or predicted.jokers[1]
  eq(own.cost,first.cost,key..' owned price after queue')
  eq(own.sell_cost,first.sell_cost,key..' owned resale after queue')
  if config.sell then
    local sold,why=M.transition(predicted,{kind='sell',area='jokers',index=1},modules)
    assert(sold,why)
    first:sell_card()
    while i<=#queue do queue[i].func();i=i+1 end
    eq(sold.dollars,G.GAME.dollars,key..' real sale proceeds')
    eq(sold.bankrupt_at,G.GAME.bankrupt_at,key..' removed borrowing allowance')
    eq(sold.interest_amount,G.GAME.interest_amount,key..' removed interest amount')
    eq(sold.hand_size,G.hand.config.card_limit,key..' sale hand size')
    eq(sold.round_resets.hands,G.GAME.round_resets.hands,key..' sale round hands')
    eq(sold.round_resets.discards,G.GAME.round_resets.discards,key..' sale round discards')
    eq(sold.joker_limit,G.jokers.config.card_limit,key..' sale Joker slots')
    eq(#sold.jokers,#G.jokers.cards,key..' actual retained population')
  end
end
run('j_joker',3,{mult=4})
run('j_joker',3,{mult=4},{inflate=true})
run('j_joker',3,{mult=4},{inflate=true,discount=25,inflation=2})
run('j_joker',3,{mult=4,rental=true},{inflate=true,discount=25})
run('j_joker',3,{mult=4},{inflate=true,coupon=true})
run('j_joker',3,{mult=4},{inflate=true,edition={negative=true,type='negative'}})
run('j_credit_card',1,{extra=20},{inflate=true})
run('j_to_the_moon',5,{extra=1},{inflate=true})
run('j_stuntman',7,{extra={h_size=2,chip_mod=250}})
run('j_troubadour',6,{extra={h_size=2,h_plays=-1}})
run('j_astronomer',8,{})
run('j_astronomer',8,{},{inflate=true})
run('c_mercury',3,{},{inflate=true,edition={negative=true,type='negative'}})
run('j_joker',3,{mult=4},{sell=true})
run('j_joker',3,{mult=4},{sell=true,edition={negative=true,type='negative'}})
run('j_joker',3,{mult=4,rental=true},{sell=true})
run('j_credit_card',1,{extra=20},{sell=true})
run('j_to_the_moon',5,{extra=1},{sell=true})
run('j_stuntman',7,{extra={h_size=2,chip_mod=250}},{sell=true})
run('j_troubadour',6,{extra={h_size=2,h_plays=-1}},{sell=true})
print('shop sequence source parity: '..cases..' cases, '..checks..' comparisons')
