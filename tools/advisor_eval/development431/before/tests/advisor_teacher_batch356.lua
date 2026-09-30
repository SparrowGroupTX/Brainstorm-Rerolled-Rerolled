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
      counts={total=150,complete=150,missing=0,unknown=0},by_key={}}}
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
    options=options or {};options.teacher_batch=true
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
math.random=function() error('teacher controller must not use RNG') end

do
  local h=harness();h.callbacks.abandon_run=nil;local controller=Auto.new(h.callbacks)
  check(not controller.start({teacher_batch=true}),'teacher mode requires safe product retirement')
  h=harness();check(not h.auto.start({teacher_batch=true,max_runs=11}),'teacher cannot exceed ten starts')
  check(not h.auto.start({teacher_batch=true,stall_seconds=29}),'teacher watchdog is exactly thirty seconds')
  h.start();eq(h.auto.status().max_runs,10,'teacher default is ten actual starts')
  eq(h.auto.status().outcomes.wins,0,'complete collection metadata does not fabricate teacher wins')
  h.missing_start_id=true;h.launch()
  eq(h.auto.status().reason,'run_start_identity_unavailable','unbound accepted start cannot proceed')
  eq(h.auto.status().runs_started,1,'uncertain start identity cannot refund the actual start')
  for _,failure in ipairs({'throw_after_start','reject_after_start','stop_then_throw_start'}) do
    h=harness();h.start({max_runs=1});h[failure]=true
    h.poll={request_id=h.request.request_id,exited=true,status='found',found={seed='FIXTURE'}}
    h.auto.tick();h.poll=nil;h.auto.tick()
    local s=h.auto.status()
    eq(h.starts,1,'manufactured callback actually changed run before failure: '..failure)
    eq(s.runs_started,0,'unconfirmed callback cannot count as a confirmed launch: '..failure)
    eq(s.start_attempts,1,'dispatch consumes a start allowance before callback: '..failure)
    eq(s.uncertain_starts,1,'post-launch uncertainty is explicit: '..failure)
    check(s.run_limit_reached,'uncertain launch cannot renew its one-use slot: '..failure)
    eq(s.reason,'run_start_uncertain','uncertain start closes session: '..failure)
    check(not h.auto.resume(),'uncertain start cannot Resume into another launch: '..failure)
    h.auto.tick();eq(h.starts,1,'uncertain start remains closed: '..failure)
    eq(s.outcomes.losses,0,'uncertain launch is not a loss: '..failure)
  end
end

do
  local h=harness();h.start()
  for run=1,10 do
    h.launch();h.ready('state:'..run);h.auto.tick()
    local outcome=run%5
    if outcome==1 then h.terminal('win')
    elseif outcome==2 then h.terminal('loss')
    elseif outcome==3 then h.time=h.time+30;h.auto.tick()
    elseif outcome==4 then h.obs.decision_state='no_decision';h.auto.tick()
    else h.obs.decision_state='error';h.auto.tick() end
    eq(h.starts,run,'a terminal/retirement callback never launches a same-tick replacement')
    h.obs.transition_ready=true;h.auto.tick()
    if run<10 then eq(h.searches,run+1,'later fresh tick requests next owned search') end
  end
  local s=h.auto.status();eq(s.reason,'run_limit','batch stops after all ten actual starts')
  eq(h.searches,10,'no eleventh search');eq(h.starts,10,'no eleventh run')
  eq(s.outcomes.wins,2,'two verified wins');eq(s.outcomes.losses,2,'two verified losses')
  eq(s.outcomes.abandoned_stall,2,'stalls are independent outcomes')
  eq(s.outcomes.unsupported,2,'no-decision outcomes are unsupported')
  eq(s.outcomes.error,2,'decision errors are independent outcomes')
  eq(h.events('run_finished'),4,'only actual terminals emit run_finished')
  eq(h.events('run_abandoned'),6,'abandonments have their own event family')
  check(not h.auto.resume(),'run limit cannot be renewed by Resume')
end

do
  local h=harness();h.play();h.obs.ready=false;h.obs.advisor_busy=true;h.obs.semantic_fingerprint=nil
  h.obs.decision_state='unsupported';h.time=1;h.auto.tick()
  check(not h.auto.status().abandonment_pending,'busy omission of snapshot and stale decision label are not errors')
  h.time=30;h.auto.tick();check(h.auto.status().abandonment_pending,'stall can wait for safe retirement')
  eq(h.abandons,0,'busy worker cannot be retired');eq(h.auto.status().outcomes.error,0,'missing busy snapshot is not error')
  h.ready('new:state');h.obs.decision_state=nil;h.auto.tick()
  eq(h.abandons,1,'queued stall retires only when the product becomes safely ready')
  eq(h.abandon_context.outcome,'abandoned_stall','pending cause retained')
  eq(h.auto.status().outcomes.losses,0,'retirement is never imputed to loss')
  eq(h.executes,1,'pending retirement cannot execute fresh advice')
end

do
  local h=harness();h.play();h.obs.ready=false;h.time=30;h.auto.tick()
  h.terminal('win');eq(h.auto.status().outcomes.wins,1,'verified terminal outranks pending abandonment')
  eq(h.abandons,0,'terminal game is not retired');check(not h.auto.status().abandonment_pending,'terminal clears queued retirement')
  h=harness();h.start();h.launch();h.time=30;h.auto.tick()
  check(h.auto.status().active and h.auto.status().abandonment_pending,'unsettled startup remains a counted pending stall')
  h.terminal('loss');eq(h.auto.status().outcomes.losses,1,'startup terminal binds to accepted launch identity')
  h=harness();h.start();h.launch();h.time=30;h.auto.tick();h.ready();h.auto.tick()
  eq(h.auto.status().outcomes.abandoned_stall,1,'startup stall retires safely when it settles')
  eq(h.starts,1,'startup retirement cannot refund its start')
end

do
  local h=harness();h.allowed=false;h.play()
  h.time=10;h.ready('noise:2','semantic:1');h.auto.tick()
  h.time=20;h.ready('noise:3','semantic:1');h.auto.tick()
  h.time=30;h.ready('noise:4','semantic:1');h.auto.tick()
  eq(h.abandons,1,'changing advice metadata cannot renew the semantic watchdog')
  h=harness();h.allowed=false;h.play()
  h.time=10;h.ready('state:2','semantic:2');h.auto.tick()
  h.time=20;h.ready('state:3','semantic:1');h.auto.tick()
  h.time=39;h.ready('state:4','semantic:2');h.auto.tick();eq(h.abandons,0,'new semantic state earns thirty seconds')
  h.time=40;h.auto.tick();eq(h.abandons,1,'oscillation through already-seen states cannot renew progress')
  h=harness();h.allowed=false;h.play()
  for i=1,600 do h.time=i;h.ready('manual:state:'..i);h.auto.tick() end
  check(h.auto.status().active,'many distinct manual/phase updates can exceed the automatic action allowance in public-state count')
  eq(h.abandons,0,'more than five hundred public states do not falsely exhaust semantic tracking')
end

do
  local h=harness();h.play();h.time=20;h.obs.paused=true;h.auto.tick()
  h.time=100;h.auto.tick();eq(h.abandons,0,'explicit pause suspends inactivity retirement')
  h.obs.paused=false;h.time=101;h.auto.tick();h.time=110;h.auto.tick();eq(h.abandons,0,'paused time is excluded')
  h.time=111;h.auto.tick();eq(h.abandons,1,'original remaining active-time allowance is preserved')
  h=harness();h.play({max_runs=1});h.time=10;h.auto.stop();h.time=100;check(h.auto.resume(),'explicit Resume accepts same attempt')
  h.time=119;h.auto.tick();eq(h.abandons,0,'Stop excludes inactivity time without adding an attempt')
  h.time=120;h.auto.tick();eq(h.abandons,1,'Resume preserves pending action inactivity elapsed')
  h.auto.tick();eq(h.auto.status().reason,'run_limit','Resume preserves run cap')
end

do
  for _,kind in ipairs({'abandon_error','abandon_reject','receipt'}) do
    local h=harness();h.play();h[kind]=kind=='receipt' and {verified=false,run_id='run:1',event_id='bad'} or true
    h.time=30;local s=h.auto.tick();check(not s.active,'uncertain or unverified retirement stops: '..kind)
    eq(s.outcomes.abandoned_stall,0,'unverified retirement grants no outcome: '..kind)
    h.auto.tick();eq(h.abandons,1,'uncertain retirement is not silently retried: '..kind)
  end
  local h=harness();h.play();h.log_failure='run_abandon_requested';h.time=30;h.auto.tick()
  eq(h.abandons,0,'log failure prevents retirement callback');eq(h.auto.status().reason,'log_unavailable','log failure remains authoritative')
  h=harness();h.play();h.stop_in_abandon=true;h.time=30;local s=h.auto.tick()
  eq(s.reason,'user_stop','Stop inside verified retirement remains authoritative');check(not s.active,'callback cannot reactivate stopped controller')
  eq(s.outcomes.abandoned_stall,1,'verified retirement is still recorded after synchronous Stop')
  h.auto.tick();eq(h.searches,1,'Stop prevents replacement search')
  h=harness();h.play();h.receipt={verified=true,run_id='run:1',event_id='replayed'};h.time=30;h.auto.tick()
  h.auto.tick();h.launch();h.ready('second');h.auto.tick()
  h.receipt={verified=true,run_id='run:2',event_id='replayed'};h.time=60;h.auto.tick()
  eq(h.auto.status().reason,'abandon_unverified','retirement event identities cannot be replayed in another run')
  eq(h.auto.status().outcomes.abandoned_stall,1,'replayed retirement grants no second outcome')
end

do
  for _,kind in ipairs({'execute_error','execute_reject','check_error'}) do
    local h=harness();h[kind]=true;h.play();check(h.auto.status().abandonment_pending,'decision execution error queues safe retirement: '..kind)
    h.auto.tick();eq(h.auto.status().outcomes.error,1,'decision execution error retained: '..kind)
    eq(h.auto.status().outcomes.losses,0,'execution failure is not a gameplay loss: '..kind)
  end
  local h=harness();h.play();h.obs.semantic_fingerprint=nil;h.auto.tick()
  eq(h.auto.status().outcomes.error,1,'settled missing semantic projection explicitly retires as error')
  h=harness();h.allowed=false;h.play();h.time=100;h.terminal('loss');h.obs.transition_ready=false;h.obs.ready=false
  h.time=129;check(h.auto.tick().active,'terminal transition uses its own receipt time')
  h.time=130;eq(h.auto.tick().reason,'terminal_transition_stalled','terminal transition wait remains bounded')
  h=harness();check(h.auto.start({teacher_batch=true}),'menu preparation begins');h.obs.ready=false;h.time=30
  eq(h.auto.tick().reason,'search_not_ready','pre-run wait is bounded without a semantic snapshot')
  h=harness();h.play({max_actions=1});h.ready('second:state');h.auto.tick()
  eq(h.auto.status().reason,'action_limit','teacher retains original per-run action cap')
  eq(h.executes,1,'teacher cannot execute above its action cap')
  h=harness();h.play({session_seconds=30});h.time=30;h.terminal('loss')
  eq(h.auto.status().outcomes.losses,1,'verified terminal at teacher session deadline takes priority')
  h.auto.tick();eq(h.auto.status().reason,'session_time_limit','terminal accounting cannot renew session time')
end
do
  local h=harness();h.start()
  for run=1,10 do
    h.launch();h.ready('loss-only:'..run);h.auto.tick();h.terminal('loss')
    h.obs.transition_ready=true;h.auto.tick()
  end
  local s=h.auto.status()
  eq(s.reason,'run_limit','ten losses complete ten-run batch')
  eq(s.outcomes.wins,0,'no win needed to finish batch')
  eq(s.outcomes.losses,10,'all ten losses counted')
  eq(h.starts,10,'zero wins never grant an eleventh start')
  eq(h.searches,10,'zero wins never grant an eleventh search')
end
print('advisor_teacher_batch356: '..checks..' checks passed')
