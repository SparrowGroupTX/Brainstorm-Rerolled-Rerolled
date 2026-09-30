local Finish=dofile('Brainstorm/Advisor/two_hand_finish.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Multi=dofile('Brainstorm/Advisor/multi_discard.lua')
local checks=0
local function check(v,l) checks=checks+1;assert(v,l) end
local function eq(a,b,l) check(a==b,l..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank,suit) return {id=id,rank=rank or 2,suit=suit or 'Spades',enhancement='c_base',ability={}} end
local function state()
  local s={phase='hand',hand={card('a',13),card('b',13),card('c',3),card('d',4)},deck={},playing_cards={},
    dollars=20,blind={key='bl_small',chips=100},chips=0,hands_left=2,hands_played=0,discards_left=1,discards_used=0,
    hand_limit=5,hand_size=4,current_round={},modifiers={},hands={},jokers={},probabilities={normal=1}}
  for i=1,12 do s.deck[i]=card('pool'..i,2+i%13,i%2==0 and 'Hearts' or 'Clubs') end
  for _,a in ipairs({s.hand,s.deck}) do for _,c in ipairs(a) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function original(s)
  return {kind='discard',play={score=20,indices={1},hand='High Card'},discard={indices={1}},
    resource_comparison={samples=4,full_remaining_horizon=true,future_discards=false,prior={probability=0}}}
end
local fake={};local play_calls,discard_calls=0,{}
function fake.score(s,indices)
  return {score=s.hands_left==1 and s.discards_used==1 and not s.first_discard and 80 or 20,
    legal=true,indices=indices,hand='High Card',scoring_indices=indices}
end
function fake.after_play(s,indices,context)
  play_calls=play_calls+1
  local out=Snapshot.copy(s);local score=fake.score(s,indices)
  local chosen={};for _,i in ipairs(indices) do chosen[i]=true end
  out.hand={};for i,c in ipairs(s.hand) do if not chosen[i] then out.hand[#out.hand+1]=Snapshot.copy(c) end end
  out.chips=s.chips+score.score;out.hands_left=s.hands_left-1;out.hands_played=s.hands_played+1
  return out,{},score
end
function fake.after_discard(s,indices)
  local out=Snapshot.copy(s);local chosen={};for _,i in ipairs(indices) do chosen[i]=true end
  out.hand={};for i,c in ipairs(s.hand) do if not chosen[i] then out.hand[#out.hand+1]=Snapshot.copy(c) end end
  out.discards_used=s.discards_used+1;out.discards_left=s.discards_left-1
  out.dollars=s.dollars-(s.modifiers.discard_cost or 0)
  if s.hands_left>1 then out.first_discard=true else out.second=indices[1] end
  discard_calls[#discard_calls+1]={hands=s.hands_left,indices=indices,dollars=out.dollars}
  return out,{}
end
local candidates={discard_candidates=function() return {{indices={1}},{indices={2}}} end}
local modules={scoring=fake,search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=candidates}
do
  local s=state();local hash=Snapshot.fingerprint(s)
  local advice,n,d=Finish.suggest(s,modules,original(s))
  check(advice and advice.action.kind=='play','two-hand lookahead can preserve the remaining discard for the final hand')
  eq(advice.action.indices[1],1,'publishes only the existing first play')
  eq(advice.action.queue,nil,'no hypothetical future action is queued')
  eq(d.baseline_probability,0,'incumbent initial discard receives the same conditional finishing policy')
  eq(d.estimated_probability,1,'controlled policy clears every nested world')
  check(d.complete and d.completed_outer==4,'all four paired outer worlds finish')
  check(n>0 and n<=12000,'score work stays within the existing specialist ceiling')
  eq(Snapshot.fingerprint(s),hash,'original state remains unchanged')
  local again,_,repeat_d=Finish.suggest(s,modules,original(s))
  eq(Snapshot.fingerprint(advice),Snapshot.fingerprint(again),'repeat action is deterministic')
  eq(Snapshot.fingerprint(d),Snapshot.fingerprint(repeat_d),'repeat diagnostics are deterministic')
  local reversed=Snapshot.copy(s);reversed.deck={};for i=#s.deck,1,-1 do reversed.deck[#reversed.deck+1]=s.deck[i] end
  local same,_,same_d=Finish.suggest(reversed,modules,original(reversed))
  eq(Snapshot.fingerprint(advice),Snapshot.fingerprint(same),'actual remaining-deck order never informs the first action')
  eq(same_d.estimated_probability,d.estimated_probability,'composition-equivalent deck order preserves samples')
  local none,count,cut=Finish.suggest(s,modules,original(s),nil,{max_evaluations=19})
  eq(none,nil,'partial score comparisons produce no override');eq(count,19,'score bound is exact');check(not cut.complete,'cutoff remains explicit')
end
do
  local saved_score=fake.score
  local observations={};local conditional={roll=Outcomes.roll,after_play=Outcomes.after_play}
  function conditional.fill(s,order,scorer,draws,seed,turn,bell)
    local out,reason=Outcomes.fill(s,order,scorer,draws,seed,turn,bell)
    if out and turn==3 then out.world=seed%2;observations[#observations+1]={second=s.second,world=out.world} end
    return out,reason
  end
  fake.score=function(s,indices)
    local win=s.hands_left==1 and s.discards_used==1 and not s.first_discard and s.world==s.second-1
    return {score=win and 80 or 20,legal=true,indices=indices,hand='High Card',scoring_indices=indices}
  end
  modules.sampled_outcomes=conditional
  local advice,_,d=Finish.suggest(state(),modules,original(state()))
  check(advice~=nil,'conditional sample fixture has a real nonzero gain')
  eq(d.estimated_probability,.5,'final discard is fixed before future identities, not chosen separately per inner world')
  local counts={};for _,v in ipairs(observations) do local key=v.second..':'..v.world;counts[key]=(counts[key] or 0)+1 end
  for _,count in pairs(counts) do eq(count,8,'each final discard receives every paired conditional world') end
  modules.sampled_outcomes=Outcomes;fake.score=saved_score
end
do
  local s=state()
  local p=original(s);p.play.score=100
  local none,n=Finish.suggest(s,modules,p);eq(none,nil,'reliable current finish is protected');eq(n,0,'current finish adds no work')
  p=original(s);p.fast_clear={};none,n=Finish.suggest(s,modules,p);eq(n,0,'fast-clear path does no specialist work')
  for _,field in ipairs({'consumable','ordering','hand_ordering','boss_rescue','mixed_rescue','growth'}) do
    p=original(s);p[field]={};none,n=Finish.suggest(s,modules,p);eq(none,nil,field..' remains protected');eq(n,0,field..' incurs no work')
  end
  p=original(s);p.resource_comparison.prior.probability=1;none,n=Finish.suggest(s,modules,p);eq(n,0,'existing sampled finishing plan is preserved')
  p=original(s);p.resource_comparison.best={probability=1};none,n=Finish.suggest(s,modules,p);eq(n,0,'already improved ordinary sampled finish also avoids extra work')
  p=original(s);p.resource_comparison=nil;none,n=Finish.suggest(s,modules,p);eq(n,0,'no costly extension without a complete ordinary comparison')
  s.hands_left=1;none,n=Finish.suggest(s,modules,original(s));eq(n,0,'last-hand Multi keeps its exclusive existing route')
  s.hands_left=3;none,n=Finish.suggest(s,modules,original(s));eq(n,0,'three-hand general planning is not implied')
  s.hands_left=2;s.hand[1].face_down=true;none,n=Finish.suggest(s,modules,original(s));eq(n,0,'initial hidden identities never reach candidate selection')
  s.hand[1].face_down=false;s.modifiers.flipped_cards=4
  local d;none,n,d=Finish.suggest(s,modules,original(s));check(not none and not d.complete,'unsupported future challenge visibility aborts the whole comparison')
  s.modifiers={};s.blind={key='bl_fish',name='The Fish',chips=100}
  none,n,d=Finish.suggest(s,modules,original(s));check(not none and not d.complete,'concealed Fish follow-up never exposes hidden cards to selection')
end
do
  local s=state();local old=fake.after_discard
  fake.after_discard=function(state,indices)
    if state.hands_left==1 and indices[1]==2 then return nil,'unsupported generation' end
    return old(state,indices)
  end
  local none,_,d=Finish.suggest(s,modules,original(s))
  check(not none and not d.complete and d.reason:find('unsupported generation',1,true),'unsupported alternative invalidates every partial outer set')
  fake.after_discard=old
end
do
  local s=state();s.blind.chips=10000;s.modifiers.discard_cost=3
  s.jokers={{key='j_burnt',ability={name='Burnt Joker',set='Joker'}}}
  local observed={}
  local wrapped={score=Scoring.score,after_play=Scoring.after_play}
  wrapped.after_discard=function(before,indices)
    local after,effects=Scoring.after_discard(before,indices)
    if after then observed[#observed+1]={before=before,after=after,effects=effects} end
    return after,effects
  end
  local real={scoring=wrapped,search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=Multi}
  local _,n,d=Finish.suggest(s,real,original(s))
  check(d.complete,'real scoring and exact Burnt discard transitions complete both hand depths')
  local initial,final=false,false
  for _,v in ipairs(observed) do
    eq(v.before.dollars-v.after.dollars,3,'paid discard cash is carried through every exact transition')
    check(v.effects.burnt_hand~=nil,'first discard receives Burnt even when it is saved for the final hand')
    if v.before.hands_left==2 then initial=true else final=true end
  end
  check(initial and final,'Burnt is evaluated both before and after the first real play')
  print('two-hand real scorer: '..d.completed_outer..' complete paired worlds, '..n..' score evaluations')
  s.jokers={};s.hand[1].seal='Purple';s.hand[1].ability.forced_selection=true
  local none;none,_,d=Finish.suggest(s,real,original(s))
  check(not none and not d.complete,'real unsupported Purple generation fails closed')
end
do
  local s=state();s.blind.chips=100000;s.hand_size=8
  for i=1,4 do s.hand[#s.hand+1]=table.remove(s.deck,1) end
  local real={scoring=Scoring,search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=Multi}
  local _,n,d=Finish.suggest(s,real,original(s))
  check(d.complete and n<=12000,'full eight-card hand compares all legal subsets within the existing specialist ceiling')
  print('two-hand eight-card scorer: '..n..' score evaluations')
end
do
  local s=state();s.blind.chips=10000;s.probabilities.normal=4
  s.hand[1].enhancement='m_glass'
  s.jokers={{key='j_glass',ability={name='Glass Joker',set='Joker',x_mult=1,extra=.75}}}
  local destroyed,played=0,0
  local wrapped={score=Scoring.score,after_discard=Scoring.after_discard}
  wrapped.after_play=function(before,indices,context)
    played=played+1
    local after,effects,result=Scoring.after_play(before,indices,context)
    if after then
      eq(#after.deck,#before.deck,'playing removes cards from the held area before any replacement draw')
      eq(after.hands_left,before.hands_left-1,'exact play consumes one playable hand')
      for _,lost in ipairs(effects.destroyed_cards or {}) do
        destroyed=destroyed+1
        for _,area in ipairs({after.hand,after.deck,after.playing_cards}) do for _,c in ipairs(area) do
          check(c.id~=lost.id,'destroyed Glass physical identity is absent from every later population')
        end end
      end
      eq(#after.playing_cards,#before.playing_cards+(effects.population_delta or 0),'full population change matches exact play effects')
      if #(effects.destroyed_cards or {})>0 then
        eq(after.jokers[1].ability.x_mult,before.jokers[1].ability.x_mult+.75*#effects.destroyed_cards,'Glass Joker growth enters the next scoring state')
      end
    end
    return after,effects,result
  end
  local real={scoring=wrapped,search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=Multi}
  local _,_,d=Finish.suggest(s,real,original(s))
  check(d.complete and played>0 and destroyed>0,'both first actions carry actual certain Glass destruction through the complete comparison')
  s=state();s.blind.chips=10000
  s.jokers={{key='j_yorick',ability={name='Yorick',set='Joker',x_mult=1,yorick_discards=1,extra={discards=23,xmult=1}}}}
  wrapped.after_play=Scoring.after_play
  local progress=0
  wrapped.after_discard=function(before,indices)
    local after,effects=Scoring.after_discard(before,indices)
    if after then
      progress=progress+1
      eq(after.jokers[1].ability.x_mult,2,'Yorick exact threshold growth applies before either next play')
      eq(after.jokers[1].ability.yorick_discards,24-#indices,'Yorick remainder tracks the actual discarded count')
    end
    return after,effects
  end
  _,_,d=Finish.suggest(s,real,original(s))
  check(d.complete and progress>4,'saved final-hand discards preserve exact Yorick progress')
end
do
  local s=state();s.hands_left=3;s.blind.chips=120
  local p=original(s);p.resource_comparison.horizon=3
  local original_key=Snapshot.fingerprint(s)
  local advice,n,d=Finish.suggest(s,modules,p)
  check(advice and advice.action.kind=='play' and advice.horizon==3,'three-hand plan can preserve the final redraw across an observed middle play')
  check(d.complete and d.completed_outer==4 and d.baseline_probability==0 and d.estimated_probability==1,'every three-hand branch receives the same complete conditional final policy')
  check(n>0 and n<=12000,'three-hand work shares the same specialist allowance')
  eq(Snapshot.fingerprint(s),original_key,'three-hand planning never mutates real resources')
  local none,count,cut=Finish.suggest(s,modules,p,nil,{max_evaluations=35})
  eq(none,nil,'partial three-hand comparisons never override');eq(count,35,'three-hand score cap remains exact')
  local old=fake.after_play
  fake.after_play=function(state,indices,context)
    if state.hands_left==2 then return nil,'unknown middle growth' end
    return old(state,indices,context)
  end
  none,_,cut=Finish.suggest(s,modules,p)
  check(not none and not cut.complete and cut.reason:find('unknown middle growth',1,true),'unknown intermediate transitions invalidate the whole comparison')
  fake.after_play=old
  s.hand_size=7
  none,count=Finish.suggest(s,modules,p);eq(count,0,'three-hand work excludes larger hands before expensive scoring')
  s.hand_size=4;s.blind.chips=100000;s.modifiers.discard_cost=2
  local observed=0
  local real={scoring={score=Scoring.score,after_play=function(state,indices,context)
      local after,effect,score=Scoring.after_play(state,indices,context)
      if state.hands_left==2 and after then observed=observed+1;eq(after.hands_left,1,'real middle hand consumes its exact resource') end
      return after,effect,score
    end,after_discard=Scoring.after_discard},search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=Multi}
  _,n,d=Finish.suggest(s,real,p)
  check(d.complete and observed==8 and n<=12000,'three-hand actual scoring and transitions complete every admitted comparison')
  print('three-hand real scorer: '..n..' evaluations / '..observed..' exact middle transitions')
end
print('two/three-hand finish: '..checks..' checks passed (bounded nested policy; no measured win claim)')
