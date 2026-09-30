local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function equal(actual, expected, message)
  check(actual == expected, (message or 'values differ') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

local overlay_calls, exits, underlying_clicks = 0, 0, 0
local A = {
  display = {title = 'Comparing moves...', status = 'Calculating the complete recommendation'},
  page = 1, lines = {'Comparing plays and discard draws.'},
  active = function() return true end, defaults = function() end,
  select = function() end,
}
Brainstorm = {VERSION = 'Brainstorm vTEST', Advisor = A, config = {advisor = {enabled = true}}, writeConfig = function() end}
love, Game = {mousepressed = function() underlying_clicks = underlying_clicks + 1 end}, {draw = function() end}
G = {
  UIT = {ROOT = 'ROOT', R = 'R', C = 'C', T = 'T', O = 'O'},
  C = {CLEAR = {}, GREEN = {}, ORANGE = {}, WHITE = {}, UI = {TEXT_INACTIVE = {0.1, 0.1, 0.1, 1}}},
  SETTINGS = {}, FUNCS = {},
}
Moveable = function() return {remove = function(self) self.removed = true end} end
UIBox = function(args)
  local object = {definition = args.definition, config = args.config, elements = {}, recalculations = 0}
  function object:remove() self.removed = true end
  function object:recalculate() self.recalculations = self.recalculations + 1 end
  function object:get_UIE_by_ID(id) return self.elements[id] end
  local function scan(definition)
    if definition.config and definition.config.id then
      object.elements[definition.config.id] = {config = definition.config, UIBox = object}
    end
    for _, child in ipairs(definition.nodes or definition.contents or {}) do scan(child) end
  end
  scan(args.definition)
  return object
end
G.FUNCS.overlay_menu = function(args)
  overlay_calls = overlay_calls + 1
  if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
  G.OVERLAY_MENU = UIBox(args)
end
G.FUNCS.exit_overlay_menu = function()
  exits = exits + 1
  if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
  G.OVERLAY_MENU = nil
  G.SETTINGS.paused = false
end
create_UIBox_generic_options = function(args) return args end
UIBox_button = function(args) return {n = 'BUTTON', config = args} end
create_toggle = function(args) return {n = 'TOGGLE', config = args} end
dofile('Brainstorm/UI/advisor.lua')

local function text_and_buttons(content)
  local texts, buttons = {}, {}
  local function visit(node)
    if node.config and node.config.text then texts[node.config.text] = node.config end
    if node.config and node.config.button then buttons[node.config.button] = node.config end
    for _, child in ipairs(node.nodes or {}) do visit(child) end
  end
  visit(content.definition)
  return texts, buttons
end

A.render_menu()
equal(overlay_calls, 0, 'background render never opens a popup')
A.open()
equal(overlay_calls, 1, 'explicit open creates exactly one overlay')
check(A.menu_open and G.SETTINGS.paused, 'explicit open owns panel and pauses game')
local overlay = G.OVERLAY_MENU
local holder = overlay:get_UIE_by_ID('brainstorm_advisor_contents')
check(holder ~= nil, 'content holder exists')
equal(holder.config.object.config.parent, holder, 'content belongs to native holder')
equal(overlay.recalculations, 1, 'initial content sizes the overlay')
local first = holder.config.object
local texts, buttons = text_and_buttons(first)
local status = texts['Calculating the complete recommendation']
check(status and status.colour ~= G.C.UI.TEXT_INACTIVE, 'status uses its own readable color')
check(status.colour[1] >= 0.8 and status.colour[2] >= 0.8 and status.colour[3] >= 0.8, 'status is light gray')

A.lines = {'Comparing discard draws'}
A.render_menu()
equal(overlay_calls, 1, 'calculation progress never reconstructs overlay')
equal(G.OVERLAY_MENU, overlay, 'calculating overlay identity preserved')
check(not overlay.removed and first.removed, 'only prior content removed')
texts, buttons = text_and_buttons(holder.config.object)
check(texts['Comparing moves...'] and texts['Comparing discard draws'], 'calculation content updated')
equal(buttons.brainstorm_advisor_select, nil, 'calculating panel offers no provisional selection')

local calculating = holder.config.object
A.display.title, A.display.status = 'Final discard', 'Estimated | 1200 scores compared'
A.selection = {kind = 'discard'}
A.lines = {}
for i = 1, 24 do A.lines[i] = 'Detail line ' .. i end
A.render_menu()
equal(overlay_calls, 1, 'final progress never reconstructs overlay')
check(calculating.removed and not overlay.removed, 'final replaces content only')
texts, buttons = text_and_buttons(holder.config.object)
check(texts['Final discard'] and texts['Estimated | 1200 scores compared'], 'final title and status visible')
check(texts['Detail line 1'] and texts['Detail line 11'] and not texts['Detail line 12'], 'first details page bounded')
equal(buttons.brainstorm_advisor_select.label[1], 'Select cards to discard', 'final action updated')
equal(buttons.brainstorm_advisor_page.label[1], 'More details (1/3)', 'page count updated')

local first_page = holder.config.object
G.FUNCS.brainstorm_advisor_page()
equal(overlay_calls, 1, 'pagination never reconstructs overlay')
equal(G.OVERLAY_MENU, overlay, 'pagination preserves overlay identity')
check(first_page.removed and not overlay.removed, 'pagination replaces content only')
texts = text_and_buttons(holder.config.object)
check(texts['Detail line 12'] and texts['Detail line 22'] and not texts['Detail line 1'], 'second page displayed')
equal(G.SETTINGS.paused, true, 'render/page do not unpause')

A.selection, A.lines = nil, {'Waiting for the game...'}
A.render_menu()
equal(A.page, 1, 'shorter update clamps current page')
texts, buttons = text_and_buttons(holder.config.object)
equal(buttons.brainstorm_advisor_select, nil, 'obsolete action removed')
equal(buttons.brainstorm_advisor_page, nil, 'obsolete pagination removed')
equal(overlay_calls, 1, 'invalidation never reconstructs overlay')

A.open()
equal(overlay_calls, 1, 'reopening current advisor reuses existing overlay')
G.FUNCS.brainstorm_advisor_close()
equal(exits, 1, 'close exits once')
equal(A.menu_open, false, 'close releases ownership')
equal(A.menu_overlay, nil, 'close releases overlay reference')
A.render_menu()
equal(overlay_calls, 1, 'late progress cannot reopen a closed advisor')
A.open()
equal(overlay_calls, 2, 'new explicit open creates a new overlay')

A.selection = {kind = 'use', indices = {2, 4}}
A.display.title, A.lines = 'Use Strength', {'Target cards: #2, #4'}
A.render_menu()
local target_holder = G.OVERLAY_MENU:get_UIE_by_ID('brainstorm_advisor_contents')
texts, buttons = text_and_buttons(target_holder.config.object)
equal(buttons.brainstorm_advisor_select.label[1], 'Select consumable targets', 'consumable button distinguishes targets from a play')
equal(overlay_calls, 2, 'consumable update does not open another popup')

local foreign = UIBox({definition = {nodes = {}}})
G.OVERLAY_MENU = foreign
A.render_menu()
equal(overlay_calls, 2, 'late progress cannot replace another menu')
equal(G.OVERLAY_MENU, foreign, 'other menu preserved')
equal(A.menu_open, false, 'replaced overlay releases advisor ownership')
check(not foreign.removed, 'other menu never removed')

-- The adjacent HUD control executes without visiting the panel. Its identity
-- is captured when drawn, and disabled clicks cannot hit the game beneath it.
G.OVERLAY_MENU, G.SETTINGS.paused = nil, false
Brainstorm.config.advisor.hud = true
local labels, execute_calls, clicked_key, executable = {}, 0, nil, true
love.graphics = {
  push = function() end, pop = function() end, origin = function() end,
  getDimensions = function() return 1600, 900 end,
  newFont = function() return {getWidth = function(_, text) return #text * 8 end} end,
  setFont = function() end, setColor = function() end, rectangle = function() end,
  print = function(text) labels[text] = true end,
  printf = function(text) labels[text] = true end,
}
A.can_execute = function() return executable end
A.execute = function(key)
  execute_calls, clicked_key = execute_calls + 1, key
  return executable
end
A.published_key = 'drawn recommendation'
A.draw()
check(labels.EXECUTE and A.execute_bounds, 'ready HUD displays Execute beside advice')
check(A.execute_bounds.x > A.hud_bounds.x + A.hud_bounds.w, 'button has a separate adjacent hitbox')
local button = A.execute_bounds
love.mousepressed(button.x + 1, button.y + 1, 1)
equal(execute_calls, 1, 'one HUD click dispatches exactly once')
equal(clicked_key, 'drawn recommendation', 'click refers to visually displayed recommendation')
equal(overlay_calls, 2, 'execution never opens a popup')
equal(underlying_clicks, 0, 'execution click never reaches underlying controls')
A.published_key = 'new recommendation'
love.mousepressed(button.x + 1, button.y + 1, 1)
equal(clicked_key, 'drawn recommendation', 'undrawn newer recommendation is not substituted by the HUD')
executable, A.published_key, labels = false, nil, {}
A.draw()
check(labels.WAIT, 'calculating or resolving HUD displays Wait')
love.mousepressed(button.x + 1, button.y + 1, 1)
equal(execute_calls, 2, 'Wait without a published recommendation never dispatches')
equal(underlying_clicks, 0, 'Wait clicks are consumed rather than passed through')
A.published_key = 'finished but not drawn'
love.mousepressed(button.x + 1, button.y + 1, 1)
equal(execute_calls, 2, 'advice finished after Wait draw cannot execute before it is shown')
love.mousepressed(1, 1, 1)
equal(underlying_clicks, 1, 'ordinary game clicks still reach the original handler')
love.mousepressed(button.x + 1, button.y + 1, 2)
equal(underlying_clicks, 2, 'right click retains normal behavior')
local badge = A.hud_bounds
love.mousepressed(badge.x + 1, badge.y + 1, 1)
equal(overlay_calls, 3, 'badge itself still opens the details panel')
A.draw()
equal(A.execute_bounds, nil, 'Execute hitbox disappears while a menu is open')

local writes,invalidations=0,0
Brainstorm.writeConfig=function()writes=writes+1 end
A.settings_changed=function()invalidations=invalidations+1 end
Brainstorm.config.advisor.enabled=false
Brainstorm.config.advisor.challenge_only=true
Brainstorm.config.advisor.hud=false
local page=Brainstorm.createAdvisorPage()
local page_texts,page_buttons=text_and_buttons({definition=page})
check(page_texts['Run Advisor / Brainstorm vTEST'] and page_texts['Advice for normal decks and challenge runs.'],'settings page shows loaded version and names both normal and challenge advice')
check(page_buttons.brainstorm_advisor_enable_normal and page_buttons.brainstorm_advisor_enable_normal.label[1]=='Enable normal-deck advice','settings page has a clear manual enable action')
equal(writes,0,'settings-page render does not write configuration')
equal(invalidations,0,'settings-page render does not discard current work')
G.FUNCS.brainstorm_advisor_enable_normal()
check(Brainstorm.config.advisor.enabled and Brainstorm.config.advisor.challenge_only==false,'manual button changes only the requested availability flags')
equal(Brainstorm.config.advisor.hud,false,'manual availability change preserves the badge preference')
equal(writes,1,'manual availability change saves once')
equal(invalidations,1,'manual availability change uses runtime invalidation')

do
  local status,reads=nil,0
  A.gold_status=function() reads=reads+1;return Brainstorm.config.advisor.gold_stickers and status or nil end
  local refreshes=0;Brainstorm.showGoldStickersPage=function() refreshes=refreshes+1 end
  local before=writes
  local texts,buttons=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['Completionist++'] and buttons.brainstorm_gold_enable,'collection goal is an explicit visible mode')
  equal(writes,before,'rendering the disabled goal page changes no settings')
  status={counts={total=150,complete=138,missing=11,unknown=1},held_status='complete',held_target_count=1,
    held_target_keys={'j_1'},targets={},eligibility={eligible=true}}
  G.P_CENTERS={}
  for i=1,12 do local key='j_'..i;status.targets[i]={key=key,status=i==12 and 'unknown' or 'missing'};G.P_CENTERS[key]={name='Target '..i} end
  G.FUNCS.brainstorm_gold_enable()
  check(Brainstorm.config.advisor.enabled and Brainstorm.config.advisor.challenge_only==false and Brainstorm.config.advisor.gold_stickers,
    'explicit objective activation enables normal advice and tracking together')
  equal(writes,before+1,'objective activation persists once')
  equal(Brainstorm.config.advisor.hud,false,'objective activation preserves HUD preference')
  equal(refreshes,1,'goal activation refreshes its own settings page')
  texts,buttons=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['138 / 150 Gold  |  11 missing  |  1 unknown'],'unknown records remain distinct in the UI')
  check(texts['* Target 1'] and texts['Target 2'],'carried target marker is visible in separate columns')
  check(not texts['Target 9'],'compact page limits the visible list to eight entries')
  check(not buttons.brainstorm_gold_enable,'already-enabled tracking omits the redundant enable button')
  check(buttons.brainstorm_gold_previous.col and buttons.brainstorm_gold_next.col,'pagination requests horizontal button columns from the real helper')
  check(buttons.brainstorm_gold_next and buttons.brainstorm_gold_previous,'long remaining lists are paginated')
  G.FUNCS.brainstorm_gold_next()
  texts=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['Target 9'] and texts['Target 11'] and texts['? Target 12'],'later page includes unknown marker and all remaining entries')
  G.FUNCS.brainstorm_gold_previous()
  status.held_status='unavailable';status.eligibility={eligible=false,reasons={'seeded_run'}}
  texts=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['Held Joker progress is unavailable; no carried count is assumed.'],'unavailable held metadata is not shown as zero carried')
  check(texts['Manually seeded runs do not earn collection stickers.'],'ineligible run has an actionable explanation')
  check(not texts['* Target 1'],'unknown held membership does not mark target as carried')
  status.eligibility={eligible=false,reasons={'outside_run_stage'}}
  texts=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['Start a normal Gold Stake run to use the collection objective.'],'outside-run reason names the next user action')
  status.stake_status='unsupported';status.stake_reason='modified_gold_sticker_map'
  texts=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['Gold mapping unavailable: modified_gold_sticker_map.'],'metadata failure states the precise failing mapping instead of a generic message')
  status.stake_status=nil;status.stake_reason=nil
  status={counts={total=150,complete=150,missing=0,unknown=0},held_status='complete',held_target_count=0,targets={},eligibility={eligible=false,reasons={'run_already_won'}}}
  texts,buttons=text_and_buttons({definition=Brainstorm.createGoldStickersPage()})
  check(texts['All 150 vanilla Jokers have a recorded Gold win.'],'fully completed profile is stated only from complete history')
  check(not buttons.brainstorm_gold_next,'completed list has no stale pagination')
  equal(writes,before+1,'view changes and pagination never write progress/config')
  Brainstorm.config.advisor.gold_stickers=false;G.FUNCS.brainstorm_gold_toggle()
  equal(writes,before+2,'user toggle is the only further configuration write')
end
do
  A.gold_search=dofile('Brainstorm/Advisor/gold_search.lua')
  A.snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
  local tracker=dofile('Brainstorm/Advisor/gold_stickers.lua')
  local goal={schema=1,goal='gold_stickers',profile_id='synthetic-a',metadata_status='complete',
    catalog_status='complete',stake_status='complete',by_key={},counts={total=150,complete=146,missing=4,unknown=0}}
  local missing={j_golden=true,j_perkeo=true,j_steel_joker=true,j_stone=true}
  for _,key in ipairs(tracker.target_keys()) do goal.by_key[key]={key=key,status=missing[key] and 'missing' or 'complete'} end
  Brainstorm.config.advisor.gold_stickers=true
  A.gold_status=function()return Brainstorm.config.advisor.gold_stickers and goal or nil end
  local original={joker_targets={'Blueprint'},soul_count=2,tag_name='tag_charm',future={keep=7}}
  Brainstorm.config.ar_filters=A.snapshot.copy(original);Brainstorm.config.collection_previous_filters=nil
  local before=writes;local cycles,rendered={},nil
  create_option_cycle=function(args) cycles[args.opt_callback]=args;return {n='CYCLE',config=args} end
  local function render() cycles={};rendered=Brainstorm.createGoldSearchPage();return text_and_buttons({definition=rendered}) end
  Brainstorm.showGoldSearchPage=function()render()end
  local function select_key(key)
    local choices=assert(A.gold_search.choices(goal))
    for index,entry in ipairs(choices) do if entry.key==key then G.FUNCS.brainstorm_gold_search_select({to_key=index});return end end
    error('missing synthetic choice '..key)
  end
  local texts,buttons=render()
  check(buttons.brainstorm_gold_search_prepare and cycles.brainstorm_gold_search_select,'missing-target page has manual selection and preparation')
  check(texts['Normal search assumes all profile unlocks.'],'native profile assumption is visible before preparation')
  equal(writes,before,'rendering target choices writes no settings')
  local game_before=A.snapshot.fingerprint(G.GAME)
  select_key('j_golden');G.FUNCS.brainstorm_gold_search_prepare()
  equal(writes,before+1,'one prepare click saves once')
  equal(Brainstorm.config.ar_filters.joker_targets[1],'Golden Joker','native target comes from canonical missing identity')
  equal(A.snapshot.fingerprint(Brainstorm.config.collection_previous_filters),A.snapshot.fingerprint(original),'original filters are preserved completely')
  select_key('j_perkeo');G.FUNCS.brainstorm_gold_search_prepare()
  equal(Brainstorm.config.ar_filters.joker_target_locations[1],'soul_pack','Legendary uses the existing Soul route')
  equal(Brainstorm.config.ar_filters.tag_name,'tag_charm','Legendary prepares Charm')
  equal(A.snapshot.fingerprint(Brainstorm.config.collection_previous_filters),A.snapshot.fingerprint(original),'subsequent target choice retains the first backup')
  local written=writes
  goal.profile_id='synthetic-b';G.FUNCS.brainstorm_gold_search_prepare()
  equal(writes,written,'profile switch after rendering rejects stale prepare')
  select_key('j_golden');goal.by_key.j_golden.status='complete';goal.counts.complete=147;goal.counts.missing=3
  G.FUNCS.brainstorm_gold_search_prepare()
  equal(writes,written,'newly completed target after rendering rejects stale prepare')
  select_key('j_stone');texts,buttons=render()
  check(not buttons.brainstorm_gold_search_prepare and buttons.brainstorm_gold_search_marble,'Stone exposes only an explicitly named prerequisite route')
  G.FUNCS.brainstorm_gold_search_prepare();equal(writes,written,'hidden direct Stone action still refuses')
  G.FUNCS.brainstorm_gold_search_marble()
  equal(Brainstorm.config.ar_filters.joker_targets[1],'Marble Joker','explicit prerequisite searches Marble, not a promised Stone offer')
  equal(writes,written+1,'explicit prerequisite saves once')
  check(#rendered.nodes<=20,'longest prepared prerequisite route keeps a bounded single-page layout')
  select_key('j_steel_joker');texts,buttons=render()
  check(not buttons.brainstorm_gold_search_prepare and not buttons.brainstorm_gold_search_marble,'other locked targets expose no unsupported search button')
  G.FUNCS.brainstorm_gold_search_marble()
  equal(writes,written+1,'stale prerequisite callback never falls back to another direct target')
  Brainstorm.ar_active=true;G.FUNCS.brainstorm_gold_search_restore()
  equal(writes,written+1,'active search protects filter restoration')
  Brainstorm.ar_active=false;G.FUNCS.brainstorm_gold_search_restore()
  equal(writes,written+2,'manual restoration saves exactly once')
  equal(A.snapshot.fingerprint(Brainstorm.config.ar_filters),A.snapshot.fingerprint(original),'restoration returns the exact original filters')
  equal(Brainstorm.config.collection_previous_filters,nil,'successful restoration clears only the filter backup')
  equal(A.snapshot.fingerprint(G.GAME),game_before,'target UI never changes game/stake/seed/progress metadata')
  select_key('j_perkeo');G.FUNCS.brainstorm_gold_search_prepare()
  Brainstorm.config.ar_filters.future.keep=99;texts=render()
  check(texts['Target, profile or filters changed. Prepare the target again.'],'changed filters invalidate displayed ready status')
  select_key('j_perkeo');G.FUNCS.brainstorm_gold_search_prepare()
  goal.by_key.j_perkeo.status='complete';goal.counts.complete=148;goal.counts.missing=2
  texts,buttons=render()
  check(texts['Target, profile or filters changed. Prepare the target again.'],'same-profile sticker completion clears the previous target ready message')
  check(not texts['Perkeo Soul preset ready. Start search yourself.'],'old prepared route never appears under a replacement target')
  Brainstorm.config.advisor.gold_stickers=false;texts,buttons=render()
  check(buttons.brainstorm_gold_enable and not buttons.brainstorm_gold_search_prepare,'disabled tracking has an explicit enable action and no stale target')
  equal(cycles.brainstorm_gold_search_select,nil,'disabled tracking shows no stale selector')
end
print('advisor_ui: ' .. checks .. ' checks passed')
