local O=Brainstorm.ChallengeOpening
local keys={'','j_caino','j_triboulet','j_yorick','j_chicot','j_perkeo'}
local labels={'Any','Canio','Triboulet','Yorick','Chicot','Perkeo'}
local later_choices=O.later_choices()
local later_labels,deadline_labels={},{}
for i,choice in ipairs(later_choices) do later_labels[i]=choice.label end
for ante=2,8 do deadline_labels[#deadline_labels+1]='Ante '..ante end
local function row(text,scale,colour)
  return {n=G.UIT.R,config={align='cm',padding=0.03},nodes={{n=G.UIT.T,config={text=text,scale=scale or 0.32,colour=colour or G.C.WHITE}}}}
end
local function live_row(state,key,scale,colour)
  return {n=G.UIT.R,config={align='cm',padding=0.03},nodes={{n=G.UIT.T,
    config={ref_table=state,ref_value=key,scale=scale or 0.27,colour=colour or G.C.WHITE}}}}
end
for slot=1,2 do
  local index=slot
  G.FUNCS['brainstorm_opening_target_'..slot]=function(args)
    local choice=args and args.cycle_config and args.cycle_config.current_option
    if keys[choice]~=nil then O.defaults(Brainstorm.config).targets[index]=keys[choice];Brainstorm.writeConfig() end
  end
end
G.FUNCS.brainstorm_opening_later_target=function(args)
  local index=args and args.cycle_config and args.cycle_config.current_option
  if later_choices[index] then O.defaults(Brainstorm.config).later_target=later_choices[index].key;Brainstorm.writeConfig() end
end
G.FUNCS.brainstorm_opening_later_ante=function(args)
  local index=args and args.cycle_config and args.cycle_config.current_option
  if deadline_labels[index] then O.defaults(Brainstorm.config).later_ante=index+1;Brainstorm.writeConfig() end
end
G.FUNCS.brainstorm_opening_start=function() Brainstorm.startChallengeOpeningSearch() end
G.FUNCS.brainstorm_opening_stop=function() Brainstorm.stopChallengeOpeningSearch() end
G.FUNCS.brainstorm_opening_config=function() Brainstorm.writeConfig() end
G.FUNCS.brainstorm_jokerless_preset=function(args)
  local state=Brainstorm.JokerlessOpeningSearch
  local index=args and args.cycle_config and args.cycle_config.current_option
  local preset=state and state.presets and state.presets[index]
  if not preset then return end
  state.preset=preset.id
  Brainstorm.config.jokerless_opening_search=Brainstorm.config.jokerless_opening_search or {}
  Brainstorm.config.jokerless_opening_search.preset=preset.id
  Brainstorm.writeConfig()
end
local function jokerless_page()
  local search=Brainstorm.JokerlessOpeningSearch or {}
  local nodes={row('Jokerless opening search',0.5,G.C.GREEN),
    row('Coupon + main-hand Planet + Blue seals + Telescope',0.34),
    row('Skip Small, clear Big, then collect the free cards and packs.',0.28),
    row('Telescope still costs money. The advisor checks each visible step.',0.28),
    row('Mars develops Four of a Kind; Jupiter develops Flush.',0.28),
    row('Five of a Kind depends on later deck development.',0.28),
    row('This finds an opening. Surviving the run is not guaranteed.',0.28),
    row('Fresh Jokerless only: a match replaces this run and keeps its rules.',0.28),
    row('Filtered run; deterministic search, up to 1,000,000 seeds per click.',0.28),
    search.status and live_row(search,'status',0.27,G.C.GREEN) or row('Ready for a fresh Jokerless challenge.',0.27,G.C.GREEN)}
  local last=search.last
  if search.presets then
    local labels,selected={},1
    for i,preset in ipairs(search.presets) do labels[i]=preset.label;if preset.id==search.preset then selected=i end end
    table.insert(nodes,3,create_option_cycle({label='Starting pattern',options=labels,current_option=selected,
      opt_callback='brainstorm_jokerless_preset',scale=0.65,w=5.8,colour=G.C.GREEN}))
    table.insert(nodes,4,row(search.presets[selected].description,0.26))
  end
  if search.progress_text then
    nodes[#nodes+1]=live_row(search,'progress_text',0.27)
    nodes[#nodes+1]=live_row(search,'timing_text',0.27)
    nodes[#nodes+1]=live_row(search,'compute_text',0.27)
  elseif last then
    local cost=type(last.compute_seconds)=='number' and string.format('%.2fs',last.compute_seconds) or 'time unavailable'
    nodes[#nodes+1]=row('Tested '..tostring(last.tested or 0)..' seeds; '..cost..' search computation.',0.27)
  end
  if search.reason then nodes[#nodes+1]=row(search.reason,0.25) end
  nodes[#nodes+1]=UIBox_button({label={search.searching and 'Stop opening search' or 'Search this Jokerless opening'},
    button=search.searching and 'brainstorm_opening_stop' or 'brainstorm_opening_start',minw=4.8,minh=0.6,scale=0.4})
  nodes[#nodes+1]=row('The hotkey also starts or stops this search.',0.27)
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=0.06},nodes=nodes}
end
function Brainstorm.createChallengeOpeningPage()
  if G.GAME and G.GAME.challenge=='c_jokerless_1' then return jokerless_page() end
  local config=O.defaults(Brainstorm.config)
  local opening={row('First Small: Charm Tag with two Souls.',0.27),row('Pick two different targets, or Any.',0.27)}
  for slot=1,2 do
    local selected=1
    for i,key in ipairs(keys) do if key==config.targets[slot] then selected=i end end
    opening[#opening+1]=create_option_cycle({label='Legendary '..slot,options=labels,current_option=selected,
      opt_callback='brainstorm_opening_target_'..slot,scale=0.65,w=3.9,colour=G.C.RED})
  end
  local later_selected=1
  for i,choice in ipairs(later_choices) do if choice.key==config.later_target then later_selected=i end end
  local deadline=type(config.later_ante)=='number' and math.floor(config.later_ante) or 2
  deadline=math.max(2,math.min(8,deadline))
  local later={
    create_toggle({label='Conditional later offer',ref_table=config,ref_value='later_enabled',callback=G.FUNCS.brainstorm_opening_config}),
    create_option_cycle({label='Later Rare target',options=later_labels,current_option=later_selected,
      opt_callback='brainstorm_opening_later_target',scale=0.65,w=3.9,colour=G.C.RED}),
    create_option_cycle({label='Offer by end of',options=deadline_labels,current_option=deadline-1,
      opt_callback='brainstorm_opening_later_ante',scale=0.65,w=3.9,colour=G.C.RED})}
  local nodes={row('Challenge opening search',0.5,G.C.GREEN),
    create_toggle({label='Enable challenge opening search',ref_table=config,ref_value='enabled',callback=G.FUNCS.brainstorm_opening_config}),
    {n=G.UIT.R,config={align='cm',padding=0.05},nodes={
      {n=G.UIT.C,config={align='cm',padding=0.04,minw=4.1},nodes=opening},
      {n=G.UIT.C,config={align='cm',padding=0.04,minw=4.1},nodes=later}}},
    row('Later filter only: play all blinds; no rerolls, packs or vouchers.',0.27),
    row('No other Rare buys/sales/generation; keep Legendaries; target buy allowed.',0.27),
    row('No Showman or Joker-generating consumables; other support buys/sales allowed.',0.27),
    row('Offer only: survival, purchase and retention unverified.',0.27)}
  local plan=G.GAME and G.GAME.filter_info and G.GAME.filter_info.later
  if plan and plan.offer_status=='conditional' and O.rare_names[plan.target_key] then
    nodes[#nodes+1]=row('Current conditional target: '..O.rare_names[plan.target_key],0.29,G.C.GREEN)
    nodes[#nodes+1]=row('Predicted offer: Ante '..tostring(plan.found_ante)..', shop '..tostring(plan.shop)..', slot '..tostring(plan.slot)..'.',0.27)
  end
  local ledger=O.last_search or (G.GAME and G.GAME.filter_info and G.GAME.filter_info.search)
  if ledger then
    local timing=ledger.native_seconds_known and string.format('%.2fs native calls',ledger.native_seconds or 0) or 'native time unavailable'
    nodes[#nodes+1]=row('Search: '..tostring(ledger.batches or 0)..' batches, '..tostring(ledger.misses or 0)..' misses; '..timing..'.',0.26)
  end
  nodes[#nodes+1]=row('19 opening challenges; later targets exclude Bram. No Jokerless.',0.27)
  nodes[#nodes+1]=row('Fresh challenge only: replaces this run and keeps its rules.',0.27)
  nodes[#nodes+1]=row('Separate filters; first-pack duplicate-Soul exception.',0.27)
  nodes[#nodes+1]=UIBox_button({label={'Search this challenge opening'},button='brainstorm_opening_start',minw=4.8,minh=0.6,scale=0.4})
  nodes[#nodes+1]=row('Hotkey starts/stops search; extra filters can take longer.',0.27)
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=0.06},nodes=nodes}
end
