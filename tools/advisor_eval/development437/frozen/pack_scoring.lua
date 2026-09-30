-- Exact revealed non-Joker pack and narrow owned Fool shop transitions.
-- Target selection remains the existing conservative development shortlist.
local M={}
local function clone(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out
  for k,x in pairs(v) do if k~='_shop_scoring' and k~='_readiness' and type(x)~='function' then out[k]=clone(x,seen) end end
  return out
end
local supported={}
for key in ('c_pluto c_mercury c_uranus c_venus c_saturn c_jupiter c_earth c_mars c_neptune c_planet_x c_ceres c_eris '..
  'c_black_hole c_magician c_empress c_heirophant c_lovers c_chariot c_justice c_devil c_tower '..
  'c_star c_moon c_sun c_world c_strength c_death c_hanged_man c_talisman c_deja_vu c_trance c_medium c_cryptid '..
  'c_hermit c_temperance c_fool'):gmatch('%S+') do supported[key]=true end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function fool_projection(snapshot,card,targets,hand_order,owned_index)
  local ability=card.ability or {}
  if snapshot.phase~=(owned_index and 'shop' or 'pack') or card.debuff or ability.set~='Tarot' or ability.name~='The Fool' or
      hand_order or #(targets or {})~=0 or type(ability.consumeable)~='table' or
      next(ability.consumeable)~=nil then return nil,'Modified or targeted Fool use is not modeled.' end
  if not finite(ability.order) or ability.order~=math.floor(ability.order) then
    return nil,'Fool usage order is unknown.'
  end
  local last=snapshot.last_tarot_planet
  if type(last)~='string' or last=='c_fool' then return nil,'Fool has no supported previous Tarot or Planet.' end
  -- This tactical comparison does not price dilution of future Perkeo copies.
  -- Keep the existing whole-inventory strategic path for that engine, including
  -- copy Jokers pointing at Perkeo, and for Observatory inventory tradeoffs.
  if (snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory then
    return nil,'Fool inventory generation needs the existing Observatory inventory valuation.'
  end
  for _,joker in ipairs(snapshot.jokers or {}) do
    if not joker.debuff and (joker.key=='j_perkeo' or (joker.ability or {}).name=='Perkeo') then
      return nil,'Fool inventory generation needs the existing whole Perkeo copying-pool valuation.'
    end
  end
  local held=snapshot.consumeables or {}
  local limit=snapshot.consumable_limit
  if not finite(limit) or limit~=math.floor(limit) or limit<=#held or
      (snapshot.consumeable_buffer or 0)~=0 then return nil,'Pack Fool requires an unreserved held consumable slot.' end
  local meta=snapshot.shop_forecast
  if not meta or meta.consumable_pool_schema~='source_shop_consumables_v1' or
      type(meta.tarot_pool)~='table' or type(meta.planet_pool)~='table' or
      (meta.consumable_used~=nil and type(meta.consumable_used)~='table') or
      (snapshot.banned_keys or {})[last] then return nil,'Fool needs the exact unbanned public source catalog identity.' end
  local entry
  for _,set in ipairs({'Tarot','Planet'}) do
    for _,candidate in ipairs(meta[set:lower()..'_pool']) do
      if type(candidate)~='table' then return nil,'Fool source catalog contains malformed entries.' end
      if candidate.key==last then
        if entry or candidate.source_set~=set then return nil,'Fool catalog identity is ambiguous.' end
        entry=candidate
      end
    end
  end
  -- This snapshot catalog filters banned/locked/softlocked centers before
  -- duplicate removal. Forced source creation ignores duplicate ownership;
  -- a banned forced key instead falls back to random generation and abstains.
  if not entry then return nil,'The previous consumable is absent from the eligible public source catalog.' end
  local tarot_keys={c_magician=true,c_high_priestess=true,c_empress=true,c_emperor=true,c_heirophant=true,
    c_lovers=true,c_chariot=true,c_justice=true,c_hermit=true,c_wheel_of_fortune=true,c_strength=true,
    c_hanged_man=true,c_death=true,c_temperance=true,c_devil=true,c_tower=true,c_star=true,c_moon=true,
    c_sun=true,c_judgement=true,c_world=true}
  local planet_keys={c_pluto=true,c_mercury=true,c_uranus=true,c_venus=true,c_saturn=true,c_jupiter=true,
    c_earth=true,c_mars=true,c_neptune=true,c_planet_x=true,c_ceres=true,c_eris=true}
  local config=entry.source_config
  if not (tarot_keys[last] or planet_keys[last]) or (entry.source_set=='Planet')~=(not not planet_keys[last]) or
      type(config)~='table' or type(entry.name)~='string' or
      not finite(entry.source_order) or entry.source_order~=math.floor(entry.source_order) or
      not finite(entry.cost) or entry.cost<0 or not finite(meta.discount_percent) or
      meta.discount_percent<0 or meta.discount_percent>100 or not finite(meta.inflation) or meta.inflation<0 then
    return nil,'Fool generated-card metadata is incomplete or unsupported.'
  end
  if (config.h_size or 0)~=0 or (config.d_size or 0)~=0 then
    return nil,'Generated consumable resource modifiers are not modeled.'
  end
  local state=clone(snapshot)
  local cost=math.max(1,math.floor((entry.cost+meta.inflation+0.5)*(100-meta.discount_percent)/100))
  if entry.source_set=='Planet' then
    for _,joker in ipairs(state.jokers or {}) do
      if not joker.debuff and (joker.key=='j_astronomer' or (joker.ability or {}).name=='Astronomer') then cost=0 end
    end
  end
  local created_ability={name=entry.name,effect=entry.source_effect,set=entry.source_set,
    mult=config.mult or 0,h_mult=config.h_mult or 0,h_x_mult=config.h_x_mult or 0,
    h_dollars=config.h_dollars or 0,p_dollars=config.p_dollars or 0,t_mult=config.t_mult or 0,
    t_chips=config.t_chips or 0,x_mult=config.Xmult or 1,h_size=0,d_size=0,
    extra=clone(config.extra),extra_value=0,type=config.type or '',order=entry.source_order,
    perma_bonus=0,bonus=config.bonus or 0,consumeable=clone(config),
    hands_played_at_create=snapshot.hands_played_total or 0}
  for _,key in ipairs({'mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips','x_mult','bonus'}) do
    if not finite(created_ability[key]) then return nil,'Generated consumable ability contains unsupported numeric metadata.' end
  end
  -- Card:update refreshes Temperance's displayed/usable payout before the next
  -- settled decision. Creation itself pays nothing and changes no Joker value.
  if last=='c_temperance' then
    if not finite(created_ability.extra) or created_ability.extra<0 then return nil,'Generated Temperance has an unknown payout cap.' end
    local money=0
    for _,joker in ipairs(state.jokers or {}) do if (joker.ability or {}).set=='Joker' then
      if not finite(joker.sell_cost) or joker.sell_cost<0 then return nil,'Generated Temperance requires known Joker resale values.' end
      money=money+joker.sell_cost
    end end
    created_ability.money=math.min(money,created_ability.extra)
  end
  if state.consumeable_usage~=nil and type(state.consumeable_usage)~='table' then return nil,'Fool usage history is malformed.' end
  local uses=(state.consumeable_usage or {}).c_fool
  if uses~=nil and type(uses)~='table' then return nil,'Fool usage history is malformed.' end
  local count=uses and uses.count
  if not uses then count=0 end
  if not finite(count) or count<0 or count~=math.floor(count) then return nil,'Fool usage count is not a complete nonnegative integer.' end
  local id='fool:'..tostring(card.id or 'pack')..':'..tostring(count+1)..':'..last
  for _,owned in ipairs(held) do if owned.id==id then return nil,'Fool projected identity collides with an existing card.' end end
  local created={id=id,key=last,name=entry.name,base_cost=entry.cost,cost=cost,nominal=0,
    base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0},
    sell_cost=math.max(1,math.floor(cost/2)),debuff=false,face_down=false,pinned=false,ability=created_ability}
  state.consumeables=state.consumeables or {}
  if owned_index then table.remove(state.consumeables,owned_index) end
  state.consumeables[#state.consumeables+1]=created
  state.consumeable_usage=state.consumeable_usage or {}
  if uses then state.consumeable_usage.c_fool.count=count+1
  else state.consumeable_usage.c_fool={count=1,order=ability.order,set='Tarot'} end
  state.consumeable_usage_total=state.consumeable_usage_total or {tarot=0,planet=0,spectral=0,tarot_planet=0,all=0}
  if type(state.consumeable_usage_total)~='table' then return nil,'Consumable usage totals are malformed.' end
  for _,key in ipairs({'tarot','planet','spectral','tarot_planet','all'}) do
    local value=state.consumeable_usage_total[key]
    if not finite(value) or value<0 or value~=math.floor(value) then return nil,'Consumable usage totals are incomplete.' end
    if key=='tarot' or key=='tarot_planet' or key=='all' then state.consumeable_usage_total[key]=value+1 end
  end
  state.last_tarot_planet='c_fool'
  state.shop_forecast.consumable_used=state.shop_forecast.consumable_used or {}
  state.shop_forecast.consumable_used[last]=true
  return state,{kind=owned_index and 'use_owned_fool' or 'use_pack_fool',created_key=last,created_id=id,created_index=#state.consumeables,
    consumed_index=owned_index,consumed_id=owned_index and card.id or nil,
    inventory_delta=owned_index and 0 or 1,population_delta=0,free=true,copy_used=false,
    scope='Creates one fresh editionless held consumable; no copied effect is used or promised.'}
end
local planet_hands={c_pluto='High Card',c_mercury='Pair',c_uranus='Two Pair',c_venus='Three of a Kind',
  c_saturn='Straight',c_jupiter='Flush',c_earth='Full House',c_mars='Four of a Kind',
  c_neptune='Straight Flush',c_planet_x='Five of a Kind',c_ceres='Flush House',c_eris='Flush Five'}
local planet_names={c_pluto='Pluto',c_mercury='Mercury',c_uranus='Uranus',c_venus='Venus',c_saturn='Saturn',
  c_jupiter='Jupiter',c_earth='Earth',c_mars='Mars',c_neptune='Neptune',c_planet_x='Planet X',c_ceres='Ceres',c_eris='Eris'}
local function plain_data(v,seen)
  if type(v)=='function' or type(v)=='userdata' or type(v)=='thread' then return false end
  if type(v)~='table' then return true end
  seen=seen or {};if seen[v] or getmetatable(v) then return false end;seen[v]=true
  for k,x in pairs(v) do if not plain_data(k,seen) or not plain_data(x,seen) then return false end end
  seen[v]=nil;return true
end
-- Admission deliberately requires a slot already free before an ordinary owned
-- Fool is removed. Full/Negative inventory and arbitrary copied effects remain
-- outside this bounded shop comparison, even when a live use might be legal.
function M.owned_fool_candidate(snapshot,index,modules)
  local held=snapshot.consumeables or {};local card=held[index];local a=card and card.ability or {}
  local strategy=modules and modules.strategy;local hand=planet_hands[snapshot.last_tarot_planet]
  if snapshot.phase~='shop' or not card or card.key~='c_fool' or not hand or
      #(snapshot.jokers or {})>0 or (snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory or
      not strategy or not strategy.build_profile or not strategy.preservation_cost then return nil,'Owned Fool is outside the main-Planet shop scope.' end
  if type(card.id)~='string' or card.id=='' or not plain_data(card) or card.edition or card.seal or card.enhancement or card.debuff or
      card.face_down or card.unknown or card.facing=='back' or card.pinned or a.set~='Tarot' or a.name~='The Fool' or
      type(a.consumeable)~='table' or next(a.consumeable) then return nil,'Only a visible ordinary unmodified owned Fool is supported.' end
  local defaults={bonus=0,d_size=0,extra_value=0,h_dollars=0,h_mult=0,h_size=0,h_x_mult=0,mult=0,
    p_dollars=0,perma_bonus=0,t_chips=0,t_mult=0,x_mult=1,type='',effect='Disable Blind Effect'}
  for key,value in pairs(a) do
    if defaults[key]~=nil then if value~=defaults[key] then return nil,'Modified Fool ability is unsupported.' end
    elseif key~='consumeable' and key~='name' and key~='set' and key~='order' and key~='hands_played_at_create' then
      return nil,'Unknown Fool ability fields are unsupported.'
    end
  end
  local count=0;local ids={}
  for _,owned in ipairs(held) do
    if type(owned.id)~='string' or owned.id=='' or ids[owned.id] then return nil,'Owned consumable identities are incomplete or repeated.' end
    ids[owned.id]=true;if owned.key=='c_fool' then count=count+1 end
  end
  local limit=snapshot.consumable_limit
  if count~=1 or not finite(limit) or limit%1~=0 or limit<=#held or (snapshot.consumeable_buffer or 0)~=0 then
    return nil,'Owned Fool requires one original Fool and an already free unreserved slot.'
  end
  local profile=strategy.build_profile(snapshot);local old=(snapshot.hands or {})[hand]
  if not profile or profile.hand~=hand or not old or not finite(old.played) or old.played<=0 or
      not finite(old.level) or old.level<1 or not finite(old.chips) or old.chips<0 or not finite(old.mult) or old.mult<1 then
    return nil,'The previous Planet must develop the actually played main hand.'
  end
  return {id=card.id,index=index,created_key=snapshot.last_tarot_planet,hand=hand}
end
function M.project_owned_fool(snapshot,index,modules)
  local candidate,reason=M.owned_fool_candidate(snapshot,index,modules)
  if not candidate then return nil,reason end
  if not plain_data(snapshot.shop_forecast) or not plain_data(snapshot.consumeables) then
    return nil,'Owned Fool requires plain public catalog and inventory data without callbacks.'
  end
  local after,effect=fool_projection(snapshot,snapshot.consumeables[index],{},nil,index)
  if not after then return nil,effect end
  local card=after.consumeables[effect.created_index];local a=card.ability;local config=a.consumeable
  if a.name~=planet_names[candidate.created_key] or
      a.effect~='Hand Upgrade' or config.hand_type~=candidate.hand then return nil,'The copied main Planet has unsupported source metadata.' end
  for key in pairs(config) do if key~='hand_type' and key~='softlock' then return nil,'Modified copied Planet config is unsupported.' end end
  local loss,why,last=modules.strategy.preservation_cost(snapshot,after,index)
  if not finite(loss) or loss<0 or loss>0 or last then return nil,why or 'Owned Fool requires a complete unprotected inventory comparison.' end
  return after,effect
end
local function playing(c)
  return type(c.rank)=='number' and c.rank>=2 and c.rank<=14 and type(c.suit)=='string'
    and ((c.ability or {}).set=='Default' or (c.ability or {}).set=='Enhanced' or c.key=='c_base' or (c.key or ''):sub(1,2)=='m_')
end
function M.supports(card) return supported[card.key] or playing(card) end
function M.project(snapshot,card,targets,hand_order,modules)
  if not M.supports(card) then return nil,'This revealed pack effect has no exact transition.' end
  if card.key=='c_fool' then return fool_projection(snapshot,card,targets,hand_order) end
  local state=clone(snapshot)
  if hand_order then
    local hand,seen={},{}
    if #hand_order~=#(state.hand or {}) then return nil,'Incomplete hand preparation order.' end
    for i,index in ipairs(hand_order) do
      if seen[index] or not state.hand[index] then return nil,'Invalid hand preparation order.' end
      seen[index]=true;hand[i]=state.hand[index]
    end
    state.hand=hand
    targets=modules.strategy.development_targets(state,card)
    if not targets or #targets==0 then return nil,'The prepared hand has no supported target set.' end
  end
  if playing(card) then
    if not card.id or #(state.playing_cards or {})==0 then return nil,'Adding a card requires its identity and the full population.' end
    for _,c in ipairs(state.playing_cards) do if c.id==card.id then return nil,'The offered card is already in the owned population.' end end
    local a=card.ability or {};local edition=card.edition
    if (a.h_size or 0)~=0 or (a.d_size or 0)~=0 or edition=='negative' or type(edition)=='table' and edition.negative then
      return nil,'Playing-card resource changes are outside this pack projection.'
    end
    state.playing_cards[#state.playing_cards+1]=clone(card)
    for _,j in ipairs(state.jokers or {}) do if j.key=='j_hologram' and not j.debuff and not j.getting_sliced then
      local ability=j.ability or {}
      if type(ability.x_mult)~='number' or type(ability.extra)~='number' then return nil,'Unknown Hologram addition growth.' end
      ability.x_mult=ability.x_mult+ability.extra
    end end
    return state,{kind='add_playing_card',population_delta=1,free=true}
  end
  if not modules.consumables then return nil,'Exact consumable transitions are unavailable.' end
  local population={}
  for _,c in ipairs(state.playing_cards or {}) do
    if not c.id or population[c.id] then return nil,'Pack development requires unique complete population identities.' end
    population[c.id]=true
  end
  for _,index in ipairs(targets or {}) do
    local c=(state.hand or {})[index]
    if not c or c.face_down or not c.id or not population[c.id] then
      return nil,'Pack development target must be revealed and present in the owned population.'
    end
  end
  state.consumeables=state.consumeables or {}
  state.consumeables[#state.consumeables+1]=clone(card)
  -- A pack consumable is used directly even with a full held inventory. Temporary
  -- insertion only adapts the existing pure use transition; no held slot is taken.
  if card.edition=='negative' or type(card.edition)=='table' and card.edition.negative then
    state.consumable_limit=(state.consumable_limit or 2)+1
  end
  local after,reason=modules.consumables.apply(state,#state.consumeables,targets)
  if not after then return nil,reason end
  return after,{kind='use_pack_consumable',targets=clone(targets),hand_order=clone(hand_order),free=true,
    population_delta=#(after.playing_cards or {})-#(snapshot.playing_cards or {})}
end
return M
