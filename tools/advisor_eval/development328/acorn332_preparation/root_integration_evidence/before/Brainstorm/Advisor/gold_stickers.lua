-- Read only the active, already-loaded profile. This module never loads a save,
-- invokes game callbacks, changes collection flags, or infers a future win.
-- Vanilla keys: preserved source_profiles254_auditable/source_default_jokers.json.
-- History: preserved planet_pool_source1/source/functions/misc_functions.lua
-- 1034-1069 records joker_usage[key].wins[stake] for Jokers held at the win.
local M={}
local keys={}
for key in ([=[
j_joker j_greedy_joker j_lusty_joker j_wrathful_joker j_gluttenous_joker j_jolly j_zany j_mad j_crazy j_droll
j_sly j_wily j_clever j_devious j_crafty j_half j_stencil j_four_fingers j_mime j_credit_card
j_ceremonial j_banner j_mystic_summit j_marble j_loyalty_card j_8_ball j_misprint j_dusk j_raised_fist j_chaos
j_fibonacci j_steel_joker j_scary_face j_abstract j_delayed_grat j_hack j_pareidolia j_gros_michel j_even_steven j_odd_todd
j_scholar j_business j_supernova j_ride_the_bus j_space j_egg j_burglar j_blackboard j_runner j_ice_cream
j_dna j_splash j_blue_joker j_sixth_sense j_constellation j_hiker j_faceless j_green_joker j_superposition j_todo_list
j_cavendish j_card_sharp j_red_card j_madness j_square j_seance j_riff_raff j_vampire j_shortcut j_hologram
j_vagabond j_baron j_cloud_9 j_rocket j_obelisk j_midas_mask j_luchador j_photograph j_gift j_turtle_bean
j_erosion j_reserved_parking j_mail j_to_the_moon j_hallucination j_fortune_teller j_juggler j_drunkard j_stone j_golden
j_lucky_cat j_baseball j_bull j_diet_cola j_trading j_flash j_popcorn j_trousers j_ancient j_ramen
j_walkie_talkie j_selzer j_castle j_smiley j_campfire j_ticket j_mr_bones j_acrobat j_sock_and_buskin j_swashbuckler
j_troubadour j_certificate j_smeared j_throwback j_hanging_chad j_rough_gem j_bloodstone j_arrowhead j_onyx_agate j_glass
j_ring_master j_flower_pot j_blueprint j_wee j_merry_andy j_oops j_idol j_seeing_double j_matador j_hit_the_road
j_duo j_trio j_family j_order j_tribe j_stuntman j_invisible j_brainstorm j_satellite j_shoot_the_moon
j_drivers_license j_cartomancer j_astronomer j_burnt j_bootstraps j_caino j_triboulet j_yorick j_chicot j_perkeo
]=]):gmatch('%S+') do keys[#keys+1]=key end
table.sort(keys)
local vanilla={};for _,key in ipairs(keys) do vanilla[key]=true end
local function get(t,key) if type(t)=='table' then return rawget(t,key) end end
local function plain(t) return type(t)=='table' and getmetatable(t)==nil end
local function integer(n,low,high)
  return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge and n%1==0 and n>=low and (not high or n<=high)
end
local function profile_id(id)
  return type(id)=='string' and id~='' or integer(id,1)
end
function M.target_keys()
  local out={};for i,key in ipairs(keys) do out[i]=key end;return out
end
local function counts_valid(t)
  if not plain(t) then return false end
  for stake,count in next,t do
    if not integer(stake,1,8) or not integer(count,1) then return false end
  end
  return true
end
local function history_status(entry)
  if entry==nil then return 'missing' end
  if not plain(entry) then return 'unknown','malformed_joker_history' end
  -- A recorded row must retain the source's count/order and wins table. An
  -- absent row is a known absence only after the full loaded table is checked.
  if not integer(get(entry,'count'),1) or not integer(get(entry,'order'),1) or not counts_valid(get(entry,'wins')) then
    return 'unknown','malformed_joker_history'
  end
  local losses=get(entry,'losses')
  if losses~=nil and not counts_valid(losses) then return 'unknown','malformed_joker_history' end
  return get(entry.wins,8) and 'complete' or 'missing'
end
local function catalog_status(catalog,key)
  local center=get(catalog,key)
  if type(center)~='table' or get(center,'key')~=key or get(center,'set')~='Joker' then
    return false,'unavailable_vanilla_center'
  end
  if get(center,'mod')~=nil or get(center,'mod_id')~=nil then return false,'modified_vanilla_center' end
  return true
end
local function stake_status(g)
  -- The loaded vanilla catalog, not a user-selected label, establishes which
  -- recorded numeric stake means Gold. Public upstream game.lua corroborates
  -- P_STAKES.stake_gold={set='Stake',order=8,stake_level=8}; this is metadata
  -- validation, not qualification of the installed game's scoring behavior.
  local stakes=get(g,'P_STAKES');local gold=get(stakes,'stake_gold')
  if not plain(stakes) or type(gold)~='table' then return 'unknown','gold_stake_catalog_unavailable' end
  local levels,total={},0
  for key,stake in next,stakes do
    local level=get(stake,'stake_level');local order=get(stake,'order')
    if type(key)~='string' or get(stake,'set')~='Stake' or not integer(level,1,8) or levels[level] or
      order~=level or get(stake,'mod')~=nil or get(stake,'mod_id')~=nil then return 'unsupported','modified_stake_catalog' end
    levels[level]=true;total=total+1
  end
  if total~=8 or get(gold,'stake_level')~=8 or get(gold,'order')~=8 then return 'unsupported','modified_gold_stake_mapping' end
  local pool=get(get(g,'P_CENTER_POOLS'),'Stake')
  if pool~=nil then
    if not plain(pool) then return 'unsupported','malformed_stake_pool' end
    local pool_levels,pool_count={},0
    for index,stake in next,pool do
      local level=get(stake,'stake_level');local key=get(stake,'key')
      if not integer(index,1,8) or get(stake,'set')~='Stake' or not integer(level,1,8) or pool_levels[level] or
        get(stake,'order')~=level or get(stake,'mod')~=nil or get(stake,'mod_id')~=nil or
        level==8 and key~=nil and key~='stake_gold' then return 'unsupported','modified_stake_pool' end
      pool_levels[level]=true;pool_count=pool_count+1
    end
    if pool_count~=8 then return 'unsupported','incomplete_stake_pool' end
  end
  local stickers=get(g,'sticker_map')
  -- Vanilla game.lua uses display names ('White', ... 'Gold'), not
  -- lowercase catalog suffixes. Requiring 'gold' rejected every vanilla row.
  if stickers~=nil and get(stickers,8)~='Gold' then return 'unsupported','modified_gold_sticker_map' end
  return 'complete'
end
local function run_eligibility(g,result)
  local reasons={};local status='eligible'
  local function add(kind,why)
    reasons[#reasons+1]=why
    if status=='eligible' or kind=='ineligible' or status=='unknown' and kind=='unsupported' then status=kind end
  end
  local stage,run_stage=get(g,'STAGE'),get(get(g,'STAGES'),'RUN')
  local function stage_value(v) return type(v)=='string' and v~='' or integer(v,0) end
  if not stage_value(stage) or not stage_value(run_stage) then add('unknown','run_stage_unavailable')
  elseif stage~=run_stage then add('ineligible','outside_run_stage') end
  local game=get(g,'GAME')
  if type(game)~='table' then add('unknown','run_unavailable')
  else
    local stake=get(game,'stake')
    if not integer(stake,1,8) then add('unsupported','unsupported_stake')
    elseif stake~=8 then add('ineligible','not_gold_stake') end
    if get(game,'challenge') then add('ineligible','challenge_run') end
    local seeded,won=get(game,'seeded'),get(game,'won')
    if seeded~=nil and type(seeded)~='boolean' then add('unknown','seeded_flag_malformed')
    elseif seeded then add('ineligible','seeded_run') end
    if won~=nil and type(won)~='boolean' then add('unknown','win_flag_malformed')
    elseif won then add('ineligible','run_already_won') end
    local ante=get(get(game,'round_resets'),'ante');local win_ante=get(game,'win_ante')
    if not integer(ante,1) or not integer(win_ante,1) then add('unknown','ante_progress_unavailable')
    elseif ante>win_ante then add('ineligible','past_winning_ante') end
  end
  if result.stake_status~='complete' then add(result.stake_status,result.stake_reason) end
  if result.catalog_status~='complete' then
    add(result.catalog_status=='unsupported' and 'unsupported' or 'unknown','vanilla_joker_catalog_unverified')
  end
  if result.metadata_status~='complete' then add('unknown','loaded_profile_history_unavailable') end
  if result.held_status~='complete' then
    add(result.held_status=='unsupported' and 'unsupported' or 'unknown','held_inventory_'..result.held_status)
  end
  local eligible
  if status=='eligible' then eligible=true elseif status=='ineligible' then eligible=false end
  return {status=status,eligible=eligible,reasons=reasons}
end
function M.capture(g,options)
  -- Explicit opt-in is required before even reading the supplied game object.
  if get(options,'enabled')~=true then return nil end
  local result={schema=1,goal='gold_stickers',counts={total=#keys,complete=0,missing=0,unknown=0},
    targets={},by_key={},held_keys={},held_target_keys={},held_unknown_keys={},held_status='complete',
    metadata_status='unavailable',catalog_status='complete',scope='Loaded active-profile vanilla Gold sticker history; holding a target is not a completed win.'}
  local id=get(get(g,'SETTINGS'),'profile')
  local profile
  if profile_id(id) then result.profile_id=id;profile=get(get(g,'PROFILES'),id) end
  local usage=get(profile,'joker_usage')
  if type(profile)=='table' and plain(usage) then
    result.metadata_status='complete'
    for key in next,usage do
      if type(key)~='string' or key=='' then result.metadata_status='malformed';break end
    end
  elseif usage~=nil then result.metadata_status='malformed' end
  result.stake_status,result.stake_reason=stake_status(g)
  local catalog=get(g,'P_CENTERS')
  for _,key in ipairs(keys) do
    local ok,why=catalog_status(catalog,key)
    local status,reason='unknown','loaded_profile_history_unavailable'
    if not ok then
      reason=why;result.catalog_status=why=='modified_vanilla_center' and 'unsupported' or result.catalog_status=='unsupported' and 'unsupported' or 'incomplete'
    elseif result.stake_status~='complete' then reason=result.stake_reason
    elseif result.metadata_status=='complete' then status,reason=history_status(get(usage,key)) end
    local row={key=key,status=status,reason=reason}
    result.targets[#result.targets+1]=row;result.by_key[key]=row;result.counts[status]=result.counts[status]+1
  end
  local held=get(get(g,'jokers'),'cards');local held_keys={}
  if type(held)~='table' then result.held_status='unavailable'
  else
    local size=0
    for index in next,held do
      if not integer(index,1) then result.held_status='malformed';break end
      size=size+1
    end
    for index=1,size do
      local card=get(held,index);local key=get(get(card,'config'),'center_key')
      if type(card)~='table' or get(get(card,'ability'),'set')~='Joker' or type(key)~='string' then result.held_status='malformed'
      elseif vanilla[key] then held_keys[key]=true
      elseif result.held_status=='complete' then result.held_status='unsupported' end
    end
  end
  for _,key in ipairs(keys) do if held_keys[key] then
    result.held_keys[#result.held_keys+1]=key
    local status=result.by_key[key].status
    if status=='missing' then result.held_target_keys[#result.held_target_keys+1]=key
    elseif status=='unknown' then result.held_unknown_keys[#result.held_unknown_keys+1]=key end
  end end
  result.held_target_count=#result.held_target_keys
  result.eligibility=run_eligibility(g,result)
  return result
end
return M
