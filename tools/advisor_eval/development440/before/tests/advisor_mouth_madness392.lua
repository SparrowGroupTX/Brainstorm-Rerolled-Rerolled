-- Manufactured admission and terminal-progress checks; no logged state replay.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
local count=0
local function check(ok,label) count=count+1;assert(ok,label) end
local function joker(key,eternal)
  return {key=key,name=key,cost=4,sell_cost=2,blueprint_compat=true,
    ability={name=key,set='Joker',eternal=eternal,x_mult=key=='j_yorick' and 2 or nil}}
end
local function state()
  local s={phase='pack',ante=3,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=20,bankrupt_at=0,joker_limit=5,consumable_limit=2,pack_type='BUFFOON_PACK',pack_choices=1,
    jokers={joker('j_yorick'),joker('j_perkeo'),joker('j_blueprint')},
    pack_cards={},consumeables={},hand={},deck={},playing_cards={},
    hands={Pair={level=2,played=6,chips=25,mult=3}},blind={chips=800},
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1}}
  for i=1,20 do s.playing_cards[i]={id='fabricated:'..i,rank=2+(i%10),suit='Clubs',ability={}} end
  return s
end
local madness=joker('j_madness');madness.ability.x_mult=2
local s=state();local fingerprint=Snapshot.fingerprint(s)
local admitted,why=S.joker_admission(s,madness,nil,{ratio=3})
check(not admitted and why.kind=='win_first_destructive_core_guard','paired immediate score does not price later core destruction')
check(Snapshot.fingerprint(s)==fingerprint,'admission preserves the public row')
for _,key in ipairs({'j_yorick','j_perkeo','j_blueprint','j_brainstorm'}) do
  local one=state();one.jokers={joker(key)}
  check(not S.joker_admission(one,madness),'every non-Eternal win-first core is protected')
  one.jokers[1].ability.eternal=true
  check(S.joker_admission(one,madness),'an Eternal core is not destructible')
end
s=state();s.modifiers.all_eternal=true
check(S.joker_admission(s,madness),'all-Eternal modifier removes destruction risk')
s=state();s.teacher_profile=nil
check(S.joker_admission(s,madness),'collection profile retains its separate admission rules')
s=state();s.pack_cards={madness,joker('j_popcorn')};s.pack_cards[2].ability.mult=20
local pack=S.advise(s)
check(pack.action and pack.action.kind=='choose' and pack.action.index==2,
  'Buffoon choice keeps the core instead of taking Madness')
check(pack.pack_diagnostics.offers[1].collection_admitted==false,
  'pack diagnostics expose the rejected Madness offer')
s=state();s.phase='shop';s.pack_cards=nil;s.shop_jokers={madness,joker('j_popcorn')}
s.shop_vouchers={};s.shop_booster={};s.interest_cap=25
local shop=S.advise(s)
check(not (shop.action and shop.action.kind=='buy' and shop.action.area=='shop_jokers' and
  shop.action.index==1),'shop route cannot buy Madness through a generic positive rating')
local projected,why=Sequences.transition(s,{kind='buy',area='shop_jokers',index=1},{strategy=S})
check(not projected and why:find('Madness',1,true),'two-step shop graph also rejects destructive core acquisition')
s.teacher_profile=nil
projected=Sequences.transition(s,{kind='buy',area='shop_jokers',index=1},{strategy=S})
check(projected and projected.jokers[#projected.jokers].key=='j_madness',
  'collection shop graph retains its independent objective')

local function hand_state()
  local q={phase='hand',ante=4,blind={name='The Mouth',key='bl_mouth',only_hand='Flush',chips=2000},
    hands_left=1,discards_left=0,hand={},deck={},jokers={},consumeables={},
    chips=300,hands={Pair={level=1,chips=10,mult=2}},current_round={}}
  for i,rank in ipairs({3,3,6,6,9,9,12}) do
    q.hand[i]={id='fabricated-hand:'..i,rank=rank,nominal=rank,suit=i%2==0 and 'Hearts' or 'Spades',
      enhancement='c_base',ability={}}
  end
  return q
end
local q=hand_state();fingerprint=Snapshot.fingerprint(q)
local r={evaluations=0}
D.mouth_cycle(q,Score,r,2)
check(r.action and r.action.kind=='play' and r.mouth_cycle.score==0 and not r.mouth_cycle.draw_available,
  'last Mouth hand advances even with no deck and records zero score')
check(r.evaluations==2 and r.title=='Advance the blocked Mouth hand',
  'two supported probes stay within the cap and UI describes no draw')
check(Snapshot.fingerprint(q)==fingerprint,'terminal progression leaves input immutable')
q=hand_state();q.hands_left=2;r={evaluations=0}
D.mouth_cycle(q,Score,r,2)
check(r.action and not r.mouth_cycle.draw_available,'empty deck with spare hands progresses')
q=hand_state();q.deck={{id='fabricated-deck',rank=13,suit='Clubs'}};r={evaluations=0}
D.mouth_cycle(q,Score,r,2)
check(r.action and r.mouth_cycle.draw_available,'last hand with deck does not promise success')
q=hand_state();q.hands_left=0;r={evaluations=0}
D.mouth_cycle(q,{score=function()error('zero hands must guard before scoring')end},r,2)
check(not r.action,'zero hands cannot play')
q=hand_state();r={evaluations=0}
D.mouth_cycle(q,{score=function()return {legal=false,reason='unsupported'}end},r,2)
check(not r.action,'unrelated scorer rejection is not reclassified as Mouth progress')
print('mouth_madness392: '..count..' manufactured checks passed')
