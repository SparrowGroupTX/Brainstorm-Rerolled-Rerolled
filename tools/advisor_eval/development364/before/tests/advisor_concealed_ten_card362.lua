-- Manufactured population only. No captured policy/scorer or source execution.
local B=dofile(ADVISOR_CONCEALED_PATH or 'Brainstorm/Advisor/concealed_belief.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a):sub(1,160)..' ~= '..tostring(b):sub(1,160))end
local function state()
 local s={phase='hand',ante=2,hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},
  hand_size=10,hand_limit=5,hands_left=1,discards_left=0,blind={key='bl_fish',chips=10000},
  chips=0,dollars=20,modifiers={},probabilities={normal=1}}
 for _,suit in ipairs({'Hearts','Clubs','Spades','Diamonds'})do for rank=2,14 do
  local card={id=suit..rank,rank=rank,suit=suit,nominal=rank==14 and 11 or math.min(rank,10),
   enhancement='c_base',face_down=true,ability={}}
  s.playing_cards[#s.playing_cards+1]=card
  if #s.hand<10 then s.hand[#s.hand+1]=card else s.deck[#s.deck+1]=card end
 end end
 for i=2,10,2 do s.hand[i].face_down=false end
 return s
end
local original_random=math.random;math.random=function()error('global RNG forbidden')end
local s=state();local before=Snapshot.fingerprint(s)
local calls,worlds,world_count,family=0,{},0,{}
local spy=setmetatable({lower_bound=function(world,indices)
 calls=calls+1
 if not worlds[world]then
  world_count=world_count+1;worlds[world]=world_count
  eq(#world.hand,10,'ten held slots');eq(#world.deck,42,'remaining draw population');eq(#world.playing_cards,52,'full population')
  local ids={};for _,c in ipairs(world.playing_cards)do check(not ids[c.id],'unique physical population');ids[c.id]=true end
  for i=2,10,2 do eq(world.hand[i].rank,s.hand[i].rank,'visible rank fixed');eq(world.hand[i].suit,s.hand[i].suit,'visible suit fixed')end
 end
 local key=table.concat(indices,',');local f=family[key] or {sum=0};family[key]=f
 local id=worlds[world];f[id]=(f[id]or 0)+1
 local score=S.lower_bound(world,indices);f.sum=f.sum+(score.legal==false and 0 or score.score)
 return score
end},{__index=S})
local result=B.run(s,spy)
eq(result.kind,'play','ten-card public shape supported')
eq(result.concealed_belief.candidates,637,'full one-through-five subset family')
eq(result.concealed_belief.worlds,12,'twelve default common worlds')
eq(world_count,12,'every candidate reuses the same twelve world objects')
eq(calls,7644,'actual scoring calls fit unchanged budget');eq(result.evaluations,calls,'all work reported')
check(result.concealed_belief.complete and result.concealed_belief.supported,'complete immediate comparison')
check(result.play.uncertain and not result.play.reliable_bound,'sample estimate is not a guaranteed clear')
local expected,count={},0
-- Independent bit-mask oracle (not production recursive combinations).
for mask=1,1023 do
 local bits,indices=mask,{}
 for i=1,10 do if bits%2==1 then indices[#indices+1]=i end;bits=math.floor(bits/2)end
 if #indices<=5 then
  local key=table.concat(indices,',');expected[key]=true;count=count+1
  check(family[key],'every legal-size subset evaluated')
  for w=1,12 do eq(family[key][w],1,'one complete evaluation per common world')end
 end
end
eq(count,637,'independent oracle count')
for key in pairs(family)do check(expected[key],'no unrequested or duplicate candidate')end
for _,c in ipairs(result.concealed_belief.comparisons)do
 check(math.abs(c.mean-family[table.concat(c.indices,',')].sum/12)<1e-8,'reported mean uses fixed candidate in every world')
end
eq(Snapshot.fingerprint(s),before,'original input and inventory unchanged')
local permuted=Snapshot.copy(s)
permuted.hand[1],permuted.deck[9]=permuted.deck[9],permuted.hand[1]
permuted.hand[7],permuted.deck[25]=permuted.deck[25],permuted.hand[7]
permuted.deck[2],permuted.deck[40]=permuted.deck[40],permuted.deck[2]
eq(Snapshot.fingerprint(B.run(permuted,S)),Snapshot.fingerprint(result),'hidden assignments and deck order cannot affect any decision evidence')
for _,area in ipairs({permuted.hand,permuted.deck,permuted.playing_cards})do
 for _,c in ipairs(area)do c.id='renamed:'..c.id end
end
eq(Snapshot.fingerprint(B.run(permuted,S)),Snapshot.fingerprint(result),'physical ID spelling irrelevant')
eq(Snapshot.fingerprint(B.run(s,S)),Snapshot.fingerprint(result),'deterministic repeated observation')

local forbidden={lower_bound=function()error('rejection must precede scoring')end}
for _,cap in ipairs({0,1,2547,7643})do
 local rejected=B.run(s,forbidden,{max_evaluations=cap})
 eq(rejected.kind,'unsupported','incomplete default family rejected');eq(rejected.evaluations,0,'no partial scoring')
end
local exact=B.run(s,S,{max_evaluations=7644})
eq(exact.evaluations,7644,'exact-fit caller budget');eq(Snapshot.fingerprint(exact.action),Snapshot.fingerprint(result.action),'same exact-fit action')
for _,samples in ipairs({13,16,32})do eq(B.run(s,forbidden,{samples=samples}).kind,'unsupported','explicit oversized family rejected')end
local four=B.run(s,S,{samples=4,max_evaluations=2548})
eq(four.concealed_belief.worlds,4,'explicit lower sample request retained');eq(four.evaluations,2548,'lower request still complete')
local bad=Snapshot.copy(s);bad.hand[11]=table.remove(bad.deck)
eq(B.run(bad,forbidden,{samples=4}).kind,'unsupported','eleven cards still out of scope')
bad=Snapshot.copy(s);bad.playing_cards={};eq(B.run(bad,forbidden).kind,'unsupported','complete population required')
bad=Snapshot.copy(s);bad.blind={key='bl_small',chips=10000};eq(B.run(bad,forbidden).kind,'unsupported','unknown concealment origin rejected')
bad=Snapshot.copy(s);bad.jokers={{face_down=true}};eq(B.run(bad,forbidden).kind,'unsupported','hidden Joker row rejected')
bad=Snapshot.copy(s);bad.jokers={{key='j_unknown_modded'}};eq(B.run(bad,S).kind,'unsupported','unsupported mechanics remain blocked')
local forced=Snapshot.copy(s);forced.hand[1].ability.forced_selection=true
local restricted=B.run(forced,S)
eq(restricted.concealed_belief.candidates,256,'forced-card complete family')
eq(restricted.evaluations,256*12,'forced family complete in every world')
for _,c in ipairs(restricted.concealed_belief.comparisons)do eq(c.indices[1],1,'forced public slot always retained')end

-- Re-observing a revealed card changes public conditioning rather than reusing
-- a planned action or pretending the previous unknown assignment was known.
local revealed=Snapshot.copy(s);revealed.hand[1].face_down=false
check(B.run(revealed,S).concealed_belief.observation_fingerprint~=result.concealed_belief.observation_fingerprint,'fresh reveal gets fresh public belief')
local future=Snapshot.copy(s);future.hands_left=2;future.blind.chips=1000000
local fallback=B.run(future,S,{draws=Draws,sampled_outcomes=Outcomes,max_evaluations=7644})
check(fallback.concealed_belief.complete and not fallback.concealed_belief.continuation.complete,'incomplete future work does not invalidate complete immediate fallback')
eq(fallback.evaluations,7644,'continuation cannot spend beyond exact-fit budget')
eq(Snapshot.fingerprint(fallback.action),Snapshot.fingerprint(B.run(future,S).action),'partial future comparison cannot choose an action')
local routed=Decision.run(future,{concealed_belief=B,scoring=S,draws=Draws,sampled_outcomes=Outcomes,
 search={run=function()error('latent ordinary search forbidden')end}})
check(routed.concealed_belief.complete and routed.action,'production route yields a complete public action')
check(routed.evaluations<=8000,'current plus future work remains bounded')
eq(Snapshot.fingerprint(routed.action),Snapshot.fingerprint(B.run(future,S).action),'unqualified future family retains immediate action')
local transitions=0
local order_spy=setmetatable({after_play=function(...)transitions=transitions+1;return S.after_play(...)end},{__index=S})
local ordered=B.run(s,order_spy,{copy_order=function(public,common,incumbent,context)
 eq(#common,12,'copy helper shares twelve worlds');eq(context.remaining,356,'only unused budget reaches copy helper')
 for i=1,357 do context.after_play(common[1],incumbent.indices)end
 return nil,{complete=false}
end})
eq(transitions,356,'copy-order work cannot exceed remaining allowance');eq(ordered.evaluations,8000,'entire cap accounted')
eq(Snapshot.fingerprint(ordered.action),Snapshot.fingerprint(result.action),'incomplete order proposal never displaces action')
math.random=original_random
print('ten-card concealed362: '..checks..' checks; 637 candidates x 12 common worlds = 7644 actual scores')
