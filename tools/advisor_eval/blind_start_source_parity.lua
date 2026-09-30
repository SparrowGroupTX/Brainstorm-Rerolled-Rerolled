local Start=dofile(PROBE_MODULE)
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local names={j_ceremonial='Ceremonial Dagger',j_marble='Marble Joker',j_burglar='Burglar',
  j_blueprint='Blueprint',j_brainstorm='Brainstorm',j_hologram='Hologram',j_joker='Joker',
  j_oops='Oops! All 6s',j_troubadour='Troubadour',j_stuntman='Stuntman',j_merry_andy='Merry Andy',
  j_turtle_bean='Turtle Bean',j_credit_card='Credit Card',j_to_the_moon='To the Moon',j_chaos='Chaos the Clown'}
local function joker(k,a,other)
  local c={key=k,ability={set='Joker',name=names[k],h_size=0,d_size=0},sell_cost=5}
  for n,v in pairs(a or {}) do c.ability[n]=v end
  for n,v in pairs(other or {}) do c[n]=v end
  return c
end
local noop=function() end
Event=function(e) return e end
localize=function() return 'test' end
card_eval_status_text=noop;Card.juice_up=noop;play_sound=noop;calculate_reroll_cost=noop
HEX=function() return {} end
Card.start_materialize=noop
local queue,removals
Card.start_dissolve=function(self) removals[#removals+1]=self end
ease_discard=function(n) queue[#queue+1]={func=function() G.GAME.current_round.discards_left=math.max(0,G.GAME.current_round.discards_left+n);return true end} end
ease_hands_played=function(n) queue[#queue+1]={func=function() G.GAME.current_round.hands_left=G.GAME.current_round.hands_left+n;return true end} end
pseudoseed=function() return 'fixed-source-fixture' end
pseudorandom_element=function() return {id=7,suit='Hearts',nominal=7,value='7'} end
draw_card=noop -- only final complete owned population is compared, not source draw order
setmetatable(Card,{__call=function(_,x,y,w,h,front,center)
  return setmetatable({base=copy(front),ability=copy(center.config)}, {__index=Card})
end})
local function run(row,changes)
  cases=cases+1;changes=changes or {}
  for i,j in ipairs(row) do j.id=i end
  local input={jokers=copy(row),playing_cards={},hand_size=8,joker_limit=5,
    hands_left=3,discards_left=4,current_round={hands_left=3,discards_left=4,free_rerolls=1},
    round_resets={hands=3,discards=4},probabilities={normal=2,other=4},
    bankrupt_at=-20,interest_amount=3,dollars=10,blind={key='bl_small',boss=false}}
  for k,v in pairs(changes) do input[k]=copy(v) end
  local predicted,diag=Start.project(input,{sample_index=2});assert(predicted,diag)
  queue,removals={},{}
  G={C={BLUE={},RED={},SECONDARY_SET={Enhanced={}}},CARD_W=1,CARD_H=1,
    GAME={current_round=copy(input.current_round),round_resets=copy(input.round_resets),
      probabilities=copy(input.probabilities),bankrupt_at=input.bankrupt_at,
      interest_amount=input.interest_amount,joker_buffer=0,
      blind={boss=false,set_blind=noop}},
    E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},
    jokers={cards={},config={card_limit=input.joker_limit}},
    consumeables={cards={},config={card_limit=2}},
    hand={size=input.hand_size,change_size=function(self,n) self.size=self.size+n end},
    play={T={x=0,y=0,w=1},emplace=noop},deck={config={card_limit=52}},
    playing_cards={},P_CARDS={},P_CENTERS={m_stone={config={effect='Stone Card',bonus=50}}}}
  for i,j in ipairs(row) do
    local original=copy(j);original.added_to_deck=not original.debuff
    if original.debuff and original.edition and original.edition.negative then original.ability.queue_negative_removal=true end
    original.area=G.jokers;setmetatable(original,{__index=Card});G.jokers.cards[i]=original
  end
  for _,j in ipairs(G.jokers.cards) do j:calculate_joker({setting_blind=true,blind={boss=false}}) end
  local n=1
  while queue[n] do assert(n<200,'bounded callback queue');queue[n].func();n=n+1 end
  -- Source dissolution removes after callback dispatch. The remove_from_deck
  -- implementation itself is original; visual/area removal is only harness glue.
  for _,j in ipairs(removals) do
    j:remove_from_deck()
    if j.ability.queue_negative_removal then G.jokers.config.card_limit=G.jokers.config.card_limit-1 end
    for i=#G.jokers.cards,1,-1 do if G.jokers.cards[i]==j then table.remove(G.jokers.cards,i) end end
  end
  while queue[n] do assert(n<250,'bounded removal queue');queue[n].func();n=n+1 end
  eq(#predicted.jokers,#G.jokers.cards,'row size '..cases)
  for i,j in ipairs(predicted.jokers) do
    eq(j.id,G.jokers.cards[i].id,'retained order '..cases)
    eq(j.ability.mult,G.jokers.cards[i].ability.mult,'Dagger Mult '..cases)
    eq(j.ability.x_mult,G.jokers.cards[i].ability.x_mult,'Hologram XMult '..cases)
  end
  eq(predicted.hand_size,G.hand.size,'hand size '..cases)
  eq(predicted.hands_left,G.GAME.current_round.hands_left,'current hands '..cases)
  eq(predicted.discards_left,G.GAME.current_round.discards_left,'current discards '..cases)
  eq(predicted.round_resets.hands,G.GAME.round_resets.hands,'next hands '..cases)
  eq(predicted.round_resets.discards,G.GAME.round_resets.discards,'next discards '..cases)
  eq(predicted.joker_limit,G.jokers.config.card_limit,'slots '..cases)
  eq(predicted.probabilities.normal,G.GAME.probabilities.normal,'probability '..cases)
  eq(predicted.probabilities.other,G.GAME.probabilities.other,'all probability keys '..cases)
  eq(predicted.bankrupt_at,G.GAME.bankrupt_at,'credit '..cases)
  eq(predicted.interest_amount,G.GAME.interest_amount,'interest '..cases)
  eq(predicted.current_round.free_rerolls,G.GAME.current_round.free_rerolls,'free rerolls '..cases)
  eq(#predicted.playing_cards,#G.playing_cards,'generated population '..cases)
  for _,c in ipairs(G.playing_cards) do eq(c.ability.effect,'Stone Card','source Stone');eq(c.ability.bonus,50,'source Stone bonus') end
  eq(predicted.dollars,10,'destruction not sale '..cases)
end
local d=function() return joker('j_ceremonial',{mult=6}) end
local b=function() return joker('j_burglar',{extra=3}) end
local m=function() return joker('j_marble') end
local h=function() return joker('j_hologram',{x_mult=2,extra=.25}) end
run({d(),joker('j_joker')})
run({d(),joker('j_joker',{eternal=true})})
run({d(),d(),joker('j_joker')})
run({joker('j_blueprint'),d(),joker('j_joker')})
run({d(),joker('j_joker'),d(),joker('j_joker')})
run({joker('j_ceremonial',{mult=6},{debuff=true}),joker('j_joker')})
run({d(),b()});run({b(),d(),joker('j_joker')})
run({joker('j_blueprint'),b()});run({b(),joker('j_brainstorm')})
run({joker('j_blueprint'),joker('j_brainstorm')})
run({m(),h()});run({joker('j_blueprint'),m(),h()});run({m(),joker('j_brainstorm'),h()})
run({d(),m(),h()});run({m(),d(),h()});run({d(),h(),m()})
run({joker('j_blueprint'),joker('j_blueprint'),m(),h()})
run({d(),joker('j_blueprint'),m(),h()})
run({d(),joker('j_blueprint'),b()})
for _,victim in ipairs({
  joker('j_oops'),joker('j_oops',{}, {edition={negative=true}}),
  joker('j_oops',{}, {debuff=true,edition={negative=true}}),
  joker('j_troubadour',{extra={h_size=2,h_plays=-1}}),
  joker('j_stuntman',{extra={h_size=2}}),joker('j_turtle_bean',{extra={h_size=4}}),
  joker('j_merry_andy',{h_size=-1,d_size=3}),joker('j_credit_card',{extra=20}),
  joker('j_to_the_moon',{extra=1}),joker('j_chaos')}) do run({d(),victim}) end
run({b(),d(),joker('j_merry_andy',{h_size=-1,d_size=3})})
run({d(),joker('j_merry_andy',{h_size=-1,d_size=3}),b()})
print('blind-start source parity: '..cases..' cases, '..checks..' comparisons')
