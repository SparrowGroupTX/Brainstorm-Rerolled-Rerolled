local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local copy=dofile('Brainstorm/Advisor/snapshot.lua').copy
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,seal,gold)
  return {id=id,rank=2,suit='Spades',seal=seal,enhancement=gold and 'm_gold' or 'c_base',
    ability={set='Enhanced',name=gold and 'Gold Card' or 'Default Base',h_dollars=gold and 3 or 0,h_mult=0,h_x_mult=0}}
end
local function joker(n,extra)
  return {name=n,ability={name=n,set='Joker',extra=extra,h_mult=0,h_x_mult=0}}
end
local function state()
  return {hand={card('played'),card('gold',nil,true),card('blue','Blue')},deck={},jokers={},
    consumeables={},consumable_limit=2,dollars=4,ante=1,blind={},hands_left=3,
    discards_left=2,modifiers={},hands={}}
end
local noop=function() end
Event=function(e) return e end
localize=function() return 'test' end
card_eval_status_text=noop;delay=noop;ease_background_colour_blind=noop;check_for_unlock=noop
Card.juice_up=noop;Card.add_to_deck=noop;Card.remove_from_deck=noop
local queue,rows={},{}
local function flush()
  local i=1;while queue[i] do assert(i<1000,'bounded events');queue[i].func();i=i+1 end
  queue={}
end
ease_dollars=function(n) G.GAME.dollars=G.GAME.dollars+n end
add_round_eval_row=function(row) rows[row.name]=row.dollars end
create_card=function(set,area,_,__,___,____,key)
  return setmetatable({key=key,ability={set=set}},{__index=Card})
end
local function parity(s,selected,category,score_dollars,label)
  cases=cases+1
  local p=Rewards.prepare(s)
  local _,expected=Rewards.value(s,{indices=selected,hand=category,expected_dollars=score_dollars},p)
  queue={};rows={}
  G={C={BLUE={},RED={},FILTER={},SECONDARY_SET={Planet={}}},FUNCS={evaluate_round=G.FUNCS.evaluate_round},STATES={ROUND_EVAL=1},
    GAME={dollars=s.dollars,current_round={hands_left=s.hands_left-1,discards_left=s.discards_left,discards_used=1},
      modifiers=copy(s.modifiers),interest_amount=s.interest_amount or 1,interest_cap=s.interest_cap or 25,
      consumeable_buffer=s.consumeable_buffer or 0,last_hand_played=category,rental_rate=s.rental_rate or 3,
      chips=100,blind={chips=1,dollars=3,defeat=noop},challenge=true,tags={},selected_back={trigger_effect=noop}},
    E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},jokers={cards=copy(s.jokers)},
    hand={cards={}},consumeables={cards=copy(s.consumeables),config={card_limit=s.consumable_limit}},
    P_CENTER_POOLS={Planet={{key='c_pluto',config={hand_type='High Card'}},{key='c_mercury',config={hand_type='Pair'}}}}}
  G.consumeables.emplace=function(self,c) self.cards[#self.cards+1]=c end
  local chosen={};for _,i in ipairs(selected) do chosen[i]=true end
  for i,c in ipairs(copy(s.hand)) do if not chosen[i] then
    setmetatable(c,{__index=Card});G.hand.cards[#G.hand.cards+1]=c
  end end
  for _,j in ipairs(G.jokers.cards) do j.area=G.jokers;setmetatable(j,{__index=Card});j:calculate_rental();j:calculate_perishable() end
  local baseline=G.GAME.dollars
  G.FUNCS.evaluate_round();local initial_interest=rows.interest or 0
  rows={};queue={}
  ease_dollars(score_dollars)
  local before=G.GAME.dollars
  source_held_rewards()
  eq(G.GAME.dollars-before,expected.held_dollars,label..' held dollars before events')
  local initial_count=#G.consumeables.cards
  flush()
  eq(#G.consumeables.cards-initial_count,expected.blue_planets,label..' Planet count')
  for i=initial_count+1,#G.consumeables.cards do
    eq(G.consumeables.cards[i].key,category=='Pair' and 'c_mercury' or 'c_pluto',label..' final hand Planet '..i)
  end
  G.FUNCS.evaluate_round()
  eq((rows.interest or 0)-initial_interest,expected.marginal_interest,label..' marginal source interest')
  eq(rows.hands or 0,expected.hand_dollars,label..' unused hands payout')
  eq(rows.discards or 0,expected.discard_dollars,label..' unused discards payout')
  eq(G.GAME.dollars,baseline+score_dollars+expected.held_dollars,label..' cashout awards do not enter current interest')
end
local s=state();parity(s,{1},'High Card',0,'base Gold Blue')
parity(s,{2},'Pair',6,'play Gold score dollars once')
parity(s,{3},'High Card',0,'play Blue')
s.hand[2].seal='Red';parity(s,{1},'High Card',0,'Red Gold')
s.jokers={joker('Mime',1)};parity(s,{1},'Pair',3,'Mime Red Gold and Blue')
s.jokers={joker('Blueprint'),joker('Mime',2),joker('Brainstorm')};s.consumable_limit=8
parity(s,{1},'Pair',0,'two copied Mime chains')
s.jokers={joker('Mime',1),joker('Brainstorm')};parity(s,{1},'Pair',0,'Brainstorm left Mime')
s.jokers[1].debuff=true;parity(s,{1},'Pair',0,'debuffed copied Mime')
s.jokers={joker('Blueprint'),joker('Brainstorm')};parity(s,{1},'Pair',0,'copy cycle')
s.jokers={joker('Mime',1)};s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=1
parity(s,{1},'Pair',0,'perishable Mime expires before held rewards')
s.jokers[1].ability.perish_tally=2;parity(s,{1},'Pair',0,'perishable Mime retains one round')
s.jokers={joker('Blueprint'),joker('Mime',1)};s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=1
parity(s,{1},'Pair',0,'perishable copying Joker expires')
s=state();s.consumeables={{edition={negative=true}},{}};s.consumable_limit=3
parity(s,{1},'High Card',0,'Negative already contributes to actual slot limit')
s.consumeables[3]={};parity(s,{1},'Pair',0,'full inventory')
s=state();s.hand[4]=card('bluegold','Blue',true);s.jokers={joker('Mime',1)}
parity(s,{1},'Pair',0,'Blue fills slots before later Gold Blue')
s.hand[2],s.hand[4]=s.hand[4],s.hand[2];parity(s,{1},'Pair',0,'reordered Gold Blue triggers')
s.consumable_limit=9;s.consumeable_buffer=2;parity(s,{1},'Pair',0,'reserved capacity')
s.hand[2].debuff=true;s.hand[3].debuff=true;parity(s,{1},'Pair',0,'debuffed held cards')
s=state();s.modifiers={no_extra_hand_money=true,no_interest=true,money_per_discard=2}
parity(s,{1},'Pair',10,'cash modifiers')
s.modifiers={money_per_hand=3,money_per_discard=2};s.hands_left=1;parity(s,{1},'Pair',0,'last hand')
s=state();s.dollars=6;s.jokers={joker('Mime',1)};s.jokers[1].ability.rental=true;s.rental_rate=5
parity(s,{1},'Pair',0,'rental before Gold and interest')
s.dollars=23;s.interest_amount=2;s.interest_cap=25;parity(s,{1},'Pair',20,'interest cap')
print('Finish reward source parity: '..cases..' cases / '..checks..' checks passed; held-card/cashout boundary only, no win-rate evidence')
