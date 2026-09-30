-- One decision entry point for the in-game advisor and headless evaluation.
-- Dependencies are detached modules, never live game callbacks.
local D = {}
local function run(snapshot, modules, yield_fn, options)
  options = options or {}
  if snapshot.phase=='hand' and modules.concealed_belief then
    local belief_options={progress=yield_fn,draws=modules.draws,
      sampled_outcomes=modules.sampled_outcomes,search=modules.search}
    for k,v in pairs(options.concealed_belief or {}) do belief_options[k]=v end
    local belief=modules.concealed_belief.run(snapshot,modules.scoring,belief_options)
    if belief then return belief end
  end
  if snapshot.phase ~= 'hand' then
    local normal=modules.normal_opening and modules.normal_opening.advice(snapshot)
    if normal then return {kind='strategy',strategy=normal,action=normal.action,evaluations=0} end
    local jokerless=modules.jokerless_opening and modules.jokerless_opening.advice(snapshot)
    if jokerless then return {kind='strategy',strategy=jokerless,action=jokerless.action,evaluations=0} end
    if modules.blind_prep then
      local preparation,diagnostics=modules.blind_prep.suggest(snapshot,modules.strategy)
      if preparation then return {kind='strategy',strategy=preparation,action=preparation.action,evaluations=0,
        preparation_diagnostics=diagnostics} end
    end
    local opening=modules.opening and modules.opening.advice(snapshot)
    if opening then return {kind='strategy',strategy=opening,action=opening.action,evaluations=0} end
    local tactical_pack=false
    if snapshot.phase=='pack' then
      for _,card in ipairs(snapshot.pack_cards or {}) do
        if (card.ability or {}).set=='Joker' or (card.key or ''):sub(1,2)=='j_' or
          modules.pack_scoring and modules.pack_scoring.supports(card) then tactical_pack=true end
      end
    end
    local context=(snapshot.phase=='shop' or tactical_pack) and modules.shop_scoring and
      modules.shop_scoring.new(snapshot,modules.scoring,yield_fn,options.shop_scoring)
    local function advise(ctx)
      local provider=modules.strategy
      if ctx then provider=setmetatable({advise=function(state)
        return modules.strategy.advise(state,{shop_scoring=ctx})
      end},{__index=modules.strategy}) end
      local strategy=provider.advise(snapshot)
      if modules.economy then
        strategy=modules.economy.suggest(snapshot,provider,modules.consumables,strategy) or strategy
      end
      return strategy
    end
    local strategy=advise(context)
    local sequence_diagnostics
    if snapshot.phase=='shop' and modules.shop_sequences and context and not context.truncated then
      local sequence
      sequence,sequence_diagnostics=modules.shop_sequences.suggest(snapshot,modules,strategy,context,options.shop_sequences)
      if sequence then strategy=sequence end
      if modules.shop_sequences.with_continuation then
        strategy=modules.shop_sequences.with_continuation(strategy,sequence_diagnostics)
      end
    end
    if snapshot.phase=='shop' and modules.strategy.shortfall_reroll and context and not context.truncated then
      strategy=modules.strategy.shortfall_reroll(snapshot,strategy,context) or strategy
    end
    local gold_diagnostics
    if snapshot.phase=='shop' and snapshot.completionist_goal and modules.gold_goal and context and not context.truncated then
      local goal
      goal,gold_diagnostics=modules.gold_goal.suggest(snapshot,modules,strategy,context,options.gold_goal)
      if goal and gold_diagnostics and gold_diagnostics.complete and not context.truncated then strategy=goal end
    end
    if context and (context.truncated or strategy.pack_diagnostics and strategy.pack_diagnostics.incomplete) then
      -- Partial coverage cannot favor candidates evaluated first. Fall back as
      -- a whole decision, including all proposed sales and cash-use sequences.
      local attempted=strategy.pack_diagnostics
      strategy=advise(nil)
      if attempted and strategy.pack_diagnostics then
        strategy.pack_diagnostics.tactical_fallback=true
        strategy.pack_diagnostics.fallback_reason=attempted.incomplete_reason or context.unavailable_reason
        strategy.pack_diagnostics.attempted_comparisons=attempted.comparisons
      end
      strategy.warnings=strategy.warnings or {}
      strategy.warnings[#strategy.warnings+1]=tactical_pack and
        'Pack scoring could not complete every legal comparison; this decision uses the strategic ratings.' or
        'Shop scoring comparison reached its limit; this decision uses the strategic ratings.'
    end
    local routing_diagnostics
    if snapshot.phase=='blind' and modules.blind_routing and strategy.action and strategy.action.kind=='select_blind' then
      local route;route,routing_diagnostics=modules.blind_routing.suggest(snapshot,modules,options.blind_routing)
      if route then strategy=route end
    end
    return {kind='strategy', strategy=strategy, action=strategy.action,
      evaluations=(context and context.evaluations or 0)+(routing_diagnostics and routing_diagnostics.evaluations or 0),
      routing_diagnostics=routing_diagnostics,
      gold_diagnostics=gold_diagnostics,
      pack_diagnostics=strategy.pack_diagnostics,
      shop_diagnostics=context and {evaluations=context.evaluations,truncated=context.truncated,
        unavailable_reason=context.unavailable_reason,metrics=context.metrics,sequences=sequence_diagnostics,
        catalog_replacements=context.catalog_replacement_diagnostics,
        reroll_miss=context.reroll_miss_diagnostics} or nil}
  end
  local search_options={strategy=modules.strategy,finish_rewards=modules.finish_rewards,
    draws=modules.draws,sampled_outcomes=modules.sampled_outcomes}
  for k,v in pairs(options.search or {}) do search_options[k]=v end
  local result = modules.search.run(snapshot, modules.scoring, search_options, function()
    if yield_fn then yield_fn() end
  end)
  if not result then return {kind='unsupported', evaluations=0} end
  if result.fast_clear then
    result.fast_clear.development_limit=6
    result.fast_clear.growth_limit=12
    result.fast_clear.post_clear_limit=34
    if modules.consumables and modules.consumables.develop and #(snapshot.consumeables or {})>0 then
      local suggestion,count,diagnostics=modules.consumables.develop(snapshot,modules.scoring,result.play,
        {strategy=modules.strategy,max_development_evaluations=6,arm_cost=modules.search.arm_cost})
      result.consumable,result.consumable_diagnostics=suggestion,diagnostics
      result.evaluations=(result.evaluations or 0)+(count or 0)
    end
    if not result.consumable and modules.growth then
      local suggestion,count,diagnostics=modules.growth.suggest(snapshot,modules,result.play,{max_evaluations=12})
      result.growth,result.growth_diagnostics=suggestion,diagnostics
      result.evaluations=(result.evaluations or 0)+(count or 0)
    end
    result.action=result.consumable and result.consumable.action or result.growth and result.growth.action or
      {kind='play',area='hand',indices=result.play.indices}
    result.fast_clear.specialists_skipped=true
    return result
  end
  -- All specialists share the existing ordinary decision allowance. A lower
  -- local allowance still applies, and each module retains its own complete
  -- candidate/world guard before a result may displace the incumbent.
  local function specialist_options(name,local_limit)
    local bounded={}
    for key,value in pairs(options[name] or {}) do bounded[key]=value end
    local remaining=math.max(0,140000-(result.evaluations or 0))
    local requested=tonumber(bounded.max_evaluations) or local_limit
    bounded.max_evaluations=math.min(local_limit,remaining,math.max(0,math.floor(requested)))
    return bounded
  end
  if #(snapshot.consumeables or {}) > 0 then
    local consumable_options = specialist_options('consumables',25000)
    -- The ordinary consumable entry can take its known-clear development path.
    -- Its separate six-score ceiling must also fit the shared remainder.
    consumable_options.max_development_evaluations=math.min(6,consumable_options.max_evaluations,
      math.max(0,tonumber(consumable_options.max_development_evaluations) or 6))
    consumable_options.arm_cost = modules.search.arm_cost
    consumable_options.strategy = modules.strategy
    local suggestion, evaluations, diagnostics = modules.consumables.suggest(
      snapshot, modules.scoring, result, yield_fn, consumable_options)
    result.consumable, result.consumable_diagnostics = suggestion, diagnostics
    result.evaluations = (result.evaluations or 0) + (evaluations or 0)
  end
  if modules.ordering and #(snapshot.jokers or {}) > 1 then
    local ordering_options = specialist_options('ordering',30000)
    ordering_options.arm_cost = modules.search.arm_cost
    local suggestion, evaluations, diagnostics = modules.ordering.suggest(
      snapshot, modules.scoring, result, yield_fn, ordering_options)
    result.ordering, result.ordering_diagnostics = suggestion, diagnostics
    result.evaluations = (result.evaluations or 0) + (evaluations or 0)
  end
  if modules.hand_ordering then
    local opts=specialist_options('hand_ordering',10000)
    opts.arm_cost=modules.search.arm_cost
    local suggestion,evaluations,diagnostics=modules.hand_ordering.suggest(snapshot,modules.scoring,result,yield_fn,opts)
    result.hand_ordering,result.hand_ordering_diagnostics=suggestion,diagnostics
    result.evaluations=(result.evaluations or 0)+(evaluations or 0)
  end
  if modules.boss_rescue then
    local suggestion,evaluations,diagnostics=modules.boss_rescue.suggest(snapshot,modules.scoring,result,yield_fn,specialist_options('boss_rescue',10000))
    result.boss_rescue,result.boss_rescue_diagnostics=suggestion,diagnostics
    result.evaluations=(result.evaluations or 0)+(evaluations or 0)
  end
  if modules.mixed_rescue then
    local suggestion,evaluations,diagnostics=modules.mixed_rescue.suggest(snapshot,modules,result,yield_fn,specialist_options('mixed_rescue',1500))
    result.mixed_rescue,result.mixed_rescue_diagnostics=suggestion,diagnostics
    result.evaluations=(result.evaluations or 0)+(evaluations or 0)
  end
  local finish_hands=snapshot.hands_left or (snapshot.current_round or {}).hands_left
  if modules.resource_finish and modules.resource_finish.admits(snapshot,modules) then
    -- One mutually exclusive specialist allowance. The broader observed-state
    -- policy fills unsupported size/depth/randomness scopes; it is not stacked
    -- on top of the existing two/three-hand or final-hand redraw search.
    local suggestion,evaluations,diagnostics=modules.resource_finish.suggest(snapshot,modules,result,yield_fn,specialist_options('resource_finish',12000))
    result.two_hand_finish,result.two_hand_finish_diagnostics=suggestion,diagnostics
    result.evaluations=(result.evaluations or 0)+(evaluations or 0)
  elseif modules.two_hand_finish and (finish_hands==2 or finish_hands==3) then
    local suggestion,evaluations,diagnostics=modules.two_hand_finish.suggest(snapshot,modules,result,yield_fn,specialist_options('two_hand_finish',12000))
    result.two_hand_finish,result.two_hand_finish_diagnostics=suggestion,diagnostics
    result.evaluations=(result.evaluations or 0)+(evaluations or 0)
  elseif modules.multi_discard then
    local suggestion,evaluations,diagnostics=modules.multi_discard.suggest(snapshot,modules,result,yield_fn,specialist_options('multi_discard',12000))
    result.multi_discard,result.multi_discard_diagnostics=suggestion,diagnostics
    result.evaluations=(result.evaluations or 0)+(evaluations or 0)
  end
  if result.mixed_rescue then
    result.action=result.mixed_rescue.action
  elseif result.boss_rescue then
    result.action=result.boss_rescue.action
  elseif result.hand_ordering then
    result.action=result.hand_ordering.action
  elseif result.ordering then
    result.action = result.ordering.action
  elseif result.two_hand_finish and result.two_hand_finish.replaces_consumable then
    result.action=result.two_hand_finish.action
  elseif result.consumable then
    result.action = result.consumable.action
  elseif result.multi_discard then
    result.action=result.multi_discard.action
  elseif result.two_hand_finish then
    result.action=result.two_hand_finish.action
  elseif result.kind == 'discard' and result.discard then
    result.action = {kind='discard', area='hand', indices=result.discard.indices}
  elseif result.play then
    result.action = {kind='play', area='hand', indices=result.play.indices}
  end
  return result
end
function D.run(snapshot,modules,yield_fn,options)
  local statistics
  if modules.score_cache and not (options and options.prepared_scoring==false) then
    local scoped={};for k,v in pairs(modules) do scoped[k]=v end
    scoped.scoring,statistics=modules.score_cache.new(modules.scoring,options and options.score_cache)
    modules=scoped
  end
  local result=run(snapshot,modules,yield_fn,options)
  if modules.phase_copy then
    result=modules.phase_copy.apply(snapshot,modules,result,options and options.phase_copy)
  end
  local retry=options and options.retry
  if result and retry and retry.unavailable then
    result.action=nil;if result.strategy then result.strategy.action=nil end
    result.retry={review_only=true,status='unavailable',lines={retry.reason or 'Retry metadata could not be verified.'}}
  elseif result and retry and retry.matched and retry.pending then
    result.action=nil
    if result.strategy then result.strategy.action=nil end
    result.retry={review_only=true,status='pending',reloads_used=retry.reloads_used,
      lines={'A checkpoint line is already recorded. After a loss, restore it manually and use the advisor confirmation to try another line.'}}
  elseif result and retry and retry.active then
    if modules.retry_policy then result=modules.retry_policy.apply(snapshot,result,retry,modules)
    else
      result.action=nil;if result.strategy then result.strategy.action=nil end
      result.retry={review_only=true,status='unsupported',
        lines={'Retry comparison is unavailable in this adapter.'}}
    end
  end
  if result and statistics then result.score_cache=statistics() end
  return result
end
return D
