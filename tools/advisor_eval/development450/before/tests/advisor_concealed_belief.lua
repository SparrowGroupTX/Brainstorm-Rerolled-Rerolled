local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(a,label) checks=checks+1;assert(a,label) end
local function c(id,rank,hidden,suit,enhancement)
  return {id=id,rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(rank,10),
    enhancement=enhancement or 'c_base',face_down=not not hidden,ability={}}
end
local function state(hand,deck)
  local s={phase='hand',hand=hand,deck=deck or {},playing_cards={},jokers={},consumeables={},hands={},
    hands_left=1,discards_left=0,hand_limit=5,hand_size=8,blind={key='bl_house',chips=50},chips=0,modifiers={}}
  for _,card in ipairs(hand) do s.playing_cards[#s.playing_cards+1]=card end
  for _,card in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=card end
  return s
end
local s=state({c('a',2,true),c('v',13,false),c('b',7,true)},{c('c',13,true),c('d',14,true),c('e',2,true)})
s.playing_cards[#s.playing_cards+1]=c('observed',4,false,'Hearts')
local frozen=Snapshot.fingerprint(s)
local o=assert(B.observe(s));eq(#o.pool,5);eq(#o.seen,1);eq(#o.slots,2)
eq(o.state.hand[1].rank,nil,'observation hides rank');eq(o.state.hand[1].suit,nil,'observation hides suit')
eq(o.state.hand[2].rank,13,'visible held rank fixed')
local before=assert(B.run(s,S));eq(before.kind,'play');eq(before.concealed_belief.complete,true)
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local yields=0
local routed=Decision.run(s,{concealed_belief=B,scoring=S,search={run=function() error('latent ordinary search') end},
  strategy={advise=function() error('latent strategy') end}},function() yields=yields+1 end)
eq(Snapshot.fingerprint(routed),Snapshot.fingerprint(before),'shared decision bypasses every latent candidate builder')
check(yields>0,'concealed score work yields to the existing frame budget')
local early=Snapshot.copy(s);early.hands_left=2
local stopped=Decision.run(early,{concealed_belief=B,scoring=S,search={run=function() error('latent search on unsupported horizon') end}})
eq(stopped.kind,'play','missing continuation dependencies retain an honest fixed-slot immediate play')
check(not stopped.concealed_belief.continuation.complete,'missing dependencies never claim a complete finish')
eq(before.play.uncertain,true);eq(before.play.hand,'Concealed hand');eq(before.play.reliable_bound,nil)
eq(before.evaluations,7*16,'all fixed subsets across all worlds')
for i=1,12 do
  local world=assert(B.world(o,i));local ids={};eq(#world.playing_cards,#s.playing_cards)
  eq(world.hand[2].rank,13);eq(world.playing_cards[#world.playing_cards].rank,4,'observed outside hand/deck fixed')
  for _,card in ipairs(world.playing_cards) do check(not ids[card.id],'synthetic identities unique');ids[card.id]=true end
  for _,card in ipairs(world.hand) do eq(card.face_down,false,'world assignment is internal scoring data') end
end
-- Preserve public slots and the unseen multiset while permuting physical IDs,
-- hidden payloads and deck order. No actual assignment may alter the action,
-- aggregate scores, observed key, or per-candidate evidence.
local p=Snapshot.copy(s)
p.hand[1],p.deck[2]=p.deck[2],p.hand[1]
p.hand[3],p.deck[1]=p.deck[1],p.hand[3]
p.deck[1],p.deck[3]=p.deck[3],p.deck[1]
local permuted=assert(B.run(p,S))
eq(Snapshot.fingerprint(before),Snapshot.fingerprint(permuted),'complete decision invariant under latent permutation')
for i=1,16 do eq(Snapshot.fingerprint(B.world(o,i)),Snapshot.fingerprint(B.world(assert(B.observe(p)),i)),'common worlds invariant') end
eq(Snapshot.fingerprint(s),frozen,'input untouched')
-- Same selection in every world: a per-world maximum would choose a different
-- slot and incorrectly report both aces as though it knew which slot held one.
local one=state({c('ace',14,true),c('low',2,true)})
one.hand_limit=1;one.blind.chips=16
local r=B.run(one,S,{samples=32})
eq(r.concealed_belief.candidates,2);check(r.play.score<16,'no per-world action oracle')
check(r.concealed_belief.sampled_clear<1,'not all worlds clear')
-- Mark conditions on face identity; Stone and Pareidolia follow Card:is_face(true).
local mark=state({c('face',13,true)},{c('small',2,true),c('queen',12,true),c('stone',11,true,'Hearts','m_stone')})
mark.blind={key='bl_mark',chips=10}
local mo=assert(B.observe(mark))
for i=1,32 do local world=B.world(mo,i);check(world.hand[1].rank==12 or world.hand[1].rank==13,'Mark supports faces only');eq(world.hand[1].enhancement,'c_base') end
eq(B.hidden_weight(mark,mark.deck[3]),0,'Stone has no face identity')
mark.deck[3].vampired=true;eq(B.hidden_weight(mark,mark.deck[3]),1,'Vampired Stone exposes base rank')
mark.jokers={{key='j_pareidolia'}};eq(B.hidden_weight(mark,mark.deck[1]),1);eq(B.hidden_weight(mark,mark.deck[3]),1)
mark.jokers[1].debuff=true;eq(B.hidden_weight(mark,mark.deck[1]),0,'inactive Pareidolia')
-- A mixed Mark/challenge concealment posterior uses product likelihoods,
-- not sequential probability-proportional-to-size draws.
local mixed=state({c('f',13,true),c('a',2,true)},{c('b',3,true)})
mixed.blind={key='bl_mark',chips=10};mixed.modifiers.flipped_cards=2
local mixed_o=assert(B.observe(mixed));local faces=0
for i=1,4096 do local world=B.world(mixed_o,i);for _,card in ipairs(world.hand) do if card.rank==13 then faces=faces+1 end end end
check(math.abs(faces/4096-.8)<.02,'joint conditioning: expected face inclusion 0.8, got '..faces/4096)
eq(B.hidden_weight(mixed,mixed.hand[1]),1);eq(B.hidden_weight(mixed,mixed.hand[2]),.5)
-- Slot constraints survive assignment and never follow a hidden physical card.
s.hand[1].ability.forced_selection=true
r=B.run(s,S);check(r.kind=='play');local forced=false;for _,i in ipairs(r.action.indices) do if i==1 then forced=true end end;check(forced)
for _,comparison in ipairs(r.concealed_belief.comparisons) do eq(comparison.indices[1],1) end
-- Equal target coverage conserves Glass and permanently debuffed population.
local glass=state({c('g',13,true,'Spades','m_glass'),c('s',13,true,'Spades','m_steel'),c('v',14,false)})
glass.blind.chips=10;glass.hand_limit=1
r=B.run(glass,S);eq(r.action.indices[1],3,'visible clear conserves hidden Glass')
-- All unsafe routes stop before touching the scorer or latent candidate code.
local calls=0;local spy={score=function()calls=calls+1;error('must not score')end}
local function stopped(t,label) local value=B.run(t,spy);eq(value.kind,'unsupported',label);eq(value.action,nil);eq(value.play,nil) end
local t=Snapshot.copy(s);t.hand[1].rank=nil;stopped(t,'missing rank')
t=Snapshot.copy(s);t.hand[1].suit=nil;stopped(t,'missing suit')
t=Snapshot.copy(s);t.playing_cards={};stopped(t,'unknown population')
t=Snapshot.copy(s);t.blind={key='bl_small'};stopped(t,'unknown concealment origin')
t=Snapshot.copy(s);t.jokers={{face_down=true}};stopped(t,'unknown Joker')
eq(calls,0)
t=Snapshot.copy(s);t.jokers={{key='j_unknown_modded'}};eq(B.run(t,S).kind,'unsupported','unmodeled score')
eq(B.run(s,S,{max_evaluations=1}).kind,'unsupported','no partial candidate comparison')
eq(B.run(state({c('v',14,false)}),spy),nil,'visible state bypasses belief route')
-- No use of global/game RNG.
math.randomseed(9167);local expected=math.random();math.randomseed(9167);B.run(s,S);eq(math.random(),expected)
print('concealed belief: '..checks..' checks passed')
