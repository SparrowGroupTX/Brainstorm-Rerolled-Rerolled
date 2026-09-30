-- Do not undo a supported collection acquisition merely to regain surplus
-- score. Compare the complete sale/buy incumbent against holding the inventory
-- in the current row or a bounded explicitly executed copy-target row. Every
-- endpoint holds that physical row fixed; no later reorder is assumed free.
local M={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function integer(x) return finite(x) and x>=0 and x%1==0 end
local function array(x,cap)
  if type(x)~='table' or getmetatable(x) or #x>cap then return false end
  local n=0;for k in pairs(x) do if not integer(k) or k<1 or k>#x then return false end;n=n+1 end
  return n==#x
end
local function copy(x)
  if type(x)~='table' then return x end
  local out={};for k,v in pairs(x) do if k~='_shop_scoring' and k~='_readiness' then out[k]=copy(v) end end;return out
end
local function encode(x,seen)
  local t=type(x)
  if t=='nil' then return 'n' end
  if t=='string' then return 's'..#x..':'..x end
  if t=='boolean' then return x and 'b1' or 'b0' end
  if t=='number' then return finite(x) and 'd'..string.format('%.17g',x)..';' or nil end
  if t~='table' or getmetatable(x) then return nil end
  seen=seen or {};if seen[x] then return nil end;seen[x]=true
  local parts={};for k,v in pairs(x) do if k~='_shop_scoring' and k~='_readiness' then
    local a,b=encode(k,seen),encode(v,seen);if not a or not b then seen[x]=nil;return nil end;parts[#parts+1]=a..b
  end end
  table.sort(parts);seen[x]=nil;return 't'..#parts..':'..table.concat(parts)..'e'
end
local function same_action(a,b)
  return type(a)=='table' and type(b)=='table' and a.kind==b.kind and a.area==b.area and a.index==b.index
end
function M.reserve(s,limit)
  if not integer(limit) or limit==0 or not s or s.phase~='shop' then return 0 end
  local b,g=s.next_blind or {},s.completionist_goal
  local ordinary=({bl_small=true,bl_big=true})[b.key] and b.boss~=true
  local final=({bl_final_vessel=true,bl_final_leaf=true})[b.key] and b.boss==true
  if not integer(s.win_ante) or s.win_ante<1 or s.ante~=s.win_ante or b.ante~=s.win_ante or
      not (ordinary or final) or not finite(b.chips) or b.chips<=0 or not array(s.jokers,6) or
      type(g)~='table' or g.schema~=1 or g.goal~='gold_stickers' or g.metadata_status~='complete' or
      g.catalog_status~='complete' or g.held_status~='complete' or type(g.eligibility)~='table' or
      g.eligibility.eligible~=true or type(g.by_key)~='table' then return 0 end
  for _,j in ipairs(s.jokers) do
    local row=g.by_key[j.key]
    if row and row.status=='missing' then return math.min(limit,8000) end
  end
  return 0
end
function M.suggest(s,modules,base,remaining,yield_fn)
  modules=modules or {}
  local d={complete=false,evaluations=0,comparisons=0,samples=4,margin=1.25,terminal_evidence=false,
    scope='Winning-Ante current or explicit copy-target row hold versus the complete visible sale-first incumbent; all consumables held.'}
  local function no(reason) d.reason=reason;return nil,d.evaluations,d end
  local action=base and base.action
  if not s or s.phase~='shop' or not action or action.kind~='sell' or action.area~='jokers' or
      not integer(action.index) or action.index<1 then return no('No ordinary sale-first Joker action needs retention review.') end
  local b,g=s.next_blind or {},s.completionist_goal
  local ordinary=({bl_small=true,bl_big=true})[b.key] and b.boss~=true
  local final=({bl_final_vessel=true,bl_final_leaf=true})[b.key] and b.boss==true
  if not integer(s.win_ante) or s.win_ante<1 or s.ante~=s.win_ante or b.ante~=s.win_ante or
      not (ordinary or final) or not finite(b.chips) or b.chips<=0 then return no('No supported winning-Ante next blind is available.') end
  if type(g)~='table' or g.schema~=1 or g.goal~='gold_stickers' or g.metadata_status~='complete' or
      g.catalog_status~='complete' or g.held_status~='complete' or type(g.eligibility)~='table' or
      g.eligibility.eligible~=true or type(g.by_key)~='table' then return no('Complete eligible Gold-sticker metadata is required.') end
  local sold=(s.jokers or {})[action.index]
  if not sold or not g.by_key[sold.key] or g.by_key[sold.key].status~='missing' then return no('The incumbent does not sell a missing Joker.') end
  local gold,shop,score=modules.gold_goal,modules.shop_scoring,modules.scoring
  local api=modules.strategy and modules.strategy.shop_sequence_api
  local transition=modules.shop_sequences and modules.shop_sequences.transition
  local liquidity=modules.liquidity or modules.strategy and modules.strategy.liquidity
  if not gold or not gold.stable_card or not gold.validate_inventory_opening or not shop or not shop.new or
      not score or not score.lower_bound or not api or not transition or not liquidity or not liquidity.estimate then
    return no('Supported paid transitions, common worlds and score floors are required.')
  end
  if not array(s.jokers,6) or not array(s.shop_jokers,3) or not array(s.consumeables,64) or
      not array(s.playing_cards,math.huge) or not integer(s.joker_limit) or not integer(s.consumable_limit) or
      s.consumable_limit<#s.consumeables or s.consumeable_buffer~=0 or not finite(s.dollars) or
      not finite(s.bankrupt_at) or s.bankrupt_at>0 or s.ordering_safe==false or s.jokers_shuffling or not encode(s) then
    return no('Settled bounded rows, inventory, capacity, population and cash are required.')
  end
  if not integer(remaining) then return no('An exact finite remaining score allowance is required.') end
  local cap=math.min(50000,remaining);d.max_evaluations=cap
  local actions
  if base.shop_sequence then
    local p=base.shop_sequence
    if p.complete~=true or not array(p.actions,3) or #p.actions<1 or not same_action(p.actions[1],action) then
      return no('The complete ordinary continuation must begin with the proposed sale.')
    end
    actions=p.actions
  elseif action.followup then actions={action,action.followup}
  else return no('The proposed sale lacks a complete declared paid continuation.') end
  if not encode(actions) then return no('The declared paid continuation must contain bounded plain data.') end
  actions=copy(actions)
  if #actions<2 or #actions>3 then return no('Retention requires one sale followed by one or two visible Joker buys.') end
  if action.followup and not same_action(action.followup,actions[2]) then return no('The explicit follow-up disagrees with the complete paid continuation.') end
  for i,a in ipairs(actions) do
    if not integer(a.index) or a.index<1 or i==1 and (a.kind~='sell' or a.area~='jokers') or
        i>1 and (a.kind~='buy' or a.area~='shop_jokers') or a.followup and i>1 then
      return no('The incumbent exceeds the one-sale/two-visible-Joker-buy retention family.')
    end
  end
  local inventory,population=encode(s.consumeables),encode(s.playing_cards)
  local function qualify(state)
    local seen,keys,perkeo={},{},false;local count=0
    for _,j in ipairs(state.jokers) do
      local row=g.by_key[j.key]
      if not gold.stable_card(j,modules.gold_perkeo,state) or seen[tostring(j.id)] or j.face_down or j.unknown or
          j.facing=='back' or j.getting_sliced or not row or row.status~='missing' and row.status~='complete' then
        return nil,'Each endpoint needs complete visible supported physical Joker identities.'
      end
      seen[tostring(j.id)]=true;perkeo=perkeo or j.key=='j_perkeo'
      if row.status=='missing' and not keys[j.key] then keys[j.key]=true;count=count+1 end
    end
    local receipt={schema=1,supported=true,scope=perkeo and 'empty_perkeo_hold' or 'unchanged_owned_inventory_hold'}
    if perkeo and #state.consumeables>0 then
      if not modules.gold_tarot_hold or not modules.gold_tarot_hold.certify then return nil,'The full Perkeo inventory needs a hold certificate.' end
      local why;receipt,why=modules.gold_tarot_hold.certify(state)
      if not receipt or receipt.schema~=1 or receipt.supported~=true or receipt.scope~='fixed_hold_tarot_copy_score_equivalence_v1' or
          receipt.original_inventory_unchanged~=true or receipt.generation_used_for_score~=false or receipt.first_hand_consumable_actions~=0 or
          receipt.inventory_count_before~=#state.consumeables or receipt.capacity_before~=state.consumable_limit or
          receipt.cash_before~=state.dollars or receipt.cash_after~=state.dollars or encode(receipt.inventory_before)~=inventory then
        return nil,why or 'The full Perkeo inventory lacks a hold certificate.'
      end
    end
    return {missing=count,keys=keys,hold_certificate=receipt}
  end
  local held,why=qualify(s);if not held then return no(why) end
  local paid=copy(s)
  for _,a in ipairs(actions) do
    local card=(paid[a.area] or {})[a.index]
    if not card or a.kind=='buy' and (api.kind(card)~='joker' or not api.capacity(paid,card,false) or
        not finite(card.cost) or card.cost>0 and card.cost>paid.dollars-paid.bankrupt_at) then
      return no('The complete paid incumbent cannot be legally funded or placed.')
    end
    paid,why=transition(paid,a,modules);if not paid then return no(why or 'The incumbent paid transition is unsupported.') end
    if encode(paid.consumeables)~=inventory or encode(paid.playing_cards)~=population or
        paid.consumable_limit~=s.consumable_limit or paid.consumeable_buffer~=s.consumeable_buffer then
      return no('The paid incumbent changes protected original inventory, capacity or population.')
    end
  end
  local incumbent;incumbent,why=qualify(paid);if not incumbent then return no(why) end
  d.before_missing=incumbent.missing;d.after_missing=held.missing;d.incumbent_actions=copy(actions)
  if held.missing<=incumbent.missing then d.complete=true;return no('The complete incumbent does not reduce distinct missing-Joker cargo.') end
  if cap==0 then return no('No shared shop score allowance remains for retention review.') end
  local holds={{state=s,qualification=held,action_count=0,key='',order=nil}}
  if modules.gold_order then
    if type(modules.gold_order.family)~='function' or type(modules.gold_order.apply)~='function' then
      return no('The complete physical order-family helper is unavailable.')
    end
    local family;family,why=modules.gold_order.family(s,modules)
    if not family or family.complete~=true or not array(family.rows,6) or #family.rows<1 then
      return no(why or 'The complete physical order family is unsupported.')
    end
    d.order_family=copy(family);local seen={};local original=copy(s);original.jokers=nil
    for _,row in ipairs(family.rows) do
      if type(row)~='table' or not array(row.order,6) or #row.order~=#s.jokers or
          type(row.key)~='string' or row.key=='' or seen[row.key] or
          row.action_count~=0 and row.action_count~=1 then
        return no('A declared physical order row is malformed or duplicated.')
      end
      seen[row.key]=true
      local state;state,why=modules.gold_order.apply(s,row)
      if not state or not array(state.jokers,6) or #state.jokers~=#s.jokers then
        return no(why or 'A declared physical order cannot be executed from the current row.')
      end
      local normalized=copy(state);normalized.jokers=nil
      if encode(normalized)~=encode(original) then return no('An order projection changes a protected non-Joker resource.') end
      local used,moved={},false
      for i,index in ipairs(row.order) do
        if not integer(index) or index<1 or not s.jokers[index] or used[index] or
            encode(state.jokers[i])~=encode(s.jokers[index]) then
          return no('An order projection changes or duplicates a physical Joker.')
        end
        used[index]=true;moved=moved or i~=index
      end
      if row.action_count~=(moved and 1 or 0) then return no('A declared order lacks its actual arrangement action cost.') end
      local qualification;qualification,why=qualify(state);if not qualification then return no(why) end
      if qualification.missing~=held.missing then return no('A physical reorder cannot alter distinct missing-Joker cargo.') end
      if moved then
        holds[#holds+1]={state=state,qualification=qualification,action_count=1,key=row.key,order=copy(row.order)}
      else holds[1].key=row.key end
    end
    if #holds>6 then return no('The bounded current-plus-copy-target hold family exceeded six rows.') end
  end
  table.sort(holds,function(a,b)
    if a.action_count~=b.action_count then return a.action_count<b.action_count end
    return a.key<b.key
  end)
  local calls,failure=0,nil
  local facade={score=function(state,selected)
    if calls>=cap then failure='The remaining shared shop score allowance is exhausted.';return nil end
    calls=calls+1;d.evaluations=calls
    local ok,r=pcall(score.lower_bound,state,selected)
    if not ok or type(r)~='table' or not finite(r.score) or r.score<0 or r.uncertain or
        r.warnings~=nil and type(r.warnings)~='table' or type(r.warnings)=='table' and next(r.warnings)~=nil or
        r.legal~=false and (r.reliable_bound~=true or r.bound_kind~='supported_random_floor') then
      failure='An admitted selection lacks a reliable warning-free score floor.';return nil
    end
    return r
  end}
  local context=shop.new(s,facade,yield_fn,{max_evaluations=cap,current_order_opening_only=true})
  if context.preflight_family then
    local states={paid};for _,hold in ipairs(holds) do states[#states+1]=hold.state end
    local preflight=context:preflight_family(states);d.preflight=copy(preflight)
    if not preflight or preflight.complete~=true or preflight.supported~=true then
      return no('A declared retention endpoint is mechanically unsupported before scoring.')
    end
    if preflight.fits~=true and #holds>1 then
      -- Shrink the declared family only before any score call, solely for cost.
      -- An unsupported member above never permits scoring a selected prefix.
      d.order_budget_fallback=true;holds={holds[1]}
      preflight=context:preflight_family({paid,s});d.fallback_preflight=copy(preflight)
    end
    if not preflight or preflight.complete~=true or preflight.supported~=true or preflight.fits~=true then
      return no('The complete retention family does not fit the remaining shared allowance before scoring.')
    end
  elseif #holds>1 then return no('Expanded retention requires complete family cost preflight before scoring.') end
  local function fixed(r,state)
    local o=r and r.ordering
    if not o or o.action_count~=0 or o.layouts~=1 or not array(o.order,6) or #o.order~=#state.jokers then return false end
    for i,index in ipairs(o.order) do if i~=index then return false end end;return true
  end
  local chosen,family_key;d.holds={};d.rows=#holds
  for _,hold in ipairs(holds) do
    local evidence=context:compare(paid,hold.state);d.comparisons=d.comparisons+1;d.context_evaluations=context.evaluations
    if context.truncated or context.evaluations>cap or calls~=context.evaluations then
      d.truncated=context.truncated;return no('The complete retention comparison did not fit the remaining shared allowance.')
    end
    if failure then return no(failure) end
    local low,delta=gold.validate_inventory_opening(evidence,b.chips,b.key)
    local key=evidence and evidence.common_worlds and evidence.common_worlds.family_key
    if not low or type(key)~='string' or key=='' or family_key and key~=family_key or
        not fixed(evidence.before_readiness,paid) or not fixed(evidence.after_readiness,hold.state) then
      return no('Every incumbent and hold endpoint needs a complete identical-world fixed-row comparison.')
    end
    family_key=key
    local cash=liquidity.estimate(hold.state,evidence.after_readiness)
    if not cash or not finite(cash.purchase_floor) or not finite(cash.shortfall) or not finite(cash.reserve) then
      return no('A hold endpoint has unsupported immediate cash reserves.')
    end
    hold.low=low;hold.delta=delta;hold.cash=cash
    hold.eligible=low>=1.25*b.chips and hold.state.dollars>=cash.purchase_floor and cash.shortfall==0
    d.holds[#d.holds+1]={key=hold.key,action_count=hold.action_count,minimum_opening_score=low,
      minimum_score_delta=delta,eligible=hold.eligible,liquidity=copy(cash)}
    if hold.eligible and (not chosen or hold.action_count<chosen.action_count or
        hold.action_count==chosen.action_count and (low>chosen.low or low==chosen.low and hold.key<chosen.key)) then chosen=hold end
  end
  d.complete=true;d.common_world_family_key=family_key;d.incumbent_certificate=incumbent.hold_certificate
  local best=chosen or holds[1]
  d.minimum_opening_score=best.low;d.minimum_score_delta=best.delta;d.liquidity=copy(best.cash)
  d.held_certificate=best.qualification.hold_certificate;d.selected_order=copy(best.order);d.arrangement_actions=best.action_count
  if not chosen then return no('Retaining the missing Joker does not retain the sampled next-blind margin and cash reserves.') end
  d.reason='Retain more distinct missing Gold Jokers instead of exchanging them for surplus score.'
  local first=chosen.action_count==0 and {kind='leave_shop'} or {kind='reorder_jokers',area='jokers',order=copy(chosen.order)}
  return {title=chosen.action_count==0 and 'Keep the missing Gold Joker and leave the shop' or 'Reorder Jokers to retain the missing Gold Joker',
    action=first,warnings={},needs_refresh=true,
    gold_retention={before_missing=incumbent.missing,after_missing=held.missing,minimum_opening_score=chosen.low,
      minimum_score_delta=chosen.delta,arrangement_actions=chosen.action_count,order_key=chosen.key},
    lines={'The complete proposed sale-and-buy sequence would reduce missing Gold-sticker progress.',
      'The selected fixed row retains at least 25% margin in all four checked openings, with cash reserves.',
      chosen.action_count==0 and 'Hold all consumables and leave. These samples do not guarantee a final win.' or
        'Reorder only, then refresh advice. All consumables are held; no later reorder or final win is assumed.'}},d.evaluations,d
end
return M
