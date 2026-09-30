-- Compare the order of one chosen played-card set. Unselected cards stay in
-- their exact hand slots, preserving held-card order and the planned discard set.
-- No live card, game callback, or random generator is accessed here.
local M={}
local function num(value,default) return type(value)=='number' and value or (default or 0) end
local function copy(value) local out={};for key,item in pairs(value or {}) do out[key]=item end;return out end
local function list(value) local out={};for i,item in ipairs(value or {}) do out[i]=item end;return out end
local function finite(value) return type(value)=='number' and value==value and value<math.huge and value>-math.huge end
local function pinned(card) return card.pinned or (card.ability or {}).pinned end
local function chosen_indices(hand,indices)
  if type(indices)~='table' or #indices<2 or #indices>5 then return nil end
  local selected,seen={},{}
  for key in pairs(indices) do
    if type(key)~='number' or key%1~=0 or key<1 or key>#indices then return nil end
  end
  for _,index in ipairs(indices) do
    if type(index)~='number' or index%1~=0 or not hand[index] or seen[index] then return nil end
    selected[#selected+1]=index;seen[index]=true
  end
  for index,card in ipairs(hand) do
    if (card.ability or {}).forced_selection and not seen[index] then return nil end
  end
  table.sort(selected) -- The source sorts selected cards by physical left/right order.
  return selected
end
local function projected(snapshot,free,values)
  local state=copy(snapshot);state.hand=list(snapshot.hand)
  for i,position in ipairs(free) do state.hand[position]=snapshot.hand[values[i]] end
  return state
end

function M.suggest(snapshot,scorer,result,yield_fn,options)
  local s,base=snapshot or {},result or {};options=options or {}
  local diagnostics={evaluations=0,completed_orders=0,partial_orders=0,truncated=false,warnings={}}
  local function skip(reason) diagnostics.reason=reason;return nil,diagnostics.evaluations,diagnostics end
  if s.phase and s.phase~='hand' then return skip('Played-card order is evaluated at a settled hand decision.') end
  if not scorer or type(scorer.score)~='function' or not base.play then return skip('There is no chosen play to reorder.') end
  local hand=s.hand or {}
  if #hand>1000 then return skip('The hand is too large for a bounded full-hand rearrangement.') end
  if s.ordering_safe==false or s.hand_ordering_safe==false or s.hand_shuffling or s.jokers_shuffling or
    (s.blind or {}).shuffle_pending then return skip('Wait for card movement to finish before reordering.') end
  local selected=chosen_indices(hand,base.play.indices)
  if not selected then return skip('Reordering needs two to five distinct chosen cards and every forced card.') end
  diagnostics.selected_cards=#selected
  local free={}
  for _,index in ipairs(selected) do
    local card=hand[index]
    if card.face_down or card.facing=='back' then return skip('Reveal the chosen cards before relying on their order.') end
    local drag=card.states and card.states.drag
    if card.draggable==false or card.drag_can==false or (drag and (drag.can==false or drag.is)) then
      return skip('A chosen card cannot be moved right now.')
    end
    if not pinned(card) then free[#free+1]=index end
  end
  if #free<2 then return skip('Pinned chosen cards leave no alternative order.') end
  local possible=1;for i=2,#free do possible=possible*i end
  diagnostics.possible_orders=possible
  local budget=math.max(0,math.min(10000,math.floor(num(options.max_evaluations,10000))))
  local count=math.min(possible,budget,math.max(0,math.min(120,math.floor(num(options.max_orders,120)))))
  if count<2 then return skip('The budget cannot compare the current order with one alternative.') end
  diagnostics.candidate_orders=count;diagnostics.truncated=count<possible
  local blind=s.blind or {}
  local needed=math.max(1,num(blind.chips)-num(s.chips))
  if finite(base.play.score) and base.play.score>=needed then return skip('The chosen play already clears; extra overkill does not justify reordering.') end
  local existing_order=base.ordering and base.ordering.play
  if existing_order and existing_order.legal~=false and not existing_order.uncertain and num(existing_order.score)>=needed then
    return skip('The existing Joker-order plan already clears; preserve its chosen cards and future resources.')
  end
  local arm=not blind.disabled and (blind.key=='bl_arm' or blind.name=='The Arm')
  local baseline,best,best_values
  local values,used={},{}
  local invalid_reason
  local function visit()
    local state=projected(s,free,values)
    local scored=scorer.score(state,selected)
    diagnostics.evaluations=diagnostics.evaluations+1
    diagnostics.completed_orders=diagnostics.completed_orders+1
    if yield_fn and diagnostics.evaluations%32==0 then yield_fn(diagnostics.evaluations) end
    if not scored or scored.legal==false or not finite(scored.score) then
      invalid_reason='The scorer could not verify this chosen-card order.';return
    end
    if scored.uncertain then
      invalid_reason='Uncertain or unsupported scoring effects prevent a reliable order comparison.';return
    end
    local play=copy(scored);play.indices=list(selected)
    if diagnostics.completed_orders==1 then
      if not finite(base.play.score) or play.score~=base.play.score or (base.play.hand and play.hand~=base.play.hand) then
        invalid_reason='The chosen play no longer matches its published score; refresh the recommendation.';return
      end
      play.arm_cost=arm and (options.arm_cost and options.arm_cost(s,play.hand) or base.play.arm_cost) or 0
      baseline,best=play,play
    else
      if play.hand~=baseline.hand then invalid_reason='The scorer changed hand type for the same cards; order advice is withheld.';return end
      play.arm_cost=baseline.arm_cost
      -- Keep the earliest equal order. Once one clears, higher overkill never
      -- causes another rearrangement or a bounce after the next snapshot.
      if best.score<needed and play.score>best.score then best,best_values=play,list(values) end
    end
  end
  local function permute(position)
    if invalid_reason or diagnostics.completed_orders>=count then return end
    if position>#free then visit();return end
    for _,index in ipairs(free) do if not used[index] then
      used[index]=true;values[position]=index;permute(position+1);used[index]=nil
      if invalid_reason or diagnostics.completed_orders>=count then return end
    end end
  end
  permute(1) -- Sorted free positions make identity the first complete comparison.
  if invalid_reason then return skip(invalid_reason) end
  if not best_values or not baseline then return skip('The current played-card order is at least as useful as the compared alternatives.') end
  local consumable=base.consumable and (base.consumable.sequence and base.consumable.sequence.play or base.consumable.play)
  local joker_order=base.ordering and base.ordering.play
  local clears=best.score>=needed
  if base.kind=='discard' and not clears then return skip('Keep the discard plan; this rearrangement does not clear the blind.') end
  local protected={consumable=consumable,joker_order=joker_order}
  for _,key in ipairs({'consumable','joker_order'}) do
    local item=protected[key]
    if item and num(item.score)>=needed then
      if not clears then return skip('The existing consumable or Joker-order plan clears; keep that plan.') end
      if arm and item.arm_cost~=nil and (best.arm_cost==nil or best.arm_cost>item.arm_cost) then
        return skip('The existing clear preserves more hand value against The Arm.')
      end
    end
  end
  if not clears then
    if num(s.hands_left,num((s.current_round or {}).hands_left,1))<=1 then
      return skip('This order still loses on the final hand; it does not provide a rescue.')
    end
    local reference=math.max(baseline.score,num(consumable and consumable.score),num(joker_order and joker_order.score))
    local minimum=math.max(2,math.min(needed*0.02,math.max(1,reference)*math.max(0,num(options.min_relative_gain,0.05))))
    if best.score-reference<minimum then return skip('The gain is too small to improve the existing plan meaningfully.') end
  end
  local order={};for i=1,#hand do order[i]=i end
  for i,position in ipairs(free) do order[position]=best_values[i] end
  local played_order={};for _,position in ipairs(selected) do played_order[#played_order+1]='#'..order[position] end
  local lines={'Put the chosen cards in this left-to-right order: '..table.concat(played_order,' -> ')..'.',
    'Keep the same chosen cards; unselected hand cards stay in their current positions.',
    'After reordering, '..best.hand..' estimates '..tostring(best.score)..' chips (current order '..tostring(baseline.score)..').',
    'Refresh advice before selecting or playing; this action only rearranges the hand.'}
  if clears then lines[#lines+1]='The new order reaches the remaining blind target without spending another consumable or discard.'
  else lines[#lines+1]='The additional score improves progress toward the blind with hands still available.' end
  local warnings={}
  if diagnostics.truncated then warnings[#warnings+1]='Played-card permutations were budget-limited; every reported comparison finished.' end
  warnings[#warnings+1]='Only this chosen card set was reordered; held-card order, other played subsets, and future draws were not searched.'
  diagnostics.reason='A complete comparison found a useful played-card order.'
  return {kind='reorder_hand',title='Reorder the played cards',lines=lines,warnings=warnings,
    action={kind='reorder_hand',area='hand',order=order},play=best,projected_play=best,baseline_play=baseline,
    selected_indices=list(selected)},diagnostics.evaluations,diagnostics
end

return M
