-- Explicit-user-start facade. Only this product callback path may start runs
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
-- Diagnostic names only: never stringify live values or userdata addresses.
local function diagnostic_fields(value,active_only)
  local names={}
  for key,item in next,value do
    if not active_only or item then
      names[#names+1]=type(key)=='string' and key:gsub('%c','?'):sub(1,24) or ('<'..type(key)..' key>')
    end
  end
  table.sort(names)
  if #names>4 then while #names>4 do table.remove(names)end;names[#names+1]='...' end
  return #names>0 and table.concat(names,', ') or 'none'
end
local function loading_reason(value)
  local shape=type(value)
  if shape=='table'then shape=shape..(getmetatable(value)~=nil and ' with metatable' or ' fields: '..diagnostic_fields(value))end
  return 'Game loading is active ('..shape..').'
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
    for _,v in pairs(c.locks or {})do if v then return true,'Input locks active: '..diagnostic_fields(c.locks,true)..'.' end end
    if g.play and g.play.cards and #g.play.cards>0 then return true,'Played cards are settling.' end
    if B.Checkpoints and B.Checkpoints.pending then return true,'Checkpoint request is pending.' end
    if B.Checkpoints and B.Checkpoints.saving then return true,'Checkpoint save is pending.' end
    if B.save_pending then return true,'Brainstorm save is pending.' end
    if B.checkpoint_busy then return true,'Checkpoint operation is busy.' end
    if g.SAVING then return true,'Game saving is active.' end
    if loading_pending(g.LOADING)then return true,loading_reason(g.LOADING) end
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
  -- Controller.status returns a copy; this getter does not update status or work.
  function api:status_report()
    local state=controller.status()
    local requested=generations.consent_generation>0
    return {requested=requested,busy=pending~=nil or state.busy==true,text=self.status_text,
      phase=pending and 'waiting' or state.state or 'idle',owner=requested and 'auto' or nil}
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
    for _,key in ipairs({'deck_name','interchangeable_copies','minimum_distinct','quota_mode','first_ante','last_ante','budget_ms','burnt_fallback','legendary_fallback'})do
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
    if configured.search_request.legendary_fallback==nil then configured.search_request.legendary_fallback=true end
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
