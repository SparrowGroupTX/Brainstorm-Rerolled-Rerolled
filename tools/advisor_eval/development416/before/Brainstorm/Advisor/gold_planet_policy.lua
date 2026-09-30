-- Actual final-blind delivery of a freshly recomputed complete Planet policy.
-- No remembered promise, generated identity guess, save state, or RNG access.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
function M.suggest(s,modules,yield_fn,options)
  options=options or {};local d={complete=false,evaluations=0,scope='final_boss_owned_planet_delivery'}
  local function no(reason) d.reason=reason;return nil,0,d end
  local b,g=s.next_blind or {},s.completionist_goal
  if s.phase~='blind' or b.boss~=true or s.ante~=s.win_ante or b.ante~=s.win_ante or
      not ({bl_final_vessel=true,bl_final_leaf=true,bl_final_bell=true})[b.key] or not finite(b.chips) or b.chips<=0 then
    return no('The exact final supported boss must be next.')
  end
  if type(g)~='table' or g.schema~=1 or g.goal~='gold_stickers' or g.metadata_status~='complete' or
      g.catalog_status~='complete' or g.held_status~='complete' or not g.eligibility or g.eligibility.eligible~=true then
    return no('Complete eligible Gold progress is required.')
  end
  if not modules.gold_goal or not modules.gold_goal.validate_inventory_opening or not modules.gold_goal.stable_card or
      not modules.perkeo_inventory or not modules.shop_scoring or not modules.scoring or not modules.consumables then
    return no('The complete owned-policy dependencies are unavailable.')
  end
  if s.ordering_safe==false or s.jokers_shuffling or #(s.jokers or {})>6 or
      type(s.consumeables)~='table' or s.consumeable_buffer~=0 then
    return no('Owned inventory and Joker order must be settled and bounded.')
  end
  local missing,ids=false,{}
  for _,j in ipairs(s.jokers or {}) do
    local progress=g.by_key and g.by_key[j.key]
    if not modules.gold_goal.stable_card(j,modules.gold_perkeo) or ids[tostring(j.id)] or
        not progress or (progress.status~='missing' and progress.status~='complete') or j.face_down or j.unknown then
      return no('Every retained Joker needs an exact visible supported identity and progress status.')
    end
    ids[tostring(j.id)]=true;missing=missing or progress.status=='missing'
  end
  if not missing then return no('No missing retained Joker needs a final-boss delivery policy.') end
  local sample=copy(s);sample.phase='shop'
  local family,why=modules.perkeo_inventory.planet_family(sample,modules.consumables)
  if not family then return no(why) end
  local cap=math.max(0,math.min(50000,math.floor(tonumber(options.max_evaluations) or 50000)))
  local function validate(e,target) return modules.gold_goal.validate_inventory_opening(e,target,b.key,modules.bell_opening) end
  -- At the final boss there is no remaining Ante-8 development goal. First
  -- check the actual row while holding the entire qualified inventory. This
  -- deliberately trades surplus sampled score for fewer real setup actions;
  -- it does not replace the non-regression comparison used for Joker buys.
  local probe=modules.shop_scoring.new(sample,modules.scoring,yield_fn,
    {max_evaluations=math.min(5000,cap),current_order_opening_only=true})
  local evidence=probe:compare(sample,sample)
  local low,delta=validate(evidence,b.chips)
  local order=evidence and evidence.after_readiness and evidence.after_readiness.ordering
  local unchanged=order and order.action_count==0 and type(order.order)=='table' and #order.order==#s.jokers
  for i,index in ipairs(order and order.order or {}) do unchanged=unchanged and i==index end
  d.pace_check={evaluations=probe.evaluations,truncated=probe.truncated,minimum=low,margin=2,
    current_order=not not unchanged,complete=low~=nil,evidence=evidence}
  if low and low>=2*b.chips and delta==0 and unchanged then
    local base=modules.strategy and modules.strategy.advise(s)
    if base and base.action and base.action.kind=='select_blind' and base.action.blind=='Boss' then
      local action=copy(base.action)
      d.complete=true;d.evaluations=probe.evaluations;d.minimum_after=low;d.minimum_delta=delta
      d.planned_consumable_actions={};d.delivered_action=copy(action);d.pace_sufficient=true
      return {title='Select the final boss: the current build is ready',action=action,
        lines={'Keep the current inventory and Joker arrangement: all four checked openings score at least twice the final target.',
          'Avoid extra Planet uses and setup actions. These composition samples are not a guarantee or measured win probability.'},
        warnings={},needs_refresh=true,gold_planet_policy=d},probe.evaluations,d
    end
  end
  -- A failed or insufficient check spends part of the same 50k allowance;
  -- every complete use-family alternative must still fit the remainder.
  local context=modules.shop_scoring.new(sample,modules.scoring,yield_fn,{max_evaluations=cap-probe.evaluations})
  local function work() return probe.evaluations+context.evaluations end
  local selected,comparison=modules.perkeo_inventory.compare_families(family,family,context,validate,b.chips)
  d.evaluations=work();d.comparison=comparison;d.truncated=context.truncated
  if not selected or not comparison.complete or not selected.eligible then
    d.reason=comparison.reason or 'No one fixed owned-use policy preserves every alternative and clears with the required margin.'
    return nil,work(),d
  end
  local variant=selected.variant;local action=variant.actions[1]
  local title,lines
  if action then
    local owned=s.consumeables[action.index]
    if not owned or owned.id~=action.id or owned.key~=action.key then
      d.reason='The first consumable action no longer matches its actual physical identity.';return nil,work(),d
    end
    action={kind='use',area='consumeables',index=action.index,targets={}}
    title='Use '..tostring(owned.name or owned.key)..' before the final boss'
    lines={'One complete fixed policy uses '..variant.action_count..' of the currently held Planets; ordinary and Negative capacity effects were compared separately.',
      'Use only this actual held card, then refresh. The remaining policy is recomputed from the new public state.'}
  else
    local order=selected.evidence.after_readiness and selected.evidence.after_readiness.ordering
    if order and order.action_count==1 then
      local used={}
      if type(order.order)~='table' or #order.order~=#s.jokers then d.reason='The scoring layout is incomplete.';return nil,work(),d end
      for i,index in ipairs(order.order) do
        local j=s.jokers[index]
        if not j or used[index] or ((j.pinned or (j.ability or {}).pinned) and i~=index) then
          d.reason='The scored Joker layout is not a legal permutation.';return nil,work(),d
        end
        used[index]=true
      end
      action={kind='reorder_jokers',area='jokers',order=copy(order.order)}
      title='Arrange the final-boss scoring row'
      lines={'Holding the current Planet inventory dominates its bounded use alternatives in all sampled worlds.',
        'Apply this actual scoring arrangement, then refresh before selecting the final boss.'}
    else
      -- Use the ordinary provider's exact legal visible blind action; never
      -- manufacture a blind name from a projected shop state.
      local base=modules.strategy and modules.strategy.advise(s)
      if not base or not base.action or base.action.kind~='select_blind' or base.action.blind~='Boss' then
        d.reason='The final Boss selection is not the ordinary legal visible action.';return nil,work(),d
      end
      action=copy(base.action);title=#s.consumeables>0 and 'Keep the Planets and select the final boss' or 'Select the prepared final boss'
      lines={'The complete four-world comparison favors keeping this inventory for the opening hand.',
        'This result covers the supported opening policy; later draws remain unresolved.'}
    end
  end
  d.complete=true;d.minimum_after=selected.low;d.minimum_delta=selected.delta
  d.planned_consumable_actions=copy(variant.actions);d.delivered_action=copy(action)
  lines[#lines+1]='Every compared opening clears with at least 25% margin. These samples are not a guarantee or measured win probability.'
  return {title=title,action=action,lines=lines,warnings={},needs_refresh=true,gold_planet_policy=d},work(),d
end
return M
