local Multi=dofile('Brainstorm/Advisor/multi_discard.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local checks=0
local function eq(a,b,l) checks=checks+1;assert(a==b,l..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(v,l) checks=checks+1;assert(v,l) end
local function card(id,rank,suit) return {id=id,rank=rank or 2,suit=suit or 'Spades',enhancement='c_base',ability={}} end
local function state()
  local s={phase='hand',hand={card('a',13),card('b',13),card('c',3),card('d',4)},deck={},playing_cards={},
    dollars=20,blind={chips=100},chips=0,hands_left=1,hands_played=0,discards_left=2,discards_used=0,
    hand_limit=5,hand_size=4,current_round={},modifiers={},hands={},jokers={},probabilities={normal=1}}
  for i=1,12 do s.deck[i]=card('pool'..i,2+i%13,i%2==0 and 'Hearts' or 'Clubs') end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function original(s) return {kind='discard',play={score=20,indices={1},hand='High Card'},discard={indices={1}}} end

local candidates=Multi.discard_candidates(state(),{2,1},3)
eq(#candidates,3,'fixed first-candidate cap')
eq(table.concat(candidates[1].indices,','),'1,2','incumbent normalized and kept first')
local s=state();s.hand[1].ability.forced_selection=true
candidates=Multi.discard_candidates(s,{2},3)
for _,candidate in ipairs(candidates) do local found=false;for _,i in ipairs(candidate.indices) do if i==1 then found=true end end;check(found,'all discards include forced card') end
s.hand_limit=2;candidates=Multi.discard_candidates(s,nil,3)
for _,c in ipairs(candidates) do check(#c.indices<=2,'live selection limit honored') end

-- Instrument a small deterministic game to isolate non-anticipation and paired
-- sampling. The actual candidate builder and exact source discard mechanics
-- have independent fixtures below and elsewhere in the suite.
local real_candidates=Multi.discard_candidates
Multi.discard_candidates=function(s,preferred,limit)
  return {{indices={1},key='1'},{indices={2},key='2'}}
end
local transitions,score_calls,inner_states={},0,{}
local fake={}
function fake.after_discard(s,indices)
  local out=Snapshot.copy(s);out.hand={}
  for i,c in ipairs(s.hand) do if i~=indices[1] then out.hand[#out.hand+1]=Snapshot.copy(c) end end
  if (s.discards_used or 0)==0 then out.first=indices[1] else out.second=indices[1] end
  out.discards_used=s.discards_used+1;out.discards_left=s.discards_left-1
  out.dollars=s.dollars-(s.modifiers.discard_cost or 0)
  transitions[#transitions+1]={before=s.discards_used,first=out.first,second=out.second,dollars=out.dollars}
  return out
end
function fake.score(s,indices)
  score_calls=score_calls+1
  if s.discards_used==2 then inner_states[#inner_states+1]={first=s.first,second=s.second,draw=s.hand[#s.hand].id} end
  return {legal=true,score=s.discards_used==2 and s.first==2 and 100 or 20}
end
local modules={scoring=fake,search={obvious_candidates=function() return {{1}} end},draws=Draws,sampled_outcomes=Outcomes}
s=state();local before=Snapshot.fingerprint(s)
local suggestion,n,diag=Multi.suggest(s,modules,original(s))
check(suggestion~=nil,'two-discard horizon can change first discard')
eq(suggestion.action.indices[1],2,'first action selected for its conditional second-draw prospects')
eq(suggestion.action.kind,'discard','only first discard is executable')
eq(suggestion.action.queue,nil,'no later action is queued')
eq(diag.baseline_probability,0,'incumbent uses same nested comparison')
eq(diag.estimated_probability,1,'supported synthetic policy succeeds in all nested samples')
eq(diag.completed_outer,4,'all four outer sets completed')
check(diag.complete,'diagnostics only qualify complete sets')
eq(n,score_calls,'all scoring calls counted')
check(n<=12000,'hard score budget')
eq(Snapshot.fingerprint(s),before,'nested transitions never mutate original snapshot')
local found={}
for _,entry in ipairs(inner_states) do
  local k=entry.first..':'..entry.second;found[k]=(found[k] or 0)+1
end
for _,count in pairs(found) do eq(count,16,'every evaluated second action receives all paired inner samples') end
local again,_,same=Multi.suggest(s,modules,original(s))
eq(again.action.indices[1],suggestion.action.indices[1],'deterministic first action')
eq(same.estimated_probability,diag.estimated_probability,'deterministic nested estimate')
local reversed=Snapshot.copy(s);reversed.deck={}
for i=#s.deck,1,-1 do reversed.deck[#reversed.deck+1]=s.deck[i] end
local reordered,_,rd=Multi.suggest(reversed,modules,original(reversed))
eq(reordered.action.indices[1],suggestion.action.indices[1],'input deck order never exposes future draw order')
eq(rd.estimated_probability,diag.estimated_probability,'composition-equivalent deck permutation gives same result')
suggestion,n,diag=Multi.suggest(s,modules,original(s),nil,{max_evaluations=17})
eq(suggestion,nil,'partial paired comparison never changes advice');eq(n,17,'exact hard cutoff');check(not diag.complete,'incomplete sets explicitly unqualified')

-- Make each second discard win a different half of the SAME unknown inner
-- worlds. A clairvoyant choose-after-draw maximum would incorrectly report1.
local inner_rolls={}
local conditional={roll=Outcomes.roll}
function conditional.fill(s,ordered,scorer,draws,seed,turn,bell)
  local out,reason=Outcomes.fill(s,ordered,scorer,draws,seed,turn,bell)
  if out and turn==2 then
    -- Four consecutive inner seeds differ by104729, an odd number.
    out.world=seed%2;inner_rolls[#inner_rolls+1]={second=s.second,world=out.world}
  end
  return out,reason
end
modules.sampled_outcomes=conditional
fake.score=function(s)
  return {legal=true,score=s.discards_used==2 and s.first==2 and s.world==(s.second-1) and 100 or 20}
end
suggestion,n,diag=Multi.suggest(s,modules,original(s))
check(suggestion~=nil,'conditional plan still has a real paired gain')
eq(diag.estimated_probability,0.5,'second action fixed before unknown outcome; no maximum across future worlds')
eq(diag.candidates[2].probability,0.5,'nested result averages selected conditional policy')
check(diag.scope:find('not 16 independent',1,true)~=nil,'nested dependence labeled')
modules.sampled_outcomes=Outcomes
fake.score=function() return {legal=true,score=20} end
suggestion,n,diag=Multi.suggest(s,modules,original(s))
eq(suggestion,nil,'no estimated survival gain keeps incumbent')
eq(diag.uplift,0,'zero uplift reported')

local results=original(s);results.play.score=100
eq(Multi.suggest(s,modules,results),nil,'reliable finishing hand protected')
for _,field in ipairs({'consumable','ordering','hand_ordering','boss_rescue','mixed_rescue','growth'}) do
  results=original(s);results[field]={action={kind='use'}}
  local out,count=Multi.suggest(s,modules,results);eq(out,nil,field..' existing plan protected');eq(count,0,field..' incurs no nested search')
end
s.discards_left=1;eq(Multi.suggest(s,modules,original(s)),nil,'one discard keeps ordinary search')
s.discards_left=2;s.hands_left=2;eq(Multi.suggest(s,modules,original(s)),nil,'multiple playable hands keep ordinary continuation')
s.hands_left=1;s.hand[1].face_down=true;eq(Multi.suggest(s,modules,original(s)),nil,'hidden held card fails closed')
s.hand[1].face_down=false
fake.score=function() return {legal=true,score=100,uncertain=true} end
suggestion,n,diag=Multi.suggest(s,modules,original(s))
eq(suggestion,nil,'uncertain average score is not counted as a sampled clear')
check(diag.reason:find('unsupported',1,true)~=nil,'unsupported score reason explicit')

-- Restore actual production candidate/action/scoring paths for trigger and
-- payment coverage. No test-only candidate generator is used below.
Multi.discard_candidates=real_candidates
modules={scoring=Scoring,search=Search,draws=Draws,sampled_outcomes=Outcomes}
s=state();s.hand[1].seal='Purple';s.hand[1].ability.forced_selection=true
suggestion,n,diag=Multi.suggest(s,modules,original(s))
eq(suggestion,nil,'Purple generation cannot be silently omitted from nested continuation')
check(diag.reason:find('unsupported',1,true)~=nil,'unsupported incumbent transition refuses the comparison')
s=state();s.modifiers.discard_cost=3;s.jokers={{key='j_burnt',ability={name='Burnt Joker',set='Joker'}}}
local calls={};local wrapped={score=Scoring.score}
wrapped.after_discard=function(state,indices)
  local after,effects=Scoring.after_discard(state,indices)
  if after then
    calls[#calls+1]={used=after.discards_used,before=state.dollars,after=after.dollars,
      before_hands=Snapshot.fingerprint(state.hands),after_hands=Snapshot.fingerprint(after.hands),burnt=effects.burnt_hand}
  end
  return after,effects
end
modules.scoring=wrapped
suggestion,n,diag=Multi.suggest(s,modules,original(s))
check(diag.complete,'exact Burnt/cost nested comparison completes')
local first,second=false,false
for _,c in ipairs(calls) do
  eq(c.before-c.after,3,'every exact discard pays live challenge cost')
  if c.used==1 then first=true;check(c.burnt~=nil,'first discard receives exact Burnt upgrade')
  elseif c.used==2 then second=true;eq(c.burnt,nil,'second discard never receives phantom Burnt upgrade') end
end
check(first and second,'both discard depths use exact transitions')
s=state();s.modifiers.discard_cost=2;s.jokers={{key='j_trading',ability={name='Trading Card',set='Joker',extra=5}}}
local destroyed,second_count=0,0
wrapped.after_discard=function(state,indices)
  local after,effects=Scoring.after_discard(state,indices)
  if after then
    if state.discards_used==0 and #indices==1 then
      destroyed=destroyed+1
      eq(#after.playing_cards,#state.playing_cards-1,'Trading first single removes exact physical population')
      eq(after.dollars-state.dollars,3,'Trading income and paid-discard cost both carried forward')
    elseif state.discards_used==1 then
      second_count=second_count+1
      eq(#after.playing_cards,#state.playing_cards,'Trading does not destroy again on second discard')
      eq(after.dollars-state.dollars,-2,'second paid discard receives no phantom Trading income')
    end
  end
  return after,effects
end
_,_,diag=Multi.suggest(s,modules,original(s))
check(diag.complete and destroyed>0 and second_count>0,'actual Trading transition is used at both depths')
s=state();s.blind.key='bl_final_bell';s.blind.name='Cerulean Bell';s.hand[1].ability.forced_selection=true
local forced_checks=0
wrapped.after_discard=function(state,indices)
  local chosen={};for _,i in ipairs(indices) do chosen[i]=true end
  for i,c in ipairs(state.hand) do if (c.ability or {}).forced_selection then
    forced_checks=forced_checks+1;check(chosen[i],'every Bell discard includes the freshly forced card')
  end end
  return Scoring.after_discard(state,indices)
end
_,_,diag=Multi.suggest(s,modules,original(s))
check(diag.complete and forced_checks>3,'both Bell draw depths sample new forced selection')
print('Multi-discard: '..checks..' checks passed (bounded nested conditional samples; no measured win-rate claim)')
