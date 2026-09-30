-- Local, explicitly requested checkpoint exploration. A failed whole line is
-- not proof that its first action is globally bad. This module neither scores
-- nor samples; it reuses complete current-policy comparisons at an exact match.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out;for k,x in pairs(v) do out[k]=copy(x,seen) end;return out
end
local function shallow(v) local out={};for k,x in pairs(v or {}) do out[k]=x end;return out end
local function used(context,key) return key and context.failed_actions[key]~=nil and context.failed_actions[key]~=false end
local function key_for(modules,snapshot,action)
  if modules and modules._retry_action_key then return modules._retry_action_key(action) end
  local memory=modules and modules.retry_memory
  if not memory or type(memory.action_key)~='function' then return nil end
  return memory.action_key(snapshot,action)
end
local function no_inventory_engine(s)
  return #(s.jokers or {})==0 and not (s.used_vouchers or {}).v_observatory and not (s.vouchers or {}).v_observatory
end
local function finish(e)
  if not e or e.uncertain or e.incomplete then return end
  local before,after=e.before_finishing,e.after_finishing
  local br,ar=e.before_readiness,e.after_readiness
  -- A leave-shop endpoint reuses the exact baseline readiness object exported
  -- by the complete shop graph; no missing outcome is inferred from a mean.
  before=before or br and br.finishing;after=after or ar and ar.finishing
  local target=e.before_target or br and br.target
  local after_target=e.after_target or ar and ar.target
  if not finite(target) or target<=0 or target~=after_target or e.blind=='bl_arm' then return end
  for _,value in ipairs({before or false,after or false}) do
    if not value or not value.complete or not value.supported or not value.known_mechanics or value.samples~=4 or
      not value.selected or type(value.selected.worlds)~='table' or #value.selected.worlds~=4 then return end
    for _,world in ipairs(value.selected.worlds) do
      for _,field in ipairs({'progress','hands_used','discards_used','dollars_after','population_loss','finish_reward'}) do
        if not finite(world[field]) then return end
      end
      if world.progress<0 or world.progress>1 or world.population_loss<0 then return end
    end
  end
  return {target=target,before=before.selected.worlds,after=after.selected.worlds}
end
local function protects(candidate,incumbent)
  if not candidate or not incumbent or candidate.target~=incumbent.target then return false end
  for i=1,4 do
    local a,b=candidate.after[i],incumbent.after[i]
    for _,field in ipairs({'progress','hands_used','discards_used','dollars_after','population_loss','finish_reward'}) do
      if candidate.before[i][field]~=incumbent.before[i][field] then return false end
    end
    -- Exploration can change uncertain progress estimates, but cannot discard
    -- an already supported clear or buy that exploration with more population
    -- damage or a lower finishing reward in any matched world.
    if b.progress==1 and a.progress<1 or a.population_loss>b.population_loss or a.finish_reward<b.finish_reward then return false end
  end
  return true
end
local function planet(card)
  return card and not card.face_down and not card.debuff and (card.ability or {}).set=='Planet' and
    type(((card.ability or {}).consumeable or {}).hand_type)=='string'
end
local function pack_candidates(s,r,modules)
  local d=r.pack_diagnostics or r.strategy and r.strategy.pack_diagnostics
  if not d or not d.complete or d.incomplete or d.tactical_fallback or type(d.offers)~='table' or #d.offers>12 then
    return nil,'The revealed pack comparison is incomplete.'
  end
  local original=key_for(modules,s,r.action);local incumbent,candidates=nil,{}
  for _,offer in ipairs(d.offers) do
    if offer.legal and finite(offer.score) and offer.score>0 then
      local evidence=finish(offer.scoring_evidence)
      local key=key_for(modules,s,offer.action)
      if not evidence or not key then return nil,'A considered revealed choice lacks complete legal endpoint evidence.' end
      if key==original then incumbent=evidence end
      local card=(s.pack_cards or {})[offer.index]
      if planet(card) and offer.action.kind=='choose' and offer.action.area=='pack_cards' and
        not offer.planet_dominated_by and #(offer.action.targets or {})==0 then
        candidates[#candidates+1]={key=key,action=offer.action,rank=offer.score,evidence=offer.scoring_evidence,
          comparison=evidence,scope='complete_revealed_planets',title='Choose '..tostring(card.name or card.key)}
      end
    end
  end
  if not incumbent or not planet((s.pack_cards or {})[r.action.index]) then
    return nil,'The failed first action has no complete revealed-Planet comparison.'
  end
  local admitted={}
  for _,candidate in ipairs(candidates) do if protects(candidate.comparison,incumbent) then admitted[#admitted+1]=candidate end end
  return admitted
end
local function signature(action)
  return action and table.concat({action.kind or '',action.area or '',tostring(action.index or '')},':')
end
local function planet_plan(s,plan)
  if type(plan.actions)~='table' or #plan.actions>4 then return false end
  local offers,owned={},{}
  for i,card in ipairs(s.shop_jokers or {}) do offers[i]=card end
  for i,card in ipairs(s.consumeables or {}) do owned[i]=card end
  -- Validate the whole retained endpoint, including shifted offer/inventory
  -- indices. A Planet first action must not hide a later Joker or Tarot plan.
  for _,action in ipairs(plan.actions) do
    local index=action.index
    if not finite(index) or index%1~=0 or index<1 then return false end
    if action.kind=='buy' and action.area=='shop_jokers' and planet(offers[index]) then
      owned[#owned+1]=table.remove(offers,index)
    elseif action.kind=='use' and action.area=='consumeables' and planet(owned[index]) and #(action.targets or {})==0 then
      table.remove(owned,index)
    else return false end
  end
  return true
end
local function shop_candidates(s,r,modules)
  local d=r.shop_diagnostics;local sequences=d and d.sequences
  if not d or d.truncated or not sequences or not sequences.complete or type(sequences.best_by_first_action)~='table' then
    return nil,'The visible shop sequence comparison is incomplete.'
  end
  local plans=sequences.best_by_first_action
  local current=plans[signature(r.action)]
  local incumbent=current and finish(current.scoring_evidence)
  if not incumbent or not planet_plan(s,current) then return nil,'The failed shop action lacks a complete supported Planet continuation.' end
  local candidates,count={},0
  for _,plan in pairs(plans) do
    count=count+1;if count>64 then return nil,'The completed shop family exceeds retry scope.' end
    if not plan.complete or type(plan.actions)~='table' or not finite(plan.utility) or not finite(plan.cash_after) then
      return nil,'A visible shop continuation is incomplete.'
    end
    local evidence=finish(plan.scoring_evidence)
    if not evidence then return nil,'A visible shop continuation has unsupported finishing mechanics.' end
    local action=plan.actions[1] or {kind='leave_shop'}
    local allowed=action.kind=='leave_shop'
    if action.kind=='buy' and action.area=='shop_jokers' then allowed=planet((s.shop_jokers or {})[action.index]) end
    if action.kind=='use' and action.area=='consumeables' then allowed=planet((s.consumeables or {})[action.index]) end
    local key=key_for(modules,s,action)
    local funded=plan.cash_after>=(s.bankrupt_at or 0)
    if action.kind~='leave_shop' then
      -- The graph already checked legal capacity, exact transitions and
      -- whole-inventory retention for each step. Retain its final reserve too.
      local liquidity=plan.liquidity
      funded=funded and liquidity and finite(liquidity.purchase_floor) and plan.cash_after>=liquidity.purchase_floor
    end
    if allowed and key and funded and planet_plan(s,plan) and (action.kind=='leave_shop' or plan.utility>0) and protects(evidence,incumbent) then
      candidates[#candidates+1]={key=key,action=action,rank=plan.utility,plan=plan,evidence=plan.scoring_evidence,
        scope='complete_visible_planet_sequences',title=plan.titles and plan.titles[1] or 'Leave the shop'}
    end
  end
  return candidates
end
local plain_blinds={bl_small=true,bl_big=true,bl_wall=true,bl_needle=true,bl_water=true,bl_manacle=true,
  bl_psychic=true,bl_eye=true,bl_mouth=true,bl_flint=true,bl_final_vessel=true,bl_final_bell=true}
local function plain_hand(s)
  if #(s.hand or {})<1 or #s.hand>8 or #(s.consumeables or {})>0 then return false end
  local blind=s.blind or {}
  if not blind.disabled and not plain_blinds[blind.key] then return false end
  for _,key in ipairs({'discard_cost','debuff_played_cards','chips_dollar_cap','minus_hand_size_per_X_dollar','flipped_cards'}) do
    local value=(s.modifiers or {})[key];if value and value~=0 then return false end
  end
  for _,card in ipairs(s.playing_cards or {}) do
    if card.debuff or card.seal or card.edition and (type(card.edition)~='table' or next(card.edition)~=nil) or
      card.enhancement and card.enhancement~='c_base' or card.key and card.key~='c_base' or
      not finite(card.rank) or card.rank%1~=0 or card.rank<2 or card.rank>14 then return false end
    local a=card.ability or {}
    for _,key in ipairs({'mult','bonus','perma_bonus','p_dollars','h_dollars','h_mult','h_x_mult'}) do
      if a[key]~=nil and a[key]~=0 then return false end
    end
    if a.x_mult~=nil and a.x_mult~=1 then return false end
  end
  return true
end
local function valid_indices(s,indices)
  if type(indices)~='table' or #indices<1 or #indices>math.min(5,s.hand_limit or 5) then return false end
  local seen={}
  for _,i in ipairs(indices) do if not finite(i) or i%1~=0 or not s.hand[i] or seen[i] then return false end;seen[i]=true end
  for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not seen[i] then return false end end
  return true
end
local function hand_candidates(s,r,modules)
  if not plain_hand(s) or r.truncated or r.fast_clear or r.clear_shortcut then return nil,'Hand retry needs complete plain visible scoring without protected effects.' end
  for _,field in ipairs({'consumable','growth','ordering','hand_ordering','boss_rescue','mixed_rescue','multi_discard','two_hand_finish','resource_comparison'}) do
    if r[field] then return nil,'A specialist continuation cannot be replaced by a shallower retry comparison.' end
  end
  local target=(s.blind or {}).chips
  if not finite(target) or not finite(s.chips or 0) then return nil,'The remaining hand target is unknown.' end
  target=math.max(1,target-(s.chips or 0))
  if r.play and not r.play.uncertain and finite(r.play.score) and r.play.score>=target then
    return nil,'Keep the supported immediate clear available for review; a failed later line does not invalidate it.'
  end
  local candidates={}
  if r.action.kind=='play' then
    if not r.play_complete or type(r.alternatives)~='table' or #r.alternatives>256 then return nil,'Current play comparisons are incomplete.' end
    if not r.play or r.play.uncertain or not finite(r.play.score) then return nil,'The current play has unsupported scoring evidence.' end
    for _,play in ipairs(r.alternatives) do
      if play.legal~=false then
        if play.uncertain or not finite(play.score) or not valid_indices(s,play.indices) or
          (play.arm_cost or 0)~=0 or (play.population_loss or 0)~=0 or (play.population_cost or 0)~=0 or (play.glass_loss or 0)~=0 then
          return nil,'A legal play lacks a supported complete plain-card comparison.'
        end
        local action={kind='play',area='hand',indices=play.indices};local key=key_for(modules,s,action)
        if key then candidates[#candidates+1]={key=key,action=action,rank=play.score,play=play,scope='complete_plain_current_plays'} end
      end
    end
  elseif r.action.kind=='discard' then
    if not r.discard_comparison_complete or type(r.discard_alternatives)~='table' or #r.discard_alternatives>64 or
      (s.discards_left or (s.current_round or {}).discards_left or 0)<1 then return nil,'Matched discard comparisons are incomplete.' end
    local samples
    for _,discard in ipairs(r.discard_alternatives) do
      if not finite(discard.count) or discard.count<4 or discard.count%1~=0 or samples and samples~=discard.count or
        not finite(discard.mean) or not finite(discard.probability) or discard.probability<0 or discard.probability>1 or
        not finite(discard.value) then return nil,'Discard outcomes are not fully matched.' end
      samples=discard.count
      if valid_indices(s,discard.indices) and (discard.growth or 0)==0 then
        local action={kind='discard',area='hand',indices=discard.indices};local key=key_for(modules,s,action)
        if key then candidates[#candidates+1]={key=key,action=action,rank=discard.value,
          survival=(s.hands_left or (s.current_round or {}).hands_left or 0)==1 and discard.probability or nil,
          discard=discard,scope='complete_matched_plain_discards'} end
      end
    end
  else return nil,'The failed hand action has no reusable complete alternative family.' end
  local current=key_for(modules,s,r.action)
  for _,candidate in ipairs(candidates) do
    if candidate.key==current then
      if candidate.play and (s.hands_left or (s.current_round or {}).hands_left)==1 then
        local clears={}
        for _,other in ipairs(candidates) do if other.play.score>=target then clears[#clears+1]=other end end
        if #clears>0 then return clears end
        return nil,'These complete plain final-play comparisons all immediately lose; retry from an earlier checkpoint instead.'
      end
      return candidates
    end
  end
  return nil,'The failed hand action is not part of this complete admissible comparison.'
end
local function decorate(result,context,action,status,reason,candidate,count)
  local out=shallow(result)
  local lines={reason,'This explores an untried branch after your checkpoint reload. Failure of the whole line does not prove its first action was wrong; no rescue or win chance is predicted.'}
  out.retry={status=status,review_only=action==nil,original_action=copy(result.action),selected_action=copy(action),
    reloads_used=context.reloads_used,reloads_remaining=context.reloads_remaining,considered=count or 0,
    scope=candidate and candidate.scope,lines=lines,failed_line_only=true,rescored=false}
  out.action=copy(action)
  if result.strategy then out.strategy=shallow(result.strategy);out.strategy.action=copy(action) end
  if candidate then
    if candidate.play then out.kind='play';out.play=copy(candidate.play)
    elseif candidate.discard then out.kind='discard';out.discard=copy(candidate.discard)
    else
      out.kind='strategy';out.strategy={title='Retry: '..candidate.title,lines=copy(lines),warnings={},action=copy(action),
        scoring_evidence=copy(candidate.evidence),shop_sequence=copy(candidate.plan)}
    end
  end
  return out
end
function M.apply(snapshot,result,context,modules)
  if not result or not context or context.active~=true or type(context.failed_actions)~='table' then return result end
  local memory=modules and modules.retry_memory
  if memory and type(memory.action_key_context)=='function' then
    local encoder=memory.action_key_context(snapshot)
    if not encoder then return decorate(result,context,nil,'review_only','The current observation cannot be matched safely to retry history.') end
    modules=shallow(modules);modules._retry_action_key=encoder
  end
  local original=key_for(modules,snapshot,result.action)
  if not original then return decorate(result,context,nil,'review_only','The current action cannot be matched safely to retry history.') end
  if not used(context,original) then return result end
  if not no_inventory_engine(snapshot) then
    return decorate(result,context,nil,'review_only','No supported untried alternative is available without changing protected Joker or Observatory development.')
  end
  local candidates,reason
  if snapshot.phase=='pack' then candidates,reason=pack_candidates(snapshot,result,modules)
  elseif snapshot.phase=='shop' then candidates,reason=shop_candidates(snapshot,result,modules)
  elseif snapshot.phase=='hand' then candidates,reason=hand_candidates(snapshot,result,modules)
  else reason='This checkpoint phase has no complete retry comparison.' end
  if not candidates then return decorate(result,context,nil,'review_only',reason) end
  table.sort(candidates,function(a,b)
    if a.survival~=nil and b.survival~=nil and a.survival~=b.survival then return a.survival>b.survival end
    if a.rank~=b.rank then return a.rank>b.rank end
    if (a.play and b.play or a.discard and b.discard) then
      local ai,bi=a.action.indices,b.action.indices
      if #ai~=#bi then return #ai<#bi end
      for i=1,#ai do if ai[i]~=bi[i] then return ai[i]<bi[i] end end
    end
    return a.key<b.key
  end)
  for _,candidate in ipairs(candidates) do
    if not used(context,candidate.key) then
      return decorate(result,context,candidate.action,'alternative','Try the highest-ranked admissible untried first action, then request fresh advice.',candidate,#candidates)
    end
  end
  return decorate(result,context,nil,'review_only','Every supported complete alternative at this checkpoint has already appeared in a failed line.',nil,#candidates)
end
return M
