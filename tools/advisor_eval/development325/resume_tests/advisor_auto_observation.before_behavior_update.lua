local F=dofile('Brainstorm/Core/auto_run_product.lua')
local C=dofile('Brainstorm/Advisor/auto_run.lua')
local T=dofile('Brainstorm/Core/auto_terminal.lua')
local snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function fixture()
  local now,events,actions,begins,starts=0,{},0,0,0
  local g={STATES={GAME_OVER=99},STATE=3,STATE_COMPLETE=true,SETTINGS={profile=1,paused=false},
    CONTROLLER={locks={}},PROFILES={[1]={deck_usage={},joker_usage={}}},play={cards={}},
    GAME={round=0,stake=8,round_resets={ante=1},win_ante=8,chips=0,blind={boss=false,chips=1000},
      selected_back={effect={center={key='b_red'}}}},jokers={cards={{config={center_key='j_yorick',center={key='j_yorick'}}}}}}
  local B={VERSION='test',config={advisor={enabled=false,challenge_only=true,gold_stickers=false,player_logging=false}}}
  local A={retry_generation=0,display={title='Advice'},lines={'Synthetic advice'}};B.Advisor=A
  A.snapshot={copy=snapshot.copy,fingerprint=snapshot.fingerprint,capture=function()
    return {phase='hand',round=g.GAME.round,chips=g.GAME.chips,stake=g.GAME.stake}
  end}
  local complete=false
  A.gold_stickers={capture=function()return{schema=1,goal='gold_stickers',profile_id=g.SETTINGS.profile,
    metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=complete and 150 or 149,missing=complete and 0 or 1,unknown=0}}end}
  local logfail=false
  A.player_log={status='test'}
  function A.player_log:enabled()return B.config.advisor.player_logging end
  function A.player_log:event(kind,data)
    if logfail then self.error='full';return false end
    events[#events+1]={kind=kind,data=data};return true,#events
  end
  A.settings_changed=function()A.retry_generation=A.retry_generation+1;A.published_key=nil end
  local api
  local function publish()
    A.result={action={kind='play',area='hand',indices={1}}}
    A.published_key=A.snapshot.fingerprint(A.snapshot.capture());A.published_generation=A.retry_generation
    A.published_game=g.GAME
  end
  A.can_execute=function()return not g.OVERLAY_MENU and not A.worker end
  A.execute=function(key,generation)
    check(api:owned(),'Execute has a tightly scoped internal marker')
    check(A.player_log.source=='auto_run','actual action receipt is attributed to auto-run')
    check(not api:manual('internalcallback'),'internally triggered callback does not stop its own action')
    check(key==A.published_key and generation==A.retry_generation,'existing Execute receives exact published tokens')
    actions=actions+1;g.GAME.chips=g.GAME.chips+1;return true
  end
  local req,found,owner;local search={};local searching=false
  B.CollectionSearchRuntime={busy=function()return searching end}
  search.can_begin=function()return not g.OVERLAY_MENU and not searching end
  search.prepare=function(options)req={request_id=1,recipe=snapshot.copy(options)};return req end
  search.begin=function(request,who)
    check(request==req and api:owned(),'exact prepared request dispatches inside ownership scope')
    begins=begins+1;owner=who;searching=true;return 1
  end
  search.poll=function(who)
    check(who==owner,'poll uses the controller-owned search identity')
    searching=false;found=found or{seed='SYNTH',request_id=1,generation=1,receipt={synthetic=true}}
    return{request_id=1,exited=true,status='found',found=found}
  end
  search.cancel=function(who)check(who==owner,'cancellation affects only owned search');searching=false;return true end
  search.launch=function(value,who)
    check(value==found and who==owner and api:owned(),'clone crossing controller preserves native original found identity at launch')
    starts=starts+1;g.GAME=snapshot.copy(g.GAME);g.GAME.round=1
    A.settings_changed();publish();return true
  end
  local f={end_round=function()g.GAME.won=true;g.GAME.round_resets.ante=9 end}
  f.set_joker_win=function()g.PROFILES[1].joker_usage.j_yorick={wins={[8]=1}}end
  f.set_deck_win=function()g.PROFILES[1].deck_usage.b_red={wins={[8]=1}}end
  local queued_win
  g.FUNCS={overlay_menu=function(args)
    check(api:owned(),'delayed original winning overlay has a narrow callback scope')
    g.OVERLAY_MENU={original=true,definition=args.definition};g.SETTINGS.paused=true
  end}
  f.create_UIBox_win=function()return{config={id='you_win_UI'}}end
  f.win_game=function()
    check(api:owned(),'original win accounting has a narrow callback scope')
    f.set_joker_win();f.set_deck_win()
    queued_win=function()g.FUNCS.overlay_menu({definition=f.create_UIBox_win()})end
  end
  local game_class={update_game_over=function(self)
    check(api:owned(),'original loss UI has a narrow terminal callback scope')
    if not self.loss_drawn then self.loss_drawn=true;self.OVERLAY_MENU={original_loss=true};self.SETTINGS.paused=true end
  end}
  local card={calculate_joker=function()return nil end}
  local closed,lock_exit=0,false
  api=F.attach(B,{game=function()return g end,advisor=A,search=search,controller=C,terminal=T,
    globals=f,card=card,game_class=game_class,now=function()return now end,exit_overlay=function()
      check(api:owned(),'overlay close has an internal ownership marker')
      closed=closed+1;g.OVERLAY_MENU=nil;g.SETTINGS.paused=false
      if lock_exit then g.CONTROLLER.locks.frame=true;g.CONTROLLER.locks.frame_set=true end
    end})
  return {api=api,g=g,B=B,A=A,f=f,publish=publish,events=events,search=search,game_class=game_class,
    request=function()return req end,win_ui=function()local fn=queued_win;queued_win=nil;fn()end,
    stats=function()return{actions=actions,begins=begins,starts=starts,closed=closed}end,
    time=function(t)now=t end,logfail=function()logfail=true end,complete=function()complete=true end,
    lock_exit=function()lock_exit=true end}
end
local function counters(x)
  local calls={snapshot=0,fingerprint=0,goal=0}
  local capture,fingerprint,goal=x.A.snapshot.capture,x.A.snapshot.fingerprint,x.A.gold_stickers.capture
  x.A.snapshot.capture=function(...)calls.snapshot=calls.snapshot+1;return capture(...)end
  x.A.snapshot.fingerprint=function(...)calls.fingerprint=calls.fingerprint+1;return fingerprint(...)end
  x.A.gold_stickers.capture=function(...)calls.goal=calls.goal+1;return goal(...)end
  function calls.reset()calls.snapshot=0;calls.fingerprint=0;calls.goal=0 end
  return calls
end
local function starting()
  local x=fixture();check(x.api:start(),'manufactured explicit start accepted')
  for _=1,4 do x.api:update()end
  check(x.stats().starts==1 and x.stats().actions==0,'fixture is starting before its first action')
  return x,counters(x)
end
do
  local x=fixture();local calls=counters(x)
  for _=1,120 do x.api:update()end
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==0,'idle frames never observe public state or metadata')
  check(x.stats().actions==0 and x.stats().begins==0,'idle frames never create work')
end
for _,case in ipairs({
  {name='worker',set=function(x)x.A.worker={}end,clear=function(x)x.A.worker=nil end},
  {name='execution',set=function(x)x.A.execution_key='pending'end,clear=function(x)x.A.execution_key=nil end},
  {name='transition',set=function(x)x.g.STATE_COMPLETE=false end,clear=function(x)x.g.STATE_COMPLETE=true end},
  {name='screenwipe',set=function(x)x.g.screenwipe={}end,clear=function(x)x.g.screenwipe=nil end},
  {name='card action',set=function(x)x.g.GAME.STOP_USE=1 end,clear=function(x)x.g.GAME.STOP_USE=0 end},
  {name='locked control',set=function(x)x.g.CONTROLLER.locked=true end,clear=function(x)x.g.CONTROLLER.locked=nil end},
  {name='input lock',set=function(x)x.g.CONTROLLER.locks.frame=true end,clear=function(x)x.g.CONTROLLER.locks.frame=nil end},
  {name='drag',set=function(x)x.g.CONTROLLER.dragging={target={}}end,clear=function(x)x.g.CONTROLLER.dragging=nil end},
  {name='text entry',set=function(x)x.g.CONTROLLER.text_input_hook={}end,clear=function(x)x.g.CONTROLLER.text_input_hook=nil end},
  {name='play animation',set=function(x)x.g.play.cards={{}}end,clear=function(x)x.g.play.cards={}end},
  {name='checkpoint pending',set=function(x)x.B.Checkpoints={pending={}}end,clear=function(x)x.B.Checkpoints=nil end},
  {name='saving',set=function(x)x.g.SAVING=true end,clear=function(x)x.g.SAVING=nil end},
  {name='loading',set=function(x)x.g.LOADING=true end,clear=function(x)x.g.LOADING=nil end},
})do
  local x,calls=starting();case.set(x)
  local original_lines=x.A.lines;x.A.lines=setmetatable({},{})
  local original_action=x.A.result.action;local action={kind='play'};action.circular=action;x.A.result.action=action
  local public_key=x.A.published_key
  for frame=1,120 do x.time(frame/120);x.api:update()end
  check(calls.snapshot==0 and calls.fingerprint==0,case.name..' never captures or fingerprints blocked advice')
  check(calls.goal==120,case.name..' continues to reread Gold metadata every tick')
  check(x.api:status().active and x.stats().actions==0 and x.A.published_key==public_key,
    case.name..' does not copy malformed unused advice, mutate publication, dispatch or stop before deadline')
  x.A.lines=original_lines;x.A.result.action=original_action;case.clear(x);calls.reset();x.api:update()
  check(x.stats().actions==1 and calls.snapshot==3,case.name..' release captures observation plus both exact execution gates')
  check(calls.fingerprint==6,case.name..' release freshly fingerprints action and public state at all three gates')
end
for _,field in ipairs({'paused','modal'})do
  local x,calls=starting()
  if field=='paused'then x.g.SETTINGS.paused=true else x.g.OVERLAY_MENU={}end
  x.api:update()
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==1,field..' stops without serializing public action data')
  check(not x.api:status().active and x.api:status().reason=='manual_pause' and x.stats().actions==0,
    field..' retains immediate manual-stop behavior')
end
do
  local x=fixture();check(x.api:start(),'search fixture starts');x.api:update();x.api:update()
  local calls=counters(x)
  -- Simulated pending search holds its own result until explicitly released.
  local oldpoll=x.search.poll;x.search.poll=function()return{request_id=1,exited=false,status='searching'}end
  x.A.result={action={kind='play'}};x.A.lines=setmetatable({},{})
  for frame=1,120 do x.time(frame/120);x.api:update()end
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==120,'owned search keeps only lifecycle/goal observation')
  check(x.api:status().active and x.stats().starts==0,'search does not dispatch stale published action')
  x.time(30);x.api:update()
  check(x.api:status().reason=='search_timeout' and x.api:status().search_draining,'exact search deadline still cancels and owns drain')
  x.search.poll=oldpoll;x.A.lines={};x.api:update()
  check(not x.api:status().search_draining and x.stats().starts==0,'late found result drains without launch after timeout')
end
do
  local x,calls=starting();x.api:update();check(x.stats().actions==1,'pending fixture dispatches once')
  x.A.worker={};calls.reset()
  for second=1,29 do x.time(second);x.g.GAME.chips=second+1;x.publish();calls.reset();x.api:update()
    check(calls.snapshot==0 and x.stats().actions==1,'changed blocked state never repeats a pending action')end
  x.time(30);calls.reset();x.api:update()
  check(x.api:status().reason=='action_observation_stalled' and not x.api:status().active,
    'changing state or fresh publication cannot renew pending action watchdog')
  check(calls.snapshot==0 and calls.goal==1,'deadline tick retains lifecycle checking without snapshot work')
end
do
  local x,calls=starting();x.g.CONTROLLER.dragging={target={}};x.api:update()
  local prior=x.A.published_key;x.g.GAME.chips=22;x.g.CONTROLLER.dragging=nil;calls.reset();x.api:update()
  check(x.stats().actions==0 and x.api:status().waiting_for=='fresh_advice' and calls.snapshot==1,
    'release recaptures changed state and refuses old publication')
  check(x.A.published_key==prior,'observation never repairs a stale published key')
  x.publish();calls.reset();x.api:update();check(x.stats().actions==1 and calls.snapshot==3,'new matching publication permits exactly one action')
end
do
  local x,calls=starting();x.g.CONTROLLER.dragging={target={}};x.api:update()
  x.A.retry_generation=x.A.retry_generation+1;x.g.CONTROLLER.dragging=nil;calls.reset();x.api:update()
  check(x.stats().actions==0 and x.api:status().waiting_for=='executable_action',
    'generation changed while blocked cannot dispatch prior publication')
end
for _,change in ipairs({'public_state','action','generation'})do
  local x,calls=starting();local once=true
  x.A.can_execute=function()
    if once then once=false
      if change=='public_state'then x.g.GAME.chips=x.g.GAME.chips+10
      elseif change=='action'then x.A.result.action.indices={2}
      else x.A.retry_generation=x.A.retry_generation+1 end
    end
    return true
  end
  x.api:update()
  check(x.stats().actions==0 and x.api:status().reason=='execute_failed',change..' changed after can_execute is caught before actual Execute')
  local consumed=x.api:status().actions;x.api:update()
  check(consumed==1 and x.api:status().actions==1,change..' consumes its uncertain attempt once and never retries')
end
do
  local x,calls=starting();x.A.worker={};x.g.STATE=99;x.g.GAME.won=true
  x.game_class.update_game_over(x.g);x.api:update()
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==1,'terminal observation bypasses irrelevant action serialization and rereads metadata')
  check(x.api:status().outcomes.losses==1 and x.api:status().outcomes.wins==0,'incidental won during GAME_OVER remains a loss despite worker activity')
end
do
  local x,calls=starting();x.api:update();check(x.stats().actions==1,'unsupported endpoint fixture dispatches one prior action')
  local function observed_count()
    local count=0
    for _,row in ipairs(x.events)do if row.data.event=='action_observed'then count=count+1 end end
    return count
  end
  check(observed_count()==0 and x.api:status().pending_action,'prior action initially awaits its changed public state')
  x.time(5)
  x.A.result={reason='Manufactured unsupported endpoint'}
  x.A.published_key=x.A.snapshot.fingerprint(x.A.snapshot.capture(x.g))
  x.A.published_generation=x.A.retry_generation
  x.A.lines=setmetatable({},{})
  calls.reset();x.api:update()
  local state=x.api:status()
  check(observed_count()==1 and not state.pending_action and state.active and state.waiting_for=='unsupported',
    'ready changed unsupported publication acknowledges previous action exactly once')
  check(calls.snapshot==1 and calls.fingerprint==1 and calls.goal==1 and x.stats().actions==1,
    'unsupported endpoint captures fresh state without action fingerprint, unused advice copy or execution')
  x.time(30);calls.reset();x.api:update()
  check(x.api:status().active and x.api:status().waiting_for=='unsupported' and observed_count()==1,
    'acknowledgment renews the unsupported wait at its actual time instead of expiring prior action watchdog')
  x.time(34.999);x.api:update()
  check(x.api:status().active and x.stats().actions==1,'unsupported endpoint waits its complete existing30-second allowance')
  x.time(35);x.api:update()
  check(not x.api:status().active and x.api:status().reason=='unsupported_stalled' and observed_count()==1,
    'unsupported endpoint retains existing stall classification and emits one acknowledgment only')
end
do
  local x,calls=starting();x.g.CONTROLLER.dragging={target={}};x.api:update();calls.reset()
  x.g.PROFILES[1]={};x.api:update()
  check(not x.api:status().active and x.api:status().reason=='observation_unavailable',
    'loaded profile identity replacement while blocked still stops immediately')
  check(calls.snapshot==0 and calls.goal==0,'profile mismatch is rejected before observation')
end
print('advisor_auto_observation: '..checks..' checks passed')
