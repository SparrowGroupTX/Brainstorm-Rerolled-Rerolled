local F=dofile('Brainstorm/Core/auto_run_product.lua')
local C=dofile('Brainstorm/Advisor/auto_run.lua')
local T=dofile('Brainstorm/Core/auto_terminal.lua')
local S=dofile('Brainstorm/Core/auto_run_settlement.lua')
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
  api=F.attach(B,{game=function()return g end,advisor=A,search=search,controller=C,terminal=T,settlement=S,
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
for _,case in ipairs({
 {options={},expected=true},
 {options={legendary_fallback=false},expected=false},
 {options={search_request={legendary_fallback=false}},expected=false},
 {options={legendary_fallback=true},expected=true},
 {options={quota_mode='strict',minimum_distinct=0},expected=true},
})do
 local x=fixture();local before=snapshot.fingerprint(case.options)
 check(x.api:start(case.options),'explicit auto-run may configure alternate opening')
 x.api:update();x.api:update()
 check(x.request().recipe.legendary_fallback==case.expected,'only auto facade defaults to alternate opening; explicit false preserved')
 check(snapshot.fingerprint(case.options)==before,'caller configuration never rewritten')
 if case.options.quota_mode then
  check(x.request().recipe.quota_mode=='strict'and x.request().recipe.minimum_distinct==0,'strict quota remains strict before query qualification')
 end
 x.search.status='Canio + Perkeo. Searching with Burnt first (9s).'
 check(x.api:status().state=='searching'and x.api.status_text==x.search.status,'auto UI shows bound missing-Legendary recipe')
 x.api:stop('test cleanup')
end
do
 local x=fixture()
 check(not x.api:start({legendary_fallback=true,search_request={legendary_fallback=false}}),'conflicting alternate-opening preference fails before work')
 check(x.stats().begins==0 and not x.B.config.advisor.player_logging,'conflicting preference cannot enable work')
end

local writes,manual_options=0,nil
Brainstorm={config={advisor={gold_run={quota_mode='auto'}}},AutoRun={status_text='Auto-run is off.',stop=function()end},
 CollectionSearchProduct={stop=function()end,start_manual=function(q)manual_options=q;return true end},writeConfig=function()writes=writes+1 end}
G={FUNCS={},UIT={ROOT='ROOT',R='R',T='T'},C={CLEAR={},GREEN={},WHITE={},ORANGE={}}}
UIBox_button=function(args)return {n='BUTTON',config=args}end
local UI=dofile('Brainstorm/UI/collection_run.lua');local page=Brainstorm.createCollectionRunPage();local texts={}
local function walk(node)
 if node.config and node.config.text then texts[node.config.text]=true end
 for _,child in ipairs(node.nodes or {})do walk(child)end
end
walk(page)
check(texts['With Missing: Auto, auto-run may use a missing Legendary + Perkeo.'],'page discloses the automatic-only alternate opening')
check(texts['Default: Yorick + Perkeo Charm. Copy by Ante 5; Burnt preferred.'],'usual preset is explicitly the default')
G.FUNCS.brainstorm_collection_search_start()
check(manual_options.legendary_fallback==nil,'manual button does not gain automatic-only opening permission')
check(writes==0,'displaying and manually starting does not migrate stored search settings')
print('Legendary automatic forwarding: '..checks..' checks; no native/source gameplay')
