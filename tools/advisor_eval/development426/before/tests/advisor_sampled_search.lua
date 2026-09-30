local S=dofile('Brainstorm/Advisor/scoring.lua')
local Q=dofile('Brainstorm/Advisor/search.lua')
local D=dofile('Brainstorm/Advisor/draws.lua')
local R=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local n=0;local function check(v,m) n=n+1;assert(v,m) end
local function card(i,r,e) return {id=i,rank=r,suit='Spades',enhancement=e or 'c_base',face_down=false,ability={}} end
local function fixture()
  local s={phase='hand',ante=2,hand={card(1,14),card(2,2)},deck={card(3,2),card(4,2),card(5,3),card(6,3)},
    hands_left=3,hand_size=2,hand_limit=5,discards_left=2,discards_used=0,hands_played=1,
    blind={key='bl_small',chips=110},chips=0,dollars=20,current_round={},probabilities={normal=1},modifiers={},
    hands={['High Card']={level=1,chips=5,mult=1,l_chips=10,l_mult=1,played=5}},jokers={}}
  s.playing_cards={};for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end
  for _,c in ipairs(s.deck) do c.face_down=true;s.playing_cards[#s.playing_cards+1]=c end
  return s
end
local s=fixture();local old=Snapshot.fingerprint(s)
local after=assert(S.after_discard(s,{1}));local drawn=assert(D.fill(after,s.deck))
check(drawn.hand[2].face_down==false,'ordinary deck orientation clears on draw')
check(s.deck[1].face_down==true,'input deck remains unchanged')
s.hand[2].face_down=true;after=assert(S.after_discard(s,{1}));drawn=assert(D.fill(after,s.deck))
check(drawn.hand[1].face_down==true,'existing hidden held card remains hidden');s.hand[2].face_down=false
for _,blind in ipairs({'bl_small','bl_hook','bl_final_heart'}) do
  s=fixture();s.blind.key=blind
  if blind=='bl_final_heart' then s.jokers={{key='j_joker',ability={name='Joker',mult=4},debuff=true},
    {key='j_ice_cream',ability={name='Ice Cream',extra={chips=30,chip_mod=5}}}} end
  old=Snapshot.fingerprint(s)
  local r=Q.run(s,S,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
  check(r.resource_comparison~=nil,blind..' supports remaining-blind samples: '..tostring((r.search_diagnostics or {}).continuation_skipped))
  check(r.resource_comparison.samples>=4,'complete paired passes')
  check(Snapshot.fingerprint(s)==old,'sampled comparisons remain detached')
end
s=fixture();s.hand[1].enhancement='m_glass';s.blind.chips=140
local calls=0;local scorer=setmetatable({after_play=function(t,sel,ctx)
  if ctx and ctx.glass_outcomes then calls=calls+1 end;return S.after_play(t,sel,ctx)
end},{__index=S})
local r=Q.run(s,scorer,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
check(calls>0 and r.resource_comparison,'ordinary stochastic Glass participates')
local again=Q.run(s,scorer,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
check(r.kind==again.kind and r.evaluations==again.evaluations and r.resource_comparison.best.value==again.resource_comparison.best.value,'private samples repeat exactly')
local a,b={},{}
for seed=1,400 do
  local ctx=R.context(s,{1},seed,1);a[ctx.glass_outcomes[1] and 'breaks' or 'survives']=true
  local reordered={hand={s.hand[2],s.hand[1]},blind=s.blind,probabilities=s.probabilities}
  check(ctx.glass_outcomes[1]==R.context(reordered,{2},seed,1).glass_outcomes[2],'Glass shared by physical card across order')
end
check(a.breaks and a.survives,'both Glass outcomes sampled')
s=fixture();s.blind={key='bl_fish',chips=100}
after=assert(R.after_play(s,{1},S,4,1));drawn=assert(R.fill(after,after.deck,S,D,4,1,0))
check(drawn.hand[2].face_down==true,'Fish post-play draw stays hidden')
check(S.after_play(s,{1}).blind.prepped==true,'Fish press-play flag is part of shared transition')
s=fixture();s.modifiers.flipped_cards=4
r=Q.run(s,S,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
check(r.search_diagnostics.discard_skipped~=nil and not r.discard,'unsupported challenge concealment fails closed')
s=fixture();s.blind.key='bl_wheel';s.probabilities.normal=7
r=Q.run(s,S,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
check(not r.discard and r.search_diagnostics.discard_skipped:match('concealed'),'hidden replacement identities never choose future plays for utility')
s=fixture();s.hands_left=1
for _,c in ipairs(s.deck) do c.face_down=false end
local plain=Q.run(s,S,{draws=D,samples=8})
local effects=Q.run(s,S,{draws=D,sampled_outcomes=R,samples=8})
check(plain.discard.mean==effects.discard.mean and table.concat(plain.discard.indices,',')==table.concat(effects.discard.indices,','),
  'effect stream does not perturb ordinary replacement samples')
s=fixture();s.hands_left=1;s.blind={key='bl_hook',chips=90}
local actual_calls=0
local hook_scorer={after_discard=S.after_discard,score=function(t,indices)
  return {score=100,uncertain=true,legal=true,hand='High Card',scoring_indices=indices}
end,after_play=function(t,indices,ctx)
  check(ctx and ctx.hook_indices,'one-draw Hook scores require explicit outcome')
  actual_calls=actual_calls+1
  return {chips=10,hands_left=0,hand={},deck={},blind=t.blind},{},{score=10,legal=true,hand='High Card'}
end}
r=Q.run(s,hook_scorer,{draws=D,sampled_outcomes=R,samples=4})
check(actual_calls>0 and r.discard.probability==0,'final-hand Hook clear uses post-discard score')
s.blind={chips=90}
r=Q.run(s,hook_scorer,{draws=D,sampled_outcomes=R,samples=4})
check(r.discard.probability==0,'uncertain mean is not counted as a sampled clear')
hook_scorer.lower_bound=function()return {score=95,reliable_bound=true,legal=true,hand='High Card'}end
r=Q.run(s,hook_scorer,{draws=D,sampled_outcomes=R,samples=4})
-- Current floor may end the decision immediately; either supported path proves it.
check(r.fast_clear or r.discard and r.discard.probability==1,'supported reliable floor can establish a clear')
print('sampled search: '..n..' checks passed')
