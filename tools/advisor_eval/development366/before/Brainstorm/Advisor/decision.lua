-- One decision entry point for the in-game advisor and headless evaluation.
-- Dependencies are detached modules, never live game callbacks.
local D = {}
local function discard_growth_available(snapshot)
  local round=snapshot.current_round or {}
  local left=snapshot.discards_left or round.discards_left
  if type(left)~='number' or left<=0 then return false end
  local used=snapshot.discards_used or round.discards_used or 0
  for _,j in ipairs(snapshot.jokers or {}) do
    local a=j.ability or {};local name=a.name or j.name
    if not j.debuff and not a.perma_debuff and
        not (a.perishable and type(a.perish_tally)=='number' and a.perish_tally<=0) and
        (j.key=='j_yorick' or name=='Yorick' or used==0 and (j.key=='j_burnt' or name=='Burnt Joker')) then
      return true
    end
  end
  return false
end
local function hidden_joker(snapshot)
  for _,j in ipairs(snapshot.jokers or {}) do
    if j.face_down or j.identity_redacted or j.concealed or j.unknown or j.facing=='back' then return true end
  end
  return false
end
local function public_joker_decision(snapshot,modules,yield_fn,options)
  options=options or {};local actual=0
  local function unavailable(reason,diagnostics)
    return {kind='unsupported',evaluations=actual,action=nil,public_joker_belief={schema=1,supported=false,complete=false,reason=reason},
      strategy={title='Public Joker-order advice unavailable',lines={reason,
        'No concealed Joker identity or order was read to fill this gap.'},warnings={}},acorn_diagnostics=diagnostics}
  end
  if snapshot.phase~='hand' then return unavailable('Concealed Joker actions outside a settled hand are not qualified.') end
  local belief,ordering=modules.acorn_belief,modules.acorn_ordering
  local public=snapshot.public_joker_belief
  if not belief or type(belief.validate)~='function' or not ordering or type(ordering.suggest)~='function' or
    not modules.scoring or type(modules.scoring.score)~='function' or not belief.validate(public) then
    return unavailable(type(public)=='table' and type(public.reason)=='string' and public.reason or
      'A complete current public Joker belief and its comparison modules are required.')
  end
  local retry=options.retry
  if retry and (retry.unavailable or retry.active or retry.matched and retry.pending) then
    local result=unavailable('Checkpoint retry alternatives with concealed Jokers require manual review.')
    result.retry={review_only=true,status='unsupported',reloads_used=retry.reloads_used,
      lines={retry.reason or 'Existing checkpoint and persistent retry protections remain in force.'}}
    return result
  end
  local requested=options.acorn_belief or {}
  local limit=tonumber(requested.max_evaluations) or tonumber((options.search or {}).max_evaluations) or 140000
  if limit~=limit or math.abs(limit)==math.huge then return unavailable('A finite ordinary score limit is required.') end
  limit=math.max(0,math.min(140000,math.floor(limit)))
  local function charged(method)
    return function(state,indices,...)
      if actual>=limit then return {score=0,uncertain=true,warnings={'The ordinary score allowance is exhausted.'}} end
      actual=actual+1
      return method(state,indices,...)
    end
  end
  local scorer={score=charged(modules.scoring.score)}
  if type(modules.scoring.lower_bound)=='function' then scorer.lower_bound=charged(modules.scoring.lower_bound) end
  local action,reported,diagnostics=ordering.suggest(snapshot,snapshot.public_joker_belief,scorer,belief,
    {max_evaluations=limit,max_order_evaluations=requested.max_order_evaluations or 30000,yield_fn=yield_fn,
      public_incumbent=requested.public_incumbent})
  if reported~=actual then return unavailable('The public comparison score accounting is inconsistent.',diagnostics) end
  if not action then return unavailable(diagnostics and diagnostics.reason or 'The complete public comparison is unavailable.',diagnostics) end
  local b=snapshot.public_joker_belief
  local proof={schema=1,supported=true,complete=true,epoch=b.epoch,revision=b.revision,worlds=#b.worlds,
    bound_kind='public_joker_world_floor',conservative=true,deterministic_exact=false,
    joint_resource_comparison=false,terminal_evidence=false,
    supported_random_floor=diagnostics and diagnostics.supported_random_floor==true,
    scope='Complete finite public identity-world immediate score floor, using supported random-score floors when needed; no future blind-win forecast.'}
  local lines={}
  for _,line in ipairs(action.lines or {}) do lines[#lines+1]=line end
  lines[#lines+1]=tostring(#b.worlds)..' public identity worlds; the displayed score is their conservative local minimum.'
  if proof.supported_random_floor then lines[#lines+1]='Lucky effects use supported score floors, not average or assumed successful triggers.' end
  local result={kind='play',evaluations=actual,action=action.action,public_joker_belief=proof,acorn_diagnostics=diagnostics,
    strategy={title=action.kind=='reorder_jokers' and 'Reorder known public Joker slots' or 'Play from the public Joker belief',lines=lines,warnings={}},
    public_information_fallback=action.public_information_fallback==true,bound_kind=proof.bound_kind,
    deterministic_exact=false,conservative=true}
  if action.kind=='reorder_jokers' then
    result.reorder_only=true;result.ordering=action;action.title=result.strategy.title
    result.action.public_belief={schema=1,epoch=b.epoch,revision=b.revision,worlds=#b.worlds,complete=true,
      complete_order_comparison=diagnostics.order_complete==true,all_world_clear=true,bound_kind=proof.bound_kind}
    result.play={indices=action.projected_play.indices,hand='Public Joker belief',score=action.minimum_score,
      legal=true,uncertain=true,bound_kind=proof.bound_kind,conservative=true,deterministic_exact=false}
  else
    result.play={indices=action.action.indices,hand='Public Joker belief',score=action.minimum_score,
      mean_score=action.mean_score,legal=true,uncertain=true,bound_kind=proof.bound_kind,
      conservative=true,deterministic_exact=false,immediate_clear_all_worlds=action.immediate_clear_all_worlds}
  end
  return result
end
local function run(snapshot, modules, yield_fn, options)
  options = options or {}
  if snapshot.phase=='hand' and modules.concealed_belief then
    local belief_options={progress=yield_fn,draws=modules.draws,
      sampled_outcomes=modules.sampled_outcomes,search=modules.search}
    for k,v in pairs(options.concealed_belief or {}) do belief_options[k]=v end
    if modules.phase_copy and type(modules.phase_copy.concealed_order)=='function' and belief_options.copy_order~=false then
      belief_options.copy_order=function(public,worlds,incumbent,context)
        return modules.phase_copy.concealed_order(public,modules,worlds,incumbent,context)
      end
    end
    local belief=modules.concealed_belief.run(snapshot,modules.scoring,belief_options)
    if belief then return belief end
  end
  if snapshot.phase ~= 'hand' then
    local prehand_work,prehand_diagnostics=0,nil
    if snapshot.phase=='blind' and modules.gold_planet_policy then
      local policy
      policy,prehand_work,prehand_diagnostics=modules.gold_planet_policy.suggest(snapshot,modules,yield_fn,options.gold_planet_policy)
      if policy then return {kind='strategy',strategy=policy,action=policy.action,evaluations=prehand_work,
        gold_planet_diagnostics=prehand_diagnostics} end
    end
    local normal=modules.normal_opening and modules.normal_opening.advice(snapshot)
    if normal then return {kind='strategy',strategy=normal,action=normal.action,evaluations=prehand_work} end
    local jokerless=modules.jokerless_opening and modules.jokerless_opening.advice(snapshot)
    if jokerless then return {kind='strategy',strategy=jokerless,action=jokerless.action,evaluations=prehand_work} end
    if modules.blind_prep then
      local preparation,diagnostics=modules.blind_prep.suggest(snapshot,modules.strategy)
      if preparation then return {kind='strategy',strategy=preparation,action=preparation.action,evaluations=prehand_work,
        preparation_diagnostics=diagnostics} end
    end
    local opening=modules.opening and modules.opening.advice(snapshot)
    if opening then return {kind='strategy',strategy=opening,action=opening.action,evaluations=prehand_work} end
    if snapshot.phase=='shop' and modules.joker_retirement then
      local retired,receipt=modules.joker_retirement.suggest(snapshot,modules.strategy)
      if retired then return {kind='strategy',strategy=retired,action=retired.action,evaluations=prehand_work,
        retirement_diagnostics=receipt} end
    end
    local acquisition_diagnostics
    local shop_options=options.shop_scoring
    local requested=shop_options and shop_options.max_evaluations
    local shop_limit=type(requested)=='number' and requested==requested and math.abs(requested)<math.huge and
      math.max(0,math.min(50000,math.floor(requested))) or requested==nil and 50000 or 0
    if snapshot.phase=='shop' and snapshot.completionist_goal and modules.gold_acquisition then
      -- Give the declared collection family first use of the existing shop
      -- allowance. Any unsuccessful work is still charged to ordinary advice.
      local limit=shop_limit
      local actual,exhausted=0,false
      local scoped={};for k,v in pairs(modules) do scoped[k]=v end
      scoped.scoring=setmetatable({}, {__index=modules.scoring})
      if modules.scoring and modules.scoring.lower_bound then
        scoped.scoring.lower_bound=function(...)
          if actual>=limit then exhausted=true;return nil end
          actual=actual+1;return modules.scoring.lower_bound(...)
        end
      end
      local goal,reported
      goal,reported,acquisition_diagnostics=modules.gold_acquisition.suggest(snapshot,scoped,yield_fn,{max_evaluations=limit})
      prehand_work=prehand_work+actual
      if exhausted or reported~=actual then
        goal=nil
        acquisition_diagnostics={complete=false,evaluations=actual,
          reason='The collection comparison did not preserve the shared score accounting.'}
      end
      if goal and acquisition_diagnostics and acquisition_diagnostics.complete then
        return {kind='strategy',strategy=goal,action=goal.action,evaluations=prehand_work,
          gold_acquisition_diagnostics=acquisition_diagnostics}
      end
      shop_options={};for k,v in pairs(options.shop_scoring or {}) do shop_options[k]=v end
      shop_options.max_evaluations=limit-actual
    end
    local retention_reserve=0
    if snapshot.phase=='shop' then
      local remaining=math.max(0,shop_limit-prehand_work)
      if modules.gold_retention and modules.gold_retention.reserve then
        retention_reserve=modules.gold_retention.reserve(snapshot,remaining)
      end
      local scoped={};for k,v in pairs(shop_options or {}) do scoped[k]=v end
      scoped.max_evaluations=remaining-retention_reserve;shop_options=scoped
    end
    local tactical_pack=false
    if snapshot.phase=='pack' then
      for _,card in ipairs(snapshot.pack_cards or {}) do
        if (card.ability or {}).set=='Joker' or (card.key or ''):sub(1,2)=='j_' or
          modules.pack_scoring and modules.pack_scoring.supports(card) then tactical_pack=true end
      end
    end
    local context=(snapshot.phase=='shop' or tactical_pack) and modules.shop_scoring and
      modules.shop_scoring.new(snapshot,modules.scoring,yield_fn,shop_options)
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
    local retention_work,retention_diagnostics=0,nil
    if snapshot.phase=='shop' and modules.gold_retention then
      local remaining=math.max(0,shop_limit-prehand_work-(context and context.evaluations or 0))
      local exhausted=false
      local scoped={};for k,v in pairs(modules) do scoped[k]=v end
      scoped.scoring=setmetatable({}, {__index=modules.scoring})
      if modules.scoring and modules.scoring.lower_bound then
        scoped.scoring.lower_bound=function(...)
          if retention_work>=remaining then exhausted=true;return nil end
          retention_work=retention_work+1;return modules.scoring.lower_bound(...)
        end
      end
      local retained,reported
      retained,reported,retention_diagnostics=modules.gold_retention.suggest(snapshot,scoped,strategy,remaining,yield_fn)
      if exhausted or reported~=retention_work then
        retained=nil
        retention_diagnostics={complete=false,evaluations=retention_work,
          reason='The retention comparison did not preserve the shared score accounting.'}
      end
      if retention_diagnostics then retention_diagnostics.reserved_evaluations=retention_reserve end
      if retained and retention_diagnostics and retention_diagnostics.complete then strategy=retained end
    end
    local routing_diagnostics
    if snapshot.phase=='blind' and snapshot.teacher_profile~='perkeo_yorick_win_v1' and
      modules.blind_routing and strategy.action and strategy.action.kind=='select_blind' then
      local routing_options={yield_fn=yield_fn}
      for key,value in pairs(options.blind_routing or {}) do routing_options[key]=value end
      local route;route,routing_diagnostics=modules.blind_routing.suggest(snapshot,modules,routing_options)
      if route then strategy=route end
    end
    if context and context.replacement_diagnostics then
      local d,a=context.replacement_diagnostics,strategy.action or {}
      d.final_action_kind=a.kind;d.final_action_area=a.area;d.final_action_index=a.index
    end
    return {kind='strategy', strategy=strategy, action=strategy.action,
      evaluations=prehand_work+retention_work+(context and context.evaluations or 0)+(routing_diagnostics and routing_diagnostics.evaluations or 0),
      gold_planet_diagnostics=prehand_diagnostics,
      routing_diagnostics=routing_diagnostics,
      gold_diagnostics=gold_diagnostics,
      gold_acquisition_diagnostics=acquisition_diagnostics,
      gold_retention_diagnostics=retention_diagnostics,
      pack_diagnostics=strategy.pack_diagnostics,
      shop_diagnostics=context and {evaluations=context.evaluations,truncated=context.truncated,
        unavailable_reason=context.unavailable_reason,metrics=context.metrics,sequences=sequence_diagnostics,
        replacements=context.replacement_diagnostics,
        catalog_replacements=context.catalog_replacement_diagnostics,
        reroll_miss=context.reroll_miss_diagnostics} or nil}
  end
  local search_options={strategy=modules.strategy,finish_rewards=modules.finish_rewards,
    draws=modules.draws,sampled_outcomes=modules.sampled_outcomes}
  for k,v in pairs(options.search or {}) do search_options[k]=v end
  local consumable_reserve=0
  if modules.consumables and modules.consumables.comparison_reserve then
    local reserve,play_cost=modules.consumables.comparison_reserve(snapshot,options.consumables)
    local requested=math.max(0,math.min(140000,math.floor(search_options.max_evaluations or 140000)))
    -- Keep the complete current-play pass plus score-floor probes, and never
    -- reduce the seventy-score fast-clear contract or a smaller caller cap.
    local ceiling=math.max(70,(play_cost or 0)+4,140000-reserve)
    search_options.max_evaluations=math.min(requested,ceiling)
    consumable_reserve=requested-search_options.max_evaluations
  end
  if modules.hand_copy_preflight and options.hand_copy_preflight~=false then
    local plan=modules.hand_copy_preflight.prepare(snapshot,modules,options.retry)
    if plan then search_options.copy_preflight={compare=function(scorer,family,context)
      return modules.hand_copy_preflight.compare(plan,scorer,family,context)
    end} end
  end
  local result = modules.search.run(snapshot, modules.scoring, search_options, function()
    if yield_fn then yield_fn() end
  end)
  if not result then return {kind='unsupported', evaluations=0} end
  result.consumable_reserved_evaluations=consumable_reserve
  if result.reorder_only and result.copy_preflight and result.copy_preflight.complete then return result end
  local clear_shortcut=result.fast_clear or result.clear_shortcut
  if clear_shortcut then
    local ceiling=result.fast_clear and 70 or 140000
    local function available(limit)
      return math.min(limit,math.max(0,ceiling-(result.evaluations or 0)))
    end
    clear_shortcut.development_limit=6
    clear_shortcut.growth_limit=12
    clear_shortcut.post_clear_limit=34
    clear_shortcut.aggregate_limit=ceiling
    local growth_checked,growth=false,nil
    local function consider_growth()
      if growth_checked or not modules.growth then return end
      growth_checked=true
      local suggestion,count,diagnostics=modules.growth.suggest(snapshot,modules,result.play,{max_evaluations=available(12)})
      growth=suggestion;result.growth_diagnostics=diagnostics
      result.evaluations=(result.evaluations or 0)+(count or 0)
    end
    -- A useful, independently verified discard spends a resource that expires
    -- when this blind clears. Stored development can wait for the next draw.
    -- Do not let a repeatable Empress use prevent this comparison altogether.
    -- Every survival/resource guard remains in growth.suggest; this gate only
    -- changes the order of optional comparisons and never forces a discard.
    if discard_growth_available(snapshot) then consider_growth() end
    local discard_growth=growth and growth.action and growth.action.kind=='discard'
    if discard_growth then clear_shortcut.development_deferred_for_discard=true end
    if not discard_growth and modules.consumables and modules.consumables.develop and #(snapshot.consumeables or {})>0 then
      local suggestion,count,diagnostics=modules.consumables.develop(snapshot,modules.scoring,result.play,
        {strategy=modules.strategy,max_development_evaluations=available(6),arm_cost=modules.search.arm_cost})
      result.consumable,result.consumable_diagnostics=suggestion,diagnostics
      result.evaluations=(result.evaluations or 0)+(count or 0)
    end
    if not result.consumable then
      consider_growth()
      result.growth=growth
    end
    result.action=result.consumable and result.consumable.action or result.growth and result.growth.action or
      {kind='play',area='hand',indices=result.play.indices}
    clear_shortcut.specialists_skipped=true
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
  -- This precedes scoring-cache preparation, concealed playing-card inference,
  -- ordinary search, all specialists, phase copying and retry policy callbacks.
  -- None may inspect the raw concealed Joker row as an implicit fallback.
  if hidden_joker(snapshot) then return public_joker_decision(snapshot,modules,yield_fn,options) end
  local statistics
  if modules.score_cache and not (options and options.prepared_scoring==false) then
    local scoped={};for k,v in pairs(modules) do scoped[k]=v end
    scoped.scoring,statistics=modules.score_cache.new(modules.scoring,options and options.score_cache)
    modules=scoped
  end
  local result=run(snapshot,modules,yield_fn,options)
  -- Retention proves an actual reorder or fixed-row exit, including Perkeo copies.
  -- A new copy arrangement would invalidate that comparison and can expose
  -- the retained target to ordinary resale on the following decision.
  local fixed_retention=result and result.action and
    (result.action.kind=='leave_shop' or result.action.kind=='reorder_jokers') and
    result.strategy and result.strategy.gold_retention and result.gold_retention_diagnostics and
    result.gold_retention_diagnostics.complete
  if modules.phase_copy and not (result and result.reorder_only) and not fixed_retention then
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
