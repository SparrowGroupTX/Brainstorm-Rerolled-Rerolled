-- Manufactured public compositions only; no captured-state policy replay.
local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local R=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local D=dofile('Brainstorm/Advisor/draws.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function c(id,rank,hidden,lucky)
  return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),
    suit='Hearts',face_down=hidden,enhancement=lucky and 'm_lucky' or 'c_base',ability={}}
end
local function yorick()
  return {id='yorick',key='j_yorick',ability={name='Yorick',x_mult=5,
    yorick_discards=23,extra={discards=23,xmult=1}}}
end
local simple={phase='hand',hand={c('lucky',14,false,true),c('other',2,false)},
  deck={},playing_cards={},jokers={yorick()},consumeables={},hands={},
  hands_left=2,discards_left=1,hand_limit=5,hand_size=2,
  blind={key='bl_house',chips=10000},chips=0,dollars=10,probabilities={normal=1},modifiers={}}
simple.playing_cards={simple.hand[1],simple.hand[2]}
local baseline=Snap.fingerprint(simple)
local _,_,old=R.after_play(simple,{1},S,17,1)
check(old and old.uncertain,'ordinary owned-Joker Lucky transition remains out of scope')
local after,effects,result=R.after_play(simple,{1},S,17,1,{lucky_floor_with_owned_jokers=true})
check(after and result and not result.uncertain,'explicit no-trigger transition is resolved')
eq(after.dollars,10,'optional Lucky dollars are not credited')
eq(result.score,80,'Yorick scores only deterministic no-trigger base')
eq(after.jokers[1].ability.x_mult,5,'no invented Lucky growth')
check(effects.sampled_lucky,'the recorded transition used an explicit Lucky event')
eq(Snap.fingerprint(simple),baseline,'no mutation of the public input')
eq(S.after_play(simple,{1},{lucky_outcomes={[1]={{mult=false,dollars=false}}}}),nil,
  'manual event without the scoped floor marker stays unsupported')
eq(S.after_play(simple,{1},{lucky_outcomes={[1]={{mult=true,dollars=false}}},lucky_floor=true}),nil,
  'positive owned-Joker trigger cannot masquerade as the floor')
simple.probabilities.normal=5
eq(R.after_play(simple,{1},S,17,1,{lucky_floor_with_owned_jokers=true}),nil,
  'mandatory Lucky Mult has no all-failed optional floor')
simple.probabilities.normal=1
simple.modifiers.minus_hand_size_per_X_dollar=5
eq(R.after_play(simple,{1},S,17,1,{lucky_floor_with_owned_jokers=true}),nil,
  'Lucky dollar earnings could shrink a Tax hand after the conservative score')
simple.modifiers.minus_hand_size_per_X_dollar=nil
simple.jokers[2]={key='j_lucky_cat',ability={name='Lucky Cat',extra=-0.25,x_mult=2}}
eq(R.after_play(simple,{1},S,17,1,{lucky_floor_with_owned_jokers=true}),nil,
  'negative Lucky Cat trigger growth cannot use a no-trigger continuation bound')
simple.jokers[2]={key='j_bull',ability={name='Bull',extra=-2}}
eq(R.after_play(simple,{1},S,17,1,{lucky_floor_with_owned_jokers=true}),nil,
  'negative Bull cash scaling cannot make missing Lucky dollars look conservative')
simple.jokers[2]={key='j_bootstraps',ability={name='Bootstraps',extra={mult=-2,dollars=5}}}
eq(R.after_play(simple,{1},S,17,1,{lucky_floor_with_owned_jokers=true}),nil,
  'negative Bootstraps cash scaling is outside the floor')
simple.jokers[2]=nil

local function house()
  local s={phase='hand',ante=5,hand={c('h1',2,true),c('h2',3,true),c('h3',4,true)},
    deck={c('d1',14,true,true),c('d2',14,true),c('d3',14,true),
          c('d4',13,true,true),c('d5',13,true),c('d6',13,true)},
    playing_cards={},jokers={yorick()},consumeables={},hands={},
    hands_left=2,discards_left=2,hand_limit=3,hand_size=3,
    blind={key='bl_house',name='The House',chips=500},chips=0,dollars=20,
    probabilities={normal=1},modifiers={}}
  for _,area in ipairs({s.hand,s.deck}) do for _,card in ipairs(area) do s.playing_cards[#s.playing_cards+1]=card end end
  return s
end
local h=house();local frozen=Snap.fingerprint(h)
local result_house=B.run(h,S,{draws=D,sampled_outcomes=R})
check(result_house.concealed_belief.continuation.complete,
  'owned-Joker Lucky no-trigger floor completes the declared House comparison')
eq(result_house.kind,'discard','a supported House redraw can beat the concealed immediate play')
check(result_house.evaluations<=8000,'same concealed score cap')
eq(Snap.fingerprint(h),frozen,'complete comparison leaves input unchanged')
local swapped=Snap.copy(h);swapped.hand[1],swapped.deck[1]=swapped.deck[1],swapped.hand[1]
eq(Snap.fingerprint(B.run(swapped,S,{draws=D,sampled_outcomes=R})),
   Snap.fingerprint(result_house),'latent hand/deck payload assignment does not affect the public decision')
local limited=B.run(h,S,{draws=D,sampled_outcomes=R,max_evaluations=130})
check(limited.evaluations<=130 and not limited.concealed_belief.continuation.complete,
  'incomplete score budget retains the immediate fallback')

print('concealed Lucky floor: '..checks..' checks passed')
