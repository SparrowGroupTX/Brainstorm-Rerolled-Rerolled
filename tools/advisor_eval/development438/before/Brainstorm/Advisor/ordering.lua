-- Pure bounded Joker-order search. Every order is compared on the same hand
-- subsets with the real detached scorer; no live Card callback or RNG is used.
local M = {}
local function num(value, fallback) return type(value)=='number' and value or (fallback or 0) end
local function copy(value) local out={}; for k,v in pairs(value or {}) do out[k]=v end; return out end
local function list(value) local out={}; for i,v in ipairs(value or {}) do out[i]=v end; return out end
local function name(card) return (card.ability or {}).name or card.name or card.key or 'Joker' end
local function pinned(card) return card.pinned or (card.ability or {}).pinned end
local function is(card,key,label) return card.key==key or name(card)==label end

local function subsets(s, base, options)
  local all, selected, forced={},{},{}
  for i,c in ipairs(s.hand or {}) do if (c.ability or {}).forced_selection then forced[i]=true end end
  local limit=math.min(5,num(s.hand_limit,5))
  local function walk(first)
    if #selected>0 then
      local valid=true
      for i in pairs(forced) do
        local found=false; for _,j in ipairs(selected) do if i==j then found=true end end
        if not found then valid=false; break end
      end
      if valid then all[#all+1]=list(selected) end
    end
    if #selected>=limit then return end
    for i=first,#s.hand do selected[#selected+1]=i; walk(i+1); selected[#selected]=nil end
  end
  walk(1)
  if #all<=num(options.full_subset_limit,256) then return all,false end
  local max_subsets=math.max(1,num(options.max_subsets,128))
  local shortlist, seen={},{}
  local function add(indices)
    if not indices or #indices==0 or #indices>limit or #shortlist>=max_subsets then return end
    local chosen={}
    for _,i in ipairs(indices) do if not s.hand[i] or chosen[i] then return end; chosen[i]=true end
    for i in pairs(forced) do if not chosen[i] then return end end
    local sorted=list(indices); table.sort(sorted)
    local key=table.concat(sorted,',')
    if not seen[key] then seen[key]=true; shortlist[#shortlist+1]=sorted end
  end
  add(base.play and base.play.indices)
  add(base.consumable and base.consumable.play and base.consumable.play.indices)
  add(base.consumable and base.consumable.sequence and base.consumable.sequence.play.indices)
  local categories={}
  for _,play in ipairs(base.alternatives or {}) do
    if not categories[play.hand] then categories[play.hand]=true; add(play.indices) end
  end
  -- Different copy targets can favor low ranks/suits that were weak under the
  -- old order, so include singletons/pairs before filling with old top scores.
  for _,indices in ipairs(all) do if #indices<=2 then add(indices) end end
  for _,play in ipairs(base.alternatives or {}) do add(play.indices) end
  for i=1,max_subsets do add(all[math.max(1,math.floor((i-1)*#all/max_subsets)+1)]) end
  return shortlist,true
end

local function orders(jokers,limit)
  local out,seen,free,identity={},{},{},{}
  for i,j in ipairs(jokers) do identity[i]=i; if not pinned(j) then free[#free+1]=i end end
  local function add(order)
    if #out>=limit then return end
    local key=table.concat(order,',')
    if not seen[key] then seen[key]=true; out[#out+1]=list(order) end
  end
  add(identity)
  -- Useful local moves come before a bounded lexicographic permutation tail.
  -- This covers distant copy targets even when a large row cannot be exhausted.
  for _,i in ipairs(free) do for _,j in ipairs(free) do if i<j then
    local order=list(identity); order[i],order[j]=order[j],order[i]; add(order)
  end end end
  for a=1,#free do for b=1,#free do if a~=b then
    local values=list(free); local moving=table.remove(values,a); table.insert(values,b,moving)
    local order=list(identity); for k,pos in ipairs(free) do order[pos]=values[k] end; add(order)
  end end end
  local function tier(card)
    local a,e=card.ability or {},card.edition or {}
    if type(e)=='table' and e.polychrome or num(a.x_mult)>1 or num(a.Xmult)>1 then return 3 end
    if is(card,'j_blueprint','Blueprint') or is(card,'j_brainstorm','Brainstorm') then return 2 end
    if num(a.mult)>0 or type(e)=='table' and e.holo then return 1 end
    return 0
  end
  local sorted=list(free)
  table.sort(sorted,function(a,b) local ta,tb=tier(jokers[a]),tier(jokers[b]); return ta==tb and a<b or ta<tb end)
  local order=list(identity); for k,pos in ipairs(free) do order[pos]=sorted[k] end; add(order)
  local values,used={},{}
  local function permute(position)
    if #out>=limit then return end
    if position>#free then
      local candidate=list(identity); for k,pos in ipairs(free) do candidate[pos]=values[k] end; add(candidate); return
    end
    for _,index in ipairs(free) do if not used[index] then
      used[index]=true; values[position]=index; permute(position+1); used[index]=nil
      if #out>=limit then return end
    end end
  end
  permute(1)
  local possible=1; for i=2,#free do possible=math.min(1000000000,possible*i) end
  return out,#out<possible
end

local function format_order(s,order)
  local out={}
  for _,i in ipairs(order) do out[#out+1]='#'..i..' '..name(s.jokers[i]) end
  return table.concat(out,' -> ')
end

function M.suggest(snapshot,scorer,base_result,yield_fn,options)
  local s,base=snapshot or {},base_result or {}
  options=options or {}
  local diagnostics={evaluations=0,completed_orders=0,partial_orders=0,subset_shortlist=false,truncated=false}
  local function skip(reason) diagnostics.reason=reason; return nil,diagnostics.evaluations,diagnostics end
  if s.phase and s.phase~='hand' then return skip('Joker order is evaluated at a settled hand decision.') end
  if not scorer or not scorer.score or #(s.jokers or {})<2 or #(s.hand or {})==0 then return skip('No Joker order comparison available.') end
  if #s.hand>20 or #s.jokers>12 then
    diagnostics.truncated=true
    local reason='Joker-order comparison is limited to 20 held cards and 12 Jokers; use the bounded play recommendation.'
    diagnostics.warnings={reason}
    return skip(reason)
  end
  local blind=s.blind or {}
  if s.jokers_shuffling or blind.shuffle_pending or s.ordering_safe==false then return skip('Wait until Joker movement is complete.') end
  if not blind.disabled and (blind.key=='bl_final_acorn' or blind.name=='Amber Acorn') then
    return skip('Amber Acorn hides and shuffles Joker order; order advice is withheld during this blind.')
  end
  local movable=0
  for _,j in ipairs(s.jokers) do
    if j.face_down or j.facing=='back' then return skip('Reveal the Joker row before relying on an order recommendation.') end
    if not pinned(j) then movable=movable+1 end
  end
  if movable<2 then return skip('Pinned Joker positions leave no alternative order.') end
  local selected,shortlisted=subsets(s,base,options)
  diagnostics.subset_shortlist=shortlisted; diagnostics.subsets=#selected
  local budget=math.max(0,math.min(30000,math.floor(num(options.max_evaluations,30000))))
  if #selected==0 or budget<2*#selected then return skip('Budget cannot finish a fair comparison of two orders.') end
  local candidates,truncated=orders(s.jokers,math.min(num(options.max_orders,720),math.floor(budget/#selected)))
  diagnostics.truncated=truncated or shortlisted; diagnostics.candidate_orders=#candidates
  local needed=math.max(1,num(blind.chips)-num(s.chips))
  local arm=not blind.disabled and (blind.key=='bl_arm' or blind.name=='The Arm')
  local costs={}
  for _,play in ipairs(base.alternatives or {}) do if play.arm_cost~=nil then costs[play.hand]=play.arm_cost end end
  if base.play and base.play.arm_cost~=nil then costs[base.play.hand]=base.play.arm_cost end
  local function arm_cost(category)
    if not arm then return 0 end
    if options.arm_cost then return num(options.arm_cost(s,category),math.huge) end
    if costs[category]~=nil then return costs[category] end
    if num((s.hands or {})[category] and s.hands[category].level,1)<=1 then return 0 end
    return math.huge -- Never invent a favorable cost for an unknown upgraded hand.
  end
  local function future_metrics(state,play,trace)
    local loss,growth=0,0
    local played={}
    for _,i in ipairs(play.scoring_indices or play.indices) do played[i]=true end
    for _,i in ipairs(play.indices) do
      local c=state.hand[i]
      local resolved=(trace.cards or {})[i] or c
      if played[i] and (state.modifiers or {}).debuff_played_cards then loss=loss+1 end
      -- Vampire/Midas may remove Glass before its destruction check. Count
      -- only the enhancement that actually survives before-scoring effects.
      if played[i] and not resolved.debuff and resolved.enhancement=='m_glass' then loss=loss+0.25 end
    end
    for i,a in ipairs(trace.states or {}) do
      local j=state.jokers[i]; local before=j.ability or {}
      if is(j,'j_vampire','Vampire') then growth=growth+100*math.max(0,num(a.x_mult,1)-num(before.x_mult,1))
      elseif is(j,'j_wee','Wee Joker') then
        growth=growth+math.max(0,num(type(a.extra)=='table' and a.extra.chips)-num(type(before.extra)=='table' and before.extra.chips))/10
      end
    end
    return loss,growth
  end
  local function better(a,b)
    if not a then return false end
    if not b then return true end
    local ac,bc=a.score>=needed,b.score>=needed
    if ac~=bc then return ac end
    if ac then
      if a.arm_cost~=b.arm_cost then return a.arm_cost<b.arm_cost end
      if a.future_loss~=b.future_loss then return a.future_loss<b.future_loss end
      if a.expected_dollars~=b.expected_dollars then return a.expected_dollars>b.expected_dollars end
      if math.abs(a.future_growth-b.future_growth)>0.000001 then return a.future_growth>b.future_growth end
      -- A higher overkill number is not an improvement. This also ensures an
      -- unchanged order wins every tie, avoiding pointless rearrangement loops.
      return false
    end
    if a.score~=b.score then return a.score>b.score end
    if a.expected_dollars~=b.expected_dollars then return a.expected_dollars>b.expected_dollars end
    return false
  end
  local baseline,best,best_order
  for order_index,order in ipairs(candidates) do
    -- Refuse to start an order unless its ENTIRE common subset set fits.
    if diagnostics.evaluations+#selected>budget then diagnostics.truncated=true; break end
    local state=copy(s); state.jokers={}
    for _,i in ipairs(order) do state.jokers[#state.jokers+1]=s.jokers[i] end
    local top
    for _,indices in ipairs(selected) do
      local trace={}
      local scored=scorer.score(state,indices,trace)
      diagnostics.evaluations=diagnostics.evaluations+1
      if scored and scored.legal~=false and type(scored.score)=='number' then
        local play=copy(scored); play.indices=list(indices)
        play.arm_cost=arm_cost(play.hand); play.expected_dollars=num(play.expected_dollars)
        play.future_loss,play.future_growth=future_metrics(state,play,trace)
        if better(play,top) then top=play end
      end
      if yield_fn and diagnostics.evaluations%32==0 then yield_fn(diagnostics.evaluations) end
    end
    diagnostics.completed_orders=diagnostics.completed_orders+1
    if order_index==1 then baseline=top; best=top
    elseif better(top,best) then best,best_order=top,order end
  end
  if not baseline or not best or not best_order then return skip('The current order is at least as useful as the completed alternatives.') end
  local item=base.consumable and (base.consumable.sequence and base.consumable.sequence.play or base.consumable.play)
  if base.kind=='discard' and best.score<needed then return skip('Keep the discard plan; order changes do not produce an immediate clear.') end
  if item and num(item.score)>=needed and best.score<needed then return skip('The consumable already offers a clear; no distracting non-clearing reorder.') end
  if item and num(item.score)>=needed and best.score>=needed and arm and item.arm_cost~=nil and best.arm_cost>item.arm_cost then
    return skip('The consumable clear preserves a more valuable hand against The Arm.')
  end
  local generator=base.consumable and base.consumable.generator
  if generator and generator.public_replan and num(generator.complete_ordered_plays)>0 and
      num(generator.immediate_ceiling,math.huge)<needed and best.score<needed then
    -- The generator already certified every supported played/Joker order.
    -- A merely losing score is insufficient: another played-card order or
    -- random upside could otherwise rescue after this Joker rearrangement.
    return skip('Every supported immediate order still misses the target; reveal the owned generator before rearranging.')
  end
  if best.score<needed then
    local reference=math.max(baseline.score,num(item and item.score))
    local minimum=math.max(2,math.min(needed*0.02,math.max(1,reference)*num(options.min_relative_gain,0.05)))
    if best.score-reference<minimum then return skip('The modeled gain is too small to justify another manual step.') end
  elseif baseline.score>=needed and arm and (best.arm_cost==math.huge or baseline.arm_cost==math.huge) and best.hand~=baseline.hand then
    return skip('Unknown Arm hand costs prevent a safe comparison of these clears.')
  end
  local lines={format_order(s,best_order),
    'Then reassess the hand: '..best.hand..' estimates ~'..math.floor(best.score+0.5)..' chips (current order ~'..math.floor(baseline.score+0.5)..').',
    'Move the Jokers into this left-to-right order first; refresh advice before selecting or playing cards.'}
  if item and num(item.score)>=needed and best.score>=needed and baseline.score<needed then
    lines[#lines+1]='This order reaches the modeled target without spending the proposed consumable.'
  elseif arm and best.arm_cost<baseline.arm_cost then
    lines[#lines+1]='This clear preserves more future hand value against The Arm.'
  elseif best.future_growth>baseline.future_growth and baseline.score>=needed then
    lines[#lines+1]='Both orders clear; this one produces more modeled permanent Joker growth.'
  end
  if best.expected_dollars>baseline.expected_dollars then
    lines[#lines+1]='Expected immediate income improves by $'..tostring(best.expected_dollars-baseline.expected_dollars)..'.'
  end
  lines[#lines+1]=tostring(diagnostics.completed_orders)..' completed order comparisons; '..
    (diagnostics.truncated and 'bounded coverage, not an exhaustive optimum.' or 'all movable Joker permutations and legal hand subsets compared.')
  local suggestion={kind='reorder_jokers',title='Reorder Jokers before playing',lines=lines,warnings=list(best.warnings),
    action={kind='reorder_jokers',order=list(best_order)},play=best,projected_play=best,baseline_play=baseline,
    supersedes_consumable=item~=nil and best.legal~=false and best.score>=needed or nil}
  diagnostics.reason='A completed order comparison improves this decision.'
  return suggestion,diagnostics.evaluations,diagnostics
end

return M
