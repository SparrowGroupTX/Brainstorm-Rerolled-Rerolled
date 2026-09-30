-- Actual hooks under manufactured callbacks/UI and in-memory checkpoint store.
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function equal(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function slice(s,first,last)local a=assert(s:find(first,1,true));local b=assert(s:find(last,a+1,true));return s:sub(a,b-1)end
local function execute(source,env)setmetatable(env,{__index=_G});local f=assert(loadstring(source));setfenv(f,env);return f()end
local core=read('Brainstorm/Core/Brainstorm.lua')
do
  local calls={notify=0,stop=0,legacy=0,original=0,rerolls=0};local engaged=true;local down={};local returned={}
  local B={config={keybinds={modifier='ctrl',a_reroll='a',f_reroll='r',s_state='z',l_state='x'}},
    AutoRun={engaged=function()return engaged end,manual=function()calls.notify=calls.notify+1 end},
    CollectionSearchProduct={stop=function()calls.stop=calls.stop+1 end},
    Checkpoints={hotkey=function(_,key)return key=='1'end},
    validateAutoRerollFilters=function()calls.legacy=calls.legacy+1;return true end,
    startChallengeOpeningSearch=function()calls.legacy=calls.legacy+1 end,
    stopChallengeOpeningSearch=function()calls.legacy=calls.legacy+1 end,
    reroll=function()calls.legacy=calls.legacy+1;calls.rerolls=calls.rerolls+1 end}
  local env={Brainstorm=B,G={GAME={}},love={keyboard={isDown=function(k)return down[k]end}},
    Controller={key_press_update=function(self,key,dt)calls.original=calls.original+1;calls.self=self;calls.key=key;calls.dt=dt end,
      queue_L_cursor_press=function(self,...)returned.self=self;returned.n=select('#',...);returned.args={...};return nil,'left',nil end,
      queue_R_cursor_press=function(self,...)returned.self=self;returned.n=select('#',...);return 'right' end}}
  execute(slice(core,'local key_press_update_ref =','function saveManagerAlert(text)'),env)
  execute(slice(core,"for _,method in ipairs({'queue_L_cursor_press'",'local update_ref = Game.update'),env)
  local c=setmetatable({},{__index=env.Controller})
  c:key_press_update('q',.02);equal(calls.stop,0,'ordinary key preserves engaged shared search')
  equal(calls.notify,1,'ordinary key still invalidates controller context');equal(calls.original,1,'ordinary key reaches original')
  equal(calls.self,c,'keyboard self preserved');equal(calls.key,'q','keyboard key preserved');equal(calls.dt,.02,'keyboard dt preserved')
  c:key_press_update('1',.03);equal(calls.notify,2,'checkpoint hotkey still notifies');equal(calls.original,1,'checkpoint consumes its key')
  local function packed(...)return{n=select('#',...),...}end
  local result=packed(c:queue_L_cursor_press('a',nil,7))
  equal(result.n,3,'mouse original nil return arity preserved');equal(result[2],'left','mouse original return preserved')
  equal(returned.n,3,'mouse nil argument arity preserved');equal(returned.args[3],7,'mouse last argument preserved')
  equal(c:queue_R_cursor_press(), 'right','right mouse handler preserved');equal(calls.stop,0,'both mouse hooks preserve engaged search')
  equal(calls.notify,4,'both mouse hooks still notify')
  down.ctrl=true
  for _,state in ipairs({'native','legacy','idle'})do
    B.ar_hotkey_down=false;B.native_search_busy=state=='native';B.ar_active=state=='legacy'
    local before=calls.legacy;c:key_press_update('a',.01)
    equal(calls.stop,0,state..' engaged Ctrl+A cannot cancel owned search')
    equal(calls.legacy,before,state..' engaged Ctrl+A cannot dispatch overlapping search')
    local original=calls.original;c:key_press_update('r',.01)
    equal(calls.rerolls,0,state..' engaged fast reroll cannot replace the owned run')
    equal(calls.legacy,before,state..' engaged fast reroll performs no legacy dispatch')
    equal(calls.original,original+1,state..' engaged fast reroll still reaches the original input handler')
  end
  engaged=false;down.ctrl=false;c:key_press_update('q',.01);equal(calls.stop,1,'standalone manual search still cancels on key')
  c:queue_L_cursor_press();equal(calls.stop,2,'standalone manual search still cancels on click')
  B.native_search_busy=true;B.ar_hotkey_down=false;down.ctrl=true;c:key_press_update('a',.01)
  equal(calls.stop,4,'standalone Ctrl+A retains generic input plus native cancellation')
  B.native_search_busy=false;B.ar_active=false;local original=calls.original
  c:key_press_update('r',.01)
  equal(calls.rerolls,1,'standalone modifier plus fast-reroll hotkey still rerolls once')
  equal(calls.original,original+1,'standalone fast reroll still reaches the original input handler')
  down.ctrl=false;c:key_press_update('r',.01)
  equal(calls.rerolls,1,'plain fast-reroll letter without modifier does not reroll')
end
do
  local s=read('Brainstorm/Advisor/runtime.lua');local notifications,stops,invalidated=0,0,0;local engaged=true
  local A={retry_generation=9,published_key='old',published_generation=9,published_game={},hud_action_key='old'}
  local B={AutoRun={engaged=function()return engaged end,owned=function()return false end,
    manual=function(_,reason,kind)equal(kind,'settings','settings notification kind');notifications=notifications+1 end},
    CollectionSearchProduct={stop=function()stops=stops+1 end}}
  execute(slice(s,'function A.settings_changed()','-- Seed/profile identity'),{A=A,Brainstorm=B,invalidate=function()invalidated=invalidated+1 end})
  A.settings_changed();equal(stops,0,'settings preserve auto-owned search');equal(A.retry_generation,10,'settings still advance retry generation')
  equal(A.published_generation,nil,'settings revoke old advice generation');equal(A.hud_action_key,nil,'settings revoke drawn Execute')
  equal(invalidated,1,'settings still invalidate worker/result');equal(notifications,1,'settings still notify controller')
  engaged=false;A.settings_changed();equal(stops,1,'unowned standalone search keeps settings cancellation')
end
do
  local source=read('tests/advisor_checkpoint_runtime.lua')
  local helpers=source:sub(1,assert(source:find('local r,g,B,f,alerts',1,true))-1)
  local fixture=assert(loadstring(helpers..'\nreturn fixture'))()
  local r,g,B,files,alerts,faults,counts,deps,events=fixture();local notifications,stops={},0;local engaged=true
  B.AutoRun={engaged=function()return engaged end,stop=function()error('checkpoint must never hard-stop auto')end,
    manual=function(_,reason,kind)
      if kind=='checkpoint_loaded' then local _,_,_,n=counts();equal(n,1,'verified adoption follows advisor invalidation')end
      notifications[#notifications+1]=kind
    end}
  B.CollectionSearchProduct={stop=function()stops=stops+1 end}
  check(r:save('1'),'engaged checkpoint save remains verified');equal(stops,0,'save keeps owned search')
  equal(notifications[#notifications],'checkpoint','save only sends request notification')
  check(r:load('1'),'engaged checkpoint load remains verified');equal(stops,0,'load keeps owned search')
  equal(notifications[#notifications],'checkpoint','raw load request is not adoption')
  local n=#notifications;r:update(.1)
  equal(#notifications,n+1,'verified load sends one completion notification');equal(notifications[#notifications],'checkpoint_loaded','only verified state emits adoption kind')
  local _,_,_,invalidated=counts();equal(invalidated,1,'verified load invalidates existing advice once');equal(B.retry_counter,5,'retry cap unchanged')
  n=#notifications;r:update(.1);equal(#notifications,n,'settled later tick does not repeat adoption')
  check(not r:load('5'),'invalid missing slot still rejected');equal(notifications[#notifications],'checkpoint','failed load does not claim restoration')
  faults.write=true;check(not r:save('2'),'write failure still rejected');faults.write=nil
  g.STATE_COMPLETE=false;check(not r:save('1')and not r:load('1'),'unsettled saves and loads still rejected');g.STATE_COMPLETE=true
  engaged=false;r:save('1');equal(stops,1,'standalone search remains cancelled for explicit checkpoint request')
end
local ui_source=read('tests/advisor_startup_ui.lua'):gsub('\r\n','\n')
local ui_helpers=ui_source:sub(1,assert(ui_source:find('\ndo\n',1,true))-1)
local environment=assert(loadstring(ui_helpers..'\nreturn environment'))()
local function ui()
  local e,A=environment();e.engaged=true;e.resumes=0;e.notifications=0
  Brainstorm.AutoRun.engaged=function()return e.engaged end
  Brainstorm.AutoRun.manual=function()e.notifications=e.notifications+1 end
  Brainstorm.AutoRun.resume=function(self,...)
    equal(select('#',...),0,'Resume sends no options or new-start request')
    e.resumes=e.resumes+1
    if e.resume_error then return false,e.resume_error end
    e.auto.resume_pending=true;e.auto.resume_available=false;return true
  end
  return e,A
end
do
  local e,A=ui();e.auto.requested=true;e.auto.busy=true;e.auto.phase='playing';e.auto.text='Playing'
  check(e.draw():find('STOP',1,true)and A.hud_auto_stop,'active HUD draws dedicated Stop')
  e.click();equal(e.auto_stops,1,'HUD calls explicit Stop');equal(e.notifications,0,'HUD Stop does not call ordinary-input method')
  equal(e.executes,0,'HUD Stop cannot execute advice');equal(e.stops,0,'HUD auto Stop never cancels shared search directly')
  e.auto.busy=false;e.auto.resume_available=true;e.auto.phase='stopped';e.auto.text='Stopped; Resume this session.'
  e.now=1000;local text=e.draw();check(text:find('RESUME',1,true)and A.hud_auto_resume,'resumable HUD persists beyond short notice timeout')
  check(text:find('AUTO-RUN',1,true),'stopped resumable header still identifies auto-run')
  e.click();equal(e.resumes,1,'HUD resumes once per user click');equal(e.starts,0,'HUD Resume never starts a searched run')
  equal(e.executes,0,'HUD Resume never executes old advice');equal(e.notifications,0,'HUD Resume does not count as stop')
  e.draw();check(A.hud_auto_stop and not A.hud_auto_resume,'resume pending displays Stop while waiting')
  e.auto.resume_pending=false;e.auto.resume_available=true;e.draw();e.resume_error='Original search budget expired.';e.click()
  equal(e.starts,0,'rejected Resume does not fall back to Start');equal(e.executes,0,'rejected Resume does not fall through')
end
do
  local e,A=ui();e.manual.requested=true;e.manual.busy=true;e.manual.phase='searching';e.manual.text='Standalone search'
  e.auto.requested=false;e.auto.busy=false;e.draw();check(A.hud_search_stop,'manual search drawn before ownership change')
  e.click();equal(e.stops,0,'stale manual Stop cannot cancel newly engaged auto-owned receipt')
end
do
  local e,A=ui();local B=Brainstorm
  local before=B.config.advisor.gold_run
  G.FUNCS.brainstorm_collection_resume();equal(e.resumes,1,'page Resume calls resume directly')
  equal(e.starts,0,'page Resume never invokes Start');equal(B.config.advisor.gold_run,before,'page Resume leaves configured options intact')
  e.resume_error='No resumable session';G.FUNCS.brainstorm_collection_resume()
  check(e.text(B.createCollectionRunPage()):find('No resumable session',1,true),'rejected page Resume explains failure')
  local start=e.starts;G.FUNCS.brainstorm_collection_search_start();equal(e.starts,start,'manual new search cannot replace engaged session')
  check(e.text(B.createCollectionRunPage()):find('already owns this run',1,true),'engaged new-search rejection is explicit')
  local settings={'deck','copy','burnt','count','after','through','runs'}
  for _,name in ipairs(settings)do G.FUNCS['brainstorm_collection_'..name]()end
  equal(e.writes,#settings,'setting edits still persist once each');equal(e.auto_stops,0,'setting edits never Stop active session')
  equal(e.stops,0,'setting edits preserve owned search');equal(e.notifications,0,'future recipe edit does not alter current session binding')
  local stop=B.AutoRun.stop
  B.AutoRun.stop=function(...)local result=stop(...);e.engaged=false;return result end
  G.FUNCS.brainstorm_collection_stop();equal(e.auto_stops,1,'page explicit Stop controls auto session')
  equal(e.stops,0,'page Stop does not cancel auto-owned found receipt separately')
  local page=B.createCollectionRunPage();local row_index,buttons={},{}
  for i,row in ipairs(page.nodes)do for _,button in ipairs(row.nodes or {})do
    local c=button.config or {};if c.button then row_index[c.button]=i;buttons[c.button]=c end
  end end
  equal(row_index.brainstorm_collection_resume,row_index.brainstorm_collection_stop,'Resume fits same row as Stop')
  equal(row_index.brainstorm_collection_resume,row_index.brainstorm_search_status_open,'Resume fits existing status row')
  check(buttons.brainstorm_collection_resume.minw+buttons.brainstorm_collection_stop.minw+buttons.brainstorm_search_status_open.minw<=6.7,'three controls retain bounded total width')
  e.engaged=false;G.FUNCS.brainstorm_collection_stop();equal(e.stops,1,'unowned standalone explicit Stop still cancels search')
end
print('advisor_input_ui: '..checks..' checks passed')
