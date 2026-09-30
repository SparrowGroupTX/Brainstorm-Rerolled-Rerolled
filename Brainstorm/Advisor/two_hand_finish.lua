-- Two or three playable hands with one conditional final-hand redraw. This compares
-- fixed FIRST actions; the later discard may depend only on its observed hand,
-- never on the independent inner draws used to evaluate it.
local M={}
local min,max,floor=math.min,math.max,math.floor
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function list(t) local out={};for i,v in ipairs(t or {}) do out[i]=v end;return out end
local function copy(t)
  if type(t)~='table' then return t end
  local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function hidden(s) for _,c in ipairs(s.hand or {}) do if c.face_down then return true end end;return false end
local function reliable(p,target)
  return p and p.legal~=false and not p.uncertain and type(p.score)=='number' and p.score==p.score and p.score<math.huge and p.score>=target
end
local function ordered(deck,seed,turn)
  local order=list(deck)
  table.sort(order,function(a,b) return tostring(a.id)<tostring(b.id) end)
  seed=(seed+turn*104729)%4294967296
  for i=#order,2,-1 do
    seed=(seed*1664525+1013904223)%4294967296
    local j=seed%i+1;order[i],order[j]=order[j],order[i]
  end
  return order
end
local function all_plays(s)
  local limit=min(5,num(s.hand_limit,5),#s.hand)
  local out,chosen,forced={},{},{}
  for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection then forced[i]=true end end
  local function walk(start)
    if #chosen>0 then
      local used={};for _,i in ipairs(chosen) do used[i]=true end
      local legal=true;for i in pairs(forced) do if not used[i] then legal=false end end
      if legal then out[#out+1]=list(chosen) end
    end
    if #chosen>=limit then return end
    for i=start,#s.hand do chosen[#chosen+1]=i;walk(i+1);chosen[#chosen]=nil end
  end
  walk(1);return out
end
local upgrades={c_pluto=true,c_mercury=true,c_uranus=true,c_venus=true,c_saturn=true,c_jupiter=true,
  c_earth=true,c_mars=true,c_neptune=true,c_planet_x=true,c_ceres=true,c_eris=true,c_black_hole=true}
function M.suggest(s,modules,result,yield_fn,options)
  options=options or {};result=result or {};modules=modules or {}
  local initial_hands=num(s.hands_left,(s.current_round or {}).hands_left)
  local no_discard_planet=false
  if s.phase=='hand' and s.teacher_profile=='perkeo_yorick_win_v1' and initial_hands==2 and
      s.discards_left==0 then
    for _,owned in ipairs(s.consumeables or {}) do
      if upgrades[owned.key] and owned.key~='c_black_hole' and not owned.debuff then no_discard_planet=true end
    end
  end
  local diag={evaluations=0,max_evaluations=min(12000,max(0,floor(num(options.max_evaluations,12000)))),
    outer_samples=4,inner_samples=4,first_actions=2,final_discard_limit=2,complete=false,heuristic=true,
    horizon=initial_hands,
    consumable_offers={},consumable_limit=2,
    scope='Two or three plays, with the current play or discard first and at most one conditional discard before the final play. Small hands may compare one owned Planet or Black Hole before playing. A middle play follows its observed hand. Four outer x four conditional inner samples; not independent episodes.'}
  local function no(reason) diag.reason=reason;return nil,diag.evaluations,diag end
  local remaining=max(1,num((s.blind or {}).chips)-num(s.chips))
  if no_discard_planet then
    diag.no_discard_planet=true
    diag.scope='Two plays with no discards: incumbent and greedy current-play hold policies versus each eligible Planet followed by the same incumbent first play. Complete final observed-hand play families in four common composition worlds; no later owned use or guaranteed win.'
    local size=num(s.hand_size,#(s.hand or {}));local round=s.current_round or {}
    if size~=size or size<1 or size>8 or size~=floor(size) or
        #(s.consumeables or {})>8 or #(s.jokers or {})>8 then
      return no('The no-discard Planet comparison exceeds its public hand, row or inventory bounds.')
    end
    if round.hands_left~=nil and round.hands_left~=2 or round.discards_left~=nil and round.discards_left~=0 then
      return no('The no-discard Planet comparison requires consistent remaining resources.')
    end
    for _,area in ipairs({'hand','deck','jokers','consumeables'}) do for _,c in ipairs(s[area] or {}) do
      if c.unknown or c.identity_unknown or c.identity_redacted or c.concealed or c.getting_sliced or
          area~='deck' and (c.face_down or c.facing=='back') then
        return no('The no-discard Planet comparison requires known public identities.')
      end
    end end
  end
  if (initial_hands~=2 and initial_hands~=3) or not no_discard_planet and num(s.discards_left)<1 or #(s.deck or {})==0 then
    return no('This specialist requires two or three playable hands and a remaining discard.')
  end
  if initial_hands==3 and (#(s.hand or {})>6 or num(s.hand_size,#s.hand)>6) then
    return no('Three-hand finishing is admitted only for hands of at most six cards within the existing work bound.')
  end
  if hidden(s) or #(s.hand or {})<1 or #s.hand>8 or #s.deck>120 then return no('Visible hands of at most eight cards and a bounded deck are required.') end
  if reliable(result.play,remaining) or result.fast_clear then return no('A reliable current finish takes priority.') end
  if no_discard_planet then
    if result.kind~='play' then return no('The no-discard Planet comparison requires an incumbent play.') end
    if result.action then
      local current,scored=result.action.indices or {},(result.play or {}).indices or {}
      if result.action.kind~='play' or #current~=#scored then return no('The incumbent action and scored play must match.') end
      for i,index in ipairs(current) do if scored[i]~=index then return no('The incumbent action and scored play must match.') end end
    end
  end
  for _,field in ipairs({'consumable','ordering','hand_ordering','boss_rescue','mixed_rescue','growth'}) do
    if result[field] then return no('An existing tactical or investment action takes priority.') end
  end
  local prior=result.resource_comparison
  if not no_discard_planet and (not prior or not prior.full_remaining_horizon or prior.future_discards~=false or num(prior.samples)<4) then
    return no('A complete existing two-hand play-only comparison is required before extending it.')
  end
  if initial_hands==3 and num(prior.horizon)<3 then return no('A completed three-hand baseline is required.') end
  if not no_discard_planet and (prior.prior and num(prior.prior.probability)>=1 or prior.best and num(prior.best.probability)>=1) then
    return no('The existing sampled finishing plan already clears every compared world.')
  end
  if not result.play or not result.play.indices or not no_discard_planet and (not result.discard or not result.discard.indices) then return no('Both current first actions are required for a fair comparison.') end
  local scorer,search,draws,outcomes=modules.scoring,modules.search,modules.draws,modules.sampled_outcomes
  local multi=modules.multi_discard
  if not scorer or not scorer.score or not scorer.after_play or not scorer.after_discard or not search or
      not search.population_profile or not search.population_cost or not draws or not outcomes or not multi or not multi.discard_candidates then
    return no('Exact play/discard, population, conditional draw or candidate dependencies are unavailable.')
  end
  local ids={}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    if no_discard_planet and not (type(c.id)=='string' and c.id~='' or
        type(c.id)=='number' and c.id==c.id and math.abs(c.id)<math.huge) then
      return no('Canonical public physical identities are required for Planet composition sampling.')
    end
    local id=no_discard_planet and tostring(c.id) or c.id
    if id==nil or ids[id] then return no('Distinct physical identities are required for composition sampling.') end
    ids[id]=true
  end end
  local aborted
  local function charge()
    if diag.evaluations>=diag.max_evaluations then aborted='The existing 12,000-score specialist allowance cannot complete all compared worlds.';return false end
    diag.evaluations=diag.evaluations+1
    if yield_fn and diag.evaluations%64==0 then yield_fn() end
    return true
  end
  local function best_play(state)
    if hidden(state) or #state.hand>8 then aborted='A future hand is concealed or exceeds eight cards.';return nil end
    local target=max(1,num(state.blind.chips)-num(state.chips))
    local population=search.population_profile(state)
    local rewards
    local best
    for _,indices in ipairs(all_plays(state)) do
      if not charge() then return nil end
      local p=scorer.score(state,indices)
      if p and p.legal~=false then
        if type(p.score)~='number' or p.score~=p.score or p.score<0 or p.score==math.huge or p.uncertain then
          aborted='An uncertain, unsupported or non-finite score cannot establish this finishing comparison.';return nil
        end
        p.indices=list(indices)
        p.population_cost=search.population_cost(state,p,population)
        p.arm_cost=search.arm_cost and search.arm_cost(state,p.hand) or 0
        local clear=reliable(p,target)
        p.finish_reward=0
        if clear and modules.finish_rewards then
          rewards=rewards or modules.finish_rewards.prepare(state,modules.strategy)
          p.finish_reward=modules.finish_rewards.value(state,p,rewards)
        end
        local old_clear=reliable(best,target)
        if not best or clear and not old_clear or clear and old_clear and
            (p.population_cost<best.population_cost or p.population_cost==best.population_cost and
              (p.arm_cost<best.arm_cost or p.arm_cost==best.arm_cost and p.finish_reward>best.finish_reward)) or
            not clear and not old_clear and p.score>best.score then best=p end
      end
    end
    if not best then aborted='No supported legal future play exists.' end
    return best
  end
  local function fill(state,seed,turn)
    local bell=floor(outcomes.roll(seed,turn,'two-hand-bell',0)*1000000)
    local next_state,reason=outcomes.fill(state,ordered(state.deck,seed,turn),scorer,draws,seed,turn,bell)
    if not next_state then aborted=reason;return nil end
    if hidden(next_state) or #next_state.hand>8 then aborted='A future observation is concealed or exceeds eight cards.';return nil end
    return next_state
  end
  local function outcome(state,play,first_loss)
    local total=num(state.chips)+num(play.score)-num(s.chips)
    return {probability=total>=remaining and 1 or 0,utility=min(1,max(0,total/remaining)),
      population_loss=num(first_loss)+num(play.population_cost),finish_reward=num(play.finish_reward),hands=initial_hands,extra_discards=0}
  end
  local function final_policy(state,seed,first_loss)
    local p=best_play(state);if not p then return nil end
    local chosen=outcome(state,p,first_loss)
    if chosen.probability==1 or num(state.discards_left)<=0 or #state.deck==0 then return chosen end
    local candidates=multi.discard_candidates(state,nil,2)
    for _,candidate in ipairs(candidates) do
      local discarded,reason=scorer.after_discard(state,candidate.indices)
      if not discarded then aborted='A considered final discard is unsupported: '..tostring(reason);return nil end
      local wins,utility,loss,rewards=0,0,0,0
      for inner=1,4 do
        -- Candidate indices are fixed BEFORE these independent future draws.
        -- They can depend on this outer observation, never on inner identities.
        local next_state=fill(discarded,seed+inner*104729,initial_hands+1)
        if not next_state then return nil end
        local play=best_play(next_state);if not play then return nil end
        local v=outcome(next_state,play,first_loss)
        wins=wins+v.probability;utility=utility+v.utility;loss=loss+v.population_loss;rewards=rewards+v.finish_reward
      end
      local p,u=wins/4,utility/4
      if p>chosen.probability or p==chosen.probability and u>chosen.utility+0.02 then
        chosen={probability=p,utility=u,population_loss=loss/4,finish_reward=rewards/4,hands=initial_hands,extra_discards=1}
      end
    end
    return chosen
  end
  local second_play
  if no_discard_planet then second_play=best_play(s);if not second_play then return no(aborted) end end
  local branches={{kind='play',indices=list(result.play.indices),probability=0,utility=0,population_loss=0,finish_reward=0,hands=0,discards=0},
    {kind=no_discard_planet and 'play' or 'discard',indices=list(no_discard_planet and second_play.indices or result.discard.indices),
      probability=0,utility=0,population_loss=0,finish_reward=0,hands=0,discards=0}}
  local use_states,use_plays,eligible,pending={},{},{},{}
  for index,owned in ipairs(s.consumeables or {}) do
    local offer={index=index,key=owned.key,name=(owned.ability or {}).name or owned.name or owned.key,
      edition=copy(owned.edition),status='declined'}
    diag.consumable_offers[#diag.consumable_offers+1]=offer
    if not upgrades[owned.key] or no_discard_planet and owned.key=='c_black_hole' then offer.reason='Only the declared zero-target upgrades are admitted.'
    elseif not no_discard_planet and (#s.hand>6 or num(s.hand_size,#s.hand)>6) then offer.reason='Owned-upgrade finishing is limited to hands of at most six cards.'
    elseif owned.debuff then offer.reason='The held consumable is debuffed.'
    elseif not modules.consumables or not modules.consumables.apply or not modules.strategy or
      not modules.strategy.preservation_cost then offer.reason='Exact use and inventory-preservation dependencies are required.'
    else pending[#pending+1]=offer end
  end
  if #pending>2 then
    -- Do not let inventory order choose a partial subset, or clone a large
    -- Negative inventory repeatedly merely to decline it after scoring.
    for _,offer in ipairs(pending) do offer.reason='More than two eligible owned upgrades exceeds the complete comparison scope.' end
    diag.consumable_scope_declined=true
    if no_discard_planet then return no('More than two eligible Planets exceeds the complete no-discard comparison scope.') end
  else
    local unsupported
    for _,offer in ipairs(pending) do
      local index=offer.index;local upgraded,reason=modules.consumables.apply(s,index,{})
      if not upgraded then
        offer.status='unsupported';offer.reason=reason
        unsupported='A considered owned upgrade is unsupported: '..tostring(reason)
      else
        local cost,retention,last=modules.strategy.preservation_cost(s,upgraded,index)
        if type(cost)~='number' or cost~=cost or cost<0 or cost==math.huge then
          offer.status='unsupported';offer.reason='Inventory preservation cost is not finite.';unsupported=offer.reason
        else
          offer.inventory_cost=cost;offer.retention_reason=retention;offer.protected_last_source=not not last
          offer.inventory_after=#(upgraded.consumeables or {});offer.capacity_after=upgraded.consumable_limit
          if last and not no_discard_planet then offer.reason=retention or 'A sampled finish cannot consume the last protected Perkeo source.'
          else eligible[#eligible+1]={offer=offer,state=upgraded} end
        end
      end
    end
    if unsupported then return no(unsupported) end
    for _,candidate in ipairs(eligible) do
      local offer=candidate.offer;offer.status='admitted'
      local play
      if no_discard_planet then
        -- Match the actual first play across hold/use. The extra greedy hold
        -- branch prevents an inferior incumbent from fabricating Planet value.
        if not charge() then return no(aborted) end
        play=scorer.score(candidate.state,result.play.indices)
        if not play or play.legal==false or play.uncertain or type(play.score)~='number' or
            play.score~=play.score or play.score<0 or play.score==math.huge then
          offer.status='unsupported';return no('The matched post-Planet first play is unsupported.')
        end
        play.indices=list(result.play.indices)
        offer.matched_first_play=list(result.play.indices)
      else play=best_play(candidate.state) end
      if not play then offer.status='unsupported';offer.reason=aborted;return no(aborted) end
      use_states[offer.index]=candidate.state;use_plays[offer.index]=play
      branches[#branches+1]={kind='use',index=offer.index,name=offer.name,inventory_cost=offer.inventory_cost,
        probability=0,utility=0,population_loss=0,finish_reward=0,hands=0,discards=0,offer=offer}
    end
  end
  diag.first_actions=#branches
  local function branch_outcome(branch,seed)
    local state=copy(branch.kind=='use' and use_states[branch.index] or s);state.deck=ordered(state.deck,seed,0)
    local selected
    if branch.kind=='discard' then
      local reason;state,reason=scorer.after_discard(state,branch.indices)
      if not state then aborted='The incumbent first discard is unsupported: '..tostring(reason);return nil end
      state=fill(state,seed,1);if not state then return nil end
      selected=best_play(state);if not selected then return nil end
    elseif branch.kind=='use' then selected=use_plays[branch.index]
    else selected={indices=list(branch.indices)} end
    if not charge() then return nil end
    local after,reason,actual=outcomes.after_play(state,selected.indices,scorer,seed,1)
    if not after then aborted='The first play transition is unsupported: '..tostring(reason);return nil end
    if not actual or actual.uncertain or type(actual.score)~='number' or actual.score~=actual.score or actual.score<0 or actual.score==math.huge then
      aborted='The first play has unsupported random scoring or growth.';return nil
    end
    actual.indices=list(selected.indices)
    local first_loss=search.population_cost(state,actual,search.population_profile(state))
    local initial_discard=branch.kind=='discard' and 1 or 0
    if num(after.chips)>=num(after.blind.chips) then
      local reward=modules.finish_rewards and modules.finish_rewards.value(state,actual,
        modules.finish_rewards.prepare(state,modules.strategy)) or 0
      return {probability=1,utility=1,population_loss=first_loss,finish_reward=reward,hands=1,discards=initial_discard}
    end
    if num(after.hands_left)<=0 or #after.hand+#after.deck==0 then
      return {probability=0,utility=min(1,max(0,(num(after.chips)-num(s.chips))/remaining)),
        population_loss=first_loss,hands=1,discards=initial_discard}
    end
    state=fill(after,seed,2);if not state then return nil end
    if initial_hands==3 then
      local middle=best_play(state);if not middle then return nil end
      if not charge() then return nil end
      local next_state,why,actual_middle=outcomes.after_play(state,middle.indices,scorer,seed,2)
      if not next_state or not actual_middle or actual_middle.uncertain or type(actual_middle.score)~='number' or
        actual_middle.score~=actual_middle.score or actual_middle.score<0 or actual_middle.score==math.huge then
        aborted='The middle play transition is unsupported: '..tostring(why);return nil
      end
      actual_middle.indices=list(middle.indices)
      first_loss=first_loss+search.population_cost(state,actual_middle,search.population_profile(state))
      if num(next_state.chips)>=num(next_state.blind.chips) then
        local reward=modules.finish_rewards and modules.finish_rewards.value(state,actual_middle,
          modules.finish_rewards.prepare(state,modules.strategy)) or 0
        return {probability=1,utility=1,population_loss=first_loss,finish_reward=reward,hands=2,discards=initial_discard}
      end
      if #next_state.hand+#next_state.deck==0 then
        return {probability=0,utility=min(1,max(0,(num(next_state.chips)-num(s.chips))/remaining)),
          population_loss=first_loss,hands=2,discards=initial_discard}
      end
      if num(next_state.hands_left)~=1 then aborted='The middle transition did not leave one final playable hand.';return nil end
      state=fill(next_state,seed,3);if not state then return nil end
    end
    local final=final_policy(state,seed,first_loss);if not final then return nil end
    final.discards=initial_discard+final.extra_discards
    if no_discard_planet then
      final.first_indices=list(selected.indices);final.first_score=actual.score
      final.inventory_after_use=#(state.consumeables or {});final.capacity_after_use=state.consumable_limit
    end
    return final
  end
  for outer,seed in ipairs({2718281,3141593,1618033,1414213}) do
    local observations={}
    for i,branch in ipairs(branches) do
      observations[i]=branch_outcome(branch,seed)
      if not observations[i] then return no(aborted) end
    end
    -- Commit only fully paired outer sets; a later failure invalidates all sets.
    for i,branch in ipairs(branches) do
      if no_discard_planet then branch.worlds=branch.worlds or {};branch.worlds[outer]=copy(observations[i]) end
      for _,field in ipairs({'probability','utility','population_loss','finish_reward','hands','discards'}) do
        branch[field]=branch[field]+num(observations[i][field])/4
      end
    end
    diag.completed_outer=outer
  end
  diag.complete=true;diag.candidates=branches
  local incumbent=result.kind=='discard' and branches[2] or branches[1]
  local best=incumbent
  local function better(branch,reference)
    return branch.probability>reference.probability or branch.probability==reference.probability and
      (branch.utility>reference.utility+0.02 or math.abs(branch.utility-reference.utility)<0.000001 and
        branch.population_loss<reference.population_loss)
  end
  for i=1,2 do if better(branches[i],best) then best=branches[i] end end
  local best_without_use=best
  local function required_uplift(branch,reference)
    local extra_discards=max(0,branch.discards-reference.discards)
    local extra_actions=max(0,branch.hands+branch.discards+(branch.kind=='use' and 1 or 0)-reference.hands-reference.discards)
    local threshold=max(.125,num(options.minimum_uplift,.125))+
      min(.25,.025*extra_actions+.025*extra_discards*num((s.modifiers or {}).discard_cost))
    -- Inventory points and this sampled probability are both heuristics. Keep
    -- the conversion explicit; it is not a calibrated win/cash equivalence.
    return threshold+(branch.kind=='use' and branch.inventory_cost/100 or 0),extra_actions
  end
  for i=3,#branches do
    local branch=branches[i];local threshold,extra_actions=required_uplift(branch,best_without_use)
    branch.offer.required_uplift=threshold;branch.offer.extra_actions=extra_actions
    branch.offer.no_use_probability=best_without_use.probability
    branch.offer.uplift=branch.probability-best_without_use.probability
    if branch.offer.uplift<threshold then
      branch.offer.status='declined';branch.offer.reason='The paired gain does not cover preserving the inventory and one extra use action.'
    else
      branch.offer.status='compared';branch.offer.reason='Complete paired gain covers the explicit inventory and action-cost threshold.'
      if better(branch,best) then best=branch end
    end
  end
  diag.baseline_probability=incumbent.probability;diag.estimated_probability=best.probability
  diag.uplift=best.probability-incumbent.probability
  if no_discard_planet and best.kind~='use' then return no('The no-use policies remain preferable after the complete two-hand Planet comparison.') end
  if best==incumbent then return no('The incumbent remains best after the conditional final-hand discard comparison.') end
  local threshold=required_uplift(best,incumbent)
  diag.required_uplift=threshold
  if diag.uplift<threshold then return no('The paired finishing gain does not cover the extra action and discard costs.') end
  if best.kind=='use' then
    best.offer.status='selected'
    return {action={kind='use',area='consumeables',index=best.index,targets={}},horizon=initial_hands,
      consumable_name=best.name,probability=best.probability,baseline_probability=incumbent.probability,
      no_use_probability=best_without_use.probability,heuristic=true,scope=diag.scope,
      reason=string.format('Use %s before playing: the complete bounded %d-hand comparison improves from %.0f%% to %.0f%% over the best no-use plan. Only use this card, then refresh; the paired samples are not a win-rate estimate.',
        tostring(best.name),initial_hands,best_without_use.probability*100,best.probability*100)},diag.evaluations,diag
  end
  return {action={kind=best.kind,area='hand',indices=list(best.indices)},indices=list(best.indices),horizon=initial_hands,
    probability=best.probability,baseline_probability=incumbent.probability,heuristic=true,scope=diag.scope,
    reason=string.format('Preserve a final-hand redraw: the complete bounded %d-hand comparison improves from %.0f%% to %.0f%%. Take this first action, then refresh after the actual observation; these samples are not a win-rate estimate.',initial_hands,incumbent.probability*100,best.probability*100)},diag.evaluations,diag
end
return M
