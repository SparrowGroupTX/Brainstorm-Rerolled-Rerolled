-- Final-boss cargo comparison. Complete public composition openings only;
-- never a terminal result, sticker award, or calibrated survival probability.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v) return finite(v) and v>=0 and v%1==0 end
local function copy(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out
  for k,x in pairs(v) do if k~='_shop_scoring' and k~='_readiness' then out[k]=copy(x,seen) end end
  return out
end
local function encode(v,seen)
  local kind=type(v)
  if kind=='nil' then return 'n' end
  if kind=='boolean' then return v and 'b1' or 'b0' end
  if kind=='number' then return finite(v) and 'd'..string.format('%.17g',v)..';' or nil end
  if kind=='string' then return 's'..#v..':'..v end
  if kind~='table' or getmetatable(v) then return nil end
  seen=seen or {};if seen[v] then return nil end;seen[v]=true
  local parts={}
  for k,x in pairs(v) do if k~='_shop_scoring' and k~='_readiness' then
    local a,b=encode(k,seen),encode(x,seen)
    if not a or not b then seen[v]=nil;return nil end
    parts[#parts+1]=a..b
  end end
  table.sort(parts);seen[v]=nil
  return 't'..#parts..':'..table.concat(parts)..'e'
end
-- Explicit source identities with no automatic Joker creation/destruction.
-- Their current scoring still needs every complete nonrandom comparison.
-- Counters and deterministic income may change; no future payout is spent.
-- Enhancement-replacing Midas/Vampire are outside this first cargo boundary.
local stable={}
for key in ([=[j_joker j_greedy_joker j_lusty_joker j_wrathful_joker j_gluttenous_joker
j_jolly j_zany j_mad j_crazy j_droll j_sly j_wily j_clever j_devious j_crafty
j_half j_stencil j_four_fingers j_mime j_credit_card j_banner j_mystic_summit
j_loyalty_card j_dusk j_raised_fist j_fibonacci j_steel_joker j_scary_face
j_abstract j_delayed_grat j_hack j_pareidolia j_even_steven j_odd_todd j_scholar
j_supernova j_ride_the_bus j_egg j_blackboard j_runner j_splash j_blue_joker
j_constellation j_hiker j_faceless j_green_joker j_card_sharp j_red_card j_square
j_shortcut j_hologram j_baron j_cloud_9 j_rocket j_obelisk j_photograph
j_gift j_erosion j_to_the_moon j_fortune_teller j_juggler j_drunkard j_stone
j_golden j_lucky_cat j_baseball j_bull j_flash j_trousers j_walkie_talkie j_castle
j_smiley j_campfire j_ticket j_acrobat j_sock_and_buskin j_swashbuckler
j_troubadour j_smeared j_throwback j_hanging_chad j_rough_gem j_arrowhead
j_onyx_agate j_glass j_ring_master j_flower_pot j_blueprint j_wee j_merry_andy
j_oops j_seeing_double j_duo j_trio j_family j_order j_tribe j_stuntman
j_brainstorm j_satellite j_shoot_the_moon j_drivers_license j_astronomer
j_burnt j_bootstraps j_caino j_triboulet j_yorick]=]):gmatch('%S+') do stable[key]=true end
local function stable_card(card,perkeo)
  local a=card and card.ability
  if not card or not (stable[card.key] or perkeo and perkeo.accepts_card(card)) or type(a)~='table' or a.set~='Joker' or
      not (type(card.id)=='string' and card.id~='' or finite(card.id)) or
      not finite(card.cost) or card.cost<0 or not finite(card.sell_cost) or card.sell_cost<0 then return false end
  for _,field in ipairs({'eternal','perishable','rental','perma_debuff'}) do
    if a[field]~=nil and type(a[field])~='boolean' then return false end
  end
  if a.perishable and not integer(a.perish_tally) then return false end
  local e=card.edition
  if e~=nil then
    if type(e)~='table' then return false end
    local selected,count=nil,0
    for _,key in ipairs({'foil','holo','polychrome','negative'}) do if e[key] then selected=key;count=count+1 end end
    if count~=1 or e.type~=nil and e.type~=selected then return false end
    for key,value in pairs(e) do
      if ({foil=true,holo=true,polychrome=true,negative=true})[key] then
        if type(value)~='boolean' then return false end
      elseif key=='type' then
        if value~=selected then return false end
      elseif key=='chips' and selected=='foil' or key=='mult' and selected=='holo' or key=='x_mult' and selected=='polychrome' then
        if not finite(value) or value<0 then return false end
      else return false end
    end
  end
  return true
end
local function signature(actions)
  local result={}
  for _,a in ipairs(actions) do result[#result+1]=table.concat({a.kind or '',a.area or '',tostring(a.index or '')},':') end
  return #result==0 and 'leave_shop' or table.concat(result,';')
end
local function progress(state,goal,perkeo)
  local keys,ids,count={},{},0
  for _,card in ipairs(state.jokers or {}) do
    local status=goal.by_key and goal.by_key[card.key]
    status=status and status.status
    if not stable_card(card,perkeo) or ids[tostring(card.id)] or status~='missing' and status~='complete' then return nil end
    ids[tostring(card.id)]=true
    if status=='missing' and not keys[card.key] then keys[card.key]=true;count=count+1 end
  end
  local sorted={};for key in pairs(keys) do sorted[#sorted+1]=key end;table.sort(sorted)
  return count,sorted
end
local function opening(e,target,boss,bell)
  if not e or e.incomplete or e.samples~=4 or e.uncertain~=false or e.temporal or e.before_startup or e.after_startup or
      e.before_target~=target or e.after_target~=target or not finite(e.low_sample_delta) then return nil end
  local after_low=math.huge
  for _,r in ipairs({e.before_readiness,e.after_readiness}) do
    if not r or not r.supported or r.samples~=4 or r.target~=target or
        type(r.opening_scores)~='table' or #r.opening_scores~=4 then return nil end
    for i=1,4 do
      if not finite(r.opening_scores[i]) or r.opening_scores[i]<0 then return nil end
      if r==e.after_readiness then after_low=math.min(after_low,r.opening_scores[i]) end
    end
  end
  local delta=math.huge
  for i=1,4 do delta=math.min(delta,e.after_readiness.opening_scores[i]-e.before_readiness.opening_scores[i]) end
  if boss=='bl_final_bell' then
    if not bell or not bell.compare or e.score_kind~='forced_card_lower_bound' then return nil end
    local forced=bell.compare(e.before_readiness.bell_opening,e.after_readiness.bell_opening,target)
    if not forced then return nil end
    for i=1,4 do
      if forced.before_scores[i]~=e.before_readiness.opening_scores[i] or
          forced.after_scores[i]~=e.after_readiness.opening_scores[i] then return nil end
    end
    after_low=math.min(after_low,forced.minimum_after);delta=math.min(delta,forced.minimum_delta)
  end
  return after_low,math.min(delta,e.low_sample_delta)
end
local function inventory_opening(e,target,boss,bell)
  local worlds=e and e.common_worlds
  if not worlds or worlds.schema~=1 or worlds.kind~='shop_four_common_worlds_v1' or worlds.samples~=4 or
      type(worlds.world_ids)~='table' or #worlds.world_ids~=4 then return nil end
  for i=1,4 do if worlds.world_ids[i]~=i then return nil end end
  for _,r in ipairs({e.before_readiness or {},e.after_readiness or {}}) do
    local o=r.ordering
    if not o or o.samples~=4 or not integer(o.layouts) or o.layouts<1 or
        (o.action_count~=0 and o.action_count~=1) or type(o.order)~='table' or
        (o.selection~='one_fixed_layout_by_complete_common_opening_mean' and
          o.selection~='one_fixed_layout_by_complete_forced_card_floor_mean') then return nil end
  end
  return opening(e,target,boss,bell)
end
local function exact_incumbent(base)
  if type(base)~='table' or type(base.action)~='table' then return nil end
  local a=base.action
  if base.sequence or a.sequence then return nil end
  if a.kind=='leave_shop' then
    if a.followup or base.shop_sequence and (not base.shop_sequence.complete or type(base.shop_sequence.actions)~='table' or #base.shop_sequence.actions>0) then return nil end
    return {}
  end
  if base.shop_sequence then
    local p=base.shop_sequence
    if not p.complete or type(p.actions)~='table' or #p.actions<1 or #p.actions>2 or
        signature({p.actions[1]})~=signature({a}) then return nil end
    for _,step in ipairs(p.actions) do if step.sequence or step.followup then return nil end end
    return copy(p.actions)
  end
  if a.kind=='buy' and a.area=='shop_jokers' and not a.followup then return {copy(a)} end
  local next_action=a.followup
  if a.kind=='sell' and a.area=='jokers' and next_action and next_action.kind=='buy' and next_action.area=='shop_jokers' and
      not next_action.sequence and not next_action.followup then
    return {{kind='sell',area='jokers',index=a.index},{kind='buy',area='shop_jokers',index=next_action.index}}
  end
end
function M.suggest(snapshot,modules,base,context,options)
  options=options or {};modules=modules or {}
  local diag={complete=false,projection_complete=false,evidence_complete=false,comparisons=0,endpoints={},excluded={},samples=4,margin=1.25,
    objective='more_distinct_missing_jokers_subject_to_complete_sampled_clear_margin',
    scope='Final pre-boss shop: every admitted zero/one Joker buy with at most one original sale; four paired nonrandom opening scores, exact paid endpoints and unique missing keys. No sticker is awarded by this projection.'}
  local function no(reason) diag.reason=reason;return nil,diag end
  if type(snapshot)~='table' then return no('A detached public snapshot is required.') end
  local g=snapshot.completionist_goal
  if type(g)~='table' or g.schema~=1 or g.goal~='gold_stickers' or g.metadata_status~='complete' or g.catalog_status~='complete' or
      g.held_status~='complete' or type(g.eligibility)~='table' or g.eligibility.eligible~=true then return no('Complete eligible Gold-sticker metadata is required.') end
  if type(snapshot.jokers)~='table' or type(snapshot.shop_jokers)~='table' or type(snapshot.consumeables)~='table' or
      not integer(snapshot.joker_limit) or not integer(snapshot.consumable_limit) or
      not integer(snapshot.consumeable_buffer or 0) then return no('Exact owned rows and inventory capacities are required.') end
  local b=snapshot.next_blind or {}
  if snapshot.phase~='shop' or b.boss~=true or not integer(snapshot.win_ante) or snapshot.win_ante<1 or
      snapshot.ante~=snapshot.win_ante or b.ante~=snapshot.win_ante or
      not ({bl_final_vessel=true,bl_final_leaf=true,bl_final_bell=true})[b.key] or not finite(b.chips) or b.chips<=0 then
    return no('This comparison requires the final known supported boss immediately after the current shop.')
  end
  if b.key=='bl_final_bell' and not modules.bell_opening then return no('Complete Bell forced-card dependencies are required.') end
  local strategy=modules.strategy;local api=strategy and strategy.shop_sequence_api
  local transition=modules.shop_sequences and modules.shop_sequences.transition
  local liquidity=modules.liquidity or strategy and strategy.liquidity
  if not api or not transition or not liquidity or not liquidity.estimate or not context or not context.compare or
      context.truncated or not finite(context.evaluations) or not finite(context.max_evaluations) or
      context.evaluations>=context.max_evaluations then return no('Supported transitions, liquidity and remaining shared comparison budget are required.') end
  if #(snapshot.shop_jokers or {})>3 or #(snapshot.jokers or {})>6 then return no('The complete shop exceeds three offers or six owned Jokers.') end
  local original_inventory=encode(snapshot.consumeables or {})
  if not original_inventory or not encode(snapshot) then return no('Plain finite public state is required.') end
  local perkeo=modules.gold_perkeo
  local joint_inventory=false
  if #(snapshot.consumeables or {})>0 then
    for _,j in ipairs(snapshot.jokers or {}) do joint_inventory=joint_inventory or j.key=='j_perkeo' end
    for _,j in ipairs(snapshot.shop_jokers or {}) do joint_inventory=joint_inventory or j.key=='j_perkeo' end
  end
  if joint_inventory and (not modules.perkeo_inventory or not modules.gold_planet_policy) then
    return no('Complete nonempty copying and actual owned-policy delivery dependencies are required.')
  end
  local function exit_projection(state)
    if perkeo and perkeo.project then return perkeo.project(state,modules) end
    for _,card in ipairs(state.jokers or {}) do if card.key=='j_perkeo' then
      return nil,'Exact Perkeo shop-exit projection is unavailable.'
    end end
    return state
  end
  local original_exit,exit_reason=exit_projection(snapshot)
  if not original_exit then return no(exit_reason) end
  local count=progress(snapshot,g,perkeo)
  if not count then return no('The current row has unknown progress or effects outside the stable retention scope.') end
  local incumbent=exact_incumbent(base)
  if not incumbent then return no('The exact incumbent continuation is outside this one-buy/one-sale comparison.') end
  local function project(actions)
    local state=copy(snapshot);local buys,sales=0,0;local original={};local titles={}
    for _,c in ipairs(snapshot.jokers or {}) do original[tostring(c.id)]=true end
    for _,a in ipairs(actions) do
      if not integer(a.index) or a.index<1 then return nil,'A selected index is invalid.' end
      local c=(state[a.area] or {})[a.index]
      if a.kind=='buy' and a.area=='shop_jokers' then
        buys=buys+1
        if not c or not stable_card(c,perkeo) then return nil,'A proposed Joker is outside stable supported retention.' end
        if not finite(c.cost) or c.cost<0 or not finite(state.dollars) or not finite(state.bankrupt_at) then
          return nil,'Exact purchase price or borrowing metadata is unavailable.'
        end
        if not api.capacity(state,c,false) or c.cost>0 and c.cost>state.dollars-state.bankrupt_at then
          return nil,'The exact purchase has no slot or is unaffordable.',true
        end
      elseif a.kind=='sell' and a.area=='jokers' then
        sales=sales+1
        if not c or not original[tostring(c.id)] then return nil,'Only an original owned Joker can be sold.' end
        if c.pinned or (c.ability or {}).pinned or (c.ability or {}).eternal or (state.modifiers or {}).all_eternal then
          return nil,'The original Joker cannot legally be sold.',true
        end
      else return nil,'The incumbent contains a use, reroll, pack or unsupported action.' end
      if buys>1 or sales>1 then return nil,'The incumbent exceeds one Joker buy and one original sale.' end
      titles[#titles+1]=(a.kind=='buy' and 'buy ' or 'sell ')..tostring(c.name or c.key)..
        ' ($'..tostring(a.kind=='buy' and c.cost or c.sell_cost)..')'
      local after,reason=transition(state,a,modules)
      if not after then return nil,reason end
      state=after
    end
    if #actions>0 and buys~=1 then return nil,'An unaccompanied sale is not an admitted cargo endpoint.' end
    if encode(state.consumeables or {})~=original_inventory or state.consumable_limit~=snapshot.consumable_limit or
        state.consumeable_buffer~=snapshot.consumeable_buffer or encode(state.playing_cards)~=encode(snapshot.playing_cards) then
      return nil,'A cargo endpoint changes protected consumable inventory or playing-card population.'
    end
    local after_exit,exit_receipt=exit_projection(state)
    if not after_exit then return nil,exit_receipt end
    state=after_exit
    local carried,keys=progress(state,g,perkeo)
    if not carried then return nil,'A resulting row has unknown progress or unsupported retention.' end
    local family
    if joint_inventory then
      local why;family,why=modules.perkeo_inventory.planet_family(state,modules.consumables)
      if not family then return nil,why end
    end
    return {state=state,actions=copy(actions),titles=titles,key=signature(actions),carried=carried,keys=keys,shop_exit=exit_receipt,first_hand_family=family}
  end
  local reference,why=project(incumbent)
  if not reference then return no('The exact incumbent cannot be projected: '..tostring(why)) end
  local root,error=project({});if not root then return no(error) end
  local plans={root};local seen={[root.key]=root}
  local function add(actions)
    local key=signature(actions);if seen[key] then return true end
    local p,reason,blocked=project(actions)
    if not p then
      if not blocked then return false,reason end
      diag.excluded[#diag.excluded+1]={actions=copy(actions),reason=reason};return true
    end
    if #plans>=40 then return false,'The complete endpoint family exceeds forty plans.' end
    plans[#plans+1]=p;seen[key]=p;return true
  end
  for index,c in ipairs(snapshot.shop_jokers or {}) do
    if api.kind(c)=='joker' and stable_card(c,perkeo) then
      local ok,why=add({{kind='buy',area='shop_jokers',index=index}});if not ok then return no(why) end
      for sold,owned in ipairs(snapshot.jokers or {}) do
        if not (owned.ability or {}).eternal and not owned.pinned and not (owned.ability or {}).pinned and not (snapshot.modifiers or {}).all_eternal then
          ok,why=add({{kind='sell',area='jokers',index=sold},{kind='buy',area='shop_jokers',index=index}});if not ok then return no(why) end
          ok,why=add({{kind='buy',area='shop_jokers',index=index},{kind='sell',area='jokers',index=sold}});if not ok then return no(why) end
        end
      end
    else diag.excluded[#diag.excluded+1]={offer=index,reason='Not an admitted stable Joker offer.'} end
  end
  if not seen[reference.key] then return no('The exact incumbent is absent from the complete declared family.') end
  reference=seen[reference.key]
  diag.projection_complete=true;diag.before_missing=reference.carried
  local can_improve=false
  for _,p in ipairs(plans) do can_improve=can_improve or p.carried>reference.carried end
  if not can_improve then
    for _,p in ipairs(plans) do
      diag.endpoints[#diag.endpoints+1]={actions=copy(p.actions),key=p.key,carried_missing=p.carried,
        missing_keys=copy(p.keys),cash_after=p.state.dollars,shop_exit=copy(p.shop_exit),projection_only=true}
    end
    diag.complete=true
    return no('The complete projected family cannot add a distinct missing Joker over the exact incumbent; no opening comparisons were needed.')
  end
  local function compare(left,right)
    local e=context:compare(left.state,right.state);diag.comparisons=diag.comparisons+1
    if context.truncated then return nil,'The shared score allowance could not complete all cargo comparisons.' end
    local low,delta=opening(e,b.chips,b.key,modules.bell_opening)
    if not low then return nil,'An admitted endpoint lacks complete supported nonrandom first-hand evidence.' end
    return {evidence=e,low=low,delta=delta}
  end
  local best
  for _,p in ipairs(plans) do
    local hold,ref,error
    if joint_inventory then
      local references,protected={},{}
      for _,source in ipairs(reference==root and {root,p} or {root,reference,p}) do
        for _,variant in ipairs(source.first_hand_family) do
          references[#references+1]=variant
          if source==p then protected[#protected+1]=#references end
        end
      end
      local function validate(e,target) return inventory_opening(e,target,b.key,modules.bell_opening) end
      local selected,comparison=modules.perkeo_inventory.compare_families(references,p.first_hand_family,context,validate,b.chips,
        {protected_reference_indices=protected})
      diag.comparisons=diag.comparisons+comparison.comparisons
      if not selected or not comparison.complete then return no(comparison.reason or 'The complete post-copy use family is unsupported.') end
      hold={evidence=selected.evidence,low=selected.low,delta=selected.delta,variant=selected.variant,family=copy(comparison),
        policy_preserved=selected.eligible,protected_delta=selected.protected_delta}
      ref=hold -- One fixed after policy preserves its own complete use family.
    else
      hold,error=compare(root,p)
      if not hold then return no(error) end
      ref=reference==root and hold or nil
      if not ref then ref,error=compare(reference,p);if not ref then return no(error) end end
    end
    local evaluated=hold.variant and hold.variant.state or p.state
    local allowance=liquidity.estimate(evaluated,hold.evidence.after_readiness)
    if not allowance or not finite(allowance.purchase_floor) or not finite(allowance.shortfall) or
        not finite(allowance.reserve) or not finite(p.state.dollars) then return no('An endpoint has unsupported immediate cash reserves.') end
    local safe=hold.low>=b.chips*1.25 and ref.low>=b.chips*1.25 and
      (not joint_inventory or hold.policy_preserved==true) and
      p.state.dollars>=allowance.purchase_floor and allowance.shortfall==0
    local row={actions=copy(p.actions),titles=copy(p.titles),key=p.key,carried_missing=p.carried,missing_keys=copy(p.keys),
      cash_after=p.state.dollars,jokers=copy(p.state.jokers),inventory=copy(evaluated.consumeables),shop_exit=copy(p.shop_exit),first_hand_policy=hold.variant and {actions=copy(hold.variant.actions),key=hold.variant.key,comparison=copy(hold.family)} or nil,
      hold_evidence=copy(hold.evidence),incumbent_evidence=copy(ref.evidence),liquidity=copy(allowance),eligible=safe,
      minimum_opening_score=math.min(hold.low,ref.low),minimum_score_delta=math.min(hold.delta,ref.delta),
      surplus_score_traded=math.min(hold.delta,ref.delta)<0,minimum_own_policy_delta=hold.protected_delta,
      setup_actions=joint_inventory and hold.evidence.after_readiness.ordering and hold.evidence.after_readiness.ordering.action_count or
        b.key=='bl_final_bell' and hold.evidence.after_readiness.bell_opening.setup_actions or 0}
    row.projected_actions=#p.actions+row.setup_actions+(p.shop_exit and p.shop_exit.setup_actions or 0)+(hold.variant and hold.variant.action_count or 0);p.projected_actions=row.projected_actions
    diag.endpoints[#diag.endpoints+1]=row;p.receipt=row;p.low=math.min(hold.low,ref.low)
    if safe and p.carried>reference.carried and (not best or p.carried>best.carried or p.carried==best.carried and
        (p.low>best.low or p.low==best.low and (p.state.dollars>best.state.dollars or p.state.dollars==best.state.dollars and
          (p.projected_actions<best.projected_actions or p.projected_actions==best.projected_actions and p.key<best.key)))) then best=p end
  end
  diag.complete=true;diag.evidence_complete=true;diag.incumbent=copy(reference.receipt);diag.before_missing=reference.carried
  if not best then return no('No completed endpoint adds a distinct missing Joker while preserving every sampled clearing margin, its owned-use policy and cash reserves.') end
  diag.selected=copy(best.receipt);diag.after_missing=best.carried
  local action=copy(best.actions[1] or best.shop_exit and best.shop_exit.setup_action or {kind='leave_shop'})
  local first=best.actions[1];local card=first and (snapshot[first.area] or {})[first.index]
  local title=not first and 'Keep the missing Gold-sticker Jokers for the final boss' or
    (first.kind=='sell' and 'Sell ' or 'Buy ')..tostring(card and (card.name or card.key) or 'Joker')..
      ' ($'..tostring(card and (first.kind=='sell' and card.sell_cost or card.cost) or '?')..')'
  return {title=title,action=action,warnings={},completionist_goal=copy(best.receipt),
    lines={'This complete paid endpoint carries '..best.carried..' distinct missing Gold-sticker Joker(s), versus '..reference.carried..' in the current plan.',
      b.key=='bl_final_bell' and 'Every possible forced card in all four sampled first hands clears with at least 25% margin. One fixed Joker layout is used per endpoint; later forced draws remain unresolved.' or
      'All four supported sampled openings clear the final boss with at least 25% margin.',
      best.receipt.surplus_score_traded and 'Trade excess sampled score for another missing sticker opportunity; the lowest paired score change is '..tostring(best.receipt.minimum_score_delta)..' chips. This margin is not a win guarantee.' or
      'Prefer more distinct missing Jokers once the complete sampled clearing margin is met; additional excess score is not required.',
      #best.actions>1 and 'Proposed endpoint: '..table.concat(best.titles,'; then ')..'. Take only the first step, then refresh advice.' or 'Refresh advice after this action.',
      joint_inventory and 'The complete copied-Planet hold/use family includes Observatory and ordinary/Negative slot effects. The final-blind action is recomputed from actual public inventory; generated identity symbols are never executed.' or 'These are composition samples, not a win guarantee. Gold progress changes only after the game records an eligible win.',
      'Gold progress changes only after the game records an eligible win; no terminal outcome is predicted by these samples.'}},diag
end
M.stable_card=stable_card
M.validate_opening=opening
M.validate_inventory_opening=inventory_opening
return M
