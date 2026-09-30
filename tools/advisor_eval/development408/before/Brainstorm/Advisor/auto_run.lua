-- Explicitly started, injected auto-run controller. No game globals, RNG,
-- persistence, filesystem, threads or native calls belong in this module.
local M={schema=1}
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function integer(v,lo,hi) return finite(v) and v%1==0 and v>=lo and (not hi or v<=hi) end
local function id(v) return type(v)=='string' and v~='' and #v<=256 or integer(v,0) end
local function clone(value,seen,budget,depth)
  seen=seen or {};budget=budget or {left=20000};depth=depth or 0
  budget.left=budget.left-1
  if budget.left<0 or depth>16 then error('Controller data exceeded its copy bound.',0) end
  if type(value)~='table' then
    if value==nil or type(value)=='boolean' or finite(value) or type(value)=='string' and #value<=262144 then return value end
    error('Controller data must be plain finite values.',0)
  end
  if getmetatable(value) or seen[value] then error('Controller data must be plain and acyclic.',0) end
  seen[value]=true;local result={}
  for key,v in pairs(value) do
    if type(key)~='string' and not integer(key,1) then error('Invalid controller data key.',0) end
    result[key]=clone(v,seen,budget,depth+1)
  end
  seen[value]=nil;return result
end
local generation_fields={'consent_generation','settings_generation','checkpoint_generation','manual_generation'}
local function config(options)
  options=options or {}
  if type(options)~='table' then return nil,'Options must be a table.' end
  local c={}
  if options.teacher_batch~=nil and type(options.teacher_batch)~='boolean' then return nil,'Invalid teacher_batch option.' end
  c.teacher_batch=options.teacher_batch==true
  if options.retire_unsupported~=nil and type(options.retire_unsupported)~='boolean' then return nil,'Invalid retirement option.' end
  c.retire_unsupported=options.retire_unsupported==true
  c.retire_runs=c.teacher_batch or c.retire_unsupported
  for _,entry in ipairs({{'search_seconds',30,30},{'stall_seconds',30,30},{'max_actions',500,500},
      {'run_seconds',1800,1800},{'max_runs',25,100},{'session_seconds',21600,21600}}) do
    local value=options[entry[1]];if value==nil then value=c.teacher_batch and entry[1]=='max_runs' and 10 or entry[2] end
    if not integer(value,1,entry[3]) then return nil,'Invalid '..entry[1]..' limit.' end
    c[entry[1]]=value
  end
  if c.teacher_batch and (c.max_runs>10 or c.stall_seconds~=30) then
    return nil,'Teacher batches allow at most ten actual starts and require the thirty-second semantic watchdog.'
  end
  local ok,request=pcall(clone,options.search_request or {})
  if not ok then return nil,request end
  c.search_request=request
  return c
end
local function outcomes(teacher)
  local out={wins=0,losses=0}
  if teacher then out.abandoned_stall=0;out.unsupported=0;out.error=0 end
  return out
end
local function goal_status(goal,profile)
  if type(goal)~='table' or goal.schema~=1 or goal.goal~='gold_stickers' or goal.profile_id~=profile or
      goal.metadata_status~='complete' or goal.catalog_status~='complete' or goal.stake_status~='complete' then
    return nil,'Loaded Gold-sticker metadata is unavailable or changed.'
  end
  local c=goal.counts
  if type(c)~='table' or c.total~=150 or not integer(c.complete,0,150) or not integer(c.missing,0,150) or
      not integer(c.unknown,0,150) or c.complete+c.missing+c.unknown~=150 then
    return nil,'Gold-sticker counts are inconsistent.'
  end
  if c.unknown~=0 then return nil,'Unknown Gold-sticker records cannot support auto-run.' end
  return c.missing==0 and 'complete' or 'missing'
end
local function gold_progress()
  return {schema=1,confirmed_new_count=0,confirmed_new_keys={},zero_new_wins=0,unknown_wins=0}
end
-- Count achievement progress from the bound original award callback only.
-- The loaded catalog is an identity whitelist; neither its history statuses,
-- its aggregate counts nor the current held row establishes an earned sticker.
local function gold_award(ended,goal)
  if ended.kind~='win' then return {schema=1,status='not_applicable'} end
  local function unknown(reason) return {schema=1,status='unknown',reason=reason} end
  local final,callbacks=ended.final_context,ended.callbacks
  if type(final)~='table' or final.stake~=8 or final.seeded~=false or final.challenge or final.boss~=true or
      not integer(final.ante,1) or final.ante~=final.win_ante or not integer(final.round,0) or
      type(final.deck)~='string' or final.deck=='' or type(callbacks)~='table' then
    return unknown('The original Gold award context is unavailable.')
  end
  local count=0
  for index in pairs(callbacks) do
    if not integer(index,1,2) then return unknown('The original award callback sequence is incomplete.') end
    count=count+1
  end
  if count~=2 then return unknown('The original award callback sequence is incomplete.') end
  for i,name in ipairs({'set_joker_win','set_deck_win'}) do
    local callback=callbacks[i]
    if type(callback)~='table' or callback.name~=name or callback.verified~=true then
      return unknown('The original award callback sequence is unverified.')
    end
    for _,field in ipairs({'before','after'}) do
      local context=callback[field]
      if type(context)~='table' or context.stake~=8 or context.deck~=final.deck or context.round~=final.round or
          context.won~=true or context.seeded~=false or context.challenge then
        return unknown('The original award callback context does not match this Gold win.')
      end
    end
  end
  local before,after=callbacks[1].before.jokers,callbacks[1].after.jokers
  if type(before)~='table' or type(after)~='table' or type(goal)~='table' or goal.catalog_status~='complete' or
      type(goal.by_key)~='table' then return unknown('The complete original Joker counters or vanilla catalog are unavailable.') end
  local keys,total={},0
  for key,value in pairs(before) do
    total=total+1
    local row=goal.by_key[key]
    if total>150 or type(key)~='string' or type(row)~='table' or row.key~=key or
        not integer(value,0) or not integer(after[key],0) or after[key]<=value then
      return unknown('An original Joker award identity or counter is unavailable or inconsistent.')
    end
    if value==0 then keys[#keys+1]=key end
  end
  for key in pairs(after) do
    if before[key]==nil then return unknown('The original Joker award changed its identity set.') end
  end
  table.sort(keys)
  return {schema=1,status='confirmed',new_count=#keys,new_keys=keys,source='original_set_joker_win',
    scope='Distinct vanilla Gold counters changing from zero to positive in this verified original win callback.'}
end
function M.new(callbacks)
  local cb={}
  for _,key in ipairs({'observe','search_start','search_poll','search_cancel','start_run','can_execute','execute','log','now'}) do
    assert(type(callbacks and callbacks[key])=='function','Missing auto-run callback '..key)
    cb[key]=callbacks[key]
  end
  if callbacks.project_log~=nil then
    assert(type(callbacks.project_log)=='function','Invalid auto-run log projection callback')
    cb.project_log=callbacks.project_log
  end
  if callbacks.abandon_run~=nil then
    assert(type(callbacks.abandon_run)=='function','Invalid auto-run abandonment callback')
    cb.abandon_run=callbacks.abandon_run
  end
  local state={state='idle',active=false,complete=false,search_pending=false,session_serial=0,
    runs_started=0,start_attempts=0,uncertain_starts=0,actions=0,outcomes={wins=0,losses=0},gold_progress=gold_progress(),gold_seen={},last_time=nil}
  local api={}
  local request_abandon
  local function start_allowances_used()
    return state.config and state.config.retire_runs and state.start_attempts or state.runs_started
  end
  local function emit(event,details)
    local record={schema=1,event=event,time=state.last_time,session=state.session_serial,
      profile_id=state.binding and state.binding.profile_id,run_id=state.run_id,
      search_id=state.search_id,state=state.state}
    for k,v in pairs(details or {}) do record[k]=v end
    -- Product freshness keys may be much larger than an exported log field.
    -- Apply its opaque identity projection before the unchanged bounded copy.
    -- This never changes the exact keys retained for equality and execution.
    if cb.project_log then
      local okay,projected=pcall(cb.project_log,record)
      if not okay then return false,'Controller log projection failed.' end
      if type(projected)~='table' or getmetatable(projected) then
        return false,'Controller log projection must return a plain record.'
      end
      record=projected
    end
    local copied,payload=pcall(clone,record)
    if not copied then return false,tostring(payload) end
    local ok,result=pcall(cb.log,payload)
    if not ok or result==false then return false,ok and 'The event log rejected a record.' or tostring(result) end
    return true
  end
  local function cancel_search()
    if not state.search_pending or state.cancel_requested then return end
    state.cancel_requested=true
    local ok,result=pcall(cb.search_cancel,state.search_id)
    state.cancel_error=not ok and tostring(result) or result==false and 'Cancellation request was rejected.' or nil
    emit('search_cancel_requested',{reason=state.reason,cancel_error=state.cancel_error})
  end
  local function stop(reason,detail,completed,resumable)
    if state.active or state.state~='stopped' or not resumable and reason~=state.reason then
      state.resume_point=resumable and state.active and {state=state.state,waiting_for=state.waiting_for} or nil
      state.stopped_at=state.last_time
      state.active=false;state.state='stopped';state.reason=reason;state.detail=detail
      state.complete=completed==true
      local ok,why=emit(completed and 'collection_complete' or 'session_stopped',
        {reason=reason,detail=detail,runs_started=state.runs_started,
          start_attempts=state.start_attempts,uncertain_starts=state.uncertain_starts,actions=state.actions,
          outcomes=state.outcomes,gold_progress=state.gold_progress,search_draining=state.search_pending})
      if not ok then state.log_error=why end
    end
    cancel_search()
  end
  local function clock()
    local ok,t=pcall(cb.now)
    if not ok or not finite(t) or state.last_time and t<state.last_time then
      stop('clock_unavailable','A finite monotonic clock is required.');return nil
    end
    state.last_time=t;return t
  end
  local function observe()
    local ok,obs=pcall(cb.observe)
    if not ok or type(obs)~='table' or getmetatable(obs) then
      stop('observation_unavailable',ok and 'No plain observation.' or tostring(obs));return nil
    end
    return obs
  end
  local function checked_log(event,details)
    local ok,why=emit(event,details)
    if not ok then stop('log_unavailable',why);return false end
    return true
  end
  local function binding(obs)
    if not id(obs.profile_id) then return nil,'The current profile identity is unavailable.' end
    local b={profile_id=obs.profile_id}
    for _,field in ipairs(generation_fields) do
      if not integer(obs[field],0) then return nil,'Missing '..field..' change tracking.' end
      b[field]=obs[field]
    end
    return b
  end
  local function check_observation(obs)
    if obs.profile_id~=state.binding.profile_id then stop('profile_changed');return false end
    for _,field in ipairs(generation_fields) do
      if obs[field]~=state.binding[field] then stop(field..'_changed');return false end
    end
    return true
  end
  local function pause_watchdogs(seconds,t)
    -- A search/terminal receipt may establish progress during the input wait.
    -- Exclude only the overlap after that receipt, never grant future time.
    if state.progress_at then state.progress_at=math.min(t,state.progress_at+seconds) end
    if state.semantic_at then state.semantic_at=math.min(t,state.semantic_at+seconds) end
    if state.pending_action then state.pending_action.time=math.min(t,state.pending_action.time+seconds) end
  end
  local function input_wait(obs,t)
    if obs.modal or obs.paused or obs.input_busy then
      state.input_since=state.input_since or t;state.input_wait=true
      return true
    end
    if state.input_since then pause_watchdogs(t-state.input_since,t) end
    state.input_since=nil;state.input_wait=nil
    return false
  end
  local function ready(obs)
    return obs.ready==true and not obs.modal and not obs.paused and not obs.advisor_busy and not obs.action_pending and not obs.search_busy
  end
  local function progress(obs,t)
    if type(obs.fingerprint)=='string' and obs.fingerprint~='' and obs.fingerprint~=state.progress_fingerprint then
      -- Animations or changing metadata must not continually renew a missing
      -- action's thirty-second allowance. Only accepted lifecycle progress and
      -- observation of a dispatched action renew that allowance.
      state.progress_fingerprint=obs.fingerprint
    end
    if state.config.retire_runs and ready(obs) and not obs.input_busy then
      local token=obs.semantic_fingerprint
      if type(token)~='string' or token=='' or #token>8192 then
        if state.config.teacher_batch then request_abandon('error','semantic_progress_unavailable',obs.decision_reason)
        else stop('semantic_progress_unavailable',obs.decision_reason) end;return
      end
      if not state.semantic_seen[token] then
        -- More than one settled public state can occur per advisory action;
        -- keep room for those phases and manual play without accepting loops
        -- as progress. The storage bound remains independent of frame count.
        if state.semantic_count>=2048 then
          if state.config.teacher_batch then request_abandon('error','semantic_progress_capacity')
          else stop('semantic_progress_capacity') end;return
        end
        state.semantic_seen[token]=true;state.semantic_count=state.semantic_count+1
        state.semantic_at=t;state.semantic_fingerprint=token
      end
    end
  end
  local function stalled(t,reason)
    -- Search/start/terminal transitions have their own lifecycle receipts.
    -- A finished game's old semantic timestamp cannot expire a new wait.
    local since=state.config.retire_runs and state.run_id and not state.run_finalized and
      state.semantic_at or state.progress_at
    if t-(since or t)>=state.config.stall_seconds then
      if state.config.retire_runs and state.run_id and not state.run_finalized then
        request_abandon('abandoned_stall',reason or 'stalled')
      else stop(reason or 'stalled') end
      return true
    end
    return false
  end
  request_abandon=function(outcome,reason,detail)
    if not state.config.retire_runs or not state.active or state.run_finalized or not state.run_id then return false end
    if not state.abandon_pending then
      state.abandon_pending={outcome=outcome,reason=reason,detail=detail,time=state.last_time}
    end
    return true
  end
  local function maybe_abandon(obs,t)
    local pending=state.abandon_pending
    if not pending then return false end
    -- A watchdog is not permission to replace a moving/paused game. The
    -- product independently verifies these gates again inside its callback.
    if not ready(obs) or obs.abandon_ready~=true or obs.input_busy or obs.terminal then
      state.state='waiting';state.waiting_for='abandon_ready';state.detail=pending.reason
      return true
    end
    local context={run_id=state.run_id,run_number=state.runs_started,outcome=pending.outcome,
      reason=pending.reason,detail=pending.detail,run_seconds=t-state.run_started_at,
      run_actions=state.run_actions,semantic_fingerprint=state.semantic_fingerprint,
      last_action=state.last_action,pending_action=state.pending_action,
      action=obs.action,advice=obs.advice,decision_state=obs.decision_state,decision_reason=obs.decision_reason}
    if not checked_log('run_abandon_requested',context) or not state.active then return true end
    -- The product retirement callback needs only scalar run identity and
    -- accounting. The projected audit above retains the full context; never
    -- copy a raw exact-state fingerprint into the callback's bounded payload.
    local retirement={run_id=state.run_id,run_number=state.runs_started,outcome=pending.outcome,
      run_seconds=t-state.run_started_at,run_actions=state.run_actions}
    local called,accepted,detail,receipt=pcall(cb.abandon_run,pending.reason,retirement)
    if not called or accepted~=true then
      stop('abandon_uncertain',called and detail or tostring(accepted));return true
    end
    if type(receipt)~='table' or receipt.verified~=true or receipt.run_id~=state.run_id or not id(receipt.event_id)
        or state.abandonment_seen[receipt.event_id] then
      stop('abandon_unverified','The product did not verify retirement of this settled run.');return true
    end
    state.abandonment_seen[receipt.event_id]=true
    state.run_finalized=true;state.pending_action=nil;state.abandon_pending=nil
    state.outcomes[pending.outcome]=state.outcomes[pending.outcome]+1
    state.last_abandonment=clone(receipt);state.progress_at=t
    if state.active then state.state='abandoned';state.waiting_for=nil;state.detail=nil
    else state.resume_point=nil end -- A Stop delivered inside the callback stays authoritative.
    checked_log('run_abandoned',{outcome=pending.outcome,reason=pending.reason,detail=pending.detail,
      evidence=receipt,run_number=state.runs_started,run_seconds=t-state.run_started_at,
      run_actions=state.run_actions,last_action=state.last_action,actual_terminal=false})
    return true -- Only a later fresh tick can search or launch another run.
  end
  local function poll_search(t,draining)
    local ok,poll=pcall(cb.search_poll,state.search_id)
    if not ok or type(poll)~='table' then
      if not draining then stop('search_poll_error',ok and 'Missing search status.' or tostring(poll)) end
      return
    end
    if poll.request_id~=state.search_id then
      if not draining then stop('search_identity_changed','The owned search worker has a different request identity.') end
      return
    end
    if poll.exited~=true then return end
    state.search_pending=false
    if draining or state.cancel_requested or not state.active then
      emit('search_worker_exited',{status=poll.status,late_result_discarded=poll.status=='found'})
      return
    end
    -- Check time again after the nonblocking poll. A late result cannot win a
    -- race against the hard deadline simply because it arrived between ticks.
    local current=clock();if not current then return end
    if current>=state.search_deadline then stop('search_timeout');return end
    if poll.status~='found' then stop(poll.status=='not_found' and 'search_not_found' or 'search_failed',poll.reason);return end
    if type(poll.found)~='table' or type(poll.found.seed)~='string' or poll.found.seed=='' or #poll.found.seed>16 then
      stop('search_result_invalid');return
    end
    local copied,found=pcall(clone,poll.found)
    if not copied then stop('search_result_invalid',tostring(found));return end
    state.found=found;state.state='waiting';state.waiting_for='start_ready';state.progress_at=current
    checked_log('search_found',{found=found,search_seconds=current-state.search_started_at})
  end
  local function begin_search(obs,t)
    if start_allowances_used()>=state.config.max_runs then stop('run_limit');return end
    if obs.search_busy then stop('external_search_active');return end
    local goal,why=goal_status(obs.goal,state.binding.profile_id)
    if not goal then stop('goal_unavailable',why);return end
    if goal=='complete' and not state.config.teacher_batch then stop('collection_complete',nil,true);return end
    local ok,request=pcall(clone,{recipe=state.config.search_request,goal=obs.goal,
      profile_id=state.binding.profile_id,consent_generation=state.binding.consent_generation,
      budget_seconds=state.config.search_seconds})
    if not ok then stop('search_request_invalid',tostring(request));return end
    state.search_number=state.search_number+1
    state.search_id='auto:'..tostring(state.binding.consent_generation)..':'..state.session_serial..':'..state.search_number
    request.request_id=state.search_id;request.deadline=t+state.config.search_seconds
    state.search_started_at=t;state.search_deadline=request.deadline
    state.search_pending=false;state.cancel_requested=false;state.cancel_error=nil;state.found=nil
    state.state='searching';state.waiting_for=nil
    if not checked_log('search_requested',{request=request}) then return end
    state.search_pending=true
    local called,accepted,detail=pcall(cb.search_start,request)
    if not called then stop('search_start_uncertain',tostring(accepted));return end
    if accepted~=true then
      -- Contract: an explicit false return proves that no worker started.
      -- Throws remain uncertain and retain cancellation/poll obligations.
      if accepted==false then state.search_pending=false end
      stop('search_start_failed',detail);return
    end
    if not checked_log('search_started',{request_id=state.search_id}) then return end
    local current=clock()
    if current and current>=state.search_deadline then stop('search_timeout') end
  end
  local function begin_run(obs,t)
    if not ready(obs) or obs.transition_ready~=true then
      state.state='waiting';state.waiting_for='start_ready';stalled(t,'start_not_ready');return
    end
    if start_allowances_used()>=state.config.max_runs then stop('run_limit');return end
    if obs.search_busy then stop('external_search_active');return end
    state.previous_run_id=obs.run_id;state.run_id=nil;state.run_actions=0;state.pending_action=nil
    state.run_started_at=t;state.progress_at=t;state.progress_fingerprint=nil
    state.semantic_at=t;state.semantic_seen={};state.semantic_count=0;state.semantic_fingerprint=nil
    state.abandon_pending=nil;state.last_action=nil;state.last_abandonment=nil
    local next_run=state.runs_started+1;state.run_finalized=false
    state.state='starting';state.waiting_for=nil
    if not checked_log('run_start_requested',{found=state.found,run_number=next_run}) then return end
    -- The product may launch before a later callback fails (for example while
    -- binding terminal observation). Reserve the retiring session's allowance first;
    -- uncertainty cannot refund it or be resumed into a second launch.
    if state.config.retire_runs then state.start_attempts=state.start_attempts+1 end
    local ok,accepted,detail,started_id=pcall(cb.start_run,clone(state.found),clone(state.binding))
    if not ok or accepted~=true then
      if state.config.retire_runs then state.uncertain_starts=state.uncertain_starts+1 end
      stop('run_start_uncertain',ok and detail or tostring(accepted));return
    end
    state.expected_run_id=id(started_id) and started_id or nil
    state.runs_started=next_run
    state.found=nil
    if state.config.retire_runs then
      if not state.expected_run_id then
        stop('run_start_identity_unavailable','The accepted run start has no bound identity; its start allowance remains consumed.');return
      end
      -- Bind an accepted start before the first settled advisory snapshot, so
      -- startup stalls and fast terminal callbacks retain this actual attempt.
      state.run_id=state.expected_run_id
      checked_log('run_launch_accepted',{run_number=next_run})
    end
  end
  local function terminal(obs,t)
    local ended=obs.terminal
    if ended==nil then return false end
    if type(ended)~='table' or ended.verified~=true or ended.run_id~=state.run_id or not id(ended.event_id) or
        not (ended.kind=='win' and ended.source=='original_win_callback' or ended.kind=='loss' and ended.source=='GAME_OVER') then
      stop('terminal_unverified','A loaded GAME.won flag or an unbound terminal report cannot establish a win.');return true
    end
    if state.run_finalized then return true end
    state.run_finalized=true;state.pending_action=nil;state.abandon_pending=nil;state.state='terminal';state.waiting_for=nil;state.progress_at=t
    state.terminal_event=clone(ended)
    local kind=ended.kind=='win' and 'wins' or 'losses';state.outcomes[kind]=state.outcomes[kind]+1
    local award=gold_award(ended,obs.goal);state.last_gold_award=award
    if award.status=='confirmed' then
      if award.new_count==0 then state.gold_progress.zero_new_wins=state.gold_progress.zero_new_wins+1 end
      for _,key in ipairs(award.new_keys) do
        if not state.gold_seen[key] then
          state.gold_seen[key]=true
          state.gold_progress.confirmed_new_keys[#state.gold_progress.confirmed_new_keys+1]=key
        end
      end
      table.sort(state.gold_progress.confirmed_new_keys)
      state.gold_progress.confirmed_new_count=#state.gold_progress.confirmed_new_keys
    elseif award.status=='unknown' then state.gold_progress.unknown_wins=state.gold_progress.unknown_wins+1 end
    checked_log('run_finished',{outcome=ended.kind,evidence=ended,run_seconds=t-state.run_started_at,
      run_actions=state.run_actions,run_number=state.runs_started,gold_award=award,gold_progress=state.gold_progress})
    return true
  end
  function api.start(options)
    if state.active or state.search_pending then return false,'The previous session or search worker is still active.' end
    local c,why=config(options);if not c then return false,why end
    if c.retire_runs and not cb.abandon_run then return false,'Retiring sessions require the verified product abandonment callback.' end
    local t=clock();if not t then return false,state.reason end
    local obs=observe();if not obs then return false,state.reason end
    local b;b,why=binding(obs);if not b then return false,why end
    if obs.modal or obs.paused or obs.search_busy or obs.action_pending then return false,'Close menus and wait for existing activity before starting.' end
    local goal;goal,why=goal_status(obs.goal,b.profile_id);if not goal then return false,why end
    state.session_serial=state.session_serial+1;state.config=c;state.binding=b;state.session_started_at=t
    state.active=true;state.complete=false;state.reason=nil;state.detail=nil;state.log_error=nil
    state.state='waiting';state.waiting_for='search_ready';state.search_number=0
    state.runs_started=0;state.start_attempts=0;state.uncertain_starts=0
    state.actions=0;state.outcomes=outcomes(c.retire_runs);state.run_id=nil
    state.gold_progress=gold_progress();state.gold_seen={};state.last_gold_award=nil
    state.run_actions=0;state.pending_action=nil;state.found=nil;state.terminal_event=nil
    state.run_started_at=nil;state.expected_run_id=nil;state.run_finalized=false
    state.progress_at=t;state.progress_fingerprint=nil;state.cancel_requested=false
    state.semantic_at=nil;state.semantic_seen={};state.semantic_count=0;state.semantic_fingerprint=nil
    state.abandon_pending=nil;state.last_action=nil;state.last_abandonment=nil;state.abandonment_seen={}
    state.resume_point=nil;state.stopped_at=nil
    state.input_since=nil;state.input_wait=nil;state.resumes=0;state.manual_continuations=0
    if not checked_log('session_started',{binding=b,limits=c,goal=obs.goal}) then return false,state.reason end
    if goal=='complete' and not c.teacher_batch then stop('collection_complete',nil,true) end
    -- Starting never performs gameplay or dispatches a search in the UI call.
    -- The next explicit tick observes the state afresh before doing either.
    return true
  end
  function api.stop(reason)
    local t=clock()
    if t and state.active and state.input_since then
      pause_watchdogs(t-state.input_since,t);state.input_since=nil;state.input_wait=nil
    end
    stop(reason or 'user_stop',nil,false,true)
    return not state.search_pending
  end
  function api.resume()
    if state.active then return false,'Auto-run is already active.' end
    if not state.resume_point then return false,'There is no stopped session to resume.' end
    if state.search_pending then return false,'Wait for the stopped search worker to exit.' end
    local t=clock();if not t then return false,state.reason end
    local point=state.resume_point
    local obs=observe();if not obs then return false,state.reason end
    local b,why=binding(obs);if not b then return false,why end
    for k,v in pairs(state.binding) do if b[k]~=v then return false,'The original session context changed: '..k end end
    if obs.modal or obs.paused or obs.input_busy or obs.search_busy then return false,'Wait for the current controls to settle.' end
    if state.run_id and obs.run_id~=state.run_id then return false,'The original run was replaced.' end
    if point.state=='starting' and (not state.expected_run_id or obs.run_id~=state.expected_run_id) then
      return false,'The already-started run identity is not verified.'
    end
    if not obs.terminal then
      if t-state.session_started_at>=state.config.session_seconds then return false,'The original session time limit is exhausted.' end
      if state.run_started_at and not state.run_finalized and t-state.run_started_at>=state.config.run_seconds then
        return false,'The original run time limit is exhausted.'
      end
    end
    local goal;goal,why=goal_status(obs.goal,b.profile_id);if not goal and not obs.terminal then return false,why end
    pause_watchdogs(t-(state.stopped_at or t),t)
    state.state=point.state;state.waiting_for=point.waiting_for
    if point.state=='searching' then
      state.state='waiting';state.waiting_for='search_ready'
    end
    state.resume_point=nil;state.stopped_at=nil;state.active=true;state.reason=nil;state.detail=nil
    state.resumes=(state.resumes or 0)+1
    if not checked_log('session_resumed',{resumes=state.resumes,runs_started=state.runs_started,
      actions=state.actions,pending_action=state.pending_action~=nil,gold_progress=state.gold_progress,
      restart_cancelled_search=point.state=='searching',
      new_search_authorization=point.state=='searching' and 'Explicit Resume requests a new bounded search after the old request drained; no old allocation is refunded.' or nil,
      limits_preserved=true,scope='Same session; user interaction may have changed its continuation.'}) then return false,state.reason end
    if goal=='complete' and not state.config.teacher_batch and not obs.terminal then stop('collection_complete',nil,true) end
    return true -- Only a later fresh tick may dispatch an action or a search.
  end
  function api.halt(reason)
    clock();stop(reason or 'product_unavailable')
    state.resume_point=nil
  end
  function api.engaged() return state.active or state.search_pending or state.resume_point~=nil end
  function api.check_limits()
    local t=clock();if not t then return false end
    if state.config and state.session_started_at and t-state.session_started_at>=state.config.session_seconds then
      stop('session_time_limit');return false
    end
    if state.config and state.run_started_at and not state.run_finalized and t-state.run_started_at>=state.config.run_seconds then
      stop('run_time_limit');return false
    end
    return true
  end
  -- Only the product's verified checkpoint-loaded notification may call this.
  -- The restored timeline is an explicit manual continuation, not a new attempt
  -- or proof of equivalent hidden RNG. Existing action/run/session caps remain.
  function api.continue_checkpoint()
    if not state.binding or not state.run_id or state.run_finalized or state.search_pending or
      not (state.active or state.resume_point) then return false,'No in-progress run can adopt this checkpoint.' end
    local t=clock();if not t then return false,state.reason end
    if t-state.session_started_at>=state.config.session_seconds or
      state.run_started_at and t-state.run_started_at>=state.config.run_seconds then
      stop('continuation_time_limit','The original session or run time limit is exhausted.');return false,state.reason
    end
    local obs=observe();if not obs then return false,state.reason end
    local b,why=binding(obs);if not b then return false,why end
    for k,v in pairs(state.binding) do if b[k]~=v then return false,'The session context changed: '..k end end
    if not id(obs.run_id) or not ready(obs) then return false,'Wait for fresh advice for the restored state.' end
    local goal;goal,why=goal_status(obs.goal,b.profile_id);if not goal then return false,why end
    local previous=state.run_id
    if not checked_log('manual_checkpoint_continuation',{previous_run_id=previous,restored_run_id=obs.run_id,
      interrupted_action=state.pending_action,scope='Manual restoration; previous action completion is unknown; counters and limits retained.'}) then return false,state.reason end
    state.run_id=obs.run_id;state.pending_action=nil;state.progress_at=t;state.progress_fingerprint=nil
    state.manual_continuations=(state.manual_continuations or 0)+1
    if state.active then state.state='playing';state.waiting_for=nil
    else state.resume_point={state='playing'} end
    return true
  end
  function api.status()
    return clone({schema=1,state=state.state,active=state.active,busy=state.active or state.search_pending,
      complete=state.complete,reason=state.reason,detail=state.detail,waiting_for=state.waiting_for,
      input_wait=state.input_wait==true,resume_available=state.resume_point~=nil,
      resumes=state.resumes,manual_continuations=state.manual_continuations,session_serial=state.session_serial,
      search_draining=state.search_pending and not state.active,cancel_requested=state.cancel_requested,
      cancel_error=state.cancel_error,log_error=state.log_error,search_id=state.search_id,
      runs_started=state.runs_started,max_runs=state.config and state.config.max_runs,
      start_attempts=state.start_attempts,uncertain_starts=state.uncertain_starts,
      start_allowances_used=start_allowances_used(),
      run_limit_reached=state.config~=nil and start_allowances_used()>=state.config.max_runs,
      actions=state.actions,run_actions=state.run_actions,
      teacher_batch=state.config and state.config.teacher_batch or false,
      retire_unsupported=state.config and state.config.retire_unsupported or false,
      abandonment_pending=state.abandon_pending~=nil,last_abandonment=state.last_abandonment,
      outcomes=state.outcomes,gold_progress=state.gold_progress,last_gold_award=state.last_gold_award,
      profile_id=state.binding and state.binding.profile_id,run_id=state.run_id,
      session_started_at=state.session_started_at,search_deadline=state.search_deadline,
      pending_action=state.pending_action~=nil})
  end
  -- Both collection and teacher sessions acknowledge the same exact action
  -- transition. Their different retirement/timeout ordering remains in tick.
  local function acknowledge_pending(obs,t)
    local prior=state.pending_action
    local changed=type(obs.fingerprint)=='string' and obs.fingerprint~='' and obs.fingerprint~=prior.fingerprint
    if not changed or not ready(obs) or obs.advice_fingerprint~=obs.fingerprint then return false end
    if not checked_log('action_observed',{before=prior.fingerprint,after=obs.fingerprint,
        action_token=prior.action_token}) then return nil end
    state.pending_action=nil;state.state='playing';state.waiting_for=nil;state.progress_at=t
    return true
  end
  local function tick()
    if not state.active then
      if state.search_pending then poll_search(state.last_time,true) end
      return api.status()
    end
    local t=clock();if not t then return api.status() end
    local obs=observe();if not obs then return api.status() end
    if not check_observation(obs) then return api.status() end
    local holding_input=input_wait(obs,t)
    local goal,goal_reason=goal_status(obs.goal,state.binding.profile_id)
    if state.run_id and not state.run_finalized and obs.run_id==state.run_id and state.state~='terminal' and terminal(obs,t) then return api.status() end
    if t-state.session_started_at>=state.config.session_seconds then stop('session_time_limit');return api.status() end
    if state.run_started_at and not state.run_finalized and t-state.run_started_at>=state.config.run_seconds then
      stop('run_time_limit');return api.status()
    end
    if state.search_pending then
      if not goal then stop('goal_unavailable',goal_reason);return api.status() end
      if goal=='complete' and not state.config.teacher_batch then stop('collection_complete',nil,true);return api.status() end
      if t>=state.search_deadline then stop('search_timeout');return api.status() end
      poll_search(t,false);return api.status()
    end
    if holding_input then return api.status() end
    if obs.search_busy then stop('external_search_active');return api.status() end
    if state.state=='waiting' and state.waiting_for=='search_ready' then
      if ready(obs) and obs.transition_ready==true then begin_search(obs,t)
      else stalled(t,'search_not_ready') end
      return api.status()
    end
    if state.state=='waiting' and state.waiting_for=='start_ready' then
      if not goal then stop('goal_unavailable',goal_reason)
      elseif goal=='complete' and not state.config.teacher_batch then stop('collection_complete',nil,true)
      else begin_run(obs,t) end
      return api.status()
    end
    if state.state=='starting' then
      if state.expected_run_id and obs.run_id~=state.expected_run_id then stop('run_changed','The already-started run was replaced.');return api.status() end
      if id(obs.run_id) and obs.run_id~=state.previous_run_id and ready(obs) then
        state.run_id=obs.run_id;state.state='playing';state.progress_at=t
        if not checked_log('run_started',{run_number=state.runs_started}) then return api.status() end
      else
        stalled(t,'run_start_stalled')
        if state.config.retire_runs and state.active then maybe_abandon(obs,t) end
        return api.status()
      end
    end
    if obs.run_id~=state.run_id then stop('run_changed','The active run was replaced outside this controller.');return api.status() end
    if state.state=='terminal' or state.state=='abandoned' then
      -- This is a different observe() call from the terminal receipt. The
      -- adapter must reread loaded sticker metadata each time, never cache it.
      if not goal then stop('goal_unavailable',goal_reason)
      elseif goal=='complete' and not state.config.teacher_batch then stop('collection_complete',nil,true)
      elseif start_allowances_used()>=state.config.max_runs then stop('run_limit')
      elseif ready(obs) and obs.transition_ready==true then begin_search(obs,t)
      else stalled(t,'terminal_transition_stalled') end
      return api.status()
    end
    if terminal(obs,t) then return api.status() end
    if not goal then stop('goal_unavailable',goal_reason);return api.status() end
    if t-state.run_started_at>=state.config.run_seconds then stop('run_time_limit');return api.status() end
    -- Collection retirement cannot turn an unobserved execution into a new run.
    -- Settle its existing receipt before considering a fresh unsupported result.
    if state.config.retire_unsupported and not state.config.teacher_batch and state.pending_action then
      local observed=acknowledge_pending(obs,t)
      if observed==nil then return api.status() end
      if not observed then
        state.state='waiting';state.waiting_for='action_observation'
        if t-state.pending_action.time>=state.config.stall_seconds then stop('action_observation_stalled') end
        return api.status()
      end
    end
    progress(obs,t)
    if not state.active then return api.status() end
    if state.config.retire_runs then
      if ready(obs) and (obs.decision_state=='unsupported' or obs.decision_state=='no_decision') then
        request_abandon('unsupported',obs.decision_state,obs.decision_reason)
      elseif ready(obs) and obs.decision_state=='error' then
        if state.config.teacher_batch then request_abandon('error','decision_error',obs.decision_reason)
        else stop('decision_error',obs.decision_reason);return api.status() end
      end
      if t-(state.semantic_at or t)>=state.config.stall_seconds then
        request_abandon('abandoned_stall','semantic_progress_stalled')
      end
      if maybe_abandon(obs,t) then return api.status() end
    end
    if state.pending_action then
      local observed=acknowledge_pending(obs,t)
      if observed==nil then return api.status() end
      if not observed then
        state.state='waiting';state.waiting_for='action_observation'
        if t-state.pending_action.time>=state.config.stall_seconds then
          if state.config.teacher_batch then request_abandon('abandoned_stall','action_observation_stalled')
          else stop('action_observation_stalled') end
        end
        return api.status()
      end
    end
    if not ready(obs) or type(obs.fingerprint)~='string' or obs.fingerprint=='' or obs.advice_fingerprint~=obs.fingerprint or
        not id(obs.action_token) then
      state.state='waiting';state.waiting_for=obs.unsupported and 'unsupported' or 'fresh_advice'
      stalled(t,obs.unsupported and 'unsupported_stalled' or 'advisor_stalled');return api.status()
    end
    if state.run_actions>=state.config.max_actions then stop('action_limit');return api.status() end
    local ok,allowed,why=pcall(cb.can_execute,obs.fingerprint,obs.action_token)
    if not ok then
      if state.config.teacher_batch then request_abandon('error','execution_check_failed',tostring(allowed))
      else stop('execution_check_failed',tostring(allowed)) end
      return api.status()
    end
    if not state.active then return api.status() end
    if allowed~=true then
      state.state='waiting';state.waiting_for='executable_action';state.detail=why
      stalled(t,'no_executable_action');return api.status()
    end
    -- Consume the attempt before entering the callback. Even a thrown or
    -- rejected Execute is never silently retried from the same public state.
    state.pending_action={fingerprint=obs.fingerprint,action_token=obs.action_token,time=t}
    state.actions=state.actions+1;state.run_actions=state.run_actions+1
    state.state='waiting';state.waiting_for='action_observation'
    if not checked_log('action_attempt',{fingerprint=obs.fingerprint,action_token=obs.action_token,
      action=obs.action,advice=obs.advice,run_action=state.run_actions}) then return api.status() end
    if state.config.teacher_batch then
      state.last_action=clone({action=obs.action,advice=obs.advice,action_token=obs.action_token,
        time=t,run_action=state.run_actions,callback_status='pending'})
      if not state.active then return api.status() end
    end
    local called,accepted,detail=pcall(cb.execute,obs.fingerprint,obs.action_token)
    if state.config.teacher_batch then
      state.last_action.callback_status=called and (accepted==true and 'accepted' or 'rejected') or 'error'
      state.last_action.callback_reason=called and detail or tostring(accepted)
      if not checked_log('action_callback_returned',{last_action=state.last_action,
        scope='Callback result only; semantic action completion still requires a fresh observation.'}) then return api.status() end
      if not called or accepted~=true then request_abandon('error','execute_failed',called and detail or tostring(accepted)) end
    elseif not called or accepted~=true then stop('execute_failed',called and detail or tostring(accepted)) end
    return api.status()
  end
  local stepping=false
  function api.tick()
    if stepping then return api.status() end
    stepping=true
    local ok,result=pcall(tick)
    stepping=false
    if not ok then stop('controller_error',tostring(result));return api.status() end
    return result
  end
  return api
end
return M
