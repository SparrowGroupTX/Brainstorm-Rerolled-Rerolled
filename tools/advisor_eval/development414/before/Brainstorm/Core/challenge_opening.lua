-- Separate, deliberately limited challenge route. Normal deck filters are not
-- consulted. Only explicit in-game search controls may replace a fresh run.
local M = {}
M.legendary = {j_caino='Canio',j_triboulet='Triboulet',j_yorick='Yorick',j_chicot='Chicot',j_perkeo='Perkeo'}
M.profiles = {
  c_omelette_1={5,5,2},c_city_1={5,2,0},c_rich_1={5,0,0},c_knife_1={5,1,0},
  c_xray_1={5,0,0},c_mad_world_1={6,2,0},c_luxury_1={5,0,0},c_non_perishable_1={5,0,0},
  c_medusa_1={5,1,0},c_double_nothing_1={5,0,0},c_typecast_1={5,0,0},c_inflation_1={5,1,0},
  c_bram_poker_1={5,1,0},c_fragile_1={7,2,0},c_monolith_1={6,2,0},c_blast_off_1={4,2,0},
  c_five_card_1={7,2,0},c_golden_needle_1={5,1,0},c_cruelty_1={3,0,0},
}
-- Fixed source Rare pool order. Common/Uncommon eligibility can depend on
-- gameplay-enhancement/death gates and is outside the conditional later route.
M.starting_rows={
  c_omelette_1={{'j_egg'},{'j_egg'},{'j_egg'},{'j_egg'},{'j_egg'}},
  c_city_1={{'j_ride_the_bus',true},{'j_shortcut',true}},c_knife_1={{'j_ceremonial',true,false,true}},
  c_mad_world_1={{'j_pareidolia',true,true},{'j_business',true}},c_medusa_1={{'j_marble',true}},
  c_inflation_1={{'j_credit_card'}},c_bram_poker_1={{'j_vampire',true}},
  c_fragile_1={{'j_oops',true,true},{'j_oops',true,true}},c_monolith_1={{'j_obelisk',true},{'j_marble',true,true}},
  c_blast_off_1={{'j_constellation',true},{'j_rocket',true}},c_five_card_1={{'j_card_sharp'},{'j_joker'}},
  c_golden_needle_1={{'j_credit_card'}},
}
M.rare_order={'j_dna','j_vagabond','j_baron','j_obelisk','j_baseball','j_ancient','j_campfire','j_blueprint',
  'j_wee','j_hit_the_road','j_duo','j_trio','j_family','j_order','j_tribe','j_stuntman','j_invisible',
  'j_brainstorm','j_drivers_license','j_burnt'}
M.rare_names={j_dna='DNA',j_vagabond='Vagabond',j_baron='Baron',j_obelisk='Obelisk',
  j_baseball='Baseball Card',j_ancient='Ancient Joker',j_campfire='Campfire',j_blueprint='Blueprint',
  j_wee='Wee Joker',j_hit_the_road='Hit the Road',j_duo='The Duo',j_trio='The Trio',j_family='The Family',
  j_order='The Order',j_tribe='The Tribe',j_stuntman='Stuntman',j_invisible='Invisible Joker',
  j_brainstorm='Brainstorm',j_drivers_license="Driver's License",j_burnt='Burnt Joker'}
M.rare_keys=M.rare_order
M.later_schedule='first_charm_then_play_all_fixed_rare_pool'
function M.later_choices()
  local choices={};for key,label in pairs(M.rare_names) do choices[#choices+1]={key=key,label=label} end
  table.sort(choices,function(a,b)return a.label<b.label end);return choices
end
function M.later_shop_profile(id)
  if not M.profiles[id] or id=='c_bram_poker_1' then return nil end
  return {joker_rate=20,tarot_rate=4,planet_rate=id=='c_blast_off_1' and 32 or 4,
    playing_card_rate=0,spectral_rate=0,edition_rate=1}
end
function M.later_request(g,config)
  if config.later_enabled==nil or config.later_enabled==false then return nil end
  if config.later_enabled~=true then return nil,'The conditional later-offer setting must be enabled or disabled.' end
  local key,deadline=config.later_target,config.later_ante
  if not M.rare_names[key] then return nil,'Choose a supported Rare Joker for the optional later target.' end
  if type(deadline)~='number' or deadline~=math.floor(deadline) or deadline<2 or deadline>8 then
    return nil,'The later target deadline must be Ante 2 through Ante 8.'
  end
  local game=g and g.GAME or {}
  if game.challenge=='c_bram_poker_1' then return nil,'Bram Poker has no shop Jokers for the optional later target.' end
  local modifiers=game.modifiers
  if type(modifiers)~='table' or modifiers.no_shop_jokers or
    (modifiers.all_eternal~=nil and type(modifiers.all_eternal)~='boolean') or
    (not not modifiers.all_eternal)~=(game.challenge=='c_non_perishable_1') then
    return nil,'The challenge shop-Joker or Eternal rules differ from the conditional route.'
  end
  local forced=g.SETTINGS and g.SETTINGS.tutorial_progress and g.SETTINGS.tutorial_progress.forced_shop
  if forced and (type(forced)~='table' or next(forced)~=nil) or g.load_shop_jokers then
    return nil,'Forced tutorial or saved shop contents are outside the conditional route.'
  end
  if type(game.used_jokers)~='table' or type(game.banned_keys)~='table' then
    return nil,'The live Joker ownership and ban profile is unavailable.'
  end
  local expected_row=M.starting_rows[game.challenge] or {}
  local actual_row=g.jokers and g.jokers.cards or {}
  if #actual_row~=#expected_row then return nil,'The conditional route requires the original starting Joker row.' end
  for i,expected in ipairs(expected_row) do
    local j=actual_row[i];local ability=j.ability or {};local edition=j.edition or {}
    local edition_ok=expected[3] and edition.negative==true and edition.type=='negative' or not expected[3] and next(edition)==nil
    if (j.config and j.config.center or {}).key~=expected[1] or (not not ability.eternal)~=(not not expected[2]) or
      (not not j.pinned)~=(not not expected[4]) or not edition_ok or ability.perishable or ability.rental then
      return nil,'The starting Joker identity, Eternal, edition or pin flags differ from the conditional route.'
    end
  end
  local rates=M.later_shop_profile(game.challenge)
  if not rates or type(game.shop)~='table' or game.shop.joker_max~=2 then
    return nil,'The conditional later route requires the original two shop slots.'
  end
  for field,expected in pairs(rates) do if type(game[field])~='number' or game[field]~=expected then
    return nil,'The live shop rates differ from the supported conditional route.'
  end end
  if type(game.tags)~='table' or next(game.tags)~=nil then return nil,'The conditional later route requires no pending tags.' end
  local pool=g and g.P_JOKER_RARITY_POOLS and g.P_JOKER_RARITY_POOLS[3]
  if type(pool)~='table' or #pool~=#M.rare_order then return nil,'The original 20-card Rare Joker pool is unavailable.' end
  local owned={};for _,j in ipairs(g.jokers and g.jokers.cards or {}) do
    local owned_key=(j.config and j.config.center or {}).key
    if owned_key then owned[owned_key]=true end
  end
  local mask={};local selected
  for i,expected in ipairs(M.rare_order) do
    local center=g.P_CENTERS and g.P_CENTERS[expected]
    if not center or center.key~=expected or center.set~='Joker' or center.rarity~=3 or
      not pool[i] or pool[i]~=center or pool[i].key~=expected or type(center.unlocked)~='boolean' or
      center.enhancement_gate or center.no_pool_flag or center.yes_pool_flag then
      return nil,'The live Rare Joker pool differs from the supported conditional route.'
    end
    if owned[expected] and not (game.used_jokers or {})[expected] then
      return nil,'The starting Rare Joker ownership flags are inconsistent.'
    end
    local available=center.unlocked and not (game.banned_keys or {})[expected] and not (game.used_jokers or {})[expected]
    mask[i]=available and '1' or '0'
    if expected==key then selected=available end
  end
  if not selected then return nil,'The later target is locked, banned or already owned in this challenge.' end
  return {target_key=key,deadline=deadline,rare_pool_mask=table.concat(mask),shop_slots=2,shop_rates=rates}
end
function M.defaults(config)
  if type(config.challenge_opening)~='table' then config.challenge_opening={} end
  local c=config.challenge_opening
  if c.enabled==nil then c.enabled=true end
  if type(c.targets)~='table' then c.targets={'',''} end
  if c.later_enabled==nil then c.later_enabled=false end
  if c.later_target==nil then c.later_target='j_blueprint' end
  if c.later_ante==nil then c.later_ante=2 end
  return c
end
function M.targets(config)
  local targets,seen={},{}
  for i=1,2 do
    local key=(config.targets or {})[i] or ''
    if key~='' then
      if not M.legendary[key] or seen[key] then return nil,'Choose two different Legendary targets, or Any.' end
      targets[#targets+1]=key;seen[key]=true
    end
  end
  return table.concat(targets,',')
end
function M.validate(g,config)
  local game=g and g.GAME
  if not game or not game.challenge then return false,'Start a challenge first.' end
  local profile=M.profiles[game.challenge]
  if not profile then return false,'This opening supports the 19 vanilla challenges with Jokers; Jokerless is excluded.' end
  if not config.enabled then return false,'Enable Challenge opening search in Brainstorm settings.' end
  if game.stake and game.stake~=1 then return false,'This opening route supports the original challenge stake only.' end
  local csv,reason=M.targets(config);if not csv then return false,reason end
  if g.STAGE~=g.STAGES.RUN or g.STATE~=g.STATES.BLIND_SELECT or not g.STATE_COMPLETE or
    game.round~=0 or (game.round_resets or {}).ante~=1 or game.blind_on_deck~='Small' or
    (game.round_resets.blind_states or {}).Small~='Select' or (game.skips or 0)~=0 then
    return false,'Opening search is available only before the first blind of a fresh challenge.'
  end
  if not game.challenge_tab or game.challenge_tab.id~=game.challenge then return false,'The original challenge definition is unavailable.' end
  local banned=game.banned_keys or {}
  if banned.c_soul or banned.tag_charm then return false,'This challenge bans the required Soul or Charm Tag.' end
  for key in pairs(M.legendary) do if banned[key] then return false,'A banned Legendary changes this opening pool.' end end
  for key,value in pairs(banned) do
    if value and key:match('^tag_') and not (game.challenge=='c_fragile_1' and key=='tag_standard') then
      return false,'The challenge tag pool differs from the supported opening.'
    end
  end
  local starting_soul=false
  for _,card in ipairs(g.consumeables and g.consumeables.cards or {}) do
    if (card.config and card.config.center or {}).key=='c_soul' then starting_soul=true end
  end
  if (game.used_vouchers or {}).v_omen_globe or starting_soul or (game.used_jokers or {}).c_soul then
    return false,'This opening requires the original challenge consumables and vouchers.'
  end
  local owned=g.jokers and g.jokers.cards or {}
  if #owned~=profile[2] or not g.jokers or g.jokers.config.card_limit~=profile[1] then
    return false,'Start with the challenge original Joker row and slots.'
  end
  local sellable=0
  for _,card in ipairs(owned) do
    local key=card.config and card.config.center and card.config.center.key
    if M.legendary[key] or key=='j_ring_master' then return false,'The opening requires no starting Legendary or Showman.' end
    if key=='j_egg' and not (card.ability or {}).eternal and not (game.modifiers or {}).all_eternal then sellable=sellable+1 end
  end
  if sellable<profile[3] then return false,'This opening needs two sellable starting Eggs.' end
  local later,later_reason=M.later_request(g,config)
  if later_reason then return false,later_reason end
  return true,csv,later
end

-- Strict small JSON transport parser: native output contains a flat object of
-- strings, positive integers, booleans and a string array. No executable input.
function M.decode(raw)
  if type(raw)~='string' or #raw>4096 then return nil end
  local i=1
  local function ws() local _,last=raw:find('^%s*',i);i=(last or i-1)+1 end
  local function string_value()
    ws();if raw:sub(i,i)~='"' then return nil end
    local last=raw:find('"',i+1,true);if not last then return nil end
    local value=raw:sub(i+1,last-1)
    if value:find('[\\%c]') then return nil end
    i=last+1;return value
  end
  local function value()
    ws();local c=raw:sub(i,i)
    if c=='"' then return string_value() end
    if c=='[' then
      i=i+1;ws();local out={}
      if raw:sub(i,i)==']' then i=i+1;return out end
      for _=1,8 do
        local item=string_value();if item==nil then return nil end
        out[#out+1]=item;ws();c=raw:sub(i,i);i=i+1
        if c==']' then return out elseif c~=',' then return nil end
      end
      return nil
    end
    if raw:sub(i,i+3)=='true' then i=i+4;return true end
    if raw:sub(i,i+4)=='false' then i=i+5;return false end
    local digits=raw:match('^%d+',i)
    if digits then i=i+#digits;return tonumber(digits) end
  end
  ws();if raw:sub(i,i)~='{' then return nil end;i=i+1
  local out,seen={},{}
  for _=1,24 do
    local key=string_value();if not key or seen[key] then return nil end
    seen[key]=true;ws();if raw:sub(i,i)~=':' then return nil end;i=i+1
    local v=value();if v==nil then return nil end;out[key]=v
    ws();local c=raw:sub(i,i);i=i+1
    if c=='}' then ws();if i<=#raw then return nil end;return out end
    if c~=',' then return nil end
  end
end
local function seed_valid(seed,empty) return type(seed)=='string' and #seed<9 and (#seed>0 or empty) and not seed:find('[^1-9A-Z]') end
function M.result(raw,id,csv,later)
  local r=M.decode(raw);local p=M.profiles[id]
  if not r or not p then return nil,'Malformed opening search response.' end
  if r.status=='invalid' or r.status=='error' then return nil,type(r.reason)=='string' and r.reason or 'Opening search failed.' end
  if r.challenge_id~=id or r.first_tag~='tag_charm' or r.multi_soul_exception~=true or
    r.required_sales~=p[3] or r.starting_joker_count~=p[2] or r.starting_joker_limit~=p[1] or
    type(r.search_limit)~='number' or r.search_limit<1 or r.search_limit>1000000 then
    return nil,'Opening response does not match this challenge.'
  end
  if later then
    if r.api_version~=2 or r.later_target~=later.target_key or r.later_deadline~=later.deadline or
      r.later_pool_mask~=later.rare_pool_mask or r.later_source~='shop_initial' or
      r.later_schedule~=M.later_schedule or r.later_offer_status~='conditional' or r.later_retention~='not_verified' then
      return nil,'The conditional later-offer response does not match this request and live pool.'
    end
    if r.status=='found' and (type(r.later_found_ante)~='number' or r.later_found_ante<1 or
      r.later_found_ante>math.min(later.deadline,id=='c_typecast_1' and 4 or 8) or
      type(r.later_shop)~='number' or r.later_shop<1 or r.later_shop>(r.later_found_ante==1 and 1 or 3) or
      type(r.later_slot)~='number' or r.later_slot<1 or r.later_slot>2 or
      not ({base=true,foil=true,holo=true,polychrome=true,negative=true})[r.later_edition] or type(r.later_eternal)~='boolean') then
      return nil,'The conditional later offer is incomplete or outside its deadline.'
    end
  end
  if r.status=='not_found' and seed_valid(r.next_seed,true) then return r end
  if r.status~='found' or not seed_valid(r.seed) or type(r.soul_count)~='number' or r.soul_count<2 or r.soul_count>5 or
    type(r.legendary_jokers)~='table' or #r.legendary_jokers~=2 then return nil,'Incomplete opening result.' end
  local a,b=r.legendary_jokers[1],r.legendary_jokers[2]
  if not M.legendary[a] or not M.legendary[b] or a==b then return nil,'Invalid Legendary pair.' end
  for key in (csv or ''):gmatch('[^,]+') do if key~=a and key~=b then return nil,'Opening missed a requested Legendary.' end end
  return r
end
function M.later_plan(result)
  if not result or result.status~='found' or result.api_version~=2 or not M.rare_names[result.later_target] or
    type(result.later_pool_mask)~='string' or #result.later_pool_mask~=#M.rare_order or result.later_pool_mask:find('[^01]') then return nil end
  local rates=M.later_shop_profile(result.challenge_id);if not rates then return nil end
  local pool_keys={};for i,key in ipairs(M.rare_order) do if result.later_pool_mask:sub(i,i)=='1' then pool_keys[#pool_keys+1]=key end end
  -- Copy scalar metadata only: later UI/advisor changes must not mutate the
  -- validated response or turn a conditional offer into acquisition evidence.
  return {api_version=2,target_key=result.later_target,deadline=result.later_deadline,
    rare_pool_mask=result.later_pool_mask,rare_pool_keys=pool_keys,shop_slots=2,shop_rates=rates,source=result.later_source,schedule=result.later_schedule,
    offer_status=result.later_offer_status,retention=result.later_retention,
    found_ante=result.later_found_ante,shop=result.later_shop,slot=result.later_slot,
    edition=result.later_edition,eternal=result.later_eternal,acquisition_verified=false,retention_verified=false}
end
local function signature(game,csv,later)
  return game.challenge..':'..csv..(later and ':'..later.target_key..':'..later.deadline..':'..later.rare_pool_mask or '')
end
function M.matching_pack(game,pack)
  local f=game and game.filter_info
  if not f or not f.challenge_opening then return true end -- Existing normal-deck exception unchanged.
  return game.challenge==f.challenge_id and game.round==0 and (game.round_resets or {}).ante==1 and
    (game.round_resets.blind_states or {}).Small=='Skipped' and game.blind_on_deck=='Big'
end

-- One action at a time: skip the searched tag, then make space only when the
-- Soul is visible. This never sells an Egg for a hypothetical future pack.
function M.advice(s)
  local f=s.filter_info
  if not f or not f.challenge_opening or f.challenge_id~=s.challenge or s.round~=0 or s.ante~=1 then return nil end
  if s.phase=='blind' and s.blind_on_deck=='Small' and not f.multi_soul_pack_consumed and
    (s.skip_tags or {}).Small=='tag_charm' then
    return {title='Skip Small Blind for the two-Soul opening',lines={'Choose both Souls from the searched Charm pack. Make Joker space when prompted.'},warnings={},action={kind='skip_blind',blind='Small'}}
  end
  if s.phase~='pack' or not s.opening_pack or not f.multi_soul_pack_consumed then return nil end
  for index,card in ipairs(s.pack_cards or {}) do if card.key=='c_soul' then
    if #(s.jokers or {})>=s.joker_limit then
      for j,owned in ipairs(s.jokers or {}) do
        if owned.key=='j_egg' and not (owned.ability or {}).eternal and not (s.modifiers or {}).all_eternal then
          return {title='Sell an Egg to make room for The Soul',lines={'Keep the other Eggs; this sale makes one slot for a visible Legendary.'},warnings={},action={kind='sell',area='jokers',index=j}}
        end
      end
      return nil
    end
    return {title='Choose The Soul for a Legendary Joker',lines={'Use the next Soul, then reassess the remaining pack choice.'},warnings={},action={kind='choose',area='pack_cards',index=index,targets={}}}
  end end
end

local function new_session(game,csv,later)
  return {game=game,signature=signature(game,csv,later),mode=later and 'conditional_later' or 'opening_only',
    batches=0,misses=0,timed_batches=0,measured_native_seconds=0,native_seconds_known=true}
end
local function search_record(session,status,reason)
  return {status=status,reason=reason,challenge_id=session.game.challenge,mode=session.mode,
    start_cursor=session.start_cursor,end_cursor=session.end_cursor,batches=session.batches,misses=session.misses,
    timed_batches=session.timed_batches,measured_native_seconds=session.measured_native_seconds,
    native_seconds_known=session.native_seconds_known,
    native_seconds=session.native_seconds_known and session.measured_native_seconds or nil,
    scope='Native-call time and batch counts; excludes gameplay/setup and does not count evaluated seeds.'}
end
function M.attach(brainstorm,dependencies)
  brainstorm.ChallengeOpening=M
  M.defaults(brainstorm.config)
  function brainstorm.validateChallengeOpening() return M.validate(G,M.defaults(brainstorm.config)) end
  local function now()
    local clock=dependencies.now or (love and love.timer and love.timer.getTime)
    if type(clock)~='function' then return nil end
    local ok,value=pcall(clock)
    if ok and type(value)=='number' and value==value and value>=0 and value<math.huge then return value end
  end
  function brainstorm.stopChallengeOpeningSearch(status,reason)
    if M.session then M.last_search=search_record(M.session,status or 'stopped',reason) end
    brainstorm.ar_active=false;brainstorm.ar_frames=0;brainstorm.ar_timer=0;M.session=nil
    if brainstorm.ar_text then
      brainstorm.removeAttentionText(brainstorm.ar_text);brainstorm.ar_text=nil
    end
  end
  function brainstorm.startChallengeOpeningSearch()
    local ok,reason,later=brainstorm.validateChallengeOpening()
    if not ok then dependencies.alert(reason);return false end
    if M.session then brainstorm.stopChallengeOpeningSearch('replaced') end
    M.session=new_session(G.GAME,reason,later);M.last_search=search_record(M.session,'searching')
    brainstorm.ar_frames=0;brainstorm.ar_timer=0;brainstorm.ar_active=true
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    return true
  end
  function brainstorm.challengeOpeningSearch(initial_seed)
    if not brainstorm.ar_active then return nil end
    local valid,csv,later=brainstorm.validateChallengeOpening()
    local function fail(reason)
      brainstorm.stopChallengeOpeningSearch('error',reason);dependencies.alert(reason);return nil
    end
    if not valid then return fail(csv) end
    local game=G.GAME;local query_signature=signature(game,csv,later)
    if M.session and (M.session.game~=game or M.session.signature~=query_signature) then return fail('The challenge changed; start opening search again.') end
    M.session=M.session or new_session(game,csv,later)
    if not M.session.started then M.session.started=true;M.session.seed=initial_seed;M.session.start_cursor=initial_seed or '' end
    M.session.end_cursor=M.session.seed or '';M.session.batches=M.session.batches+1
    local before=now()
    local ok,raw
    if later then ok,raw=pcall(dependencies.search,M.session.seed,game.challenge,csv,later)
    else ok,raw=pcall(dependencies.search,M.session.seed,game.challenge,csv) end
    local after=now()
    if before and after and after>=before then
      M.session.measured_native_seconds=M.session.measured_native_seconds+after-before;M.session.timed_batches=M.session.timed_batches+1
    else M.session.native_seconds_known=false end
    if not ok then return fail('Opening search unavailable: '..tostring(raw)) end
    local result,reason=M.result(raw,game.challenge,csv,later)
    if not result then return fail(reason) end
    if result.status=='not_found' then
      M.session.seed=result.next_seed;M.session.end_cursor=result.next_seed;M.session.misses=M.session.misses+1
      M.last_search=search_record(M.session,'searching');return nil
    end
    M.session.end_cursor=result.seed
    -- Recheck immediately before the sole mutation. The challenge definition
    -- object is retained, including all deck/rule/restriction/start parameters.
    local current_later
    valid,reason,current_later=brainstorm.validateChallengeOpening()
    if not valid or G.GAME~=game then return fail(reason or 'The run changed.') end
    if signature(game,reason,current_later)~=query_signature then return fail('The opening targets or live Rare pool changed; search again.') end
    local definition,stake=game.challenge_tab,game.stake or 1
    brainstorm.stopChallengeOpeningSearch('found')
    local search={};for key,value in pairs(M.last_search or {}) do search[key]=value end
    G:delete_run();G:start_run({stake=stake,seed=result.seed,challenge=definition})
    G.GAME.used_filter=true
    G.GAME.filter_info={challenge_opening=true,challenge_id=result.challenge_id,native_api_version=later and 'challenge_opening_v2' or 'challenge_opening_v1',
      required_soul_count=2,soul_count=result.soul_count,legendary_jokers=result.legendary_jokers,
      required_sales=result.required_sales,multi_soul_pack_consumed=false,later=M.later_plan(result),search=search}
    G.GAME.seeded=false -- Same filtered-run handling as the existing reroller.
    return result.seed
  end
end
return M
