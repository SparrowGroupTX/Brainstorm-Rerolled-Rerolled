-- Phase-specific copying, detached from game callbacks and RNG. Reordering is
-- the actual first action; every irreversible action requires fresh advice.
local M={}
local function num(v,d) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge and v or (d or 0) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function shallow(v) local r={};for k,x in pairs(v or {}) do r[k]=x end;return r end
local function list(v) local r={};for i,x in ipairs(v or {}) do r[i]=x end;return r end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function name(j) return (j.ability or {}).name or j.name or j.key end
local function weight(modules,key,default)
  return modules.policy_weights and modules.policy_weights.get and num(modules.policy_weights.get(key),default) or default
end
local function active(j)
  local a=j.ability or {}
  return not j.debuff and not a.perma_debuff and not (a.perishable and num(a.perish_tally,5)<=0)
end
local function pinned(j) return j.pinned or (j.ability or {}).pinned end
local function copying(j) return j.key=='j_blueprint' or j.key=='j_brainstorm' end
local function identity(s) local r={};for i=1,#s.jokers do r[i]=i end;return r end
local function reorder(s,order)
  local r=shallow(s);r.jokers={};for i,j in ipairs(order) do r.jokers[i]=s.jokers[j] end;return r
end
local function restore(s,from,to)
  if #s.jokers~=#from then return nil end
  local originals={};for i,j in ipairs(from) do originals[j]=s.jokers[i] end
  local r=shallow(s);r.jokers={};for i,j in ipairs(to) do r.jokers[i]=originals[j] end;return r
end
local function resolve(row,index,seen)
  local j=row[index]
  if not j or not active(j) or seen[index] then return nil end
  seen[index]=true
  if j.key=='j_blueprint' then return resolve(row,index+1,seen) end
  if j.key=='j_brainstorm' then return resolve(row,1,seen) end
  return index
end
local function effects(s,target,physical_id)
  local count=0
  for i in ipairs(s.jokers) do local resolved=resolve(s.jokers,i,{})
    if resolved and s.jokers[resolved].key==target and
        (physical_id==nil or s.jokers[resolved].id==physical_id) then count=count+1 end
  end
  return count
end
local function valid(s,order)
  if #order~=#s.jokers then return false end
  local seen={}
  for position,index in ipairs(order) do
    if not s.jokers[index] or seen[index] or pinned(s.jokers[index]) and position~=index then return false end
    seen[index]=true
  end
  -- Even a shop arrangement must not expose a different owned Joker to Dagger
  -- when the next blind begins. Eternal neighbours block the sacrifice.
  local function victims(sequence)
    local result={}
    for position,index in ipairs(sequence) do
      local actor=s.jokers[index];local victim=sequence[position+1]
      if actor.key=='j_ceremonial' and active(actor) then
        result[index]=victim and not (s.jokers[victim].ability or {}).eternal and victim or false
      end
    end
    return result
  end
  return equal(victims(identity(s)),victims(order))
end
local function available(s,modules)
  if #(s.jokers or {})<2 or #s.jokers>8 then return false,'Copy setup is bounded to two through eight Jokers.' end
  if s.ordering_safe==false or s.jokers_shuffling or (s.blind or {}).shuffle_pending then return false,'Wait until Joker movement is complete.' end
  local b=s.blind or {}
  if s.phase=='hand' and not b.disabled and (b.key=='bl_final_acorn' or b.name=='Amber Acorn') then return false,'Hidden or shuffled orders cannot support copy setup.' end
  if not modules.gold_stickers or not modules.gold_stickers.target_keys then return false,'The vanilla Joker identity registry is unavailable.' end
  local known={};for _,key in ipairs(modules.gold_stickers.target_keys()) do known[key]=true end
  local copies=0
  for _,j in ipairs(s.jokers) do
    if not known[j.key] then return false,'Unknown Joker callbacks prevent phase-specific setup.' end
    if j.face_down or j.facing=='back' or j.getting_sliced or j.unknown then return false,'The whole Joker row must be visible and settled.' end
    if copying(j) and active(j) then copies=copies+1 end
  end
  return copies>0,copies>0 and nil or 'No active copying Joker.'
end
local function target_order(s,target,physical_id)
  local original=identity(s);local candidates,seen={},{}
  local function add(order)
    local signature=table.concat(order,',')
    if not seen[signature] and #candidates<64 and valid(s,order) then
      seen[signature]=true;candidates[#candidates+1]=order
    end
  end
  add(original)
  -- Blueprint chains terminate at the target; Brainstorms then point back
  -- through that same chain. This works for either copy Joker or both together.
  for target_index,j in ipairs(s.jokers) do if j.key==target and active(j) and
      (physical_id==nil or j.id==physical_id) then
    local order,used={},{}
    local function put(index) order[#order+1]=index;used[index]=true end
    for i,c in ipairs(s.jokers) do if c.key=='j_blueprint' and active(c) then put(i) end end
    put(target_index)
    for i,c in ipairs(s.jokers) do if c.key=='j_brainstorm' and active(c) then put(i) end end
    for i in ipairs(s.jokers) do if not used[i] then put(i) end end
    add(order)
    -- Pinned rows may need a smaller move instead of the complete chain.
    for position=1,#s.jokers do
      local swap=list(original);swap[position],swap[target_index]=swap[target_index],swap[position];add(swap)
    end
  end end
  for i=1,#s.jokers do for j=i+1,#s.jokers do
    local order=list(original);order[i],order[j]=order[j],order[i];add(order)
  end end
  local best,best_count,best_moves=original,effects(s,target,physical_id),0
  for _,order in ipairs(candidates) do
    local count,moves=effects(reorder(s,order),target,physical_id),0
    for i,j in ipairs(order) do if i~=j then moves=moves+1 end end
    if count>best_count or count==best_count and moves<best_moves then best,best_count,best_moves=order,count,moves end
  end
  return best,best_count,#candidates
end
local function order_text(s,order)
  local names={};for _,index in ipairs(order) do names[#names+1]='#'..index..' '..name(s.jokers[index]) end
  return table.concat(names,' -> ')
end
local function suggestion(s,order,title,lines,proof)
  table.insert(lines,1,order_text(s,order))
  lines[#lines+1]='Reorder first, then refresh advice before taking the next action.'
  return {kind='reorder_jokers',title=title,lines=lines,warnings={},
    action={kind='reorder_jokers',area='jokers',order=list(order)},needs_refresh=true,phase_copy=proof}
end
local function shop(s,modules,base,d)
  if not base.action or base.action.kind~='leave_shop' then return nil end
  d.scope='shop_perkeo'
  if #(s.consumeables or {})==0 then d.reason='Perkeo has no copying inventory.';return nil end
  local before=effects(s,'j_perkeo')
  local order,after,count=target_order(s,'j_perkeo');d.orders=count
  d.events_before=before;d.events_after=after
  if after<=before then d.reason='No legal shortlisted order adds a Perkeo copy event.';return nil end
  if not modules.strategy or not modules.strategy.inventory_value or not modules.strategy.build_profile then d.reason='The whole-inventory copying comparison is unavailable.';return nil end
  -- This is the immediate exit, including the final pre-boss shop. A zero
  -- future-shop horizon must not erase copies that are created right now.
  local profile=shallow(modules.strategy.build_profile(s));profile.horizon=math.max(1,num(profile.horizon))
  local original,old_info=modules.strategy.inventory_value(s,nil,{events=before,profile=profile,immediate_exit=true})
  local changed=reorder(s,order)
  local improved,info=modules.strategy.inventory_value(changed,nil,{events=after,profile=profile,immediate_exit=true})
  if not old_info or not info or old_info.approximate or info.approximate or
      old_info.events~=before or info.events~=after or old_info.valuation~='exact_immediate_urn' or
      info.valuation~='exact_immediate_urn' then d.reason='The exact immediate whole-inventory comparison is unavailable.';return nil end
  d.valuation=info.valuation;d.inventory_value_gain=improved-original
  local tied=math.abs(improved-original)<=0.000001
  if improved<original-0.000001 or tied and s.teacher_profile~='perkeo_yorick_win_v1' then
    d.reason='Extra copying has no qualified positive inventory value.';return nil
  end
  -- Stock caps express a bounded planning preference, not that another free
  -- Negative card is harmful or literally unusable. In win-first mode prefer
  -- the extra options on an exact utility tie. Reordering costs no cash or
  -- owned card; the existing pinned/Dagger and fresh-advice guards still apply.
  d.inventory_value_tie=tied
  d.complete=true;d.scope='shop_perkeo';d.events_before=before;d.events_after=after
  d.inventory_before=#s.consumeables;d.inventory_after=#s.consumeables;d.inventory_value_gain=improved-original
  d.proof='The same whole inventory and cash gain more Perkeo copy events without reducing the bounded expected inventory utility; all cards remain physically owned.'
  return suggestion(s,order,'Copy Perkeo before leaving the shop',{
    'This changes the next shop exit from '..before..' to '..after..' Perkeo copy events.',
    'All held consumables, including Negative cards, remain in the copying pool. Their identities are still random.'},d)
end
local function indices_for(s,base)
  local out,seen={},{}
  local function add(indices)
    if not indices or #indices==0 or #indices>5 or #out>=3 then return end
    local chosen={}
    for _,index in ipairs(indices) do if not s.hand[index] or chosen[index] then return end;chosen[index]=true end
    for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not chosen[i] then return end end
    local key=table.concat(indices,',');if not seen[key] then seen[key]=true;out[#out+1]=list(indices) end
  end
  add(base.ordering and base.ordering.play and base.ordering.play.indices or base.play and base.play.indices)
  -- The earlier Burnt order may hide a cheap winning singleton from the main
  -- search. Include one high card and one distinct displayed alternative.
  local high
  for i,c in ipairs(s.hand) do if not high or num(c.nominal,num(c.rank))>num(s.hand[high].nominal,num(s.hand[high].rank)) then high=i end end
  if high then add({high}) end
  for _,play in ipairs(base.alternatives or {}) do add(play.indices) end
  return out
end
local function reliable(play) return play and play.legal~=false and play.uncertain~=true and type(play.score)=='number' end
-- Reserve existing work before search, including when Burnt is already copied:
-- that row still needs the retained-finish proof before actually discarding.
function M.comparison_reserve(s,modules,options)
  local round=s.current_round or {}
  if s.phase~='hand' or s.teacher_profile~='perkeo_yorick_win_v1' or
      num(s.discards_used,round.discards_used)~=0 or num(s.discards_left,round.discards_left)<=0 or
      not modules.growth or not modules.scoring or not modules.scoring.after_discard or not modules.scoring.score or
      not modules.strategy or not modules.strategy.build_profile or not modules.search or not modules.search.hand_growth_value or
      not available(s,modules) then return 0 end
  local _,after=target_order(s,'j_burnt')
  if after<2 then return 0 end
  -- At most three held subsets in two scoring orders, plus twelve growth calls.
  local cap=math.max(0,math.floor(num((options or {}).max_evaluations,30)))
  return cap>=13 and math.min(18,cap) or 0
end
local function burnt(s,modules,base,cap,d)
  if base.growth and base.growth.growth and base.growth.growth.kind=='burnt_setup' then return nil,0 end
  -- A selected independent scoring order can supersede an earlier item
  -- proposal. Keep necessary uses protected, but do not let an unselected
  -- proposal veto the fresh Burnt discard and cause an order oscillation.
  local superseded=base.ordering and base.ordering.supersedes_consumable==true and
    base.action==base.ordering.action and base.action.kind=='reorder_jokers'
  if not base.action or (base.action.kind~='play' and base.action.kind~='discard' and
      not (base.action.kind=='reorder_jokers' and base.ordering)) or
      base.consumable and not superseded or base.mixed_rescue or base.boss_rescue or base.hand_ordering then return nil,0 end
  local round=s.current_round or {}
  if num(s.discards_used,round.discards_used)~=0 or num(s.discards_left,round.discards_left)<=0 then return nil,0 end
  if not modules.growth or not modules.scoring or not modules.scoring.after_discard or not modules.scoring.score or
      not modules.strategy or not modules.strategy.build_profile or not modules.search or not modules.search.hand_growth_value then return nil,0 end
  local burnt_order,after,count=target_order(s,'j_burnt');d.orders=count
  if after<2 then return nil,0 end
  d.scope='first_discard_burnt'
  local original=identity(s);local scoring_orders={original};local yorick=target_order(s,'j_yorick')
  if not equal(yorick,original) then scoring_orders[#scoring_orders+1]=yorick end
  local selected=indices_for(s,base)
  local scoring_cost=#selected*#scoring_orders
  local growth_remaining=math.max(0,12-num(base.discard_preference_work))
  d.growth_remaining=growth_remaining;d.required_evaluations=scoring_cost+growth_remaining
  -- Finish every admitted order on exactly the same held subsets, retaining
  -- the existing twelve-score growth allowance as a whole afterward.
  if #selected==0 or growth_remaining==0 or cap<d.required_evaluations then d.reason='No budget for the complete paired order and retained-clear comparison.';return nil,0 end
  local scored,best,best_order=0,nil,nil
  -- Match Growth's exact retained-finish floor before considering copy setup.
  local exhaust=s.teacher_profile=='perkeo_yorick_win_v1'
  local needed=math.max(1,num((s.blind or {}).chips)-num(s.chips))*(exhaust and 1 or 1.05)
  for _,order in ipairs(scoring_orders) do
    local state=reorder(s,order)
    for _,indices in ipairs(selected) do
      local play=modules.scoring.score(state,indices);scored=scored+1
      if reliable(play) and play.score>=needed then
        local cost=num(play.glass_loss)
        if not best or cost<num(best.glass_loss) or cost==num(best.glass_loss) and #indices<#best.indices then
          best=shallow(play);best.indices=list(indices);best_order=order
        end
      end
    end
  end
  if not best then d.reason='No supported held clear for a reversible Burnt setup.';return nil,scored end
  local prepared=reorder(s,burnt_order)
  local proxy=setmetatable({}, {__index=modules.scoring})
  -- Model the discard in the Burnt order, then restore only the Joker row for
  -- its reserved finish. Actual play still waits for a separate fresh reorder.
  proxy.score=function(state,indices)
    local ready=restore(state,burnt_order,best_order)
    if not ready then return nil end
    return modules.scoring.score(ready,indices)
  end
  proxy.lower_bound=function(state,indices)
    local ready=restore(state,burnt_order,best_order)
    if not ready then return nil end
    return (modules.scoring.lower_bound or modules.scoring.score)(ready,indices)
  end
  local scoped=shallow(modules);scoped.scoring=proxy
  local growth,work,gd=modules.growth.suggest(prepared,scoped,best,
    {max_evaluations=growth_remaining,exhaust_discards=exhaust,setup_scoring=modules.scoring})
  scored=scored+num(work)
  d.growth_work=num(work)
  d.growth=gd
  if growth and growth.action.kind=='play' and growth.growth and growth.growth.kind=='burnt_setup' then
    d.complete=true;d.scope='nonwinning_burnt_setup';d.finish_order=list(best_order)
    d.retained_finish=copy(growth.play);d.setup_indices=list(growth.action.indices)
    d.burnt_preparation=copy(growth.growth.burnt_preparation);d.score_calls=scored
    d.proof='Actual setup scoring uses the Burnt arrangement; a separate legal scoring restoration retains an independent finish without assuming a draw.'
    if not equal(burnt_order,original) then
      return suggestion(s,burnt_order,'Move copies off Yorick before the non-winning setup',{
        'This arrangement copies Burnt and keeps the proposed spare play below the current blind target.',
        'The held finish was checked in a separately legal scoring order. Refresh after each reorder, play and discard.'},d),scored
    end
    growth.phase_copy=d;growth.needs_refresh=true
    return growth,scored
  end
  if not growth or growth.action.kind~='discard' then return nil,scored end
  if base.action.kind=='discard' and #growth.action.indices<#(base.action.indices or {}) then
    d.reason='Copying Burnt cannot reduce the selected discard volume.';return nil,scored
  end
  local before_state,before_effects=modules.scoring.after_discard(s,growth.action.indices)
  local after_state,after_effects=modules.scoring.after_discard(prepared,growth.action.indices)
  if not before_state or not after_state then d.reason='Discard effects are not supported in both orders.';return nil,scored end
  after_state=restore(after_state,burnt_order,original)
  if not after_state or after_effects.burnt_hand~=before_effects.burnt_hand then return nil,scored end
  local hand=after_effects.burnt_hand
  local before_hand,after_hand=before_state.hands[hand],after_state.hands[hand]
  local extra=after_effects.burnt_levels-before_effects.burnt_levels
  if extra<0 or not before_hand or not after_hand or
      after_hand.level~=before_hand.level+extra or after_hand.chips<before_hand.chips or after_hand.mult<before_hand.mult then return nil,scored end
  -- Require byte-structural equality everywhere except the exact leveled hand.
  -- Copying Mail/Faceless less, changing physical Yorick growth, destruction,
  -- consumables, Blue generation, cash, or a different population all reject.
  local normalized=shallow(after_state);normalized.hands=shallow(after_state.hands);normalized.hands[hand]=before_hand
  if not equal(normalized,before_state) then d.reason='Another discard resource or physical Joker effect changes with this setup.';return nil,scored end
  local moves=(equal(burnt_order,original) and 0 or 1)+(equal(burnt_order,best_order) and 0 or 1)
  local action_cost=math.max(0,weight(modules,'growth_action_cost',4))*moves
  if not exhaust and num(growth.merit)<=action_cost then d.reason='The growth does not justify the extra arrangement actions.';return nil,scored end
  if extra>0 then
    local profile=modules.strategy.build_profile(s)
    local incremental=10*modules.search.hand_growth_value(s,hand,profile)*extra*math.min(1,num(profile.horizon)/3)*weight(modules,'growth_utility_scale',1)
    if not exhaust and incremental<=action_cost then d.reason='The extra Burnt levels do not justify rearranging twice.';return nil,scored end
    d.incremental_growth_utility=incremental
  end
  d.complete=true;d.scope='first_discard_burnt';d.events_before=before_effects.burnt_levels
  d.events_after=after_effects.burnt_levels;d.burnt_hand=hand;d.discard_indices=list(growth.action.indices)
  d.finish_order=list(best_order);d.retained_finish=copy(growth.play);d.score_calls=scored
  d.extra_arrangement_actions=moves;d.action_utility_cost=action_cost;d.calibrated=false
  d.proof='Exact same-card discard transitions agree in every other field after restoring physical Joker order; the retained cards clear without favorable replacement draws.'
  if not equal(burnt_order,original) then
    return suggestion(s,burnt_order,'Copy Burnt Joker before the first discard',{
      'The supported '..hand..' discard gains '..after_effects.burnt_levels..' levels instead of '..before_effects.burnt_levels..'.',
      'A separately verified scoring order keeps a finish from cards already held. Scoring order is restored only after fresh advice.'},d),scored
  end
  -- Already in the correct Burnt order: actually discard now instead of
  -- bouncing back to the scoring order and losing the first-discard upgrade.
  growth.phase_copy=d;growth.needs_refresh=true
  growth.lines[#growth.lines+1]='Burnt is already copied. After the discard, refresh advice to restore a useful scoring order before playing.'
  return growth,scored
end
local function restore_yorick(s,modules,base,cap,d)
  if s.teacher_profile~='perkeo_yorick_win_v1' or num(s.discards_used,(s.current_round or {}).discards_used)<=0 or
      not base.action or (base.action.kind~='play' and base.action.kind~='discard') or
      not modules.scoring or not modules.scoring.after_play or cap<2 then return nil,0 end
  for _,j in ipairs(s.jokers) do if not ({j_yorick=true,j_perkeo=true,j_burnt=true,j_blueprint=true,j_brainstorm=true})[j.key] then return nil,0 end end
  local order,count=target_order(s,'j_yorick');local before_count=effects(s,'j_yorick')
  if count<=before_count then return nil,0 end
  local indices=base.action.kind=='play' and base.action.indices or base.play and base.play.indices
  if not indices or #indices==0 then return nil,0 end
  local before,be,bp=modules.scoring.after_play(s,indices)
  local after,ae,ap=modules.scoring.after_play(reorder(s,order),indices)
  local function exact(play)
    return reliable(play) and play.legal==true and play.uncertain==false and
      play.score==play.score and play.score>=0 and play.score<math.huge
  end
  if not before or not after or not exact(bp) or not exact(ap) or ap.score<=bp.score then return nil,2 end
  after=restore(after,order,identity(s));if not after then return nil,2 end
  after.chips=before.chips
  if not equal(before,after) or not equal(be,ae) then d.reason='Scoring restoration changes non-score play resources.';return nil,2 end
  if base.action.kind=='discard' then
    local left,le=modules.scoring.after_discard(s,base.action.indices)
    local right,re=modules.scoring.after_discard(reorder(s,order),base.action.indices)
    right=right and restore(right,order,identity(s))
    if not left or not right or not equal(left,right) or not equal(le,re) then return nil,2 end
  end
  d.complete=true;d.scope='restore_yorick_after_first_discard';d.events_before=before_count;d.events_after=count
  d.score_before=bp.score;d.score_after=ap.score;d.score_calls=2
  d.proof='The same actual play gains score; complete paired after-play states and effects agree after normalizing only scored chips and physical Joker order.'
  return suggestion(s,order,'Restore Yorick copies after the first discard',{
    'Burnt has already triggered. Restore the stronger scoring arrangement before reassessing the next discard or play.',
    'The same held play improves without changing its modeled cash, inventory, population or other non-score effects.'},d),2
end
function M.suggest(s,modules,base,options)
  options=options or {};base=base or {}
  local d={complete=false,score_calls=0,bounded=true,needs_refresh=true}
  if s.phase=='shop' and base.action and base.action.kind=='leave_shop' then d.scope='shop_perkeo' end
  local ok,why=available(s,modules)
  if not ok then d.reason=why;return nil,0,d end
  if s.phase=='shop' then local result=shop(s,modules,base,d);return result,0,d end
  if s.phase~='hand' then return nil,0,d end
  local cap=math.max(0,math.min(30,math.floor(num(options.max_evaluations,0))))
  local restored,restoration_work=restore_yorick(s,modules,base,cap,d)
  if restored or restoration_work>0 then d.score_calls=restoration_work;d.max_evaluations=cap;return restored,restoration_work,d end
  local result,work=burnt(s,modules,base,cap,d);d.score_calls=work or 0;d.max_evaluations=cap
  return result,work or 0,d
end
-- Called once after the shared decision has chosen its complete incumbent and
-- before retry arbitration. It spends only the unused current decision budget;
-- existing search limits and earlier specialist work are never expanded.
function M.apply(s,modules,result,options)
  if not result or not result.action then return result end
  options=options or {}
  -- Later enumeration clears carry clear_shortcut, and retain the ordinary
  -- allowance; only the initial shortlist carries the fast_clear contract.
  local ceiling=result.fast_clear and 70 or s.phase=='shop' and 50000 or 140000
  ceiling=math.min(ceiling,num(result.aggregate_limit,ceiling))
  local remaining=math.max(0,ceiling-num(result.evaluations))
  local cap=math.min(30,remaining,math.max(0,num(options.max_evaluations,30)))
  local proposal,work,diagnostics=M.suggest(s,modules,result,{max_evaluations=cap})
  local updated=shallow(result)
  updated.evaluations=num(result.evaluations)+num(work)
  updated.discard_preference_work=num(result.discard_preference_work)+num(diagnostics.growth_work)
  diagnostics.aggregate_limit=ceiling;diagnostics.remaining_before=remaining
  diagnostics.reserved_evaluations=num(result.phase_copy_reserved_evaluations)
  updated.phase_copy_diagnostics=diagnostics
  if not proposal then return updated end
  updated.phase_copy=proposal.phase_copy;updated.action=proposal.action
  updated.phase_copy_incumbent={kind=result.kind,action=copy(result.action),evaluations=result.evaluations}
  if s.phase=='shop' then updated.strategy=proposal
  else
    for _,field in ipairs({'ordering','growth','two_hand_finish','multi_discard','discard','resource_comparison','consumable'}) do updated[field]=nil end
    if proposal.action.kind=='reorder_jokers' then updated.ordering=proposal
    else updated.growth=proposal;updated.kind=proposal.action.kind end
  end
  return updated
end
M.reorder=reorder
M.copy_effects=effects
M.target_order=target_order

-- The concealed route supplies public observations and conditioned worlds.
-- No raw hidden identity is read here, and a different action is never chosen
-- inside a world. This compares actual arrangements, not promised future moves.
function M.concealed_order(s,modules,worlds,incumbent,context)
  local d={schema=1,complete=false,scope='concealed_fixed_play_public_copy_order_v1',
    fixed_slots=true,sampled=true,terminal_evidence=false,extra_setup_actions=1,rows={}}
  local function no(reason) d.reason=reason;return nil,d end
  local ok,why=available(s,modules)
  if not ok then return no(why) end
  if s.phase~='hand' or not incumbent or not incumbent.indices or not context or
      type(context.after_play)~='function' or #worlds<4 or #worlds>32 then
    return no('A complete concealed incumbent and its conditioned worlds are required.')
  end
  if not modules.finish_rewards or type(modules.finish_rewards.prepare)~='function' then
    return no('The held Gold/Blue cashout retrigger model is required for order conservation.')
  end
  local ids={}
  for _,j in ipairs(s.jokers) do
    local a=j.ability
    local valid_id=type(j.id)=='string' and j.id~='' or type(j.id)=='number' and j.id==j.id and math.abs(j.id)<math.huge
    if not valid_id or ids[tostring(j.id)] or type(a)~='table' or type(j.debuff)~='boolean' or
        type(j.blueprint_compat)~='boolean' or j.identity_redacted or j.concealed then
      return no('Distinct physical Joker IDs and exact public activity/copy metadata are required.')
    end
    ids[tostring(j.id)]=true
    for _,value in ipairs({{j,'pinned'},{a,'pinned'},{a,'perishable'},{a,'perma_debuff'}})do
      if value[1][value[2]]~=nil and type(value[1][value[2]])~='boolean' then
        return no('Unknown pin or activity metadata prevents a public order comparison.')
      end
    end
    if a.perishable and (type(a.perish_tally)~='number' or a.perish_tally~=a.perish_tally or
        math.abs(a.perish_tally)==math.huge or a.perish_tally%1~=0) then
      return no('Unknown perish timing prevents a public order comparison.')
    end
  end
  if incumbent.clear_count==#worlds then return no('The current fixed play already clears every compared world.') end
  local candidates,seen={},{}
  local function add(order)
    local key=table.concat(order,',')
    if not seen[key] then seen[key]=true;candidates[#candidates+1]=list(order) end
  end
  add(identity(s))
  local targets={}
  for i,j in ipairs(s.jokers) do
    if active(j) and not copying(j) and j.blueprint_compat==true then targets[#targets+1]=i end
  end
  table.sort(targets,function(a,b)
    local x,y=s.jokers[a],s.jokers[b]
    local ka,kb=tostring(x.id or x.key),tostring(y.id or y.key)
    return ka==kb and a<b or ka<kb
  end)
  for _,i in ipairs(targets) do local order=target_order(s,s.jokers[i].key,s.jokers[i].id);add(order) end
  d.worlds=#worlds;d.candidate_rows=#candidates;d.required_score_calls=#candidates*#worlds
  if #candidates<2 then return no('No different supported copy arrangement is available.') end
  if d.required_score_calls>num(context.remaining) then return no('The entire public order family does not fit the remaining concealed allowance.') end
  local target=math.max(0,num((s.blind or {}).chips)-num(s.chips))
  local baselines,best={},nil
  local function reliable(p)
    return p and p.legal==true and p.uncertain==false and type(p.score)=='number' and
      p.score==p.score and p.score>=0 and p.score<math.huge
  end
  local function near(a,b)return math.abs(a-b)<=1e-8*math.max(1,math.abs(a),math.abs(b))end
  for row_index,order in ipairs(candidates) do
    local row={order=list(order),mean=0,clipped_mean=0,clear_count=0,eligible=true}
    d.rows[#d.rows+1]=row
    for world_index,world in ipairs(worlds) do
      -- Glass outcomes, where available, use the existing private common-world
      -- stream. Unsupported Lucky/copy or other random transitions still fail.
      local transition={};local ordered=reorder(world,order)
      if modules.sampled_outcomes and modules.sampled_outcomes.context then
        transition=modules.sampled_outcomes.context(ordered,incumbent.indices,context.seed+world_index*104729,1,nil,modules.scoring)
      end
      local after,effects,play=context.after_play(ordered,incumbent.indices,transition)
      if not after or not reliable(play) then return no('A complete paired order transition has unsupported scoring or resources.') end
      if #after.jokers~=#order then return no('A paired play changes physical Joker membership.') end
      -- Mime/copy expiration happens before held Gold and Blue processing.
      -- Equal post-play cards alone cannot prove equal cashout retriggers.
      local finish=modules.finish_rewards.prepare(after)
      if not finish or type(finish.mimes)~='number' then return no('Held-card cashout copy counts are unsupported.') end
      local restored={};for position,index in ipairs(order) do restored[index]=after.jokers[position] end
      after.jokers=restored
      row.mean=row.mean+play.score/#worlds;row.clipped_mean=row.clipped_mean+math.min(target,play.score)/#worlds
      row.clear_count=row.clear_count+(play.score>=target and 1 or 0)
      if row_index==1 then baselines[world_index]={state=after,effects=effects,play=play,mimes=finish.mimes}
      else
        local baseline=baselines[world_index]
        after.chips=baseline.state.chips
        if finish.mimes~=baseline.mimes or play.score<baseline.play.score or play.hand~=baseline.play.hand or
            not equal(play.scoring_indices,baseline.play.scoring_indices) or
            not equal(after,baseline.state) or not equal(effects,baseline.effects) then
          row.eligible=false;row.reason='This order loses a compared score or changes non-score resources.'
        end
      end
    end
    if row_index==1 then
      if not near(row.mean,incumbent.mean) or not near(row.clipped_mean,incumbent.clipped_mean) or
          row.clear_count~=incumbent.clear_count then return no('The paired current row does not reproduce the completed fixed-play comparison.') end
      best=row
    elseif row.eligible and (row.clear_count>best.clear_count or row.clear_count==best.clear_count and
        row.clipped_mean>best.clipped_mean+math.max(1,0.05*best.clipped_mean)) then best=row end
  end
  d.complete=true
  if best==d.rows[1] then return no('The current row is at least as useful as the complete admissible order family.') end
  d.selected_order=list(best.order);d.fixed_indices=list(incumbent.indices)
  d.reason='One actual reorder improves the same fixed play without losing any compared world or changing its non-score resources.'
  d.resource_scope='Complete paired after_play states and effects normalize only physical Joker order and scored chips, preserving expiry-aware Mime cashout counts; future draws and other cashout awards are not forecast.'
  return suggestion(s,best.order,'Reorder known Jokers before the concealed play',{
    'The same selected slots improve across the complete compared public-order family.',
    'Cash, inventory, population and other supported play effects agree in every paired world.',
    'Hidden cards remain unknown. These conditioned samples are not a guaranteed clear or win probability.'},d),d
end
return M
