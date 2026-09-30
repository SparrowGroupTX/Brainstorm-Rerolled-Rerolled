-- Synthetic detached integration: real scorer/transitions, no source callbacks.
local p='Brainstorm/Advisor/'
local r='Brainstorm/Advisor/'
local Pool=dofile(p..'perkeo_inventory.lua')
local Policy=dofile(p..'gold_planet_policy.lua')
local Goal=dofile(p..'gold_goal.lua')
local Perkeo=dofile(p..'gold_perkeo.lua')
local Decision=dofile(p..'decision.lua')
local Snapshot=dofile(p..'snapshot.lua')
local Consumables=dofile(r..'consumables.lua')
local Scoring=dofile(r..'scoring.lua')
local Shop=dofile(r..'shop_scoring.lua')
local Strategy=dofile(r..'strategy.lua')
local Liquidity=dofile(r..'liquidity.lua')
local Phase=dofile(r..'phase_copy.lua')
local Bell=dofile(r..'bell_opening.lua')
Shop.bell_opening=Bell;Shop.strategy=Strategy
Strategy.liquidity=Liquidity;Liquidity.snapshot=Snapshot
local checks=0
local function check(x,m) checks=checks+1;assert(x,m) end
local function eq(x,y,m) check(x==y,m..': '..tostring(x)..' ~= '..tostring(y)) end
local copy=Snapshot.copy
local calls=0
local raw_score=Scoring.score
Scoring.score=function(...) calls=calls+1;return raw_score(...) end
local Score=Scoring
local mods={perkeo_inventory=Pool,gold_planet_policy=Policy,gold_goal=Goal,gold_perkeo=Perkeo,
  scoring=Score,shop_scoring=Shop,consumables=Consumables,phase_copy=Phase,strategy=Strategy,
  gold_stickers=dofile(r..'gold_stickers.lua'),shop_sequences=dofile(r..'shop_sequences.lua'),liquidity=Liquidity,bell_opening=Bell}
local function joker(key,id,name,a)
  a=a or {};a.name=name;a.set='Joker'
  return {key=key,id=id,name=name,ability=a,cost=5,base_cost=5,sell_cost=5,debuff=false,
    face_down=false,pinned=false,blueprint_compat=true}
end
local function planet(id,neg)
  local c={key='c_mercury',name='Mercury',set='Planet',consumeable=true,cost=3,order=2,
    effect='Hand Upgrade',config={hand_type='Pair'}}
  local raw={sort_id=id,config={center=c,card={}},params={},base_cost=3,cost=neg and 8 or 3,
    sell_cost=neg and 4 or 1,debuff=false,pinned=false,facing='front',
    base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0},
    ability={name='Mercury',set='Planet',order=2,effect='Hand Upgrade',type='',h_size=0,d_size=0,
      consumeable={hand_type='Pair'},extra_value=0,mult=0,h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,
      t_mult=0,t_chips=0,x_mult=1,bonus=0,perma_bonus=0,hands_played_at_create=0},
    edition=neg and {negative=true,type='negative'} or nil}
  local card=Snapshot.card(raw);card.copy_source=Pool.capture(raw,{c_mercury=c});return card,raw
end
local function state()
  local s={phase='shop',ante=8,win_ante=8,dollars=30,bankrupt_at=0,joker_limit=4,consumable_limit=2,
    consumeable_buffer=0,consumeables={(planet('real:1'))},jokers={
      joker('j_yorick','y','Yorick',{x_mult=2,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
      joker('j_perkeo','p','Perkeo'),joker('j_brainstorm','b','Brainstorm',{eternal=true})},
    shop_jokers={joker('j_golden','offer','Golden Joker',{extra=4})},shop_booster={},shop_vouchers={},
    next_blind={key='bl_final_bell',name='Cerulean Bell',boss=true,chips=600,ante=8},
    blind_on_deck='Boss',blind_states={Small='Defeated',Big='Defeated',Boss='Select'},
    hand_size=2,hand_limit=5,hands_left=4,discards_left=3,round_resets={hands=4,discards=3},
    current_round={},modifiers={},probabilities={normal=1},playing_cards={},hand={},deck={},
    hands={Pair={level=4,chips=55,mult=5,l_chips=15,l_mult=1,played=5}},used_vouchers={v_observatory=true},
    ordering_safe=true,jokers_shuffling=false,shop_forecast={inflation=0,discount_percent=0},
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={eligible=true},by_key={j_yorick={status='complete'},j_perkeo={status='missing'},
        j_brainstorm={status='complete'},j_golden={status='missing'}}}}
  for i=1,12 do s.playing_cards[i]={id='synthetic:'..i,rank=2,nominal=2,
    suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}} end
  return s
end
local function delivery(s,options)
  local before=calls;local action,work,diag=Policy.suggest(s,mods,nil,options)
  eq(work,calls-before,'all actual subset score calls are charged once')
  check(work<=50000,'the unchanged comparison cap bounds every delivery')
  return action,work,diag
end
math.random=function() error('No game RNG belongs in this fixture') end;pseudorandom=math.random

do
  local s=state();local original=Snapshot.fingerprint(s)
  local exit,receipt=Perkeo.project(s,mods)
  check(exit and receipt.supported,'complete phase setup and nonempty Perkeo projection succeed: '..tostring(receipt))
  eq(receipt.setup_actions,1,'shop-exit copy layout is a charged real action')
  eq(receipt.setup_action.kind,'reorder_jokers','the first setup is actually executable')
  eq(exit.jokers[1].id,'p','Perkeo is placed before Brainstorm for copying')
  eq(#exit.consumeables,3,'both copying events add distinct Negative Planets')
  eq(Snapshot.fingerprint(s),original,'projection does not mutate owned rows or inventory')
  local family=Pool.planet_family(exit,Consumables)
  local context=Shop.new(exit,Score,nil,{max_evaluations=50000});local before=calls
  local chosen,d=Pool.compare_families(family,family,context,function(e,t) return Goal.validate_opening(e,t,'bl_final_bell',Bell) end,600)
  check(chosen and d.complete and chosen.eligible,'real Bell scorer completes every forced branch of all use-count pairs')
  eq(d.comparisons,36,'six complete policies are checked against all six references')
  eq(context.evaluations,calls-before,'every actual score invocation belongs to the same context budget')
  eq(chosen.variant.action_count,1,'the complete actual score comparison prefers one Planet use')
  eq(chosen.variant.ordinary_used,1,'equal-scoring uses free an ordinary slot instead of losing Negative capacity')
  eq(chosen.evidence.after_readiness.ordering.action_count,1,'the later scoring arrangement remains a real action')
  check(chosen.evidence.after_readiness.bell_opening.complete,'the chosen opening retains all forced-card branches')
  -- A projection symbol is replaced with an observed physical identity before
  -- delivery. No earlier receipt is supplied to the actual-action controller.
  exit.phase='blind'
  for i=2,3 do exit.consumeables[i].id='real:generated:'..i;exit.consumeables[i].projected_identity=nil end
  local advice,work,diag=delivery(exit)
  check(advice and diag.complete,'a fresh public blind snapshot can deliver the plan')
  eq(advice.action.kind,'use','first deliver the actual currently held ordinary Planet')
  eq(advice.action.index,1,'use the exact observed first card, not a generated symbol')
  eq(diag.planned_consumable_actions[1].id,'card:real:1','the plan is bound to a real observed identity')
  check(advice.needs_refresh,'the next step must be recomputed after actual mutation')
  local used=assert(Consumables.apply(exit,advice.action.index,{}))
  advice,work,diag=delivery(used)
  check(advice and diag.complete,'the remaining suffix is recomputed completely after the real use')
  eq(advice.action.kind,'reorder_jokers','the current hold policy now delivers its scored arrangement')
  local arranged=copy(used);arranged.jokers={}
  for i,index in ipairs(advice.action.order) do arranged.jokers[i]=copy(used.jokers[index]) end
  advice,work,diag=delivery(arranged)
  check(advice and diag.complete,'the observed scoring order can complete the delivery')
  eq(advice.action.kind,'select_blind','only after preparation select the final boss')
  eq(advice.action.blind,'Boss','use the legal ordinary provider action')
  eq(#arranged.consumeables,2,'actual delivery does not generate copies a second time')
  eq(arranged.consumable_limit,4,'the two retained Negative slots and free ordinary slot persist')
  -- Without Observatory, using all Planets is allowed. Empty inventory is an
  -- exact terminal use-family member and must still deliver scoring order.
  local empty=copy(exit);empty.used_vouchers={}
  for step=1,3 do
    advice,work,diag=delivery(empty)
    check(advice and advice.action.kind=='use','complete-use policy delivers one actual card per refresh')
    empty=assert(Consumables.apply(empty,advice.action.index,{}))
  end
  eq(#empty.consumeables,0,'all three physical cards were removed exactly once')
  advice,work,diag=delivery(empty)
  check(advice and advice.action.kind=='reorder_jokers','empty suffix still delivers the scoring arrangement')
end

do
  local _,raw=planet('capture-check')
  local before=Snapshot.fingerprint(raw)
  local old_G=G;G={P_CENTERS={c_mercury=raw.config.center}};Snapshot.perkeo_inventory=Pool
  local observed=Snapshot.card(raw)
  check(observed.copy_source and observed.copy_source.supported,'runtime snapshot captures the exact source proof using the loaded registry')
  eq(Snapshot.fingerprint(raw),before,'runtime observation calls no mutating Card method')
  G.P_CENTERS.c_mercury=copy(raw.config.center)
  check(not Snapshot.card(raw).copy_source.supported,'the live registry identity gate remains visible in snapshots')
  G=old_G;Snapshot.perkeo_inventory=nil
end

do
  local s=state();local before=calls;local context=Shop.new(s,Score,nil,{max_evaluations=50000})
  local advice,d=Goal.suggest(s,mods,{action={kind='leave_shop'}},context)
  check(advice and d.complete and d.evidence_complete,'complete paid Gold comparison integrates the copied Planet family')
  eq(context.evaluations,calls-before,'Gold uses the same real score counter for all endpoints and policies')
  eq(advice.action.kind,'buy','deliver the real paid first action before imagined exit events')
  eq(advice.action.index,1,'buy the visible missing Golden Joker')
  eq(d.after_missing,2,'only the exact distinct retained missing Joker keys receive credit')
  check(d.selected.first_hand_policy.comparison.complete,'the complete selected use family is preserved in the receipt')
  eq(d.selected.projected_actions,4,'charge buy, pre-exit reorder, one use and pre-boss scoring reorder')
  eq(d.selected.first_hand_policy.actions[1].id,'card:real:1','the first paid endpoint use plan prefers the real ordinary card')
  -- Keep Perkeo over a proposed sale only if its whole copy/use family really
  -- preserves the exact incumbent, including the sale proceeds and inventory.
  s=state();s.joker_limit=3;s.completionist_goal.by_key.j_golden.status='complete'
  context=Shop.new(s,Score,nil,{max_evaluations=50000});before=calls
  local incumbent={action={kind='sell',area='jokers',index=2,followup={kind='buy',area='shop_jokers',index=1}}}
  advice,d=Goal.suggest(s,mods,incumbent,context)
  check(advice and d.complete,'retaining Perkeo can beat a fully projected replacement')
  eq(context.evaluations,calls-before,'retention charges every shared real score call')
  eq(advice.action.kind,'reorder_jokers','retention delivers the actual exit setup before leaving')
  eq(d.selected.shop_exit.copy_events,2,'retention value includes exactly two future immediate copies')
  eq(d.before_missing,0,'selling Perkeo removes its exact missing key from the incumbent')
  eq(d.after_missing,1,'holding adds one distinct missing key over that incumbent')
  check(d.selected.first_hand_policy.comparison.policies[1].comparisons[1],'retention contains complete use alternatives rather than a fixed hold heuristic')
  -- Buying Perkeo from a previously non-generating row must activate exactly
  -- the same full-family qualification; an unqualified name is insufficient.
  s=state();s.jokers[2]=joker('j_golden','g','Golden Joker',{extra=4,eternal=true})
  s.shop_jokers={joker('j_perkeo','new-p','Perkeo')};s.consumeables[1].copy_source=nil
  advice,d=Goal.suggest(s,mods,{action={kind='leave_shop'}},Shop.new(s,Score))
  check(not advice and not d.complete,'offered Perkeo cannot bypass whole-inventory qualification')
end

do
  -- Scalar non-Bell fallback historically may optimize a different order for
  -- each sample. The new joint policy needs the existing fixed-layout helper.
  local s=assert(Perkeo.project(state(),mods));s.phase='blind'
  s.next_blind={key='bl_final_vessel',name='Violet Vessel',boss=true,chips=600,ante=8}
  local advice,work,d=delivery(s)
  check(not advice and not d.complete,'a scalar forecast without a fixed physical-layout receipt cannot deliver a joint policy')
  local Finish=dofile(r..'blind_finishing.lua')
  for _,key in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do Finish[key]=dofile(r..key..'.lua') end
  Finish.strategy=Strategy;Shop.blind_finishing=Finish
  advice,work,d=delivery(s)
  check(advice and d.complete and advice.action.kind=='use','non-Bell fixed-layout forecast delivers the same complete nonlinear owned-use policy')
  local family=assert(Pool.planet_family(s,Consumables))
  local c=Shop.new(s,Score);local evidence=c:compare(family[1].state,family[2].state)
  check(Goal.validate_inventory_opening(evidence,600,'bl_final_vessel',Bell),'a complete common-world fixed-layout receipt qualifies')
  local wrong=copy(evidence);wrong.common_worlds.world_ids[1]=4
  check(not Goal.validate_inventory_opening(wrong,600,'bl_final_vessel',Bell),'mismatched common-world identities cannot qualify')
  wrong=copy(evidence);wrong.after_readiness.ordering=nil
  check(not Goal.validate_inventory_opening(wrong,600,'bl_final_vessel',Bell),'after ordering cannot be dropped while retaining scalar floors')
  wrong=copy(evidence);wrong.after_readiness.ordering.selection='best_order_per_future_world'
  check(not Goal.validate_inventory_opening(wrong,600,'bl_final_vessel',Bell),'clairvoyant per-world order selection is rejected')
  Shop.blind_finishing=nil
end

do
  for _,mutate in ipairs({
    function(s) s.next_blind.key='bl_small';s.next_blind.boss=false end,
    function(s) s.ante=7 end,
    function(s) s.completionist_goal.metadata_status='unknown' end,
    function(s) s.completionist_goal.eligibility.eligible=false end,
    function(s) s.consumeables[1].copy_source=nil end,
    function(s) s.consumeables[2]=copy(s.consumeables[1]) end,
    function(s) s.consumeables[1].copy_source.params.playing_card=1 end,
    function(s) s.consumeables[1].base={} end,
    function(s) s.consumeable_buffer=1 end,
    function(s) s.consumeables={hidden_pending=true} end,
    function(s) s.ordering_safe=false end,
    function(s) s.jokers[2].unknown=true end,
    function(s) s.jokers[2].cost=nil end}) do
    local s=state();s.phase='blind';mutate(s)
    local advice,work,d=delivery(s)
    check(not advice and not d.complete,'missing public source/progress/settlement information cannot authorize a use')
  end
  local s=state();s.phase='blind'
  local advice,work,d=delivery(s,{max_evaluations=1})
  check(not advice and not d.complete,'insufficient aggregate budget cannot publish the best partial policy')
  check(work<=1,'tiny explicit allowance is respected')
  s.next_blind.chips=1e12
  advice,work,d=delivery(s)
  check(not advice and not d.complete,'unsupported survival margin earns no prepared-policy override')
  s=state();s.phase='blind';s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=nil
  advice,work,d=delivery(s)
  check(not advice,'unknown perish timing fails closed')
end

do
  local s=state();s.phase='blind';local before=calls
  local result=Decision.run(s,mods)
  check(result and result.action.kind=='use','the real decision entry point invokes actual Planet delivery')
  eq(result.evaluations,calls-before,'decision aggregate includes all complete owned-policy work')
  local fallback=setmetatable({gold_planet_policy={suggest=function() return nil,49999,{complete=false} end},
    blind_prep={suggest=function() return {action={kind='reorder_jokers',order={1,2,3}}},{} end}},{__index=mods})
  result=Decision.run(s,fallback)
  eq(result.evaluations,49999,'failed preparation work is retained even when ordinary blind preparation returns early')
end

print('advisor_gold_planet_policy: '..checks..' checks passed; '..calls..' actual score calls across independent synthetic cases')
