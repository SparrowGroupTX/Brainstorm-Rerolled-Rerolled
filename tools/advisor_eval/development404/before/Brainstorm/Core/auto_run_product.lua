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
  local settlement=assert(deps.settlement,'Missing auto-run shop settlement module').new()
  local terminal=terminal_module.attach({game=get,globals=deps.globals,card=deps.card,game_class=deps.game_class})
  local api={internal_depth=0,status_text='Auto-run is off.'};local controller,pending,owned_search,advice_token
  function api:subscribe_terminal_source(listener)return terminal:subscribe_source(listener)end
  local suspended_pending,resuming,checkpoint_loaded,stopped_at,resume_error,checkpoint_at
  local profile_binding
  local teacher_profile,retired_run
  local semantic_cache_key,semantic_cache_value
  local abandon_serial=0
  local retire_unsupported=false
  local serial,advice_serial=0,0;local run_ids=setmetatable({},{__mode='k'})
  local auto_games=setmetatable({},{__mode='k'})
  function api:is_auto_game(g)return g and g.GAME and auto_games[g.GAME]==true or false end
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
  local function now()
    local ok,t=pcall(clock)
    if ok and type(t)=='number' and t==t and t>=0 and t<math.huge then return t end
  end
  local function user_busy(g)
    local c=g.CONTROLLER or {}
    return not not (g.OVERLAY_MENU or (g.SETTINGS or {}).paused or c.text_input_hook or
      c.dragging and c.dragging.target or B.Checkpoints and (B.Checkpoints.pending or B.Checkpoints.saving) or
      B.checkpoint_busy or B.save_pending or B.config.advisor.enabled==false)
  end
  local function public_fingerprint(value)
    local record={schema=1,kind='snapshot_fingerprint_sha256',status='unavailable'}
    if type(value)~='string' then record.reason='invalid_fingerprint_type';return record end
    record.byte_length=#value
    local hash=deps.fingerprint_hash
    if hash==nil then
      if not (love and love.data and type(love.data.hash)=='function') then
        record.reason='hash_unavailable';return record
      end
      hash=function(bytes)
        local raw=love.data.hash('sha256',bytes)
        assert(type(raw)=='string' and #raw==32,'Invalid SHA256 result.')
        return (raw:gsub('.',function(c)return string.format('%02x',string.byte(c))end))
      end
    end
    local okay,digest=pcall(hash,value)
    if not okay then record.reason='hash_failed';return record end
    if type(digest)~='string' or #digest~=64 or digest:find('[^0-9a-fA-F]') then
      record.reason='invalid_hash_result';return record
    end
    record.status,record.sha256='available',digest:lower()
    return record
  end
  local function project_log(event)
    -- Internal freshness keys serialize the full detached scoring state. The
    -- separate public observation redacts concealed identities, so these keys
    -- must not bypass that boundary. Keep exact keys inside the controller and
    -- export opaque identity/length only; a missing hash never exposes raw data.
    local exported={}
    for key,value in pairs(event)do
      if key=='fingerprint' or key=='before' or key=='after' then exported[key]=public_fingerprint(value)
      else exported[key]=value end
    end
    for _,field in ipairs({'interrupted_action','last_action','pending_action'})do
      if type(event[field])=='table' then
        local action={}
        for key,value in pairs(event[field])do
          action[key]=key=='fingerprint' and public_fingerprint(value) or value
        end
        exported[field]=action
      end
    end
    return exported
  end
  local function write_log(event)
    if not logging()then return false end
    local okay,accepted=pcall(A.player_log.event,A.player_log,'auto_run',event)
    return okay and accepted==true
  end
  local function log(event)return write_log(project_log(event))end
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
    local pending,why=settlement:check(g);if pending then return true,why end
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
    local ready=not busy(g,overlay~=nil) and (ended~=nil or not A.worker and not A.execution_key)
    local searching=search_busy()
    -- A blocked observation cannot dispatch or acknowledge an action. Keep
    -- terminal, profile, generation, goal and watchdog checks fresh, but build
    -- public action data only when those existing readiness gates permit it.
    -- Never reuse a snapshot or token from a prior frame; matches() still
    -- recaptures the live state separately at both exact execution gates.
    local action=result and result.action
    -- A ready unsupported endpoint can still acknowledge the prior action.
    -- Its fresh fingerprint must survive even when no next action is offered.
    local snapshot_needed=ready and not searching and not ended
    local action_ready=snapshot_needed and action~=nil
    local snapshot=snapshot_needed and A.snapshot.capture(g) or nil
    local fingerprint=snapshot and A.snapshot.fingerprint(snapshot)
    local action_key=action_ready and A.snapshot.fingerprint(action) or nil
    if action_ready and (not advice_token or advice_token.result~=result or advice_token.key~=A.published_key or
      advice_token.generation~=A.published_generation or advice_token.action_key~=action_key)then
      advice_serial=advice_serial+1
      advice_token={id='advice:'..advice_serial,result=result,key=A.published_key,generation=A.published_generation,
        game=g.GAME,action_key=action_key}
    end
    local n=native();local transition=n and n.can_begin and n.can_begin()==true or false
    local goal=A.gold_stickers.capture(g,{enabled=true})
    local semantic
    if (teacher_profile or retire_unsupported) and snapshot and A.player_journal and A.player_journal.semantic_fingerprint then
      if fingerprint~=semantic_cache_key then
        semantic_cache_value=A.player_journal.semantic_fingerprint(snapshot);semantic_cache_key=fingerprint
      end
      semantic=semantic_cache_value
    end
    local fresh=result and fingerprint~=nil and A.published_key==fingerprint
    local obs={profile_id=(g.SETTINGS or {}).profile,run_id=id,fingerprint=fingerprint,
      semantic_fingerprint=semantic,abandon_ready=ready and transition and not ended and not searching,
      decision_state=fresh and not action and (result.kind=='error' and 'error' or 'unsupported') or nil,
      decision_reason=fresh and not action and (A.display and A.display.status or result.kind) or nil,
      advice_fingerprint=A.published_key,action_token=action_ready and advice_token and advice_token.id,
      action=action_ready and copy(action) or nil,
      advice=action_ready and {title=A.display and A.display.title,lines=copy(A.lines)} or nil,
      ready=ready,
      modal=not not g.OVERLAY_MENU and not overlay,paused=(g.SETTINGS or {}).paused==true and not overlay,
      input_busy=not not ((g.CONTROLLER or {}).text_input_hook or
        (g.CONTROLLER or {}).dragging and g.CONTROLLER.dragging.target or
        B.Checkpoints and (B.Checkpoints.pending or B.Checkpoints.saving) or B.checkpoint_busy or B.save_pending or
        B.config.advisor.enabled==false),
      advisor_busy=not ended and A.worker~=nil,action_pending=not ended and A.execution_key~=nil,search_busy=searching,
      unsupported=result and not action or not result and not A.worker,
      transition_ready=transition and (not ended or ended.result_surface_seen==true),goal=goal,terminal=ended}
    for k,v in pairs(generations)do obs[k]=v end
    return obs
  end
  local function matches(fingerprint,token)
    local g=get();local ref=advice_token
    if not logging()then return false,'Observation recording is unavailable.'end
    local blocked,reason=busy(g,false);if blocked then return false,reason end
    if not ref or ref.id~=token or ref.key~=fingerprint or ref.result~=A.result or ref.game~=g.GAME or
      ref.generation~=A.published_generation or ref.generation~=A.retry_generation or A.published_key~=fingerprint or
      ref.action_key~=A.snapshot.fingerprint(A.result and A.result.action)then return false,'The published action changed.'end
    local snapshot=A.snapshot.capture(g)
    if not snapshot or A.snapshot.fingerprint(snapshot)~=fingerprint then return false,'The public state changed.'end
    local executable,why=A.can_execute()
    if not executable then return false,why or 'The existing Execute gate is not ready.'end
    local receipt,why=settlement:capture(g,A.result and A.result.action)
    if receipt==false then return false,why end
    return true
  end
  controller=controller_module.new({now=clock,observe=observe,log=write_log,project_log=project_log,
    search_start=function(request)
      local n=native();if not n or not n.prepare or not n.begin then return false,'Collection search is unavailable.'end
      local available,reason=n.can_begin()
      if available~=true then return false,reason end
      local recipe=copy(request.recipe)
      recipe.budget_ms=math.min(tonumber(recipe.budget_ms) or 30000,math.floor(request.budget_seconds*1000))
      local prepared,why=n.prepare(recipe)
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
      retired_run=nil;settlement:clear()
      local started_id=run_id(get())
      auto_games[get().GAME]=true
      if not terminal:arm(started_id)then return false,'The new run cannot bind terminal progress.'end
      return true,nil,started_id
    end,
    abandon_run=function(reason,context)
      local g=get();local id=run_id(g)
      if not (teacher_profile or retire_unsupported) or retired_run==id or not context or context.run_id~=id or not logging() or
        A.worker or A.execution_key or search_busy() or busy(g,false) or terminal:poll(id) then
        return false,'The current run cannot be retired while an action or transition is unresolved.'
      end
      local n=native()
      if not n or n.can_begin()~=true then return false,'A safe replacement run is not available.' end
      abandon_serial=abandon_serial+1
      local receipt={verified=true,run_id=id,event_id='abandon:'..abandon_serial,
        reason=reason,method='settled_run_retired_before_owned_search',terminal=false}
      if not log({event=teacher_profile and 'teacher_run_retired' or 'collection_run_retired',receipt=receipt,run_number=context.run_number,
        outcome=context.outcome,run_seconds=context.run_seconds,run_actions=context.run_actions}) then
        return false,'The abandonment record could not be written.'
      end
      -- Retire only. A later fresh observation precedes the normal owned search.
      retired_run=id;advice_token=nil;terminal:disarm()
      return true,nil,receipt
    end,
    can_execute=matches,
    execute=function(fingerprint,token)
      local okay,why=matches(fingerprint,token);if not okay then return false,why end
      local receipt,reason=settlement:capture(get(),A.result and A.result.action)
      if receipt==false then return false,reason end
      -- Bind before dispatch, including callbacks that throw after queuing work.
      -- Only this exact card's transfer and debit release the purchase barrier.
      settlement:bind(receipt)
      local journal=A.player_log;local source=journal.source;journal.source='auto_run'
      local result=packed(pcall(owned,A.execute,fingerprint,advice_token.generation))
      journal.source=source
      if not result[1]then error(result[2],0)end
      local accepted=result[2]
      -- Runtime releases its execution latch only for a confirmed preflight
      -- rejection. Such a rejection queued no transaction to wait for.
      settlement:release_on_rejection(accepted,A.execution_key)
      if not logging()then return false,'Recording stopped during the action; no further action will be attempted.'end
      return accepted==true,result[3]
    end})
  function api:owned()return self.internal_depth>0 or terminal:in_win_callback() end
  function api:teacher_profile()return teacher_profile end
  function api:engaged()
    return pending~=nil or suspended_pending~=nil or resuming~=nil or controller.engaged()
  end
  function api:status()
    local state=controller.status()
    if pending then state.state='arming';state.busy=true;state.reason=pending.reason or 'Menu is closing.'end
    state.resume_available=suspended_pending~=nil or state.resume_available==true
    state.resume_pending=resuming~=nil
    if resuming then state.state='resuming';state.busy=true end
    local search=native()
    local search_text=state.state=='searching' and owned_search and search and type(search.status)=='string' and search.status
    state.log_status=A.player_log and A.player_log.status
    self.status_text=state.complete and 'All 150 vanilla Jokers have verified loaded Gold stickers.' or
      pending and ('Waiting: '..tostring(pending.reason or 'Menu is closing.')) or
      resuming and ('Resuming: '..tostring(resuming.reason or 'Waiting for fresh advice.')) or
      state.input_wait and 'Auto-run is waiting for your controls or menu to settle.' or
      search_text or
      state.busy and ('Auto-run: '..tostring(state.state)..'; '..tostring(state.runs_started or 0)..' runs, '..tostring(state.actions or 0)..' actions.') or
      state.reason=='run_limit' and ('Auto-run stopped: run limit reached ('..tostring(state.runs_started)..
        ' of '..tostring(state.max_runs)..' runs; wins: '..tostring(state.outcomes.wins)..
        ', losses: '..tostring(state.outcomes.losses)..').') or
      state.reason and ('Auto-run stopped: '..tostring(state.detail or state.reason)) or 'Auto-run is off.'
    if state.resume_available and not state.busy then
      self.status_text=resume_error and ('Resume unavailable: '..resume_error) or 'Auto-run stopped. Resume continues this session.'
    end
    if state.busy and state.waiting_for=='executable_action' and state.detail then
      self.status_text=self.status_text..' '..tostring(state.detail)
    end
    if state.search_draining then self.status_text=self.status_text..' Waiting for the owned search worker to exit.'end
    if state.outcomes and state.outcomes.wins>0 and state.gold_progress then
      local progress=state.gold_progress
      self.status_text=self.status_text..' '..(progress.unknown_wins>0 and 'Confirmed new Gold: ' or 'New Gold: ')..
        tostring(progress.confirmed_new_count)..'; wins with no new Gold: '..tostring(progress.zero_new_wins)..'.'
      if progress.unknown_wins>0 then
        self.status_text=self.status_text..' Sticker progress unknown for '..tostring(progress.unknown_wins)..' win(s).'
      end
    end
    if (state.teacher_batch or state.retire_unsupported) and state.outcomes then
      local o=state.outcomes
      self.status_text=self.status_text..(state.teacher_batch and ' Teacher: ' or ' Collection marathon: ')..tostring(o.abandoned_stall or 0)..' stalls, '..
        tostring(o.unsupported or 0)..' unsupported, '..tostring(o.error or 0)..' errors.'
    end
    return state
  end
  -- Controller.status returns a copy; this getter does not update status or work.
  function api:status_report()
    local state=controller.status()
    local requested=generations.consent_generation>0
    return {requested=requested,busy=pending~=nil or resuming~=nil or state.busy==true,text=self.status_text,
      resume_available=suspended_pending~=nil or state.resume_available==true,resume_pending=resuming~=nil,
      phase=pending and 'waiting' or resuming and 'resuming' or state.state or 'idle',owner=requested and 'auto' or nil}
  end
  function api:stop(reason)
    local t=now()
    if pending then
      if t and pending.input_since then pending.at=math.min(t,pending.at+t-pending.input_since);pending.input_since=nil end
      suspended_pending=pending;pending=nil;stopped_at=t
    elseif resuming or controller.status().active then stopped_at=t end
    resuming=nil;resume_error=nil
    local stopped=controller.stop(reason or 'User stopped auto-run');self:status();return stopped
  end
  local function halt(reason)
    pending=nil;suspended_pending=nil;resuming=nil;checkpoint_loaded=nil
    profile_binding=nil;terminal:disarm();controller.halt(reason);api:status()
    return false
  end
  function api:manual(reason,kind)
    if self:owned()then return false end
    -- Ordinary input is not a revocation of explicit auto-run consent. Fresh
    -- snapshot/action/generation checks still protect every actual dispatch.
    if kind=='checkpoint_loaded' and self:engaged() then
      checkpoint_loaded=true;checkpoint_at=now();advice_token=nil;settlement:clear()
    end
    return true
  end
  function api:resume()
    local state=controller.status();local g=get()
    if pending or resuming or state.active then return false,'Auto-run is already active or resuming.' end
    if not suspended_pending and not state.resume_available then return false,'No stopped session is available to resume.' end
    if state.search_draining or search_busy() then return false,'Wait for the stopped search worker to exit.' end
    if not logging() then return false,'Restore observation recording before resuming.' end
    if not g or not g.GAME or (g.PROFILES or {})[(g.SETTINGS or {}).profile]~=profile_binding then
      return false,'The original loaded profile changed.'
    end
    local t=now();if not t then return false,'A finite clock is unavailable.' end
    if not log({event='explicit_resume_requested',session=state.session_serial,run_id=run_id(g),
      scope='Same in-memory session; no limits, counts, run or logging session reset.'}) then return false,'Recording rejected Resume.' end
    if A.settings_changed then owned(A.settings_changed)end
    -- Resume may follow the final receipt or a terminal callback while stopped.
    -- Retain its exact owned result until fresh controller checks decide whether
    -- this session can continue; explicit Resume never renews its run allowance.
    if g.OVERLAY_MENU and not terminal:owned_overlay(run_id(g)) then
      local close=deps.exit_overlay or g.FUNCS and g.FUNCS.exit_overlay_menu
      if type(close)~='function' then return false,'The menu cannot close safely.' end
      local okay,why=pcall(owned,close);if not okay then return false,tostring(why) end
    end
    A.menu_open,A.menu_overlay=false,nil
    resume_error=nil;resuming={profile=(g.SETTINGS or {}).profile,game=g.GAME,at=t,last_time=t}
    self:status();return true
  end
  function api:start(options)
    if pending or resuming or controller.status().busy then return false,'Auto-run or its search worker is already active.'end
    local g=get();if not g or not g.GAME or search_busy()then return false,'Wait for the current activity to finish.'end
    local n=native()
    for _,name in ipairs({'can_begin','prepare','begin','poll','cancel','launch'})do
      if not n or type(n[name])~='function'then return false,'Collection search is unavailable.'end
    end
    if not B.CollectionSearchRuntime or type(B.CollectionSearchRuntime.busy)~='function'then return false,'Native worker ownership is unavailable.'end
    if not A.player_log then return false,'Observation recording is unavailable.'end
    if options~=nil and (type(options)~='table' or getmetatable(options))then return false,'Auto-run options must be plain data.'end
    local copied,configured=pcall(copy,options or {})
    if not copied then return false,tostring(configured)end
    if configured.teacher_batch~=nil and type(configured.teacher_batch)~='boolean' then return false,'Invalid teacher mode.' end
    if configured.retire_unsupported~=nil and type(configured.retire_unsupported)~='boolean' then return false,'Invalid retirement option.' end
    if configured.retire_unsupported and (not A.player_journal or type(A.player_journal.semantic_fingerprint)~='function') then
      return false,'Marathon progress recording is unavailable.'
    end
    if configured.teacher_batch==true then
      if A.execution_key then return false,'Wait for the current action to settle before clearing observations.' end
      if type(A.player_log.prepare_collection)~='function' or not A.player_journal or
        type(A.player_journal.semantic_fingerprint)~='function' then return false,'Teacher recording is unavailable.' end
      configured={teacher_batch=true,max_runs=10,stall_seconds=30,search_seconds=30,
        max_actions=500,run_seconds=1800,session_seconds=21600,
        search_request={deck_name='Red Deck',interchangeable_copies=true,quota_mode='strict',
          minimum_distinct=0,first_ante=1,last_ante=8,budget_ms=30000,burnt_fallback=true,legendary_fallback=false}}
    elseif A.player_log.error then return false,'Observation recording is unavailable.' end
    if configured.search_request~=nil and (type(configured.search_request)~='table' or getmetatable(configured.search_request))then
      return false,'Search options must be plain data.'
    end
    configured.search_request=configured.search_request or {}
    for _,key in ipairs({'deck_name','interchangeable_copies','minimum_distinct','quota_mode','first_ante','last_ante','budget_ms','burnt_fallback','legendary_fallback'})do
      if not configured.teacher_batch and options and options[key]~=nil then
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
    if configured.teacher_batch then
      -- Cancel only the advisor coroutine before replacing its own journal.
      -- No game callback, save, profile, or unrelated log is touched here.
      if A.settings_changed then owned(A.settings_changed)end
      local okay,receipt=A.player_log:prepare_collection({clear_existing=true,
        collection_id='teacher356-'..tostring(os.time())..'-'..tostring(generations.consent_generation+1)})
      if not okay then return false,'Teacher log preparation failed: '..tostring(receipt) end
      configured.collection_receipt=copy(receipt)
      teacher_profile='perkeo_yorick_win_v1'
    else
      if A.player_log.end_collection then A.player_log:end_collection('A normal auto-run session was requested.')end
      teacher_profile=nil
    end
    retire_unsupported=configured.retire_unsupported==true
    A.teacher_profile=teacher_profile
    B.config.advisor.enabled=true;B.config.advisor.challenge_only=false
    B.config.advisor.gold_stickers=true;B.config.advisor.player_logging=true
    generations.consent_generation=generations.consent_generation+1
    if not log({event='explicit_start_requested',version=B.VERSION,options=copy(configured),
      teacher_profile=teacher_profile,teacher_quality='unreviewed_heuristic',
      profile_id=(g.SETTINGS or {}).profile,run_id=run_id(g),scope=teacher_profile and
        'User requested ten real win-first teacher runs; old observation journals cleared. No win or expert label is assumed.' or
        'User enabled advisor, Gold objective, recording and bounded automatic play/search.'})then
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
    suspended_pending=nil;checkpoint_loaded=nil;resume_error=nil;terminal:disarm()
    pending={options=configured,profile=(g.SETTINGS or {}).profile,profile_table=profile_binding,at=now,game=g.GAME}
    self:status()
    return true
  end
  function api:update()
    local g=get()
    local finished=controller.status()
    if teacher_profile and not pending and not resuming and not suspended_pending and
      not finished.active and not finished.resume_available and not finished.search_draining then
      if A.player_log and A.player_log.end_collection then A.player_log:end_collection(finished.reason or 'Session ended.')end
      B.config.advisor.player_logging=false
      teacher_profile=nil;A.teacher_profile=nil
      if A.settings_changed then owned(A.settings_changed)end
    end
    if resuming then
      local t=now();if not t then return halt('Resume clock unavailable.') end
      if t<resuming.last_time then return halt('Resume clock moved backwards.') end
      resuming.last_time=t
      if not logging() or (g.SETTINGS or {}).profile~=resuming.profile or g.GAME~=resuming.game or
        (g.PROFILES or {})[resuming.profile]~=profile_binding then return halt('Resume context changed.') end
      local blocked,why=busy(g,terminal:owned_overlay(run_id(g))~=nil);resuming.reason=why
      if blocked then
        if t-resuming.at>=30 then resuming=nil;resume_error='The controls have not settled yet.' end
        return self:status()
      end
      resuming=nil
      if suspended_pending then
        pending=suspended_pending;suspended_pending=nil
        pending.at=pending.at+t-(stopped_at or t)
      else
        local okay,reason=controller.resume()
        if not okay then resume_error=tostring(reason);return self:status() end
      end
      return self:status()
    end
    if pending then
      local t=now();if not t then return halt('Startup clock unavailable.') end
      if t<(pending.last_time or pending.at) then return halt('Startup clock moved backwards.') end
      pending.last_time=t
      if not logging()or (g.SETTINGS or {}).profile~=pending.profile or
        (g.PROFILES or {})[pending.profile]~=pending.profile_table or g.GAME~=pending.game then return halt('Start context changed')end
      local blocked,reason=busy(g,false);pending.reason=reason
      if user_busy(g) then pending.input_since=pending.input_since or t;return self:status() end
      if pending.input_since then pending.at=pending.at+t-pending.input_since;pending.input_since=nil end
      if t-pending.at>=30 then return halt('The menu did not settle before startup')end
      if not blocked then
        local options=pending.options;pending=nil
        local okay,why=controller.start(options)
        if not okay then controller.stop(why or 'Automatic startup was rejected')end
      end
      return self:status()
    end
    local state=controller.status()
    if state.active and not logging()then halt('Observation recording stopped');return self:status()end
    if checkpoint_loaded and (state.active or state.resume_available) then
      if not controller.check_limits() then checkpoint_loaded=nil;return self:status() end
      local t=now()
      if not t or not checkpoint_at or t-checkpoint_at>=30 then return halt('Restored checkpoint did not become eligible for continuation.') end
      if (g.PROFILES or {})[(g.SETTINGS or {}).profile]~=profile_binding then return halt('Restored checkpoint profile changed.') end
      if busy(g,false) or A.worker or A.execution_key then return self:status() end
      local okay,why=controller.continue_checkpoint()
      if not okay then
        local result=self:status();self.status_text='Auto-run is waiting for the restored checkpoint: '..tostring(why);return result
      end
      if not terminal:arm(run_id(g)) then return halt('Restored checkpoint cannot bind new terminal evidence.') end
      auto_games[g.GAME]=true
      checkpoint_loaded=nil;return self:status()
    end
    -- The earlier update logged the verified outcome. Reread the goal and
    -- remaining allowance before dismissing its original result surface;
    -- completion or a hard stop must leave that surface available to the user.
    if state.active and state.state=='terminal' then
      terminal:install_hooks()
      state=controller.tick()
      if not state.active or state.state~='terminal' or state.input_wait then return self:status()end
      local overlay=terminal:owned_overlay(run_id(g))
      if overlay then
        if not log({event='terminal_overlay_close_requested',run_id=run_id(g)})then halt('Observation recording stopped');return self:status()end
        local close=deps.exit_overlay or g.FUNCS and g.FUNCS.exit_overlay_menu
        if type(close)~='function'then halt('The result screen cannot close safely');return self:status()end
        local okay,why=pcall(owned,close)
        if not okay then halt('The result screen could not close: '..tostring(why))end
        return self:status()
      end
      return self:status()
    end
    terminal:install_hooks()
    controller.tick();return self:status()
  end
  B.AutoRun=api;return api
end
return M
