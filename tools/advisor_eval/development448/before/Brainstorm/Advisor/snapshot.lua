-- Only copy data: never evaluate a live Card or advance the game's RNG.
local M = {}

function M.copy(value, seen)
  if type(value) ~= 'table' then
    if type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean' then return value end
    return nil
  end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  local result = {}
  for k, v in pairs(value) do
    if type(k) == 'number' or type(k) == 'string' then result[k] = M.copy(v, seen) end
  end
  seen[value] = nil
  return result
end

function M.fingerprint(value)
  local function encode(v)
    if type(v) ~= 'table' then return type(v) .. ':' .. tostring(v) end
    local keys, parts = {}, {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do parts[#parts + 1] = encode(k) .. '=' .. encode(v[k]) end
    return '{' .. table.concat(parts, ';') .. '}'
  end
  return encode(value)
end

local function settled_flip(card)
  if not card.flipping then return card.pinch==nil or type(card.pinch)=='table' and not card.pinch.x end
  local target=card.flipping=='f2b' and 'back' or card.flipping=='b2f' and 'front'
  return target and card.facing==target and card.sprite_facing==target and
    type(card.pinch)=='table' and card.pinch.x==false or false
end
function M.presentation_settled(card)
  return settled_flip(card) and not (card.facing and card.sprite_facing and card.facing~=card.sprite_facing)
end
function M.public_front(card)
  return M.presentation_settled(card) and card.facing~='back' and card.sprite_facing~='back' and
    card.face_down~=true and card.identity_redacted~=true
end
function M.card(card)
  local center = card.config and card.config.center or {}
  local base = card.base or {}
  local ability = M.copy(card.ability or {})
  -- Hovering a copy Joker updates these tooltip caches without changing the run.
  ability.blueprint_compat_ui, ability.blueprint_compat_check = nil, nil
  return {
    id = card.playing_card and ('playing:' .. tostring(card.playing_card)) or
      card.sort_id and ('card:' .. tostring(card.sort_id)) or tostring(card),
    key = center.key, name = center.name or (card.ability or {}).name,
    rank = base.id, nominal = base.nominal, suit = base.suit,
    -- Deterministic physical-card tie break for public automatic hand sorting.
    -- Copy data only: do not call get_nominal or expose a future deck position.
    sort_tie = card.unique_val,
    enhancement = center.set == 'Enhanced' and center.key or nil,
    edition = M.copy(card.edition), seal = card.seal, debuff = not not card.debuff,
    face_down = not M.public_front(card), ability = ability, base = M.copy(base),
    cost = card.cost, base_cost = card.base_cost, sell_cost = card.sell_cost, rarity = center.rarity,
    blueprint_compat = center.blueprint_compat, vampired = card.vampired,
    pinned = not not card.pinned,
    copy_source = M.perkeo_inventory and M.perkeo_inventory.capture(card, G and G.P_CENTERS) or nil,
    tarot_hold_source = center.set=='Tarot' and M.gold_tarot_hold and
      M.gold_tarot_hold.capture(card, G and G.P_CENTERS) or nil,
  }
end

local function hidden_joker(card)
  -- A flip direction persists after Card:update finishes revealing the front.
  -- Match the observer's public presentation predicate before reading identity.
  return not M.public_front(card)
end
local function cards(area, discarded, joker_row)
  local result = {}
  for _, card in ipairs(area and area.cards or {}) do
    -- Do not read identity, ability or copying metadata before redacting a
    -- Joker whose visible sprite is still a back.
    local observation = joker_row and hidden_joker(card) and
      {face_down=true,identity_redacted=true,public_slot=#result+1} or M.card(card)
    -- Discard alignment turns even publicly seen cards back-side up. The
    -- source retains wheel_flipped only for identities that stayed concealed;
    -- its remaining-deck UI uses that same marker. Do not infer visibility for
    -- other outside cards, or from the current blind (which may be disabled).
    if discarded and discarded[card] and not (card.ability or {}).wheel_flipped then
      observation.face_down = false
    end
    result[#result + 1] = observation
  end
  return result
end

local function shop_forecast(g)
  local game, pools = g.GAME, g.P_JOKER_RARITY_POOLS
  if not pools or not pools[1] or not pools[2] or not pools[3] then return nil end
  local out = {pools = {}, used = {}, slots = game.shop and game.shop.joker_max,
    rates = {joker=game.joker_rate, tarot=game.tarot_rate, planet=game.planet_rate,
      playing=game.playing_card_rate, spectral=game.spectral_rate},
    discount_percent=game.discount_percent, inflation=game.inflation, rental_rate=game.rental_rate,edition_rate=game.edition_rate,
    round_bonus=M.copy(game.round_bonus), blind_rewards={}}
  local enhanced = {}
  for _, card in ipairs(g.playing_cards or {}) do
    local center = card.config and card.config.center
    if center then enhanced[center.key] = true end
  end
  for rarity = 1, 3 do
    out.pools[rarity] = {}
    for _, center in ipairs(pools[rarity]) do
      local flags = game.pool_flags or {}
      if center.key and center.unlocked ~= false and not (game.banned_keys or {})[center.key] and
        (not center.no_pool_flag or not flags[center.no_pool_flag]) and
        (not center.yes_pool_flag or flags[center.yes_pool_flag]) and
        (not center.enhancement_gate or enhanced[center.enhancement_gate]) then
        out.pools[rarity][#out.pools[rarity] + 1] = {key=center.key, name=center.name,
          cost=center.cost, rarity=rarity, source_config=M.copy(center.config),
          source_set=center.set,source_effect=center.effect,blueprint_compat=center.blueprint_compat,source_order=center.order}
      end
      if center.key and (game.used_jokers or {})[center.key] then out.used[center.key] = true end
    end
    table.sort(out.pools[rarity], function(a, b) return a.key < b.key end)
  end
  -- Source get_current_pool eligibility before duplicate removal. The old shop
  -- is removed before a refresh; prospective duplicate exclusions therefore
  -- belong in the forecast, using this detached used-key map and owned cards.
  if g.P_CENTER_POOLS and type(g.P_CENTER_POOLS.Planet)=='table' and type(g.P_CENTER_POOLS.Tarot)=='table' then
    out.consumable_pool_schema='source_shop_consumables_v1'
    out.consumable_used={}
    for _,set in ipairs({'Planet','Tarot'}) do
      local pool={};out[set:lower()..'_pool']=pool
      for _,center in ipairs(g.P_CENTER_POOLS[set]) do
        local config,flags=center.config or {},game.pool_flags or {}
        local hand=(game.hands or {})[config.hand_type]
        if center.key and center.set==set and center.unlocked~=false and
          not (game.banned_keys or {})[center.key] and
          (not center.no_pool_flag or not flags[center.no_pool_flag]) and
          (not center.yes_pool_flag or flags[center.yes_pool_flag]) and
          (set~='Planet' or not config.softlock or hand and type(hand.played)=='number' and hand.played>0) and
          (set~='Tarot' or not center.enhancement_gate or enhanced[center.enhancement_gate]) and
          center.name~='The Soul' and center.name~='Black Hole' then
          pool[#pool+1]={key=center.key,name=center.name,cost=center.cost,source_config=M.copy(center.config),
            source_set=center.set,source_effect=center.effect,source_order=center.order}
        end
        if center.key and (game.used_jokers or {})[center.key] then out.consumable_used[center.key]=true end
      end
      table.sort(pool,function(a,b) return a.key<b.key end)
    end
  end
  local choices = (game.round_resets or {}).blind_choices or {}
  for label, key in pairs({Small='bl_small',Big='bl_big',Boss=choices.Boss}) do
    local blind = g.P_BLINDS and g.P_BLINDS[key]
    if blind then out.blind_rewards[label] = blind.dollars end
  end
  local forced = {tag_rare=true,tag_uncommon=true,tag_foil=true,tag_holo=true,
    tag_polychrome=true,tag_negative=true,tag_coupon=true}
  for _, tag in ipairs(game.tags or {}) do
    if forced[tag.key] then out.special_shop_rules = true end
  end
  if g.SETTINGS and g.SETTINGS.tutorial_progress and g.SETTINGS.tutorial_progress.forced_shop then out.special_shop_rules = true end
  return out
end

-- A held Fool copies the public last-used center, but ordinary hand snapshots
-- do not carry the shop's full catalog. Capture only the needed source center;
-- the policy still checks its exact vanilla scope before proposing a use.
local function fool_source(g)
  local game=g.GAME or {}
  if game.last_tarot_planet~='c_jupiter' or (game.banned_keys or {}).c_jupiter then return nil end
  local held=false
  for _,card in ipairs(g.consumeables and g.consumeables.cards or {}) do
    if ((card.config or {}).center or {}).key=='c_fool' then held=true;break end
  end
  if not held then return nil end
  local center=(g.P_CENTERS or {}).c_jupiter
  if not center then return nil end
  return {schema='fool_last_center_v1',key=center.key,name=center.name,set=center.set,
    effect=center.effect,order=center.order,cost=center.cost,
    config=M.copy(center.config or {}),unlocked=center.unlocked}
end

-- The runtime uses this small public-state check before copying a complete
-- snapshot. Logging and execution still use capture, including other phases.
function M.phase(g)
  if not g or not g.GAME or not g.STAGES or g.STAGE ~= g.STAGES.RUN then return nil end
  local states = g.STATES
  local phase,pack_type = 'other',nil
  if g.STATE == states.SELECTING_HAND then phase = 'hand'
  elseif g.STATE == states.SHOP then phase = 'shop'
  elseif g.STATE == states.BLIND_SELECT then phase = 'blind'
  elseif g.STATE == states.ROUND_EVAL then phase = 'round'
  else
    for _, name in ipairs({'TAROT_PACK', 'PLANET_PACK', 'SPECTRAL_PACK', 'STANDARD_PACK', 'BUFFOON_PACK'}) do
      if states[name] and g.STATE == states[name] then phase = 'pack';pack_type=name end
    end
  end
  return phase,pack_type
end

function M.capture(g)
  local phase,pack_type=M.phase(g)
  if not phase then return nil end
  local game=g.GAME
  local concealed_jokers=false
  for _,card in ipairs(g.jokers and g.jokers.cards or {})do if hidden_joker(card)then concealed_jokers=true end end
  local blind, round, resets = game.blind or {}, game.current_round or {}, game.round_resets or {}
  local back = game.selected_back and game.selected_back.effect and game.selected_back.effect.center or {}
  local next_target, next_blind, route_blinds, route_tags, active_tags, route_ante
  do
    -- Same ante table and printed multipliers as get_blind_amount/UI. This is
    -- a pressure indicator, not a simulation of the upcoming boss ability.
    local amounts=({{300,800,2000,5000,11000,20000,35000,50000},
      {300,900,2600,8000,20000,36000,60000,100000},
      {300,1000,3200,9000,25000,60000,110000,200000}})[(game.modifiers or {}).scaling or 1]
    local states=resets.blind_states or {}
    -- reset_blinds can already have changed ALL states to Upcoming while the
    -- post-boss shop is still open. Match the source blind-select predicate,
    -- including skipped/hidden blinds, instead of assuming every shop follows Small.
    local complete={Defeated=true,Skipped=true,Hide=true}
    local next_label=states.Boss=='Defeated' and 'Small' or
      not complete[states.Small] and 'Small' or not complete[states.Big] and 'Big' or 'Boss'
    if phase=='blind' then
      local selected=game.blind_on_deck
      if selected=='Small' or selected=='Big' or selected=='Boss' then next_label=selected
      else
        for _,label in ipairs({'Small','Big','Boss'}) do if states[label]=='Select' then next_label=label;break end end
      end
    end
    local key=next_label=='Small' and 'bl_small' or next_label=='Big' and 'bl_big' or (resets.blind_choices or {}).Boss
    local definition=key and (g.P_BLINDS or {})[key]
    local ante=states.Boss=='Defeated' and resets.ante or resets.blind_ante or resets.ante
    route_ante=ante
    if definition and type(definition.mult)=='number' and amounts and amounts[ante] then next_target=amounts[ante]*definition.mult*((game.starting_params or {}).ante_scaling or 1) end
    if definition then next_blind={key=key,name=definition.name,boss=not not definition.boss,
      label=next_label,ante=ante,mult=definition.mult,debuff=M.copy(definition.debuff or {}),chips=next_target} end
    do
      route_blinds,route_tags,active_tags={},{},{}
      for _,tag in ipairs(game.tags or {}) do
        active_tags[#active_tags+1]={key=tag.key,name=tag.name,config=M.copy(tag.config or {}),triggered=tag.triggered}
      end
      for _,label in ipairs({'Small','Big','Boss'}) do
        local route_key=(resets.blind_choices or {})[label] or
          (label=='Small' and 'bl_small' or label=='Big' and 'bl_big')
        local def=route_key and (g.P_BLINDS or {})[route_key]
        if def then
          local target=type(def.mult)=='number' and amounts and amounts[ante] and
            amounts[ante]*def.mult*((game.starting_params or {}).ante_scaling or 1) or nil
          local reward=def.dollars
          if type((game.modifiers or {}).no_blind_reward)=='table' and game.modifiers.no_blind_reward[label] then reward=0 end
          route_blinds[label]={key=route_key,name=def.name,label=label,boss=not not def.boss,ante=ante,state=states[label],
            mult=def.mult,debuff=M.copy(def.debuff or {}),chips=target,dollars=reward}
        end
        local tag_key=(resets.blind_tags or {})[label]
        if type(tag_key)=='table' then tag_key=tag_key.key end
        local tag=tag_key and (g.P_TAGS or {})[tag_key]
        if tag then route_tags[label]={key=tag_key,name=tag.name,config=M.copy(tag.config or {})} end
      end
    end
    -- Public current-ante route context stays visible during hands and shops.
    -- Keep the existing next-action pressure contract phase scoped.
    if phase~='shop' and phase~='blind' and phase~='pack' then next_target,next_blind=nil,nil end
  end
  local filter_info=game.filter_info and (game.filter_info.challenge_opening or game.filter_info.jokerless_opening) and M.copy(game.filter_info) or nil
  -- Search telemetry belongs in the product's settings/result display, not in
  -- a policy observation. Wall-clock timings or miss batches must never seed
  -- different deterministic draw samples for the same actual run.
  if filter_info then filter_info.search=nil end
  local discarded = {}
  for _, card in ipairs(g.discard and g.discard.cards or {}) do discarded[card] = true end
  -- update_hand_text writes this HUD display aggregate independently of the
  -- scoring state. Actual hand levels, accumulated chips and round
  -- resources are captured independently; no policy reads current_hand.
  -- Excluding only this presentation table keeps unchanged advice reusable.
  local public_round=M.copy(round)
  public_round.current_hand=nil
  local snapshot = {
    phase = phase, state = g.STATE, challenge = game.challenge, round = game.round,
    filter_info = filter_info,
    opening_pack = phase=='pack' and not not (g.pack_cards and g.pack_cards.brainstorm_challenge_opening),
    hand = cards(g.hand), deck = cards(g.deck), jokers = cards(g.jokers,nil,true),
    consumeables = cards(g.consumeables), playing_cards = cards({cards = g.playing_cards}, discarded),
    shop_jokers = phase == 'shop' and cards(g.shop_jokers) or {},
    shop_vouchers = phase == 'shop' and cards(g.shop_vouchers) or {},
    shop_booster = phase == 'shop' and cards(g.shop_booster) or {},
    pack_cards = phase == 'pack' and cards(g.pack_cards) or {},
    hands = M.copy(game.hands or {}), modifiers = M.copy(game.modifiers or {}),
    blind = {key = blind.config and blind.config.blind and blind.config.blind.key,
      name = blind.name, disabled = blind.disabled, chips = blind.chips or 0,
      boss = blind.boss, hands_sub = blind.hands_sub, discards_sub = blind.discards_sub,
      mult = blind.mult, hands = M.copy(blind.hands), only_hand = blind.only_hand,
      prepped = blind.prepped, block_play = blind.block_play, debuff = M.copy(blind.debuff)},
    dollars = game.dollars or 0, bankrupt_at = game.bankrupt_at or 0,
    rental_rate = game.rental_rate, win_ante = game.win_ante,
    consumeable_buffer = game.consumeable_buffer,
    chips = game.chips or 0, hands_left = round.hands_left or 0,
    discards_left = round.discards_left or 0, hands_played = round.hands_played or 0,
    discards_used = round.discards_used or 0, hands_played_total = game.hands_played,
    starting_deck_size = game.starting_deck_size,
    consumeable_usage_total = M.copy(game.consumeable_usage_total),
    consumeable_usage = M.copy(game.consumeable_usage),
    current_round = public_round, round_resets = M.copy(resets),
    probabilities = M.copy(game.probabilities or {normal = 1}),
    joker_limit = g.jokers and g.jokers.config.card_limit or 0,
    consumable_limit = g.consumeables and g.consumeables.config.card_limit or 0,
    hand_limit = g.hand and g.hand.config.highlighted_limit or 5,
    hand_size = g.hand and g.hand.config.card_limit or 8,
    hand_sort = g.hand and g.hand.config.sort,
    stake = game.stake,
    normal_opening = M.normal_opening and M.normal_opening.capture(g) or nil,
    certificate_pool = not concealed_jokers and M.certificate and M.certificate.capture(g) or nil,
    deck_key = back.key, blind_choices = M.copy(resets.blind_choices or {}),
    blind_states = M.copy(resets.blind_states or {}), skip_tags = M.copy(resets.blind_tags or {}),
    blind_on_deck = game.blind_on_deck, ante = resets.ante or 1,
    pack_choices = game.pack_choices, pack_kind = g.STATE,pack_type=pack_type,
    reroll_cost = round.reroll_cost or 0, interest_cap = game.interest_cap,
    next_blind_chips = next_target,
    next_blind = next_blind,
    route_blinds=route_blinds,route_tags=route_tags,route_ante=route_ante,
    active_tags=active_tags,
    skips=game.skips,unused_discards=game.unused_discards,round_bonus=M.copy(game.round_bonus),
    interest_amount = game.interest_amount, last_tarot_planet = game.last_tarot_planet,
    used_vouchers = M.copy(game.used_vouchers), first_used_hand_level = game.first_used_hand_level,
    shop_forecast = (phase == 'shop' or phase == 'pack') and shop_forecast(g) or nil,
    fool_source = phase == 'hand' and fool_source(g) or nil,
  }
  -- Use remaining composition, never the game's next-draw order.
  table.sort(snapshot.deck, function(a, b) return a.id < b.id end)
  return snapshot
end

return M
