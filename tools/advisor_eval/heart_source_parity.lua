local S=dofile('Brainstorm/Advisor/scoring.lua')
local copy=dofile('Brainstorm/Advisor/snapshot.lua').copy
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local noop=function() end
Event=function(e) return e end
discover_card=noop;check_for_unlock=noop;play_sound=noop;card_eval_status_text=noop;calculate_reroll_cost=noop
localize=function() return 'test' end;pseudoseed=function(key) return key end
ease_discard=function(amount) G.GAME.current_round.discards_left=G.GAME.current_round.discards_left+amount end
local function j(n,a,debuff) a=a or {};a.name=n;a.h_size=a.h_size or 0;a.d_size=a.d_size or 0;a.set='Joker';return {ability=a,debuff=not not debuff} end
local function parity(jokers,target,label)
 cases=cases+1
 local s={jokers=jokers,hand_size=8,discards_left=2,joker_limit=5,bankrupt_at=0,interest_amount=1,
  round_resets={hands=4,discards=3},probabilities={normal=2,other=0.5},current_round={discards_left=2,free_rerolls=0},
  blind={name='Crimson Heart',crimson_pending=true}}
 local actual=assert(S.after_draw(s,{crimson_index=target}))
 local queue={}
 G={C={},I={CARD={}},P_CENTERS={e_base={discovered=true},e_negative={discovered=true}},
  E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},hand={config={card_limit=8}},jokers={cards=copy(jokers),config={card_limit=5}},
  GAME={bankrupt_at=s.bankrupt_at,interest_amount=s.interest_amount,current_round=copy(s.current_round),
    probabilities=copy(s.probabilities),round_resets=copy(s.round_resets)}}
 G.hand.change_size=function(area,amount) area.config.card_limit=area.config.card_limit+amount end
 local blind=setmetatable({name='Crimson Heart',prepped=true,wiggle=noop,set_blind=noop},{__index=Blind});G.GAME.blind=blind
 for i,c in ipairs(G.jokers.cards) do
  c.source_index=i;c.added_to_deck=not c.debuff;c.area=G.jokers;c.config={center={discovered=true}};c.juice_up=noop
  setmetatable(c,{__index=Card})
 end
 pseudorandom_element=function(cards,key)
  eq(key,'crimson_heart',label..' source RNG key')
  for _,card in ipairs(cards) do if card.source_index==target then return card end end
  assert(#cards==0,'target not eligible in source')
 end
 blind:drawn_to_hand()
 local event=1;while queue[event] do assert(event<100,'bounded Heart events');if queue[event].func then queue[event].func() end;event=event+1 end
 eq(actual.hand_size,G.hand.config.card_limit,label..' capacity')
 eq(actual.discards_left,G.GAME.current_round.discards_left,label..' remaining discards')
 eq(actual.round_resets.discards,G.GAME.round_resets.discards,label..' round discard resources')
 eq(actual.round_resets.hands,G.GAME.round_resets.hands,label..' round hand resources')
 eq(actual.bankrupt_at,G.GAME.bankrupt_at,label..' debt capacity');eq(actual.interest_amount,G.GAME.interest_amount,label..' interest')
 eq(actual.current_round.free_rerolls,G.GAME.current_round.free_rerolls,label..' free rerolls')
 eq(actual.joker_limit,G.jokers.config.card_limit,label..' negative capacity')
 for k,v in pairs(G.GAME.probabilities) do eq(actual.probabilities[k],v,label..' odds '..k) end
 for i,c in ipairs(G.jokers.cards) do
  eq(actual.jokers[i].debuff,c.debuff,label..' debuff '..i)
  eq(actual.jokers[i].ability.queue_negative_removal,c.ability.queue_negative_removal,label..' negative pending '..i)
 end
end
parity({j('Turtle Bean',{extra={h_size=5}},true),j('Oops! All 6s'),j('Stuntman',{extra={h_size=2}})},2,'restore Bean disable odds')
parity({j('Stuntman',{extra={h_size=2}},true),j('Troubadour',{extra={h_size=2,h_plays=-1}})},2,'restore Stuntman disable Troubadour')
parity({j('Merry Andy',{h_size=-1,d_size=3}),j('Drunkard',{d_size=1},true)},1,'discard resources')
parity({j('Credit Card',{extra=20},true),j('To the Moon',{extra=1})},2,'debt and interest')
parity({j('Chaos the Clown',{},true),j('Joker',{mult=4})},2,'free rerolls')
local neg=j('Joker',{mult=4},true);neg.edition={negative=true,type='negative'};neg.ability.queue_negative_removal=true
parity({neg,j('Joker',{mult=4})},2,'Negative slot survives debuff')
parity({j('Joker',{mult=4,perishable=true,perish_tally=0},true),j('DNA')},2,'expired perishable cannot restore')
parity({j('Joker',{mult=4},true)},1,'single Joker may repeat')
parity({j('Joker',{mult=4},true),j('DNA',{},true)},nil,'all debuffed row restoration')
print('Heart source parity: '..cases..' cases / '..checks..' comparisons passed')
