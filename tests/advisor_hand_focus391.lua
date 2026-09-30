-- Manufactured hand histories: played counts alone are not a durable win-first plan.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function profile(hands,jokers,teacher)
  return Strategy.build_profile({teacher_profile=teacher or 'perkeo_yorick_win_v1',
    ante=2,win_ante=8,hands=hands,jokers=jokers or {},playing_cards={}})
end
local incidental={Straight={level=1,played=1},Flush={level=1,played=1}}
check(profile(incidental).hand=='Pair','one incidental Straight and Flush do not select a win-first plan')
check(profile(incidental,{},'collection_progress').hand=='Straight',
  'collection profile retains its historical neutral hand comparison')
check(profile({Straight={level=3,played=6},['Full House']={level=1,played=2}}).hand=='Full House',
  'repeatable rank hand beats a modest unassisted Straight history')
check(profile(incidental,{{key='j_shortcut',ability={name='Shortcut'}}}).hand=='Straight',
  'actual Straight support can overcome the win-first prior')
check(profile({Straight={level=7,played=8}}).hand=='Straight',
  'substantial hand levels and repeated plays can overcome the win-first prior')
check(profile({Flush={level=3,played=14},['High Card']={level=3,played=12}}).hand=='Flush',
  'mature Flush investment remains the plan and keeps useful Jupiter stock eligible')
check(profile({Flush={level=1,played=1}},{{key='j_smeared',ability={name='Smeared Joker'}}}).hand=='Flush',
  'actual Flush support can overcome the win-first prior')
check(profile({['Three of a Kind']={level=3,played=4},Straight={level=3,played=6}}).hand=='Three of a Kind',
  'rank-hand development is preferred when its evidence is stronger')
do
  local cards={}
  for i=1,52 do cards[i]={id='manufactured:'..i,rank=2+(i-1)%13,
      suit=({'Hearts','Spades','Diamonds','Clubs'})[(i-1)%4+1],enhancement='c_base',ability={}} end
  local s={phase='shop',ante=1,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=10,bankrupt_at=0,interest_cap=25,joker_limit=5,
    jokers={{key='j_yorick',ability={name='Yorick',x_mult=1,extra={discards=23,xmult=1}}},
      {key='j_perkeo',ability={name='Perkeo'}}},
    shop_jokers={{key='c_saturn',cost=3,ability={set='Planet',name='Saturn'}},
      {key='c_mercury',cost=3,ability={set='Planet',name='Mercury'}}},
    shop_vouchers={},shop_booster={},consumeables={},playing_cards=cards,deck={},hand={},
    hands=incidental,hand_size=8,round_resets={hands=4,discards=3},
    blind={key='bl_big',name='Big Blind',chips=450},modifiers={}}
  local advice=Strategy.advise(s)
  check(advice.action and advice.action.kind=='buy' and advice.action.area=='shop_jokers' and
    advice.action.index==2,'a viable Pair planet outranks incidental Straight as first Perkeo source')
end
print('hand focus391: '..checks..' checks passed')
