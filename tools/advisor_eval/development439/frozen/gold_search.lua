-- Prepare existing normal-reroll filters from detached Gold progress, only on
-- an explicit click. No game, profile, save, native, search or config callbacks.
-- Source names: preserved runs/roi247_catalog_source/source_probe.lua (150
-- source centers). Three native/UI spellings follow Immolate/src/items.hpp:
-- Caino -> Canio, Seance -> Seance with acute accent, Riff-raff -> Riff-Raff.
local M={}
local names={}
for line in ([=[
j_8_ball=8 Ball
j_abstract=Abstract Joker
j_acrobat=Acrobat
j_ancient=Ancient Joker
j_arrowhead=Arrowhead
j_astronomer=Astronomer
j_banner=Banner
j_baron=Baron
j_baseball=Baseball Card
j_blackboard=Blackboard
j_bloodstone=Bloodstone
j_blue_joker=Blue Joker
j_blueprint=Blueprint
j_bootstraps=Bootstraps
j_brainstorm=Brainstorm
j_bull=Bull
j_burglar=Burglar
j_burnt=Burnt Joker
j_business=Business Card
j_caino=Canio
j_campfire=Campfire
j_card_sharp=Card Sharp
j_cartomancer=Cartomancer
j_castle=Castle
j_cavendish=Cavendish
j_ceremonial=Ceremonial Dagger
j_certificate=Certificate
j_chaos=Chaos the Clown
j_chicot=Chicot
j_clever=Clever Joker
j_cloud_9=Cloud 9
j_constellation=Constellation
j_crafty=Crafty Joker
j_crazy=Crazy Joker
j_credit_card=Credit Card
j_delayed_grat=Delayed Gratification
j_devious=Devious Joker
j_diet_cola=Diet Cola
j_dna=DNA
j_drivers_license=Driver's License
j_droll=Droll Joker
j_drunkard=Drunkard
j_duo=The Duo
j_dusk=Dusk
j_egg=Egg
j_erosion=Erosion
j_even_steven=Even Steven
j_faceless=Faceless Joker
j_family=The Family
j_fibonacci=Fibonacci
j_flash=Flash Card
j_flower_pot=Flower Pot
j_fortune_teller=Fortune Teller
j_four_fingers=Four Fingers
j_gift=Gift Card
j_glass=Glass Joker
j_gluttenous_joker=Gluttonous Joker
j_golden=Golden Joker
j_greedy_joker=Greedy Joker
j_green_joker=Green Joker
j_gros_michel=Gros Michel
j_hack=Hack
j_half=Half Joker
j_hallucination=Hallucination
j_hanging_chad=Hanging Chad
j_hiker=Hiker
j_hit_the_road=Hit the Road
j_hologram=Hologram
j_ice_cream=Ice Cream
j_idol=The Idol
j_invisible=Invisible Joker
j_joker=Joker
j_jolly=Jolly Joker
j_juggler=Juggler
j_loyalty_card=Loyalty Card
j_luchador=Luchador
j_lucky_cat=Lucky Cat
j_lusty_joker=Lusty Joker
j_mad=Mad Joker
j_madness=Madness
j_mail=Mail-In Rebate
j_marble=Marble Joker
j_matador=Matador
j_merry_andy=Merry Andy
j_midas_mask=Midas Mask
j_mime=Mime
j_misprint=Misprint
j_mr_bones=Mr. Bones
j_mystic_summit=Mystic Summit
j_obelisk=Obelisk
j_odd_todd=Odd Todd
j_onyx_agate=Onyx Agate
j_oops=Oops! All 6s
j_order=The Order
j_pareidolia=Pareidolia
j_perkeo=Perkeo
j_photograph=Photograph
j_popcorn=Popcorn
j_raised_fist=Raised Fist
j_ramen=Ramen
j_red_card=Red Card
j_reserved_parking=Reserved Parking
j_ride_the_bus=Ride the Bus
j_riff_raff=Riff-Raff
j_ring_master=Showman
j_rocket=Rocket
j_rough_gem=Rough Gem
j_runner=Runner
j_satellite=Satellite
j_scary_face=Scary Face
j_scholar=Scholar
j_seance=Séance
j_seeing_double=Seeing Double
j_selzer=Seltzer
j_shoot_the_moon=Shoot the Moon
j_shortcut=Shortcut
j_sixth_sense=Sixth Sense
j_sly=Sly Joker
j_smeared=Smeared Joker
j_smiley=Smiley Face
j_sock_and_buskin=Sock and Buskin
j_space=Space Joker
j_splash=Splash
j_square=Square Joker
j_steel_joker=Steel Joker
j_stencil=Joker Stencil
j_stone=Stone Joker
j_stuntman=Stuntman
j_supernova=Supernova
j_superposition=Superposition
j_swashbuckler=Swashbuckler
j_throwback=Throwback
j_ticket=Golden Ticket
j_to_the_moon=To the Moon
j_todo_list=To Do List
j_trading=Trading Card
j_tribe=The Tribe
j_triboulet=Triboulet
j_trio=The Trio
j_troubadour=Troubadour
j_trousers=Spare Trousers
j_turtle_bean=Turtle Bean
j_vagabond=Vagabond
j_vampire=Vampire
j_walkie_talkie=Walkie Talkie
j_wee=Wee Joker
j_wily=Wily Joker
j_wrathful_joker=Wrathful Joker
j_yorick=Yorick
j_zany=Zany Joker
]=]):gmatch('[^\r\n]+') do local key,label=line:match('^(j_[%w_]+)=(.+)$');names[key]=label end
local keys={};for key in next,names do keys[#keys+1]=key end;table.sort(keys)
local legendary={j_caino=true,j_triboulet=true,j_yorick=true,j_chicot=true,j_perkeo=true}
-- Instance::initLocks(freshRun) excludes all six. The normal timeline does not
-- simulate enhancement creation or Gros Michel extinction; a later deadline
-- or another named Joker target does not establish those eligibility changes.
local blocked={
  j_stone='Stone Joker needs a Stone Card. Use Marble Joker or The Tower during play, then find Stone Joker. Direct fresh-run search does not model that prerequisite.',
  j_steel_joker='Steel Joker needs a Steel Card, for example from The Chariot. Create it during play, then find Steel Joker; direct fresh-run search does not model that prerequisite.',
  j_glass='Glass Joker needs a Glass Card, for example from Justice. Create it during play, then find Glass Joker; direct fresh-run search does not model that prerequisite.',
  j_ticket='Golden Ticket needs a Gold Card, for example from The Devil. Create it during play, then find Golden Ticket; direct fresh-run search does not model that prerequisite.',
  j_lucky_cat='Lucky Cat needs a Lucky Card, for example from The Magician. Create it during play, then find Lucky Cat; direct fresh-run search does not model that prerequisite.',
  j_cavendish='Cavendish needs Gros Michel to go extinct during play. A Gros Michel offer alone does not establish that event; direct fresh-run search does not model it.',
}
local function get(t,key) if type(t)=='table' then return rawget(t,key) end end
local function integer(v,low,high)
  return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge and v%1==0 and v>=low and (not high or v<=high)
end
local function profile_id(v) return type(v)=='string' and v~='' or integer(v,1) end
local function context(goal)
  if get(goal,'schema')~=1 or get(goal,'goal')~='gold_stickers' or not profile_id(get(goal,'profile_id')) or
    get(goal,'metadata_status')~='complete' or get(goal,'catalog_status')~='complete' or get(goal,'stake_status')~='complete' then
    return nil,'Loaded Gold progress or its vanilla catalog is unavailable. Refresh the active profile before choosing a target.'
  end
  local counts,rows=get(goal,'counts'),get(goal,'by_key');local actual={complete=0,missing=0,unknown=0}
  if get(counts,'total')~=150 or type(rows)~='table' then return nil,'Gold progress is incomplete; missing targets cannot be inferred.' end
  for _,key in ipairs(keys) do
    local row=get(rows,key);local status=get(row,'status')
    if get(row,'key')~=key or actual[status]==nil then return nil,'Gold progress contains an unavailable target status.' end
    actual[status]=actual[status]+1
  end
  for status,count in next,actual do if get(counts,status)~=count then return nil,'Gold progress counts do not match its target records.' end end
  return goal
end
local function ticket(goal,key,route)
  return {schema=1,goal='gold_stickers',profile_id=get(goal,'profile_id'),target_key=key,expected_status='missing',route=route or 'direct'}
end
function M.name(key) return names[key] end
function M.choices(goal)
  local ok,reason=context(goal);if not ok then return nil,reason end
  local out={}
  for _,key in ipairs(keys) do if get(get(goal,'by_key'),key).status=='missing' then
    out[#out+1]={key=key,label=names[key],profile_id=get(goal,'profile_id'),direct_supported=not blocked[key],
      route=blocked[key] and 'unsupported' or legendary[key] and 'soul' or 'early',reason=blocked[key],
      prerequisite_key=key=='j_stone' and 'j_marble' or nil,binding=ticket(goal,key)}
  end end
  return out,{profile_id=get(goal,'profile_id'),unknown_count=get(get(goal,'counts'),'unknown')}
end
function M.bind(goal,key,route)
  local ok,reason=context(goal);if not ok then return nil,reason end
  if not names[key] then return nil,'Choose a vanilla Joker from the current missing-target list.' end
  local row=get(get(goal,'by_key'),key)
  if get(row,'status')~='missing' then return nil,'This Joker is no longer a known missing Gold target. Refresh the selection.' end
  route=route or 'direct'
  if route~='direct' and not (route=='marble_prerequisite' and key=='j_stone') then return nil,'That prerequisite route is unsupported.' end
  return ticket(goal,key,route)
end
local function clone(value)
  local active,nodes={},0
  local function visit(v,depth)
    if depth>32 then return nil,'Search filter metadata exceeds the bounded nesting depth.' end
    nodes=nodes+1;if nodes>4096 then return nil,'Search filter metadata exceeds the bounded copy size.' end
    local kind=type(v)
    if kind=='nil' or kind=='boolean' or kind=='string' then return v end
    if kind=='number' then
      if v==v and v~=math.huge and v~=-math.huge then return v end
      return nil,'Search filter metadata contains a nonfinite number.'
    end
    if kind~='table' or getmetatable(v) or active[v] then return nil,'Search filters must be plain finite data without callbacks or cycles.' end
    active[v]=true;local out={}
    for key,item in next,v do
      if type(key)~='string' and not integer(key,1) then return nil,'Search filter metadata contains an unsupported key.' end
      local changed,reason=visit(item,depth+1);if reason then return nil,reason end;out[key]=changed
    end
    active[v]=nil;return out
  end
  return visit(value,0)
end
local function manual(options)
  if get(options,'explicit_click')~=true then return nil,'Preparing or restoring filters requires an explicit user click.' end
  if get(options,'active_search')~=false then return nil,'Stop the active search before changing its filters.' end
  return true
end
function M.prepare(goal,binding,current_filters,previous_filters,options)
  local ok,reason=manual(options);if not ok then return nil,reason end
  ok,reason=context(goal);if not ok then return nil,reason end
  if get(binding,'schema')~=1 or get(binding,'goal')~='gold_stickers' or
    get(binding,'profile_id')~=get(goal,'profile_id') or get(binding,'expected_status')~='missing' then
    return nil,'The selected target belongs to different or stale profile metadata. Refresh the selection.'
  end
  local key,route=get(binding,'target_key'),get(binding,'route')
  local bound;bound,reason=M.bind(goal,key,route);if not bound then return nil,reason end
  if route=='direct' and blocked[key] then return nil,blocked[key] end
  if route~='direct' and route~='marble_prerequisite' then return nil,'An explicit supported search route is required.' end
  if type(current_filters)~='table' or previous_filters~=nil and type(previous_filters)~='table' then return nil,'Current or saved search filters are unavailable.' end
  local filters;filters,reason=clone(current_filters);if not filters then return nil,reason end
  local previous;previous,reason=clone(previous_filters~=nil and previous_filters or current_filters)
  if not previous then return nil,reason end
  local search_key=route=='marble_prerequisite' and 'j_marble' or key
  local soul=legendary[search_key]==true
  filters.pack={};filters.pack_id=1;filters.voucher_name='';filters.voucher_id=1
  filters.tag_name=soul and 'tag_charm' or '';filters.tag_id=soul and 2 or 1;filters.soul_count=soul and 1 or 0
  filters.inst_observatory=false;filters.observatory_deadline=0;filters.inst_perkeo=false
  filters.no_perishable_jokers=false;filters.copy_money=false;filters.bean=false;filters.burglar=false;filters.retcon=false
  filters.custom_filter_name='No Filter';filters.custom_filter_id=1
  filters.rank_min=0;filters.rank_min_id=1;filters.any_rank_min=0;filters.any_rank_min_id=1
  filters.joker_targets={names[search_key],'','','',''}
  filters.joker_target_editions={'Any Edition','Any Edition','Any Edition','Any Edition','Any Edition'}
  filters.joker_target_locations={soul and 'soul_pack' or 'ante_1','ante_1','ante_1','ante_1','ante_1'}
  local instructions=soul and {
    'Use a normal deck and start the existing filtered reroll yourself.',
    'Take the opening Charm Tag and use its Soul for '..names[search_key]..'.',
  } or {
    'Use a normal deck and start the existing filtered reroll yourself.',
    'Play Small and Big without skips or shop rerolls; inspect the first two shops and their Buffoon packs.',
    'Until the searched Joker, avoid other Joker acquisitions and Joker-generating cards.',
  }
  if route=='marble_prerequisite' then
    instructions[#instructions+1]='This searches only for Marble Joker. Buy Marble and select a blind to add a Stone Card; find Stone Joker separately during play.'
  end
  instructions[#instructions+1]='This search assumes all profile unlocks; Gold history alone does not verify them.'
  instructions[#instructions+1]='An offer is not guaranteed affordable acquisition, retention, survival or a Gold-sticker win.'
  return {schema=1,profile_id=get(goal,'profile_id'),target_key=key,search_key=search_key,route=route,
    filters=filters,previous_filters=previous,saved_previous=previous_filters==nil,starts_search=false,
    assumes_complete_profile_unlocks=true,profile_unlocks_verified=false,
    message=route=='marble_prerequisite' and 'Marble prerequisite preset ready; Stone Joker is not searched or guaranteed.' or
      names[search_key]..(soul and ' Soul preset ready. Start search yourself.' or ' early preset ready. Start search yourself.'),
    instructions=instructions}
end
function M.restore(current_filters,previous_filters,options)
  local ok,reason=manual(options);if not ok then return nil,reason end
  if type(previous_filters)~='table' then return nil,'No previous search filters are saved.' end
  local filters;filters,reason=clone(previous_filters);if not filters then return nil,reason end
  return {schema=1,filters=filters,clear_previous=true,starts_search=false,message='Previous search filters restored.'}
end
return M
