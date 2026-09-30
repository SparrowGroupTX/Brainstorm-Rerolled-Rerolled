local F=dofile('Brainstorm/Core/auto_run_product.lua')
local C=dofile('Brainstorm/Advisor/auto_run.lua')
local T=dofile('Brainstorm/Core/auto_terminal.lua')
local snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function fixture()
  local now,events,actions,begins,starts=0,{},0,0,0
  local polls,cancels,settings_changes=0,0,0
  local poll_held,cancel_held=false,false
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
  A.settings_changed=function()settings_changes=settings_changes+1;A.retry_generation=A.retry_generation+1;A.published_key=nil end
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
  search.prepare=function(options)found=nil;req={request_id=1,recipe=snapshot.copy(options)};return req end
  search.begin=function(request,who)
    check(request==req and api:owned(),'exact prepared request dispatches inside ownership scope')
    begins=begins+1;owner=who;searching=true;return 1
  end
  search.poll=function(who)
    check(who==owner,'poll uses the controller-owned search identity')
    polls=polls+1
    if poll_held then return{request_id=1,exited=false,status='searching'}end
    searching=false;found=found or{seed='SYNTH',request_id=1,generation=1,receipt={synthetic=true}}
    return{request_id=1,exited=true,status='found',found=found}
  end
  search.cancel=function(who)check(who==owner,'cancellation affects only owned search');cancels=cancels+1
    if not cancel_held then searching=false end;return true end
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
    stats=function()return{actions=actions,begins=begins,starts=starts,closed=closed,polls=polls,cancels=cancels,settings_changes=settings_changes}end,
    time=function(t)now=t end,logfail=function()logfail=true end,complete=function()complete=true end,
    lock_exit=function()lock_exit=true end,poll_held=function(v)poll_held=v end,cancel_held=function(v)cancel_held=v end}
end
do
  local x=fixture();x.api:update();check(x.stats().begins==0 and x.stats().actions==0,'inactive facade never searches or plays')
  x.g.OVERLAY_MENU={manual_start=true};x.g.SETTINGS.paused=true
  check(x.api:start({search_request={deck='Red Deck'}}),'explicit user start is accepted')
  check(x.B.config.advisor.enabled and not x.B.config.advisor.challenge_only and x.B.config.advisor.gold_stickers and
    x.B.config.advisor.player_logging,'only explicit start enables advisor, normal decks, Gold context and recording')
  check(x.stats().begins==0 and x.stats().starts==0 and x.stats().closed==1,'UI start only records consent and closes the menu')
  x.api:update();check(x.api:status().active,'separate settled update arms controller')
  x.api:update();check(x.stats().begins==1,'later update dispatches a single search')
  x.api:update();check(x.stats().starts==0,'found receipt waits for a fresh startup observation')
  x.api:update();check(x.stats().starts==1,'fresh observation starts the native-owned exact receipt once')
  x.api:update();check(x.stats().actions==1 and x.A.player_log.source==nil,'fresh original advisor gates permit one action and restore its temporary log source')
  x.api:update();check(x.stats().actions==1,'stale advice cannot repeat the action')
  x.publish();x.api:update();check(x.stats().actions==2,'changed state plus fresh advice permits the next action')
  x.g.GAME.chips=1000;x.g.GAME.blind.boss=true;x.g.GAME.round_resets.ante=8;x.g.GAME.round=23
  x.f.end_round();x.f.win_game()
  x.api:update();check(x.api:status().outcomes.wins==1 and not x.g.OVERLAY_MENU,'original counters can be observed before their asynchronous result UI')
  x.api:update();check(x.stats().begins==1 and x.api:status().active,'verified accounting waits for its queued result surface before another search')
  x.win_ui();x.complete()
  check(x.api:status().outcomes.wins==1 and x.g.OVERLAY_MENU~=nil,'verified terminal is logged before original result overlay is dismissed')
  x.api:update();check(x.stats().closed==2 and not x.g.OVERLAY_MENU,'a later update dismisses exactly the original winning overlay')
  x.api:update();check(x.api:status().complete and not x.api:status().active,'fresh exact-zero missing metadata ends collection')
end
do
  local x=fixture();x.api:start();x.api:update();x.api:update()
  check(x.api:manual('checkpoint save','checkpoint'),'external checkpoint activity is detected')
  check(x.api:status().active,'saving a checkpoint does not revoke automatic consent')
  x.api:update();check(not x.api:status().search_draining and x.stats().cancels==0,'checkpoint save does not cancel an owned worker')
  check(x.stats().starts==0,'found result still waits for a fresh startup observation')
  x.api:update();check(x.stats().starts==1,'same owned found result remains usable after checkpoint save')
end
do
  local x=fixture();x.api:start();x.logfail();x.api:update()
  check(not x.api:status().active and x.stats().begins==0,'logging failure prevents search dispatch')
end
do
  local x=fixture();x.api:start();x.g.SETTINGS.profile=2;x.api:update()
  check(not x.api:status().active and x.stats().begins==0,'profile switch while menu settles invalidates consent')
end
do
  local x=fixture();local options={deck_name='Zodiac Deck',interchangeable_copies=false,minimum_distinct=4,first_ante=5,last_ante=8}
  check(x.api:start(options),'flat menu search options are accepted')
  options.deck_name='Red Deck';x.api:update();x.api:update()
  local q=x.request().recipe
  check(q.deck_name=='Zodiac Deck'and q.interchangeable_copies==false and q.minimum_distinct==4 and q.first_ante==5 and q.last_ante==8,
    'flat menu deck, explicit false OR, quota and window survive immutable controller search forwarding')
  check(x.api.status_text:find('searching',1,true),'UI status_text follows active controller state')
  x.api:stop('test stop');check(x.api.status_text:find('Waiting for the owned search worker',1,true),'UI shows cancellation draining until actual exit')
end
do
  local x=fixture();x.api:start();x.api:update();x.api:update();x.api:update();x.api:update()
  x.g.PROFILES[1]={deck_usage={},joker_usage={}};x.api:update()
  check(not x.api:status().active and x.stats().actions==0,'same-number profile-table replacement blocks any stale automatic action')
end
do
  local x=fixture();x.api:start();x.api:update();x.api:update();x.api:update();x.api:update();x.api:update()
  x.g.STATE=99;x.g.GAME.won=true;x.game_class.update_game_over(x.g)
  x.api:update();check(x.api:status().outcomes.losses==1 and x.api:status().outcomes.wins==0,'source GAME_OVER with incidental won records only loss')
  x.lock_exit()
  x.api:update();check(not x.g.OVERLAY_MENU,'separate update dismisses owned original loss overlay')
  x.api:update();check(x.stats().begins==1,'original exit-overlay frame locks block the next search until settled')
  x.g.CONTROLLER.locks.frame=false;x.g.CONTROLLER.locks.frame_set=false
  x.api:update();check(x.stats().begins==2,'settled loss result can begin the next independently owned search')
end
do
  local x=fixture();x.search.begin=function()return nil,'pre-dispatch refusal'end
  x.search.poll=function()return nil end;x.search.cancel=function()return false end
  x.api:start();x.api:update();x.api:update();x.api:update()
  check(not x.api:status().active and not x.api:status().search_draining,'uncertain start with positively empty runtime drains instead of inventing an active worker')
  check(x.stats().starts==0 and x.stats().actions==0,'uncertain refused startup never launches or plays')
end
do
  local x=fixture();x.A.player_log.event=function()error('storage failure')end
  check(not x.api:start()and x.stats().begins==0,'journal exceptions return startup failure without dispatch')
  local y=fixture();local cyclic={};cyclic.self=cyclic
  check(not y.api:start(cyclic)and not y.B.config.advisor.player_logging,'cyclic UI options fail before settings or logging changes')
end
do
  local x=fixture();x.A.player_log.source='existing_source'
  x.A.execute=function()check(x.A.player_log.source=='auto_run','throwing Execute still receives auto-run source');error('synthetic callback failure')end
  x.api:start();for i=1,5 do x.api:update()end
  check(not x.api:status().active and x.A.player_log.source=='existing_source'and not x.api:owned(),
    'Execute exception restores prior action source and ownership before stopping')
end
do
  local x=fixture();x.g.LOADING={font={synthetic_font=true}}
  check(x.api:start(),'source-shaped boot cache permits explicit automatic Start')
  x.api:update();x.api:update()
  check(x.stats().begins==1 and x.g.LOADING.font.synthetic_font,'automatic search starts while preserving persistent boot cache')
end
for shape_index,value in ipairs({true,{}, {font={synthetic_font=true},active=true},{font='unexpected'},17,
    {font={synthetic_font=true},[1]='unknown_extra'},setmetatable({font={}},{})})do
  local x=fixture();x.g.LOADING=value
  check(x.api:start(),'automatic Start queues one explicit request')
  x.api:update();x.api:update()
  check(x.stats().begins==0 and x.stats().starts==0 and x.api.status_text=='Waiting: Game loading is active ('..({'boolean','table fields: none','table fields: active, font','table fields: font','number','table fields: <number key>, font','table with metatable'})[shape_index]..').',
      'active/unknown loading blocks with a concise visible reason')
end
for _,case in ipairs({
  {set=function(x)x.g.STATE_COMPLETE=false end,reason='Game transition incomplete.'},
  {set=function(x)x.g.CONTROLLER.locked=true end,reason='Controls are settling.'},
  {set=function(x)x.g.CONTROLLER.locks.frame=true end,reason='Input locks active: frame.'},
  {set=function(x)x.g.CONTROLLER.locks.frame_set=true end,reason='Input locks active: frame_set.'},
  {set=function(x)x.B.Checkpoints={pending={slot=1}}end,reason='Checkpoint request is pending.'},
  {set=function(x)x.g.SAVING=true end,reason='Game saving is active.'},
  {set=function(x)x.g.GAME.STOP_USE=1 end,reason='Card action pending.'},
})do
  local x=fixture();x.g.LOADING={font={}};case.set(x)
  check(x.api:start(),'boot cache does not remove explicit consent requirements')
  x.api:update();x.api:update()
  check(x.stats().begins==0 and x.api.status_text=='Waiting: '..case.reason,
      'actual blocker stays protective and explains the wait: '..case.reason)
end
do
  local x=fixture();x.g.LOADING={font={}};x.g.STAGES={MAIN_MENU=1,RUN=2};x.g.STAGE=1;x.g.STATES.MENU=5;x.g.STATE=5;x.g.STATE_COMPLETE=false
  check(x.api:start(),'automatic Start accepts original main-menu shape')
  x.api:update();x.api:update();check(x.stats().begins==1,'main-menu latch remains false without blocking automatic search')
end
for _,complete in ipairs({false,true})do
  local x=fixture();x.g.LOADING={font={}};x.g.STAGES={MAIN_MENU=1,RUN=2};x.g.STAGE=1;x.g.STATES.MENU=5;x.g.STATE=6;x.g.STATE_COMPLETE=complete
  check(x.api:start(),'explicit request may wait for a transient menu to settle')
  x.api:update();x.api:update();check(x.stats().begins==0,'automatic startup never treats splash/demo as settled MENU')
end
for _,case in ipairs({
  {options={},mode='auto'},
  {options={minimum_distinct=0},mode='auto'},
  {options={minimum_distinct=4},mode='strict',count=4},
  {options={minimum_distinct=0,quota_mode='strict'},mode='strict',count=0},
  {options={minimum_distinct=4,quota_mode='auto'},mode='auto',count=4},
  {options={search_request={minimum_distinct=0,quota_mode='strict'}},mode='strict',count=0},
})do
  local x=fixture();local before=snapshot.fingerprint(case.options)
  check(x.api:start(case.options),'explicit automatic/strict quota options accepted')
  x.api:update();x.api:update()
  local q=x.request().recipe
  check(q.quota_mode==case.mode and (case.count==nil or q.minimum_distinct==case.count),
    'automatic facade preserves explicit mode/count and migrates only absent or legacy default')
  check(snapshot.fingerprint(case.options)==before,'automatic quota forwarding does not mutate caller settings')
end
do
  local x=fixture()
  check(not x.api:start({quota_mode='auto',search_request={quota_mode='strict'}}),
    'conflicting flat/nested quota modes fail before work')
  check(x.stats().begins==0 and not x.B.config.advisor.player_logging,'conflicting mode does not enable work or logging')
end
for _,case in ipairs({
  {options={},expected=true},
  {options={burnt_fallback=false},expected=false},
  {options={search_request={burnt_fallback=false}},expected=false},
  {options={burnt_fallback=true},expected=true},
})do
  local x=fixture();check(x.api:start(case.options),'automatic Burnt preference accepted')
  x.api:update();x.api:update()
  check(x.request().recipe.burnt_fallback==case.expected,'automatic facade preserves explicit false and defaults to authorized bounded fallback')
end
do
  local x=fixture()
  check(not x.api:start({burnt_fallback=true,search_request={burnt_fallback=false}}),
    'conflicting Burnt preference fails before work')
  check(x.stats().begins==0,'conflicting fallback never dispatches')
  local y=fixture();y.api:start();y.api:update();y.api:update()
  y.search.status='Searching without required Burnt; same total time limit.'
  check(y.api:status().state=='searching'and y.api.status_text==y.search.status,
    'automatic searching status exposes actual relaxed query rather than generic searching')
end
do
  local x=fixture()
  local r=x.api:status_report()
  check(not r.requested and not r.busy and r.owner==nil,'initial auto report does not imply consent')
  check(not x.api:start({search_request='bad'}) and not x.api:status_report().requested,
    'pre-consent rejection remains unrequested')
  x.g.OVERLAY_MENU={};x.g.SETTINGS.paused=true
  assert(x.api:start())
  local before=x.stats();local events=#x.events;local input=x.g.CONTROLLER;local text=x.api.status_text
  local config=snapshot.copy(x.B.config);local key=x.A.published_key
  for i=1,5 do
    r=x.api:status_report()
    check(r.requested and r.busy and r.phase=='waiting' and r.owner=='auto' and r.text==text,
      'accepted auto request reports pending state without running an update')
    r.text='mutated output';r.requested=false;r.busy=false
  end
  local after=x.stats()
  check(after.actions==before.actions and after.begins==before.begins and after.starts==before.starts and after.closed==before.closed
    and #x.events==events and x.g.CONTROLLER==input and x.api.status_text==text and x.A.published_key==key and
    x.B.config.advisor.enabled==config.advisor.enabled and x.B.config.advisor.player_logging==config.advisor.player_logging,
    'auto status reads preserve input, settings, status, logs and native/game counts')
  x.api:manual('Keyboard input.')
  r=x.api:status_report()
  check(r.requested and r.busy and r.owner=='auto','ordinary keyboard input preserves the pending automatic request')
  x.api:update();check(x.stats().begins==0 and x.stats().actions==0 and x.api:status().active,
    'ordinary keyboard input allows only the separate controller arming update')
end
do
  local x=fixture();assert(x.api:start());x.api:update();x.api:update()
  local r=x.api:status_report()
  check(r.requested and r.busy and r.phase=='searching','actual auto controller phase is exposed')
  x.api:stop('Stop while native worker drains.')
  r=x.api:status_report()
  check(r.requested and r.busy,'auto drain remains busy')
  x.api:update();r=x.api:status_report()
  check(r.requested and not r.busy and x.stats().starts==0,'auto drain completion is observable without launching')
end

for _,case in ipairs({
  {set=function(x)x.B.Checkpoints={saving=true}end,text='Checkpoint save is pending.'},
  {set=function(x)x.B.save_pending=true end,text='Brainstorm save is pending.'},
  {set=function(x)x.B.checkpoint_busy=true end,text='Checkpoint operation is busy.'},
  {set=function(x)x.g.CONTROLLER.locks={zeta=true,alpha=true,ignore=false}end,text='Input locks active: alpha, zeta.'},
  {set=function(x)x.g.LOADING={font={},extra={secret='hidden'}}end,text='Game loading is active (table fields: extra, font).'},
})do
  local x=fixture();assert(x.api:start());case.set(x);x.api:update()
  local r=x.api:status_report()
  check(r.busy and r.text=='Waiting: '..case.text and x.stats().begins==0 and x.stats().starts==0,
    'specific auto blocker remains enforced: '..case.text)
end

-- Append before advisor_auto_run_product.lua's final print; manufactured fixture only.
do
  local Execution=dofile('Brainstorm/Advisor/execution.lua')
  local x=fixture();assert(x.api:start())
  for _=1,4 do x.api:update()end
  check(x.stats().starts==1 and x.stats().actions==0,'cash-out fixture starts its synthetic normal run before any play')
  x.g.STATES.ROUND_EVAL=3;x.g.STATE=3
  local root={elements={},config={},states={visible=true}}
  function root:get_UIE_by_ID(id)return self.elements[id]end
  x.g.round_eval=root
  local detached={elements={},config={major=root},states={visible=true}}
  function detached:get_UIE_by_ID(id)return self.elements[id]end
  detached.UIRoot={UIBox=detached,states={visible=true},config={}}
  local button={config={id='cash_out_button'},states={visible=true},UIBox=detached,parent=detached.UIRoot}
  detached.elements.cash_out_button=button;x.g.I={UIBOX={detached}}
  local callback_count=0
  x.g.FUNCS.cash_out=function(e)check(e==button,'automatic cash-out dispatch retains original detached element');callback_count=callback_count+1 end
  x.A.result={action={kind='cash_out'}}
  x.A.published_key=x.A.snapshot.fingerprint(x.A.snapshot.capture(x.g));x.A.published_generation=x.A.retry_generation
  x.A.can_execute=function()return Execution.button_ready(x.g,x.A.result.action)end
  local original_execute=x.A.execute
  x.A.execute=function(...)
    local accepted,reason=Execution.execute(x.g,{kind='cash_out'})
    if not accepted then return false,reason end
    return original_execute(...)
  end
  local function event_count(name)
    local count=0;for _,row in ipairs(x.events)do if row.data and row.data.event==name then count=count+1 end end;return count
  end
  local attempts=event_count('action_attempt')
  local _,reason=Execution.button_ready(x.g,{kind='cash_out'})
  for second=1,5 do
    x.time(second);x.api:update()
    local status=x.api:status_report()
    check(status.busy and status.text:find(reason,1,true),'waiting automatic status exposes the exact live cash-out reason')
    check(event_count('action_attempt')==attempts and x.stats().actions==0 and callback_count==0,
      'unavailable button consumes neither action attempt nor callback')
  end
  button.config.button='cash_out';x.api:update()
  check(callback_count==1 and x.stats().actions==1 and event_count('action_attempt')==attempts+1,
    'one enabling transition permits exactly one automatic cash-out')
  x.api:update()
  check(callback_count==1 and x.stats().actions==1,'unchanged publication cannot automatically repeat cash-out')
  check(x.api:status().active,'successful cash-out does not stop automatic mode')
end
do
  local x=fixture();assert(x.api:start())
  for _=1,4 do x.api:update()end
  x.A.execute=function()return false,'Specific synthetic cash-out callback failure' end
  x.api:update()
  local status=x.api:status()
  check(not status.active and status.reason=='execute_failed' and status.detail=='Specific synthetic cash-out callback failure',
    'a consumed automatic execution failure keeps its original string reason and stops without retry')
  local before=x.stats().actions;x.api:update();check(x.stats().actions==before,'failed execution is never automatically retried')
end

local function run_to_play(x,options)
  check(x.api:start(options),'synthetic explicit Start is accepted')
  for _=1,5 do x.api:update()end
  check(x.stats().starts==1 and x.stats().actions==1,'synthetic settled startup reaches one action')
end
local function event_count(x,name)
  local n=0;for _,row in ipairs(x.events)do if row.data.event==name then n=n+1 end end;return n
end
local function search_authorizations(x)
  local n=0;for _,row in ipairs(x.events)do local e=row.data
    if e.event=='session_resumed' and e.restart_cancelled_search==true and type(e.new_search_authorization)=='string'then n=n+1 end
  end;return n
end
do
  local x=fixture();check(not x.api:engaged(),'unrequested facade is not engaged')
  run_to_play(x,{max_actions=3,run_seconds=300,session_seconds=500})
  local before=x.api:status();local config=snapshot.fingerprint(x.B.config)
  x.time(10);check(x.api:stop(),'explicit Stop can pause a running game')
  check(x.api:engaged() and x.api:status_report().resume_available and not x.api:status_report().busy,
    'paused session remains engaged with visible Resume and no automatic work')
  x.g.OVERLAY_MENU={resume_menu=true};x.g.SETTINGS.paused=true;x.time(80)
  local stats=x.stats();check(x.api:resume(),'explicit Resume accepts the same loaded profile')
  check(x.api:status_report().resume_pending and x.api:status_report().busy,'Resume is a separately observable pending operation')
  check(x.stats().closed==stats.closed+1 and not x.g.OVERLAY_MENU,'Resume closes only its explicit menu inside ownership scope')
  check(x.stats().actions==stats.actions and x.stats().begins==stats.begins and x.stats().starts==stats.starts,
    'Resume callback never executes, searches or launches')
  check(x.A.published_key==nil and x.stats().settings_changes==stats.settings_changes+1,
    'Resume invalidates published advice before asking for a fresh execution state')
  check(snapshot.fingerprint(x.B.config)==config,'Resume does not reset or overwrite settings')
  x.api:update();local resumed=x.api:status()
  check(resumed.active and resumed.session_serial==before.session_serial and resumed.session_started_at==before.session_started_at,
    'separate Resume update retains the original controller session and absolute origin')
  check(resumed.actions==before.actions and resumed.run_actions==before.run_actions and resumed.runs_started==before.runs_started,
    'Resume preserves all consumed work counters')
  check(x.stats().actions==1 and x.stats().starts==1 and x.stats().begins==1,'resuming does not repeat the pending physical callback')
  x.api:update();check(x.stats().actions==1,'unpublished advice cannot dispatch after Resume')
  x.publish();x.api:update();check(x.stats().actions==2,'fresh changed public state allows one next action')
  check(event_count(x,'explicit_start_requested')==1 and event_count(x,'session_started')==1 and
    event_count(x,'explicit_resume_requested')==1 and event_count(x,'session_resumed')==1,
    'Resume has explicit receipts without creating another session or search start')
  check(x.A.player_log.source==nil and not x.api:owned(),'Resume and resumed action restore narrow ownership/source markers')
end
do
  local x=fixture();local options={deck_name='Zodiac Deck',minimum_distinct=4,first_ante=5,last_ante=8,interchangeable_copies=false}
  check(x.api:start(options),'pending fixture accepts initial options');options.deck_name='Red Deck'
  x.time(2);x.api:stop();check(x.api:engaged() and x.api:status().resume_available,'Stop while arming preserves the accepted pending consent')
  x.time(90);check(x.api:resume(),'stopped arming request is resumable')
  check(x.stats().begins==0 and x.stats().actions==0,'arming Resume call performs no work')
  x.api:update();x.api:update();x.api:update()
  check(x.stats().begins==1 and x.stats().starts==0,'resumed arming dispatches exactly one deferred query')
  local q=x.request().recipe
  check(q.deck_name=='Zodiac Deck' and q.minimum_distinct==4 and q.first_ante==5 and q.last_ante==8 and q.interchangeable_copies==false,
    'Stop/Resume before first search preserves immutable accepted search options')
  check(event_count(x,'explicit_start_requested')==1 and event_count(x,'session_started')==1,
    'resumed arming does not duplicate consent or session starts')
end
do
  for _,stage in ipairs({'arming','searching','playing'})do
    for _,kind in ipairs({'keyboard','mouse','settings','checkpoint','drag'})do
      local x=fixture();assert(x.api:start())
      if stage=='searching'then x.poll_held(true);x.api:update();x.api:update()
      elseif stage=='playing'then for _=1,5 do x.api:update()end end
      local before=x.api:status();local count=x.stats();local events=#x.events
      check(x.api:manual('Ordinary '..kind,kind),'ordinary input notification is accepted')
      check(x.api:engaged() and x.stats().cancels==count.cancels and x.stats().begins==count.begins and x.stats().actions==count.actions,
        'ordinary '..kind..' neither stops nor dispatches during '..stage)
      check(#x.events==events,'ordinary input notification does not synthesize a Stop/Resume log')
      x.api:update();local after=x.api:status()
      check(after.active and not after.search_draining and after.session_serial>=before.session_serial,
        'ordinary '..kind..' does not invalidate controller context during '..stage)
      if stage~='arming'then check(after.session_serial==before.session_serial,'ordinary input retains the same session')end
    end
  end
end
do
  for _,kind in ipairs({'menu','drag','text'})do
    local x=fixture();run_to_play(x);x.time(5)
    if kind=='menu'then x.g.OVERLAY_MENU={manual=true};x.g.SETTINGS.paused=true
    elseif kind=='drag'then x.g.CONTROLLER.dragging={target={}}
    else x.g.CONTROLLER.text_input_hook={} end
    x.api:update();local actions=x.stats().actions
    for second=10,70,10 do x.time(second);x.api:update();check(x.api:status().active,'long '..kind..' waits without revoking consent')end
    check(x.stats().actions==actions and x.stats().cancels==0,'long '..kind..' cannot execute or cancel ownership')
    x.g.OVERLAY_MENU=nil;x.g.SETTINGS.paused=false;x.g.CONTROLLER.dragging=nil;x.g.CONTROLLER.text_input_hook=nil
    x.api:update();check(x.api:status().active,'settling '..kind..' does not consume its paused watchdog')
    x.publish();x.api:update();check(x.stats().actions==actions+1,'fresh state resumes after '..kind)
  end
  for _,kind in ipairs({'menu','drag'})do
    local x=fixture();assert(x.api:start());x.time(1)
    if kind=='menu'then x.g.OVERLAY_MENU={};x.g.SETTINGS.paused=true else x.g.CONTROLLER.dragging={target={}}end
    x.api:update();x.time(65);x.api:update()
    check(x.api:engaged() and x.stats().begins==0,'initial arming survives more than thirty seconds of ordinary '..kind)
    x.g.OVERLAY_MENU=nil;x.g.SETTINGS.paused=false;x.g.CONTROLLER.dragging=nil
    x.api:update();x.api:update();check(x.stats().begins==1,'initial arming continues when '..kind..' settles')
  end
end
do
  local x=fixture();assert(x.api:start());x.poll_held(true);x.api:update();x.api:update()
  x.g.OVERLAY_MENU={};x.g.SETTINGS.paused=true;x.time(4);x.api:update()
  check(x.stats().polls==1 and x.stats().cancels==0,'owned native poll continues while a menu is open')
  x.poll_held(false);x.time(5);x.api:update();x.time(80);x.api:update()
  check(x.api:status().active and x.stats().starts==0,'found result survives a long ordinary menu')
  x.g.OVERLAY_MENU=nil;x.g.SETTINGS.paused=false;x.api:update()
  check(x.stats().starts==1 and x.stats().begins==1,'settled menu launches the same receipt without another query')
end
do
  local x=fixture();assert(x.api:start({budget_ms=5000}));x.poll_held(true);x.cancel_held(true)
  x.api:update();x.api:update();check(x.request().recipe.budget_ms==5000,'first native recipe honors the requested five-second cap')
  x.time(1);x.api:stop();check(x.api:status().search_draining and x.api:engaged(),'Stop preserves owned draining search')
  check(not x.api:resume(),'Resume cannot overlap a draining native worker')
  x.time(2);x.poll_held(false);x.api:update()
  check(x.stats().starts==0 and not x.api:status().search_draining,'cancelled worker exit discards a late found result')
  check(x.api:resume(),'explicit Resume can authorize a distinct native request after actual cancelled exit')
  x.poll_held(true);x.api:update();x.api:update()
  local q=x.request().recipe
  check(x.stats().begins==2 and q.budget_ms==5000,
    'new explicitly authorized native request retains its original configured five-second cap')
  check(event_count(x,'search_cancel_requested')==1 and search_authorizations(x)==1,
    'old cancelled allocation and separate new-work authorization both remain auditable')
  check(x.api:status().session_started_at==0,'new request cannot reset the absolute automatic-session origin')
end
do
  local x=fixture();assert(x.api:start());x.api:update();x.api:update();x.api:update()
  check(x.stats().starts==0,'found stop fixture is before launch');x.api:stop();x.time(65)
  check(x.api:resume(),'found native result can resume after the already-completed search deadline')
  x.api:update();x.api:update();check(x.stats().starts==1 and x.stats().begins==1,'found receipt is reused exactly once without searching')
  x.api:stop();check(x.api:resume(),'accepted startup can pause before its first advisor action')
  x.api:update();x.publish();x.api:update()
  check(x.stats().starts==1 and x.stats().actions==1,'accepted startup Resume never starts its run a second time')
end
do
  local x=fixture();run_to_play(x,{max_runs=1});x.api:stop()
  x.g.GAME.chips=1000;x.g.GAME.blind.boss=true;x.g.GAME.round_resets.ante=8;x.g.GAME.round=23
  x.f.end_round();x.f.win_game();x.win_ui()
  check(x.api:resume(),'paused run retains its original terminal monitor through actual callbacks')
  x.api:update();x.api:update()
  check(x.api:status().outcomes.wins==1 and event_count(x,'run_finished')==1,
    'same original win accounting is classified once after Resume')
  x.api:update();check(x.api:status().outcomes.wins==1,'resumed terminal receipt cannot duplicate win credit')
end
do
  for _,case in ipairs({'profile_id','profile_table','run_table','log_failure'})do
    local x=fixture();run_to_play(x);x.api:stop();local actions=x.stats().actions
    if case=='profile_id'then x.g.SETTINGS.profile=2;x.g.PROFILES[2]={}
    elseif case=='profile_table'then x.g.PROFILES[1]={deck_usage={},joker_usage={}}
    elseif case=='run_table'then x.g.GAME=snapshot.copy(x.g.GAME)
    else x.logfail() end
    local accepted=x.api:resume();if accepted then x.api:update()end
    check(not x.api:status().active and x.stats().actions==actions and x.stats().starts==1,
      'invalid '..case..' cannot resume gameplay or replace its session')
  end
  local x=fixture();run_to_play(x);x.api:stop();check(x.api:resume(),'pending Resume fixture accepts fresh request')
  x.g.GAME=snapshot.copy(x.g.GAME);x.api:update()
  check(not x.api:status().active and x.stats().actions==1,'game replacement while Resume settles fails closed')
end
do
  local x=fixture();run_to_play(x,{max_actions=2,run_seconds=100});local before=x.api:status()
  x.g.GAME=snapshot.copy(x.g.GAME);x.g.GAME.chips=0;x.g.GAME.won=true;x.publish()
  check(x.api:manual('Verified checkpoint loaded','checkpoint_loaded'),'verified checkpoint-loaded product notification is accepted')
  x.api:update();local after=x.api:status()
  check(after.active and after.run_id~=before.run_id and after.session_serial==before.session_serial and after.manual_continuations==1,
    'verified restored game adopts the same session with a separate manual intervention count')
  check(after.actions==1 and after.run_actions==1 and after.runs_started==1 and x.stats().actions==1,
    'checkpoint adoption performs no action and renews no counters')
  check(after.outcomes.wins==0 and event_count(x,'manual_checkpoint_continuation')==1,
    'loaded incidental won is not terminal evidence; checkpoint continuation has its own receipt')
  x.api:update();check(x.stats().actions==2,'fresh restored state can use only the remaining action allowance')
  x.publish();x.api:update();check(x.api:status().reason=='action_limit' and x.stats().actions==2,'checkpoint cannot renew the original action cap')
end
do
  for _,blocker in ipairs({'worker','unknown_goal'})do
  for _,limit in ipairs({'run_seconds','session_seconds'})do
    local x=fixture();run_to_play(x,{[limit]=10})
    x.g.GAME=snapshot.copy(x.g.GAME);x.publish();x.api:manual('Verified load','checkpoint_loaded')
    if blocker=='worker'then x.A.worker={}
    else local old=x.A.gold_stickers.capture;x.A.gold_stickers.capture=function()local g=old();g.metadata_status='unknown';return g end end
    x.time(10);x.api:update()
    check(not x.api:status().active and x.stats().actions==1,'pending checkpoint '..blocker..' cannot hide the original '..limit)
  end
  end
end
do
  local x=fixture();run_to_play(x,{max_actions=2});local before=x.api:status();x.api:stop()
  x.g.GAME=snapshot.copy(x.g.GAME);x.g.GAME.chips=0;x.publish()
  x.api:manual('Verified checkpoint loaded while stopped','checkpoint_loaded');x.api:update()
  local paused=x.api:status()
  check(not paused.active and paused.resume_available and paused.manual_continuations==1,
    'verified checkpoint while stopped preserves explicit Resume instead of silently restarting')
  check(paused.session_serial==before.session_serial and paused.actions==1 and paused.runs_started==1,
    'stopped checkpoint adoption keeps original session and consumed work')
  check(x.stats().actions==1 and x.stats().starts==1,'stopped checkpoint notification performs no gameplay or startup')
  check(x.api:resume(),'explicit Resume can continue the verified adopted checkpoint')
  x.api:update();x.publish();x.api:update()
  check(x.stats().actions==2 and x.stats().starts==1 and x.stats().begins==1,
    'restored continuation uses remaining original actions without a new run or search')
end
do
  for _,limit in ipairs({'run_seconds','session_seconds'})do
    local x=fixture();run_to_play(x,{[limit]=10});x.time(2);x.api:stop();x.time(10)
    local accepted=x.api:resume();if accepted then x.api:update()end
    check(not x.api:status().active and x.stats().actions==1 and x.stats().starts==1,
      'explicit Stop duration still consumes the original product '..limit)
  end
  local x=fixture();assert(x.api:start());x.time(2);x.api:stop();x.time(20);x.api:stop();x.time(50)
  check(x.api:resume(),'repeated Stop retains one pending arming continuation')
  x.api:update();x.g.SAVING=true;x.time(77.9);x.api:update()
  check(x.api:engaged() and x.stats().begins==0,'repeated Stop cannot lose excluded stopped time from the startup watchdog')
  x.time(78);x.api:update()
  check(not x.api:engaged() and x.stats().begins==0,'resumed arming retains its pre-stop active startup wait')
end
do
  local x=fixture();run_to_play(x);x.time(90);x.api:stop();x.time(100)
  check(x.api:resume(),'blocked Resume clock fixture accepts explicit same-session continuation')
  x.g.CONTROLLER.locks.frame=true;x.time(110);x.api:update()
  check(x.api:status_report().resume_pending and x.stats().actions==1,'blocked Resume samples and retains its latest monotonic anchor')
  x.time(105);x.api:update()
  check(not x.api:status().active and not x.api:engaged() and x.stats().actions==1 and x.stats().starts==1,
    'backwards time between blocked Resume updates fails closed without gameplay or startup')
end
print('advisor_auto_run_product: '..checks..' checks passed')
