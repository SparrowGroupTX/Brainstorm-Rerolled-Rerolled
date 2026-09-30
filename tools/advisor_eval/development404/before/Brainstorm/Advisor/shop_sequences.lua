-- Bounded, visible shop plans. Every admitted final build is compared before
-- publishing one action; no pack contents, reroll offers or random uses are invented.
local M={}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function copy(v,seen)
  if type(v)~='table' then if type(v)=='function' then return nil end;return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out
  for k,x in pairs(v) do if k~='_shop_scoring' and k~='_readiness' then out[k]=copy(x,seen) end end
  return out
end
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,out={},{}
  for k in pairs(v) do if k~='_shop_scoring' and k~='_readiness' then keys[#keys+1]=k end end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(v[k]) end
  return '{'..table.concat(out,';')..'}'
end
local function ability(c) return c.ability or {} end
local function negative(c) return c.edition=='negative' or type(c.edition)=='table' and c.edition.negative end
local function label(c) return c.name or ability(c).name or c.key or 'card' end
local planets={c_pluto=true,c_mercury=true,c_uranus=true,c_venus=true,c_saturn=true,c_jupiter=true,
  c_earth=true,c_mars=true,c_neptune=true,c_planet_x=true,c_ceres=true,c_eris=true}
local function active(s,key)
  for _,j in ipairs(s.jokers or {}) do if j.key==key and not j.debuff then return true end end
  return false
end
local function cash(s,delta)
  local before=num(s.dollars);s.dollars=before+delta
  local tax=num((s.modifiers or {}).minus_hand_size_per_X_dollar)
  if tax>0 then s.hand_size=num(s.hand_size,8)+math.floor(before/tax)-math.floor(s.dollars/tax) end
end
local function pricing(s,card,in_shop,delta)
  local a=ability(card);local f=s.shop_forecast or {}
  local discount=num(f.discount_percent)
  local old_inflation=num(f.inflation)
  local price
  if type(card.base_cost)=='number' then
    local e=type(card.edition)=='table' and card.edition or {[tostring(card.edition)]=true}
    local extra=(e.holo and 3 or 0)+(e.foil and 2 or 0)+(e.polychrome and 5 or 0)+(e.negative and 5 or 0)
    price=math.max(1,math.floor((card.base_cost+extra+old_inflation+delta+0.5)*(100-discount)/100))
  elseif discount==0 and not active(s,'j_astronomer') and num(card.cost)>0 and not a.couponed then
    price=num(card.cost)+delta
  elseif a.rental then price=1
  elseif planets[card.key] and active(s,'j_astronomer') then price=0
  else return nil,'Exact repricing needs the card base cost and discount metadata.' end
  if planets[card.key] and active(s,'j_astronomer') then price=0 end
  if a.rental then price=1 end
  card.sell_cost=math.max(1,math.floor(price/2))+num(a.extra_value)
  card.cost=in_shop and a.couponed and 0 or price
  return true
end
local function reprice(s,delta)
  for _,area in ipairs({'jokers','consumeables','shop_jokers'}) do
    for _,card in ipairs(s[area] or {}) do
      local ok,reason=pricing(s,card,area=='shop_jokers',delta)
      if not ok then return nil,reason end
    end
  end
  s.shop_forecast=s.shop_forecast or {}
  s.shop_forecast.inflation=num(s.shop_forecast.inflation)+delta
  return s
end

-- The injected callbacks are the same detached resource/retained-row valuation
-- helpers used by ordinary single-action strategy. This layer owns shop removal,
-- sequential prices, Planet inventory/use, and buying allowance/interest changes.
function M.transition(snapshot,action,modules)
  local strategy=modules.strategy;local api=strategy and strategy.shop_sequence_api
  if not api then return nil,'Shop transition helpers are unavailable.' end
  local state=copy(snapshot)
  if action.kind=='buy' and action.area=='shop_jokers' then
    local c=state.shop_jokers and state.shop_jokers[action.index]
    if not c then return nil,'The visible offer is missing.' end
    local category=api.kind(c)
    if category~='joker' and not planets[c.key] then return nil,'Only visible Jokers and supported Planets enter these plans.' end
    if c.debuff then return nil,'A debuffed shop offer is unsupported.' end
    if category=='joker' and (state.modifiers or {}).no_shop_jokers then return nil,'Shop Joker purchases are forbidden.' end
    if not api.capacity(state,c,false) then return nil,'There is no legal inventory slot.' end
    if num(c.cost)>0 and num(c.cost)>num(state.dollars)-num(state.bankrupt_at) then return nil,'This step is unaffordable.' end
    local _,_,known=api.card_value(state,c)
    if category=='joker' and known==false and not (modules.shop_scoring and modules.shop_scoring.known_joker(c.key)) then
      return nil,'Unknown Joker purchase effects are unsupported.'
    end
    if category=='joker' and c.key=='j_madness' and api.joker_admission then
      local admitted,why=api.joker_admission(state,c)
      if not admitted then return nil,why and why.reason or 'Destructive Joker purchase is not admitted.' end
    end
    if category=='joker' then
      state=api.after_joker_purchase(state,c)
    else
      state.consumeables=state.consumeables or {};state.consumeables[#state.consumeables+1]=c
      if negative(c) then state.consumable_limit=num(state.consumable_limit,2)+1 end
      cash(state,-num(c.cost))
    end
    table.remove(state.shop_jokers,action.index)
    state.current_round=state.current_round or {}
    if category=='joker' then state.current_round.jokers_purchased=num(state.current_round.jokers_purchased)+1 end
    if (state.modifiers or {}).inflation or c.key=='j_astronomer' then
      return reprice(state,(state.modifiers or {}).inflation and 1 or 0)
    end
    return state
  elseif action.kind=='sell' and action.area=='jokers' then
    local c=state.jokers and state.jokers[action.index]
    if not c then return nil,'The owned Joker is missing.' end
    if (state.modifiers or {}).all_eternal or ability(c).eternal or c.pinned or ability(c).pinned then return nil,'The owned Joker is protected from this sale plan.' end
    local _,_,known=api.card_value(state,c)
    if known==false and not (modules.shop_scoring and modules.shop_scoring.known_joker(c.key)) then
      return nil,'Unknown Joker sale effects are unsupported.'
    end
    if c.key=='j_luchador' or c.key=='j_diet_cola' then return nil,'This sale changes blind or tag state outside the short-plan model.' end
    if c.key=='j_astronomer' then
      for _,area in ipairs({'jokers','consumeables','shop_jokers'}) do for _,other in ipairs(state[area] or {}) do
        if type(other.base_cost)~='number' then return nil,'Removing Astronomer needs exact base prices.' end
      end end
    end
    state=api.after_joker_sale(state,action.index)
    if not state then return nil,'This sale can create a random replacement.' end
    if c.key=='j_astronomer' then return reprice(state,0) end
    return state
  elseif action.kind=='use' and action.area=='consumeables' then
    local c=state.consumeables and state.consumeables[action.index]
    if c and c.key=='c_fool' then
      if not modules.pack_scoring or not modules.pack_scoring.project_owned_fool then return nil,'Owned Fool projection is unavailable.' end
      return modules.pack_scoring.project_owned_fool(snapshot,action.index,modules)
    end
    if not c or not planets[c.key] then return nil,'Only deterministic held Planet uses enter these plans.' end
    if not modules.consumables or not modules.consumables.apply then return nil,'Planet transitions are unavailable.' end
    local used,reason=modules.consumables.apply(state,action.index,{})
    if not used then return nil,reason end
    if strategy.preservation_cost then
      local loss,why,last=strategy.preservation_cost(state,used,action.index)
      if last or num(loss)>0 then return nil,why or 'Keep the copying or Observatory inventory value.' end
    end
    return used
  end
  return nil,'The action has no supported short-shop transition.'
end

local function signature(a) return a and table.concat({a.kind or '',a.area or '',tostring(a.index or '')},':') or '' end
local function continuation(plan)
  return {actions=copy(plan.node.actions),titles=copy(plan.node.titles),cash_after=num(plan.node.state.dollars),
    utility=plan.merit,readiness=copy(plan.ready),scoring_evidence=copy(plan.evidence),
    liquidity=copy(plan.liquidity),liquidity_penalty=plan.liquidity_penalty,
    gold_slot_admission=copy(plan.gold_slot_admission),complete=true}
end

-- Used only inside the current decision, after the entire graph has completed.
-- Enriching an unchanged incumbent is essential: a later reroll comparison must
-- see the same visible continuation that the sequence comparison already used.
-- This is evidence for fresh advice, never a queue of actions to execute later.
function M.with_continuation(base,diagnostics)
  if not base or not diagnostics or not diagnostics.complete then return base end
  local plan=(diagnostics.best_by_first_action or {})[signature(base.action)]
  if not plan or not plan.complete or not plan.scoring_evidence then return base end
  local result=copy(base)
  result.shop_sequence=copy(plan)
  result.scoring_evidence=copy(plan.scoring_evidence)
  return result
end
local function describe(action,state)
  local card=(state[action.area] or {})[action.index]
  if action.kind=='buy' then return 'Buy '..label(card)..' ($'..num(card.cost)..')' end
  if action.kind=='sell' then return 'Sell '..label(card)..' #'..action.index..' ($'..num(card.sell_cost)..')' end
  return 'Use '..label(card)
end

local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function whole(v) return finite(v) and v>=0 and v%1==0 end
local function finishing_worlds(finish)
  if not finish or not finish.complete or not finish.supported or not finish.known_mechanics or
      finish.samples~=4 or not finish.selected or type(finish.selected.worlds)~='table' or
      #finish.selected.worlds~=4 then return end
  local mean,clears=0,0
  for index=1,4 do
    local world=finish.selected.worlds[index]
    if type(world)~='table' or type(world.clear)~='boolean' or not finite(world.progress) or world.progress<0 or world.progress>1 or
        world.clear~=(world.progress==1) or not whole(world.hands_used) or not whole(world.discards_used) or
        not finite(world.dollars_after) or not finite(world.population_loss) or world.population_loss<0 or
        not finite(world.finish_reward) or type(world.actions)~='table' or
        not whole(world.setup_actions or 0) or (world.setup_actions or 0)>1 or
        #world.actions~=world.hands_used+world.discards_used+(world.setup_actions or 0) then return end
    local hands,discards,setups=0,0,0
    for position,action in ipairs(world.actions) do
      if type(action)~='table' then return end
      if action.kind=='play' then hands=hands+1 elseif action.kind=='discard' then discards=discards+1
      elseif action.kind=='reorder_jokers' and action.area=='jokers' and action.projected==true and position==1 and
          type(action.order)=='table' and #action.order>=2 and #action.order<=12 and
          type(action.joker_ids)=='table' and #action.joker_ids==#action.order then
        local seen={};local changed=false
        for i,index in ipairs(action.order) do
          if not whole(index) or index<1 or index>#action.order or seen[index] then return end
          seen[index]=true;changed=changed or index~=i
        end
        if not changed then return end
        setups=setups+1
      else return end
    end
    if hands~=world.hands_used or discards~=world.discards_used or setups~=(world.setup_actions or 0) then return end
    mean=mean+world.progress/4;clears=clears+(world.clear and 1 or 0)
  end
  if not finite(finish.selected.mean_progress) or math.abs(mean-finish.selected.mean_progress)>0.000001 or
      finish.selected.clearing_samples~=clears then return end
  return finish.selected.worlds,mean
end
local function finish_certificate(plan,baseline)
  local ready=plan.ready;local root_ready=baseline.ready
  if not ready or not ready.supported or not root_ready or not finite(ready.target) or ready.target<=0 or
      ready.target~=root_ready.target or not finite(plan.node.state.dollars) then return end
  local root_worlds=finishing_worlds(root_ready.finishing)
  if not root_worlds then return end
  local finish=ready.finishing
  if plan~=baseline then
    local e=plan.evidence
    if not e or not e.complete_finishing or e.incomplete or e.samples~=4 or
        e.before_target~=ready.target or e.after_target~=ready.target then return end
    local before=finishing_worlds(e.before_finishing)
    if not before or encode(before)~=encode(root_worlds) then return end
    finish=e.after_finishing
  end
  local worlds,mean=finishing_worlds(finish)
  if not worlds then return end
  return {worlds=worlds,mean=mean,cash=plan.node.state.dollars}
end
-- An exception to opening-only vetoes, not a price for future wins. Existing
-- utility, paid transitions, liquidity and whole-inventory guards still apply.
local function finish_dominates(candidate,reference,baseline)
  local a,b=finish_certificate(candidate,baseline),finish_certificate(reference,baseline)
  if not a or not b then return end
  local strict=false;local payment=b.cash-a.cash
  for i=1,4 do
    local x,y=a.worlds[i],b.worlds[i]
    if x.progress<y.progress or y.clear and not x.clear or x.hands_used>y.hands_used or
        x.discards_used>y.discards_used or #x.actions+#candidate.node.actions>#y.actions+#reference.node.actions or
        x.dollars_after<y.dollars_after-payment-0.000001 or x.population_loss>y.population_loss or
        x.finish_reward<y.finish_reward then return end
    -- A pre-existing clear must not lose a known Blue reward or survivor under
    -- a larger combined cash/reward number. Unknown clear resources decline.
    if y.clear then
      local xr,yr=x.resources,y.resources
      if not xr or not yr or not finite(xr.blue_planets) or not finite(yr.blue_planets) or
          not finite(xr.planet_utility) or not finite(yr.planet_utility) or
          xr.blue_planets<yr.blue_planets or xr.planet_utility<yr.planet_utility or
          yr.blue_planets>0 and xr.planet_hand~=yr.planet_hand or
          type(xr.survivors)~='table' or type(yr.survivors)~='table' or next(yr.survivors)==nil then return end
      for id in pairs(yr.survivors) do if not xr.survivors[id] then return end end
    end
    strict=strict or x.progress>y.progress+0.000001
  end
  if not strict then return end
  return {complete=true,samples=4,before_mean_progress=b.mean,after_mean_progress=a.mean,
    endpoint_cash_before=b.cash,endpoint_cash_after=a.cash,additional_paid_cash=payment,
    scope='Complete fixed-policy progress improves without worse paired actions, population, known rewards or cash beyond the exact paid endpoint difference; future-run value remains heuristic.'}
end

function M.suggest(snapshot,modules,base,context,options)
  options=options or {}
  local diagnostics={complete=false,states=0,comparisons=0,rejected={},plans={},scope='Complete supported graph: at most two visible Joker/Planet buys, one original Joker sale, one Planet use and one original ordinary Fool copying the played main Planet with an already free slot. Unsupported transitions are listed separately.'}
  local function stop(reason) diagnostics.reason=reason;return nil,diagnostics end
  local strategy=modules.strategy;local api=strategy and strategy.shop_sequence_api
  if snapshot.phase~='shop' or not api or not context or not context.readiness then return stop('No supported shop sequence context.') end
  local slots=modules.gold_slot or strategy.gold_slot
  if slots and type(slots.endpoint)~='function' then return stop('Collection slot endpoint admission is unavailable.') end
  local ready=context:readiness(snapshot)
  local rescuing=context.survival_dominated_actions and next(context.survival_dominated_actions)~=nil
  if not ready or not ready.supported or ready.status=='sampled_safe' and not rescuing then
    return stop('Sequence search is reserved for a supported scoring shortfall, unresolved finish or an otherwise useful purchase needing a visible rescue.')
  end
  local base_action=base and base.action or {kind='leave_shop'}
  if base_action.kind~='leave_shop' and not (base_action.kind=='buy' and base_action.area=='shop_jokers') and
      not (base_action.kind=='sell' and base_action.area=='jokers') and
      not (base_action.kind=='use' and base_action.area=='consumeables') then
    return stop('The existing action has an outcome outside the supported sequence comparison.')
  end
  if #(snapshot.shop_jokers or {})>3 or #(snapshot.jokers or {})>6 or #(snapshot.consumeables or {})>4 then
    return stop('This visible action graph exceeds the small-shop admission bounds.')
  end
  local root=copy(snapshot)
  local fool_id
  for index,c in ipairs(snapshot.consumeables or {}) do if c.key=='c_fool' then
    if not modules.pack_scoring or not modules.pack_scoring.owned_fool_candidate or not modules.pack_scoring.project_owned_fool then
      return stop('A held Fool requires the complete owned-copy comparison dependencies.')
    end
    local candidate=modules.pack_scoring.owned_fool_candidate(snapshot,index,modules)
    if candidate then
      -- Validate the raw catalog before graph copying can discard callbacks.
      -- Failure of an admitted copy aborts rather than deleting that branch.
      local projected,reason=modules.pack_scoring.project_owned_fool(snapshot,index,modules)
      if not projected then return stop(reason or 'An admitted owned Fool projection is unavailable.') end
      fool_id=candidate.id
    end
  end end
  if fool_id and (not modules.consumables or not modules.consumables.apply) then return stop('The copied Planet transition is unavailable.') end
  diagnostics.owned_fool_id=fool_id
  local originals={};for i in ipairs(root.jokers or {}) do originals[i]=true end
  local nodes={{state=root,actions={},titles={},buys=0,sales=0,uses=0,fool_uses=0,cost=0,used_inventory_value=0,originals=originals}}
  local seen={[encode(root)..':0:0:0']=true}
  local max_states=math.max(1,math.min(96,math.floor(num(options.max_states,64))))
  local function reject(reason) diagnostics.rejected[reason or 'Unsupported transition.']=true end
  local required_failure
  local function append(node,action,required)
    local state,reason=M.transition(node.state,action,modules)
    if not state then
      reject(reason)
      if required then required_failure=reason or 'An admitted owned Fool transition is unsupported.';return false end
      return true
    end
    local buys=node.buys+(action.kind=='buy' and 1 or 0)
    local sales=node.sales+(action.kind=='sell' and 1 or 0)
    local used_card=action.kind=='use' and (node.state.consumeables or {})[action.index]
    local uses=node.uses+(used_card and planets[used_card.key] and 1 or 0)
    local fool_uses=node.fool_uses+(used_card and used_card.key=='c_fool' and 1 or 0)
    local actions,titles=copy(node.actions),copy(node.titles)
    local kept=copy(node.originals)
    if action.kind=='sell' then table.remove(kept,action.index)
    elseif action.kind=='buy' and api.kind(node.state.shop_jokers[action.index])=='joker' then kept[#kept+1]=false end
    actions[#actions+1]=action;titles[#titles+1]=describe(action,node.state)
    local cost=node.cost+2
    local used_inventory_value=node.used_inventory_value
    if action.kind=='buy' then
      local card=node.state.shop_jokers[action.index]
      -- Liquidity is assessed once at the fully scored endpoint. Step-local
      -- readiness can miss a later rental sale or a blind-start resource change.
      cost=cost+api.purchase_penalty(node.state,num(card.cost),card,state,nil,true)
    elseif action.kind=='sell' then cost=cost+6
    elseif used_card and planets[used_card.key] and strategy.inventory_value then
      local _,before_inventory=strategy.inventory_value(node.state)
      local _,after_inventory=strategy.inventory_value(state)
      -- The Planet became a permanent hand level. Carry its already-owned
      -- direct utility across that deterministic conversion; the paired score
      -- comparison still decides whether using it actually improves this build.
      used_inventory_value=used_inventory_value+math.max(0,num(before_inventory.direct)-num(after_inventory.direct))
    end
    -- Preserve every first-action alternative even if later transitions reach
    -- the same inventory. Otherwise an earlier-enumerated path could erase the
    -- best continuation of the existing recommendation.
    local key=encode(state)..':'..buys..':'..sales..':'..uses..':'..fool_uses..':'..signature(actions[1])..':'..cost..':'..used_inventory_value..':'..encode(kept)
    if seen[key] then return true end
    if #nodes>=max_states then return false end
    seen[key]=true
    nodes[#nodes+1]={state=state,actions=actions,titles=titles,buys=buys,sales=sales,uses=uses,fool_uses=fool_uses,cost=cost,
      fool_copy_id=used_card and used_card.key=='c_fool' and reason.created_id or node.fool_copy_id,
      used_inventory_value=used_inventory_value,originals=kept}
    return true
  end
  local cursor=1
  while cursor<=#nodes do
    local node=nodes[cursor];cursor=cursor+1
    if node.buys<2 then
      for index,c in ipairs(node.state.shop_jokers or {}) do
        if api.kind(c)=='joker' or planets[c.key] then
          if not append(node,{kind='buy',area='shop_jokers',index=index}) then return stop('The complete visible graph exceeds the state bound; no partial plan is used.') end
        end
      end
    end
    if node.sales<1 then
      for index,c in ipairs(node.state.jokers or {}) do
        -- One existing sale is enough for this slice. No speculative flipping.
        if node.originals[index] and not c.pinned and not ability(c).pinned and not ability(c).eternal and not (node.state.modifiers or {}).all_eternal then
          if not append(node,{kind='sell',area='jokers',index=index}) then return stop('The complete visible graph exceeds the state bound; no partial plan is used.') end
        end
      end
    end
    if node.uses<1 then
      for index,c in ipairs(node.state.consumeables or {}) do if planets[c.key] then
        if not append(node,{kind='use',area='consumeables',index=index,targets={}},node.fool_copy_id==c.id) then
          return stop(required_failure or 'The complete visible graph exceeds the state bound; no partial plan is used.')
        end
      end end
    end
    if fool_id and node.fool_uses<1 then
      for index,c in ipairs(node.state.consumeables or {}) do if c.id==fool_id then
        local candidate=modules.pack_scoring.owned_fool_candidate(node.state,index,modules)
        if candidate and not append(node,{kind='use',area='consumeables',index=index,targets={}},true) then
          return stop(required_failure or 'The complete visible graph exceeds the state bound; no partial plan is used.')
        end
      end end
    end
  end
  diagnostics.states=#nodes
  root._readiness=ready
  local before_value=api.build_value(root)
  local before_inventory=strategy.inventory_value and strategy.inventory_value(root) or 0
  local baseline={node=nodes[1],merit=0,ready=ready,evidence={ratio=1,adjustment=0,
    before_readiness=ready,after_readiness=ready,before_mean=ready.opening_mean,after_mean=ready.opening_mean}}
  local complete_finishing_family=finish_certificate(baseline,baseline)~=nil
  local best=baseline;local existing=base_action.kind=='leave_shop' and baseline or nil
  local first_actions={[signature({kind='leave_shop'})]=baseline}
  local function better(a,b)
    if not b or a.merit>b.merit+0.000001 then return true end
    if math.abs(a.merit-b.merit)<0.000001 then
      local aa,bb=signature(a.node.actions[1]),signature(b.node.actions[1])
      if aa==signature(base_action) and bb~=aa then return true end
      if aa~=bb then return aa<bb end
      return #a.node.actions<#b.node.actions
    end
    return false
  end
  diagnostics.plans[1]={actions={},merit=0,cash=num(root.dollars),readiness=ready.status}
  for i=2,#nodes do
    local node=nodes[i]
    -- An unaccompanied sale is never a useful short plan; its role is to fund or
    -- make room for an actual offered upgrade (or preserve a Planet use).
    if node.buys>0 or node.uses>0 or node.fool_uses>0 then
      local evidence=context:compare(root,node.state)
      diagnostics.comparisons=diagnostics.comparisons+1
      if not evidence or not evidence.after_readiness or not evidence.after_readiness.supported then
        return stop(context.unavailable_reason or 'A final build lacks a complete supported paired scoring comparison.')
      end
      local r=evidence.after_readiness
      local dominated=strategy.survival_dominated and strategy.survival_dominated(evidence)
      node.state._readiness=r
      local gain=(num(r.opening_mean)-num(ready.opening_mean))/math.max(1,num(ready.target))
      local plan={node=node,ready=r,evidence=evidence}
      if not finish_certificate(plan,baseline) then complete_finishing_family=false end
      local finishing_gain=finish_dominates(plan,baseline,baseline)
      local used_finish_exception=false
      if ready.status=='sampled_deficit' and finishing_gain then
        gain=finishing_gain.after_mean_progress-finishing_gain.before_mean_progress
        used_finish_exception=true
      end
      local inventory=strategy.inventory_value and strategy.inventory_value(node.state) or 0
      local merit=api.build_value(node.state)-before_value+inventory-before_inventory+node.used_inventory_value+num(evidence.adjustment)-node.cost
      local liquidity_penalty,liquidity
      if strategy.liquidity then
        local before_liquidity
        liquidity_penalty,before_liquidity,liquidity=strategy.liquidity.incremental(root,node.state,ready,r)
        merit=merit-liquidity_penalty
      end
      if ready.status=='sampled_deficit' then merit=merit+math.max(-30,math.min(48,48*gain)) end
      if num(evidence.ratio,1)<0.85 then
        if finishing_gain then used_finish_exception=true else merit=-1000000 end
      end
      plan.merit=merit;plan.liquidity=liquidity;plan.liquidity_penalty=liquidity_penalty
      plan.used_finish_exception=used_finish_exception;plan.finishing_gain=finishing_gain
      -- Mechanical transitions remain legal and the whole graph is still
      -- scored. Only selectable final endpoints must satisfy the collection
      -- objective; a later Planet/use cannot excuse a permanent completed slot.
      local admitted,admission=true,nil
      if slots then admitted,admission=slots.endpoint(root,node.state,evidence,node.actions) end
      plan.gold_slot_admission=copy(admission)
      if admitted~=true then reject(admission and admission.reason or 'Collection slot admission declined the final endpoint.') end
      diagnostics.plans[#diagnostics.plans+1]={actions=copy(node.actions),titles=copy(node.titles),merit=merit,
        action_cost=node.cost,used_inventory_value=node.used_inventory_value,planet_uses=node.uses,fool_uses=node.fool_uses,
        cash=num(node.state.dollars),readiness=r.status,opening_mean=r.opening_mean,ratio=evidence.ratio,
        liquidity=liquidity,liquidity_penalty=liquidity_penalty,survival_dominated=not not dominated,
        finishing_gain=copy(finishing_gain),gain_basis=used_finish_exception and 'complete_paired_blind_progress' or 'opening_mean',
        gold_slot_admitted=admitted==true,gold_slot_admission=copy(admission)}
      -- Graph expansion is already complete. Reject only a dominated FINAL
      -- endpoint, so a temporarily weak buy/use/sale can still precede a fully
      -- observed, affordable rescuing continuation.
      if not dominated and admitted==true then
      if better(plan,best) then best=plan end
      local first=signature(node.actions[1])
      if better(plan,first_actions[first]) then first_actions[first]=plan end
      if signature(node.actions[1])==signature(base_action) and better(plan,existing) then existing=plan end
      end
    end
  end
  if base_action.kind~='leave_shop' and not existing then return stop('The existing first action could not be included in the completed comparison.') end
  diagnostics.complete=true
  diagnostics.complete_finishing_family=complete_finishing_family
  diagnostics.best_actions=copy(best.node.actions)
  diagnostics.best_merit=best.merit
  diagnostics.best_by_first_action={}
  for first,plan in pairs(first_actions) do diagnostics.best_by_first_action[first]=continuation(plan) end
  -- Keep the existing utility margin. A weaker opening needs a complete
  -- progress certificate against both saving and the incumbent continuation.
  local reference=existing or baseline
  local opening_improves=num(best.ready.opening_mean)>=math.max(num(ready.opening_mean),num(reference.ready.opening_mean))*1.1
  local finish_exception=complete_finishing_family and best.finishing_gain and finish_dominates(best,reference,baseline)
  diagnostics.finishing_override=copy(finish_exception)
  if #best.node.actions<2 or best.merit<26 or best.merit<reference.merit+8 or
      signature(best.node.actions[1])==signature(base_action) or
      (best.used_finish_exception and not finish_exception) or not opening_improves and not finish_exception then
    return nil,diagnostics
  end
  local lines={'The complete visible sequence improves the sampled scoring plan after its cash, interest, inventory and action costs.',
    table.concat(best.node.titles,'; then ')..'.',best.evidence.reason,
    'Take only this first step, then refresh advice. Later hands, discards and unseen offers are not promised.'}
  return {title=best.node.titles[1],lines=lines,warnings={},action=copy(best.node.actions[1]),
    scoring_evidence=best.evidence,shop_sequence=continuation(best)},diagnostics
end
return M
