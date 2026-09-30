-- Routine synthetic fixtures; no preserved-state replay or source execution.
local Finish=dofile('Brainstorm/Advisor/resource_finish.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Multi=dofile('Brainstorm/Advisor/multi_discard.lua')
local Support=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank,suit,e)
  return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit or 'Spades',enhancement=e or 'c_base',ability={}}
end
local function state(n,hands)
  local s={phase='hand',ante=3,hand={},deck={},playing_cards={},jokers={},consumeables={},consumable_limit=2,
    hand_size=n,hand_limit=5,hands_left=hands,hands_played=0,discards_left=2,discards_used=0,
    blind={key='bl_small',chips=1000000},chips=0,dollars=15,current_round={},hands={},modifiers={},probabilities={normal=1}}
  local suits={'Spades','Hearts','Clubs','Diamonds'}
  for i=1,n do s.hand[i]=card('held'..i,2+(i-1)%13,suits[(i-1)%4+1]) end
  for i=1,24 do s.deck[i]=card('deck'..i,2+(i+3)%13,suits[(i+1)%4+1]) end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local modules={scoring=Scoring,search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=Multi,
  blind_finishing=Support,finish_rewards=Rewards}
local function result(s,play,discard)
  play=play or {1};discard=discard or {2,3}
  local p=Scoring.score(s,play);p.indices=play
  return {kind='discard',play=p,discard={indices=discard}}
end
do
  local s=state(9,4)
  s.hand={card('a',13,'Hearts'),card('b',13),card('c',13,'Clubs'),card('d',8),card('e',8,'Hearts'),
    card('f',4,'Diamonds'),card('g',5,'Hearts'),card('h',6,'Clubs'),card('i',7)}
  local classified=0;local choices=Finish.structural_candidates(s,Scoring,function() classified=classified+1;return true end)
  local groups={};for _,c in ipairs(choices) do groups[c.category]=true;check(Scoring.score(s,c.indices).legal,'representatives remain legal') end
  check(groups['Two Pair'] and groups['Full House'],'structural family includes Two Pair and Full House absent from obvious_candidates')
  check(groups.Straight and groups.Pair and groups['Three of a Kind'],'category cover retains alternative scoring families')
  check(#choices<=24 and classified==381,'nine cards classify exactly381 bounded subsets')
  s.blind={key='bl_eye',chips=1000000,hands={Straight=true,['Full House']=true}}
  choices=Finish.structural_candidates(s,Scoring)
  for _,c in ipairs(choices) do check(c.category~='Straight' and c.category~='Full House','Eye-used categories excluded before representative selection') end
  s.blind={key='bl_psychic',chips=1000000};s.hand[3].ability.forced_selection=true
  choices=Finish.structural_candidates(s,Scoring)
  for _,c in ipairs(choices) do local forced=false;for _,i in ipairs(c.indices) do forced=forced or i==3 end
    check(#c.indices==5 and forced,'Psychic size and forced card survive structural shortlisting') end
end
do
  local s=state(3,4);s.hand={card('a',14),card('b',14),card('c',14,'Spades','m_mult')}
  local choices=Finish.structural_candidates(s,Scoring);local enhanced=false
  for _,c in ipairs(choices) do if c.category=='Pair' then for _,i in ipairs(c.indices) do enhanced=enhanced or i==3 end end end
  check(enhanced,'same-rank Mult enhancement is represented instead of losing to lexicographic base-card ties')
  s.hand[3].enhancement='c_base';s.hand[3].seal='Red';choices=Finish.structural_candidates(s,Scoring);enhanced=false
  for _,c in ipairs(choices) do if c.category=='Pair' then for _,i in ipairs(c.indices) do enhanced=enhanced or i==3 end end end
  check(enhanced,'same-rank Red repetition receives a structural scoring representative')
end
do
  local s=state(10,5);s.blind={key='bl_final_bell',boss=true,chips=1000000};s.ante=8
  s.hand[2].ability.forced_selection=true;s.hand[8].enhancement='m_steel';s.hand[8].seal='Blue'
  local original=Snapshot.fingerprint(s);local r=result(s,{2},{1,2,3,4,5});local yields=0
  local _,n,d=Finish.suggest(s,modules,r,function() yields=yields+1 end)
  check(d.complete and d.completed_outer==4 and d.horizon==5,'five-hand ten-card Bell completes every first action and policy')
  check(n<=12000 and d.classifications<=150000 and yields>0,'score/classification/yield bounds are observed')
  eq(#d.candidates,15,'all three first actions cross all five globally fixed policies')
  for _,plan in ipairs(d.candidates) do
    eq(#plan.worlds,4,'every plan has every common world')
    for _,world in ipairs(plan.worlds) do
      check(world.hands==5 or world.win==1,'every Bell world finishes its remaining-hand horizon')
      local first_play=false;local future_discards=0
      for index,action in ipairs(world.actions) do
        if action.kind=='play' then first_play=true end
        if action.kind=='discard' and index>1 then
          check(first_play or plan.policy=='repeat_early' or plan.policy=='repeat_final','legacy later discard follows an actual first play')
          future_discards=future_discards+1
        end
      end
      local repeated=plan.policy=='repeat_early' or plan.policy=='repeat_final'
      check(future_discards<=(repeated and s.discards_left or 1),'later discards respect the declared fixed policy')
    end
  end
  eq(Snapshot.fingerprint(s),original,'Bell planning preserves all input state')
  local reverse=Snapshot.copy(s);reverse.deck={};for i=#s.deck,1,-1 do reverse.deck[#reverse.deck+1]=s.deck[i] end
  local _,again,other=Finish.suggest(reverse,modules,r)
  eq(again,n,'actual remaining-deck order cannot change the work performed')
  eq(Snapshot.fingerprint(other),Snapshot.fingerprint(d),'composition-identical reversed deck preserves every policy world')
  print('resource finish Bell: '..n..' scores / '..d.classifications..' classifications')
end
do
  local s=state(9,4);s.blind={key='bl_eye',chips=1000000};s.modifiers.discard_cost=2
  s.hand[1].enhancement='m_lucky';s.hand[1].ability={mult=20,p_dollars=20}
  s.deck[1].enhancement='m_glass';s.consumeables={{key='c_hanged_man',ability={name='The Hanged Man',set='Tarot'}}}
  local original=Snapshot.fingerprint(s);local saw_lucky,saw_cash=false,false
  local _,n,d=Finish.suggest(s,modules,result(s,{1},{2,3,4,5}))
  check(d.complete,'four-hand nine-card Eye carries supported Lucky through the full family: '..tostring(d.reason))
  check(d.policy_exhausted_worlds>0 and d.source_counterfactual==false and d.terminal_evidence==false,
    'known policy exhaustion is reported separately from source terminal evidence')
  local exhausted=0
  for _,plan in ipairs(d.candidates) do for _,world in ipairs(plan.worlds) do
    if world.policy_exhausted then exhausted=exhausted+1;check(world.hands_left>0,'policy exhaustion retains unspent hand resources explicitly') end
    local types={};for _,action in ipairs(world.actions) do
      if action.kind=='play' then
        check(not types[action.hand],'Eye world never repeats a used hand type');types[action.hand]=true
        saw_lucky=saw_lucky or action.sampled_lucky
      else eq(action.dollars_before-action.dollars_after,2,'paid discard costs are exact in every policy');saw_cash=true end
    end
  end end
  eq(exhausted,d.policy_exhausted_worlds,'policy-exhausted world count is explicit and auditable')
  check(saw_lucky and saw_cash,'synthetic Eye exercises actual sampled Lucky and discard cash')
  eq(Snapshot.fingerprint(s),original,'owned consumable and population remain untouched in the input')
  print('resource finish Eye: '..n..' scores / '..d.classifications..' classifications')
end
do
  local s=state(4,4);s.blind.chips=100;s.hand_size=4
  local fake={classify=Scoring.classify}
  function fake.score(before,indices)
    local hand,scoring=Scoring.classify(before,indices)
    return {legal=true,score=before.discards_used>0 and not before.first_discard and before.hands_played>0 and 100 or 1,
      indices=indices,hand=hand,scoring_indices=scoring,warnings={}}
  end
  local function remove(before,indices)
    local out=Snapshot.copy(before);local used={};for _,i in ipairs(indices) do used[i]=true end
    out.hand={};for i,c in ipairs(before.hand) do if not used[i] then out.hand[#out.hand+1]=Snapshot.copy(c) end end;return out
  end
  function fake.after_play(before,indices)
    local actual=fake.score(before,indices);local out=remove(before,indices)
    out.chips=before.chips+actual.score;out.hands_left=before.hands_left-1;out.hands_played=before.hands_played+1
    return out,{},actual
  end
  function fake.after_discard(before,indices)
    local out=remove(before,indices);out.discards_left=before.discards_left-1;out.discards_used=before.discards_used+1
    out.dollars=before.dollars-(before.modifiers.discard_cost or 0)
    if before.hands_played==0 then out.first_discard=true end;return out,{}
  end
  local m={scoring=fake,search=Search,draws=Draws,sampled_outcomes=Outcomes,multi_discard=Multi,blind_finishing=Support}
  local r={kind='discard',play={indices={1},score=1},discard={indices={2,3}}}
  local advice,n,d=Finish.suggest(s,m,r)
  check(advice and advice.action.kind=='play','controlled complete family can preserve a useful later discard')
  eq(d.baseline_probability,0,'incumbent receives its own best complete continuation policy')
  eq(d.estimated_probability,1,'one globally fixed alternative clears all controlled worlds')
  eq(advice.action.queue,nil,'only the first action is published')
  local again,_,repeat_d=Finish.suggest(s,m,r)
  eq(Snapshot.fingerprint(advice),Snapshot.fingerprint(again),'same input yields deterministic action')
  eq(Snapshot.fingerprint(d),Snapshot.fingerprint(repeat_d),'same input yields deterministic diagnostics')
  local none,count,cut=Finish.suggest(s,m,r,nil,{max_evaluations=17})
  check(not none and not cut.complete,'partial score comparisons never override');eq(count,17,'explicit smaller score cap is exact')
  none,count,cut=Finish.suggest(s,m,r,nil,{max_classifications=11})
  check(not none and not cut.complete,'partial classification comparisons never override');eq(cut.classifications,11,'classification cutoff is exact')
  local old=fake.after_play
  fake.after_play=function(before,indices,ctx)
    if before.hands_played==1 then return nil,'unsupported middle callback' end
    return old(before,indices,ctx)
  end
  none,_,cut=Finish.suggest(s,m,r)
  check(not none and not cut.complete and cut.reason:find('unsupported middle callback',1,true),'one unsupported middle transition invalidates entire comparison')
  fake.after_play=old
  local selected_mean=fake.score
  fake.score=function(before,indices)
    local p=selected_mean(before,indices);p.score=before.hands_left==1 and 1000 or 1;return p
  end
  fake.after_play=function(before,indices)
    local out,why,p=old(before,indices);out.chips=before.chips+1;p.score=1;return out,why,p
  end
  _,_,cut=Finish.suggest(s,m,r)
  check(cut.complete,'mean-versus-transition fixture completes')
  for _,plan in ipairs(cut.candidates) do eq(plan.probability,0,'an attractive final ordinary mean cannot fabricate an actual clearing transition') end
  fake.score=selected_mean;fake.after_play=old
  local crossed={roll=Outcomes.roll,fill=Outcomes.fill}
  crossed.after_play=function(before,indices,scorer,seed,turn)
    local out,why,p=old(before,indices)
    local win=before.first_discard and seed==2718281 or not before.first_discard and seed~=2718281
    p.score=turn==4 and win and 100 or 1;out.chips=before.chips+p.score
    return out,why,p
  end
  m.sampled_outcomes=crossed
  none,_,cut=Finish.suggest(s,m,r)
  check(not none and cut.complete and cut.override_rejected,'274 guard rejects crossed-world play override while later discard decisions remain omitted')
  eq(cut.aggregate_best.probability,.75,'crossed candidate aggregate gain remains visible without becoming authority')
  eq(cut.baseline.probability,.25,'incumbent winning world is preserved by the resource guard')
  m.sampled_outcomes=Outcomes
  s.modifiers.discard_cost=2;s.dollars=0
  none,_,cut=Finish.suggest(s,m,r)
  check(not none and not cut.complete and cut.reason:find('borrowing limit',1,true),'unaffordable incumbent first discard cannot establish a complete family')
  s.bankrupt_at=-2
  _,_,cut=Finish.suggest(s,m,r)
  check(cut.complete,'explicit signed borrowing allowance admits affordable compared discards')
  for _,plan in ipairs(cut.candidates) do for _,world in ipairs(plan.worlds) do
    check(world.dollars_after>=-2,'optional later discards respect the signed borrowing limit')
  end end
end
do
  local s=state(9,4);s.blind.chips=200;s.consumeables={{key='c_mercury',ability={set='Planet'}}}
  for _,c in ipairs(s.playing_cards) do c.seal='Blue' end
  local _,_,d=Finish.suggest(s,modules,result(s,{1},{2,3}))
  check(d.complete,'held Blue reward comparison completes with actual inventory capacity')
  local saw=false
  for _,plan in ipairs(d.candidates) do for _,world in ipairs(plan.worlds) do for _,action in ipairs(world.actions) do
    if action.finish_rewards then
      eq(action.finish_rewards.blue_planets,1,'clearing reward respects the one remaining ordinary inventory slot')
      eq(action.finish_rewards.planet_hand,action.hand,'Blue reward uses the actual final hand category');saw=true
    end
  end end end
  check(saw,'real synthetic scoring reaches a Blue-generating clearing endpoint')
  eq(#s.consumeables,1,'prospective finishing reward never creates inventory in the original snapshot')
  s.consumeables[2]={key='c_pluto',ability={set='Planet'}}
  _,_,d=Finish.suggest(s,modules,result(s,{1},{2,3}));check(d.complete,'whole full inventory is retained in complete resource policies')
  for _,plan in ipairs(d.candidates) do for _,world in ipairs(plan.worlds) do for _,action in ipairs(world.actions) do
    if action.finish_rewards then eq(action.finish_rewards.blue_planets,0,'full inventory blocks prospective Blue generation') end
  end end end
end
do
  local s=state(4,4);local r=result(s)
  for _,field in ipairs({'consumable','ordering','hand_ordering','boss_rescue','mixed_rescue','growth','fast_clear'}) do
    local protected=Snapshot.copy(r);protected[field]={};local none,n=Finish.suggest(s,modules,protected)
    check(not none and n==0,field..' priority requires no specialist work')
  end
  local protected=Snapshot.copy(r);protected.play.score=s.blind.chips
  local none,n=Finish.suggest(s,modules,protected);check(not none and n==0,'reliable current finish retains priority')
  s.jokers={{key='j_joker'}};check(not Finish.admits(s),'owned Jokers stay outside family')
  s.jokers={};s.used_vouchers={v_observatory=true};check(not Finish.admits(s),'Observatory remains outside family')
  s.used_vouchers={};s.hands_left=2;check(not Finish.admits(s),'supported small two-hand owned-Planet path retains its existing route')
  s.deck[1].enhancement='m_lucky';check(Finish.admits(s),'ordinary drawable Lucky admits the new complete sampled family')
  s.deck[1].enhancement='c_base';s.hands_left=3;check(not Finish.admits(s),'supported small three-hand path stays on existing module')
  s.hand_size=7;check(Finish.admits(s),'three-hand future size above six admits extension')
  s.hand_size=11;check(not Finish.admits(s),'oversized future hand rejected before work')
  s=state(4,4);s.hand[1].face_down=true;check(not Finish.admits(s),'initial concealment rejects identity-based policy')
  s=state(4,4);s.deck[1].id=s.hand[1].id;none,n=Finish.suggest(s,modules,result(s));check(not none and n==0,'duplicate physical identity rejected before work')
  s=state(4,4);s.modifiers.flipped_cards=4;local d;none,n,d=Finish.suggest(s,modules,result(s))
  check(not none and not d.complete,'unsupported future concealment invalidates all comparisons')
  s=state(4,4);s.hand[2].seal='Purple';s.hand[2].ability.forced_selection=true
  none,n,d=Finish.suggest(s,modules,result(s,{2},{2,3}))
  check(not none and not d.complete,'unsupported forced Purple discard fails closed')
  for _,field in ipairs({'dollars','chips','bankrupt_at','discards_left','hands_played'}) do
    s=state(4,4);s[field]=0/0;none,n,d=Finish.suggest(s,modules,result(s))
    check(not none and n==0 and not d.complete,'nonfinite '..field..' cannot produce completed policy evidence')
  end
  s=state(4,4);s.discards_left=1.5;none,n,d=Finish.suggest(s,modules,result(s))
  check(not none and n==0,'fractional discard resources are declined')
  s=state(4,4);s.modifiers.discard_cost='2';none,n,d=Finish.suggest(s,modules,result(s))
  check(not none and n==0,'malformed paid-discard cost is declined')
  s=state(4,4);s.deck[1].enhancement='m_unknown';none,n,d=Finish.suggest(s,modules,result(s))
  check(not none and n==0 and d.reason:find('Unknown',1,true),'unknown drawable enhancement stays explicit before any policy exhaustion')
  s=state(4,4);local missing={};for k,v in pairs(modules) do missing[k]=v end
  missing.sampled_outcomes={fill=Outcomes.fill,after_play=Outcomes.after_play}
  none,n,d=Finish.suggest(s,missing,result(s));check(not none and n==0,'missing private roll dependency fails before any work')
end
print('resource finish: '..checks..' checks passed; synthetic complete-family coverage, no measured win claim')
