-- One decision entry point for the in-game advisor and headless evaluation.
-- Dependencies are detached modules, never live game callbacks.
local D = {}
-- Mouth rejects scoring categories, not the engine's play button. When no
-- scoring/resource action remains, spend a hand to let the game advance.
-- A nonempty deck can expose fresh cards; an empty deck or final hand cannot
-- promise a continuation, but still needs an executable terminal progression.
function D.mouth_cycle(s,scorer,result,cap)
  local b=s.blind or {};local round=s.current_round or {}
  if s.phase~='hand' or b.disabled or not (b.key=='bl_mouth' or b.name=='The Mouth') or
    type(b.only_hand)~='string' or (s.hands_left or round.hands_left or 0)<=0 or
    (s.discards_left or round.discards_left or 0)~=0 or #(s.hand or {})==0 or
    result.action or result.play or not scorer or not scorer.score or (result.evaluations or 0)+2>cap then return end
  for _,c in ipairs(s.hand or {}) do if c.face_down or c.identity_redacted or c.unknown or
    type(c.rank)~='number' or c.rank<2 or c.rank>14 or c.rank%1~=0 then return end end
  for _,j in ipairs(s.jokers or {}) do if j.face_down or j.identity_redacted or j.unknown then return end end
  local ranks={};for _,c in ipairs(s.hand) do ranks[c.rank]=(ranks[c.rank] or 0)+1 end
  local indices,spare={},{}
  for i,c in ipairs(s.hand) do
    if (c.ability or {}).forced_selection then indices[#indices+1]=i
    elseif ranks[c.rank]==1 and c.enhancement~='m_gold' and c.enhancement~='m_steel' and c.seal~='Blue' then spare[#spare+1]=i end
  end
  table.sort(spare,function(i,j) return s.hand[i].rank<s.hand[j].rank end)
  for _,i in ipairs(spare) do if #indices<5 then indices[#indices+1]=i end end
  if #indices==0 then indices={#s.hand} end
  if #indices>5 then return end
  table.sort(indices)
  local actual=scorer.score(s,indices);result.evaluations=(result.evaluations or 0)+1
  if not actual or actual.legal~=false or actual.reason~='The Mouth requires '..b.only_hand..'.' then return end
  local probe={};for k,v in pairs(s) do probe[k]=v end
  probe.blind={};for k,v in pairs(b) do probe.blind[k]=v end;probe.blind.only_hand=nil
  local supported=scorer.score(probe,indices);result.evaluations=result.evaluations+1
  if not supported or supported.legal==false or #(supported.warnings or {})>0 then return end
  local action={kind='play',area='hand',indices=indices}
  result.kind='strategy';result.action=action
  local draw_available=#(s.deck or {})>0
  local title=draw_available and 'Cycle a non-scoring hand under The Mouth' or
    'Advance the blocked Mouth hand'
  local lines={
    'This hand scores zero under the locked category. Spend a hand to let the game advance.',
    draw_available and 'Fresh cards may be drawn; their identities and a successful continuation are unknown.' or
      'The deck is empty, so this play cannot draw cards. The game will determine whether the run ends.'}
  result.title=title;result.lines=lines
  result.strategy={action=action,title=title,warnings={},lines=lines}
  result.mouth_cycle={score=0,future_draw_known=false,draw_available=draw_available}
end
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
local function exhaust_discards(snapshot)
  local left=snapshot.discards_left or (snapshot.current_round or {}).discards_left
  return snapshot.teacher_profile=='perkeo_yorick_win_v1' and type(left)=='number' and left>0 and left<math.huge
end
local function stamp_yorick_choice(result)
  local risk=result and result.risky_yorick_clear
  if not risk then return end
  if risk.search_selected==nil then
    risk.search_selected=risk.selected==true
    risk.proposal_indices={}
    for i,index in ipairs(result.discard and result.discard.indices or {}) do risk.proposal_indices[i]=index end
  end
  local actual=result.action or {};local proposed=risk.proposal_indices or {}
  local same=actual.kind=='discard' and #proposed>0 and #(actual.indices or {})==#proposed
  if same then for i,index in ipairs(proposed) do
    if actual.indices[i]~=index then same=false;break end
  end end
  risk.final_action_kind=actual.kind
  risk.final_action_matches_search=not not same
  risk.selected=risk.search_selected and same or false
end
local function early_yorick_comparison_available(snapshot,modules)
  if snapshot.teacher_profile~='perkeo_yorick_win_v1' or
    type(snapshot.ante)~='number' or snapshot.ante>8 or
    #(snapshot.hand or {})>12 or #(snapshot.deck or {})==0 or
    not modules.scoring or not modules.scoring.after_discard or
    not discard_growth_available(snapshot) then return false end
  for _,j in ipairs(snapshot.jokers or {}) do
    local a=j.ability or {}
    if not j.debuff and not a.perma_debuff and
      not (a.perishable and type(a.perish_tally)=='number' and a.perish_tally<=1) and
      (j.key=='j_yorick' or a.name=='Yorick' or j.name=='Yorick') and
      type(a.x_mult)=='number' and a.x_mult>=1 and a.x_mult<=8 then return true end
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
  local retained_work=0
  if exhaust_discards(snapshot) and action.kind=='play' and modules.acorn_discard and modules.acorn_discard.retained then
    local before=actual;local kept,receipt
    kept,retained_work,receipt=modules.acorn_discard.retained(snapshot,public,action,scorer,modules.scoring,belief,modules,
      {max_evaluations=math.min(12,limit-actual)})
    diagnostics.retained=receipt
    if retained_work~=actual-before then return unavailable('The retained public score accounting is inconsistent.',receipt) end
    if kept then
      kept.title='Discard '..#kept.action.indices..' cards before clearing'
      return {kind='discard',action=kept.action,growth=kept,strategy=kept,evaluations=actual,
      discard_preference_work=retained_work,acorn_diagnostics=diagnostics,
      public_joker_belief={schema=1,supported=true,complete=true,worlds=#public.worlds,
        bound_kind='public_retained_clear_floor',scope=receipt.scope}} end
  end
  local discard,discard_diag
  if action.kind=='play' and snapshot.hands_left>=1 and snapshot.discards_left>0 and
    modules.acorn_discard and type(modules.acorn_discard.suggest)=='function' then
    local before=actual;local requested_discard=options.acorn_discard or {}
    local local_limit=tonumber(requested_discard.max_evaluations)
    if local_limit and (local_limit~=local_limit or math.abs(local_limit)==math.huge) then
      return unavailable('A finite public redraw score limit is required.',diagnostics)
    end
    discard,reported,discard_diag=modules.acorn_discard.suggest(snapshot,public,action,diagnostics,scorer,
      modules.scoring,belief,modules.draws,
      modules.concealed_belief and modules.concealed_belief.public_candidates,
      {max_evaluations=math.min(limit-actual,local_limit or limit-actual),yield_fn=yield_fn})
    if reported~=actual-before then return unavailable('The public redraw score accounting is inconsistent.',discard_diag) end
    diagnostics.discard=discard_diag
  end
  local b=snapshot.public_joker_belief
  local proof={schema=1,supported=true,complete=true,epoch=b.epoch,revision=b.revision,worlds=#b.worlds,
    bound_kind='public_joker_world_floor',conservative=true,deterministic_exact=false,
    joint_resource_comparison=false,terminal_evidence=false,
    supported_random_floor=diagnostics and diagnostics.supported_random_floor==true,
    scope='Complete finite public identity-world immediate score floor, using supported random-score floors when needed; no future blind-win forecast.'}
  local lines={}
  for _,line in ipairs(action.lines or {}) do lines[#lines+1]=line end
  lines[#lines+1]=tostring(#b.worlds)..' public identity worlds; the displayed score is their conservative local minimum.'
  if proof.supported_random_floor then lines[#lines+1]='Random card and Joker effects use supported score floors, not average or assumed successful triggers.' end
  if discard then
    proof.bound_kind='sampled_public_joker_redraw'
    proof.scope='Complete retained public Joker worlds and a declared first-discard/next-play family on common sampled draws; no full-run forecast.'
    local discard_lines={}
    for _,line in ipairs(discard.lines or {}) do discard_lines[#discard_lines+1]=line end
    discard_lines[#discard_lines+1]=tostring(#b.worlds)..' public Joker orders remained in every redraw comparison.'
    return {kind='discard',evaluations=actual,action=discard.action,public_joker_belief=proof,
      acorn_diagnostics=diagnostics,acorn_discard_diagnostics=discard_diag,
      strategy={title='Discard from the public Joker belief',lines=discard_lines,warnings={}},
      sampled_clear_fraction=discard.sampled_clear_fraction,
      baseline_clear_fraction=discard.baseline_clear_fraction,
      bound_kind=proof.bound_kind,deterministic_exact=false,conservative=true}
  end
  local result={kind='play',evaluations=actual,action=action.action,public_joker_belief=proof,acorn_diagnostics=diagnostics,
    discard_preference_work=retained_work,
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
    local public_work,public_receipt=0,nil
    if exhaust_discards(snapshot) and modules.growth and modules.growth.visible_retained and
        modules.concealed_belief.has_hidden and modules.concealed_belief.has_hidden(snapshot) then
      local cap=math.min(8000,belief_options.max_evaluations or 8000,
        (options.search or {}).max_evaluations or 140000)
      local kept;kept,public_work,public_receipt=modules.growth.visible_retained(snapshot,modules,math.min(12,cap))
      if kept then
        kept.title='Discard '..#kept.action.indices..' cards before clearing'
        return {kind='discard',action=kept.action,growth=kept,strategy=kept,evaluations=public_work,
        discard_preference_work=public_work,concealed_belief={supported=true,complete=true,
          scope='visible_retained_floor',evaluations=public_work,retained=public_receipt}} end
      belief_options.max_evaluations=math.max(0,cap-public_work)
    end
    if modules.phase_copy and type(modules.phase_copy.concealed_order)=='function' and belief_options.copy_order~=false then
      belief_options.copy_order=function(public,worlds,incumbent,context)
        return modules.phase_copy.concealed_order(public,modules,worlds,incumbent,context)
      end
    end
    local belief=modules.concealed_belief.run(snapshot,modules.scoring,belief_options)
    if belief then
      if public_receipt then
        belief.evaluations=(belief.evaluations or 0)+public_work
        belief.discard_preference_work=public_work
        if belief.concealed_belief then belief.concealed_belief.retained=public_receipt end
      end
      return belief
    end
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
    if snapshot.phase=='shop' and modules.joker_retirement and
        not (snapshot.shop_sequence_commitment and snapshot.shop_sequence_commitment.status=='matched') then
      local retired,receipt=modules.joker_retirement.suggest(snapshot,modules.strategy)
      if retired then return {kind='strategy',strategy=retired,action=retired.action,evaluations=prehand_work,
        retirement_diagnostics=receipt} end
    end
    local acquisition_diagnostics
    local shop_options=options.shop_scoring
    local requested=shop_options and shop_options.max_evaluations
    local shop_limit=type(requested)=='number' and requested==requested and math.abs(requested)<math.huge and
      math.max(0,math.min(50000,math.floor(requested))) or requested==nil and 50000 or 0
    local continuation_diagnostics
    if snapshot.phase=='shop' and snapshot.shop_sequence_commitment and modules.shop_sequences and
      modules.shop_sequences.resume and modules.shop_scoring then
      local lease={};for k,v in pairs(shop_options or {}) do lease[k]=v end
      lease.max_evaluations=math.max(0,shop_limit-prehand_work)
      local ctx=modules.shop_scoring.new(snapshot,modules.scoring,yield_fn,lease)
      local resumed;resumed,continuation_diagnostics=modules.shop_sequences.resume(snapshot,modules,ctx)
      prehand_work=prehand_work+ctx.evaluations
      if resumed then return {kind='strategy',strategy=resumed,action=resumed.action,evaluations=prehand_work,
        shop_diagnostics={evaluations=ctx.evaluations,truncated=ctx.truncated,continuation=continuation_diagnostics}} end
      if snapshot.shop_sequence_commitment.status=='matched' then
        return {kind='unsupported',action=nil,evaluations=prehand_work,
          strategy={title='Funded continuation needs review',warnings={},lines={
            'The shop still matches the executed sale, but its remaining plan could not be fully revalidated.',
            tostring(continuation_diagnostics and continuation_diagnostics.status)}},
          shop_diagnostics={evaluations=ctx.evaluations,truncated=ctx.truncated,continuation=continuation_diagnostics}}
      end
      shop_options={};for k,v in pairs(options.shop_scoring or {}) do shop_options[k]=v end
      shop_options.max_evaluations=math.max(0,shop_limit-prehand_work)
    end
    local copy_diagnostics
    if snapshot.phase=='shop' and snapshot.teacher_profile=='perkeo_yorick_win_v1' and
        modules.strategy.copy_acquisition and modules.shop_scoring then
      local visible=false
      for _,c in ipairs(snapshot.shop_jokers or {}) do
        if c.key=='j_blueprint' or c.key=='j_brainstorm' then visible=true end
      end
      if visible then
        local focused_options={};for k,v in pairs(shop_options or {}) do focused_options[k]=v end
        focused_options.max_evaluations=math.max(0,shop_limit-prehand_work)
        -- Current and generic sorted rows occupy the first two slots. Leave
        -- room for explicit copy-target layouts in the declared shortlist.
        focused_options.max_orders=4
        local focused=modules.shop_scoring.new(snapshot,modules.scoring,yield_fn,focused_options)
        local choice,receipt=modules.strategy.copy_acquisition(snapshot,focused)
        if choice and (choice.copy_endpoint_certificate or choice.copy_reserve_funding) then
          -- Do not sell away the uncertain incumbent unless the resulting
          -- physical vacancy can complete its exact funded purchase on fresh
          -- advice. Qualify within this SAME context/allowance before any sale.
          local action=choice.action
          local follow=action and action.followup
          if not modules.shop_sequences or not modules.shop_sequences.qualify_sale or not follow then choice=nil
          else
            choice.shop_sequence={complete=true,actions={
              {kind=action.kind,area=action.area,index=action.index},
              {kind=follow.kind,area=follow.area,index=follow.index}},
              titles={choice.title,'Buy the funded copy Joker'}}
            local qualified,why=modules.shop_sequences.qualify_sale(snapshot,choice,modules,focused)
            focused.copy_endpoint_continuation={complete=not not qualified,reason=why}
            if not qualified then choice=nil end
          end
        end
        prehand_work=prehand_work+focused.evaluations
        copy_diagnostics={schema=1,evaluations=focused.evaluations,truncated=focused.truncated,
          attempted=receipt~=nil or focused.copy_direct_diagnostics~=nil,
          complete=not focused.truncated and (not receipt or receipt.complete) and
            focused.copy_direct_diagnostics~=nil and focused.copy_direct_diagnostics.complete,
          replacements=receipt,direct=focused.copy_direct_diagnostics,
          reason=choice and (choice.copy_endpoint_certificate and 'supported_copy_endpoint' or 'supported_copy_priority') or
            focused.unavailable_reason or 'no_supported_copy_priority'}
        if choice then return {kind='strategy',strategy=choice,action=choice.action,evaluations=prehand_work,
          copy_acquisition_diagnostics=copy_diagnostics,shop_diagnostics={evaluations=focused.evaluations,
            truncated=focused.truncated,replacements=receipt}} end
        shop_options={};for k,v in pairs(options.shop_scoring or {}) do shop_options[k]=v end
        shop_options.max_evaluations=math.max(0,shop_limit-prehand_work)
      end
    end
    if snapshot.phase=='shop' and snapshot.completionist_goal and modules.gold_acquisition then
      -- Give the declared collection family first use of the existing shop
      -- allowance. Any unsuccessful work is still charged to ordinary advice.
      local limit=math.max(0,shop_limit-prehand_work)
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
    local fallback_survival,source_exploration,source_review
    if snapshot.phase=='shop' and snapshot.teacher_profile=='perkeo_yorick_win_v1' and
        modules.shop_scoring and modules.strategy.shortfall_fallback_evidence then
      local probe_options={};for k,v in pairs(shop_options or {}) do probe_options[k]=v end
      probe_options.max_evaluations=math.min(12000,math.max(0,shop_limit-prehand_work))
      local probe=modules.shop_scoring.new(snapshot,modules.scoring,yield_fn,probe_options)
      if modules.strategy.copy_source_exploration then
        source_exploration=modules.strategy.copy_source_exploration(snapshot,probe)
        source_review=probe.copy_source_diagnostics
      end
      fallback_survival=modules.strategy.shortfall_fallback_evidence(snapshot,probe)
      prehand_work=prehand_work+probe.evaluations
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
        strategy=modules.shop_sequences.with_continuation(strategy,sequence_diagnostics,snapshot,modules)
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
      if snapshot.phase=='shop' then
        -- Scored shop candidates were abandoned as a whole. Clear their
        -- receipts, then independently recheck only the bounded, unscored
        -- surplus opportunity against the complete strategic fallback.
        context.reroll_development_diagnostics=nil
        context.reroll_surplus_diagnostics=nil
        context.reroll_miss_diagnostics=nil
        local rescue=modules.strategy.shortfall_fallback and
          modules.strategy.shortfall_fallback(snapshot,strategy,context,fallback_survival)
        if rescue then strategy=rescue
        elseif modules.strategy.surplus_reroll then
          strategy=modules.strategy.surplus_reroll(snapshot,strategy,context) or strategy
        end
      end
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
    -- This proposal has its own complete early paid-miss proof. It survives
    -- an unrelated optional-family budget fallback, but never displaces a
    -- visible purchase, pack, stock cleanup, commitment or copy arrangement.
    if source_exploration and strategy.action and strategy.action.kind=='leave_shop' then strategy=source_exploration end
    if snapshot.phase=='shop' and modules.strategy.late_cash_spend then
      strategy=modules.strategy.late_cash_spend(snapshot,strategy,source_review) or strategy
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
      copy_acquisition_diagnostics=copy_diagnostics,
      gold_retention_diagnostics=retention_diagnostics,
      pack_diagnostics=strategy.pack_diagnostics,
      shop_diagnostics=context and {evaluations=context.evaluations,truncated=context.truncated,continuation=continuation_diagnostics,
        copy_source=source_review,
        unavailable_reason=context.unavailable_reason,metrics=context.metrics,sequences=sequence_diagnostics,
        replacements=context.replacement_diagnostics,
        catalog_replacements=context.catalog_replacement_diagnostics,
        reroll_development=context.reroll_development_diagnostics,
        reroll_surplus=context.reroll_surplus_diagnostics,
        reroll_miss=context.reroll_miss_diagnostics} or nil}
  end
  local search_options={strategy=modules.strategy,finish_rewards=modules.finish_rewards,
    draws=modules.draws,sampled_outcomes=modules.sampled_outcomes}
  for k,v in pairs(options.search or {}) do search_options[k]=v end
  if search_options.fast_clear~=true and early_yorick_comparison_available(snapshot,modules) then
    -- A win-first Yorick may trade a current clear for a bounded,
    -- matched-world redraw. This is an ordinary search, not a 70-score fast
    -- clear; the latter remains unchanged for every other state.
    search_options.fast_clear=false
    search_options.win_first_yorick_clear_discard=true
  end
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
  -- Search has already compared this growth discard and applied its remaining-
  -- blind continuation veto. Optional development must not replace that actual
  -- incumbent merely because result.play also contains a clearing alternative.
  local risk=result.risky_yorick_clear
  local preserve_search_discard=exhaust_discards(snapshot) and result.kind=='discard' and
    result.discard and #(result.discard.indices or {})>0 and risk and risk.selected==true and
    risk.compared==true and risk.exact_transition==true and (risk.samples or 0)>=24
  if preserve_search_discard and result.action then
    local actual=result.action;local proposed=result.discard.indices
    preserve_search_discard=actual.kind=='discard' and #(actual.indices or {})==#proposed
    if preserve_search_discard then for i,index in ipairs(proposed) do
      if actual.indices[i]~=index then preserve_search_discard=false;break end
    end end
  end
  local clear_shortcut=result.fast_clear or result.clear_shortcut
  local held_death=false
  if snapshot.teacher_profile=='perkeo_yorick_win_v1' then
    for _,c in ipairs(snapshot.consumeables or {}) do if c.key=='c_death' and not c.debuff then held_death=true end end
  end
  if not clear_shortcut and not preserve_search_discard and held_death and result.play and result.play.legal~=false and
      result.play.uncertain~=true and type(result.play.score)=='number' and
      result.play.score>=math.max(1,(snapshot.blind or {}).chips-(snapshot.chips or 0))*1.05 then
    clear_shortcut={search_path='death_retained_clear'};result.clear_shortcut=clear_shortcut
  end
  -- Every teacher clear with expiring discards gets the retained comparison
  -- before optional Tarot development, including mature/mixed Joker rows.
  -- A search-selected discard still wins; no unsupported redraw is forced.
  local current_clear_action=true
  if result.action then
    local selected=result.action.indices or {};local scored=result.play and result.play.indices or {}
    current_clear_action=result.action.kind=='play' and #selected==#scored
    for i,index in ipairs(selected) do if scored[i]~=index then current_clear_action=false end end
  end
  if not clear_shortcut and current_clear_action and exhaust_discards(snapshot) and
    result.kind=='play' and result.play and result.play.legal~=false and
    result.play.uncertain~=true and type(result.play.score)=='number' and
    result.play.score>=math.max(1,(snapshot.blind or {}).chips-(snapshot.chips or 0)) then
    clear_shortcut={search_path='discard_before_development'}
    result.clear_shortcut=clear_shortcut
  end
  if clear_shortcut and not preserve_search_discard then
    local ceiling=math.min(result.fast_clear and 70 or 140000,
      math.max(0,math.floor(search_options.max_evaluations or 140000)))
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
      local growth_clear=result.play
      local preference={exhaust_discards=exhaust_discards(snapshot),max_evaluations=available(12)}
      local suggestion,count,diagnostics
      if modules.growth.suggest_portfolio then
        suggestion,count,diagnostics,growth_clear,result.growth_anchor_diagnostics=
          modules.growth.suggest_portfolio(snapshot,modules,result.play,result.alternatives,preference)
      else
      if modules.growth.select_clear then
        growth_clear,result.growth_anchor_diagnostics=modules.growth.select_clear(snapshot,result.play,result.alternatives,preference)
      end
      suggestion,count,diagnostics=modules.growth.suggest(snapshot,modules,growth_clear,preference)
      end
      growth=suggestion;result.growth_diagnostics=diagnostics
      result.discard_preference_work=preference.exhaust_discards and (count or 0) or nil
      result.discard_preference_anchor=preference.exhaust_discards and growth_clear or nil
      result.evaluations=(result.evaluations or 0)+(count or 0)
    end
    -- A useful, independently verified discard spends a resource that expires
    -- when this blind clears. Stored development can wait for the next draw.
    -- Do not let a repeatable Empress use prevent this comparison altogether.
    -- Every survival/resource guard remains in growth.suggest; this gate only
    -- changes the order of optional comparisons and never forces a discard.
    if exhaust_discards(snapshot) or discard_growth_available(snapshot) or held_death then consider_growth() end
    local discard_growth=growth and growth.action and growth.action.kind=='discard'
    if discard_growth then clear_shortcut.development_deferred_for_discard=true end
    local discard_count=discard_growth and #growth.action.indices or 0
    local death_preparation=held_death and exhaust_discards(snapshot) and discard_count<5 and
      math.max(0,12-(result.discard_preference_work or 0))>0
    if (not discard_growth or death_preparation) and modules.consumables and modules.consumables.develop and #(snapshot.consumeables or {})>0 then
      local suggestion,count,diagnostics=modules.consumables.develop(snapshot,modules.scoring,result.play,
        {strategy=modules.strategy,max_development_evaluations=available(6),arm_cost=modules.search.arm_cost,
         discard_preparation=death_preparation and {modules=modules,min_count=discard_count,
           max_evaluations=math.max(0,12-(result.discard_preference_work or 0))} or nil})
      if diagnostics and (diagnostics.discard_preparation_evaluations or 0)>0 then
        result.discard_preference_work=(result.discard_preference_work or 0)+diagnostics.discard_preparation_evaluations
      end
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
    stamp_yorick_choice(result)
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
    if preserve_search_discard and suggestion and suggestion.development then
      risk.development_deferred_for_discard=true
      suggestion=nil
    end
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
  if modules.consumables and modules.consumables.fool_jupiter_stock and result.action and result.action.kind=='play' and
      not (result.mixed_rescue or result.boss_rescue or result.hand_ordering or result.ordering or
        result.two_hand_finish or result.multi_discard or result.consumable) then
    local stock=modules.consumables.fool_jupiter_stock(snapshot,modules.strategy,result)
    if stock then
      result.consumable=stock
      result.fool_jupiter_stock=stock.fool_jupiter_stock
      result.action=stock.action
    end
  end
  stamp_yorick_choice(result)
  D.mouth_cycle(snapshot,modules.scoring,result,math.min(140000,options and options.search and options.search.max_evaluations or 140000))
  return result
end
-- Final actions, rather than projected specialist/search plays, govern this
-- preference. Coverage gaps remain visible exceptions, never invented proofs.
local function discard_preference(s,modules,result,options)
  if not result or s.phase~='hand' or not exhaust_discards(s) or not result.action then return result end
  local action=result.action
  if action.kind~='play' and action.kind~='discard' then return result end
  local receipt={schema=1,remaining_discards=s.discards_left or (s.current_round or {}).discards_left,
    final_action_kind=action.kind,status='not_finishing',selected=false,evaluations=0}
  result.discard_before_clear=receipt
  local function exception(reason,category)
    receipt.status='exception';receipt.reason=reason;receipt.category=category or 'public_model_gap'
    return result
  end
  if action.kind=='discard' then
    receipt.status='discard_selected';receipt.selected=true
    receipt.reason=result.growth and 'supported_retained_clear' or 'existing_discard_plan'
    receipt.evaluations=result.discard_preference_work or 0
    return result
  end
  local retry=options and options.retry
  if retry and (retry.active or retry.unavailable or retry.matched and retry.pending) then
    return exception('Checkpoint retry protections retain the recorded action.','retry_constraint')
  end
  if result.public_joker_belief or result.concealed_belief then
    receipt.evaluations=result.discard_preference_work or 0
    local retained=(result.acorn_diagnostics or {}).retained or (result.concealed_belief or {}).retained
    return exception(retained and retained.reason or 'A complete retained-clear discard proof over the public identity worlds is unavailable.')
  end
  local function same(a,b)
    if type(a)~='table' or type(b)~='table' or #a~=#b then return false end
    for i,v in ipairs(a) do if v~=b[i] then return false end end
    return true
  end
  local cap=math.min(result.fast_clear and 70 or 140000,
    options and options.search and options.search.max_evaluations or 140000)
  local spent=result.discard_preference_work or 0
  receipt.evaluations=spent
  local remaining=math.max(0,math.min(12-spent,cap-(result.evaluations or 0)))
  local play=result.play
  if not play or not same(action.indices,play.indices) or play.uncertain then
    if remaining<1 then return exception('The discard comparison allowance is exhausted.','work_limit') end
    if not modules.scoring or not modules.scoring.score then return exception('Final-action score support is unavailable.') end
    local score=modules.scoring.lower_bound or modules.scoring.score
    play=score(s,action.indices)
    result.evaluations=(result.evaluations or 0)+1;spent=spent+1;remaining=remaining-1
    receipt.evaluations=spent;result.discard_preference_work=spent
    if not play then return exception('Final-action score support is unavailable.') end
    play.indices=action.indices
  end
  local target=(s.blind or {}).chips
  if type(target)~='number' or target~=target or target==math.huge then return exception('The remaining blind target is unavailable.') end
  local needed=math.max(1,target-(s.chips or 0))
  receipt.final_play_score=play.score;receipt.needed_score=needed
  if play.legal==false or type(play.score)~='number' or play.uncertain then
    return exception('The selected play lacks a supported clearing score.')
  end
  if play.score<needed then
    if play.bound_kind or play.conservative then return exception('The supported floor is below target; a random clear remains possible.') end
    receipt.reason='selected_play_does_not_clear';return result
  end
  receipt.clear_supported=true
  local diagnostics=result.growth_diagnostics
  if diagnostics and diagnostics.exhaust_discards and same(action.indices,(result.discard_preference_anchor or {}).indices) then
    receipt.evaluations=spent
    return exception((diagnostics.reasons or {})[1] or 'The existing retained-clear discard comparison did not qualify.',
      (diagnostics.max_evaluations or 0)<=0 and 'work_limit' or nil)
  end
  if remaining<1 then return exception('The discard comparison allowance is exhausted.','work_limit') end
  if not modules.growth or not modules.growth.suggest then return exception('The retained-clear discard module is unavailable.') end
  local preference={exhaust_discards=true,max_evaluations=remaining}
  local anchor=play
  local suggestion,count,why
  if modules.growth.suggest_portfolio then
    suggestion,count,why,anchor,result.growth_anchor_diagnostics=
      modules.growth.suggest_portfolio(s,modules,play,result.alternatives,preference)
  else
  if modules.growth.select_clear then
    anchor,result.growth_anchor_diagnostics=modules.growth.select_clear(s,play,result.alternatives,preference)
  end
  suggestion,count,why=modules.growth.suggest(s,modules,anchor,preference)
  end
  result.evaluations=(result.evaluations or 0)+(count or 0)
  receipt.evaluations=spent+(count or 0);result.discard_preference_work=receipt.evaluations
  result.growth_diagnostics=why
  if not suggestion or not suggestion.action or suggestion.action.kind~='discard' then
    return exception(why and (why.reasons or {})[1] or 'No supported retained-clear discard was found.')
  end
  -- Keep the displaced evidence but presentation and Execute must use the
  -- selected discard rather than a stale resource/specialist play.
  result.discard_preference_prior_kind=result.kind
  for _,field in ipairs({'mixed_rescue','boss_rescue','hand_ordering','ordering','consumable',
      'multi_discard','two_hand_finish','growth'}) do result[field]=nil end
  result.growth=suggestion;result.action=suggestion.action;result.kind='discard'
  result.discard_preference_displaced_strategy=result.strategy;result.strategy=nil
  receipt.status='discard_selected';receipt.selected=true;receipt.reason='supported_retained_clear'
  receipt.final_action_kind='discard'
  return result
end
function D.run(snapshot,modules,yield_fn,options)
  -- This precedes scoring-cache preparation, concealed playing-card inference,
  -- ordinary search, all specialists, phase copying and retry policy callbacks.
  -- None may inspect the raw concealed Joker row as an implicit fallback.
  if hidden_joker(snapshot) then return discard_preference(snapshot,modules,
    public_joker_decision(snapshot,modules,yield_fn,options),options) end
  local statistics
  if modules.score_cache and not (options and options.prepared_scoring==false) then
    local scoped={};for k,v in pairs(modules) do scoped[k]=v end
    scoped.scoring,statistics=modules.score_cache.new(modules.scoring,options and options.score_cache)
    modules=scoped
  end
  local result=run(snapshot,modules,yield_fn,options)
  local fishing_action
  if result and result.growth and result.growth.growth and result.growth.growth.death_source then
    local proposed=result.growth.action
    if proposed and proposed.kind=='discard' then
      fishing_action={kind=proposed.kind,area=proposed.area,indices={}}
      for i,index in ipairs(proposed.indices or {}) do fishing_action.indices[i]=index end
    end
  end
  -- Retention proves an actual reorder or fixed-row exit, including Perkeo copies.
  -- A new copy arrangement would invalidate that comparison and can expose
  -- the retained target to ordinary resale on the following decision.
  local fixed_retention=result and result.action and
    (result.action.kind=='leave_shop' or result.action.kind=='reorder_jokers') and
    result.strategy and result.strategy.gold_retention and result.gold_retention_diagnostics and
    result.gold_retention_diagnostics.complete
  local first_burnt=false
  if snapshot.phase=='hand' and snapshot.teacher_profile=='perkeo_yorick_win_v1' and
      (snapshot.discards_used or (snapshot.current_round or {}).discards_used or 0)==0 then
    for _,j in ipairs(snapshot.jokers or {}) do if j.key=='j_burnt' and not j.debuff then first_burnt=true end end
  end
  if modules.phase_copy and (not (result and result.reorder_only) or first_burnt) and not fixed_retention then
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
  result=discard_preference(snapshot,modules,result,options)
  -- Copy setup and checkpoint retry can replace or remove the action after the
  -- ordinary arbitration. Keep the immutable proposal separate from execution.
  stamp_yorick_choice(result)
  if result then
    -- Record the final selected physical Death direction after all overrides.
    local a=result.action or {};local selected=(snapshot[a.area] or {})[a.index or 0]
    local targets=a.targets
    if selected and selected.key=='c_death' and targets and #targets==2 then
      local left,right=math.min(targets[1],targets[2]),math.max(targets[1],targets[2])
      local source,recipient=(snapshot.hand or {})[right],(snapshot.hand or {})[left]
      if source and recipient then result.death_review={schema=1,stage=snapshot.phase=='pack' and 'pack' or 'held',
        status='selected',source_id=source.id,recipient_id=recipient.id,source_index=right,recipient_index=left,
        source_rank=source.rank,source_suit=source.suit,source_enhancement=source.enhancement,source_seal=source.seal,
        source_edition=type(source.edition)=='string' and source.edition or type(source.edition)=='table' and
          (source.edition.type or source.edition.polychrome and 'polychrome' or source.edition.foil and 'foil' or source.edition.holo and 'holo' or source.edition.negative and 'negative') or nil} end
    end
    if snapshot.phase=='hand' and snapshot.teacher_profile=='perkeo_yorick_win_v1' then
      result.death_fishing_review={schema=1,status='not_applicable',attempted=false,complete=false,reason='no_held_death'}
    end
    local held=false
    for _,c in ipairs(snapshot.consumeables or {}) do if c.key=='c_death' and not c.debuff then held=true end end
    if held and snapshot.phase=='hand' then
      local reason='ordinary_joint_search'
      if not modules.growth then reason='growth_module_unavailable'
      elseif not result.play or result.play.uncertain or not result.play.score or
          result.play.score<math.max(1,(snapshot.blind or {}).chips-(snapshot.chips or 0))*1.05 then reason='no_reliable_retained_clear' end
      result.death_fishing_review=result.growth_diagnostics and result.growth_diagnostics.death_fishing or
        {schema=1,status='not_requested',attempted=false,complete=false,reason=reason}
      local fishing={}
      for k,v in pairs(result.death_fishing_review) do fishing[k]=v end
      local same=fishing_action and a.kind==fishing_action.kind and a.area==fishing_action.area and
        #(a.indices or {})==#fishing_action.indices or false
      if same then for i,index in ipairs(fishing_action.indices) do
        if a.indices[i]~=index then same=false;break end
      end end
      fishing.proposal_selected=fishing.selected==true
      fishing.final_action_kind=a.kind
      fishing.final_action_matches_proposal=same
      fishing.selected=fishing.proposal_selected and same or false
      if fishing.proposal_selected and not same then
        fishing.proposal_reason=fishing.reason
        fishing.status='superseded';fishing.reason=a.kind and 'final_action_changed' or 'final_action_unavailable'
      end
      result.death_fishing_review=fishing
    end
    -- Presentation follows final arbitration, retaining the original search
    -- kind only as diagnostic evidence of an overridden proposal.
    if (a.kind=='play' or a.kind=='discard') and result.kind~=a.kind then result.search_kind=result.kind;result.kind=a.kind end
  end
  if result and statistics then result.score_cache=statistics() end
  return result
end
return D
