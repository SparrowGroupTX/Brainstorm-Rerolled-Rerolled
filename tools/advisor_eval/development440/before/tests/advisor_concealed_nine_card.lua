-- Manufactured finite populations only; no captured state or source execution.
local function previous_limit()
 local f=assert(io.open('Brainstorm/Advisor/concealed_belief.lua','rb'));local text=f:read('*a');f:close()
 local a,b;text,a=text:gsub('#s%.hand>12','#s.hand>8',1);text,b=text:gsub('#state%.hand>9','#state.hand>8',1)
 assert(a==1 and b==1,'Expected bounded current and future admissions')
 text=text:gsub('at most twelve held cards','at most eight held cards',1)
 return assert(loadstring(text,'@manufactured_previous_concealed_limit'))()
end
local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local Baseline=previous_limit()
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function state()
 local s={phase='hand',ante=2,round=5,hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},
  hand_size=9,hand_limit=5,hands_left=1,discards_left=0,blind={key='bl_house',name='The House',chips=2000},
  chips=0,dollars=20,bankrupt_at=0,modifiers={},probabilities={normal=1}}
 for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'})do for rank=2,14 do
  local card={id=suit..rank,rank=rank,suit=suit,nominal=rank==14 and 11 or math.min(rank,10),
   enhancement='c_base',face_down=true,ability={}}
  s.playing_cards[#s.playing_cards+1]=card
  if #s.hand<9 then s.hand[#s.hand+1]=card else s.deck[#s.deck+1]=card end
 end end
 s.hand[9].face_down=false
 return s
end
local function spy_state(world)
 local ids={}
 eq(#world.hand,9,'all fixed immediate actions use nine-card worlds')
 eq(#world.deck,43,'draw population stays partitioned')
 eq(#world.playing_cards,52,'whole physical population is conserved')
 for _,area in ipairs({world.hand,world.deck})do for _,card in ipairs(area)do
  check(not ids[card.id],'sampled hand/deck physical identities are unique');ids[card.id]=true
 end end
 eq(world.hand[9].rank,10,'the visible ninth card is fixed')
end
local before=state();local original=Snapshot.fingerprint(before)
local old_random=math.random;math.random=function()error('nine-card belief cannot use global RNG')end
local calls,world_ids,next_id,family=0,{},0,{}
local spy=setmetatable({lower_bound=function(world,indices)
 calls=calls+1
 if not world_ids[world]then next_id=next_id+1;world_ids[world]=next_id;spy_state(world)end
 local key=table.concat(indices,',');family[key]=family[key] or {};local id=world_ids[world]
 family[key][id]=(family[key][id] or 0)+1
 return S.lower_bound(world,indices)
end},{__index=S})
local rejected=Baseline.run(before,spy)
eq(rejected.kind,'unsupported','old eight-card guard rejects this public shape');eq(calls,0,'baseline rejection costs no score work')
local result=B.run(before,spy)
eq(result.kind,'play','complete nine-card immediate comparison produces a supported fixed action')
check(result.concealed_belief.complete and result.concealed_belief.supported,'immediate family is complete and supported')
eq(result.concealed_belief.candidates,381,'every subset of one through five cards is admitted')
eq(result.concealed_belief.worlds,16,'default common-world count is unchanged')
eq(calls,6096,'381 fixed actions across sixteen complete worlds')
eq(result.evaluations,6096,'reported work matches actual production lower-bound calls')
eq(next_id,16,'the same sixteen world objects support every fixed candidate')
local candidates=0
for _,worlds in pairs(family)do candidates=candidates+1;for id=1,16 do eq(worlds[id],1,'each fixed candidate is scored once in each common world')end end
eq(candidates,381,'no candidate was dropped or repeated')
eq(Snapshot.fingerprint(before),original,'all public and latent input data remain untouched')

-- Latent assignments and physical IDs are not public action-selection data.
local permuted=Snapshot.copy(before)
permuted.hand[1],permuted.deck[3]=permuted.deck[3],permuted.hand[1]
permuted.hand[8],permuted.deck[20]=permuted.deck[20],permuted.hand[8]
permuted.deck[1],permuted.deck[40]=permuted.deck[40],permuted.deck[1]
eq(Snapshot.fingerprint(B.run(permuted,S)),Snapshot.fingerprint(result),'whole result is invariant under hidden assignment/deck-order permutation')
for _,area in ipairs({permuted.hand,permuted.deck,permuted.playing_cards})do for _,card in ipairs(area)do card.id='renamed:'..card.id end end
eq(Snapshot.fingerprint(B.run(permuted,S)),Snapshot.fingerprint(result),'physical identity spelling does not change hidden beliefs or actions')

local forbidden_calls=0
local forbidden={lower_bound=function()forbidden_calls=forbidden_calls+1;error('over-cap admission must not call scorer')end}
local too_many=B.run(before,forbidden,{samples=32})
eq(too_many.kind,'unsupported','32-world nine-card family is rejected before partial evaluation')
eq(too_many.evaluations,0,'over-cap family has no score work');eq(forbidden_calls,0,'no over-cap callback ran')
local eleven=Snapshot.copy(before);for i=1,4 do eleven.hand[#eleven.hand+1]=table.remove(eleven.deck)end
eq(B.run(eleven,forbidden,{samples=4}).kind,'unsupported','thirteen held cards remain explicitly unsupported')
eq(forbidden_calls,0,'larger hands are rejected before scoring')

local forced=Snapshot.copy(before);forced.hand[2].ability.forced_selection=true
local restricted=B.run(forced,S)
eq(restricted.concealed_belief.candidates,163,'forced slot reduces complete candidate family exactly')
eq(restricted.evaluations,163*16,'forced-family work remains complete')
for _,c in ipairs(restricted.concealed_belief.comparisons)do
 local present=false;for _,index in ipairs(c.indices)do if index==2 then present=true end end
 check(present,'every admitted play preserves the public forced slot')
end

-- Nine-card future observations use the existing <=8 public candidates and
-- charge every current/future score against the same unchanged 8,000 budget.
local future=state();future.hands_left=2;future.discards_left=1;future.blind.chips=10
local observed_nine=0;local public=B.public_candidates
B.public_candidates=function(s,discard)
 local family=public(s,discard)
 if not discard and #s.hand==9 then observed_nine=observed_nine+1;check(#family<=8,'complete nine-card future family fits old candidate bound')end
 return family
end
local transitions=0
local physical=setmetatable({after_play=function(s,indices,context)
 local after,effects,prediction=S.after_play(s,indices,context)
 if after then
  transitions=transitions+1
  eq(#after.playing_cards,#s.playing_cards+(effects.population_delta or 0),'future play conserves physical population with exact loss')
  local ids={};for _,area in ipairs({after.hand,after.deck})do for _,card in ipairs(area)do check(not ids[card.id],'future held/deck identities do not duplicate');ids[card.id]=true end end
 end
 return after,effects,prediction
end},{__index=S})
local continued=B.run(future,physical,{draws=Draws,sampled_outcomes=Outcomes})
check(continued.concealed_belief.continuation.complete,'admitted nine-card future observations finish the whole existing family')
check(observed_nine>0 and transitions>0,'future nine-card guard and exact transitions were actually reached')
eq(continued.concealed_belief.continuation.future_candidate_limit,8,'future family cap remains eight')
check(continued.evaluations<=8000,'complete current-plus-future work stays within old cap')
local limited=B.run(future,S,{draws=Draws,sampled_outcomes=Outcomes,max_evaluations=6096})
check(limited.concealed_belief.complete,'full immediate family remains valid at its exact cost')
check(not limited.concealed_belief.continuation.complete,'incomplete future family receives no decision credit')
eq(limited.evaluations,6096,'future fallback cannot exceed even the lower supplied cap')
local immediate=B.run(future,S)
eq(Snapshot.fingerprint(limited.action),Snapshot.fingerprint(immediate.action),'partial future coverage falls back to the complete immediate action')
B.public_candidates=public
local routed=Decision.run(before,{concealed_belief=B,scoring=S,search={run=function()error('nine-card hidden hand cannot use latent ordinary search')end}})
eq(Snapshot.fingerprint(routed),Snapshot.fingerprint(result),'shared runtime decision uses the bounded concealed route')
math.random=old_random
print('nine-card concealed admission: '..checks..' checks passed; immediate=6096; continued='..continued.evaluations)
