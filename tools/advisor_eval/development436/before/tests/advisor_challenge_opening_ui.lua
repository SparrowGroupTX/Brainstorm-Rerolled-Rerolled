local O=dofile('Brainstorm/Core/challenge_opening.lua')
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local writes,searches,starts,deletes,alerts,exits,removed=0,0,0,0,0,0,0
G={UIT={ROOT='ROOT',R='R',C='C',T='T'},C={GREEN={},WHITE={},RED={},CLEAR={}},
  STAGES={RUN=1},STAGE=1,STATES={BLIND_SELECT=2},STATE=2,STATE_COMPLETE=true,
  jokers={cards={},config={card_limit=5}},consumeables={cards={}},FUNCS={}}
local definition={id='c_city_1',deck={type='Challenge Deck'},rules={custom={{id='retained_rule'}}}}
G.GAME={challenge='c_city_1',challenge_tab=definition,round=0,stake=1,skips=0,
  blind_on_deck='Small',round_resets={ante=1,blind_states={Small='Select'}},banned_keys={},modifiers={}}
for i=1,2 do G.jokers.cards[i]={config={center={key='j_joker'}},ability={}} end
G.delete_run=function() deletes=deletes+1 end
G.start_run=function() starts=starts+1 end
G.FUNCS.exit_overlay_menu=function() exits=exits+1;G.OVERLAY_MENU=nil end
local normal_filters={soul_count=1,voucher_name='v_telescope',joker_targets={'Perkeo'}}
Brainstorm={config={ar_filters=normal_filters},ar_active=false,writeConfig=function() writes=writes+1 end,
  removeAttentionText=function() removed=removed+1 end}
O.attach(Brainstorm,{alert=function() alerts=alerts+1 end,search=function()
  searches=searches+1;error('fixture missing native export')
end})
create_toggle=function(args) return {n='TOGGLE',config=args} end
create_option_cycle=function(args) return {n='CYCLE',config=args} end
UIBox_button=function(args) return {n='BUTTON',config=args} end
dofile('Brainstorm/UI/challenge_opening.lua')
check(not Brainstorm.ar_active and searches==0 and starts==0 and deletes==0,'loading the opening UI never starts or replaces a run')
local function inspect()
  local tree=Brainstorm.createChallengeOpeningPage()
  local toggles,cycles,buttons,texts={},{},{},{}
  local columns=0
  local function walk(node)
    if node.n=='TOGGLE' then toggles[#toggles+1]=node.config end
    if node.n=='CYCLE' then cycles[#cycles+1]=node.config end
    if node.n=='BUTTON' then buttons[node.config.button]=node.config end
    if node.n=='C' then columns=columns+1 end
    if node.config and node.config.text then texts[node.config.text]=true end
    for _,child in ipairs(node.nodes or {}) do walk(child) end
  end
  walk(tree)
  check(columns==2 and #tree.nodes<=15,'compact two-column layout keeps all controls and disclosures in one page')
  return toggles,cycles,buttons,texts
end
local toggles,cycles,buttons,texts=inspect()
check(#toggles==2 and #cycles==4,'page retains two Legendary selectors and adds separate optional later controls')
check(cycles[1].current_option==1 and cycles[2].current_option==1,'both new selectors default to Any')
check(buttons.brainstorm_opening_start~=nil,'search is an explicit separate button')
check(texts['Fresh challenge only: replaces this run and keeps its rules.'],'page explains the run replacement before starting')
local disclosed=false
for text in pairs(texts) do if text:find('first-pack duplicate-Soul exception',1,true) then disclosed=true end end
check(disclosed,'page discloses the special Soul rule')
check(texts['19 opening challenges; later targets exclude Bram. No Jokerless.'],'page exposes the compatibility limit')
for i=1,4 do inspect() end
check(searches==0 and starts==0 and deletes==0 and writes==0 and alerts==0 and exits==0,
  'rendering or reopening settings neither searches nor opens/closes overlays')
local cfg=O.defaults(Brainstorm.config)
check(toggles[1].ref_table==cfg and toggles[1].ref_value=='enabled','toggle edits only the dedicated opening configuration')
toggles[1].ref_table[toggles[1].ref_value]=false;toggles[1].callback()
check(not cfg.enabled and writes==1 and not Brainstorm.ar_active,'disabling saves the setting without triggering a search')
toggles[1].ref_table[toggles[1].ref_value]=true;toggles[1].callback()
check(cfg.enabled and writes==2 and not Brainstorm.ar_active,'enabling saves the setting without triggering a search')
local function choose(slot,index)
  local cycle=cycles[slot];cycle.current_option=index
  G.FUNCS[cycle.opt_callback]({cycle_config=cycle,to_key=index,to_val=cycle.options[index]})
end
choose(1,6);choose(2,5)
check(cfg.targets[1]=='j_perkeo' and cfg.targets[2]=='j_chicot','selector callbacks retain their own slot and correct native keys')
check(writes==4 and not Brainstorm.ar_active and searches==0,'target changes save once each without starting')
local _,selected=inspect()
check(selected[1].current_option==6 and selected[2].current_option==5,'reopening settings reflects the persisted pair')
choose(1,1)
check(cfg.targets[1]=='' and cfg.targets[2]=='j_chicot','Any clears only the selected target')
local valid_writes=writes
for _,bad in ipairs({0,7,-1,'2',2.5}) do choose(1,bad) end
G.FUNCS.brainstorm_opening_target_1(nil)
G.FUNCS.brainstorm_opening_target_2({})
check(writes==valid_writes and cfg.targets[1]=='' and cfg.targets[2]=='j_chicot','malformed option events do not change settings or schedule work')
check(Brainstorm.config.ar_filters==normal_filters and normal_filters.soul_count==1 and
  normal_filters.voucher_name=='v_telescope' and normal_filters.joker_targets[1]=='Perkeo',
  'challenge controls preserve normal reroll settings')
check(G.GAME.challenge_tab==definition and searches==0 and starts==0 and deletes==0,'all setting edits preserve the current challenge')

choose(1,5) -- duplicate Chicot is rejected by the actual search-start validator.
G.OVERLAY_MENU={}
G.FUNCS.brainstorm_opening_start()
check(alerts==1 and not Brainstorm.ar_active and searches==0 and starts==0 and deletes==0,
  'explicit start with duplicate targets reports once and never searches')
check(G.OVERLAY_MENU~=nil and exits==0,'invalid start leaves settings available for correction')
choose(1,6)
G.GAME.round=1;G.FUNCS.brainstorm_opening_start()
check(alerts==2 and not Brainstorm.ar_active and searches==0,'progressed challenge cannot be restarted by the search button')
G.GAME.round=0
G.FUNCS.brainstorm_opening_start()
check(Brainstorm.ar_active and exits==1 and G.OVERLAY_MENU==nil,'valid explicit start schedules search and closes only its settings overlay')
check(searches==0 and starts==0 and deletes==0,'start button defers native work and never directly replaces the run')
inspect();inspect()
check(Brainstorm.ar_active and searches==0 and exits==1,'rendering after explicit start does not invoke another search or close another overlay')
Brainstorm.ar_text={};Brainstorm.ar_frames=60;Brainstorm.ar_timer=9
Brainstorm.challengeOpeningSearch('I1L21111')
check(searches==1 and alerts==3 and not Brainstorm.ar_active and starts==0 and deletes==0,
  'a native failure stops the scheduled search without replacing the challenge')
check(removed==1 and Brainstorm.ar_text==nil and Brainstorm.ar_frames==0 and Brainstorm.ar_timer==0,
  'failed search removes progress text and resets timers instead of leaving a reroll indicator')
check(cfg.later_enabled==false and cfg.later_target=='j_blueprint' and cfg.later_ante==2,
  'later filter defaults off without changing the existing pair')
local later_index
for i,label in ipairs(cycles[3].options) do if label=='Brainstorm' then later_index=i end end
check(later_index~=nil and #cycles[3].options==20,'later selector includes the complete supported Rare catalog')
choose(3,later_index);choose(4,7)
check(cfg.later_target=='j_brainstorm' and cfg.later_ante==8,'later selectors persist canonical keys and by-Ante deadlines')
check(cfg.targets[1]=='j_perkeo' and cfg.targets[2]=='j_chicot','later target does not replace either Legendary')
local unchanged_writes=writes
for _,bad in ipairs({0,21,-1,'2',2.5}) do choose(3,bad) end
for _,bad in ipairs({0,8,-1,'2',2.5}) do choose(4,bad) end
G.FUNCS.brainstorm_opening_later_target(nil);G.FUNCS.brainstorm_opening_later_ante({})
check(writes==unchanged_writes,'invalid later option events never mutate preferences')
local rendered_toggles=inspect()
rendered_toggles[2].ref_table.later_enabled=true;rendered_toggles[2].callback()
local _,_,_,later_text=inspect()
check(later_text['Offer only: survival, purchase and retention unverified.'],'later offer clearly distinguishes acquisition and retention')
check(later_text['Later filter only: play all blinds; no rerolls, packs or vouchers.'],'conditional route disclosed before starting')
check(later_text['No Showman or Joker-generating consumables; other support buys/sales allowed.'],'ordinary scoring development remains allowed')
check(searches==1 and starts==0 and deletes==0 and not Brainstorm.ar_active,'editing or rendering later controls never searches or controls gameplay')
rendered_toggles[2].ref_table.later_enabled=false;rendered_toggles[2].callback()
local failure_alerts=alerts
for i=1,4 do inspect() end
choose(2,1);G.FUNCS.brainstorm_opening_config()
Brainstorm.challengeOpeningSearch('I1L21111') -- A stale scheduled tick must be inert.
check(searches==1 and alerts==failure_alerts and not Brainstorm.ar_active,
  'failed search does not retry or reopen alerts when settings render or change')
check(removed==1,'a stale scheduled tick does not remove or recreate progress UI again')
check(G.GAME.challenge_tab==definition,'failed search preserves the exact challenge definition')
G.GAME.filter_info={later={offer_status='conditional',target_key='j_blueprint',found_ante=2,shop=3,slot=1}}
local _,_,_,final_text=inspect()
check(final_text['Current conditional target: Blueprint'] and final_text['Predicted offer: Ante 2, shop 3, slot 1.'],
  'maximum-height page retains the conditional found offer beside every control')
local cost_visible=false
for text in pairs(final_text) do if text:find('Search: ',1,true)==1 then cost_visible=true end end
check(cost_visible,'search batch/cost summary stays reviewable after an error or stop')
do
  G.GAME.challenge='c_jokerless_1'
  Brainstorm.JokerlessOpeningSearch={status='Fixture ready',last={tested=512,compute_seconds=0.1}}
  local before={starts,deletes,searches,writes};local tree=Brainstorm.createChallengeOpeningPage()
  local texts,buttons={},{}
  local function walk(n)
    if n.config and n.config.text then texts[n.config.text]=true end
    if n.n=='BUTTON' then buttons[n.config.button]=true end
    for _,child in ipairs(n.nodes or {}) do walk(child) end
  end
  walk(tree)
  check(texts['Jokerless opening search'] and buttons.brainstorm_opening_start,'Jokerless receives its separate user-clicked search page')
  check(texts['Coupon + main-hand Planet + Blue seals + Telescope'],'page exposes the selected-Planet search predicate')
  check(texts['Mars develops Four of a Kind; Jupiter develops Flush.'],'page identifies the two new target hands')
  check(texts['Five of a Kind depends on later deck development.'],'page does not promise an initially available Five of a Kind Planet')
  check(starts==before[1] and deletes==before[2] and searches==before[3] and writes==before[4],'Jokerless rendering has no search or game side effects')
  Brainstorm.JokerlessOpeningSearch.searching=true;buttons={};walk(Brainstorm.createChallengeOpeningPage())
  check(buttons.brainstorm_opening_stop,'running search exposes cancellation')
  Brainstorm.JokerlessOpeningSearch.presets={{id='two_blue',label='Two Blue seals',description='Two Blue seals.'},
    {id='blue_steel',label='Blue + Steel',description='A rarer Steel seal.'},
    {id='three_blue_steel',label='Three Blue Steel',description='Three rare Steel seals.'}}
  Brainstorm.JokerlessOpeningSearch.preset='two_blue'
  local before_writes=writes
  G.FUNCS.brainstorm_jokerless_preset({cycle_config={current_option=3}})
  check(Brainstorm.JokerlessOpeningSearch.preset=='three_blue_steel' and Brainstorm.config.jokerless_opening_search.preset=='three_blue_steel',
    'explicit selector saves the stronger search preference')
  check(writes==before_writes+1 and starts==before[1] and searches==before[3],'preset selection saves without starting a run or search')
  G.FUNCS.brainstorm_jokerless_preset(nil);G.FUNCS.brainstorm_jokerless_preset({cycle_config={current_option=99}})
  check(writes==before_writes+1,'malformed preset callback is inert')
  local selected_tree=Brainstorm.createChallengeOpeningPage();local selected_cycle
  local function find_cycle(n)
    if n.n=='CYCLE' and n.config.opt_callback=='brainstorm_jokerless_preset' then selected_cycle=n.config end
    for _,child in ipairs(n.nodes or {}) do find_cycle(child) end
  end
  find_cycle(selected_tree)
  check(selected_cycle and selected_cycle.current_option==3,'selected stronger pattern appears when reopening settings')
  local Runtime=dofile('Brainstorm/Core/jokerless_search_runtime.lua')
  local writes_before_attach=writes
  local actual=Runtime.attach(Brainstorm,{opening={}})
  local actual_tree=Brainstorm.createChallengeOpeningPage()
  find_cycle(actual_tree)
  check(actual.preset=='three_blue_steel' and selected_cycle.current_option==5 and #selected_cycle.options==5,
    'real five-preset wrapper reopens the saved legacy selection by id after new defaults were inserted')
  check(writes==writes_before_attach and starts==before[1] and searches==before[3],
    'upgrading and rendering the real preset list does not rewrite the saved legacy preference or start work')
  local refs={}
  local function find_refs(n)
    if n.config and n.config.ref_table==actual then refs[n.config.ref_value]=n.config end
    for _,child in ipairs(n.nodes or {}) do find_refs(child) end
  end
  find_refs(actual_tree)
  check(refs.status and refs.progress_text and refs.timing_text and refs.compute_text,
    'Jokerless menu binds status, tested counts, wall timing and compute cost to persistent runtime state')
  actual.status='searching';actual.progress_text='512 / 1,000,000 seeds tested.'
  actual.timing_text='2.00s elapsed; 256.0 seeds/s (wall).';actual.compute_text='0.10s detached search computation.'
  check(refs.progress_text.ref_table[refs.progress_text.ref_value]=='512 / 1,000,000 seeds tested.' and
    refs.timing_text.ref_table[refs.timing_text.ref_value]=='2.00s elapsed; 256.0 seeds/s (wall).' and
    refs.compute_text.ref_table[refs.compute_text.ref_value]=='0.10s detached search computation.' and
    refs.status.ref_table[refs.status.ref_value]=='searching',
    'existing UI references show subsequent progress without rebuilding nodes or invoking work')
  check(writes==writes_before_attach and starts==before[1] and searches==before[3],
    'reading changing progress references has no settings, search or game side effects')
  G.FUNCS.brainstorm_jokerless_preset({cycle_config={current_option=1}})
  find_cycle(Brainstorm.createChallengeOpeningPage())
  check(actual.preset=='four_kind' and Brainstorm.config.jokerless_opening_search.preset=='four_kind' and selected_cycle.current_option==1,
    'user may explicitly switch a saved legacy choice to the Four of a Kind preset')
  check(writes==writes_before_attach+1 and starts==before[1] and searches==before[3],
    'new target selection only persists the requested preference')
end
print('advisor_challenge_opening_ui: '..checks..' checks passed')
