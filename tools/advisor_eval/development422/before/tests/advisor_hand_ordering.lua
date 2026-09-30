local Ordering=dofile('Brainstorm/Advisor/hand_ordering.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function equal(a,b,message) check(a==b,(message or 'Mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local next_id=0
local function card(rank,suit,enhancement)
  next_id=next_id+1
  return {id='card'..next_id,rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(10,rank),
    enhancement=enhancement or 'c_base',ability={}}
end
local function joker(name,extra) return {name=name,ability={name=name,extra=extra},blueprint_compat=true} end
local function state(hand,jokers,target)
  return {phase='hand',hand=hand,playing_cards=hand,deck={},consumeables={},jokers=jokers or {},hands={},
    blind={chips=target or 200},chips=0,dollars=10,hands_left=3,hands_played=0,discards_left=0,
    hand_limit=5,hand_size=#hand,probabilities={normal=1},modifiers={},current_round={}}
end
local function result(s,indices)
  local play=Scoring.score(s,indices);play.indices=indices
  return {kind='play',play=play}
end
local function reorder(s,order)
  local projected=Snapshot.copy(s);projected.hand={}
  for i,index in ipairs(order) do projected.hand[i]=Snapshot.copy(s.hand[index]) end
  return projected
end
local function photochad(target)
  return state({card(13,'Hearts'),card(2,'Clubs','m_steel'),card(13,'Diamonds','m_mult'),card(7,'Spades')},
    {joker('Photograph',2),joker('Hanging Chad',2),joker('Raised Fist')},target or 2500)
end
local function skip(s,base,needle,options)
  local use,evaluations,diagnostics=Ordering.suggest(s,Scoring,base,nil,options)
  equal(use,nil,'Expected no extra rearrangement')
  check(diagnostics.reason and diagnostics.reason:find(needle,1,true),'Unexpected skip reason: '..tostring(diagnostics.reason))
  return evaluations,diagnostics
end

local old_random,old_seed,old_pseudo,old_pseudoseed=math.random,math.randomseed,pseudorandom,pseudoseed
math.random=function() error('Hand ordering used global RNG') end
math.randomseed=function() error('Hand ordering seeded global RNG') end
pseudorandom=function() error('Hand ordering used game RNG') end
pseudoseed=function() error('Hand ordering used game seed') end

do
  local s=photochad();local base=result(s,{1,3})
  local before=Snapshot.fingerprint(s);local before_result=Snapshot.fingerprint(base)
  equal(base.play.score,1700,'Original Photograph/Chad/held-card score')
  local use,evaluations,diagnostics=Ordering.suggest(s,Scoring,base)
  check(use,'Photograph/Chad ordering can rescue a blind')
  equal(use.action.kind,'reorder_hand');equal(use.action.area,'hand')
  equal(table.concat(use.action.order,','),'3,2,1,4','Only the two selected slots are exchanged')
  equal(table.concat(use.selected_indices,','),'1,3','Chosen physical card set remains the same')
  equal(table.concat(use.play.indices,','),'1,3','Projected play uses the same slots after rearranging')
  equal(use.play.hand,'Pair');equal(use.baseline_play.score,1700);equal(use.play.score,5600)
  equal(use.play,use.projected_play);equal(evaluations,2);equal(diagnostics.completed_orders,2)
  equal(diagnostics.partial_orders,0);equal(diagnostics.truncated,false)
  equal(Snapshot.fingerprint(s),before,'The complete input snapshot is unchanged')
  equal(Snapshot.fingerprint(base),before_result,'Published result is unchanged')
  equal(Snapshot.fingerprint(use),Snapshot.fingerprint(Ordering.suggest(s,Scoring,base)),'Repeated unchanged state gives identical advice')
  check(table.concat(use.lines,' '):find('Refresh advice',1,true),'Instructions require fresh advice before play')
  local after=reorder(s,use.action.order)
  equal(after.hand[2].id,s.hand[2].id,'Held Steel stays in place')
  equal(after.hand[4].id,s.hand[4].id,'Other held card stays in place')
  equal(Scoring.score(after,use.play.indices).score,5600,'True scorer agrees after applying the full permutation')
  local no_more,work=Ordering.suggest(after,Scoring,result(after,{1,3}))
  equal(no_more,nil,'No bounce after the rearrangement');equal(work,0,'A current clearing order needs no more permutation work')
end

do
  local s=state({card(13,'Hearts'),card(13,'Clubs','m_mult')},{joker('Photograph',2)},300)
  local use=Ordering.suggest(s,Scoring,result(s,{1,2}))
  equal(use.baseline_play.score,240);equal(use.play.score,360,'Photograph alone benefits from Mult on its first face')
  s=state({card(2,'Hearts'),card(2,'Clubs')},{joker('Hanging Chad',2)},200)
  s.hand[2].edition={foil=true}
  use=Ordering.suggest(s,Scoring,result(s,{1,2}))
  equal(use.baseline_play.score,136);equal(use.play.score,336,'Chad retriggers a valuable nonface Foil card first')
  s=state({card(14,'Spades'),card(14,'Hearts','m_mult')},{joker('The Idol',2)},300)
  s.current_round.idol_card={id=14,suit='Spades'}
  use=Ordering.suggest(s,Scoring,result(s,{1,2}))
  equal(use.baseline_play.score,256);equal(use.play.score,384,'Add Mult before the Idol matching card multiplies it')
  equal(table.concat(use.action.order,','),'2,1')
end

do
  local s=state({card(2,'Spades','m_glass'),card(3,'Hearts','m_mult'),card(4,'Clubs'),card(5,'Diamonds'),card(6,'Spades')},{},750)
  local base=result(s,{1,2,3,4,5});equal(base.play.score,600)
  local calls,yields=0,0
  local scorer={score=function(projected,indices)
    calls=calls+1;equal(table.concat(indices,','),'1,2,3,4,5','Every permutation scores exactly the same selected slots')
    return Scoring.score(projected,indices)
  end}
  local use,evaluations,diagnostics=Ordering.suggest(s,scorer,base,function() yields=yields+1 end)
  check(use,'Card enhancement order works without any Joker')
  equal(use.play.score,800);equal(use.play.hand,'Straight')
  equal(evaluations,120,'All five-card permutations are bounded at 120 calls')
  equal(calls,evaluations);equal(yields,3);equal(diagnostics.possible_orders,120)
  equal(diagnostics.completed_orders,120);equal(diagnostics.partial_orders,0);equal(diagnostics.truncated,false)
  equal(table.concat(use.action.order,','),'2,1,3,4,5','First useful clear wins equal-score alternatives')
  use,evaluations,diagnostics=Ordering.suggest(s,Scoring,base,nil,{max_evaluations=24})
  equal(use,nil,'Budget cannot claim an unseen better permutation');equal(evaluations,24);check(diagnostics.truncated)
  use,evaluations,diagnostics=Ordering.suggest(s,Scoring,base,nil,{max_evaluations=25})
  check(use,'A completely scored improvement can be reported within a partial permutation shortlist')
  equal(evaluations,25);equal(use.play.score,800);equal(diagnostics.partial_orders,0);check(diagnostics.truncated)
  check(#use.warnings>1,'Limited coverage is explicit')
  evaluations=skip(s,base,'budget', {max_evaluations=1});equal(evaluations,0,'No baseline-only comparison is started')
end

do
  local s=photochad();s.hand[1].pinned=true
  local work=skip(s,result(s,{1,3}),'Pinned');equal(work,0)
  s=photochad();s.hand[2].pinned=true
  local use=Ordering.suggest(s,Scoring,result(s,{1,3}));check(use,'Pinned unselected cards do not prohibit moving the chosen cards')
  equal(use.action.order[2],2)
  s=photochad();s.hand[1].ability.forced_selection=true
  use=Ordering.suggest(s,Scoring,result(s,{1,3}));check(use,'A forced card may move while remaining in the chosen set')
  equal(use.action.order[3],1);local after=reorder(s,use.action.order)
  check(after.hand[3].ability.forced_selection);check(Scoring.score(after,use.play.indices).legal,'Forced card remains in projected play')
  s.hand[2].ability.forced_selection=true
  skip(s,{kind='play',play={score=1700,indices={1,3}}},'forced')
  s=photochad();s.hand[1].face_down=true;skip(s,result(s,{1,3}),'Reveal')
  s=photochad();s.hand_shuffling=true;skip(s,result(s,{1,3}),'movement')
  s=photochad();s.hand[1].states={drag={can=false}};skip(s,result(s,{1,3}),'cannot be moved')
  s=photochad();s.phase='shop';skip(s,result(s,{1,3}),'settled hand')
  s=photochad();skip(s,{play={score=1700,indices={1,1}}},'distinct')
  skip(s,{play={score=1700,indices={1,5}}},'distinct')
  skip(s,{play={score=1700,indices={[1]=1,[3]=3}}},'distinct')
end

do
  local s=photochad(1000);skip(s,result(s,{1,3}),'overkill')
  s=photochad(10000);local base=result(s,{1,3})
  local use=Ordering.suggest(s,Scoring,base);check(use,'A meaningful gain can help with further hands available')
  s.hands_left=1;skip(s,base,'final hand')
  s.hands_left=3;base.kind='discard';skip(s,base,'discard plan')
  s.blind.chips=5000
  use=Ordering.suggest(s,Scoring,base);check(use,'An immediate reorder clear can replace discarding')
  s.blind.chips=6000;base.kind='play';base.consumable={play={score=52},sequence={play={score=7000}}}
  skip(s,base,'existing consumable')
  base.consumable=nil;base.ordering={play={score=7000}};skip(s,base,'existing Joker-order')
  s.blind.chips=5000;base.ordering=nil;base.consumable={sequence={play={score=7000}}}
  use=Ordering.suggest(s,Scoring,base);check(use,'An immediate reorder clear may save both consumables')
  s.blind={chips=5000,key='bl_arm',name='The Arm'}
  s.hands.Pair={level=2,chips=25,mult=3,l_chips=15,l_mult=1}
  base=result(s,{1,3});base.play.arm_cost=9;base.consumable={play={score=6000,arm_cost=1}}
  skip(s,base,'The Arm')
end

do
  local s=photochad();local base=result(s,{1,3});base.play.score=999
  local work=skip(s,base,'published score');equal(work,1,'A baseline mismatch stops before alternative scoring')
  s=photochad();s.jokers[#s.jokers+1]=joker('Misprint',{min=0,max=23})
  skip(s,result(s,{1,3}),'Uncertain')
  s=state({card(14)},{joker('DNA',1)},100)
  local work=skip(s,result(s,{1}),'two to five');equal(work,0,'DNA single-card play has no ordering permutation')
  s=state({card(13,'Hearts'),card(7,'Spades','m_steel'),card(13,'Clubs'),card(2,'Diamonds')},{joker('Raised Fist')},240)
  local base=result(s,{1,3});equal(base.play.score,210)
  skip(s,base,'current played-card order')
  local changed_held=reorder(s,{1,4,3,2})
  equal(Scoring.score(changed_held,{1,3}).score,270,'Held Steel/Raised Fist opportunity is deliberately a separate feature')
end

do
  local hand={card(13,'Hearts')};for i=2,12 do hand[i]=card(2,'Spades') end;hand[13]=card(13,'Clubs','m_mult')
  local s=state(hand,{joker('Photograph',2),joker('Hanging Chad',2)},2000)
  local use,work=Ordering.suggest(s,Scoring,result(s,{1,13}))
  check(use,'An enlarged hand retains played-card ordering')
  equal(work,2);equal(#use.action.order,13);equal(use.action.order[1],13);equal(use.action.order[13],1)
  for i=2,12 do equal(use.action.order[i],i,'Every unselected enlarged-hand position is preserved') end
  equal(use.play.score,3600)
end

math.random,math.randomseed,pseudorandom,pseudoseed=old_random,old_seed,old_pseudo,old_pseudoseed
do
  local s=state({card(2,'Spades','m_glass'),card(3,'Hearts','m_mult'),card(14)},
    {joker('Splash'),joker('Cavendish',{Xmult=3}),joker('Joker')},230)
  local base=result(s,{1,2});equal(base.play.score,220)
  local harmful_order=Ordering.suggest(s,Scoring,base)
  check(harmful_order,'The chosen Glass/Mult card order could otherwise be offered')
  equal(harmful_order.play.score,340)
  local free=Snapshot.copy(s);free.jokers={free.jokers[1],free.jokers[3],free.jokers[2]}
  local safe_play=Scoring.score(free,{3});safe_play.indices={3};safe_play.future_loss=0
  equal(safe_play.score,240,'Reordering Jokers instead clears with the lone Ace and preserves Glass')
  base.ordering={play=safe_play,action={kind='reorder_jokers',order={1,3,2}}}
  local work=skip(s,base,'existing Joker-order')
  equal(work,0,'Keep an already clearing free plan before doing competing permutation work')
end
print('advisor_hand_ordering: '..checks..' checks passed')
