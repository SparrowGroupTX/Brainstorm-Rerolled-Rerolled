local Auto=dofile('Brainstorm/Advisor/auto_run.lua')
local checks=0
local function check(v,label) checks=checks+1;if not v then error(debug.traceback(label,2),0)end end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function goal(missing,unknown)
  return {schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=150-(missing or 5)-(unknown or 0),missing=missing or 5,unknown=unknown or 0},
    by_key={j_yorick={status='missing'}},targets={{key='j_yorick',status='missing'}}}
end
local function harness()
  local h={time=0,logs={},searches=0,starts=0,cancels=0,executions=0,observes=0,polls=0,allowed=true,
    obs={profile_id=1,consent_generation=1,settings_generation=0,checkpoint_generation=0,manual_generation=0,
      ready=true,transition_ready=true,goal=goal(),fingerprint='menu',advice_fingerprint='menu',action_token='initial'}}
  local callbacks={
    now=function() return h.time end,
    observe=function() h.observes=h.observes+1;return h.obs end,
    log=function(e) h.logs[#h.logs+1]=e;if h.log_failure==e.event then return false end end,
    search_start=function(request)
      h.searches=h.searches+1;h.request=request
      if h.search_throw then error('search may have started') end
      return h.search_accept~=false
    end,
    search_poll=function(request_id)
      h.polls=h.polls+1;h.polled_id=request_id
      if h.poll_throw then error('poll failed') end
      if h.poll_time then h.time=h.poll_time end
      return h.poll or {request_id=request_id,status='running',exited=false}
    end,
    search_cancel=function(request_id) h.cancels=h.cancels+1;h.cancelled_id=request_id;return true end,
    start_run=function(found,binding)
      h.starts=h.starts+1;h.found=found;h.start_binding=binding
      if h.start_throw then error('start may have happened') end
      if h.start_accept==false then return false end
      h.obs.run_id='run'..h.starts;h.obs.ready=false;h.obs.transition_ready=false;h.obs.terminal=nil
      h.obs.fingerprint=nil;h.obs.advice_fingerprint=nil;h.obs.action_token=nil
      if h.omit_started_id then return true end
      return true,nil,h.obs.run_id
    end,
    can_execute=function(fingerprint,token)
      h.checked_fingerprint=fingerprint;h.checked_token=token
      if h.check_throw then error('check failed') end
      if h.stop_during_check then h.controller.stop('manual_stop_in_gate') end
      return h.allowed,'not allowed yet'
    end,
    execute=function(fingerprint,token)
      h.executions=h.executions+1;h.executed_fingerprint=fingerprint;h.executed_token=token
      if h.reenter then h.controller.tick() end
      if h.execute_throw then error('callback may have begun') end
      return h.execute_accept~=false
    end,
  }
  h.controller=Auto.new(callbacks)
  function h.start(options)
    local ok,why=h.controller.start(options);check(ok,'explicit start accepted: '..tostring(why))
    h.controller.tick();eq(h.searches,1,'one initial search dispatched on next tick')
  end
  function h.found_search(seed)
    h.poll={request_id=h.request.request_id,status='found',exited=true,found={seed=seed or 'TEST1',source='synthetic_fixture'}}
    h.controller.tick();h.poll=nil
    eq(h.controller.status().waiting_for,'start_ready','found result waits for a fresh start-ready observation')
    h.controller.tick()
    eq(h.controller.status().state,'starting','one new run is requested')
  end
  function h.ready(fingerprint)
    h.obs.ready=true;h.obs.advisor_busy=false;h.obs.action_pending=false
    h.obs.fingerprint=fingerprint or 'hand1';h.obs.advice_fingerprint=h.obs.fingerprint
    h.obs.action_token='action:'..h.obs.fingerprint
    h.obs.action={kind='reorder_jokers',order={2,1}};h.obs.advice={title='Reorder before playing'}
  end
  function h.play(options)
    h.start(options);h.found_search();h.ready();h.controller.tick()
    eq(h.executions,1,'first settled run state executes exactly one action')
  end
  function h.finish(kind)
    h.obs.terminal={kind=kind,verified=true,source=kind=='win' and 'original_win_callback' or 'GAME_OVER',
      run_id=h.obs.run_id,event_id='terminal:'..h.obs.run_id,fixture=true}
    h.controller.tick()
    eq(h.controller.status().state,'terminal','verified outcome enters terminal state')
  end
  return h
end
math.random=function() error('auto-run used global RNG') end
pseudorandom=function() error('auto-run used game RNG') end

do
  local h=harness();h.controller.tick();h.controller.tick()
  eq(h.controller.status().state,'idle','construction and module load never resume a run')
  eq(h.observes,0,'idle controller performs no monitoring')
  eq(h.searches,0,'idle controller never starts a search')
  local options={search_request={deck='b_red',targets={'Yorick','Perkeo'}},max_runs=2}
  check(h.controller.start(options),'start is explicit')
  eq(h.searches,0,'start call itself performs no search or gameplay')
  options.search_request.targets[1]='Changed';options.max_runs=100
  h.controller.tick()
  eq(h.request.recipe.targets[1],'Yorick','session recipe was copied immutably')
  eq(h.request.budget_seconds,30,'default native work has a thirty-second actual budget')
  eq(h.request.deadline,30,'search receives the monotonic deadline')
  eq(h.request.goal.counts.missing,5,'request has the freshly observed missing set')
  check(not h.controller.start(),'a running session cannot be duplicated')
end

do
  local h=harness();h.play()
  for i=1,6 do h.time=i;h.controller.tick() end
  eq(h.executions,1,'no duplicate Execute while the state fingerprint is unchanged')
  h.obs.action_token='another proposal at same state';h.controller.tick()
  eq(h.executions,1,'a recalculated token cannot duplicate the pending physical action')
  h.obs.fingerprint='hand2';h.obs.advice_fingerprint='hand1';h.obs.advisor_busy=true;h.controller.tick()
  eq(h.executions,1,'changing fingerprint during calculation is not fresh executable advice')
  h.obs.advisor_busy=false;h.controller.tick();eq(h.executions,1,'old published advice still cannot execute')
  h.ready('hand2');h.controller.tick();eq(h.executions,2,'one new action is possible only after changed state and fresh advice')
  eq(h.executed_fingerprint,'hand2','the current fingerprint is passed to the real Execute gate')
  eq(h.executed_token,'action:hand2','the current action token is passed to the real Execute gate')
  local attempts,observed=0,0
  for _,event in ipairs(h.logs) do if event.event=='action_attempt' then attempts=attempts+1;check(event.advice.title,'advice is logged at action attempt')
    elseif event.event=='action_observed' then observed=observed+1 end end
  eq(attempts,2,'every attempted action is logged once');eq(observed,1,'observed state change is a separate receipt')
end

do
  local h=harness();h.start()
  h.time=29.9;h.controller.tick();eq(h.cancels,0,'search may continue strictly before its deadline')
  h.time=30;local status=h.controller.tick()
  eq(status.reason,'search_timeout','the actual deadline cancels even if estimates said it was cheap')
  eq(h.cancels,1,'one cancellation request')
  check(status.busy and status.search_draining,'cancelled search remains busy until actual worker exit')
  check(not h.controller.start(),'no new session while the cancelled worker is still running')
  h.controller.stop();h.controller.tick();eq(h.cancels,1,'repeated stop never duplicates cancellation')
  eq(h.cancelled_id,h.request.request_id,'only the owned search identity is cancelled')
  h.poll={request_id=h.request.request_id,status='found',exited=true,found={seed='TOO_LATE'}}
  status=h.controller.tick();check(not status.busy,'confirmed worker exit clears the busy state')
  eq(h.starts,0,'a late found result cannot start a run after cancellation')
  eq(status.state,'stopped','draining never resumes the stopped session')
end

do
  for _,field in ipairs({'profile_id','consent_generation','settings_generation','checkpoint_generation','manual_generation'}) do
    local h=harness();h.play();h.obs[field]=h.obs[field]+1
    local status=h.controller.tick();check(not status.active,'changed binding stops: '..field)
    eq(h.executions,1,'no subsequent action after '..field)
  end
  local h=harness();h.start();h.obs.manual_generation=1;h.controller.tick()
  eq(h.cancels,1,'manual activity also cancels an owned search')
  h=harness();h.play();h.obs.modal=true;check(h.controller.tick().active,'opening a menu keeps the controller active while waiting')
  h=harness();h.play();h.obs.paused=true;check(h.controller.tick().active,'game pause keeps the controller active while waiting')
  h=harness();h.play();h.obs.run_id='manual replacement';eq(h.controller.tick().reason,'run_changed','unreported replacement run is still detected')
end

do
  for _,mode in ipairs({'execute_throw','execute_accept','check_throw'}) do
    local h=harness();h.start();h.found_search();h.ready()
    if mode=='execute_accept' then h[mode]=false else h[mode]=true end
    local status=h.controller.tick();check(not status.active,'failed execution path stops: '..mode)
    local count=h.executions;h.controller.tick();h.controller.tick()
    eq(h.executions,count,'failed or uncertain action is never automatically repeated')
  end
  local h=harness();h.reenter=true;h.play();eq(h.executions,1,'reentrant update cannot execute a second action')
  h=harness();h.play();h.time=30;eq(h.controller.tick().reason,'action_observation_stalled','unchanged post-Execute state stops after thirty seconds')
end

do
  local h=harness();h.start();h.found_search();h.ready();h.allowed=false;h.controller.tick()
  h.time=30;eq(h.controller.tick().reason,'no_executable_action','lack of an executable action has a bounded wait')
  h=harness();h.start();h.found_search();h.ready();h.obs.advisor_busy=true;h.controller.tick()
  h.time=30;eq(h.controller.tick().reason,'run_start_stalled','startup cannot wait forever for a calculation')
  h=harness();h.play();h.ready('unsupported-state');h.obs.advice_fingerprint=nil;h.obs.unsupported=true;h.controller.tick()
  h.time=30;eq(h.controller.tick().reason,'action_observation_stalled','pending action stays guarded even if the resulting state is unsupported')
  h=harness();h.start();h.found_search();h.ready();h.obs.action_token=nil;h.obs.unsupported=true;h.controller.tick()
  h.time=30;eq(h.controller.tick().reason,'unsupported_stalled','unsupported fresh decisions have a bounded wait')
end

do
  local h=harness();h.play();h.obs.game_won=true;h.controller.tick()
  eq(h.controller.status().outcomes.wins,0,'a GAME.won-like field never establishes a win')
  h.obs.terminal={kind='win',verified=false,source='GAME.won',run_id='run1',event_id='bad'}
  eq(h.controller.tick().reason,'terminal_unverified','an unverified win is stopped and preserved')
  h=harness();h.play();h.finish('win')
  eq(h.controller.status().outcomes.wins,1,'only original callback evidence establishes the run win')
  for _=1,3 do h.controller.tick() end
  eq(h.controller.status().outcomes.wins,1,'the same terminal event is logged once')
  eq(h.searches,1,'no subsequent search before the terminal transition is ready')
  h.obs.goal=goal(4);h.obs.transition_ready=true;h.controller.tick()
  eq(h.searches,2,'the next search starts after a fresh post-outcome observation')
  eq(h.request.goal.counts.missing,4,'the updated missing set is reread for the next search')
  h=harness();h.play();h.finish('loss');eq(h.controller.status().outcomes.losses,1,'actual GAME_OVER loss is retained')
  h.obs.goal=goal(0);h.obs.transition_ready=true
  local complete=h.controller.tick();check(complete.complete and not complete.active,'zero missing and zero unknown completes the session')
  eq(h.searches,1,'complete collection starts no extra search')
  h=harness();h.obs.goal=goal(0,1);check(not h.controller.start(),'zero missing with unknown records is not completion')
  check(not h.controller.status().complete,'unknown collection remains incomplete')
  h=harness();h.play();h.obs.goal=goal(0,1);h.finish('win')
  eq(h.controller.status().outcomes.wins,1,'verified outcome is retained even if current collection metadata becomes unknown')
  eq(h.controller.tick().reason,'goal_unavailable','unknown metadata blocks only the subsequent continuation')
  check(not h.controller.status().complete,'an observed run win with unknown stickers is not achievement completion')
end

do
  local h=harness();h.play({max_actions=1});h.ready('second state')
  eq(h.controller.tick().reason,'action_limit','per-run action cap stops before another Execute')
  eq(h.executions,1,'only the permitted action executed')
  h=harness();h.play({run_seconds=1});h.time=1
  eq(h.controller.tick().reason,'run_time_limit','per-run actual time is bounded')
  h=harness();h.start({session_seconds=1});h.time=1
  eq(h.controller.tick().reason,'session_time_limit','session time includes search cost')
  eq(h.cancels,1,'session deadline cancels active search')
  h=harness();h.play({max_runs=1});h.finish('loss');h.obs.transition_ready=true
  eq(h.controller.tick().reason,'run_limit','session run limit prevents another search')
  h=harness();h.play();h.time=-1
  eq(h.controller.tick().reason,'clock_unavailable','backwards time fails closed')
end

do
  local h=harness();h.obs.goal.counts.complete=149;check(not h.controller.start(),'inconsistent count totals rejected')
  h=harness();h.obs.settings_generation=nil;check(not h.controller.start(),'missing change tracking prevents start')
  h=harness();h.obs.search_busy=true;check(not h.controller.start(),'an external worker prevents auto-run start')
  h=harness();h.obs.goal=goal(0);check(h.controller.start(),'already completed collection is detected at explicit start')
  check(h.controller.status().complete,'only fully known completed collection sets complete')
  eq(h.searches,0,'completed collection consumes no search')
  for _,options in ipairs({{search_seconds=31},{stall_seconds=31},{max_actions=501},{max_runs=101},{run_seconds=1801},{session_seconds=21601}}) do
    h=harness();check(not h.controller.start(options),'configured limit cannot exceed hard bound')
  end
  h=harness();local cycle={};cycle.self=cycle;check(not h.controller.start({search_request=cycle}),'cyclic recipe data rejected')
  h=harness();check(not h.controller.start({search_request={callback=function() end}}),'executable recipe data rejected')
end

do
  local h=harness();h.search_throw=true;h.start()
  local status=h.controller.status();eq(status.reason,'search_start_uncertain','uncertain dispatch is preserved')
  check(status.busy and status.search_draining,'possible launched worker remains owned until exit')
  eq(h.cancels,1,'uncertain dispatch requests cancellation once')
  h.poll={request_id=h.request.request_id,status='cancelled',exited=true};h.controller.tick()
  check(not h.controller.status().busy,'explicit worker exit resolves uncertainty')
  h=harness();h.search_accept=false;h.start()
  check(not h.controller.status().busy,'explicit no-worker rejection does not invent a draining worker')
  h=harness();h.log_failure='search_requested';check(h.controller.start(),'initial session log is accepted')
  h.controller.tick();eq(h.searches,0,'failed pre-dispatch log prevents the search')
  check(not h.controller.status().busy,'failed pre-dispatch log leaves no fictitious worker')
  h=harness();h.start();h.poll={request_id='different-worker',status='found',exited=true,found={seed='WRONG'}}
  eq(h.controller.tick().reason,'search_identity_changed','wrong worker result cannot start a run')
  eq(h.starts,0,'foreign result performs no start callback')
  eq(h.cancelled_id,h.request.request_id,'cancellation remains bound to this controller worker')
end
do
  local h=harness();h.play({max_runs=2});h.finish('loss');h.obs.transition_ready=true;h.obs.goal=goal(3)
  h.controller.tick();eq(h.searches,2,'second search follows a logged first outcome')
  h.found_search('SECOND');h.ready('run2-state1');h.controller.tick()
  eq(h.executions,2,'second run starts with exactly one fresh action')
  eq(h.controller.status().run_actions,1,'per-run action allowance resets only for an accepted new run')
  eq(h.controller.status().actions,2,'session action count spans both runs')
  h.finish('win');h.obs.transition_ready=true;h.obs.goal=goal(0);h.controller.tick()
  local status=h.controller.status()
  check(status.complete,'two-run session completes after fresh complete collection')
  eq(status.outcomes.losses,1,'first loss is preserved across subsequent win')
  eq(status.outcomes.wins,1,'one verified second-run win is counted')
  eq(status.runs_started,2,'only accepted start callbacks count as started runs')

  h=harness();h.start();h.start_throw=true
  h.poll={request_id=h.request.request_id,status='found',exited=true,found={seed='STARTFAIL'}}
  h.controller.tick();h.controller.tick();h.controller.tick()
  eq(h.starts,1,'uncertain startup is never repeated')
  eq(h.controller.status().reason,'run_start_uncertain','uncertain startup remains an explicit stopped outcome')
  eq(h.controller.status().runs_started,0,'uncertain startup is not claimed as an accepted start')

  h=harness();h.start();h.poll_throw=true;h.controller.tick()
  check(h.controller.status().search_draining,'poll failure retains the possibly active worker')
  eq(h.cancels,1,'poll failure cancels only once')
  h.controller.tick();check(h.controller.status().busy,'repeated poll failures do not pretend worker exit')
  h.poll_throw=false;h.poll={request_id=h.request.request_id,status='cancelled',exited=true};h.controller.tick()
  check(not h.controller.status().busy,'later verified exit releases failed poll ownership')

  h=harness();h.start();h.obs.goal=goal(0);h.controller.tick()
  check(h.controller.status().complete and h.controller.status().search_draining,'collection completion cancels an unnecessary active search')
  eq(h.cancels,1,'completed collection cancels owned search')
  h.poll={request_id=h.request.request_id,status='found',exited=true,found={seed='UNNEEDED'}};h.controller.tick()
  eq(h.starts,0,'a completed collection never starts a late found run')

  h=harness();h.start();h.time=29;h.poll_time=30
  h.poll={request_id=h.request.request_id,status='found',exited=true,found={seed='BOUNDARY'}}
  eq(h.controller.tick().reason,'search_timeout','deadline rechecked after poll closes the result race')
  eq(h.starts,0,'result arriving at the actual deadline cannot start a run')

  h=harness();h.start();h.found_search();h.ready();h.log_failure='action_attempt';h.controller.tick()
  eq(h.executions,0,'failed action log prevents the Execute callback')
  eq(h.controller.status().reason,'log_unavailable','unlogged action fails closed')
  h=harness();h.start();h.found_search();h.ready();h.stop_during_check=true;h.controller.tick()
  eq(h.executions,0,'manual stop inside the final gate prevents Execute')

  h=harness();h.play();h.obs.search_busy=true;h.ready('changed');h.controller.tick()
  eq(h.controller.status().reason,'external_search_active','external search activity stops further gameplay')
  eq(h.executions,1,'no action is executed while another search worker is active')

  h=harness();h.start();h.found_search();h.ready();h.allowed=false;h.controller.tick()
  for i=1,30 do h.time=i;h.ready('changing-without-action-'..i);h.controller.tick() end
  eq(h.controller.status().reason,'no_executable_action','changing public fields cannot renew a missing action allowance')
  eq(h.executions,0,'bounded missing-action wait never executes')

  h=harness();h.play();h.obs.terminal={kind='win',verified=true,source='original_win_callback',run_id='other-run',event_id='other'}
  eq(h.controller.tick().reason,'terminal_unverified','verified callback from another run cannot be reused')
  eq(h.controller.status().outcomes.wins,0,'foreign callback receives no win credit')
end
-- Explicit Stop retains the same session and consumed physical action. Resume
-- only arms that continuation; it never dispatches from the UI callback.
local function count_event(h,name)
  local n=0;for _,row in ipairs(h.logs)do if row.event==name then n=n+1 end end;return n
end
local function search_authorizations(h)
  local n=0;for _,row in ipairs(h.logs)do
    if row.event=='session_resumed' and row.restart_cancelled_search==true and type(row.new_search_authorization)=='string' then n=n+1 end
  end;return n
end
do
  local h=harness();h.play({max_runs=2,max_actions=3,run_seconds=300,session_seconds=500})
  local before=h.controller.status();h.time=10;check(h.controller.stop(),'explicit stop without native work finishes immediately')
  local paused=h.controller.status()
  check(not paused.active and paused.resume_available and paused.pending_action,'explicit stop keeps the pending action and resume point')
  eq(paused.session_serial,before.session_serial,'stop keeps the session identity')
  eq(paused.session_started_at,before.session_started_at,'stop keeps the absolute session origin')
  eq(paused.run_id,before.run_id,'stop keeps the actual run identity')
  h.time=99;h.controller.tick();eq(h.executions,1,'stopped updates never execute')
  check(h.controller.stop(),'repeated Stop is harmless');check(h.controller.status().resume_available,'repeated Stop does not erase the resume point')
  h.time=100;check(h.controller.resume(),'explicit Resume accepts the same settled session')
  local resumed=h.controller.status()
  eq(resumed.session_serial,before.session_serial,'Resume never starts a new session')
  eq(resumed.session_started_at,0,'Resume does not renew the session clock')
  eq(resumed.actions,1,'Resume keeps consumed action count');eq(resumed.run_actions,1,'Resume keeps per-run action count')
  eq(resumed.runs_started,1,'Resume does not increment started runs');eq(resumed.resumes,1,'Resume has a separate intervention count')
  eq(h.executions,1,'Resume itself never dispatches');eq(h.searches,1,'Resume does not search for an active run')
  h.controller.tick();eq(h.executions,1,'same pending physical action cannot repeat after Resume')
  h.time=119;check(h.controller.tick().active,'explicit stopped time is excluded from the pending-action watchdog')
  h.time=120;eq(h.controller.tick().reason,'action_observation_stalled','pre-stop active waiting time is retained')
  eq(count_event(h,'session_started'),1,'one session-start receipt spans Stop and Resume')
  eq(count_event(h,'session_resumed'),1,'Resume has one distinct logged receipt')
end
do
  local h=harness();h.play({max_actions=1});h.controller.stop();h.ready('user-changed-state')
  check(h.controller.resume(),'resuming does not preemptively dispatch a changed manual state')
  eq(h.executions,1,'changed state is not executed in Resume')
  eq(h.controller.tick().reason,'action_limit','fresh changed state cannot renew the original one-action cap')
  eq(count_event(h,'action_observed'),1,'changed state acknowledges the pending action once')
  check(not h.controller.resume(),'hard-cap stop has no resumable action allowance')
  for _,field in ipairs({'profile_id','consent_generation','settings_generation','checkpoint_generation','manual_generation'})do
    h=harness();h.play();h.controller.stop();h.obs[field]=h.obs[field]+1
    check(not h.controller.resume(),'Resume rejects changed context: '..field)
    eq(h.executions,1,'invalid Resume cannot dispatch: '..field)
  end
  h=harness();h.play();h.controller.stop();h.obs.run_id='foreign'
  check(not h.controller.resume(),'Resume rejects a replaced run')
  for _,field in ipairs({'modal','paused','input_busy','search_busy'})do
    h=harness();h.play();h.controller.stop();h.obs[field]=true
    check(not h.controller.resume(),'Resume waits for controls: '..field)
    eq(h.executions,1,'busy Resume never executes')
  end
  h=harness();h.play();h.controller.stop();h.obs.goal=goal(1,1)
  check(not h.controller.resume(),'Resume rejects unknown loaded collection metadata')
  h=harness();h.obs.goal=goal(0,1);h.obs.terminal={kind='win',verified=true,source='original_win_callback',run_id='foreign',event_id='unbound'}
  check(not h.controller.start(),'initial Start retains strict metadata admission despite an unbound terminal field')
  eq(h.searches,0,'unbound terminal data cannot authorize an initial search')
  h=harness();h.play();h.controller.stop();h.log_failure='session_resumed'
  check(not h.controller.resume(),'Resume receipt must be recorded before further work')
  eq(h.controller.status().reason,'log_unavailable','failed Resume logging is explicit')
  h.controller.tick();eq(h.executions,1,'failed Resume log cannot execute')
end
do
  for _,limit in ipairs({'run_seconds','session_seconds'})do
    local h=harness();h.play({[limit]=10});h.time=2;h.controller.stop();h.time=10
    check(not h.controller.resume(),'stopped time still consumes the absolute '..limit)
    eq(h.executions,1,'absolute time exhaustion cannot dispatch')
  end
  local h=harness();h.play();h.time=2;h.controller.stop();h.time=1
  check(not h.controller.resume(),'Resume requires a monotonic clock')
  eq(h.controller.status().reason,'clock_unavailable','backwards resumed clock fails closed')
end
do
  local h=harness();h.start({search_request={deck='Zodiac Deck',minimum_distinct=4},session_seconds=100})
  local original=h.request;h.time=5;check(not h.controller.stop(),'Stop retains ownership of a draining native worker')
  check(not h.controller.resume(),'Resume cannot overlap a cancelled worker')
  eq(h.searches,1,'draining Resume dispatches no replacement search')
  h.poll={request_id=original.request_id,exited=true,status='found',found={seed='LATE'}}
  h.time=10;h.controller.tick();eq(h.starts,0,'cancelled late found result is never adopted')
  check(h.controller.resume(),'explicit Resume after confirmed cancellation authorizes a distinct bounded request')
  eq(h.searches,1,'Resume does not dispatch a new worker immediately')
  h.controller.tick();eq(h.searches,2,'later fresh tick may dispatch the separately authorized replacement search')
  eq(h.request.deadline,40,'new explicit request has a distinct thirty-second deadline')
  eq(h.request.budget_seconds,30,'new request has its declared per-request cap without refunding prior work')
  eq(h.request.recipe.deck,'Zodiac Deck','resumed search preserves original deck options')
  eq(h.request.recipe.minimum_distinct,4,'resumed search preserves original quota')
  check(h.request.request_id~=original.request_id,'replacement has its own native ownership identity')
  h.time=12;h.controller.stop();h.poll={request_id=h.request.request_id,exited=true,status='cancelled'}
  h.time=15;h.controller.tick();check(h.controller.resume(),'another explicit Resume creates another bounded request in the same session')
  h.controller.tick();eq(h.request.deadline,45,'new request deadline is explicit rather than represented as old unused budget')
  eq(h.request.budget_seconds,30,'per-request maximum stays thirty seconds')
  eq(h.controller.status().session_started_at,0,'additional explicitly authorized requests keep the original session origin')
  eq(count_event(h,'search_cancel_requested'),2,'both previously cancelled allocations remain logged')
  eq(search_authorizations(h),2,'every replacement requires its own explicit authorization receipt')
  h.time=45;eq(h.controller.tick().reason,'search_timeout','new request cannot exceed its own actual deadline')
  h=harness();h.start();h.time=2;h.controller.stop();h.poll={request_id=h.request.request_id,exited=true,status='cancelled'}
  h.controller.tick();h.time=40;check(h.controller.resume(),'explicit Resume can authorize a new request after the old request deadline')
  eq(h.searches,1,'new authorization still cannot dispatch from the Resume callback')
  h.controller.tick();eq(h.request.deadline,70,'new request is separately bounded and not a revival of the expired request')
end
do
  local h=harness();h.start();local receipt={seed='KEPT',proof={exact='receipt'},slots={1,4}}
  h.poll={request_id=h.request.request_id,exited=true,status='found',found=receipt}
  h.controller.tick();h.poll=nil;h.time=1;h.controller.stop();h.time=60
  check(h.controller.resume(),'completed found result remains resumable after the search deadline')
  eq(h.starts,0,'found Resume itself never launches')
  h.controller.tick();eq(h.starts,1,'next fresh tick launches the found result once')
  eq(h.found.seed,'KEPT','same found seed survives Stop');eq(h.found.proof.exact,'receipt','nested found evidence survives Stop')
  eq(h.searches,1,'found Resume does not search again')
  h.controller.stop();h.time=65;check(h.controller.resume(),'accepted startup remains resumable before first ready action')
  h.controller.tick();eq(h.starts,1,'startup Resume never launches its accepted run again')
  h.ready('startup-settled');h.controller.tick();eq(h.executions,1,'settled resumed startup permits one fresh action')
  h=harness();h.start();h.found_search();h.controller.stop();h.obs.run_id='foreign-startup'
  check(not h.controller.resume(),'resuming accepted startup rejects a different loaded game')
  eq(h.starts,1,'replaced startup never launches again')
  h=harness();h.omit_started_id=true;h.start();h.found_search();h.controller.stop()
  check(not h.controller.resume(),'unknown accepted startup identity must fail closed on Resume')
  eq(h.starts,1,'unknown startup identity never triggers another launch')
end
do
  local h=harness();h.play({max_runs=1});h.finish('win');h.controller.stop();h.time=70
  check(h.controller.resume(),'verified terminal state can resume its same result transition')
  eq(h.controller.status().outcomes.wins,1,'Resume retains the exact existing terminal count')
  h.controller.tick();eq(h.controller.status().outcomes.wins,1,'terminal callback is not counted twice')
  eq(count_event(h,'run_finished'),1,'same terminal receipt remains unique')
  h.obs.transition_ready=true;eq(h.controller.tick().reason,'run_limit','terminal Resume preserves original run limit')
  eq(h.searches,1,'terminal run limit prevents another search')
end
do
  for _,field in ipairs({'modal','paused','input_busy'})do
    local h=harness();h.play();h.time=5;h.obs[field]=true;h.controller.tick()
    for second=10,70,10 do h.time=second;check(h.controller.tick().active,'ordinary input waits past thirty seconds: '..field)end
    eq(h.executions,1,'ordinary input does not duplicate a pending action: '..field)
    eq(h.cancels,0,'ordinary input does not cancel ownership: '..field)
    h.obs[field]=false;h.controller.tick();check(h.controller.status().active,'closing input does not spend its paused watchdog')
    h.time=94.9;check(h.controller.tick().active,'only pre-input active waiting counts')
    h.time=95;eq(h.controller.tick().reason,'action_observation_stalled','watchdog resumes when input ends')
  end
  local h=harness();h.start();h.obs.modal=true;h.time=2;h.controller.tick()
  eq(h.polls,1,'an owned search is still polled while a menu is open')
  h.poll={request_id=h.request.request_id,exited=true,status='found',found={seed='MENU'}};h.time=3;h.controller.tick()
  h.time=75;check(h.controller.tick().active,'found result waits through a long menu')
  eq(h.starts,0,'menu blocks startup without discarding its found receipt')
  h.obs.modal=false;h.controller.tick();eq(h.starts,1,'fresh closing observation starts the retained result')
  h=harness();h.start();h.obs.input_busy=true;h.time=30
  eq(h.controller.tick().reason,'search_timeout','input cannot extend the native search deadline')
  for _,field in ipairs({'modal','paused','input_busy'})do
    h=harness();h.play({run_seconds=10});h.obs[field]=true;h.time=10
    eq(h.controller.tick().reason,'run_time_limit','input does not extend absolute run limit: '..field)
  end
  h=harness();h.play({session_seconds=10});h.obs.modal=true;h.time=10
  eq(h.controller.tick().reason,'session_time_limit','menu does not extend absolute session limit')
end
do
  local h=harness();h.play({max_actions=2,run_seconds=100});local original=h.controller.status()
  h.time=15;h.obs.run_id='verified-restored';h.ready('restored-public-state')
  check(h.controller.continue_checkpoint(),'verified adapter notification can adopt an in-progress restored game')
  local continued=h.controller.status()
  eq(continued.session_serial,original.session_serial,'checkpoint continuation keeps original session identity')
  eq(continued.actions,1,'checkpoint does not undo consumed actions');eq(continued.run_actions,1,'checkpoint does not renew per-run actions')
  eq(continued.runs_started,1,'checkpoint restoration does not count as a new automatic run')
  eq(continued.run_id,'verified-restored','checkpoint continuation binds the newly restored actual game')
  eq(continued.manual_continuations,1,'manual restoration has its own explicit intervention counter')
  check(not continued.pending_action,'checkpoint receipt records interrupted old action instead of claiming it completed')
  eq(count_event(h,'action_observed'),0,'checkpoint replacement is not false evidence of action completion')
  eq(count_event(h,'manual_checkpoint_continuation'),1,'checkpoint adoption is logged exactly once')
  eq(h.executions,1,'checkpoint notification never dispatches gameplay')
  h.controller.tick();eq(h.executions,2,'fresh restored state can use the remaining original action allowance')
  h.ready('next-restored-state');eq(h.controller.tick().reason,'action_limit','restoration cannot renew the action cap')
  h=harness();h.play({run_seconds=10});h.controller.stop();h.obs.run_id='restored';h.ready();h.time=10
  check(not h.controller.continue_checkpoint(),'restoration cannot bypass the absolute run deadline')
  h=harness();h.play();h.finish('loss');h.obs.run_id='old-checkpoint';h.ready()
  check(not h.controller.continue_checkpoint(),'completed outcome cannot be rewritten as an in-progress checkpoint')
  eq(h.controller.status().outcomes.losses,1,'restored stale flags cannot erase an already audited loss')
  h=harness();h.play();h.obs.run_id='restored';h.ready();h.log_failure='manual_checkpoint_continuation'
  check(not h.controller.continue_checkpoint(),'checkpoint intervention requires a successful log receipt')
  eq(h.executions,1,'failed checkpoint logging cannot execute')
  eq(h.controller.status().run_id,'run1','failed intervention log cannot replace the bound run')
end
do
  local h=harness();h.start();h.obs.modal=true;h.controller.tick();h.time=20
  h.poll={request_id=h.request.request_id,exited=true,status='found',found={seed='OVERLAP'}};h.controller.tick();h.poll=nil
  h.time=25;h.obs.modal=false;h.obs.ready=false;h.obs.transition_ready=false;h.controller.tick()
  h.time=54.999;check(h.controller.tick().active,'found result watchdog excludes only the actual input overlap after its creation')
  h.time=55;eq(h.controller.tick().reason,'start_not_ready','pre-found menu time is not credited to a later watchdog')
end
do
  for _,kind in ipairs({'win','loss'})do
    local h=harness();h.play({run_seconds=10,session_seconds=10});h.time=10;h.finish(kind)
    eq(h.controller.status().outcomes[kind=='win' and 'wins' or 'losses'],1,'terminal at absolute limit is recorded before refusing more work')
    eq(count_event(h,'run_finished'),1,'boundary terminal is recorded once')
    h.controller.tick();eq(h.executions,1,'terminal boundary never permits additional gameplay')
  end
  local h=harness();h.play({run_seconds=10,session_seconds=10});h.time=2;h.controller.stop();h.time=12
  h.obs.goal=goal(0);h.obs.terminal={kind='win',verified=true,source='original_win_callback',run_id='run1',event_id='stopped-final'}
  check(h.controller.resume(),'stopped verified terminal can be accounted even when the session clock and collection are complete')
  h.controller.tick();eq(h.controller.status().outcomes.wins,1,'zero-missing terminal Resume preserves the actual win receipt')
  eq(count_event(h,'run_finished'),1,'completion metadata cannot bypass terminal accounting')
  h.controller.tick();eq(h.searches,1,'expired completed session dispatches no further search')
  h=harness();h.play();h.controller.stop();h.obs.goal=goal(0,1)
  h.obs.terminal={kind='loss',verified=true,source='GAME_OVER',run_id='run1',event_id='unknown-goal-final'}
  h.controller.resume();h.controller.tick()
  eq(h.controller.status().outcomes.losses,1,'unknown collection metadata cannot erase a verified terminal retained during Stop')
  eq(count_event(h,'run_finished'),1,'unknown-goal stopped terminal is recorded once')
  h.controller.tick();eq(h.executions,1,'unknown collection metadata permits no subsequent gameplay')
  eq(h.searches,1,'unknown collection metadata permits no subsequent search')
end
print('advisor_auto_run: '..checks..' checks passed')
