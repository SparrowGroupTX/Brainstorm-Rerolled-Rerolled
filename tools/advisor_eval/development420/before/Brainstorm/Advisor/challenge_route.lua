-- Public observation diagnostics for a conditional later-shop seed filter.
-- This never advances RNG, chooses an action, or certifies an unobserved path.
local M={}
local function active(card)
  local a=card.ability or {}
  return not (card.debuff or a.perma_debuff or a.perishable and (a.perish_tally or 5)<=0)
end
local function negative(card)
  return card.edition=='negative' or type(card.edition)=='table' and card.edition.negative
end
local function contains(list,key)
  for _,v in ipairs(list or {}) do if v==key then return true end end
  return false
end
local function location(later)
  local ante,shop=later.found_ante,later.shop
  if type(ante)~='number' or type(shop)~='number' then return 'the conditional later shop' end
  local after=ante==1 and 'Big Blind' or shop==1 and 'previous Ante Boss' or shop==2 and 'Small Blind' or 'Big Blind'
  return 'Ante '..ante..', after '..after..', slot '..tostring(later.slot or '?')
end
function M.inspect(s,action,opening)
  local f=s.filter_info;local later=f and f.later
  if not f or not f.challenge_opening or f.challenge_id~=s.challenge or type(later)~='table' or
      type(later.target_key)~='string' then return nil end
  local out={status='conditional',lines={},warnings={},missing={},inactive={},qualification=false,
    acquisition_verified=false,retention_verified=false,history_verified=false,location=location(later)}
  local owned={};for _,card in ipairs(s.jokers or {}) do owned[card.key]=card end
  local required={};for _,key in ipairs(f.legendary_jokers or {}) do required[#required+1]=key end
  required[#required+1]=later.target_key
  for _,key in ipairs(required) do
    if not owned[key] then out.missing[#out.missing+1]=key
    elseif not active(owned[key]) then out.inactive[#out.inactive+1]=key end
  end
  local card=owned[later.target_key]
  local target_name=card and (card.name or (card.ability or {}).name) or later.target_key
  if opening and opening.rare_names then target_name=opening.rare_names[later.target_key] or target_name end
  out.target_key=later.target_key;out.target_name=target_name
  if #required==3 and #out.missing==0 and #out.inactive==0 then
    out.status='observed_retained';out.retention_verified=true
    out.lines[1]='Later target: '..target_name..' and both searched Legendaries are present and active now.'
    out.lines[2]='This confirms current retention; future survival is still unverified.'
    return out
  end
  if owned[later.target_key] then
    out.status='target_present_incomplete_engine'
    out.lines[1]='Later target is present, but the full searched engine is missing or inactive.'
  else out.lines[1]='Conditional later offer: '..target_name..' — '..out.location..'.' end
  local function incompatible(reason)
    out.status='incompatible_observation';out.warnings[#out.warnings+1]=reason
  end
  -- Opening setup legitimately has not acquired both Legendaries yet.
  if (s.round or 0)>0 then
    for _,key in ipairs(f.legendary_jokers or {}) do
      if not owned[key] or not active(owned[key]) then
        incompatible('A searched Legendary is missing or inactive; the retained-engine forecast no longer applies.')
        break
      end
    end
  end
  if (s.skips or 0)>1 then incompatible('An additional blind was skipped; the searched shop path no longer applies.') end
  if s.phase=='pack' and not s.opening_pack then
    incompatible('An extra pack is open; its generation can change the searched shop path.')
  end
  local forecast=s.shop_forecast
  if forecast then
    if forecast.special_shop_rules or forecast.slots~=(later.shop_slots or 2) then incompatible('Shop slots or forced shop rules differ from the searched route.') end
    local rate_keys={joker_rate='joker',tarot_rate='tarot',planet_rate='planet',playing_card_rate='playing',spectral_rate='spectral'}
    for key,value in pairs(later.shop_rates or {}) do
      local actual=key=='edition_rate' and forecast.edition_rate or (forecast.rates or {})[rate_keys[key] or key]
      if actual~=value then incompatible('Shop item rates changed; the searched shop path no longer applies.');break end
    end
    if forecast.edition_rate and forecast.edition_rate~=1 then incompatible('Joker edition rates changed; the searched offer edition no longer applies.') end
    if type(later.rare_pool_keys)=='table' and forecast.pools and forecast.pools[3] then
      local transient={}
      for _,c in ipairs(s.shop_jokers or {}) do if not owned[c.key] then transient[c.key]=true end end
      local eligible={};for _,c in ipairs(forecast.pools[3]) do
        -- Original Card:set_ability marks unbought shop stock as used too.
        -- It blocks the other slot in this shop, then disappears on removal.
        if not (forecast.used or {})[c.key] or transient[c.key] then eligible[#eligible+1]=c.key end
      end
      for _,key in ipairs(later.rare_pool_keys) do
        if not (key==later.target_key and owned[key]) and not contains(eligible,key) then
          incompatible('Rare Joker availability changed; the conditional offer needs a different path.');break
        end
      end
      for _,key in ipairs(eligible) do
        if not contains(later.rare_pool_keys,key) then
          incompatible('Rare Joker availability changed; the conditional offer needs a different path.');break
        end
      end
    end
  end
  for _,c in ipairs(s.jokers or {}) do
    if c.key=='j_ring_master' then incompatible('Showman changes duplicate availability; the searched Rare pool no longer applies.');break end
  end
  if not owned[later.target_key] and type(later.found_ante)=='number' and (s.ante or 1)>later.found_ante then
    incompatible('The forecast offer ante has passed without the target in the current row.')
  end
  if not owned[later.target_key] then
    for _,area in ipairs({'shop_jokers','pack_cards'}) do
      for index,c in ipairs(s[area] or {}) do if c.key==later.target_key then
        local free=area=='pack_cards';local cost=free and 0 or c.cost
        local affordable=type(cost)=='number' and cost<=math.max(0,(s.dollars or 0)-(s.bankrupt_at or 0))
        local room=#(s.jokers or {})<(s.joker_limit or 0)+(negative(c) and 1 or 0)
        local replacements={}
        if not room then for slot,j in ipairs(s.jokers or {}) do
          if #(s.jokers or {})-1<(s.joker_limit or 0)+(negative(c) and 1 or 0) and
            not (j.ability or {}).eternal and not (s.modifiers or {}).all_eternal and
            not j.pinned and not (j.ability or {}).pinned and
            not contains(f.legendary_jokers,j.key) and not negative(j) then replacements[#replacements+1]=slot end
        end end
        out.observed_offer={area=area,index=index,cost=cost,affordable=affordable,
          immediate_capacity=room,replacement_slots=replacements}
        out.lines[#out.lines+1]=target_name..' is actually offered now'..(free and ' as a free pack choice.' or ' for $'..tostring(cost or '?')..'.')
        if not affordable then out.warnings[#out.warnings+1]='The observed target is not currently affordable.' end
        if not room then out.warnings[#out.warnings+1]=#replacements>0 and
          'The target needs a replacement; compare the final build before selling.' or
          'No one-sale replacement preserves both Legendaries and enough Joker capacity.' end
      end end
    end
  end
  if action and not owned[later.target_key] then
    local c=action.area and (s[action.area] or {})[action.index]
    local key=c and c.key
    local breaks=action.kind=='reroll' or action.kind=='skip_blind' and (s.skips or 0)>=1 or
      action.kind=='buy' and (action.area=='shop_booster' or action.area=='shop_vouchers' or
        key=='j_ring_master' or c and c.rarity==3 and key~=later.target_key) or
      action.kind=='sell' and action.area=='jokers' and (c and c.rarity==3 or contains(f.legendary_jokers,key)) or
      (action.kind=='use' or action.kind=='choose') and
        (key=='c_judgement' or key=='c_wraith' or key=='c_ankh' or key=='c_soul' and not s.opening_pack)
    if breaks then
      out.proposed_action_changes_path=true
      out.warnings[#out.warnings+1]='The recommended action changes the conditional search path; it may still be needed for survival.'
    end
  end
  if out.status=='conditional' then
    out.lines[#out.lines+1]='Follow the displayed search route. Past actions, affordability and survival are not verified by this forecast.'
  elseif out.status=='incompatible_observation' and not owned[later.target_key] then
    out.lines[1]='Later target: '..target_name..'. The original conditional forecast no longer applies to this observed state.'
  end
  return out
end
return M
