local prefix='Brainstorm/Advisor/'
local Pool=dofile(prefix..'perkeo_inventory.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function eq(a,b,why) check(a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local copy=Snapshot.copy
local function raw_planet(id,negative)
  local center={key='c_mercury',name='Mercury',set='Planet',effect='Hand Upgrade',consumeable=true,
    cost=3,order=2,config={hand_type='Pair'}}
  local ability={name='Mercury',effect='Hand Upgrade',set='Planet',order=2,type='',
    mult=0,h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,t_mult=0,t_chips=0,x_mult=1,
    h_size=0,d_size=0,extra_value=0,bonus=0,perma_bonus=0,hands_played_at_create=0,
    consumeable={hand_type='Pair'}}
  return {sort_id=id,config={center=center,card={}},params={bypass_discovery_center=true},
    base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0},ability=ability,
    facing='front',debuff=false,pinned=false,base_cost=3,cost=negative and 8 or 3,
    sell_cost=negative and 4 or 1,edition=negative and {negative=true,type='negative'} or nil}
end
local function observe(raw)
  local card=Snapshot.card(raw)
  card.copy_source=Pool.capture(raw,{[raw.config.center.key]=raw.config.center})
  return card
end
local function joker(key,id,name)
  return {key=key,id=id,name=name,ability={set='Joker',name=name},debuff=false,blueprint_compat=true}
end
local function state()
  local p1={id='one',rank=2,nominal=2,suit='Spades',ability={}}
  local p2={id='two',rank=2,nominal=2,suit='Hearts',ability={}}
  return {phase='shop',jokers={joker('j_perkeo','perkeo','Perkeo'),joker('j_brainstorm','copy','Brainstorm')},
    consumeables={observe(raw_planet(1))},consumable_limit=2,consumeable_buffer=0,
    dollars=30,shop_forecast={inflation=0,discount_percent=0},playing_cards={p1,p2},hand={p1,p2},deck={},
    hands={Pair={level=4,chips=55,mult=5,l_chips=15,l_mult=1,played=5}},hand_limit=5,hand_size=2,
    hands_left=4,discards_left=3,current_round={},modifiers={},probabilities={normal=1},
    blind={disabled=true,chips=600},used_vouchers={v_observatory=true},jokers_shuffling=false,ordering_safe=true}
end
math.random=function() error('Perkeo projection used RNG') end
pseudorandom=math.random

do
  local raw=raw_planet(1);local before=Snapshot.fingerprint(raw)
  local card=observe(raw)
  check(card.copy_source.supported,'source-shaped ordinary Planet receives an explicit source proof')
  check(Pool.source_key(card),'full public observation matches its source proof')
  eq(Snapshot.fingerprint(raw),before,'capture does not mutate live-shaped input metadata')
  local wrong=copy(raw);wrong.params.playing_card=1
  check(not observe(wrong).copy_source.supported,'copy params with physical playing-card identity are unsupported')
  wrong=copy(raw);wrong.config.center.config.extra=1
  check(not observe(wrong).copy_source.supported,'same display name cannot qualify a modified center config')
  wrong=copy(raw);wrong.ability.consumeable.hand_type='Flush'
  check(not observe(wrong).copy_source.supported,'actual copied hand type must agree with source center')
  wrong=copy(raw);wrong.base.times_played=1
  check(not observe(wrong).copy_source.supported,'constructor-reset base history cannot be copied blindly')
  wrong=copy(raw);wrong.base={}
  check(not observe(wrong).copy_source.supported,'all four empty-front constructor fields are mandatory')
  wrong=copy(raw);wrong.base.suit_nominal_original=0
  check(not observe(wrong).copy_source.supported,'a field absent from the empty-front constructor cannot be silently preserved')
  wrong=copy(raw);wrong.ability.h_size=1
  check(not observe(wrong).copy_source.supported,'consumable copies may not hide extra hand-size effects')
  wrong=copy(raw);wrong.ability.mult=function() end
  check(not observe(wrong).copy_source.supported,'unknown function metadata cannot be dropped into an apparently exact proof')
  check(not Pool.capture(raw,{c_mercury=copy(raw.config.center)}).supported,'registry identity is verified directly')
  local damaged=copy(card);damaged.copy_source.params.playing_card=7
  check(not Pool.source_key(damaged),'a stale supported flag cannot bypass exact copy parameters')
  damaged=copy(card);damaged.base={};damaged.copy_source.base={}
  check(not Pool.source_key(damaged),'matching malformed public/proof bases do not establish copy closure')
  damaged=copy(card);damaged.copy_source.ability.extra_value=4
  check(not Pool.source_key(damaged),'proof ability must still match the actual copied full ability')
  local s=state();local fingerprint=Snapshot.fingerprint(s)
  local exit,receipt=Pool.project(s)
  check(exit and receipt.supported,'qualified homogeneous pool projects its complete immediate exit')
  eq(receipt.copy_events,2,'physical Perkeo and resolved Brainstorm each produce one copy')
  eq(#exit.consumeables,3,'both generated Negative cards join the whole inventory')
  eq(exit.consumable_limit,4,'new Negative copies each add exactly one consumable slot')
  eq(exit.dollars,30,'copy generation spends no cash')
  eq(Snapshot.fingerprint(s),fingerprint,'all original row, cash, population and inventory fields remain unchanged')
  for i=2,3 do
    eq(exit.consumeables[i].edition.type,'negative','source edition is rebuilt canonically')
    eq(exit.consumeables[i].cost,8,'Negative copy uses current base-plus-five pricing')
    eq(exit.consumeables[i].sell_cost,4,'Negative resale is recomputed from its real copied price')
    check(exit.consumeables[i].id~=exit.consumeables[1].id,'projection symbols preserve unique identities')
    check(exit.consumeables[i].projected_identity,'new identities are explicitly symbolic, not predicted source sort IDs')
  end
  eq(Pool.source_key(exit.consumeables[1]),Pool.source_key(exit.consumeables[3]),'the new Negative remains in the same recopying class')
  s.consumeables[2]=observe(raw_planet(2,true));s.consumable_limit=3
  local mixed,why=Pool.project(s)
  check(mixed,why or 'ordinary and Negative members with identical copied effects form one class')
  eq(#mixed.consumeables,4,'the complete original mixed inventory is retained')
  eq(mixed.consumable_limit,5,'only newly created Negative cards add capacity')
  s.consumeables[2].copy_source.ability.extra_value=1;s.consumeables[2].ability.extra_value=1
  check(not Pool.project(s),'identical Planet names with different copied resale metadata are not homogeneous')
end

do
  local s=state();s.shop_forecast={inflation=2,discount_percent=25}
  local exit=Pool.project(s)
  eq(exit.consumeables[2].cost,7,'inflation and discount apply before price floor')
  eq(exit.consumeables[2].sell_cost,3,'discounted copied resale is explicit')
  s.jokers[3]=joker('j_astronomer','astro','Astronomer')
  exit=Pool.project(s)
  eq(exit.consumeables[2].cost,0,'active Astronomer makes the newly copied Planet free')
  eq(exit.consumeables[2].sell_cost,1,'free copied Planets retain the source minimum resale')
  s.jokers[3].debuff=true
  exit=Pool.project(s)
  eq(exit.consumeables[2].cost,7,'debuffed Astronomer supplies no copied price exception')
  s.jokers[1].debuff=true
  exit=Pool.project(s)
  eq(#exit.consumeables,1,'debuffed target suppresses physical and copied Perkeo callbacks')
  s=state();s.jokers={joker('j_blueprint','b','Blueprint'),joker('j_brainstorm','s','Brainstorm'),joker('j_perkeo','p','Perkeo')}
  local r;exit,r=Pool.project(s)
  eq(r.copy_events,1,'a Blueprint/Brainstorm cycle creates no imagined copying event')
  s.jokers={joker('j_blueprint','b','Blueprint'),joker('j_perkeo','p','Perkeo'),joker('j_brainstorm','s','Brainstorm')}
  exit,r=Pool.project(s)
  eq(r.copy_events,3,'a legal Blueprint-to-Perkeo chain is copied by Brainstorm')
  s.jokers[1].blueprint_compat=false
  exit,r=Pool.project(s)
  eq(r.copy_events,2,'copy-incompatible Blueprint breaks only the outer Brainstorm link')
  s.consumeable_buffer=1
  check(not Pool.project(s),'an unsettled pending consumable buffer blocks the family')
  s=state();s.consumeables[1].copy_source=nil
  check(not Pool.project(s),'old snapshots receive no inferred source qualification')
  s=state();s.consumeables[1].id='perkeo-projection:1'
  check(not Pool.project(s),'projection symbols cannot collide with an existing identity')
end

do
  local s=state();local exit=Pool.project(s);local before=Snapshot.fingerprint(exit)
  local family,receipt=Pool.planet_family(exit,Consumables)
  check(family and receipt.complete,'all qualified ordinary/Negative use counts are enumerated')
  eq(#family,6,'one ordinary and two Negative cards create six complete hold/use combinations')
  eq(receipt.score_evaluations,0,'building the family spends no score calls')
  local best,best_score=nil,-1
  local seen={}
  for _,plan in ipairs(family) do
    local state=plan.state
    local result=Scoring.score(state,{1,2})
    check(result.legal and not result.uncertain,'each synthetic post-use state supports an exact actual score')
    eq(#state.consumeables,3-plan.action_count,'every planned use removes exactly one held identity')
    eq(state.consumable_limit,4-plan.negative_used,'ordinary and Negative capacity costs remain distinct')
    eq(state.hands.Pair.level,4+plan.action_count,'all known Planet level increments are retained')
    eq(state.dollars,exit.dollars,'owned uses preserve current cash')
    seen[plan.ordinary_used..':'..plan.negative_used]=true
    if result.score>best_score then best,best_score=plan,result.score end
  end
  for o=0,1 do for n=0,2 do check(seen[o..':'..n],'no ordinary/Negative count pair disappears') end end
  eq(best.action_count,1,'nonlinear Observatory tradeoff can favor exactly one use instead of hold-all or use-all')
  eq(Snapshot.fingerprint(exit),before,'use enumeration leaves its full input inventory untouched')
  s=state();s.used_vouchers={};s.jokers[3]=joker('j_constellation','c','Constellation');s.jokers[3].ability.x_mult=1;s.jokers[3].ability.extra=0.1
  exit=Pool.project(s);family=Pool.planet_family(exit,Consumables)
  local all
  for _,plan in ipairs(family) do if plan.action_count==3 then all=plan end end
  check(all and math.abs(all.state.jokers[3].ability.x_mult-1.3)<1e-10,'actual Constellation growth is included for every Planet use')
  eq(all.state.consumeable_usage_total.planet,3,'Planet usage history increments exactly')
  eq(all.state.last_tarot_planet,'c_mercury','last-used identity follows the actual generated Planet')
  eq(#all.state.consumeables,0,'consuming every card remains an explicit alternative, not silently excluded')
  eq(all.state.consumable_limit,2,'using every new Negative returns the original ordinary capacity')
end

do
  local exit=Pool.project(state());local family=Pool.planet_family(exit,Consumables)
  -- Four manufactured worlds make a policy with the best average fail one
  -- comparison. A single complete after policy must preserve every reference.
  local function context(cap,fail_at)
    local c={evaluations=0,max_evaluations=cap or 50000}
    function c:compare(before,after)
      self.evaluations=self.evaluations+1
      if self.evaluations==fail_at then return nil end
      local used=4-(after.consumable_limit-#after.consumeables)-#after.consumeables
      local score=Scoring.score(after,{1,2}).score
      local prior=Scoring.score(before,{1,2}).score
      return {low=score,delta=score-prior}
    end
    return c
  end
  local function validate(e) if e then return e.low,e.delta end end
  local c=context();local result,d=Pool.compare_families(family,family,c,validate,600)
  check(result and d.complete,'all use policies complete before choosing one after policy')
  eq(d.comparisons,36,'all six before and six after alternatives are compared')
  eq(result.variant.action_count,1,'one fixed Observatory use policy dominates all alternative use counts')
  eq(result.variant.ordinary_used,1,'equal complete scores prefer the extra ordinary capacity available for later Blue generation')
  check(result.eligible and result.delta>=0,'the complete policy preserves every bounded reference and margin')
  for _,policy in ipairs(d.policies) do eq(#policy.comparisons,6,'each candidate retains all before alternatives') end
  local failure,negative=Pool.compare_families(family,family,context(50000,7),validate,600)
  check(not failure and not negative.complete,'one unsupported later pair invalidates the entire family')
  local bounded=context(5)
  failure,negative=Pool.compare_families(family,family,bounded,validate,600)
  check(not failure and not negative.complete,'insufficient aggregate allowance publishes no partial winner')
  eq(bounded.evaluations,5,'the family never exceeds its existing score allowance')
  c=context()
  function c:compare(before,after)
    self.evaluations=self.evaluations+1
    local value=after.hands.Pair.level==5 and 900 or 800
    return {low=value,delta=before.hands.Pair.level==7 and -1 or 10}
  end
  result,d=Pool.compare_families(family,family,c,validate,600)
  check(result and d.complete and not result.eligible,'a strong average cannot hide one worse complete reference')
  c=context()
  function c:compare(before,after)
    self.evaluations=self.evaluations+1
    return {low=1000+self.evaluations,delta=1}
  end
  failure,negative=Pool.compare_families(family,family,c,validate,600)
  check(not failure and not negative.complete,'paired comparisons cannot change the same fixed after policy floor')
end

do
  local function variant(key,values)
    return {key=key,state={scores=values},actions={},action_count=0,free_slots=1}
  end
  local strong=variant('other_joker_endpoint',{1000,1000,1000,1000})
  local own_hold=variant('own_hold',{150,160,170,180})
  local own_use=variant('own_use',{160,170,180,190})
  local before={strong,own_hold,own_use};local after={own_hold,own_use}
  local function context()
    local c={evaluations=0,max_evaluations=50000}
    function c:compare(a,b)
      self.evaluations=self.evaluations+1
      local low,delta=math.huge,math.huge
      for i=1,4 do low=math.min(low,b.scores[i]);delta=math.min(delta,b.scores[i]-a.scores[i]) end
      return {low=low,delta=delta}
    end
    return c
  end
  local function validate(e) return e.low,e.delta end
  local c=context();local selected,d=Pool.compare_families(before,after,c,validate,100)
  check(selected and d.complete and not selected.eligible,'default contract still protects every reference')
  c=context();selected,d=Pool.compare_families(before,after,c,validate,100,{protected_reference_indices={2,3}})
  check(selected and d.complete and selected.eligible,'explicit own-family protection can trade excess score from a different Joker endpoint')
  eq(selected.variant.key,'own_use','one fixed policy dominates both owned-use alternatives')
  eq(selected.delta,-840,'the full reference score reduction is preserved')
  eq(selected.protected_delta,0,'the selected own-policy minimum remains nonnegative')
  eq(d.comparisons,6,'unprotected references still receive every complete comparison')
  eq(#d.policies[1].comparisons,3,'no reference disappears from the evidence')
  check(not d.policies[1].eligible,'an alternative that loses against the protected own use is still rejected')
  -- The ordinary fresh-delivery call continues to enforce the same own-family
  -- contract without importing the prior endpoint's relaxed comparison mode.
  local delivered,delivery=Pool.compare_families(after,after,context(),validate,100)
  check(delivered and delivery.complete and delivered.eligible,'fresh default delivery accepts the same owned policy')
  eq(delivered.variant.key,selected.variant.key,'the shop and fresh delivery agree on the actual policy')
  local invalid={false,1,{}, {0},{4},{2,2},{1.5},{'2'},{[2]=2},{2,extra=3},setmetatable({2},{})}
  for _,indices in ipairs(invalid) do
    c=context();local bad,why=Pool.compare_families(before,after,c,validate,100,{protected_reference_indices=indices})
    check(not bad and not why.complete,'malformed protected reference lists fail closed')
    eq(c.evaluations,0,'malformed option rejection spends no score calls')
  end
  for _,options in ipairs({false,1,'all',{unknown=true},setmetatable({},{})}) do
    c=context();local bad,why=Pool.compare_families(before,after,c,validate,100,options)
    check(not bad and not why.complete,'malformed reference options fail closed')
    eq(c.evaluations,0,'malformed options decline before comparing')
  end
  own_use.state.scores[4]=124
  selected,d=Pool.compare_families(before,after,context(),validate,100,{protected_reference_indices={2,3}})
  check(selected and d.complete and not selected.eligible,'a weak world or crossed own alternatives cannot yield an eligible policy')
end

print('advisor_perkeo_inventory: '..checks..' checks passed')
