-- Invented, already-paid pack; exercise production projection, scoring, and ranking.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
Strategy.consumables=Consumables;Strategy.pack_scoring=Pack
local checks=0;local function check(v,s)assert(v,s);checks=checks+1 end
local s={phase='pack',teacher_profile='perkeo_yorick_win_v1',ante=2,dollars=6,bankrupt_at=0,
  jokers={{id='invented:perkeo',key='j_perkeo',name='Perkeo',cost=20,sell_cost=10,ability={set='Joker',name='Perkeo'}}},
  joker_limit=5,consumeables={},consumable_limit=2,shop_jokers={},shop_vouchers={},shop_booster={},
  hand={},playing_cards={},deck={},hand_size=8,hand_limit=5,hands_left=4,discards_left=3,
  hands={Pair={level=1,chips=10,mult=2,played=9},['Two Pair']={level=1,chips=20,mult=2,played=1}},
  round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
  next_blind={key='bl_small',name='Small Blind',chips=40},next_blind_chips=40,
  blind={key='bl_small',name='Small Blind',chips=40},pack_choices=1,
  pack_cards={{id='invented:uranus',key='c_uranus',name='Uranus',cost=3,sell_cost=1,
    ability={set='Planet',name='Uranus',effect='Hand Upgrade',consumeable={hand_type='Two Pair'}}}}}
for i,rank in ipairs({2,2,3,3,4,4,5,5})do
  s.playing_cards[i]={id='invented:p'..i,key='c_base',rank=rank,nominal=rank,suit=({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1],ability={}}
end
local original=Snapshot.fingerprint(s)
local after=assert(Pack.project(s,s.pack_cards[1],{},nil,{strategy=Strategy,consumables=Consumables}))
check(after.hands['Two Pair'].level==2,'free revealed Planet produces permanent upgrade')
check(after.dollars==s.dollars and #after.consumeables==0,'pack use spends no cash and occupies no inventory')
local ctx=Shop.new(s,Scoring)
local evidence=assert(ctx:compare(s,after))
local advice=Strategy.advise(s,{shop_scoring=ctx})
print('diagnostic complete='..tostring(evidence.complete_finishing)..', adjustment='..tostring(evidence.adjustment)..', ratio='..tostring(evidence.ratio)..', action='..tostring(advice.action.kind)..', reason='..tostring(evidence.reason))
check(evidence.complete_finishing and evidence.adjustment<0,'generic acquisition comparison penalizes no improvement to already-capped finish')
check(advice.action.kind=='skip_pack','known current defect: positive free upgrade is rejected after negative acquisition adjustment')
check(Snapshot.fingerprint(s)==original,'original invented state remains intact')
print('manufactured_pack_diagnostics407: '..checks..' checks passed; action='..advice.action.kind..', adjustment='..evidence.adjustment..', evaluations='..ctx.evaluations)
