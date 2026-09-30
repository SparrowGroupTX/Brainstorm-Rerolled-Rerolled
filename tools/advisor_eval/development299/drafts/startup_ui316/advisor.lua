local A = Brainstorm.Advisor
local contents_id = 'brainstorm_advisor_contents'
local status_colour = {0.82, 0.86, 0.85, 1}
local notices={seen={}}
local function bounded_text(value,limit)
  local text=type(value)=='string' and value or ''
  text=text:gsub('[%z\1-\31]',' ')
  limit=limit or 512
  if #text>limit then text=text:sub(1,limit-3)..'...' end
  return text
end
local function version()
  local text=bounded_text(Brainstorm.VERSION,80)
  return text~='' and text or 'Loaded version unavailable'
end
local function ui_time()
  return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
end
local function report(owner)
  local product=owner=='manual' and Brainstorm.CollectionSearchProduct or Brainstorm.AutoRun
  if not product or type(product.status_report)~='function' then return nil end
  local okay,value
  if owner=='manual' then okay,value=pcall(product.status_report)
  else okay,value=pcall(product.status_report,product) end
  if not okay or type(value)~='table' then return nil end
  return {requested=value.requested==true,busy=value.busy==true,owner=owner,
    phase=bounded_text(value.phase,64),text=bounded_text(value.text)}
end
function A.note_search_notice(owner,text)
  -- Called only by explicit UI callbacks after a rejected request.
  notices.current={owner=owner=='auto' and 'auto' or 'manual',text=bounded_text(text),
    phase='rejected',busy=false,requested=true}
  notices.expires=ui_time()+15
end
function A.search_diagnostics(include_stopped)
  local now=ui_time();local manual,auto=report('manual'),report('auto')
  local active=auto and auto.busy and auto or manual and manual.busy and manual
  for _,value in ipairs({manual or false,auto or false}) do
    if value then
      local signature=value.phase..'|'..value.text..'|'..tostring(value.busy)..'|'..tostring(value.requested)
      if signature~=notices.seen[value.owner] then
        notices.seen[value.owner]=signature
        if value.requested and not value.busy then
          if value.owner=='manual' and value.phase=='started' then
            if notices.current and notices.current.owner=='manual' then notices.current=nil end
          elseif value.text~='' then notices.current=value;notices.expires=now+15 end
        end
      end
    end
  end
  if active then notices.current=active;notices.expires=now+15;return active end
  local current=notices.current
  if current and current.busy then
    -- A consumed successful manual launch clears its previous busy notice.
    if manual and manual.phase=='started' and current.owner=='manual' then notices.current=nil;return nil end
    current=nil
  end
  if current and (include_stopped or now<(notices.expires or 0)) then return current end
  return nil
end

local function row(text, colour, scale)
  return {n = G.UIT.R, config = {align = 'cm', padding = 0.035}, nodes = {
    {n = G.UIT.T, config = {text = text, colour = colour or G.C.WHITE, scale = scale or 0.34}},
  }}
end
local function wrap(text, width)
  local result, line = {}, ''
  for word in tostring(text):gmatch('%S+') do
    if #line + #word + 1 > width and #line > 0 then result[#result + 1] = line; line = '' end
    line = line == '' and word or line .. ' ' .. word
  end
  if line ~= '' then result[#result + 1] = line end
  return result
end
local function enable_normal_button()
  return UIBox_button({label={'Enable normal-deck advice'},button='brainstorm_advisor_enable_normal',
    minw=4,minh=0.5,scale=0.35})
end

local function menu_contents()
  local diagnostic=A.search_diagnostics(A.search_detail_mode==true)
  local all = {}
  local lines=diagnostic and {diagnostic.text,'Search phase: '..diagnostic.phase..'. Owner: '..diagnostic.owner..'.'} or
    A.lines or {'Start a normal deck or challenge run to receive advice.'}
  for _, line in ipairs(lines) do
    for _, part in ipairs(wrap(line, 78)) do all[#all + 1] = part end
  end
  local pages = math.max(1, math.ceil(#all / 11))
  A.page = math.max(1, math.min(A.page, pages))
  local nodes = {row('RUN ADVISOR / '..version(), G.C.GREEN, 0.34)}
  if not Brainstorm.config.advisor.enabled or Brainstorm.config.advisor.challenge_only then
    nodes[#nodes+1]=enable_normal_button()
  end
  for _, part in ipairs(wrap(diagnostic and 'Search diagnostics' or A.display.title, 65)) do nodes[#nodes + 1] = row(part, G.C.ORANGE, 0.40) end
  nodes[#nodes + 1] = row(diagnostic and (diagnostic.busy and 'Active request' or 'Last request status') or A.display.status, status_colour, 0.28)
  for i = (A.page - 1) * 11 + 1, math.min(#all, A.page * 11) do nodes[#nodes + 1] = row(all[i]) end
  if pages > 1 then
    nodes[#nodes + 1] = UIBox_button({label = {'More details (' .. A.page .. '/' .. pages .. ')'}, button = 'brainstorm_advisor_page', minw = 4, minh = 0.45, scale = 0.32})
  end
  if not diagnostic and A.selection then
    local label = A.selection.kind == 'use' and 'Select consumable targets' or ('Select cards to ' .. A.selection.kind)
    nodes[#nodes + 1] = UIBox_button({label = {label}, button = 'brainstorm_advisor_select', colour = G.C.GREEN, minw = 4, minh = 0.6, scale = 0.38})
  end
  if not diagnostic and A.retry_status and A.active() then
    local retry=A.retry_status()
    for _,part in ipairs(wrap(retry.text,90)) do nodes[#nodes+1]=row(part,status_colour,0.25) end
    nodes[#nodes+1]=row('Save and restore checkpoints yourself. These controls remember decisions only.',status_colour,0.25)
    nodes[#nodes+1]=row('Use Execute for the first action. Confirm a loss only after restoring manually.',status_colour,0.25)
    if retry.can_mark then
      nodes[#nodes+1]=UIBox_button({label={'Remember this decision'},button='brainstorm_advisor_checkpoint_mark',
        ref_table=retry.token,minw=4,minh=0.45,scale=0.30})
    end
    if retry.can_report then
      nodes[#nodes+1]=UIBox_button({label={'I restored after a loss - try another line'},button='brainstorm_advisor_checkpoint_loss',
        ref_table=retry.token,minw=4,minh=0.45,scale=0.30})
    end
  end
  return {n = G.UIT.ROOT, config = {align = 'cm', minw = 10, colour = G.C.CLEAR}, nodes = nodes}
end

function A.render_menu()
  -- Progress and pagination update only the content object. Reopening the
  -- overlay would replay its entrance animation and reset controller focus.
  if not A.menu_open or not A.menu_overlay or G.OVERLAY_MENU ~= A.menu_overlay then
    A.menu_open, A.menu_overlay = false, nil
    return
  end
  local holder = A.menu_overlay:get_UIE_by_ID(contents_id)
  if not holder then return end
  if holder.config.object then holder.config.object:remove() end
  holder.config.object = UIBox({
    definition = menu_contents(),
    config = {offset = {x = 0, y = 0}, align = 'cm', parent = holder},
  })
  holder.UIBox:recalculate()
end

local function open_menu(persistent_diagnostics)
  A.search_detail_mode=persistent_diagnostics==true
  if not A.search_diagnostics(A.search_detail_mode) and A.refresh then A.refresh() end
  if not A.active() then
    A.display.title = 'Advisor settings'
    A.display.status = 'Settings > Brainstorm > Advisor'
    A.lines = {'Advice is available on normal decks and challenge runs.',
      'Use Enable normal-deck advice here, or change the Advisor settings.'}
  elseif not A.lines then A.lines = {'Reading this decision. Advice appears automatically when ready.'} end
  A.page = 1
  if not A.menu_open or G.OVERLAY_MENU ~= A.menu_overlay then
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu({definition = create_UIBox_generic_options({
      contents = {{n = G.UIT.C, config = {align = 'cm', minw = 10}, nodes = {
        {n = G.UIT.O, config = {id = contents_id, object = Moveable()}},
      }}},
      back_func = 'brainstorm_advisor_close',
    })})
    A.menu_overlay, A.menu_open = G.OVERLAY_MENU, true
  end
  A.render_menu()
end
function A.open() open_menu(false) end
function A.open_search_status() open_menu(true) end

G.FUNCS.brainstorm_advisor_open = function() A.open() end
G.FUNCS.brainstorm_search_status_open = function() A.open_search_status() end
G.FUNCS.brainstorm_advisor_close = function()
  A.menu_open, A.menu_overlay,A.search_detail_mode = false, nil,nil
  G.FUNCS.exit_overlay_menu()
end
G.FUNCS.brainstorm_advisor_select = function() A.select() end
G.FUNCS.brainstorm_advisor_checkpoint_mark=function(e)
  if A.remember_checkpoint then A.remember_checkpoint(e and e.config and e.config.ref_table) end
end
G.FUNCS.brainstorm_advisor_checkpoint_loss=function(e)
  if A.report_checkpoint_loss then A.report_checkpoint_loss(e and e.config and e.config.ref_table) end
end
G.FUNCS.brainstorm_advisor_page = function()
  local count = 0
  for _, line in ipairs(A.lines or {}) do count = count + #wrap(line, 78) end
  A.page = A.page % math.max(1, math.ceil(count / 11)) + 1
  A.render_menu()
end
G.FUNCS.brainstorm_advisor_config = function()
  A.settings_changed()
  Brainstorm.writeConfig()
end
G.FUNCS.brainstorm_advisor_enable_normal = function()
  A.defaults()
  Brainstorm.config.advisor.enabled=true
  Brainstorm.config.advisor.challenge_only=false
  G.FUNCS.brainstorm_advisor_config()
end
G.FUNCS.brainstorm_advisor_logging = function()
  G.FUNCS.brainstorm_advisor_config()
  if A.player_log then A.player_log:event('recording_enabled',{scope='Public state, advice and player actions.'}) end
end

function Brainstorm.createAdvisorPage()
  A.defaults()
  return {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.1}, nodes = {
    row('Run Advisor / '..version(), G.C.GREEN, 0.34),
    row('Advice for normal decks and challenge runs.', nil, 0.30),
    create_toggle({label = 'Enable advisor', ref_table = Brainstorm.config.advisor, ref_value = 'enabled', callback = G.FUNCS.brainstorm_advisor_config}),
    create_toggle({label = 'Challenge runs only', ref_table = Brainstorm.config.advisor, ref_value = 'challenge_only', callback = G.FUNCS.brainstorm_advisor_config}),
    create_toggle({label = 'Show advice badge', ref_table = Brainstorm.config.advisor, ref_value = 'hud', callback = G.FUNCS.brainstorm_advisor_config}),
    create_toggle({label = 'Record actions and advice', ref_table = Brainstorm.config.advisor, ref_value = 'player_logging', callback = G.FUNCS.brainstorm_advisor_logging}),
    enable_normal_button(),
    row('Ctrl+H: advice and recommended card selection', nil, 0.34),
    row('Z+1-5 saves a verified checkpoint; X+1-5 loads it.', nil, 0.28),
    row(A.player_log and A.player_log.status or 'Recording is off.', status_colour, 0.26),
    row('Logs: Balatro/advisor_player_log_v1 (stops at its storage limit).', nil, 0.25),
    row('Execute carries out one recommendation; selection only highlights.', nil, 0.28),
    UIBox_button({label = {'Open advisor'}, button = 'brainstorm_advisor_open', minw = 4, minh = 0.6, scale = 0.4}),
  }}
end

local gold_page=1
local gold_page_size=8
local gold_search_view={choices={},message='Choose a missing Joker, then prepare its search filters.'}
local function gold_row(text,colour,scale)
  return {n=G.UIT.R,config={align='cm',padding=0.015,maxw=7.7},nodes={
    {n=G.UIT.T,config={text=text,colour=colour or G.C.WHITE,scale=scale or 0.25}}}}
end
local function gold_name(key)
  local center=(G.P_CENTERS or {})[key]
  return center and center.name or key
end
local gold_reasons={
  run_unavailable='Start a normal Gold Stake run to use the collection objective.',
  outside_run_stage='Start a normal Gold Stake run to use the collection objective.',
  not_gold_stake='This run is below Gold Stake; sticker progress is shown for reference.',
  challenge_run='Challenge runs do not earn collection stickers.',
  seeded_run='Manually seeded runs do not earn collection stickers.',
  run_already_won='This run has already awarded its win. New acquisitions need another run.',
  past_winning_ante='Endless play does not award another sticker win.',
}
local function gold_status_text(status)
  if not status then return 'Enable Completionist++ to read the loaded collection records.' end
  if status.metadata_status and status.metadata_status~='complete' then
    return 'Loaded profile history unavailable: '..status.metadata_status..'.'
  end
  if status.stake_status and status.stake_status~='complete' then
    return 'Gold mapping unavailable: '..tostring(status.stake_reason or status.stake_status)..'.'
  end
  if status.catalog_status and status.catalog_status~='complete' then
    return 'Vanilla Joker catalog unavailable: '..status.catalog_status..'.'
  end
  if status.eligibility and status.eligibility.eligible then
    return 'Normal Gold Stake run: keep missing Jokers through the winning boss.'
  end
  for _,reason in ipairs(status.eligibility and status.eligibility.reasons or {}) do
    if gold_reasons[reason] then return gold_reasons[reason] end
  end
  return 'Run metadata is unavailable; unknown records receive no goal credit.'
end
local function gold_entries(status)
  local entries={}
  for _,entry in ipairs(status and status.targets or {}) do
    if entry.status~='complete' then entries[#entries+1]=entry end
  end
  return entries
end
local function refresh_gold_page()
  if Brainstorm.showGoldStickersPage then Brainstorm.showGoldStickersPage() end
end
G.FUNCS.brainstorm_gold_enable=function()
  A.defaults()
  Brainstorm.config.advisor.enabled=true
  Brainstorm.config.advisor.challenge_only=false
  Brainstorm.config.advisor.gold_stickers=true
  G.FUNCS.brainstorm_advisor_config()
  refresh_gold_page()
end
G.FUNCS.brainstorm_gold_toggle=function()
  G.FUNCS.brainstorm_advisor_config()
  refresh_gold_page()
end
G.FUNCS.brainstorm_gold_next=function()
  local pages=math.max(1,math.ceil(#gold_entries(A.gold_status())/gold_page_size))
  gold_page=gold_page%pages+1
  refresh_gold_page()
end
G.FUNCS.brainstorm_gold_previous=function()
  local pages=math.max(1,math.ceil(#gold_entries(A.gold_status())/gold_page_size))
  gold_page=(gold_page-2)%pages+1
  refresh_gold_page()
end
function Brainstorm.createGoldStickersPage()
  A.defaults()
  local status=A.gold_status()
  local entries=gold_entries(status)
  local pages=math.max(1,math.ceil(#entries/gold_page_size))
  gold_page=math.max(1,math.min(gold_page,pages))
  local controls={create_toggle({label='Track Gold stickers',ref_table=Brainstorm.config.advisor,ref_value='gold_stickers',
    callback=G.FUNCS.brainstorm_gold_toggle,col=true,w=2.6,scale=0.65,label_scale=0.27})}
  if not Brainstorm.config.advisor.gold_stickers or not Brainstorm.config.advisor.enabled or Brainstorm.config.advisor.challenge_only then
    controls[#controls+1]=UIBox_button({label={'Enable Completionist++'},button='brainstorm_gold_enable',col=true,minw=3.2,minh=0.38,scale=0.26})
  end
  local nodes={gold_row('Completionist++',G.C.GREEN,0.38),
    {n=G.UIT.R,config={align='cm',padding=0.02},nodes=controls}}
  if status then
    local counts=status.counts
    nodes[#nodes+1]=gold_row(tostring(counts.complete)..' / '..tostring(counts.total)..' Gold  |  '..
      tostring(counts.missing)..' missing  |  '..tostring(counts.unknown)..' unknown',G.C.ORANGE,0.29)
    local held=status.held_status=='complete' and
      ('Carrying '..tostring(status.held_target_count)..' missing Jokers (*); ? means unknown.') or
      'Held Joker progress is unavailable; no carried count is assumed.'
    nodes[#nodes+1]=gold_row(held,nil,0.23)
  end
  for _,text in ipairs(wrap(gold_status_text(status),66)) do nodes[#nodes+1]=gold_row(text,status_colour,0.23) end
  if status then
    local held={};if status.held_status=='complete' then
      for _,key in ipairs(status.held_target_keys or {}) do held[key]=true end
    end
    local function label(entry)
      if not entry then return '' end
      return (entry.status=='unknown' and '? ' or held[entry.key] and '* ' or '')..gold_name(entry.key)
    end
    if #entries==0 then nodes[#nodes+1]=gold_row('All 150 vanilla Jokers have a recorded Gold win.',G.C.GREEN,0.28) end
    for i=(gold_page-1)*gold_page_size+1,math.min(#entries,gold_page*gold_page_size),2 do
      local cells={}
      for offset=0,1 do cells[#cells+1]={n=G.UIT.C,config={align='cl',minw=3.65,maxw=3.65},nodes={
        {n=G.UIT.T,config={text=label(entries[i+offset]),scale=0.25,colour=G.C.WHITE}}}} end
      nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=0.015},nodes=cells}
    end
    if pages>1 then
      nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=0.025,id='gold_progress_pagination'},nodes={
        UIBox_button({label={'Previous'},button='brainstorm_gold_previous',col=true,minw=1.65,minh=0.35,scale=0.25}),
        {n=G.UIT.C,config={align='cm',minw=1.2},nodes={
          {n=G.UIT.T,config={text=gold_page..' / '..pages,scale=0.24,colour=G.C.WHITE}}}},
        UIBox_button({label={'Next'},button='brainstorm_gold_next',col=true,minw=1.65,minh=0.35,scale=0.25})}}
    end
    nodes[#nodes+1]=gold_row('Keep targets through a qualifying win to earn their stickers.',status_colour,0.23)
  end
  nodes[#nodes+1]=UIBox_button({label={'Find a missing Joker'},button='brainstorm_gold_search_open',minw=4.2,minh=0.38,scale=0.28})
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=0.02,minw=7.7},nodes=nodes}
end

local function refresh_gold_search()
  if Brainstorm.showGoldSearchPage then Brainstorm.showGoldSearchPage() end
end
G.FUNCS.brainstorm_gold_search_open=function() refresh_gold_search() end
G.FUNCS.brainstorm_gold_search_back=function() refresh_gold_page() end
G.FUNCS.brainstorm_gold_search_select=function(args)
  local index=args and args.to_key
  local entry=type(index)=='number' and gold_search_view.choices[index]
  if not entry then return end
  gold_search_view.key=entry.key
  gold_search_view.message='Choose a missing Joker, then prepare its search filters.'
  gold_search_view.prepared=nil
  refresh_gold_search()
end
local function prepare_gold_search(prerequisite)
  if not A.gold_search then return end
  local binding=gold_search_view.binding
  if prerequisite then binding=gold_search_view.prerequisite_binding end
  local config=Brainstorm.config
  local prepared,reason=A.gold_search.prepare(A.gold_status(),binding,config.ar_filters,
    config.collection_previous_filters,{explicit_click=true,active_search=not not Brainstorm.ar_active})
  if prepared then
    config.ar_filters=prepared.filters
    config.collection_previous_filters=prepared.previous_filters
    Brainstorm.writeConfig()
    gold_search_view.prepared=prepared
    gold_search_view.filters_key=A.snapshot.fingerprint(config.ar_filters)
    gold_search_view.message=prepared.message
  else gold_search_view.prepared=nil;gold_search_view.message=reason end
  refresh_gold_search()
end
G.FUNCS.brainstorm_gold_search_prepare=function() prepare_gold_search(false) end
G.FUNCS.brainstorm_gold_search_marble=function() prepare_gold_search(true) end
G.FUNCS.brainstorm_gold_search_restore=function()
  if not A.gold_search then return end
  local config=Brainstorm.config
  local restored,reason=A.gold_search.restore(config.ar_filters,config.collection_previous_filters,
    {explicit_click=true,active_search=not not Brainstorm.ar_active})
  if restored then
    config.ar_filters=restored.filters;config.collection_previous_filters=nil
    Brainstorm.writeConfig()
  end
  gold_search_view.prepared=nil;gold_search_view.message=restored and restored.message or reason
  refresh_gold_search()
end
function Brainstorm.createGoldSearchPage()
  A.defaults()
  local goal=A.gold_status()
  local choices,reason
  if A.gold_search then choices,reason=A.gold_search.choices(goal) end
  choices=choices or {}
  gold_search_view.choices=choices
  local index=1;for i,choice in ipairs(choices) do if choice.key==gold_search_view.key then index=i end end
  local selected=choices[index]
  gold_search_view.key=selected and selected.key
  gold_search_view.binding=selected and selected.binding
  gold_search_view.prerequisite_binding=selected and selected.prerequisite_key and A.gold_search.bind(goal,selected.key,'marble_prerequisite')
  local prepared=gold_search_view.prepared
  if prepared and (not goal or not selected or prepared.target_key~=selected.key or prepared.profile_id~=goal.profile_id or
      not (goal.by_key and goal.by_key[prepared.target_key] and goal.by_key[prepared.target_key].status=='missing') or
      gold_search_view.filters_key~=A.snapshot.fingerprint(Brainstorm.config.ar_filters)) then
    gold_search_view.prepared=nil;prepared=nil
    gold_search_view.message='Target, profile or filters changed. Prepare the target again.'
  end
  local nodes={gold_row('Missing-Joker search',G.C.GREEN,0.36),
    gold_row('Use a normal Gold Stake run; do not manually enter a seed.',nil,0.23),
    gold_row('Normal search assumes all profile unlocks.',status_colour,0.23)}
  local actions={}
  if selected then
    local labels={};for i,choice in ipairs(choices) do labels[i]=choice.label end
    nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=0.01},nodes={
      create_option_cycle({options=labels,current_option=index,opt_callback='brainstorm_gold_search_select',
        w=7,h=0.48,scale=0.7,no_pips=true})}}
    if selected.direct_supported then
      actions[#actions+1]=UIBox_button({label={'Prepare target search'},button='brainstorm_gold_search_prepare',col=true,minw=3.25,minh=0.38,scale=0.25})
    else
      if not prepared then
        for _,line in ipairs(wrap(selected.reason or 'This target needs a prerequisite during play.',66)) do nodes[#nodes+1]=gold_row(line,status_colour,0.22) end
      end
      if selected.prerequisite_key then
        actions[#actions+1]=UIBox_button({label={'Prepare Marble prerequisite only'},button='brainstorm_gold_search_marble',col=true,minw=3.65,minh=0.38,scale=0.23})
      end
    end
    if not prepared then
      local route=selected.route=='soul' and 'Soul route: take the opening Charm Tag and use its Soul.' or
        'Early route: play Small and Big; inspect their shops and Buffoon packs.'
      if selected.direct_supported then
        for _,line in ipairs(wrap(route,66)) do nodes[#nodes+1]=gold_row(line,nil,0.22) end
      end
    end
  else
    local message=type(reason)=='string' and reason or 'No known missing targets are available.'
    for _,line in ipairs(wrap(message,66)) do nodes[#nodes+1]=gold_row(line,status_colour,0.22) end
    if not goal then actions[#actions+1]=UIBox_button({label={'Enable Completionist++'},button='brainstorm_gold_enable',col=true,minw=3.2,minh=0.38,scale=0.25}) end
  end
  actions[#actions+1]=UIBox_button({label={'Restore previous search filters'},button='brainstorm_gold_search_restore',col=true,minw=3.65,minh=0.38,scale=0.23})
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=0.02},nodes=actions}
  for _,line in ipairs(wrap(gold_search_view.message or '',66)) do nodes[#nodes+1]=gold_row(line,G.C.GREEN,0.22) end
  if prepared then
    local name=A.gold_search.name(prepared.search_key)
    local instructions=prepared.filters.joker_target_locations[1]=='soul_pack' and
      {'Take the opening Charm Tag and use its Soul for '..name..'.'} or
      {'Play Small and Big with no skips or shop rerolls.',
       'Check their shops and Buffoon packs for '..name..'.',
       'Until then, avoid other Joker acquisitions and Joker-generating cards.'}
    if prepared.route=='marble_prerequisite' then
      instructions[#instructions+1]='Buy Marble, select a blind, then find Stone Joker separately during play.'
    end
    for _,instruction in ipairs(instructions) do
      for _,line in ipairs(wrap(instruction,66)) do nodes[#nodes+1]=gold_row(line,nil,0.22) end
    end
  end
  nodes[#nodes+1]=gold_row(prepared and 'Start search yourself. An offer does not guarantee a Gold win.' or
    'Filters are backed up. Start search with the normal controls.',nil,0.22)
  nodes[#nodes+1]=UIBox_button({label={'Back to Gold progress'},button='brainstorm_gold_search_back',minw=3.4,minh=0.35,scale=0.25})
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=0.02,minw=7.7},nodes=nodes}
end

local function font_wrap(text,font,width,max_lines)
  local lines,line={},''
  local function push()
    if line~='' then lines[#lines+1]=line;line='' end
  end
  for word in bounded_text(text):gmatch('%S+') do
    if line~='' and font:getWidth(line..' '..word)>width then push() end
    while font:getWidth(word)>width and #word>1 do
      local cut=#word
      while cut>1 and font:getWidth(word:sub(1,cut))>width do cut=cut-1 end
      if line~='' then push() end
      lines[#lines+1]=word:sub(1,cut);word=word:sub(cut+1)
    end
    line=line=='' and word or line..' '..word
  end
  push()
  if #lines>max_lines then
    while #lines>max_lines do table.remove(lines) end
    local tail=lines[max_lines]
    while #tail>0 and font:getWidth(tail..'...')>width do tail=tail:sub(1,-2) end
    lines[max_lines]=tail..'...'
  end
  return lines
end
function A.draw()
  A.hud_bounds,A.execute_bounds,A.hud_action_key,A.hud_auto_stop,A.hud_search_stop,A.hud_status_only=nil,nil,nil,nil,nil,nil
  local diagnostic=A.search_diagnostics(false)
  if (not diagnostic and (not A.active() or not Brainstorm.config.advisor.hud)) or
    G.OVERLAY_MENU or G.SETTINGS.paused or G.screenwipe then return end
  local graphics=love.graphics
  graphics.push('all');graphics.origin()
  local width,height=graphics.getDimensions()
  local scale=math.max(0.7,math.min(1.5,height/900))
  local w,h=math.min(width*.34,430*scale),(diagnostic and 110 or 82)*scale
  local button_w,gap=100*scale,6*scale
  local x,y=width-w-button_w-gap-12*scale,height-h-12*scale
  A.hud_bounds={x=x,y=y,w=w,h=h}
  A.execute_bounds={x=x+w+gap,y=y,w=button_w,h=h}
  A.hud_status_only=diagnostic~=nil
  A.hud_action_key=not diagnostic and A.published_key or nil
  A.hud_retry_generation=A.published_generation
  A.hud_auto_stop=diagnostic and diagnostic.busy and diagnostic.owner=='auto' or false
  A.hud_search_stop=diagnostic and diagnostic.busy and diagnostic.owner=='manual' or false
  if not A.font or A.font_size~=math.floor(16*scale) then
    A.font_size=math.floor(16*scale);A.font=graphics.newFont(A.font_size)
  end
  graphics.setFont(A.font)
  graphics.setColor(.035,.07,.065,.94);graphics.rectangle('fill',x,y,w,h,7*scale,7*scale)
  graphics.setColor(.28,.9,.65,1)
  local heading=(A.hud_auto_stop and 'AUTO-RUN' or diagnostic and 'SEARCH' or 'ADVISOR')..' / '..version()
  local header_scale=math.min(1,(w-20*scale)/math.max(1,A.font:getWidth(heading)))
  graphics.print(heading,x+10*scale,y+7*scale,0,header_scale,header_scale)
  graphics.setColor(1,1,1,1)
  if diagnostic then
    for i,line in ipairs(font_wrap(diagnostic.text,A.font,w-20*scale,4)) do
      graphics.print(line,x+10*scale,y+(28+(i-1)*18)*scale)
    end
  else
    local title=bounded_text(A.display.title)
    while A.font:getWidth(title)>w-22*scale and #title>4 do title=title:sub(1,-5)..'...' end
    graphics.print(title,x+10*scale,y+30*scale)
    graphics.setColor(.72,.77,.74,1)
    graphics.printf(A.display.status,x+10*scale,y+53*scale,w-20*scale)
  end
  local stop=A.hud_auto_stop or A.hud_search_stop
  local execute_ready=stop or not diagnostic and A.can_execute and A.can_execute()
  if execute_ready then graphics.setColor(.08,.46,.30,.97) else graphics.setColor(.12,.17,.15,.94) end
  local button=A.execute_bounds
  graphics.rectangle('fill',button.x,button.y,button.w,button.h,7*scale,7*scale)
  if execute_ready then graphics.setColor(1,1,1,1) else graphics.setColor(.55,.62,.58,1) end
  graphics.printf(stop and 'STOP' or diagnostic and 'STATUS' or execute_ready and 'EXECUTE' or 'WAIT',
    button.x+3*scale,button.y+23*scale,button.w-6*scale,'center')
  graphics.printf(stop and (A.hud_search_stop and 'Cancel search' or 'Keep this run') or
    diagnostic and 'Click details' or execute_ready and 'One action' or 'Fresh advice',
    button.x+3*scale,button.y+48*scale,button.w-6*scale,'center')
  graphics.pop()
end

if not Brainstorm.advisor_ui_hooks then
  Brainstorm.advisor_ui_hooks = true
  local draw = Game.draw
  function Game:draw(...)
    draw(self, ...)
    if Brainstorm.Advisor then Brainstorm.Advisor.draw() end
  end
  local mousepressed = love.mousepressed
  function love.mousepressed(x, y, button, ...)
    local advisor = Brainstorm.Advisor
    local bounds = advisor and advisor.hud_bounds
    local execute=advisor and advisor.execute_bounds
    if execute and button==1 and not G.OVERLAY_MENU and not G.SETTINGS.paused and
      (advisor.hud_status_only or advisor.active())
      and x>=execute.x and x<=execute.x+execute.w and y>=execute.y and y<=execute.y+execute.h then
      -- Swallow disabled clicks too, so they never hit a game control beneath.
      -- Honor the button that was drawn, even if another input just stopped
      -- the controller. A stale STOP must never become an Execute action.
      if advisor.hud_search_stop then
        if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.stop('HUD Search Stop clicked.') end
        return
      end
      if advisor.hud_auto_stop then
        if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('HUD Stop clicked.') end
        return
      end
      if advisor.hud_status_only then advisor.open_search_status();return end
      if advisor.execute and advisor.hud_action_key then advisor.execute(advisor.hud_action_key,advisor.hud_retry_generation) end
      return
    end
    if bounds and button == 1 and not G.OVERLAY_MENU and not G.SETTINGS.paused and
      (advisor.hud_status_only or advisor.active())
      and x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
      if advisor.hud_status_only then advisor.open_search_status() else advisor.open() end
      return
    end
    if mousepressed then return mousepressed(x, y, button, ...) end
  end
end
