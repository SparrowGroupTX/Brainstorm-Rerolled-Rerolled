-- Public first-Charm route for an explicitly searched normal deck. This module
-- never searches, generates a Joker, assumes a future purchase, or reads saves.
local M={schema=1,kind='normal_two_soul_v1'}
local decks={b_red='Red Deck',b_blue='Blue Deck',b_yellow='Yellow Deck',b_green='Green Deck',b_black='Black Deck',
  b_magic='Magic Deck',b_nebula='Nebula Deck',b_ghost='Ghost Deck',b_abandoned='Abandoned Deck',b_checkered='Checkered Deck',
  b_zodiac='Zodiac Deck',b_painted='Painted Deck',b_anaglyph='Anaglyph Deck',b_plasma='Plasma Deck',b_erratic='Erratic Deck'}
local legendary={j_caino=true,j_triboulet=true,j_yorick=true,j_chicot=true,j_perkeo=true}
local locations={ante_1=true,soul_pack=true,ante_2=true,soul_or_ante_2=true,ante_3=true,ante_4=true,
  by_ante_2=true,by_ante_3=true,by_ante_4=true,by_ante_5=true,by_ante_6=true,by_ante_7=true,by_ante_8=true}
local function integer(v,lo,hi) return type(v)=='number' and v==v and v%1==0 and v>=lo and (not hi or v<=hi) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function list(v,maximum)
  if type(v)~='table' or getmetatable(v) then return false end
  local count=0;for k in pairs(v) do if not integer(k,1,maximum) then return false end;count=count+1 end
  if count~=#v or #v>maximum then return false end
  return true
end
local function split(value)
  if type(value)~='string' or #value>512 then return nil end
  local result={};for part in (value..'\31'):gmatch('([^\31]*)\31') do result[#result+1]=part end
  return #result==5 and result or nil
end
local function registry()
  if not M.gold_stickers or not M.gold_stickers.target_keys or not M.gold_search or not M.gold_search.name then return nil end
  local keys,names={},{}
  for _,key in ipairs(M.gold_stickers.target_keys()) do
    local name=M.gold_search.name(key)
    if not name or names[name] then return nil end
    keys[key]=true;names[name]=key
  end
  return keys,names
end
local function validate_targets(targets,known)
  if not list(targets,5) or #targets<2 then return nil,'The declared target list is unavailable.' end
  local count,seen,opening=0,{},{}
  for _,target in ipairs(targets) do
    if type(target)~='table' or not known[target.key] or seen[target.key] or not locations[target.location] or
        (target.edition~='any' and target.edition~='negative') then return nil,'Invalid or repeated target identity, timing or edition.' end
    seen[target.key]=true
    if legendary[target.key] then
      if target.location~='soul_pack' and target.location~='ante_1' and target.location~='soul_or_ante_2' then
        return nil,'A Legendary target must come from the starting Charm pack.'
      end
      count=count+1;opening[#opening+1]=target.key
    elseif target.location=='soul_pack' then return nil,'Two Souls leave no third starting-pack choice.' end
  end
  if count~=2 then return nil,'This route requires two distinct declared starting Legendary targets.' end
  return opening
end
function M.parse_filter(f,deck_key,stake,live_seed)
  if type(f)~='table' or f.challenge_opening or f.jokerless_opening or not decks[deck_key] or not integer(stake,1,8) or
      type(live_seed)~='string' or live_seed=='' or #live_seed>16 then return nil,'The current normal-deck run binding is unavailable.' end
  local known,names=registry();if not known then return nil,'The native target-name registry is unavailable.' end
  local recipe,seed
  if type(f.normal_opening)=='table' then
    local declared=f.normal_opening
    if declared.schema~=1 or declared.kind~=M.kind or declared.deck_key~=deck_key or declared.stake~=stake or
        declared.required_souls~=2 or type(declared.no_perishable_targets)~='boolean' then
      return nil,'The explicit normal opening recipe differs from this deck or stake.'
    end
    if not list(declared.targets,5) then return nil,'The explicit target list is malformed.' end
    recipe={targets={}}
    for _,target in ipairs(declared.targets) do
      if type(target)~='table' then return nil,'A declared target is malformed.' end
      recipe.targets[#recipe.targets+1]={key=target.key,location=target.location,edition=target.edition or 'any'}
    end
    recipe.no_perishable_targets=declared.no_perishable_targets;seed=declared.seed
  else
    local p=f.filter_params
    if f.native_api_version~=8 or f.deck_name~=decks[deck_key] or f.stake_level~=stake or f.required_soul_count~=2 or
        not integer(f.soul_count,0,2) or type(f.no_perishable_jokers)~='boolean' or type(p)~='table' then
      return nil,'A complete API 8 two-Soul normal filter receipt is required.'
    end
    -- The receipt duplicates these native arguments. Reject mixed or stale
    -- fields rather than silently choosing whichever version is convenient.
    if p[5]~=f.soul_count or p[18]~=f.joker_targets or p[19]~=f.deck_name or p[20]~=f.joker_target_locations or
        p[21]~=f.stake_level or p[22]~=f.no_perishable_jokers then return nil,'The native filter receipt is internally inconsistent.' end
    local target_names,timing=split(f.joker_targets),split(f.joker_target_locations)
    if not target_names or not timing then return nil,'The native target fields are malformed.' end
    recipe={targets={},no_perishable_targets=f.no_perishable_jokers};seed=p[1]
    for i,name in ipairs(target_names) do
      if not locations[timing[i]] then return nil,'Unknown native target timing.' end
      if name~='' then
        local edition='any'
        if name:sub(-2)=='\30N' then name=name:sub(1,-3);edition='negative' end
        local key=names[name];if not key then return nil,'Unknown native Joker target name.' end
        recipe.targets[#recipe.targets+1]={key=key,location=timing[i],edition=edition}
      end
    end
  end
  if seed~=live_seed then return nil,'The opening receipt belongs to a different run.' end
  local opening,why=validate_targets(recipe.targets,known);if not opening then return nil,why end
  if type(f.multi_soul_pack_consumed)~='boolean' then return nil,'The one-use opening-pack marker is unavailable.' end
  recipe.schema=1;recipe.kind=M.kind;recipe.deck_key=deck_key;recipe.stake=stake
  recipe.required_souls=2;recipe.legendary_targets=opening;recipe.bound_to_run=true
  recipe.multi_soul_pack_consumed=f.multi_soul_pack_consumed
  -- Seed and search timing are intentionally absent from policy observations.
  return recipe
end
function M.capture(g)
  local game=g and g.GAME
  if not game or game.challenge or game.used_filter~=true then return nil end
  local back=game.selected_back and game.selected_back.effect and game.selected_back.effect.center or {}
  local recipe,why=M.parse_filter(game.filter_info,back.key,game.stake,(game.pseudorandom or {}).seed)
  if not recipe then return nil,why end
  local buffer=game.joker_buffer
  if buffer==nil then buffer=0 end
  if not integer(buffer,0,20) then return nil,'The pending Joker count is unavailable.' end
  recipe.joker_buffer=buffer
  recipe.pack_marked=not not (g.pack_cards and g.pack_cards.brainstorm_normal_opening)
  return recipe
end
local function negative(card) return type(card.edition)=='table' and card.edition.negative==true end
local function action(title,lines,move,route)
  return {title=title,lines=lines,warnings={},action=move,normal_opening={scope='observed_first_charm',
    required_souls=2,targets=copy(route.legendary_targets),future_acquisition_verified=false}}
end
function M.advice(s)
  local route=s and s.normal_opening
  if not route or route.schema~=1 or route.kind~=M.kind or not route.bound_to_run or s.challenge or
      route.deck_key~=s.deck_key or route.stake~=s.stake or route.required_souls~=2 or
      s.round~=0 or s.ante~=1 or route.joker_buffer~=0 then return nil end
  local known=registry();if not known then return nil end
  local targets=validate_targets(route.targets,known);if not targets then return nil end
  if not list(route.legendary_targets,2) or #route.legendary_targets~=2 or
      targets[1]~=route.legendary_targets[1] or targets[2]~=route.legendary_targets[2] then return nil end
  if not integer(s.joker_limit,0,20) or type(s.jokers)~='table' or #s.jokers>2 then return nil end
  if type(route.no_perishable_targets)~='boolean' or type(route.multi_soul_pack_consumed)~='boolean' then return nil end
  local owned={}
  for _,card in ipairs(s.jokers) do
    local requested
    for _,target in ipairs(route.targets) do if target.key==card.key and legendary[target.key] then requested=target end end
    local a=card.ability or {}
    if not requested or owned[card.key] or card.unknown or card.face_down or card.debuff or a.perma_debuff or
        (route.no_perishable_targets and a.perishable) or (requested.edition=='negative' and not negative(card)) then return nil end
    owned[card.key]=true
  end
  -- Held consumables are not spent and need no free slot: a pack Soul is used
  -- immediately. A held Soul, however, changes the opening's duplicate history.
  for _,card in ipairs(s.consumeables or {}) do
    if card.key=='c_soul' or card.unknown or card.face_down then return nil end
  end
  if s.phase=='blind' then
    if s.blind_on_deck~='Small' or (s.blind_states or {}).Small~='Select' or s.skips~=0 or
        route.multi_soul_pack_consumed or #s.jokers~=0 or s.joker_limit<2 then return nil end
    local tag=(s.skip_tags or {}).Small;if type(tag)=='table' then tag=tag.key end
    if tag~='tag_charm' then return nil end
    return action('Skip Small Blind for the searched Legendary opening',{
      'The visible Charm Tag opens the declared two-Soul pack. Choose the visible Souls one at a time.',
      'Later searched offers still require cash, room and survival; this opening does not guarantee their acquisition.'},
      {kind='skip_blind',blind='Small'},route)
  end
  if s.phase~='pack' or not route.pack_marked or not route.multi_soul_pack_consumed or s.skips~=1 or
      s.blind_on_deck~='Big' or (s.blind_states or {}).Small~='Skipped' or
      (s.pack_type~='TAROT_PACK' and s.pack_type~='SPECTRAL_PACK') or
      not integer(s.pack_choices,1,2) or #s.jokers~=2-s.pack_choices or #s.jokers>=s.joker_limit then return nil end
  for index,card in ipairs(s.pack_cards or {}) do
    local a=card.ability or {}
    if card.key=='c_soul' and a.name=='The Soul' and a.set=='Spectral' and type(a.consumeable)=='table' and
        not card.debuff and not card.unknown and not card.face_down and not card.edition then
      return action('Choose the visible Soul for the searched opening',{
        'This immediately uses one visible Soul in an available Joker slot. Refresh after the Legendary appears.',
        'The next decision checks the actual acquired Joker before spending the remaining pack choice.'},
        {kind='choose',area='pack_cards',index=index,targets={}},route)
    end
  end
end
return M
