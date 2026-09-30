-- Exact zero-generation shop exit for Gold cargo comparisons. This is an
-- inventory transition certificate, not a strategic value or survival odds.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v) return finite(v) and v>=0 and v%1==0 end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
function M.accepts_card(card)
  local a=card and card.ability
  return card and card.key=='j_perkeo' and type(a)=='table' and a.set=='Joker' and
    a.name=='Perkeo' and (card.name==nil or card.name=='Perkeo') and
    card.blueprint_compat==true
end
local function active(card)
  local a=card.ability or {}
  return not card.debuff and not a.perma_debuff and not (a.perishable and a.perish_tally<=0)
end
function M.project(snapshot,modules)
  local present=false
  for _,card in ipairs(snapshot.jokers or {}) do if card.key=='j_perkeo' then present=true end end
  if not present then return snapshot,{schema=1,supported=true,scope='no_perkeo',copy_events=0} end
  if snapshot.phase~='shop' or type(snapshot.consumeables)~='table' or
      not integer(snapshot.consumable_limit) or snapshot.consumeable_buffer~=0 then
    return nil,'Perkeo needs an exact settled consumable inventory and capacity.'
  end
  -- Even identical names are insufficient: copied ability, edition, price,
  -- capacity, Observatory and pre-hand use decisions must all be projected.
  if next(snapshot.consumeables)~=nil then
    local inventory=modules and modules.perkeo_inventory
    if not inventory or not modules.phase_copy or not modules.phase_copy.suggest then
      return nil,'Nonempty Perkeo copying pools need a complete shop-exit and owned-use projection.'
    end
    local prepared=snapshot;local setup
    local suggestion,work=modules.phase_copy.suggest(snapshot,modules,{action={kind='leave_shop'}},{max_evaluations=0})
    if work~=0 then return nil,'An immediate copying setup must not consume hidden scoring work.' end
    if suggestion then
      setup=suggestion.action
      if not setup or setup.kind~='reorder_jokers' then return nil,'The immediate copying setup is not a supported reorder.' end
      prepared=copy(snapshot);prepared.jokers={};local seen={}
      for i,index in ipairs(setup.order or {}) do
        local card=snapshot.jokers[index]
        if not card or seen[index] or ((card.pinned or (card.ability or {}).pinned) and i~=index) then
          return nil,'The immediate copying setup is not a legal physical permutation.'
        end
        seen[index]=true;prepared.jokers[i]=copy(card)
      end
      if #prepared.jokers~=#snapshot.jokers then return nil,'The copying setup loses an owned Joker.' end
    end
    local state,receipt=inventory.project(prepared)
    if not state then return nil,receipt end
    receipt.setup_action=copy(setup);receipt.setup_actions=setup and 1 or 0
    receipt.input_order=copy(snapshot.jokers);receipt.exit_order=copy(prepared.jokers)
    receipt.requires_fresh_public_delivery=true
    return state,receipt
  end
  if snapshot.ordering_safe==false or snapshot.jokers_shuffling then
    return nil,'Perkeo shop exit requires a visible settled physical Joker row.'
  end
  local ids,perkeo_ids={},{}
  for _,card in ipairs(snapshot.jokers or {}) do
    local a=card.ability or {}
    if card.face_down or card.facing=='back' or card.unknown or card.getting_sliced or
        not (type(card.id)=='string' and card.id~='' or finite(card.id)) or ids[tostring(card.id)] then
      return nil,'The whole Perkeo row must contain distinct visible physical identities.'
    end
    ids[tostring(card.id)]=true
    if a.perishable and not integer(a.perish_tally) then return nil,'The Perkeo row has unknown perish timing.' end
    if card.key=='j_perkeo' then
      if not M.accepts_card(card) then return nil,'The Perkeo identity or copy compatibility is unsupported.' end
      perkeo_ids[#perkeo_ids+1]=card.id
    end
  end
  local sources={}
  local function resolve(index,seen)
    local card=snapshot.jokers[index]
    if not card or seen[index] or not active(card) then return nil end
    seen[index]=true
    local target=card.key=='j_blueprint' and index+1 or card.key=='j_brainstorm' and 1 or nil
    if target then
      local next_card=snapshot.jokers[target]
      if not next_card or next_card.blueprint_compat~=true then return nil end
      return resolve(target,seen)
    end
    return card.key=='j_perkeo' and index or nil
  end
  for index,card in ipairs(snapshot.jokers) do
    local target=resolve(index,{})
    if target then sources[#sources+1]={source_id=card.id,perkeo_id=snapshot.jokers[target].id} end
  end
  -- Every possible copying arrangement still has an empty pool, so zero
  -- generated cards is invariant under legal pre-exit/first-hand reorders.
  -- Nothing is used, bought, repriced, sold, or generated by this transition.
  local result=copy(snapshot)
  return result,{schema=1,supported=true,scope='empty_perkeo_shop_exit',copy_events=0,
    perkeo_ids=perkeo_ids,physical_sources=sources,inventory_before={},inventory_after={},
    capacity_before=snapshot.consumable_limit,capacity_after=snapshot.consumable_limit,
    buffer_before=0,buffer_after=0,cash_before=snapshot.dollars,cash_after=snapshot.dollars,
    current_order=copy(snapshot.jokers),all_legal_arrangements_same_inventory=true,
    observatory_inventory_unchanged=true,first_hand_consumable_actions=0,
    timing='After all paid endpoint actions, before leaving this shop and starting the final blind.'}
end
return M
