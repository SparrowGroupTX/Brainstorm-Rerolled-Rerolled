-- Compile generated preload snippets only; never execute source or product modules.
local checks=0
assert(not loadstring([==[package.preload[[=[probe_auto_run_product]=]]=assert(loadstring([=[-- Explicit-user-start facade. Only this product callback path may start runs
-- or execute advice. No active session is saved or restored across launches.
local M={}
-- Original boot_timer retains G.LOADING={font=Font} after startup.
-- It is display cache, not active loading. Unknown shapes and true still block.
local function loading_pending(value)
  if value==nil or value==false then return false end
  if type(value)~='table' or getmetatable(value)~=nil then return true end
  local font=rawget(value,'font')
  if type(font)~='userdata' and type(font)~='table' then return true end
  for key in next,value do if key~='font' then return true end end
  return false
end
local function settled_main_menu(g)
  return g and g.STAGES and g.STATES and g.STAGES.MAIN_MENU~=nil and g.STATES.MENU~=nil
    and g.STAGE==g.STAGES.MAIN_MENU and g.STATE==g.STATES.MENU
end
local function copy(t,seen,budget,depth)
  seen=seen or {};budget=budget or {left=20000};depth=depth or 0
  budget.left=budget.left-1;assert(budget.left>=0 and depth<=16,'Auto-run data exceeds its copy bound.')
  if type(t)~='table'then
    assert(t==nil or type(t)=='boolean' or type(t)=='string' and #t<=262144 or
      type(t)=='number' and t==t and math.abs(t)<math.huge,'Auto-run data must contain plain finite values.')
    return t
  end
  assert(not getmetatable(t)and not seen[t],'Auto-run data must be plain and acyclic.')
  seen[t]=true;local out={};for k,v in pairs(t)do out[k]=copy(v,seen,budget,depth+1)end;seen[t]=nil;return out
end
local function packed(...)return {n=select('#',...),...}end
function M.attach(B,deps)
  deps=deps or {};local A=assert(deps.advisor or B.Advisor)
  local get=deps.game or function()return G end
  local clock=deps.now or function()return love.timer.getTime()end
  local controller_module=assert(deps.controller,'Missing auto-run controller')
  local terminal_module=assert(deps.terminal,'Missing original terminal monitor')
  local terminal=terminal_module.attach({game=get,globals=deps.globals,card=deps.card,game_class=deps.game_class})
  local api={internal_depth=0,status_text='Auto-run is off.'};local controller,pending,owned_search,advice_token
  local profile_binding
  local serial,advice_serial=0,0;local run_ids=setmetatable({},{__mode='k'})
  local generations={consent_generation=0,settings_generation=0,checkpoint_generation=0,manual_generation=0}
  local function run_id(g)
    if not g or type(g.GAME)~='table'then return nil end
    if not run_ids[g.GAME]then serial=serial+1;run_ids[g.GAME]='game:'..serial end
    return run_ids[g.GAME]
  end
  local function native()return deps.search or B.CollectionSearchProduct end
  local function owned(fn,...)
    api.internal_depth=api.internal_depth+1
    local out=packed(pcall(fn,...));api.internal_depth=api.internal_depth-1
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  local function logging()
    local log=A.player_log
    return log and type(log.enabled)=='function' and log:enabled() and not log.error and type(log.event)=='function'
  end
  local function log(event)
    if not logging()then return false end
    local okay,accepted=pcall(A.player_log.event,A.player_log,'auto_run',event)
    return okay and accepted==true
  end
  local function busy(g,ignore_overlay)
    if not g or not g.GAME then return true,'Game unavailable.' end
    if not g.STATE_COMPLETE and not settled_main_menu(g)then return true,'Game transition incomplete.' end
    if g.STAGES and g.STAGES.MAIN_MENU~=nil and g.STAGE==g.STAGES.MAIN_MENU and not settled_main_menu(g)then
      return true,'Wait for the main menu.' end
    if g.screenwipe then return true,'Screen transition active.' end
    if (g.GAME.STOP_USE or 0)>0 then return true,'Card action pending.' end
    if not ignore_overlay and g.OVERLAY_MENU then return true,'Menu is still open.' end
    if not ignore_overlay and (g.SETTINGS or {}).paused then return true,'Game is paused.' end
    local c=g.CONTROLLER or {}
    if c.locked then return true,'Controls are settling.' end
    if c.text_input_hook then return true,'Finish text entry.' end
    if c.dragging and c.dragging.target then return true,'Release the dragged card.' end
    for _,v in pairs(c.locks or {})do if v then return true,'Input lock is active.' end end
    if g.play and g.play.cards and #g.play.cards>0 then return true,'Played cards are settling.' end
    if B.Checkpoints and (B.Checkpoints.pending or B.Checkpoints.saving) or B.save_pending or B.checkpoint_busy or g.SAVING then return true,'Save/checkpoint pending.' end
    if loading_pending(g.LOADING)then return true,'Game loading is active.' end
    return false
  end
  local function search_busy()
    return B.native_search_busy==true or B.ar_active==true or
      B.CollectionSearchRuntime and B.CollectionSearchRuntime.busy() or false
  end
  local function observe()
    local g=get();local id=run_id(g);local result=A.result
    if profile_binding and (g.PROFILES or {})[(g.SETTINGS or {}).profile]~=profile_binding then
      error('The loaded profile table changed.',0)
    end
    local ended=terminal:poll(id);local overlay=terminal:owned_overlay(id)
    local snapshot=A.snapshot.capture(g)
    local fingerprint=snapshot and A.snapshot.fingerprint(snapshot)
    local action=result and result.action
    local action_key=action and A.snapshot.fingerprint(action)
    if result and action and (not advice_token or advice_token.result~=result or advice_token.key~=A.published_key or
      advice_token.generation~=A.published_generation or advice_token.action_key~=action_key)then
      advice_serial=advice_serial+1
      advice_token={id='advice:'..advice_serial,result=result,key=A.published_key,generation=A.published_generation,
        game=g.GAME,action_key=action_key}
    end
    local n=native();local transition=n and n.can_begin and n.can_begin()==true or false
    local goal=A.gold_stickers.capture(g,{enabled=true})
    local obs={profile_id=(g.SETTINGS or {}).profile,run_id=id,fingerprint=fingerprint,
      advice_fingerprint=A.published_key,action_token=action and advice_token and advice_token.id,
      action=copy(action),advice={title=A.display and A.display.title,lines=copy(A.lines)},
      ready=not busy(g,overlay~=nil) and (ended~=nil or not A.worker and not A.execution_key),
      modal=not not g.OVERLAY_MENU and not overlay,paused=(g.SETTINGS or {}).paused==true and not overlay,
      advisor_busy=not ended and A.worker~=nil,action_pending=not ended and A.execution_key~=nil,search_busy=search_busy(),
      unsupported=result and not action or not result and not A.worker,
      transition_ready=transition and (not ended or ended.result_surface_seen==true),goal=goal,terminal=ended}
    for k,v in pairs(generations)do obs[k]=v end
    return obs
  end
  local function matches(fingerprint,token)
    local g=get();local ref=advice_token
    if not logging()then return false,'Observation recording is unavailable.'end
    if not ref or ref.id~=token or ref.key~=fingerprint or ref.result~=A.result or ref.game~=g.GAME or
      ref.generation~=A.published_generation or ref.generation~=A.retry_generation or A.published_key~=fingerprint or
      ref.action_key~=A.snapshot.fingerprint(A.result and A.result.action)then return false,'The published action changed.'end
    local snapshot=A.snapshot.capture(g)
    if not snapshot or A.snapshot.fingerprint(snapshot)~=fingerprint then return false,'The public state changed.'end
    if not A.can_execute()then return false,'The existing Execute gate is not ready.'end
    return true
  end
  controller=controller_module.new({now=clock,observe=observe,log=log,
    search_start=function(request)
      local n=native();if not n or not n.prepare or not n.begin then return false,'Collection search is unavailable.'end
      local available,reason=n.can_begin()
      if available~=true then return false,reason end
      local prepared,why=n.prepare(request.recipe)
      if not prepared then return false,why end
      owned_search={id=request.request_id,prepared=prepared,owner=request.request_id,found=nil}
      local id,reason=owned(n.begin,prepared,request.request_id)
      -- A nil return can follow partial native dispatch. Leave ownership in
      -- place so the controller cancels and drains instead of claiming exit.
      if not id then return nil,reason end
      owned_search.native_id=id;return true
    end,
    search_poll=function(id)
      local job=owned_search;local n=native()
      if not job or job.id~=id or not n or not n.poll then return nil end
      local poll=n.poll(job.owner)
      if not poll then
        local runtime=B.CollectionSearchRuntime
        if job.cancel_requested and runtime and type(runtime.busy)=='function' and
          runtime.busy()==false and B.native_search_busy~=true then
          return {request_id=id,exited=true,status='cancelled',reason='Cancellation found no remaining native worker.'}
        end
        return nil
      end
      if job.native_id and poll.request_id~=job.native_id then return {request_id='foreign',exited=false}end
      if poll.found then job.found=poll.found;job.found_key=A.snapshot.fingerprint(poll.found)end
      return {request_id=id,exited=poll.exited==true,status=poll.status=='searching' and 'running' or poll.status,
        found=copy(poll.found),reason=poll.reason}
    end,
    search_cancel=function(id)
      local job=owned_search;local n=native()
      if not job or job.id~=id then return true end
      job.cancel_requested=true
      return n and n.cancel and owned(n.cancel,job.owner,'Auto-run stopped') or false
    end,
    start_run=function(found,binding)
      local job=owned_search;local n=native();local g=get()
      if not logging()or not job or not job.found or not n or not n.launch or
        binding.profile_id~=(g.SETTINGS or {}).profile or A.snapshot.fingerprint(found)~=job.found_key then return false,'The owned result or profile changed.'end
      local okay,why=owned(n.launch,job.found,job.owner)
      if okay~=true then return false,why end
      local started_id=run_id(get())
      if not terminal:arm(started_id)then return false,'The new run cannot bind terminal progress.'end
      return true
    end,
    can_execute=matches,
    execute=function(fingerprint,token)
      local okay,why=matches(fingerprint,token);if not okay then return false,why end
      local journal=A.player_log;local source=journal.source;journal.source='auto_run'
      local result=packed(pcall(owned,A.execute,fingerprint,advice_token.generation))
      journal.source=source
      if not result[1]then error(result[2],0)end
      local accepted=result[2]
      if not logging()then return false,'Recording stopped during the action; no further action will be attempted.'end
      return accepted==true
    end})
  function api:owned()return self.internal_depth>0 or terminal:in_win_callback() end
  function api:status()
    local state=controller.status()
    if pending then state.state='arming';state.busy=true;state.reason=pending.reason or 'Menu is closing.'end
    local search=native()
    local search_text=state.state=='searching' and owned_search and search and type(search.status)=='string' and search.status
    state.log_status=A.player_log and A.player_log.status
    self.status_text=state.complete and 'All 150 vanilla Jokers have verified loaded Gold stickers.' or
      pending and ('Waiting: '..tostring(pending.reason or 'Menu is closing.')) or
      search_text or
      state.busy and ('Auto-run: '..tostring(state.state)..'; '..tostring(state.runs_started or 0)..' runs, '..tostring(state.actions or 0)..' actions.') or
      state.reason and ('Auto-run stopped: '..tostring(state.detail or state.reason)) or 'Auto-run is off.'
    if state.search_draining then self.status_text=self.status_text..' Waiting for the owned search worker to exit.'end
    return state
  end
  function api:stop(reason)
    pending=nil;profile_binding=nil;terminal:disarm()
    local stopped=controller.stop(reason or 'User stopped auto-run');self:status();return stopped
  end
  function api:manual(reason,kind)
    if self:owned()then return false end
    generations.manual_generation=generations.manual_generation+1
    if kind=='checkpoint'then generations.checkpoint_generation=generations.checkpoint_generation+1 end
    if kind=='settings'then generations.settings_generation=generations.settings_generation+1 end
    if pending or controller.status().busy then self:stop(reason or 'Manual action interrupted auto-run')end
    return true
  end
  function api:start(options)
    if pending or controller.status().busy then return false,'Auto-run or its search worker is already active.'end
    local g=get();if not g or not g.GAME or search_busy()then return false,'Wait for the current activity to finish.'end
    local n=native()
    for _,name in ipairs({'can_begin','prepare','begin','poll','cancel','launch'})do
      if not n or type(n[name])~='function'then return false,'Collection search is unavailable.'end
    end
    if not B.CollectionSearchRuntime or type(B.CollectionSearchRuntime.busy)~='function'then return false,'Native worker ownership is unavailable.'end
    if not A.player_log or A.player_log.error then return false,'Observation recording is unavailable.'end
    if options~=nil and (type(options)~='table' or getmetatable(options))then return false,'Auto-run options must be plain data.'end
    local copied,configured=pcall(copy,options or {})
    if not copied then return false,tostring(configured)end
    if configured.search_request~=nil and (type(configured.search_request)~='table' or getmetatable(configured.search_request))then
      return false,'Search options must be plain data.'
    end
    configured.search_request=configured.search_request or {}
    for _,key in ipairs({'deck_name','interchangeable_copies','minimum_distinct','quota_mode','first_ante','last_ante','budget_ms','burnt_fallback'})do
      if options and options[key]~=nil then
        if configured.search_request[key]~=nil and configured.search_request[key]~=options[key]then return false,'Conflicting search option: '..key end
        configured.search_request[key]=copy(options[key])
      end
    end
    -- Automatic collection must include progress once the fixed opening is
    -- already complete. Explicit numeric positive or strict zero requests
    -- retain their meaning; absent/legacy zero defaults to the new Auto mode.
    if configured.search_request.quota_mode==nil then
      local count=configured.search_request.minimum_distinct
      configured.search_request.quota_mode=type(count)=='number' and count>0 and 'strict' or 'auto'
    end
    if configured.search_request.burnt_fallback==nil then configured.search_request.burnt_fallback=true end
    local timed,now=pcall(clock)
    if not timed or type(now)~='number' or now~=now or math.abs(now)==math.huge then return false,'A monotonic clock is unavailable.'end
    profile_binding=(g.PROFILES or {})[(g.SETTINGS or {}).profile]
    if type(profile_binding)~='table'then return false,'The loaded profile is unavailable.'end
    B.config.advisor.enabled=true;B.config.advisor.challenge_only=false
    B.config.advisor.gold_stickers=true;B.config.advisor.player_logging=true
    generations.consent_generation=generations.consent_generation+1
    if not log({event='explicit_start_requested',version=B.VERSION,options=copy(configured),
      profile_id=(g.SETTINGS or {}).profile,run_id=run_id(g),scope='User enabled advisor, Gold objective, recording and bounded automatic play/search.'})then
      return false,'Recording could not start; auto-run remains stopped.'
    end
    if A.settings_changed then owned(A.settings_changed)end
    if g.OVERLAY_MENU then
      local close=deps.exit_overlay or g.FUNCS and g.FUNCS.exit_overlay_menu
      if type(close)~='function'then return false,'The menu cannot close safely.'end
      local okay,why=pcall(owned,close)
      if not okay then return false,tostring(why)end
    end
    A.menu_open,A.menu_overlay=false,nil
    pending={options=configured,profile=(g.SETTINGS or {}).profile,profile_table=profile_binding,at=now,game=g.GAME}
    self:status()
    return true
  end
  function api:update()
    local g=get()
    if pending then
      if not logging()or (g.SETTINGS or {}).profile~=pending.profile or
        (g.PROFILES or {})[pending.profile]~=pending.profile_table or g.GAME~=pending.game then return self:stop('Start context changed')end
      if clock()-pending.at>=30 then return self:stop('The menu did not settle before startup')end
      local blocked,reason=busy(g,false);pending.reason=reason
      if not blocked then
        local options=pending.options;pending=nil
        local okay,why=controller.start(options)
        if not okay then controller.stop(why or 'Automatic startup was rejected')end
      end
      return self:status()
    end
    local state=controller.status()
    if state.active and not logging()then self:stop('Observation recording stopped');return self:status()end
    -- The original result overlay is dismissed only after its verified
    -- terminal event has been logged in an earlier controller update.
    if state.active and state.state=='terminal' then
      local overlay=terminal:owned_overlay(run_id(g))
      if overlay then
        if not log({event='terminal_overlay_close_requested',run_id=run_id(g)})then self:stop('Observation recording stopped');return self:status()end
        local close=deps.exit_overlay or g.FUNCS and g.FUNCS.exit_overlay_menu
        if type(close)~='function'then self:stop('The result screen cannot close safely');return self:status()end
        local okay,why=pcall(owned,close)
        if not okay then self:stop('The result screen could not close: '..tostring(why))end
        return self:status()
      end
    end
    terminal:install_hooks()
    controller.tick();return self:status()
  end
  B.AutoRun=api;return api
end
return M
]=],[=[@policy/Core/auto_run_product.lua]=]))]==]));checks=checks+1
assert(loadstring([==[package.preload[ [=[probe_auto_run_product]=] ]=assert(loadstring([=[-- Explicit-user-start facade. Only this product callback path may start runs
-- or execute advice. No active session is saved or restored across launches.
local M={}
-- Original boot_timer retains G.LOADING={font=Font} after startup.
-- It is display cache, not active loading. Unknown shapes and true still block.
local function loading_pending(value)
  if value==nil or value==false then return false end
  if type(value)~='table' or getmetatable(value)~=nil then return true end
  local font=rawget(value,'font')
  if type(font)~='userdata' and type(font)~='table' then return true end
  for key in next,value do if key~='font' then return true end end
  return false
end
local function settled_main_menu(g)
  return g and g.STAGES and g.STATES and g.STAGES.MAIN_MENU~=nil and g.STATES.MENU~=nil
    and g.STAGE==g.STAGES.MAIN_MENU and g.STATE==g.STATES.MENU
end
local function copy(t,seen,budget,depth)
  seen=seen or {};budget=budget or {left=20000};depth=depth or 0
  budget.left=budget.left-1;assert(budget.left>=0 and depth<=16,'Auto-run data exceeds its copy bound.')
  if type(t)~='table'then
    assert(t==nil or type(t)=='boolean' or type(t)=='string' and #t<=262144 or
      type(t)=='number' and t==t and math.abs(t)<math.huge,'Auto-run data must contain plain finite values.')
    return t
  end
  assert(not getmetatable(t)and not seen[t],'Auto-run data must be plain and acyclic.')
  seen[t]=true;local out={};for k,v in pairs(t)do out[k]=copy(v,seen,budget,depth+1)end;seen[t]=nil;return out
end
local function packed(...)return {n=select('#',...),...}end
function M.attach(B,deps)
  deps=deps or {};local A=assert(deps.advisor or B.Advisor)
  local get=deps.game or function()return G end
  local clock=deps.now or function()return love.timer.getTime()end
  local controller_module=assert(deps.controller,'Missing auto-run controller')
  local terminal_module=assert(deps.terminal,'Missing original terminal monitor')
  local terminal=terminal_module.attach({game=get,globals=deps.globals,card=deps.card,game_class=deps.game_class})
  local api={internal_depth=0,status_text='Auto-run is off.'};local controller,pending,owned_search,advice_token
  local profile_binding
  local serial,advice_serial=0,0;local run_ids=setmetatable({},{__mode='k'})
  local generations={consent_generation=0,settings_generation=0,checkpoint_generation=0,manual_generation=0}
  local function run_id(g)
    if not g or type(g.GAME)~='table'then return nil end
    if not run_ids[g.GAME]then serial=serial+1;run_ids[g.GAME]='game:'..serial end
    return run_ids[g.GAME]
  end
  local function native()return deps.search or B.CollectionSearchProduct end
  local function owned(fn,...)
    api.internal_depth=api.internal_depth+1
    local out=packed(pcall(fn,...));api.internal_depth=api.internal_depth-1
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  local function logging()
    local log=A.player_log
    return log and type(log.enabled)=='function' and log:enabled() and not log.error and type(log.event)=='function'
  end
  local function log(event)
    if not logging()then return false end
    local okay,accepted=pcall(A.player_log.event,A.player_log,'auto_run',event)
    return okay and accepted==true
  end
  local function busy(g,ignore_overlay)
    if not g or not g.GAME then return true,'Game unavailable.' end
    if not g.STATE_COMPLETE and not settled_main_menu(g)then return true,'Game transition incomplete.' end
    if g.STAGES and g.STAGES.MAIN_MENU~=nil and g.STAGE==g.STAGES.MAIN_MENU and not settled_main_menu(g)then
      return true,'Wait for the main menu.' end
    if g.screenwipe then return true,'Screen transition active.' end
    if (g.GAME.STOP_USE or 0)>0 then return true,'Card action pending.' end
    if not ignore_overlay and g.OVERLAY_MENU then return true,'Menu is still open.' end
    if not ignore_overlay and (g.SETTINGS or {}).paused then return true,'Game is paused.' end
    local c=g.CONTROLLER or {}
    if c.locked then return true,'Controls are settling.' end
    if c.text_input_hook then return true,'Finish text entry.' end
    if c.dragging and c.dragging.target then return true,'Release the dragged card.' end
    for _,v in pairs(c.locks or {})do if v then return true,'Input lock is active.' end end
    if g.play and g.play.cards and #g.play.cards>0 then return true,'Played cards are settling.' end
    if B.Checkpoints and (B.Checkpoints.pending or B.Checkpoints.saving) or B.save_pending or B.checkpoint_busy or g.SAVING then return true,'Save/checkpoint pending.' end
    if loading_pending(g.LOADING)then return true,'Game loading is active.' end
    return false
  end
  local function search_busy()
    return B.native_search_busy==true or B.ar_active==true or
      B.CollectionSearchRuntime and B.CollectionSearchRuntime.busy() or false
  end
  local function observe()
    local g=get();local id=run_id(g);local result=A.result
    if profile_binding and (g.PROFILES or {})[(g.SETTINGS or {}).profile]~=profile_binding then
      error('The loaded profile table changed.',0)
    end
    local ended=terminal:poll(id);local overlay=terminal:owned_overlay(id)
    local snapshot=A.snapshot.capture(g)
    local fingerprint=snapshot and A.snapshot.fingerprint(snapshot)
    local action=result and result.action
    local action_key=action and A.snapshot.fingerprint(action)
    if result and action and (not advice_token or advice_token.result~=result or advice_token.key~=A.published_key or
      advice_token.generation~=A.published_generation or advice_token.action_key~=action_key)then
      advice_serial=advice_serial+1
      advice_token={id='advice:'..advice_serial,result=result,key=A.published_key,generation=A.published_generation,
        game=g.GAME,action_key=action_key}
    end
    local n=native();local transition=n and n.can_begin and n.can_begin()==true or false
    local goal=A.gold_stickers.capture(g,{enabled=true})
    local obs={profile_id=(g.SETTINGS or {}).profile,run_id=id,fingerprint=fingerprint,
      advice_fingerprint=A.published_key,action_token=action and advice_token and advice_token.id,
      action=copy(action),advice={title=A.display and A.display.title,lines=copy(A.lines)},
      ready=not busy(g,overlay~=nil) and (ended~=nil or not A.worker and not A.execution_key),
      modal=not not g.OVERLAY_MENU and not overlay,paused=(g.SETTINGS or {}).paused==true and not overlay,
      advisor_busy=not ended and A.worker~=nil,action_pending=not ended and A.execution_key~=nil,search_busy=search_busy(),
      unsupported=result and not action or not result and not A.worker,
      transition_ready=transition and (not ended or ended.result_surface_seen==true),goal=goal,terminal=ended}
    for k,v in pairs(generations)do obs[k]=v end
    return obs
  end
  local function matches(fingerprint,token)
    local g=get();local ref=advice_token
    if not logging()then return false,'Observation recording is unavailable.'end
    if not ref or ref.id~=token or ref.key~=fingerprint or ref.result~=A.result or ref.game~=g.GAME or
      ref.generation~=A.published_generation or ref.generation~=A.retry_generation or A.published_key~=fingerprint or
      ref.action_key~=A.snapshot.fingerprint(A.result and A.result.action)then return false,'The published action changed.'end
    local snapshot=A.snapshot.capture(g)
    if not snapshot or A.snapshot.fingerprint(snapshot)~=fingerprint then return false,'The public state changed.'end
    if not A.can_execute()then return false,'The existing Execute gate is not ready.'end
    return true
  end
  controller=controller_module.new({now=clock,observe=observe,log=log,
    search_start=function(request)
      local n=native();if not n or not n.prepare or not n.begin then return false,'Collection search is unavailable.'end
      local available,reason=n.can_begin()
      if available~=true then return false,reason end
      local prepared,why=n.prepare(request.recipe)
      if not prepared then return false,why end
      owned_search={id=request.request_id,prepared=prepared,owner=request.request_id,found=nil}
      local id,reason=owned(n.begin,prepared,request.request_id)
      -- A nil return can follow partial native dispatch. Leave ownership in
      -- place so the controller cancels and drains instead of claiming exit.
      if not id then return nil,reason end
      owned_search.native_id=id;return true
    end,
    search_poll=function(id)
      local job=owned_search;local n=native()
      if not job or job.id~=id or not n or not n.poll then return nil end
      local poll=n.poll(job.owner)
      if not poll then
        local runtime=B.CollectionSearchRuntime
        if job.cancel_requested and runtime and type(runtime.busy)=='function' and
          runtime.busy()==false and B.native_search_busy~=true then
          return {request_id=id,exited=true,status='cancelled',reason='Cancellation found no remaining native worker.'}
        end
        return nil
      end
      if job.native_id and poll.request_id~=job.native_id then return {request_id='foreign',exited=false}end
      if poll.found then job.found=poll.found;job.found_key=A.snapshot.fingerprint(poll.found)end
      return {request_id=id,exited=poll.exited==true,status=poll.status=='searching' and 'running' or poll.status,
        found=copy(poll.found),reason=poll.reason}
    end,
    search_cancel=function(id)
      local job=owned_search;local n=native()
      if not job or job.id~=id then return true end
      job.cancel_requested=true
      return n and n.cancel and owned(n.cancel,job.owner,'Auto-run stopped') or false
    end,
    start_run=function(found,binding)
      local job=owned_search;local n=native();local g=get()
      if not logging()or not job or not job.found or not n or not n.launch or
        binding.profile_id~=(g.SETTINGS or {}).profile or A.snapshot.fingerprint(found)~=job.found_key then return false,'The owned result or profile changed.'end
      local okay,why=owned(n.launch,job.found,job.owner)
      if okay~=true then return false,why end
      local started_id=run_id(get())
      if not terminal:arm(started_id)then return false,'The new run cannot bind terminal progress.'end
      return true
    end,
    can_execute=matches,
    execute=function(fingerprint,token)
      local okay,why=matches(fingerprint,token);if not okay then return false,why end
      local journal=A.player_log;local source=journal.source;journal.source='auto_run'
      local result=packed(pcall(owned,A.execute,fingerprint,advice_token.generation))
      journal.source=source
      if not result[1]then error(result[2],0)end
      local accepted=result[2]
      if not logging()then return false,'Recording stopped during the action; no further action will be attempted.'end
      return accepted==true
    end})
  function api:owned()return self.internal_depth>0 or terminal:in_win_callback() end
  function api:status()
    local state=controller.status()
    if pending then state.state='arming';state.busy=true;state.reason=pending.reason or 'Menu is closing.'end
    local search=native()
    local search_text=state.state=='searching' and owned_search and search and type(search.status)=='string' and search.status
    state.log_status=A.player_log and A.player_log.status
    self.status_text=state.complete and 'All 150 vanilla Jokers have verified loaded Gold stickers.' or
      pending and ('Waiting: '..tostring(pending.reason or 'Menu is closing.')) or
      search_text or
      state.busy and ('Auto-run: '..tostring(state.state)..'; '..tostring(state.runs_started or 0)..' runs, '..tostring(state.actions or 0)..' actions.') or
      state.reason and ('Auto-run stopped: '..tostring(state.detail or state.reason)) or 'Auto-run is off.'
    if state.search_draining then self.status_text=self.status_text..' Waiting for the owned search worker to exit.'end
    return state
  end
  function api:stop(reason)
    pending=nil;profile_binding=nil;terminal:disarm()
    local stopped=controller.stop(reason or 'User stopped auto-run');self:status();return stopped
  end
  function api:manual(reason,kind)
    if self:owned()then return false end
    generations.manual_generation=generations.manual_generation+1
    if kind=='checkpoint'then generations.checkpoint_generation=generations.checkpoint_generation+1 end
    if kind=='settings'then generations.settings_generation=generations.settings_generation+1 end
    if pending or controller.status().busy then self:stop(reason or 'Manual action interrupted auto-run')end
    return true
  end
  function api:start(options)
    if pending or controller.status().busy then return false,'Auto-run or its search worker is already active.'end
    local g=get();if not g or not g.GAME or search_busy()then return false,'Wait for the current activity to finish.'end
    local n=native()
    for _,name in ipairs({'can_begin','prepare','begin','poll','cancel','launch'})do
      if not n or type(n[name])~='function'then return false,'Collection search is unavailable.'end
    end
    if not B.CollectionSearchRuntime or type(B.CollectionSearchRuntime.busy)~='function'then return false,'Native worker ownership is unavailable.'end
    if not A.player_log or A.player_log.error then return false,'Observation recording is unavailable.'end
    if options~=nil and (type(options)~='table' or getmetatable(options))then return false,'Auto-run options must be plain data.'end
    local copied,configured=pcall(copy,options or {})
    if not copied then return false,tostring(configured)end
    if configured.search_request~=nil and (type(configured.search_request)~='table' or getmetatable(configured.search_request))then
      return false,'Search options must be plain data.'
    end
    configured.search_request=configured.search_request or {}
    for _,key in ipairs({'deck_name','interchangeable_copies','minimum_distinct','quota_mode','first_ante','last_ante','budget_ms','burnt_fallback'})do
      if options and options[key]~=nil then
        if configured.search_request[key]~=nil and configured.search_request[key]~=options[key]then return false,'Conflicting search option: '..key end
        configured.search_request[key]=copy(options[key])
      end
    end
    -- Automatic collection must include progress once the fixed opening is
    -- already complete. Explicit numeric positive or strict zero requests
    -- retain their meaning; absent/legacy zero defaults to the new Auto mode.
    if configured.search_request.quota_mode==nil then
      local count=configured.search_request.minimum_distinct
      configured.search_request.quota_mode=type(count)=='number' and count>0 and 'strict' or 'auto'
    end
    if configured.search_request.burnt_fallback==nil then configured.search_request.burnt_fallback=true end
    local timed,now=pcall(clock)
    if not timed or type(now)~='number' or now~=now or math.abs(now)==math.huge then return false,'A monotonic clock is unavailable.'end
    profile_binding=(g.PROFILES or {})[(g.SETTINGS or {}).profile]
    if type(profile_binding)~='table'then return false,'The loaded profile is unavailable.'end
    B.config.advisor.enabled=true;B.config.advisor.challenge_only=false
    B.config.advisor.gold_stickers=true;B.config.advisor.player_logging=true
    generations.consent_generation=generations.consent_generation+1
    if not log({event='explicit_start_requested',version=B.VERSION,options=copy(configured),
      profile_id=(g.SETTINGS or {}).profile,run_id=run_id(g),scope='User enabled advisor, Gold objective, recording and bounded automatic play/search.'})then
      return false,'Recording could not start; auto-run remains stopped.'
    end
    if A.settings_changed then owned(A.settings_changed)end
    if g.OVERLAY_MENU then
      local close=deps.exit_overlay or g.FUNCS and g.FUNCS.exit_overlay_menu
      if type(close)~='function'then return false,'The menu cannot close safely.'end
      local okay,why=pcall(owned,close)
      if not okay then return false,tostring(why)end
    end
    A.menu_open,A.menu_overlay=false,nil
    pending={options=configured,profile=(g.SETTINGS or {}).profile,profile_table=profile_binding,at=now,game=g.GAME}
    self:status()
    return true
  end
  function api:update()
    local g=get()
    if pending then
      if not logging()or (g.SETTINGS or {}).profile~=pending.profile or
        (g.PROFILES or {})[pending.profile]~=pending.profile_table or g.GAME~=pending.game then return self:stop('Start context changed')end
      if clock()-pending.at>=30 then return self:stop('The menu did not settle before startup')end
      local blocked,reason=busy(g,false);pending.reason=reason
      if not blocked then
        local options=pending.options;pending=nil
        local okay,why=controller.start(options)
        if not okay then controller.stop(why or 'Automatic startup was rejected')end
      end
      return self:status()
    end
    local state=controller.status()
    if state.active and not logging()then self:stop('Observation recording stopped');return self:status()end
    -- The original result overlay is dismissed only after its verified
    -- terminal event has been logged in an earlier controller update.
    if state.active and state.state=='terminal' then
      local overlay=terminal:owned_overlay(run_id(g))
      if overlay then
        if not log({event='terminal_overlay_close_requested',run_id=run_id(g)})then self:stop('Observation recording stopped');return self:status()end
        local close=deps.exit_overlay or g.FUNCS and g.FUNCS.exit_overlay_menu
        if type(close)~='function'then self:stop('The result screen cannot close safely');return self:status()end
        local okay,why=pcall(owned,close)
        if not okay then self:stop('The result screen could not close: '..tostring(why))end
        return self:status()
      end
    end
    terminal:install_hooks()
    controller.tick();return self:status()
  end
  B.AutoRun=api;return api
end
return M
]=],[=[@policy/Core/auto_run_product.lua]=]))]==]));checks=checks+1
assert(not loadstring([==[package.preload[[=[probe_auto_terminal]=]]=assert(loadstring([=[-- Loaded-state receipts around original callbacks. Never writes profile/save
-- data and never accepts GAME.won alone as completion. Arm only a newly
-- controller-started actual GAME table; checkpoint/profile changes disarm it.
local M={}
local function number(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function packed(...)return {n=select('#',...),...}end
function M.attach(deps)
  deps=deps or {};local get=assert(deps.game);local globals=deps.globals or _G
  local card=deps.card or globals.Card;local game_class=deps.game_class or globals.Game
  local api={};local bound;local hooks={}
  local function current()
    local g=get();return bound and g and g.GAME==bound.game and (g.SETTINGS or {}).profile==bound.profile and
      (g.PROFILES or {})[bound.profile]==bound.profile_table and g or nil
  end
  local function info(g)
    local game=g.GAME;local profile=(g.PROFILES or {})[(g.SETTINGS or {}).profile]
    if type(profile)~='table' then return nil end
    local stake=game.stake;local center=game.selected_back and game.selected_back.effect and game.selected_back.effect.center
    if not number(stake) or not center or type(center.key)~='string' then return nil end
    local function wins(kind,key)
      local value=((((profile[kind] or {})[key] or {}).wins or {})[stake])
      if value==nil then return 0 end
      return number(value) and value>=0 and value%1==0 and value or nil
    end
    local held={}
    for _,c in ipairs(g.jokers and g.jokers.cards or {})do
      local ccenter=c.config and c.config.center
      local key=c.config and c.config.center_key or ccenter and ccenter.key
      if not key or held[key]~=nil then
        -- Repeated physical copies can increment the same counter more than
        -- once. Track its initial number once; verify a positive increment.
        if not key then return nil end
      else held[key]=wins('joker_usage',key);if held[key]==nil then return nil end end
    end
    return {deck=center.key,stake=stake,deck_wins=wins('deck_usage',center.key),jokers=held,
      ante=(game.round_resets or {}).ante,round=game.round,win_ante=game.win_ante,
      chips=game.chips,target=(game.blind or {}).chips,boss=not not (game.blind or {}).boss,
      seeded=not not game.seeded,challenge=game.challenge,won=not not game.won,state=g.STATE}
  end
  function api:arm(run_id)
    local g=get()
    if not g or type(g.GAME)~='table' or type(run_id)~='string' or run_id=='' then return false end
    local profile=(g.SETTINGS or {}).profile
    if type((g.PROFILES or {})[profile])~='table' then return false end
    bound={game=g.GAME,profile=profile,profile_table=g.PROFILES[profile],run_id=run_id,callbacks={}}
    return true
  end
  function api:disarm()bound=nil end
  local function wrap(name,before,after)
    local original=globals[name]
    if type(original)~='function' or original==hooks[name] then return end
    local function wrapped(...)
      local g=current();local stamp=bound;local context=g and info(g);local previous_overlay=g and g.OVERLAY_MENU
      if context and before then before(context,g)end
      local source_win=context and name=='win_game' and bound.final~=nil
      if source_win then stamp.win_depth=(stamp.win_depth or 0)+1 end
      local result=packed(pcall(original,...))
      if source_win then stamp.win_depth=stamp.win_depth-1 end
      if result[1] and context and current()==g and bound==stamp and after then after(context,info(g),g,previous_overlay,result)end
      if not result[1]then error(result[2],0)end
      return unpack(result,2,result.n)
    end
    hooks[name]=wrapped;globals[name]=wrapped
  end
  function api:install_hooks()
    wrap('end_round',function(context)
      if context.boss and context.ante==context.win_ante then bound.final=copy(context)end
    end)
    for _,name in ipairs({'set_joker_win','set_deck_win'})do
      local callback=name
      wrap(callback,nil,function(before,after)
        local final=bound.final
        if not final or not after or before.round~=final.round or after.round~=final.round or
          not before.won or not after.won or before.seeded or before.challenge or
          before.deck~=final.deck or before.stake~=final.stake or after.deck~=before.deck or after.stake~=before.stake then return end
        local expected=#bound.callbacks==0 and 'set_joker_win' or #bound.callbacks==1 and 'set_deck_win'
        if callback~=expected then bound.invalid=true;return end
        local valid=before.deck_wins~=nil and after.deck_wins~=nil
        if callback=='set_deck_win'then valid=valid and after.deck_wins>before.deck_wins
        else
          for key,n in pairs(before.jokers)do valid=valid and after.jokers[key]~=nil and after.jokers[key]>n end
          for key in pairs(after.jokers)do if before.jokers[key]==nil then valid=false end end
        end
        if #bound.callbacks>=8 then bound.invalid=true;return end
        bound.callbacks[#bound.callbacks+1]={name=callback,before=copy(before),after=copy(after),verified=not not valid}
        if valid then bound[callback]=true end
      end)
    end
    wrap('win_game',nil,function(_,_,g,previous_overlay)
      bound.win_called=true
      -- This exact overlay was created by the original win callback; an
      -- unrelated later menu must never inherit permission to be dismissed.
      if g.OVERLAY_MENU~=previous_overlay then bound.overlay=g.OVERLAY_MENU end
    end)
    wrap('create_UIBox_win',nil,function(_,_,g,_,result)
      -- The original win_game schedules this UI creation in a later event.
      -- Bind its actual definition object to the already observed original
      -- accounting, then consume that exact object at overlay creation.
      local ended=api:poll(bound.run_id)
      if bound.win_called and ended and ended.kind=='win' and not bound.overlay and
        not bound.win_definition and type(result[2])=='table' then bound.win_definition=result[2] end
    end)
    local g=get();local funcs=g and g.FUNCS
    if funcs and type(funcs.overlay_menu)=='function' and funcs.overlay_menu~=hooks.overlay_menu then
      local original=funcs.overlay_menu
      local function overlay_menu(args,...)
        local active=current();local stamp=bound
        local ended=active and api:poll(stamp.run_id)
        local owned=ended and ended.kind=='win' and stamp.win_definition and type(args)=='table' and
          args.definition==stamp.win_definition and not stamp.overlay
        if owned then stamp.win_definition=nil;stamp.win_depth=(stamp.win_depth or 0)+1 end
        local result=packed(pcall(original,args,...))
        if owned then stamp.win_depth=stamp.win_depth-1 end
        if result[1] and owned and current()==active and bound==stamp then stamp.overlay=active.OVERLAY_MENU end
        if not result[1]then error(result[2],0)end
        return unpack(result,2,result.n)
      end
      hooks.overlay_menu=overlay_menu;funcs.overlay_menu=overlay_menu
    end
    if game_class and type(game_class.update_game_over)=='function' and game_class.update_game_over~=hooks.game_over then
      local original=game_class.update_game_over
      local function update_game_over(self,...)
        local g=current();local stamp=bound;local previous_overlay=g and g.OVERLAY_MENU
        local owned=g and self==g and g.STATES and g.STATE==g.STATES.GAME_OVER
        if owned then stamp.result_depth=(stamp.result_depth or 0)+1 end
        local result=packed(pcall(original,self,...))
        if owned then stamp.result_depth=stamp.result_depth-1 end
        if result[1] and owned and current()==g and bound==stamp and g.OVERLAY_MENU~=previous_overlay then bound.loss_overlay=g.OVERLAY_MENU end
        if not result[1]then error(result[2],0)end
        return unpack(result,2,result.n)
      end
      hooks.game_over=update_game_over;game_class.update_game_over=update_game_over
    end
    if card and type(card.calculate_joker)=='function' and card.calculate_joker~=hooks.calculate_joker then
      local original=card.calculate_joker
      local function calculate(self,context,...)
        local g=current();local stamp=bound
        local result=packed(original(self,context,...))
        if g and current()==g and bound==stamp and context and context.end_of_round and
          type(result[1])=='table' and result[1].saved==true then bound.saved=info(g)end
        return unpack(result,1,result.n)
      end
      hooks.calculate_joker=calculate;card.calculate_joker=calculate
    end
  end
  function api:poll(run_id)
    local g=current();if not g or bound.run_id~=run_id then return nil end
    if g.STATES and g.STATE==g.STATES.GAME_OVER then
      return {kind='loss',verified=true,run_id=run_id,event_id='loss:'..run_id,source='GAME_OVER',
        source_won_field=not not g.GAME.won,result_surface_seen=bound.loss_overlay~=nil}
    end
    local final=bound.final;local now=info(g)
    if bound.invalid or not final or not now or not now.won or final.seeded or final.challenge or
      final.stake~=8 or now.stake~=final.stake or now.deck~=final.deck or not final.boss or
      final.ante~=final.win_ante or not bound.set_joker_win or not bound.set_deck_win then return nil end
    local threshold=number(final.chips) and number(final.target) and final.target>0 and final.chips>=final.target
    local saved=bound.saved and bound.saved.ante==final.ante and bound.saved.round==final.round
    if not threshold and not saved then return nil end
    return {kind='win',verified=true,run_id=run_id,event_id='win:'..run_id,source='original_win_callback',
      final_context=copy(final),callbacks=copy(bound.callbacks),threshold_met=not not threshold,
      source_saved=not not saved,game_over=false,result_surface_seen=bound.overlay~=nil}
  end
  function api:owned_overlay(run_id)
    local terminal=self:poll(run_id);local g=current()
    if terminal and terminal.kind=='win' and bound.overlay and g.OVERLAY_MENU==bound.overlay then return bound.overlay end
    if terminal and terminal.kind=='loss' and bound.loss_overlay and g.OVERLAY_MENU==bound.loss_overlay then return bound.loss_overlay end
  end
  function api:in_win_callback()
    return current()~=nil and ((bound.win_depth or 0)>0 or (bound.result_depth or 0)>0)
  end
  api:install_hooks();return api
end
return M
]=],[=[@policy/Core/auto_terminal.lua]=]))]==]));checks=checks+1
assert(loadstring([==[package.preload[ [=[probe_auto_terminal]=] ]=assert(loadstring([=[-- Loaded-state receipts around original callbacks. Never writes profile/save
-- data and never accepts GAME.won alone as completion. Arm only a newly
-- controller-started actual GAME table; checkpoint/profile changes disarm it.
local M={}
local function number(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function packed(...)return {n=select('#',...),...}end
function M.attach(deps)
  deps=deps or {};local get=assert(deps.game);local globals=deps.globals or _G
  local card=deps.card or globals.Card;local game_class=deps.game_class or globals.Game
  local api={};local bound;local hooks={}
  local function current()
    local g=get();return bound and g and g.GAME==bound.game and (g.SETTINGS or {}).profile==bound.profile and
      (g.PROFILES or {})[bound.profile]==bound.profile_table and g or nil
  end
  local function info(g)
    local game=g.GAME;local profile=(g.PROFILES or {})[(g.SETTINGS or {}).profile]
    if type(profile)~='table' then return nil end
    local stake=game.stake;local center=game.selected_back and game.selected_back.effect and game.selected_back.effect.center
    if not number(stake) or not center or type(center.key)~='string' then return nil end
    local function wins(kind,key)
      local value=((((profile[kind] or {})[key] or {}).wins or {})[stake])
      if value==nil then return 0 end
      return number(value) and value>=0 and value%1==0 and value or nil
    end
    local held={}
    for _,c in ipairs(g.jokers and g.jokers.cards or {})do
      local ccenter=c.config and c.config.center
      local key=c.config and c.config.center_key or ccenter and ccenter.key
      if not key or held[key]~=nil then
        -- Repeated physical copies can increment the same counter more than
        -- once. Track its initial number once; verify a positive increment.
        if not key then return nil end
      else held[key]=wins('joker_usage',key);if held[key]==nil then return nil end end
    end
    return {deck=center.key,stake=stake,deck_wins=wins('deck_usage',center.key),jokers=held,
      ante=(game.round_resets or {}).ante,round=game.round,win_ante=game.win_ante,
      chips=game.chips,target=(game.blind or {}).chips,boss=not not (game.blind or {}).boss,
      seeded=not not game.seeded,challenge=game.challenge,won=not not game.won,state=g.STATE}
  end
  function api:arm(run_id)
    local g=get()
    if not g or type(g.GAME)~='table' or type(run_id)~='string' or run_id=='' then return false end
    local profile=(g.SETTINGS or {}).profile
    if type((g.PROFILES or {})[profile])~='table' then return false end
    bound={game=g.GAME,profile=profile,profile_table=g.PROFILES[profile],run_id=run_id,callbacks={}}
    return true
  end
  function api:disarm()bound=nil end
  local function wrap(name,before,after)
    local original=globals[name]
    if type(original)~='function' or original==hooks[name] then return end
    local function wrapped(...)
      local g=current();local stamp=bound;local context=g and info(g);local previous_overlay=g and g.OVERLAY_MENU
      if context and before then before(context,g)end
      local source_win=context and name=='win_game' and bound.final~=nil
      if source_win then stamp.win_depth=(stamp.win_depth or 0)+1 end
      local result=packed(pcall(original,...))
      if source_win then stamp.win_depth=stamp.win_depth-1 end
      if result[1] and context and current()==g and bound==stamp and after then after(context,info(g),g,previous_overlay,result)end
      if not result[1]then error(result[2],0)end
      return unpack(result,2,result.n)
    end
    hooks[name]=wrapped;globals[name]=wrapped
  end
  function api:install_hooks()
    wrap('end_round',function(context)
      if context.boss and context.ante==context.win_ante then bound.final=copy(context)end
    end)
    for _,name in ipairs({'set_joker_win','set_deck_win'})do
      local callback=name
      wrap(callback,nil,function(before,after)
        local final=bound.final
        if not final or not after or before.round~=final.round or after.round~=final.round or
          not before.won or not after.won or before.seeded or before.challenge or
          before.deck~=final.deck or before.stake~=final.stake or after.deck~=before.deck or after.stake~=before.stake then return end
        local expected=#bound.callbacks==0 and 'set_joker_win' or #bound.callbacks==1 and 'set_deck_win'
        if callback~=expected then bound.invalid=true;return end
        local valid=before.deck_wins~=nil and after.deck_wins~=nil
        if callback=='set_deck_win'then valid=valid and after.deck_wins>before.deck_wins
        else
          for key,n in pairs(before.jokers)do valid=valid and after.jokers[key]~=nil and after.jokers[key]>n end
          for key in pairs(after.jokers)do if before.jokers[key]==nil then valid=false end end
        end
        if #bound.callbacks>=8 then bound.invalid=true;return end
        bound.callbacks[#bound.callbacks+1]={name=callback,before=copy(before),after=copy(after),verified=not not valid}
        if valid then bound[callback]=true end
      end)
    end
    wrap('win_game',nil,function(_,_,g,previous_overlay)
      bound.win_called=true
      -- This exact overlay was created by the original win callback; an
      -- unrelated later menu must never inherit permission to be dismissed.
      if g.OVERLAY_MENU~=previous_overlay then bound.overlay=g.OVERLAY_MENU end
    end)
    wrap('create_UIBox_win',nil,function(_,_,g,_,result)
      -- The original win_game schedules this UI creation in a later event.
      -- Bind its actual definition object to the already observed original
      -- accounting, then consume that exact object at overlay creation.
      local ended=api:poll(bound.run_id)
      if bound.win_called and ended and ended.kind=='win' and not bound.overlay and
        not bound.win_definition and type(result[2])=='table' then bound.win_definition=result[2] end
    end)
    local g=get();local funcs=g and g.FUNCS
    if funcs and type(funcs.overlay_menu)=='function' and funcs.overlay_menu~=hooks.overlay_menu then
      local original=funcs.overlay_menu
      local function overlay_menu(args,...)
        local active=current();local stamp=bound
        local ended=active and api:poll(stamp.run_id)
        local owned=ended and ended.kind=='win' and stamp.win_definition and type(args)=='table' and
          args.definition==stamp.win_definition and not stamp.overlay
        if owned then stamp.win_definition=nil;stamp.win_depth=(stamp.win_depth or 0)+1 end
        local result=packed(pcall(original,args,...))
        if owned then stamp.win_depth=stamp.win_depth-1 end
        if result[1] and owned and current()==active and bound==stamp then stamp.overlay=active.OVERLAY_MENU end
        if not result[1]then error(result[2],0)end
        return unpack(result,2,result.n)
      end
      hooks.overlay_menu=overlay_menu;funcs.overlay_menu=overlay_menu
    end
    if game_class and type(game_class.update_game_over)=='function' and game_class.update_game_over~=hooks.game_over then
      local original=game_class.update_game_over
      local function update_game_over(self,...)
        local g=current();local stamp=bound;local previous_overlay=g and g.OVERLAY_MENU
        local owned=g and self==g and g.STATES and g.STATE==g.STATES.GAME_OVER
        if owned then stamp.result_depth=(stamp.result_depth or 0)+1 end
        local result=packed(pcall(original,self,...))
        if owned then stamp.result_depth=stamp.result_depth-1 end
        if result[1] and owned and current()==g and bound==stamp and g.OVERLAY_MENU~=previous_overlay then bound.loss_overlay=g.OVERLAY_MENU end
        if not result[1]then error(result[2],0)end
        return unpack(result,2,result.n)
      end
      hooks.game_over=update_game_over;game_class.update_game_over=update_game_over
    end
    if card and type(card.calculate_joker)=='function' and card.calculate_joker~=hooks.calculate_joker then
      local original=card.calculate_joker
      local function calculate(self,context,...)
        local g=current();local stamp=bound
        local result=packed(original(self,context,...))
        if g and current()==g and bound==stamp and context and context.end_of_round and
          type(result[1])=='table' and result[1].saved==true then bound.saved=info(g)end
        return unpack(result,1,result.n)
      end
      hooks.calculate_joker=calculate;card.calculate_joker=calculate
    end
  end
  function api:poll(run_id)
    local g=current();if not g or bound.run_id~=run_id then return nil end
    if g.STATES and g.STATE==g.STATES.GAME_OVER then
      return {kind='loss',verified=true,run_id=run_id,event_id='loss:'..run_id,source='GAME_OVER',
        source_won_field=not not g.GAME.won,result_surface_seen=bound.loss_overlay~=nil}
    end
    local final=bound.final;local now=info(g)
    if bound.invalid or not final or not now or not now.won or final.seeded or final.challenge or
      final.stake~=8 or now.stake~=final.stake or now.deck~=final.deck or not final.boss or
      final.ante~=final.win_ante or not bound.set_joker_win or not bound.set_deck_win then return nil end
    local threshold=number(final.chips) and number(final.target) and final.target>0 and final.chips>=final.target
    local saved=bound.saved and bound.saved.ante==final.ante and bound.saved.round==final.round
    if not threshold and not saved then return nil end
    return {kind='win',verified=true,run_id=run_id,event_id='win:'..run_id,source='original_win_callback',
      final_context=copy(final),callbacks=copy(bound.callbacks),threshold_met=not not threshold,
      source_saved=not not saved,game_over=false,result_surface_seen=bound.overlay~=nil}
  end
  function api:owned_overlay(run_id)
    local terminal=self:poll(run_id);local g=current()
    if terminal and terminal.kind=='win' and bound.overlay and g.OVERLAY_MENU==bound.overlay then return bound.overlay end
    if terminal and terminal.kind=='loss' and bound.loss_overlay and g.OVERLAY_MENU==bound.loss_overlay then return bound.loss_overlay end
  end
  function api:in_win_callback()
    return current()~=nil and ((bound.win_depth or 0)>0 or (bound.result_depth or 0)>0)
  end
  api:install_hooks();return api
end
return M
]=],[=[@policy/Core/auto_terminal.lua]=]))]==]));checks=checks+1
assert(not loadstring([==[package.preload[[=[probe_collection_run_ui]=]]=assert(loadstring([=[-- Explicit controls for a bounded searched normal Gold run. Drawing the page
-- does not start a worker, replace a run or change recorded sticker progress.
local B=Brainstorm
local quiet={text='Search is idle. Starting replaces the current run.'}
local function status_text()
  if quiet.failure then return quiet.failure end
  if quiet.owner=='manual' and B.CollectionSearchProduct then return B.CollectionSearchProduct.status or quiet.text end
  if quiet.owner=='auto' and B.AutoRun then return B.AutoRun.status_text or quiet.text end
  return B.AutoRun and B.AutoRun.status_text or quiet.text
end
G.FUNCS.brainstorm_collection_status=function()
  local text=tostring(status_text()):gsub('[\r\n\t]',' ')
  if #text>140 then text=text:sub(1,137)..'...' end
  quiet.line1=text:sub(1,70);quiet.line2=text:sub(71,140)
end
local function options()
  local advisor=B.config.advisor
  if type(advisor.gold_run)~='table' then advisor.gold_run={} end
  local q=advisor.gold_run
  local defaults={deck_name='Red Deck',interchangeable_copies=true,minimum_distinct=0,
    first_ante=1,last_ante=8,budget_ms=30000,max_runs=25,burnt_fallback=true}
  for key,value in pairs(defaults) do if q[key]==nil then q[key]=value end end
  -- 302 stored only a count. Preserve positive requests. Its unset/zero
  -- default becomes Auto on this explicit-start page; strict Off is durable.
  if q.quota_mode==nil then q.quota_mode=type(q.minimum_distinct)=='number' and q.minimum_distinct>0 and 'strict' or 'auto' end
  return q
end
local function row(text,colour,scale)
  return {n=G.UIT.R,config={align='cm',padding=.015,maxw=7.7},nodes={
    {n=G.UIT.T,config={text=text,colour=colour or G.C.WHITE,scale=scale or .25}}}}
end
local function button(label,callback,width)
  return UIBox_button({label={label},button=callback,col=true,minw=width or 3.4,minh=.38,scale=.25})
end
local function refresh()
  if B.showCollectionRunPage then B.showCollectionRunPage() end
end
local function changed()
  quiet.failure=nil
  if B.AutoRun then B.AutoRun:stop('Search options changed.') end
  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Search options changed.') end
  B.writeConfig();refresh()
end
G.FUNCS.brainstorm_collection_deck=function()
  local q=options();q.deck_name=q.deck_name=='Red Deck' and 'Zodiac Deck' or 'Red Deck';changed()
end
G.FUNCS.brainstorm_collection_copy=function()
  local q=options();q.interchangeable_copies=not q.interchangeable_copies;changed()
end
G.FUNCS.brainstorm_collection_burnt=function()
  local q=options();q.burnt_fallback=not q.burnt_fallback;changed()
end
G.FUNCS.brainstorm_collection_count=function()
  local q=options()
  if q.quota_mode=='auto' then q.quota_mode='strict';q.minimum_distinct=0
  elseif (tonumber(q.minimum_distinct) or 0)>=5 then q.quota_mode='auto';q.minimum_distinct=0
  else q.quota_mode='strict';q.minimum_distinct=(tonumber(q.minimum_distinct) or 0)+1 end
  changed()
end
G.FUNCS.brainstorm_collection_after=function()
  local q=options();q.first_ante=(tonumber(q.first_ante) or 1)%8+1
  q.last_ante=math.max(q.first_ante,tonumber(q.last_ante) or 8);changed()
end
G.FUNCS.brainstorm_collection_through=function()
  local q=options();q.last_ante=(tonumber(q.last_ante) or 8)+1
  if q.last_ante>8 then q.last_ante=q.first_ante end;changed()
end
G.FUNCS.brainstorm_collection_runs=function()
  local q=options();local choices={5,10,25,50,100};local next_value=5
  for i,n in ipairs(choices) do if n==q.max_runs then next_value=choices[i%#choices+1] end end
  q.max_runs=next_value;changed()
end
G.FUNCS.brainstorm_collection_search_start=function()
  quiet.owner='manual';quiet.failure=nil
  if not B.CollectionSearchProduct then quiet.failure='Bounded search is unavailable.';refresh();return end
  local ok,reason=B.CollectionSearchProduct.start_manual(options())
  quiet.text=ok and 'Searching; Stop or a manual input cancels.' or tostring(reason or 'Search could not start.')
  if not ok then quiet.failure=quiet.text;refresh()end
end
G.FUNCS.brainstorm_collection_auto_start=function()
  quiet.owner='auto';quiet.failure=nil
  if not B.AutoRun then quiet.failure='Auto-run is unavailable.';refresh();return end
  local ok,reason=B.AutoRun:start(options())
  quiet.text=ok and 'Auto-run started. Any manual input stops it.' or tostring(reason or 'Auto-run could not start.')
  if not ok then quiet.failure=quiet.text;refresh()end
end
G.FUNCS.brainstorm_collection_stop=function()
  quiet.failure=nil
  if B.AutoRun then B.AutoRun:stop('Stopped by the user.') end
  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Stopped by the user.') end
  quiet.text='Stopped. An active native worker is allowed to finish cancellation.';refresh()
end
function B.createCollectionRunPage()
  local q=options()
  local title=B.AutoRun and 'Completionist++ auto-run' or 'Quick Gold run'
  local nodes={row(title,G.C.GREEN,.38),
    row(q.burnt_fallback and 'Yorick + Perkeo: Charm. Copy by Ante 5; Burnt preferred.' or
      'Yorick + Perkeo: starting Charm. Burnt + copy: by Ante 5.',nil,.25),
    {n=G.UIT.R,config={align='cm',padding=.03},nodes={
      button(q.deck_name..' / Gold','brainstorm_collection_deck'),
      button(q.interchangeable_copies and 'Blueprint or Brainstorm' or 'Brainstorm only','brainstorm_collection_copy')}},
    {n=G.UIT.R,config={align='cm',padding=.03},nodes={
      button('Missing: '..(q.quota_mode=='auto' and 'Auto' or q.minimum_distinct==0 and 'Off' or tostring(q.minimum_distinct)),'brainstorm_collection_count',2.2),
      button('After Ante '..tostring(q.first_ante-1),'brainstorm_collection_after',2.2),
      button('Through Ante '..tostring(q.last_ante),'brainstorm_collection_through',2.2)}},
    row('No perishable targets. Maximum native CPU. Search limit: 30 seconds.',nil,.24),
    row('Missing counts are distinct conditional offers, not purchases or wins.',nil,.24),
    row('Auto requires one reachable missing Joker; Off adds no missing-target condition.',nil,.22),
    row('Starting a searched run replaces the current run.',G.C.ORANGE,.26)}
  local controls={button('Search and start new run','brainstorm_collection_search_start',3.3)}
  if B.AutoRun then
    controls[#controls+1]=button('Start auto-run + logging','brainstorm_collection_auto_start',3.3)
    nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={
      button('Session limit: '..q.max_runs..' runs','brainstorm_collection_runs',3.4),
      button(q.burnt_fallback and 'Burnt: flexible' or 'Burnt: required','brainstorm_collection_burnt',3.4)}}
  end
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.03},nodes=controls}
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={button('Stop','brainstorm_collection_stop',3.4)}}
  G.FUNCS.brainstorm_collection_status()
  for _,key in ipairs({'line1','line2'})do
    nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.015,maxw=7.7},nodes={
      {n=G.UIT.T,config={ref_table=quiet,ref_value=key,func='brainstorm_collection_status',colour=G.C.WHITE,scale=.23}}}}
  end
  nodes[#nodes+1]=row('The game awards stickers. Unknown progress prevents an automatic start.',nil,.23)
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=.04},nodes=nodes}
end
return {options=options}
]=],[=[@policy/UI/collection_run.lua]=]))]==]));checks=checks+1
assert(loadstring([==[package.preload[ [=[probe_collection_run_ui]=] ]=assert(loadstring([=[-- Explicit controls for a bounded searched normal Gold run. Drawing the page
-- does not start a worker, replace a run or change recorded sticker progress.
local B=Brainstorm
local quiet={text='Search is idle. Starting replaces the current run.'}
local function status_text()
  if quiet.failure then return quiet.failure end
  if quiet.owner=='manual' and B.CollectionSearchProduct then return B.CollectionSearchProduct.status or quiet.text end
  if quiet.owner=='auto' and B.AutoRun then return B.AutoRun.status_text or quiet.text end
  return B.AutoRun and B.AutoRun.status_text or quiet.text
end
G.FUNCS.brainstorm_collection_status=function()
  local text=tostring(status_text()):gsub('[\r\n\t]',' ')
  if #text>140 then text=text:sub(1,137)..'...' end
  quiet.line1=text:sub(1,70);quiet.line2=text:sub(71,140)
end
local function options()
  local advisor=B.config.advisor
  if type(advisor.gold_run)~='table' then advisor.gold_run={} end
  local q=advisor.gold_run
  local defaults={deck_name='Red Deck',interchangeable_copies=true,minimum_distinct=0,
    first_ante=1,last_ante=8,budget_ms=30000,max_runs=25,burnt_fallback=true}
  for key,value in pairs(defaults) do if q[key]==nil then q[key]=value end end
  -- 302 stored only a count. Preserve positive requests. Its unset/zero
  -- default becomes Auto on this explicit-start page; strict Off is durable.
  if q.quota_mode==nil then q.quota_mode=type(q.minimum_distinct)=='number' and q.minimum_distinct>0 and 'strict' or 'auto' end
  return q
end
local function row(text,colour,scale)
  return {n=G.UIT.R,config={align='cm',padding=.015,maxw=7.7},nodes={
    {n=G.UIT.T,config={text=text,colour=colour or G.C.WHITE,scale=scale or .25}}}}
end
local function button(label,callback,width)
  return UIBox_button({label={label},button=callback,col=true,minw=width or 3.4,minh=.38,scale=.25})
end
local function refresh()
  if B.showCollectionRunPage then B.showCollectionRunPage() end
end
local function changed()
  quiet.failure=nil
  if B.AutoRun then B.AutoRun:stop('Search options changed.') end
  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Search options changed.') end
  B.writeConfig();refresh()
end
G.FUNCS.brainstorm_collection_deck=function()
  local q=options();q.deck_name=q.deck_name=='Red Deck' and 'Zodiac Deck' or 'Red Deck';changed()
end
G.FUNCS.brainstorm_collection_copy=function()
  local q=options();q.interchangeable_copies=not q.interchangeable_copies;changed()
end
G.FUNCS.brainstorm_collection_burnt=function()
  local q=options();q.burnt_fallback=not q.burnt_fallback;changed()
end
G.FUNCS.brainstorm_collection_count=function()
  local q=options()
  if q.quota_mode=='auto' then q.quota_mode='strict';q.minimum_distinct=0
  elseif (tonumber(q.minimum_distinct) or 0)>=5 then q.quota_mode='auto';q.minimum_distinct=0
  else q.quota_mode='strict';q.minimum_distinct=(tonumber(q.minimum_distinct) or 0)+1 end
  changed()
end
G.FUNCS.brainstorm_collection_after=function()
  local q=options();q.first_ante=(tonumber(q.first_ante) or 1)%8+1
  q.last_ante=math.max(q.first_ante,tonumber(q.last_ante) or 8);changed()
end
G.FUNCS.brainstorm_collection_through=function()
  local q=options();q.last_ante=(tonumber(q.last_ante) or 8)+1
  if q.last_ante>8 then q.last_ante=q.first_ante end;changed()
end
G.FUNCS.brainstorm_collection_runs=function()
  local q=options();local choices={5,10,25,50,100};local next_value=5
  for i,n in ipairs(choices) do if n==q.max_runs then next_value=choices[i%#choices+1] end end
  q.max_runs=next_value;changed()
end
G.FUNCS.brainstorm_collection_search_start=function()
  quiet.owner='manual';quiet.failure=nil
  if not B.CollectionSearchProduct then quiet.failure='Bounded search is unavailable.';refresh();return end
  local ok,reason=B.CollectionSearchProduct.start_manual(options())
  quiet.text=ok and 'Searching; Stop or a manual input cancels.' or tostring(reason or 'Search could not start.')
  if not ok then quiet.failure=quiet.text;refresh()end
end
G.FUNCS.brainstorm_collection_auto_start=function()
  quiet.owner='auto';quiet.failure=nil
  if not B.AutoRun then quiet.failure='Auto-run is unavailable.';refresh();return end
  local ok,reason=B.AutoRun:start(options())
  quiet.text=ok and 'Auto-run started. Any manual input stops it.' or tostring(reason or 'Auto-run could not start.')
  if not ok then quiet.failure=quiet.text;refresh()end
end
G.FUNCS.brainstorm_collection_stop=function()
  quiet.failure=nil
  if B.AutoRun then B.AutoRun:stop('Stopped by the user.') end
  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Stopped by the user.') end
  quiet.text='Stopped. An active native worker is allowed to finish cancellation.';refresh()
end
function B.createCollectionRunPage()
  local q=options()
  local title=B.AutoRun and 'Completionist++ auto-run' or 'Quick Gold run'
  local nodes={row(title,G.C.GREEN,.38),
    row(q.burnt_fallback and 'Yorick + Perkeo: Charm. Copy by Ante 5; Burnt preferred.' or
      'Yorick + Perkeo: starting Charm. Burnt + copy: by Ante 5.',nil,.25),
    {n=G.UIT.R,config={align='cm',padding=.03},nodes={
      button(q.deck_name..' / Gold','brainstorm_collection_deck'),
      button(q.interchangeable_copies and 'Blueprint or Brainstorm' or 'Brainstorm only','brainstorm_collection_copy')}},
    {n=G.UIT.R,config={align='cm',padding=.03},nodes={
      button('Missing: '..(q.quota_mode=='auto' and 'Auto' or q.minimum_distinct==0 and 'Off' or tostring(q.minimum_distinct)),'brainstorm_collection_count',2.2),
      button('After Ante '..tostring(q.first_ante-1),'brainstorm_collection_after',2.2),
      button('Through Ante '..tostring(q.last_ante),'brainstorm_collection_through',2.2)}},
    row('No perishable targets. Maximum native CPU. Search limit: 30 seconds.',nil,.24),
    row('Missing counts are distinct conditional offers, not purchases or wins.',nil,.24),
    row('Auto requires one reachable missing Joker; Off adds no missing-target condition.',nil,.22),
    row('Starting a searched run replaces the current run.',G.C.ORANGE,.26)}
  local controls={button('Search and start new run','brainstorm_collection_search_start',3.3)}
  if B.AutoRun then
    controls[#controls+1]=button('Start auto-run + logging','brainstorm_collection_auto_start',3.3)
    nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={
      button('Session limit: '..q.max_runs..' runs','brainstorm_collection_runs',3.4),
      button(q.burnt_fallback and 'Burnt: flexible' or 'Burnt: required','brainstorm_collection_burnt',3.4)}}
  end
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.03},nodes=controls}
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={button('Stop','brainstorm_collection_stop',3.4)}}
  G.FUNCS.brainstorm_collection_status()
  for _,key in ipairs({'line1','line2'})do
    nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.015,maxw=7.7},nodes={
      {n=G.UIT.T,config={ref_table=quiet,ref_value=key,func='brainstorm_collection_status',colour=G.C.WHITE,scale=.23}}}}
  end
  nodes[#nodes+1]=row('The game awards stickers. Unknown progress prevents an automatic start.',nil,.23)
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=.04},nodes=nodes}
end
return {options=options}
]=],[=[@policy/UI/collection_run.lua]=]))]==]));checks=checks+1
assert(loadstring([==[package.preload[ [=[test_preload]=] ]=assert(loadstring([=[return ']]']=],[=[@policy/synthetic.lua]=]))]==]));checks=checks+1
assert(loadstring([===[package.preload[ [=[test_preload]=] ]=assert(loadstring([==[return ']=]']==],[=[@policy/synthetic.lua]=]))]===]));checks=checks+1
assert(loadstring([==[package.preload[ [=[test_preload]=] ]=assert(loadstring([=[return ']===]']=],[=[@policy/synthetic.lua]=]))]==]));checks=checks+1
assert(loadstring([==[package.preload[ [=[test_preload]=] ]=assert(loadstring([=[return {eq='=',name='[[x]]'}]=],[=[@policy/synthetic.lua]=]))]==]));checks=checks+1
print('M17 preload correction: '..checks..' parse-only checks passed')
