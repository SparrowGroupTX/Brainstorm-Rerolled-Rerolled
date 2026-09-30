-- Manufactured controller contracts only: no source engine, files, or real games.
local Auto=dofile('Brainstorm/Advisor/auto_run.lua')
local checks=0
local function check(v,label) checks=checks+1;if not v then error(debug.traceback(label,2),0) end end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function harness()
  local h={time=0,logs={},starts=0,searches=0,executes=0,abandons=0,allowed=true}
  h.obs={profile_id=1,consent_generation=1,settings_generation=0,checkpoint_generation=0,manual_generation=0,
    ready=true,transition_ready=true,goal={schema=1,goal='gold_stickers',profile_id=1,
      metadata_status='complete',catalog_status='complete',stake_status='complete',
      counts={total=150,complete=149,missing=1,unknown=0},by_key={}}}
  local callbacks={now=function() return h.time end,observe=function() return h.obs end,
    log=function(e) h.logs[#h.logs+1]=e;return h.log_failure~=e.event end,
    search_start=function(r) h.searches=h.searches+1;h.request=r;return true end,
    search_poll=function(id) return h.poll or {request_id=id,exited=false,status='running'} end,
    search_cancel=function() return true end,
    start_run=function()
      h.starts=h.starts+1;h.obs.run_id='run:'..h.starts;h.obs.ready=false;h.obs.transition_ready=false
      h.obs.terminal=nil;h.obs.fingerprint=nil;h.obs.semantic_fingerprint=nil;h.obs.decision_state=nil
      if h.stop_then_throw_start then h.auto.stop('user_stop');error('manufactured callback failed after launch') end
      if h.throw_after_start then error('manufactured callback failed after launch') end
      if h.reject_after_start then return false,'manufactured terminal binding failure after launch' end
      return true,nil,not h.missing_start_id and h.obs.run_id or nil
    end,
    can_execute=function() if h.check_error then error('manufactured gate error') end;return h.allowed end,
    execute=function()
      h.executes=h.executes+1
      if h.execute_error then error('manufactured execution error') end
      if h.stop_in_execute then h.auto.stop('user_stop') end
      return h.execute_reject~=true
    end,
    abandon_run=function(reason,context)
      h.abandons=h.abandons+1;h.abandon_context=context;h.abandon_reason=reason
      if h.stop_in_abandon then h.auto.stop('user_stop') end
      if h.abandon_error then error('manufactured retirement error') end
      if h.abandon_reject then return false,'manufactured rejection' end
      h.obs.transition_ready=true
      return true,nil,h.receipt or {verified=true,run_id=h.obs.run_id,event_id='retired:'..h.starts}
    end}
  h.callbacks=callbacks;h.auto=Auto.new(callbacks)
  function h.start(options)
    options=options or {};options.retire_unsupported=true;options.teacher_batch=false;options.max_runs=options.max_runs or 10
    local ok,why=h.auto.start(options);check(ok,'teacher start accepted: '..tostring(why))
    h.auto.tick();eq(h.searches,1,'search dispatched on fresh tick')
  end
  function h.launch()
    h.poll={request_id=h.request.request_id,exited=true,status='found',found={seed='FIXTURE',source='manufactured'}}
    h.auto.tick();h.poll=nil;eq(h.auto.status().waiting_for,'start_ready','found result awaits next observation')
    h.auto.tick();eq(h.auto.status().runs_started,h.starts,'accepted starts counted before first decision')
  end
  function h.ready(token,semantic)
    h.obs.ready=true;h.obs.advisor_busy=false;h.obs.action_pending=false;h.obs.abandon_ready=true
    h.obs.fingerprint=token or 'public:1';h.obs.semantic_fingerprint=semantic or token or 'semantic:1'
    h.obs.advice_fingerprint=h.obs.fingerprint;h.obs.action_token='action:'..h.obs.fingerprint
    h.obs.action={kind='discard',indices={1,2,3,4,5}};h.obs.advice={title='Grow Yorick safely'}
  end
  function h.play(options) h.start(options);h.launch();h.ready();h.auto.tick() end
  function h.terminal(kind)
    h.obs.terminal={kind=kind,verified=true,source=kind=='win' and 'original_win_callback' or 'GAME_OVER',
      run_id=h.obs.run_id,event_id='terminal:'..h.starts};h.auto.tick()
  end
  function h.events(kind)
    local count=0;for _,e in ipairs(h.logs) do if e.event==kind then count=count+1 end end;return count
  end
  return h
end

-- The harness uses only manufactured callback receipts, never real game execution.
do
 local h=harness();h.start()
 for run=1,10 do
  h.launch();h.ready('state:'..run);h.obs.action=nil;h.obs.decision_state='unsupported'
  h.auto.tick();local s=h.auto.status()
  eq(h.starts,run,'Retirement never relaunches in the same tick')
  eq(s.outcomes.unsupported,run,'Each unsupported start has its own outcome')
  eq(s.outcomes.losses,0,'Unsupported is not a loss');check(not s.teacher_batch,'Collection objective retained')
  check(s.retire_unsupported,'Retirement consent is explicit in status')
  h.auto.tick()
 end
 eq(h.auto.status().reason,'run_limit','Ten actual starts exhaust the budget')
 eq(h.searches,10,'No eleventh search');eq(h.starts,10,'No eleventh launch')
 check(not h.auto.resume(),'Resume cannot renew consumed starts')
end
do
 local h=harness();h.start();h.launch();h.ready();h.obs.decision_state='unsupported';h.obs.action=nil
 h.obs.abandon_ready=false;h.auto.tick();eq(h.abandons,0,'Unsettled game cannot retire')
 h.auto.stop('user_stop');h.obs.abandon_ready=true;h.auto.tick();eq(h.abandons,0,'Stop blocks queued retirement')
 check(h.auto.resume(),'Explicit resume keeps original session');h.auto.tick()
 eq(h.abandons,1,'Pending retirement resumes safely');eq(h.auto.status().runs_started,1,'Resume retains count')
end
do
 local h=harness();h.start();h.launch();h.ready();h.obs.action=nil;h.obs.decision_state='unsupported';h.obs.abandon_ready=false
 h.auto.tick();h.terminal('loss');eq(h.auto.status().outcomes.losses,1,'Actual terminal precedes pending retirement')
 eq(h.abandons,0,'No double-counted retirement')
end
do
 local h=harness();h.start();h.launch();h.ready();h.obs.action=nil;h.obs.action_token=nil
 h.auto.tick();h.time=30;h.auto.tick();eq(h.abandons,1,'No-advice semantic stall retires safely')
 eq(h.auto.status().outcomes.abandoned_stall,1,'Stall accounted separately')
end
for _,mode in ipairs({'execute','log','receipt','decision','launch'})do
 local h=harness();h.start({max_runs=1})
 if mode=='launch' then h.throw_after_start=true;h.poll={request_id=h.request.request_id,exited=true,status='found',found={seed='FIXTURE'}};h.auto.tick();h.poll=nil;h.auto.tick();eq(h.auto.status().start_attempts,1,'Uncertain start consumes allowance')
 else
  h.launch();h.ready()
  if mode=='execute' then h.execute_error=true
  elseif mode=='log' then h.log_failure='run_abandon_requested';h.obs.decision_state='unsupported';h.obs.action=nil
  elseif mode=='receipt' then h.receipt={verified=false};h.obs.decision_state='unsupported';h.obs.action=nil
  else h.obs.decision_state='error';h.obs.action=nil end
  h.auto.tick()
 end
 check(not h.auto.status().active,'Hard failure stops: '..mode)
 h.auto.tick();eq(h.starts,1,'Hard failure cannot launch another run: '..mode)
end

do
 local h=harness();h.play();h.obs.action=nil;h.obs.decision_state='unsupported'
 h.auto.tick();eq(h.abandons,0,'Same-state unsupported cannot hide unobserved execution')
 h.time=30;h.auto.tick();eq(h.auto.status().reason,'action_observation_stalled','Uncertain execution remains a hard stop')
 eq(h.abandons,0,'No retirement of uncertain execution')
 h=harness();h.play();h.ready('settled:new');h.obs.action=nil;h.obs.decision_state='unsupported';h.auto.tick()
 eq(h.events('action_observed'),1,'Settled action receipt is recorded before retirement')
 eq(h.abandons,1,'Fresh settled unsupported result may retire')
end
print('advisor_collection_marathon364: '..checks..' checks passed')
