local S=dofile('Brainstorm/Advisor/search.lua')
local C=dofile('Brainstorm/Advisor/scoring.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local function card(i,r) return {id=i,rank=r,suit='Spades',enhancement='c_base',ability={}} end
local s={phase='hand',hand={},deck={},jokers={},consumeables={},hands={},hand_size=8,hand_limit=5,hands_left=1,
  discards_left=3,blind={chips=100},chips=0,dollars=0,modifiers={}}
for i=1,8 do s.hand[i]=card(i,i+1) end
for i=9,24 do s.deck[#s.deck+1]=card(i,13) end
local fp=Snap.fingerprint(s)
local fake={score=function(state,indices)
  local win=false;for _,i in ipairs(indices) do if state.hand[i].id>8 then win=true end end
  return {legal=true,score=win and 200 or 0,hand='High Card',scoring_indices={indices[1]}}
end}
local options={samples=4,candidates=5,resource_samples=0,cycle_samples=0}
local fast=S.run(s,fake,options)
options.future_clear=false;local full=S.run(s,fake,options)
check(fast.kind==full.kind and table.concat(fast.discard.indices,',')==table.concat(full.discard.indices,','),'paired redraw choice agrees with exhaustive future search')
check(fast.discard.probability==full.discard.probability and fast.discard.value==full.discard.value,'capped survival objective agrees')
check(fast.evaluations<full.evaluations/4 and fast.search_performance.future_clear_stops>0,'future clears remove redundant enumeration')
check(fast.play_complete and not fast.fast_clear,'nonclearing current hand remains fully searched')
check(Snap.fingerprint(s)==fp,'sampled optimization does not mutate input')
check(Snap.fingerprint(fast)==Snap.fingerprint(S.run(s,fake,{samples=4,candidates=5,resource_samples=0,cycle_samples=0})),'deterministic fast future sampling')
s.hand={card(1,13)};s.hand_size=1;s.deck={};s.hand[1].enhancement='m_lucky';s.blind.chips=10;s.probabilities={normal=1}
local r=S.run(s,C)
check(r.fast_clear and r.play.reliable_bound and r.play.expected_score>=r.play.score,'random upside permits a proven floor clear')
check(r.search_performance.lower_bound_checks<=4 and r.evaluations<=52,'extra floor checks bounded and counted')
s.blind.chips=100000
r=S.run(s,C)
check(not r.fast_clear,'weak random floor never claims clear')
local uncertain={score=function() return {score=10000000,legal=true,uncertain=true,hand='High Card'} end,
  lower_bound=function() return {score=10000000,legal=true,uncertain=true,reliable_bound=false,hand='High Card'} end}
for i=2,8 do s.hand[i]=card(i,i) end
r=S.run(s,uncertain)
check(not r.fast_clear and r.search_performance.lower_bound_checks==4,'unknown effects stay uncertain with exactly bounded extra checks')
print('advisor_search_efficiency: '..n..' checks passed; future paired scores '..fast.evaluations..' vs '..full.evaluations)
