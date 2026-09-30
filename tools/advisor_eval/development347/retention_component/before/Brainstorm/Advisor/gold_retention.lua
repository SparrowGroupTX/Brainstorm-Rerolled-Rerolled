-- Do not undo a supported collection acquisition merely to regain surplus
-- score. Compare the complete sale/buy incumbent against holding the current
-- row and inventory, charging only the caller's remaining shop allowance.
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
    scope='Winning-Ante fixed-current-row hold versus the complete visible sale-first incumbent; all consumables held.'}
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
  local evidence=context:compare(paid,s);d.comparisons=1;d.context_evaluations=context.evaluations
  if context.truncated or context.evaluations>cap or calls~=context.evaluations then
    d.truncated=context.truncated;return no('The complete retention comparison did not fit the remaining shared allowance.')
  end
  if failure then return no(failure) end
  local low,delta=gold.validate_inventory_opening(evidence,b.chips,b.key)
  local function fixed(r,state)
    local o=r and r.ordering
    if not o or o.action_count~=0 or o.layouts~=1 or not array(o.order,6) or #o.order~=#state.jokers then return false end
    for i,index in ipairs(o.order) do if i~=index then return false end end;return true
  end
  if not low or not evidence.common_worlds or type(evidence.common_worlds.family_key)~='string' or
      evidence.common_worlds.family_key=='' or not fixed(evidence.before_readiness,paid) or not fixed(evidence.after_readiness,s) then
    return no('The incumbent and hold endpoints lack a complete same-world fixed-row comparison.')
  end
  local cash=liquidity.estimate(s,evidence.after_readiness)
  if not cash or not finite(cash.purchase_floor) or not finite(cash.shortfall) or not finite(cash.reserve) then
    return no('The hold endpoint has unsupported immediate cash reserves.')
  end
  d.complete=true;d.minimum_opening_score=low;d.minimum_score_delta=delta;d.liquidity=copy(cash)
  d.held_certificate=held.hold_certificate;d.incumbent_certificate=incumbent.hold_certificate
  if low<1.25*b.chips or s.dollars<cash.purchase_floor or cash.shortfall~=0 then
    return no('Retaining the missing Joker does not retain the sampled next-blind margin and cash reserves.')
  end
  d.reason='Retain more distinct missing Gold Jokers instead of exchanging them for surplus score.'
  return {title='Keep the missing Gold Joker and leave the shop',action={kind='leave_shop'},warnings={},needs_refresh=true,
    gold_retention={before_missing=incumbent.missing,after_missing=held.missing,minimum_opening_score=low,minimum_score_delta=delta},
    lines={'The complete proposed sale-and-buy sequence would reduce missing Gold-sticker progress.',
      'Keeping the current row retains at least 25% margin in all four checked openings, with cash reserves.',
      'Hold all consumables in this comparison; refresh after leaving. These samples do not guarantee a final win.'}},d.evaluations,d
end
return M
