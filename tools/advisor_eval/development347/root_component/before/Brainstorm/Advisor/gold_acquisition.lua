-- Visible winning-Ante cargo acquisition before Small/Big or a supported final
-- Joker row and the entire held inventory in each endpoint; four public deck
-- composition worlds, never hidden draw order or a terminal win forecast.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v) return finite(v) and v>=0 and v%1==0 end
local function array(v)
  if type(v)~='table' or getmetatable(v) then return false end
  local n=0;for k in pairs(v) do if not integer(k) or k<1 or k>#v then return false end;n=n+1 end
  return n==#v
end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v) do if k~='_shop_scoring' and k~='_readiness' then out[k]=copy(x) end end;return out
end
local function encode(v,seen)
  local t=type(v)
  if t=='nil' then return 'n' end
  if t=='boolean' then return v and 'b1' or 'b0' end
  if t=='number' then return finite(v) and 'd'..string.format('%.17g',v)..';' or nil end
  if t=='string' then return 's'..#v..':'..v end
  if t~='table' or getmetatable(v) then return nil end
  seen=seen or {};if seen[v] then return nil end;seen[v]=true
  local parts={}
  for k,x in pairs(v) do if k~='_shop_scoring' and k~='_readiness' then
    local a,b=encode(k,seen),encode(x,seen)
    if not a or not b then seen[v]=nil;return nil end
    parts[#parts+1]=a..b
  end end
  table.sort(parts);seen[v]=nil;return 't'..#parts..':'..table.concat(parts)..'e'
end
local function signature(actions)
  local keys={};for _,a in ipairs(actions) do keys[#keys+1]=a.kind..':'..a.area..':'..a.index end
  return #keys==0 and 'hold' or table.concat(keys,';')
end

function M.suggest(s,modules,yield_fn,options)
  modules=modules or {};options=options or {}
  local d={complete=false,projection_complete=false,evaluations=0,comparisons=0,endpoints={},excluded={},samples=4,margin=1.25,
    scope='Winning-Ante shop before Small, Big, Vessel or Leaf: fixed current row and held inventory, direct visible missing buy or one completed original sale then buy.',
    terminal_evidence=false,inventory_used=false,future_copies_valued=false}
  local function no(reason) d.reason=reason;return nil,d.evaluations,d end
  if type(s)~='table' then return no('A public shop snapshot is required.') end
  local b,g=s.next_blind or {},s.completionist_goal
  local ordinary=({bl_small=true,bl_big=true})[b.key] and b.boss~=true
  local final=({bl_final_vessel=true,bl_final_leaf=true})[b.key] and b.boss==true
  if s.phase~='shop' or not integer(s.win_ante) or s.win_ante<1 or s.ante~=s.win_ante or b.ante~=s.win_ante or
      not (ordinary or final) or not finite(b.chips) or b.chips<=0 then
    return no('This acquisition family requires a known Small, Big, Vessel or Leaf next in the winning Ante.')
  end
  if type(g)~='table' or g.schema~=1 or g.goal~='gold_stickers' or g.metadata_status~='complete' or
      g.catalog_status~='complete' or g.held_status~='complete' or type(g.eligibility)~='table' or
      g.eligibility.eligible~=true or type(g.by_key)~='table' then
    return no('Complete eligible Gold-sticker metadata is required.')
  end
  local gold,shop,score=modules.gold_goal,modules.shop_scoring,modules.scoring
  local strategy=modules.strategy;local api=strategy and strategy.shop_sequence_api
  local transition=modules.shop_sequences and modules.shop_sequences.transition
  local liquidity=modules.liquidity or strategy and strategy.liquidity
  if not gold or not gold.stable_card or not gold.validate_inventory_opening or not shop or not shop.new or
      not score or not score.lower_bound or not api or not transition or not liquidity or not liquidity.estimate then
    return no('Supported paid transitions, score floors and common-world dependencies are required.')
  end
  if not array(s.jokers) or #s.jokers>6 or not array(s.shop_jokers) or #s.shop_jokers>3 or
      not array(s.consumeables) or not array(s.playing_cards) or not integer(s.joker_limit) or
      not integer(s.consumable_limit) or s.consumable_limit<#s.consumeables or s.consumeable_buffer~=0 or
      not finite(s.dollars) or not finite(s.bankrupt_at) or s.bankrupt_at>0 or
      s.ordering_safe==false or s.jokers_shuffling or not encode(s) then
    return no('Exact bounded settled public rows, inventory, population and cash are required.')
  end
  local requested=options.max_evaluations==nil and 50000 or options.max_evaluations
  if not integer(requested) then return no('A finite nonnegative remaining score allowance is required.') end
  local cap=math.min(50000,requested);d.max_evaluations=cap
  local ids,held,held_count={},{},0
  local function status(card) local v=g.by_key[card.key];return v and v.status end
  for _,j in ipairs(s.jokers) do
    if not gold.stable_card(j,modules.gold_perkeo,s) or ids[tostring(j.id)] or
        j.face_down or j.unknown or j.facing=='back' or j.getting_sliced or
        status(j)~='complete' and status(j)~='missing' then
      return no('Each owned Joker needs a unique visible supported identity and known progress.')
    end
    ids[tostring(j.id)]=true
    if status(j)=='missing' and not held[j.key] then held[j.key]=true;held_count=held_count+1 end
  end
  d.before_missing=held_count
  local offers,offer_ids={},{}
  for i,c in ipairs(s.shop_jokers) do
    if status(c)=='missing' and not held[c.key] and api.kind(c)=='joker' then
      if gold.stable_card(c,modules.gold_perkeo,s) and not c.debuff and not c.face_down and not c.unknown and c.facing~='back' and
          not ids[tostring(c.id)] then
        if offer_ids[tostring(c.id)] then return no('Visible offers cannot share a physical identity.') end
        offer_ids[tostring(c.id)]=true;offers[#offers+1]=i
      else d.excluded[#d.excluded+1]={offer=i,reason='The visible missing offer is outside the admitted supported stable family.'} end
    end
  end
  if #offers==0 then d.complete=true;d.projection_complete=true;return no('No admitted visible distinct missing Joker can be added.') end
  local inventory,population=encode(s.consumeables),encode(s.playing_cards)
  local function hold_certificate(state)
    local perkeo=false;for _,j in ipairs(state.jokers) do perkeo=perkeo or j.key=='j_perkeo' end
    if not perkeo or #state.consumeables==0 then
      return {schema=1,supported=true,scope=perkeo and 'empty_perkeo_hold' or 'unchanged_owned_inventory_hold',
        original_inventory_unchanged=true,generation_used_for_score=false,first_hand_consumable_actions=0}
    end
    local helper=modules.gold_tarot_hold
    if not helper or not helper.certify then return nil,'Nonempty Perkeo inventory needs a qualified fixed-hold copying certificate.' end
    local receipt,why=helper.certify(state)
    if not receipt or receipt.schema~=1 or receipt.supported~=true or receipt.scope~='fixed_hold_tarot_copy_score_equivalence_v1' or
        receipt.original_inventory_unchanged~=true or receipt.generation_used_for_score~=false or receipt.first_hand_consumable_actions~=0 or
        receipt.inventory_count_before~=#state.consumeables or receipt.capacity_before~=state.consumable_limit or
        receipt.cash_before~=state.dollars or receipt.cash_after~=state.dollars or encode(receipt.inventory_before)~=inventory then
      return nil,why or 'The fixed-hold Perkeo copying certificate is unavailable.'
    end
    return receipt
  end
  local function project(actions)
    local state=copy(s)
    for _,a in ipairs(actions) do
      local card=(state[a.area] or {})[a.index]
      if not card then return nil,'A declared physical card is absent.' end
      if a.kind=='buy' then
        if not api.capacity(state,card,false) or card.cost>0 and card.cost>state.dollars-state.bankrupt_at then
          return nil,'This exact purchase is unaffordable or has no legal slot.',true
        end
      end
      local next_state,why=transition(state,a,modules)
      if not next_state then return nil,why end
      if encode(next_state.consumeables)~=inventory or encode(next_state.playing_cards)~=population or
          next_state.consumable_limit~=s.consumable_limit or next_state.consumeable_buffer~=s.consumeable_buffer then
        return nil,'The paid endpoint changes protected original inventory, capacity or physical population.'
      end
      state=next_state
    end
    local certificate,why=hold_certificate(state);if not certificate then return nil,why end
    if encode(state.consumeables)~=inventory or encode(state.playing_cards)~=population or state.consumable_limit~=s.consumable_limit or
        state.consumeable_buffer~=s.consumeable_buffer then return nil,'The hold certificate changed protected public inventory or population.' end
    local keys,physical={},{};local count=0
    for _,j in ipairs(state.jokers) do
      if not gold.stable_card(j,modules.gold_perkeo,state) or physical[tostring(j.id)] or
          status(j)~='complete' and status(j)~='missing' then return nil,'A resulting row lacks complete supported identity and progress.' end
      physical[tostring(j.id)]=true
      if status(j)=='missing' and not keys[j.key] then keys[j.key]=true;count=count+1 end
    end
    return {state=state,actions=copy(actions),key=signature(actions),missing=count,hold_certificate=certificate}
  end
  local root,why=project({});if not root then return no(why) end
  local plans={root}
  local function add(actions)
    local p,reason,blocked=project(actions)
    if not p then
      if blocked then d.excluded[#d.excluded+1]={actions=copy(actions),reason=reason};return true end
      return nil,reason
    end
    if #plans>=22 then return nil,'The declared acquisition family exceeds twenty-two endpoints.' end
    plans[#plans+1]=p;return true
  end
  for _,index in ipairs(offers) do
    local buy={kind='buy',area='shop_jokers',index=index}
    local ok,error=add({buy});if not ok then return no(error) end
    for sold,j in ipairs(s.jokers) do
      if status(j)=='complete' and not j.pinned and not j.ability.pinned and not j.ability.eternal and not (s.modifiers or {}).all_eternal then
        ok,error=add({{kind='sell',area='jokers',index=sold},buy});if not ok then return no(error) end
      end
    end
  end
  d.projection_complete=true
  if #plans==1 then d.complete=true;return no('No declared missing-Joker purchase is legally funded.') end
  if cap==0 then return no('No shared score allowance remains for the complete acquisition family.') end
  local calls=0;local score_failure
  local facade={score=function(state,selected)
    if calls>=cap then score_failure='The shared score allowance is exhausted.';return nil end
    calls=calls+1
    local ok,r=pcall(score.lower_bound,state,selected)
    if not ok or type(r)~='table' or not finite(r.score) or r.score<0 or r.uncertain or
        r.warnings~=nil and type(r.warnings)~='table' or
        type(r.warnings)=='table' and next(r.warnings)~=nil or
        r.legal~=false and (r.reliable_bound~=true or r.bound_kind~='supported_random_floor') then
      score_failure='An admitted selection lacks a reliable warning-free score floor.';return nil
    end
    return r
  end}
  local context=shop.new(s,facade,yield_fn,{max_evaluations=cap,current_order_opening_only=true})
  local family_key;local best
  local function fixed(r,state)
    local o=r and r.ordering
    if not o or o.action_count~=0 or o.layouts~=1 or not array(o.order) or #o.order~=#state.jokers then return false end
    for i,index in ipairs(o.order) do if index~=i then return false end end
    return true
  end
  for _,p in ipairs(plans) do
    -- Avoid requiring yieldable protected calls; Shop yields between score
    -- calls. Unexpected errors retain the runtime worker's error handling.
    local evidence=context:compare(s,p.state)
    d.comparisons=d.comparisons+1;d.evaluations=calls;d.score_calls=calls;d.context_evaluations=context.evaluations
    if context.truncated or context.evaluations>cap or calls~=context.evaluations then
      d.truncated=context.truncated;return no('The shared allowance did not complete every admitted endpoint with exact score accounting.')
    end
    if score_failure then return no(score_failure) end
    local low,delta=gold.validate_inventory_opening(evidence,b.chips,b.key)
    local world=evidence and evidence.common_worlds
    if not low or not world or type(world.family_key)~='string' or world.family_key=='' or
        family_key and family_key~=world.family_key or not fixed(evidence.before_readiness,s) or not fixed(evidence.after_readiness,p.state) then
      return no('An admitted endpoint lacks the complete same-world fixed-current-row opening family.')
    end
    family_key=world.family_key
    local cash=liquidity.estimate(p.state,evidence.after_readiness)
    if not cash or not finite(cash.purchase_floor) or not finite(cash.shortfall) or not finite(cash.reserve) then
      return no('An endpoint has unsupported immediate cash reserves.')
    end
    local eligible=low>=1.25*b.chips and p.state.dollars>=cash.purchase_floor and cash.shortfall==0
    local row={key=p.key,actions=copy(p.actions),carried_missing=p.missing,cash_after=p.state.dollars,
      minimum_opening_score=low,minimum_score_delta=delta,eligible=eligible,hold_certificate=copy(p.hold_certificate),
      evidence=copy(evidence),liquidity=copy(cash),score_kind='supported_random_floor'}
    d.endpoints[#d.endpoints+1]=row;p.receipt=row;p.low=low
    if eligible and p.missing>held_count and (not best or p.missing>best.missing or p.missing==best.missing and
        (#p.actions<#best.actions or #p.actions==#best.actions and (p.state.dollars>best.state.dollars or
          p.state.dollars==best.state.dollars and (p.low>best.low or p.low==best.low and p.key<best.key)))) then best=p end
  end
  d.complete=true;d.score_calls=calls
  if not best then return no('No completely compared acquisition retains the next-blind sampled margin and cash reserves.') end
  d.selected=copy(best.receipt);d.after_missing=best.missing
  local first=best.actions[1];local action=copy(first);local card=s[first.area][first.index]
  if best.actions[2] then action.followup=copy(best.actions[2]) end
  local title=(first.kind=='sell' and 'Sell ' or 'Buy ')..tostring(card.name or card.key)..' for missing Gold-sticker progress'
  return {title=title,action=action,warnings={},needs_refresh=true,gold_acquisition=copy(best.receipt),
    lines={'Add one distinct missing Joker while holding the full consumable inventory and current Joker order.',
      'Every checked next-blind opening retains at least 25% margin using supported score floors; excess chips may be traded for the missing Joker.',
      first.kind=='sell' and 'The paid endpoint sells this completed Joker, then buys the visible missing target. Refresh after the sale.' or 'Refresh advice after the actual purchase.',
      'These four deck-composition samples do not guarantee the next blind or final boss. Gold credit is recorded only after an eligible win.'}},d.evaluations,d
end
return M
