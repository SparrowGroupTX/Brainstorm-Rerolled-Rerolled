-- A first-hand score dependency certificate, not an exact generated inventory.
-- Keep every original card; unused new Negative Tarot identities/prices remain
-- unresolved. No use, resale, payout, future utility or survival is credited.
local M={}
local definitions={
  c_magician={name='The Magician',effect='Enhance',order=2,config={mod_conv='m_lucky',mod_num=2,max_highlighted=2}},
  c_hermit={name='The Hermit',effect='Dollar Doubler',order=10,config={extra=20}},
}
local row_names={j_perkeo='Perkeo',j_yorick='Yorick',j_brainstorm='Brainstorm',j_blueprint='Blueprint',
  j_swashbuckler='Swashbuckler',j_devious='Devious Joker',j_crazy='Crazy Joker',j_acrobat='Acrobat',
  j_shoot_the_moon='Shoot the Moon',j_scary_face='Scary Face',j_fortune_teller='Fortune Teller',
  j_golden='Golden Joker',j_joker='Joker',j_burnt='Burnt Joker'}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function integer(x) return finite(x) and x>=0 and x%1==0 end
local function plain(t) return type(t)=='table' and getmetatable(t)==nil end
local function data(x,seen,budget)
  budget=budget or {n=32768};budget.n=budget.n-1;if budget.n<0 then return false end
  local k=type(x)
  if k=='number' then return finite(x) end
  if k~='table' then return k=='nil' or k=='string' or k=='boolean' end
  if not plain(x) then return false end
  seen=seen or {};if seen[x] then return false end;seen[x]=true
  for key,value in pairs(x) do
    if type(key)~='string' and not integer(key) or not data(value,seen,budget) then seen[x]=nil;return false end
  end
  seen[x]=nil;return true
end
local function array(t,cap)
  if not plain(t) or #t>cap then return false end
  local n=0;for k in pairs(t) do if not integer(k) or k<1 or k>#t then return false end;n=n+1 end
  return n==#t
end
local function copy(x) if type(x)~='table' then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function negative(e)
  if e==nil then return false end
  if not plain(e) or e.negative~=true or e.type~='negative' then return nil end
  for k in pairs(e) do if k~='negative' and k~='type' then return nil end end
  return true
end
local empty_base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0}
local params_allowed={discover=true,bypass_discovery_center=true,bypass_discovery_ui=true,bypass_lock=true}
local function params_ok(p)
  if not plain(p) or not data(p) then return false end
  for k,v in pairs(p) do if not params_allowed[k] or type(v)~='boolean' then return false end end
  return true
end
local zero={mult=true,h_mult=true,h_x_mult=true,h_dollars=true,p_dollars=true,t_mult=true,t_chips=true,
  h_size=true,d_size=true,bonus=true,perma_bonus=true}
local ability_fields={name=true,effect=true,set=true,order=true,type=true,x_mult=true,extra=true,
  extra_value=true,hands_played_at_create=true,consumeable=true}
local function ability_ok(a,d)
  if not plain(a) or not data(a) or a.name~=d.name or a.effect~=d.effect or a.set~='Tarot' or
      a.order~=d.order or a.type~='' or a.x_mult~=1 or not finite(a.extra_value) or a.extra_value<0 or
      not integer(a.hands_played_at_create) or not equal(a.consumeable,d.config) or a.extra~=d.config.extra then return false end
  for k in pairs(a) do if not zero[k] and not ability_fields[k] then return false end end
  for k in pairs(zero) do if a[k]~=0 then return false end end
  return true
end
local function visible_raw(card)
  if type(card)~='table' or rawget(card,'facing')~='front' or rawget(card,'face_down') or rawget(card,'identity_redacted') then return false end
  local states=rawget(card,'states');local drag=type(states)=='table' and rawget(states,'drag')
  if type(drag)=='table' and rawget(drag,'is') or rawget(card,'dragging') then return false end
  local sprite,flip,pinch=rawget(card,'sprite_facing'),rawget(card,'flipping'),rawget(card,'pinch')
  if sprite and sprite~='front' then return false end
  if flip then return flip=='b2f' and sprite=='front' and type(pinch)=='table' and rawget(pinch,'x')==false end
  return pinch==nil or type(pinch)=='table' and not rawget(pinch,'x')
end
function M.capture(card,registry)
  local function no(reason) return {schema=1,supported=false,reason=reason} end
  -- This guard precedes all identity/ability/constructor reads.
  if not visible_raw(card) then return no('A settled publicly visible Tarot is required.') end
  local center=card.config and card.config.center
  local d=type(center)=='table' and definitions[center.key]
  if not d then return no('This Tarot constructor is outside the qualified Magician/Hermit family.') end
  if not plain(center) or not data(center) or not plain(registry) or registry[center.key]~=center or
      center.name~=d.name or center.effect~=d.effect or center.order~=d.order or center.set~='Tarot' or
      center.consumeable~=true or center.cost~=3 or not data(center.config) or not equal(center.config,d.config) then
    return no('The loaded Tarot center or constructor config differs from the qualified source shape.')
  end
  if not params_ok(card.params) or not plain(card.config.card) or next(card.config.card)~=nil or
      not data(card.base) or not equal(card.base,empty_base) or not ability_ok(card.ability,d) or
      card.playing_card~=nil or card.debuff~=false or (card.pinned~=nil and card.pinned~=false) or card.seal~=nil or
      card.base_cost~=3 or not finite(card.cost) or card.cost<0 or not finite(card.sell_cost) or card.sell_cost<0 or
      negative(card.edition)==nil then return no('The copied Tarot ability, edition, front or parameters are unsupported.') end
  return {schema=1,supported=true,scope='qualified_tarot_hold_source_v1',center_key=center.key,center_name=d.name,
    center_set='Tarot',center_effect=d.effect,center_order=d.order,center_cost=3,center_consumeable=true,
    center_config=copy(center.config),ability=copy(card.ability),base=copy(card.base),params=copy(card.params),
    front_empty=true,scope_note='Observed public vanilla constructor inputs; not arbitrary mod callback qualification.'}
end
local function source_ok(c)
  local d=definitions[c.key];local p=c.tarot_hold_source
  if not d or not plain(p) or p.schema~=1 or p.supported~=true or p.scope~='qualified_tarot_hold_source_v1' or
      c.name~=d.name or not ability_ok(c.ability,d) or not data(c) or negative(c.edition)==nil or
      c.debuff~=false or c.pinned~=false or c.face_down~=false or c.seal~=nil or
      c.base_cost~=3 or not finite(c.cost) or c.cost<0 or not finite(c.sell_cost) or c.sell_cost<0 or
      not equal(c.base,empty_base) or p.center_key~=c.key or p.center_name~=d.name or p.center_set~='Tarot' or
      p.center_effect~=d.effect or p.center_order~=d.order or p.center_cost~=3 or p.center_consumeable~=true or
      not equal(p.center_config,d.config) or not equal(p.ability,c.ability) or not equal(p.base,c.base) or
      p.front_empty~=true or not params_ok(p.params) then return false end
  return true
end
local function id(c) return type(c.id)=='string' and c.id~='' or finite(c.id) end
local function visible(c)
  return plain(c) and not c.face_down and c.facing~='back' and c.sprite_facing~='back' and
    not c.identity_redacted and not c.unknown and not c.getting_sliced and not c.dragging and
    not (type(c.states)=='table' and type(c.states.drag)=='table' and c.states.drag.is)
end
function M.certify(s)
  local function no(reason) return nil,reason end
  if not plain(s) or s.phase~='shop' or not array(s.consumeables,64) or #s.consumeables<1 or
      not array(s.jokers,6) or #s.jokers<1 or not integer(s.consumable_limit) or
      s.consumable_limit<#s.consumeables or s.consumeable_buffer~=0 or not finite(s.dollars) or
      s.ordering_safe==false or s.jokers_shuffling or s.dragging or s.jokers_dragging or (s.blind or {}).shuffle_pending then
    return no('A settled fixed shop row and bounded whole inventory/capacity are required.')
  end
  -- Fail before touching any identity on a concealed or poisoned card.
  for _,c in ipairs(s.consumeables) do if not visible(c) then return no('Every held Tarot must be publicly visible.') end end
  for _,c in ipairs(s.jokers) do if not visible(c) then return no('Every Joker must be publicly visible.') end end
  local ids,classes={},{}
  for _,c in ipairs(s.consumeables) do
    if not id(c) or ids[tostring(c.id)] or not source_ok(c) then return no('The whole inventory needs distinct qualified Tarot source certificates.') end
    ids[tostring(c.id)]=true;classes[c.key]=true
  end
  for _,j in ipairs(s.jokers) do
    local a=j.ability;local expected=row_names[j.key]
    if not expected or not plain(a) or not data(j) or not id(j) or ids[tostring(j.id)] or
        a.set~='Joker' or a.name~=expected or j.name~=nil and j.name~=expected or
        type(j.debuff)~='boolean' or type(j.blueprint_compat)~='boolean' then
      return no('Unknown Joker or copy-chain identity prevents an inventory-independent exit proof.')
    end
    for _,k in ipairs({'eternal','perishable','rental','perma_debuff'}) do
      if a[k]~=nil and type(a[k])~='boolean' then return no('Unknown Joker activity metadata prevents a copy count.') end
    end
    if a.perishable and not integer(a.perish_tally) then return no('Unknown perish timing prevents a copy count.') end
    ids[tostring(j.id)]=true
  end
  local function active(j) local a=j.ability;return not j.debuff and not a.perma_debuff and not (a.perishable and a.perish_tally<=0) end
  local function resolve(i,seen)
    local j=s.jokers[i];if not j or seen[i] or not active(j) then return nil end;seen[i]=true
    local next_index=j.key=='j_blueprint' and i+1 or j.key=='j_brainstorm' and 1 or nil
    if next_index then
      local next_card=s.jokers[next_index]
      if not next_card or next_card.blueprint_compat~=true then return nil end
      return resolve(next_index,seen)
    end
    return j.key=='j_perkeo' and i or nil
  end
  local sources={}
  for i,j in ipairs(s.jokers) do local target=resolve(i,{})
    if target then sources[#sources+1]={source_id=j.id,perkeo_id=s.jokers[target].id,source_slot=i,target_slot=target} end
  end
  local class_keys={};for key in pairs(classes) do class_keys[#class_keys+1]=key end;table.sort(class_keys)
  local n=#sources
  return {schema=1,supported=true,scope='fixed_hold_tarot_copy_score_equivalence_v1',
    copy_events=n,physical_sources=sources,current_order=copy(s.jokers),inventory_before=copy(s.consumeables),
    original_inventory_unchanged=true,inventory_count_before=#s.consumeables,inventory_count_after=#s.consumeables+n,
    capacity_before=s.consumable_limit,capacity_after=s.consumable_limit+n,
    free_slots_before=s.consumable_limit-#s.consumeables,free_slots_after=s.consumable_limit-#s.consumeables,
    cash_before=s.dollars,cash_after=s.dollars,first_hand_consumable_actions=0,generation_used_for_score=false,
    source_classes=class_keys,growing_pool_closed_under_negative_copy=true,
    generated_identity='unresolved',generated_prices='unresolved',generated_resale_credit=0,generated_future_utility_credit=0,
    copied_class_score_contribution=0,observatory_multiplier_from_generated_cards=1,
    proof='Every admitted source is an unchanged nonplaying Tarot with zero add-to-deck hand/discard effects. Perkeo forces Negative, adds one card and one slot, and spends no cash. No new card has a scoring edition or Planet identity. Holding every original and new card leaves first-hand score dependencies unchanged, including the whole original inventory and Tarot usage counts.',
    boundary='Fixed current exit row and hold-all first hand only. Copied identities/prices, later uses, future copying value, later blinds and terminal survival are unresolved. This is not an exact generated inventory.'}
end
return M
