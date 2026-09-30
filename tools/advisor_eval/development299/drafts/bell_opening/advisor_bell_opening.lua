local prefix='tools/advisor_eval/development299/drafts/bell_opening/'
local Bell=dofile(prefix..'bell_opening.lua')
local Shop=dofile(prefix..'shop_scoring.lua')
local Goal=dofile(prefix..'gold_goal.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Sequences=dofile(prefix..'shop_sequences.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local copy=Snapshot.copy
local function card(id,rank,suit)
  return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(10,rank),suit=suit or 'Spades',
    key='c_base',enhancement='c_base',ability={},face_down=false}
end
local function hand_state()
  local s={phase='hand',blind={key='bl_final_bell',name='Cerulean Bell',boss=true,chips=100},
    chips=0,hand_limit=4,hands_left=4,discards_left=3,hand_size=5,current_round={},hands={},jokers={},
    consumeables={},modifiers={},probabilities={normal=1},playing_cards={},deck={},hand={}}
  for i=1,5 do s.hand[i]=card('p'..i,i<=4 and 13 or 2,({'Spades','Hearts','Clubs','Diamonds','Spades'})[i]);s.playing_cards[i]=s.hand[i] end
  return s
end
local function collect(s,scorer)
  local c,why=Bell.new(s);check(c,why or 'collector exists')
  Search.combinations(#s.hand,s.hand_limit,function(indices)
    check(Bell.add(c,indices,scorer.score(s,indices)),c.failed or 'existing subset admitted')
  end)
  local result,worst=Bell.finish(c);check(result,worst or 'complete forced family')
  return result,worst
end
math.random=function() error('Bell branch comparison touched RNG') end
pseudorandom=math.random
do
  local s=hand_state();local before=Snapshot.fingerprint(s);local calls=0
  local counted={score=function(state,indices) calls=calls+1;return Score.score(state,indices) end}
  local receipt=collect(s,counted)
  eq(calls,30,'all forced branches reuse exactly the thirty existing subset scores')
  eq(receipt.scored_subsets,calls,'receipt covers the full legal-size family')
  check(receipt.minimum<receipt.maximum,'an off-rank forced card lowers the attainable score')
  for forced,branch in ipairs(receipt.branches) do
    local observed=copy(s);observed.hand[forced].ability.forced_selection=true
    local best=-1
    Search.combinations(#observed.hand,observed.hand_limit,function(indices)
      local result=Score.score(observed,indices)
      if result.legal~=false then best=math.max(best,result.score) end
    end)
    eq(branch.score,best,'branch equals direct actual-forced-flag exhaustive oracle')
    local chosen=Score.score(observed,branch.indices)
    check(chosen.legal and chosen.score==branch.score,'each branch supplies an actually legal scoring selection')
  end
  eq(calls,30,'helper and branch receipt cause no additional scoring')
  eq(Snapshot.fingerprint(s),before,'all original cards/counters stay unchanged')
  s.hand={};check(not Bell.new(s),'empty forced family is unsupported')
  s=hand_state();s.hand[1].ability.forced_selection=true
  check(not Bell.new(s),'old forced metadata cannot masquerade as a fresh unknown Bell draw')
  s=hand_state();s.hand[1].face_down=true;check(not Bell.new(s),'concealed fronts cannot enter exact branch support')
  s=hand_state();s.playing_cards[5].id=s.playing_cards[4].id
  check(not Bell.new(s),'duplicate physical population identities reject')
  s=hand_state();local c=Bell.new(s)
  Bell.add(c,{1,2,3,4},{legal=true,score=1000,hand='Four of a Kind'})
  check(not Bell.finish(c),'partial subset coverage cannot publish even a strong score')
  check(not Bell.add(c,{1,2,3,4},{legal=true,score=1000}),'duplicate work cannot replace missing coverage')
  c=Bell.new(s);check(not Bell.add(c,{1},{legal=true,score=1000,uncertain=true}),'uncertain scoring fails the complete collector')
  c=Bell.new(s);check(not Bell.add(c,{1},{score=1000}),'unknown subset legality fails closed')
  c=Bell.new(s);check(not Bell.add(c,{1},{legal=true,score=math.huge}),'nonfinite score fails closed')
  c=Bell.new(s)
  Search.combinations(#s.hand,s.hand_limit,function(indices)
    local legal=true;for _,i in ipairs(indices) do if i==5 then legal=false end end
    Bell.add(c,indices,{legal=legal,score=legal and 1000 or 0,hand='High Card'})
  end)
  check(not Bell.finish(c),'a forced identity with no legal branch cannot disappear')
end

Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity
Shop.bell_opening=Bell;Shop.blind_finishing=Finish
local modules={strategy=Strategy,shop_sequences=Sequences,shop_scoring=Shop,liquidity=Liquidity,
  consumables=dofile('Brainstorm/Advisor/consumables.lua'),bell_opening=Bell}
local function joker(key,id,a)
  a=a or {};a.set='Joker';a.name=key=='j_joker' and 'Joker' or key=='j_golden' and 'Golden Joker' or key
  return {id=id,key=key,name=a.name,ability=a,cost=5,sell_cost=2,base_cost=5,rarity=1,blueprint_compat=true}
end
local function shop_state()
  local s={phase='shop',ante=8,win_ante=8,dollars=20,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    consumeable_buffer=0,consumeables={},jokers={joker('j_joker','engine',{mult=4,eternal=true})},
    shop_jokers={joker('j_golden','offer',{extra=4})},shop_booster={},shop_vouchers={},hand_size=4,hand_limit=5,
    hands_left=4,discards_left=3,round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',hands={},playing_cards={},hand={},deck={},
    next_blind={key='bl_final_bell',name='Cerulean Bell',boss=true,ante=8,chips=100},
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={eligible=true},by_key={j_joker={status='complete'},j_golden={status='missing'}}}}
  for i=1,16 do s.playing_cards[i]=card('p'..i,2+i%8,({'Spades','Hearts','Clubs','Diamonds'})[1+i%4]) end
  for _,label in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind',
    'Straight Flush','Five of a Kind','Flush House','Flush Five'}) do s.hands[label]={level=10,chips=100,mult=10,played=1} end
  return s
end
local hold={action={kind='leave_shop'}}
do
  local s=shop_state();local before=Snapshot.fingerprint(s);local calls=0
  local counted={score=function(state,indices) calls=calls+1;return Score.score(state,indices) end}
  local context=Shop.new(s,counted,nil,{max_evaluations=50000})
  local advice,d=Goal.suggest(s,modules,hold,context)
  check(advice and d.complete,'a fully supported Bell endpoint can add a missing passive Joker: '..tostring(d.reason)..' context: '..tostring(context.unavailable_reason))
  eq(advice.action.kind,'buy','the first actual buy action is returned')
  eq(advice.action.index,1,'the visible missing offer is chosen')
  eq(calls,context.evaluations,'all work remains in the existing shared score account')
  check(calls<=50000,'complete Bell goal family stays in the existing shop cap')
  for _,endpoint in ipairs(d.endpoints) do
    local evidence=endpoint.hold_evidence;local ready=evidence.after_readiness
    check(ready.bell_opening.complete,'every admitted endpoint has complete forced branches')
    eq(ready.score_kind,'forced_card_lower_bound','scalar score explicitly names the bound')
    check(not ready.finishing.complete,'first-hand evidence never becomes a whole-blind forecast')
    eq(ready.ordering.identity,ready.bell_opening.fixed_order_identity,'one concrete row is bound to all four worlds')
    for _,world in ipairs(ready.bell_opening.worlds) do
      eq(world.order_identity,ready.bell_opening.fixed_order_identity,'no world may select a different scoring layout')
      eq(#world.branches,4,'every held identity is represented')
      check(world.minimum>=125,'every possible forced card meets the margin')
    end
  end
  eq(Snapshot.fingerprint(s),before,'complete endpoint comparison preserves input inventory/cash')
  local small=Shop.new(s,counted,nil,{max_evaluations=1});local prior=calls
  local none,diagnostic=Goal.suggest(s,modules,hold,small)
  check(not none and not diagnostic.complete and small.truncated,'insufficient budget cannot publish a partial candidate')
  eq(calls,prior,'budget preflight rejects before scoring')
  local changed=copy(s);changed.playing_cards[1].rank=14
  local mismatch=Shop.new(s,counted,nil,{max_evaluations=50000})
  check(not mismatch:compare(s,changed),'mismatched deck endpoint cannot reuse Bell branches')
end

-- Controlled complete scored families expose a branch-wise regression that
-- scalar minimum differences conceal: 140/220 ->145/210 has a better floor,
-- but loses ten chips for the second common forced identity.
local function bundle_for(s,a,b)
  local state={hand={card('one',2),card('two',3)},jokers=copy(s.jokers),hand_limit=1,
    blind={key='bl_final_bell',chips=100},playing_cards={}}
  state.playing_cards={state.hand[1],state.hand[2]}
  local c=Bell.new(state)
  Bell.add(c,{1},{legal=true,score=a,hand='High Card'})
  Bell.add(c,{2},{legal=true,score=b,hand='High Card'})
  local world=Bell.finish(c);local order={};for i=1,#s.jokers do order[i]=i end
  return Bell.bundle({copy(world),copy(world),copy(world),copy(world)},
    {identity=world.order_identity,order=order,action_count=0})
end
do
  local s=shop_state();local c={evaluations=0,max_evaluations=50000}
  function c:compare(before,after)
    self.evaluations=self.evaluations+1
    local a=bundle_for(before,140,220);local b=bundle_for(after,#after.jokers>1 and 145 or 140,#after.jokers>1 and 210 or 220)
    return {samples=4,uncertain=false,low_sample_delta=0,before_target=100,after_target=100,score_kind='forced_card_lower_bound',
      before_readiness={supported=true,samples=4,target=100,opening_scores={140,140,140,140},bell_opening=a},
      after_readiness={supported=true,samples=4,target=100,opening_scores={b.worlds[1].minimum,b.worlds[2].minimum,b.worlds[3].minimum,b.worlds[4].minimum},bell_opening=b}}
  end
  local advice,d=Goal.suggest(s,modules,hold,c)
  check(not advice and d.complete,'a scalar floor gain cannot compensate for a worse common forced card')
  local a=bundle_for(s,140,220);local b=copy(a);b.worlds[4].population_key='different'
  check(not Bell.compare(a,b,100),'population mismatch rejects the whole paired family')
  b=copy(a);b.worlds[4].branches[1].indices={2}
  check(not Bell.compare(a,b,100),'a purported branch must actually include its forced identity')
  b=copy(a);b.worlds[4].branches={}
  check(not Bell.compare(a,b,100),'an empty branch family cannot imply safety')
  b=copy(a);b.worlds[4].order_identity='different row'
  check(not Bell.compare(a,b,100),'different world-specific Joker orders are invalid')
  b=copy(a);b.worlds[4].branches[1].indices={1,2}
  check(not Bell.compare(a,b,100),'branch selections may not exceed the declared played-card limit')
  check(not Bell.compare(a,a,101),'changed target cannot reuse a branch certificate')
  b=copy(a);b.worlds[4].uncertain=true
  check(not Bell.compare(a,b,100),'one uncertain world blocks the complete comparison')
  local low=bundle_for(s,124,300)
  local comparison=Bell.compare(a,low,100)
  eq(comparison.minimum_after,124,'weak forced branch remains visible despite high other scores')
end

-- The original shop projector discarded explicit false scalars. Snapshot-shaped
-- visible cards contain face_down=false, so a harmless buy used to appear to
-- alter the entire protected population and block the Gold comparison.
do
  local s=shop_state();s.playing_cards[1].debuff=false;s.jokers[1].debuff=false
  s.consumeables={{id='planet',key='c_mercury',debuff=false,ability={set='Planet',consumeable={hand_type='Pair'}}}}
  s.metadata={flag=false,zero=0,nested={flag=false}};s.transient=function() end
  local original=Snapshot.fingerprint(s.playing_cards)
  local after,why=Sequences.transition(s,{kind='buy',area='shop_jokers',index=1},modules)
  check(after,why or 'visible paid buy is projected')
  eq(Snapshot.fingerprint(after.playing_cards),original,'all explicit false card fields survive an ordinary buy')
  eq(after.playing_cards[1].face_down,false,'known face-up metadata remains explicit')
  eq(after.playing_cards[1].debuff,false,'known non-debuff metadata remains explicit')
  eq(after.consumeables[1].debuff,false,'whole owned inventory retains explicit false')
  eq(after.metadata.nested.flag,false,'nested false values survive projection')
  eq(after.metadata.zero,0,'zero remains distinct from absent')
  eq(after.transient,nil,'transient function values remain excluded')
  after.playing_cards[1].rank=14
  check(s.playing_cards[1].rank~=14,'detached copy does not alias original population')
end

do
  local s=shop_state()
  s.jokers={joker('j_golden','cash',{extra=4}),joker('j_brainstorm','copy',{}),
    joker('j_yorick','scale',{x_mult=4,yorick_discards=13,extra={discards=23,xmult=1}})}
  s.jokers[2].ability.name='Brainstorm';s.jokers[3].ability.name='Yorick'
  local before=Snapshot.fingerprint(s)
  local r=Shop.new(s,Score):readiness(s)
  check(r and r.supported and r.bell_opening.complete,'actual copied-scaling Bell family is supported')
  check(r.ordering.layouts>1,'actual copy family compares more than its incumbent arrangement')
  for _,w in ipairs(r.bell_opening.worlds) do
    eq(w.order_identity,r.ordering.identity,'every forced-card world uses the single fixed actual scoring row')
  end
  local aligned=copy(s);aligned.jokers={}
  for i,index in ipairs(r.ordering.order) do aligned.jokers[i]=copy(s.jokers[index]) end
  local aligned_ready=Shop.new(aligned,Score):readiness(aligned)
  eq(aligned_ready.ordering.action_count,0,'already aligned actual row requires no invented reorder')
  local e=Shop.new(s,Score):compare(s,aligned)
  check(e and e.ordering_cost and e.forced_comparison.complete,'Bell paired receipt includes the real setup cost')
  eq(e.ordering_cost.before_actions,r.ordering.action_count,'before setup charge matches its actual arrangement')
  eq(e.ordering_cost.after_actions,0,'aligned endpoint incurs zero arrangement actions')
  eq(e.ordering_cost.adjustment,-2*e.ordering_cost.extra_actions,'existing action utility is charged once per actual reorder')
  eq(e.low_sample_delta,0,'pure physical row alignment does not invent a forced-card score improvement')
  check(not e.complete_finishing and not e.after_readiness.finishing.complete,'complete first-hand branches do not become terminal evidence')
  eq(Snapshot.fingerprint(s),before,'all original Joker metadata and card population remain unchanged')
  s.jokers[1].pinned=true
  local pinned=Shop.new(s,Score):readiness(s)
  check(pinned and pinned.bell_opening.complete,'a pinned row can still have a complete legal branch family')
  eq(pinned.ordering.order[1],1,'the pinned physical Joker never moves')
  s.jokers[1].face_down=true
  local hidden=Shop.new(s,Score):readiness(s)
  check(hidden and not hidden.supported,'a concealed Joker row cannot produce an exact reorder certificate')
end

do
  -- Four different composition worlds deliberately prefer opposing layouts.
  -- The aggregate must keep the weak worlds from one common chosen layout.
  local s=shop_state();s.jokers={joker('j_golden','cash',{extra=4}),joker('j_joker','mult',{mult=4})}
  local observed,world_count,calls={},0,0
  local scorer={score=function(state)
    calls=calls+1
    local ids={};for _,c in ipairs(state.hand) do ids[#ids+1]=c.id end
    local key=table.concat(ids,',')
    if not observed[key] then world_count=world_count+1;observed[key]=world_count%2==1 and 'cash' or 'mult' end
    return {legal=true,score=state.jokers[1].id==observed[key] and 200 or 100,hand='High Card',warnings={}}
  end}
  local context=Shop.new(s,scorer)
  local r=context:readiness(s)
  eq(world_count,4,'four distinct common visible composition worlds are scored')
  check(r and r.supported and r.bell_opening.complete,'conflicting complete family remains representable')
  eq(r.opening_mean,150,'one fixed layout preserves weak worlds instead of combining per-world maxima')
  eq(r.opening_min,100,'the weaker forced-card world remains explicit')
  eq(r.opening_max,200,'the stronger forced-card world remains explicit')
  eq(calls,4*15*r.ordering.layouts,'every forced branch reuses the existing subset calls without multiplying by hand size')
  eq(calls,context.evaluations,'shared score receipt accounts for every actual call')
  for _,w in ipairs(r.bell_opening.worlds) do eq(w.order_identity,r.ordering.identity,'all conflicting worlds bind to one layout') end
end

print('advisor_bell_opening: '..checks..' checks passed')
