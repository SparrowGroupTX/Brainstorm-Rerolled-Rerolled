local Ordering=dofile('Brainstorm/Advisor/ordering.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local function equal(a,b,message) check(a==b,message..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(rank,suit)
  return {rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(rank,10),enhancement='c_base',ability={}}
end
local function joker(name,ability,key)
  local a=ability or {}; a.name=name
  return {key=key,name=name,ability=a,blueprint_compat=true}
end
local function state(jokers,hand,target)
  return {phase='hand',jokers=jokers,hand=hand or {card(14)},deck={},playing_cards=hand or {card(14)},
    blind={chips=target or 200},chips=0,hands={},dollars=10,hands_left=3,discards_left=0,
    hand_limit=5,probabilities={normal=1},modifiers={},current_round={}}
end
local function base(s)
  return Search.run(s,Scoring,{max_evaluations=15000,samples=0})
end
local function cavendish() return joker('Cavendish',{extra={Xmult=3}},'j_cavendish') end
local function flat() return joker('Joker',{mult=4},'j_joker') end
local function text(result) return table.concat(result.lines,' ') end
local old_random,old_pseudorandom=math.random,pseudorandom
math.random=function() error('ordering touched random state') end
pseudorandom=function() error('ordering touched game RNG') end

do
  local s=state({cavendish(),flat()})
  local original=Snapshot.fingerprint(s)
  local suggestion,evaluations,diagnostics=Ordering.suggest(s,Scoring,base(s))
  check(suggestion~=nil,'moving additive Mult before XMult can save a blind')
  equal(table.concat(suggestion.action.order,','),'2,1','action maps desired positions to original Joker indices')
  equal(suggestion.action.kind,'reorder_jokers','reorder is the first manual action')
  equal(suggestion.baseline_play.score,112,'baseline uses the actual current-order scorer')
  equal(suggestion.projected_play.score,240,'projected score uses the actual reordered scorer')
  equal(suggestion.play,suggestion.projected_play,'runtime may use play or projected_play consistently')
  equal(evaluations,2,'one subset across both orders is sufficient')
  equal(diagnostics.completed_orders,2,'every candidate comparison finishes')
  equal(Snapshot.fingerprint(s),original,'order search never mutates the supplied snapshot')
  check(text(suggestion):find('refresh advice',1,true),'instructions make reevaluation explicit before playing')
  equal(Snapshot.fingerprint(suggestion),Snapshot.fingerprint(Ordering.suggest(s,Scoring,base(s))), 'repeat order search is deterministic')
  local reordered=Snapshot.copy(s); reordered.jokers={}
  for _,index in ipairs(suggestion.action.order) do reordered.jokers[#reordered.jokers+1]=Snapshot.copy(s.jokers[index]) end
  equal(Ordering.suggest(reordered,Scoring,base(reordered)),nil,'after the manual reorder the advice does not bounce back to another order')
end

do
  local s=state({flat(),joker('Blueprint',{},'j_blueprint'),joker('Egg',{},'j_egg')},nil,130)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'Blueprint can be moved away from an unhelpful target')
  equal(result.play.score,144,'Blueprint actually copies the flat Mult target')
  local order=result.action.order
  local copy_position
  for position,index in ipairs(order) do if index==2 then copy_position=position end end
  equal(order[copy_position+1],1,'Blueprint ends immediately left of the scoring target')
end

do
  local jolly=joker('Jolly Joker',{type='Pair',t_mult=8},'j_jolly')
  local s=state({jolly,joker('Blueprint',{},'j_blueprint'),joker('Egg',{},'j_egg')},
    {card(14),card(2),card(2,'Hearts')},200)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'copied conditional Joker is tested against legal hand subsets')
  equal(result.play.hand,'Pair','the copied Pair condition determines the scoring hand')
  equal(result.play.score,252,'conditional copy gets its actual Pair bonus twice')
  s.hand={card(14)}; s.playing_cards=s.hand
  equal(Ordering.suggest(s,Scoring,base(s)),nil,'copying a Pair Joker gives no bonus to a lone High Card')
end

do
  local s=state({joker('Egg',{},'j_egg'),cavendish(),flat(),joker('Brainstorm',{},'j_brainstorm')},nil,400)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'Brainstorm can acquire a useful leftmost target')
  equal(result.action.order[1],3,'flat Mult becomes Brainstorm\'s leftmost target')
  equal(result.play.score,432,'both flat Mult effects resolve before the multiplier')
end

do
  local holographic=joker('Egg',{},'j_egg'); holographic.edition={holo=true}
  local s=state({cavendish(),holographic},nil,400)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'Joker edition Mult participates in order search')
  equal(result.play.score,528,'holographic Mult applies before Cavendish XMult')
end

do
  local s=state({joker('Vampire',{x_mult=1,extra=0.1},'j_vampire'),joker('Midas Mask',{},'j_midas_mask')},{card(13)},16)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'Midas before Vampire can improve the immediate score')
  equal(table.concat(result.action.order,','),'2,1','Midas creates enhancement before Vampire eats it')
  equal(result.play.score,16,'Midas/Vampire modeled score is used')
  equal(s.jokers[1].ability.x_mult,1,'Vampire growth is not applied to the input')
  equal(s.hand[1].enhancement,'c_base','Midas changes no input enhancement')
  s.blind.chips=10
  result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil and result.play.future_growth>result.baseline_play.future_growth,
    'a clearing Midas/Vampire order is justified by permanent growth, not overkill')
end

do
  local s=state({cavendish(),flat()},nil,50)
  equal(Ordering.suggest(s,Scoring,base(s)),nil,'do not rearrange for pure overkill when the current order already clears')
  s=state({joker('Egg',{},'j_egg'),joker('Gift Card',{},'j_gift'),flat()},nil,500)
  equal(Ordering.suggest(s,Scoring,base(s)),nil,'irrelevant Joker order does not create a recommendation')
end

do
  local s=state({cavendish(),flat(),joker('Business Card',{extra=2},'j_business')},{card(14),card(13)},50)
  local b=base(s)
  equal(b.play.indices[1],1,'search baseline prefers the higher-scoring Ace clear')
  check(Scoring.score(s,{2}).expected_dollars>Scoring.score(s,{1}).expected_dollars,
    'a different original-order clear already provides the income opportunity')
  equal(Ordering.suggest(s,Scoring,b),nil,'do not attribute already-available original-order income to a rearrangement')
  local glass=card(14); glass.enhancement='m_glass'
  s=state({cavendish(),flat(),joker('Vampire',{x_mult=1,extra=0.1},'j_vampire')},{glass},200)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'flat Mult before XMult still improves a Vampire hand')
  equal(result.baseline_play.future_loss,0,'Vampire-stripped Glass has no original-order Glass destruction penalty')
  equal(result.play.future_loss,0,'Vampire-stripped Glass has no reordered Glass destruction penalty')
end

do
  local s=state({flat(),joker('Blueprint',{},'j_blueprint'),joker('Egg',{},'j_egg'),
    joker('To Do List',{to_do_poker_hand='High Card',extra={dollars=4}},'j_todo_list')},nil,50)
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'copying a money effect can justify a reorder even when both orders clear')
  equal(result.baseline_play.expected_dollars,4,'original order receives one To Do List payout')
  equal(result.play.expected_dollars,8,'reordered Blueprint doubles the matching-hand payout')
end

do
  local dagger=joker('Ceremonial Dagger',{mult=0},'j_ceremonial'); dagger.pinned=true
  local s=state({dagger,cavendish(),flat()})
  local result=Ordering.suggest(s,Scoring,base(s))
  check(result~=nil,'movable scoring Jokers can improve around a pinned Joker')
  equal(result.action.order[1],1,'the actual pinned position stays fixed')
  s.jokers[2].ability.pinned=true
  local result,evaluations=Ordering.suggest(s,Scoring,base(s))
  equal(result,nil,'ability-pinned constraints also prevent an impossible swap')
  equal(evaluations,0,'fully constrained row needs no scoring search')
end

do
  local s=state({cavendish(),flat()})
  s.jokers[1].face_down=true
  equal(Ordering.suggest(s,Scoring,base(s)),nil,'hidden Joker identities cannot produce order advice')
  s.jokers[1].face_down=nil; s.blind.key='bl_final_acorn'
  equal(Ordering.suggest(s,Scoring,base(s)),nil,'active Acorn shuffle/hidden constraints suppress ordering')
  s.blind.key=nil; s.jokers_shuffling=true
  equal(Ordering.suggest(s,Scoring,base(s)),nil,'pending shuffle suppresses ordering')
end

do
  local s=state({cavendish(),flat(),joker('Egg',{},'j_egg')},{card(14),card(2),card(3)},1000)
  local yields=0
  local result,evaluations,diagnostics=Ordering.suggest(s,Scoring,base(s),function() yields=yields+1 end,{max_evaluations=20})
  check(evaluations<=20,'ordering respects the explicit additional scoring budget')
  equal(evaluations%diagnostics.subsets,0,'only fully evaluated orders count')
  equal(diagnostics.partial_orders,0,'partial comparisons are never published')
  check(diagnostics.truncated,'diagnostics disclose bounded permutation coverage')
  result,evaluations=Ordering.suggest(s,Scoring,base(s),nil,{max_evaluations=13})
  equal(result,nil,'too-small budget produces no unmatched comparison')
  equal(evaluations,0,'budget is checked before starting a comparison')
  Ordering.suggest(s,Scoring,base(s),function() yields=yields+1 end)
  check(yields>0,'longer order searches yield cooperatively')
end

do
  local s=state({cavendish(),flat()})
  local b=base(s); b.consumable={play={score=300}}
  local result=Ordering.suggest(s,Scoring,b)
  check(result~=nil and text(result):find('without spending',1,true),'a reordered clear can save a clearing consumable')
  s.blind.chips=500; b=base(s); b.consumable={play={score=600}}
  equal(Ordering.suggest(s,Scoring,b),nil,'a non-clearing reorder cannot distract from a clearing consumable')
  b.consumable=nil; b.kind='discard'
  equal(Ordering.suggest(s,Scoring,b),nil,'keep planned discard when reordered play still cannot clear')
  s.blind.chips=200; b=base(s); b.kind='discard'
  check(Ordering.suggest(s,Scoring,b)~=nil,'a reordered immediate clear can avoid a planned discard')
end

do
  local s=state({cavendish(),flat()},{card(14),card(2),card(2,'Hearts')},200)
  s.blind.key='bl_arm'
  s.hands={Pair={level=3,chips=40,mult=4,l_chips=15,l_mult=1,played=20},
    ['High Card']={level=1,chips=5,mult=1,l_chips=10,l_mult=1,played=1}}
  local b=base(s)
  equal(b.play.hand,'Pair','current order needs the upgraded Pair to clear')
  local result=Ordering.suggest(s,Scoring,b,nil,{arm_cost=Search.arm_cost})
  check(result~=nil,'an order that enables a cheaper Arm clear is useful')
  equal(result.play.hand,'High Card','reordered clear preserves the upgraded Pair')
  equal(result.play.arm_cost,0,'level-one High Card pays no future Arm cost')
  check(result.baseline_play.arm_cost>result.play.arm_cost,'future Arm relevance is compared before overkill')
  s.jokers={flat(),cavendish()}
  equal(Ordering.suggest(s,Scoring,base(s),nil,{arm_cost=Search.arm_cost}),nil,'higher Pair score never overrides an existing zero-cost Arm clear')
end

math.random,pseudorandom=old_random,old_pseudorandom
print('advisor_ordering: '..checks..' checks passed')
