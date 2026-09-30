local Auto=dofile('Brainstorm/Advisor/auto_run.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
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
      return true
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
  h=harness();h.play();h.obs.modal=true;eq(h.controller.tick().reason,'manual_pause','opening a menu pauses the controller')
  h=harness();h.play();h.obs.paused=true;eq(h.controller.tick().reason,'manual_pause','game pause stops the controller')
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
print('advisor_auto_run: '..checks..' checks passed')
