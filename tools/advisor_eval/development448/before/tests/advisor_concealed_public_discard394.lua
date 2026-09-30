-- Manufactured concealed observations only; no captured state or live game.
local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local D=dofile('Brainstorm/Advisor/draws.lua')
local O=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function card(id,rank,hidden,seal,suit)
  return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit or 'Spades',
    enhancement='c_base',face_down=hidden,seal=seal,ability={}}
end
local function state()
  local s={phase='hand',ante=7,hand={
      card('hidden-purple',2,true,'Purple'),card('hidden-2',3,true),
      card('hidden-3',4,true),card('hidden-4',5,true),
      card('visible-1',2,false,nil,'Hearts'),card('visible-2',3,false),
      card('visible-3',4,false,nil,'Hearts'),card('visible-4',5,false),
      card('visible-5',6,false,nil,'Hearts')},
    deck={},playing_cards={},jokers={},consumeables={},hands={},
    hands_left=1,discards_left=1,hand_limit=5,hand_size=9,
    blind={key='bl_wheel',name='The Wheel',chips=600},chips=0,dollars=20,
    consumable_limit=2,consumeable_buffer=0,modifiers={},probabilities={normal=1}}
  for i=1,12 do s.deck[i]=card('deck-'..i,14,true) end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local options={draws=D,sampled_outcomes=O}
local s=state();local before=Snap.fingerprint(s)
local observed=assert(B.observe(s))
local family=B.public_candidates(observed.state,true,true)
check(#family>0,'a visible safe family exists despite four hidden slots')
local five=false
for _,indices in ipairs(family) do
  check(#indices>=1 and #indices<=5,'legal selection size')
  if #indices==5 then five=true end
  for _,i in ipairs(indices) do check(i>=5 and i<=9,'only public visible non-Purple slots') end
end
check(five,'five-card discard uses later eligible slots')
local r=B.run(s,S,options)
check(r.concealed_belief.continuation.complete,'whole narrowed family completes')
eq(r.concealed_belief.continuation.first_discard_scope,'visible_nonpurple_public_slots')
eq(r.kind,'discard','complete supported continuation can prefer redraw')
eq(#r.action.indices,5,'the useful redraw spends five cards')
check(r.evaluations<=8000,'original complete shared allowance')
eq(Snap.fingerprint(s),before,'input unchanged')
local swapped=Snap.copy(s);swapped.hand[1],swapped.deck[1]=swapped.deck[1],swapped.hand[1]
eq(Snap.fingerprint(B.run(swapped,S,options)),Snap.fingerprint(r),
  'concealed hand/deck payload assignment cannot change the recommendation')

-- Interleaved forbidden slots cannot cause early truncation to miss five
-- eligible cards; a visible Purple is also outside this first-discard family.
local mixed=state();mixed.hand={
  card('h1',2,true,'Purple'),card('v1',2,false),card('v2',3,false,'Purple'),
  card('h2',4,true),card('v3',4,false),card('v4',5,false),
  card('v5',6,false),card('v6',7,false),card('h3',8,true)}
local m=B.public_candidates(mixed,true,true);local maximal=false
for _,indices in ipairs(m) do
  check(#indices>=1 and #indices<=5,'mixed family legal size')
  if #indices==5 then maximal=true end
  for _,i in ipairs(indices) do check(i~=1 and i~=3 and i~=4 and i~=9,'forbidden slots absent') end
end
check(maximal,'interleaved family reaches five safe cards')
mixed.hand[4].ability.forced_selection=true
eq(#B.public_candidates(mixed,true,true),0,'forced hidden card closes safe family')
mixed.hand[4].ability.forced_selection=nil;mixed.hand[3].ability.forced_selection=true
eq(#B.public_candidates(mixed,true,true),0,'forced visible Purple closes safe family')
mixed.hand[3].ability.forced_selection=nil;mixed.hand[8].ability.forced_selection=true
local forced=B.public_candidates(mixed,true,true);check(#forced>0,'eligible forced slot preserves a family')
for _,indices in ipairs(forced) do
  check(#indices<=5,'forced candidate stays within hand limit')
  local included=false;for _,i in ipairs(indices) do if i==8 then included=true end end
  check(included,'all candidates reserve the forced visible slot')
end
mixed.hand_limit=2
for _,indices in ipairs(B.public_candidates(mixed,true,true)) do
  check(#indices<=2,'reduced hand limit is respected')
end
for i,c in ipairs(mixed.hand) do if i~=2 then c.face_down=true end end
mixed.hand[8].ability.forced_selection=nil
local single=B.public_candidates(mixed,true,true)
eq(#single,1,'one eligible card yields one nonempty candidate')
eq(single[1][1],2)
mixed.hand[2].face_down=true
eq(#B.public_candidates(mixed,true,true),0,'all ineligible yields no discard')

local failures=0
local broken=setmetatable({after_discard=function(st,indices,ctx)
  failures=failures+1
  if failures==2 then return nil,'manufactured later unsupported branch' end
  return S.after_discard(st,indices,ctx)
end},{__index=S})
local bad=B.run(s,broken,options)
check(not bad.concealed_belief.continuation.complete,'later failure invalidates whole family')
eq(bad.kind,'play','incomplete family retains immediate-play incumbent')
check(bad.strategy.lines[3]:find('fallback',1,true),'failure reason remains visible')
local limited=B.run(s,S,{draws=D,sampled_outcomes=O,max_evaluations=6100})
check(limited.evaluations<=6100,'reduced budget cannot be exceeded')
check(not limited.concealed_belief.continuation.complete,'partial budget cannot be promoted')

local full=state()
full.consumeables={{key='c_mercury',ability={name='Mercury',set='Planet'}},
  {key='c_venus',ability={name='Venus',set='Planet'}}}
local with_no_slot=B.run(full,S,options)
eq(with_no_slot.concealed_belief.continuation.first_discard_scope,'ordinary_public_slots',
  'a full consumable inventory needs no Purple-specific candidate restriction')
local no_purple=state();no_purple.hand[1].seal=nil
for _,c in ipairs(no_purple.playing_cards) do if c.id=='hidden-purple' then c.seal=nil end end
local with_no_purple=B.run(no_purple,S,options)
eq(with_no_purple.concealed_belief.continuation.first_discard_scope,'ordinary_public_slots',
  'no possible Purple Seal retains the ordinary first-discard family')

print('concealed public discard: '..checks..' checks passed')
