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
  check(not x.api:status().active,'checkpoint activity stops active automation')
  x.api:update();check(not x.api:status().search_draining,'owned cancelled worker drains without launching its late match')
  check(x.stats().starts==0,'late result after manual stop is never launched')
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
  check(r.requested and not r.busy and r.owner=='auto' and r.text:find('Keyboard input.',1,true),
    'auto pending cancellation reason remains observable with consent flag')
  x.api:update();check(x.stats().begins==0 and x.stats().actions==0,'pure reports cannot rearm stopped auto-run')
end
do
  local x=fixture();assert(x.api:start());x.api:update();x.api:update()
  local r=x.api:status_report()
  check(r.requested and r.busy and r.phase=='searching','actual auto controller phase is exposed')
  x.api:manual('Stop while native worker drains.')
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

print('advisor_auto_run_product: '..checks..' checks passed')
