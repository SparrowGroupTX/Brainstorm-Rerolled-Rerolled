-- Exercise actual Core source snippets with detached callbacks. FFI is a pure
-- table stand-in: no native loading, searches, player game, profile or saves.
local handle=assert(io.open('Brainstorm/Core/Brainstorm.lua','rb'))
local source=handle:read('*a');handle:close()
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function slice(first,last)
  local a=assert(source:find(first,1,true),first)
  local b=assert(source:find(last,a+1,true),last)
  return source:sub(a,b-1)
end
local function execute(body,environment)
  setmetatable(environment,{__index=_G})
  local chunk=assert(loadstring(body));setfenv(chunk,environment);return chunk()
end
do
  local calls={loads=0,preloads=0,cdefs=0};local native={sentinel=true}
  local name=assert(source:match('Brainstorm%.NATIVE_FILE = "([^"]+)"'))
  local e={Brainstorm={PATH='detached/mod',NATIVE_FILE=name},ffi={os='Windows'}}
  e.ffi.cdef=function(text)
    calls.cdefs=calls.cdefs+1
    check(text:find('brainstorm_v9(',1,true) and text:find('void brainstorm_cancel_v9();',1,true),'v9 and cancellation ABI declared')
  end
  e.ffi.load=function(path)calls.loads=calls.loads+1;calls.path=path;return native end
  e.preloadImmolateRuntime=function()calls.preloads=calls.preloads+1 end
  local get=execute('local immolate,immolate_cdef_loaded\n'..
    slice('local function ensureImmolateLoaded()','local function formatCompactEstimateNumber')..'\nreturn ensureImmolateLoaded',e)
  check(get()==native and get()==native,'loader returns one cached selected library')
  check(calls.loads==1 and calls.preloads==1 and calls.cdefs==1,'loader does not overlap repeated library initialization')
  check(calls.path=='detached/mod/'..name and name:match('^Immolate%-advisor%-%x+%.dll$'),'Windows loader uses exact selected hash sidecar')
  e.ffi.load=function()error('detached missing sidecar')end
  get=execute('local immolate,immolate_cdef_loaded\n'..
    slice('local function ensureImmolateLoaded()','local function formatCompactEstimateNumber')..'\nreturn ensureImmolateLoaded',e)
  local ok,why=pcall(get)
  check(not ok and tostring(why):find('detached missing sidecar',1,true),'sidecar load error remains explicit without fallback')
end
do
  local calls={validations=0,loads=0,native=0,freed=0};local events={};local B={native_search_busy=true,
    search_estimate_generation=0,search_estimate={},config={ar_prefs={native_cpu_mode='maximum'},ar_filters={}},ar_native_query={}}
  B.validateAutoRerollFilters=function()calls.validations=calls.validations+1;return true end
  local e={Brainstorm=B,G={GAME={},E_MANAGER={add_event=function(_,event)events[#events+1]=event end}},
    Event=function(event)return event end,getCurrentDeckName=function()return 'Red Deck'end,
    getCurrentStakeLevel=function()return 8 end,getSearchEstimateFingerprint=function()return 'fixed'end,
    setSearchEstimate=function()end,finishSearchEstimate=function(...)calls.finished={...}end,
    ffi={string=function(pointer)check(pointer=='pointer','estimate reads only fake pointer');return 'fake-result'end}}
  e.ensureImmolateLoaded=function()
    calls.loads=calls.loads+1
    return {brainstorm_set_search_thread_mode=function(mode)calls.mode=mode end,
      brainstorm_estimate_v4=function(...)calls.native=calls.native+1;calls.args={...};return 'pointer'end,
      free_result=function(pointer)check(pointer=='pointer','estimate frees only fake pointer');calls.freed=calls.freed+1 end}
  end
  execute(slice('function Brainstorm.requestSearchEstimate()','function Brainstorm.loadConfig()'),e)
  check(B.requestSearchEstimate()==false and calls.validations==0 and #events==0,'native busy blocks estimator before validation or scheduling')
  B.native_search_busy=false;B.requestSearchEstimate();check(#events==1 and calls.loads==0,'idle estimator dispatch is deferred')
  B.native_search_busy=true;check(events[1].func()==true and calls.loads==0,'queued estimate cannot enter an active collection worker')
  B.native_search_busy=false;B.requestSearchEstimate();B.search_estimate_generation=B.search_estimate_generation+1
  check(events[2].func()==true and calls.native==0,'stale queued estimate cannot revive after generation invalidation')
  B.requestSearchEstimate();check(events[3].func()==true and calls.native==1 and calls.loads==1,'one valid idle estimate retains legacy dispatch')
  check(calls.mode==1 and calls.freed==1 and calls.finished[3]=='fake-result','idle estimate preserves CPU setting, cleanup and completion')
end
do
  local calls=0;local B={native_search_busy=true,startChallengeOpeningSearch=function()calls=calls+1;return 'legacy'end}
  local e={Brainstorm=B}
  execute(slice('  local start_opening=Brainstorm.startChallengeOpeningSearch','  Brainstorm.Advisor ='),e)
  check(B.startChallengeOpeningSearch()==false and calls==0,'native busy blocks challenge start')
  B.native_search_busy=false;check(B.startChallengeOpeningSearch()=='legacy' and calls==1,'idle challenge callback preserved')
  B.native_search_busy=true
  B.validateAutoRerollFilters=function()error('busy must precede validation')end
  execute(slice('function Brainstorm.autoReroll()','local cursr ='),e)
  check(B.autoReroll()==nil,'native busy blocks full legacy reroll before RNG or native use')
end
do
  local order={};local down={};local starts,validations,rerolls=0,0,0
  local B={config={keybinds={modifier='lctrl',f_reroll='r',a_reroll='a',s_state='z',l_state='x'}},
    ar_active=false,native_search_busy=false}
  B.CollectionSearchProduct={stop=function(reason)order[#order+1]='search-stop';B.last_stop=reason end}
  B.AutoRun={manual=function(self,reason)if not self.executing then order[#order+1]='auto-stop'end end}
  B.Checkpoints={hotkey=function(self,key)if key=='1'then order[#order+1]='checkpoint';return true end end}
  B.validateAutoRerollFilters=function()validations=validations+1;return true end
  B.startChallengeOpeningSearch=function()starts=starts+1 end
  B.reroll=function()rerolls=rerolls+1 end
  local e={Brainstorm=B,Controller={key_press_update=function()order[#order+1]='key-original'end,
    queue_L_cursor_press=function(self,argument)order[#order+1]='left-original';return argument end,
    queue_R_cursor_press=function(self,argument)order[#order+1]='right-original';return argument end},
    love={keyboard={isDown=function(key)return down[key]end}},G={GAME={}},saveManagerAlert=function()end}
  execute(slice('local key_press_update_ref =','function saveManagerAlert(text)'),e)
  execute(slice("for _,method in ipairs({'queue_L_cursor_press'","local update_ref = Game.update"),e)
  local controller=setmetatable({},{__index=e.Controller})
  controller:key_press_update('q',.1)
  check(table.concat(order,',')=='auto-stop,search-stop,key-original','physical keyboard cancels before original handler')
  order={};controller:key_press_update('1',.1)
  check(table.concat(order,',')=='auto-stop,search-stop,checkpoint','checkpoint hotkey cancels before save/load callback')
  order={};check(controller:queue_L_cursor_press('left')=='left','left input original result retained')
  check(table.concat(order,',')=='auto-stop,search-stop,left-original','physical left press cancels before original handler')
  order={};check(controller:queue_R_cursor_press('right')=='right','right input original result retained')
  check(table.concat(order,',')=='auto-stop,search-stop,right-original','physical right press cancels before original handler')
  down.lctrl=true;B.native_search_busy=true;order={};controller:key_press_update('a',.1)
  check(not B.ar_active and validations==0 and starts==0 and B.last_stop=='Search hotkey pressed.','Ctrl+A cancels busy search without starting legacy search')
  B.native_search_busy=false;B.ar_hotkey_down=false;controller:key_press_update('a',.1)
  check(B.ar_active and validations==1,'idle Ctrl+A still activates ordinary reroll')
  B.ar_active=false;B.ar_hotkey_down=false;e.G.GAME.challenge='challenge';controller:key_press_update('a',.1)
  check(starts==1,'idle challenge Ctrl+A retains challenge callback')
  order={};B.AutoRun.executing=true
  e.G.FUNCS={play_cards_from_highlighted=function()order[#order+1]='advisor-callback'end}
  e.G.FUNCS.play_cards_from_highlighted()
  check(table.concat(order,',')=='advisor-callback','direct product action callbacks do not impersonate physical keyboard/mouse')
end
do
  local order={};local B={config={keybinds={a_reroll='a'}},ar_active=false,ar_hotkey_down=true,
    Checkpoints={update=function()order[#order+1]='checkpoint'end},
    CollectionSearchProduct={update=function()order[#order+1]='collection'end},
    Advisor={hotkey_down=true,player_log={install_hooks=function()order[#order+1]='hooks'end,update=function()order[#order+1]='log'end},
      update=function()order[#order+1]='advisor'end},AutoRun={update=function()order[#order+1]='auto'end}}
  local e={Brainstorm=B,Game={update=function()order[#order+1]='original'end},G={},love={keyboard={isDown=function()return false end}}}
  execute(slice('local update_ref = Game.update','function Brainstorm.autoReroll()'),e)
  local instance=setmetatable({},{__index=e.Game});instance:update(.01)
  check(table.concat(order,',')=='original,checkpoint,collection,hooks,log,advisor,auto','update drains search before later controller work without physical input hooks')
  check(not B.ar_hotkey_down and not B.Advisor.hotkey_down,'released hotkey latches still clear')
end
print('advisor_collection_core: '..checks..' checks passed')
