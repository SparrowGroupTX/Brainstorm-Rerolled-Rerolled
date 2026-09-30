local path='tools/advisor_eval/development300/burnt_fallback/Brainstorm/Core/'
local M=dofile(path..'collection_search_product.lua')
local query=dofile('tools/advisor_eval/development300/burnt_fallback/Brainstorm/Advisor/collection_search.lua')
local gold=dofile('Brainstorm/Advisor/gold_search.lua')
local stickers=dofile('Brainstorm/Advisor/gold_stickers.lua')
local opening=dofile('Brainstorm/Advisor/normal_opening.lua')
opening.gold_stickers=stickers;opening.gold_search=gold
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function copy(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out end
local function env()
  local e={starts=0,deletes=0,searches=0,cancels=0,changed=0,closed=0,input=0,events={}}
  e.g={GAME={round=1,pseudorandom={seed='OLD'},selected_back={effect={center={key='b_blue'}}}},
    STAGE=2,STAGES={MAIN_MENU=1,RUN=2},STATE=3,STATES={SELECTING_HAND=3,SHOP=4,BLIND_SELECT=5,ROUND_EVAL=6,GAME_OVER=7},
    STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},SETTINGS={profile=1},P_CENTERS={
      b_red={key='b_red',set='Back'},b_zodiac={key='b_zodiac',set='Back'}},FUNCS={}}
  e.goal={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=0,missing=150,unknown=0},by_key={}}
  for _,key in ipairs(stickers.target_keys())do e.goal.by_key[key]={key=key,status='missing'}end
  e.B={collection_search_cursor=100,config={ar_filters={keep='existing'},advisor={enabled=false}},Checkpoints={},
    Advisor={settings_changed=function()e.changed=e.changed+1 end}}
  e.runtime={busy=function()return e.live end,
    start=function(q,seed,token)
      e.searches=e.searches+1;e.live=true;e.B.native_search_busy=true
      e.request=copy(q);e.seed=seed;e.token=token;e.generation=e.searches
      if e.start_error then return nil,'start error'end
      return e.generation
    end,
    poll=function(token)
      e.last_poll_token=token
      if e.ready then local r=e.ready;e.ready=nil;e.live=false;e.B.native_search_busy=false;return r end
    end,
    stop=function(reason)e.cancels=e.cancels+1;e.cancel_reason=reason;return true end}
  e.api=M.attach(e.B,{game=function()return e.g end,runtime=e.runtime,query=query,gold=gold,stickers=stickers,
    progress=function()return e.goal end,input_token=function()return e.input end,
    pending=function()return e.pending end,
    exit_overlay=function()e.closed=e.closed+1;if not e.delay_close then e.g.OVERLAY_MENU=nil;e.g.SETTINGS.paused=false end end,
    back=function(center)return {effect={center=center}}end,
    delete_run=function(g)e.deletes=e.deletes+1;if e.delete_error then error('delete error')end end,
    start_run=function(g,args)
      e.starts=e.starts+1;e.start_args=copy(args)
      if e.start_error_game then error('start error')end
      g.GAME={selected_back=g.GAME.selected_back,pseudorandom={seed=args.seed},round=0,stake=args.stake}
    end,on_event=function(kind,data)e.events[#e.events+1]={kind=kind,data=data}end})
  function e.finish(status,seed)
    e.ready={generation=e.generation,status=status or 'found',profile_id=e.request.profile_id,profile_token=e.token,
      request=copy(e.request),result={schema=1,status=status or 'found',seed=seed or M.seed_at(200),screened=50,
        exact_candidates=1,seconds=.01,budget_ms=e.request.budget_ms,threads=2,route=e.request.route},starts_run=false}
  end
  function e.begin(options,owner)
    local r=assert(e.api.prepare(options));assert(e.api.begin(r,owner or 'owner'));return r
  end
  function e.found(options,owner)
    local r=e.begin(options,owner);e.finish();return assert(e.api.poll(owner or 'owner')).found,r
  end
  function e.complete(key)
    e.goal.by_key[key].status='complete';e.goal.counts.missing=e.goal.counts.missing-1;e.goal.counts.complete=e.goal.counts.complete+1
  end
  return e
end
do
  for _,index in ipairs({1,2,8,9,42,100,200,9999,66231629136,2318107019760})do
    check(M.seed_id(M.seed_at(index))==index,'native variable-length seed enumeration round trip')
  end
  check(M.seed_at(1)=='1' and M.seed_at(8)=='11111111' and M.seed_at(9)=='21111111','native enumeration boundary values')
  check(M.seed_at(2318107019760)=='ZZZZZZZZ','last native seed')
  for _,index in ipairs({0,-1,.5,2318107019761,math.huge})do check(M.seed_at(index)==nil,'invalid cursor rejected')end
  for _,seed in ipairs({'','0','A0','123456789','a'})do check(M.seed_id(seed)==nil,'invalid seed rejected')end
end
do
  local e=env();check(e.searches==0 and e.starts==0,'attach has no side effects')
  local r=assert(e.api.prepare({budget_ms=30000,minimum_distinct=4,first_ante=4,last_ante=8}))
  check(r.query.budget_ms==27000 and r.requested_budget_ms==30000,'native budget leaves three seconds of ceiling')
  check(r.query.minimum_distinct==4 and r.query.first_ante==4 and r.query.last_ante==8,'quota and Ante window preserved')
  check(r.query.interchangeable_copies==true and r.query.reject_perishable_targets,'copy alternative and no-perishable preset')
  check(e.searches==0 and e.starts==0 and e.B.config.ar_filters.keep=='existing','prepare leaves config and game unchanged')
  check(not e.api.begin(r,nil),'owner required')
  local changed=copy(r);check(not e.api.begin(changed,'owner'),'unregistered request rejected')
  r.query.budget_ms=1;check(not e.api.begin(r,'owner'),'mutated request rejected')
  r.query.budget_ms=27000;assert(e.api.begin(r,'owner'))
  check(e.searches==1 and e.starts==0 and e.B.native_search_busy,'begin starts only one worker')
  check(e.seed==M.seed_at(100) and e.B.collection_search_cursor==101,'independent cursor reserved before dispatch')
  check(not e.api.begin(r,'owner') and not e.api.begin(assert(e.api.prepare()),'second'),'spent request and overlap rejected')
  check(e.api.poll('other')==nil,'foreign poll rejected')
  local pending=e.api.poll('owner');check(not pending.exited and pending.status=='searching','poll waits without blocking')
  e.finish();local result=e.api.poll('owner')
  check(result.exited and result.status=='found' and result.found.seed==M.seed_at(200),'found bound after actual exit')
  check(e.B.collection_search_cursor==201,'next cursor advances past match')
  check(e.api.poll('owner').found==result.found,'same owned result retained across polls')
  check(not e.api.launch(result.found,'other'),'foreign launch rejected')
  check(e.api.launch(result.found,'owner'),'owned exact result launches')
  check(e.deletes==1 and e.starts==1 and e.changed==1,'one original delete/start/settings callback')
  check(e.start_args.stake==8 and e.start_args.seed==result.found.seed and e.start_args.challenge==nil,'normal Gold arguments exact')
  check(e.g.GAME.selected_back.effect.center==e.g.P_CENTERS.b_red,'requested Red Deck selected')
  check(e.g.GAME.used_filter and not e.g.GAME.seeded,'existing searched-normal provenance semantics')
  local f=e.g.GAME.filter_info
  check(f.native_api_version==9 and #f.filter_params==28 and f.filter_params[1]==result.found.seed,'complete v9 receipt uses actual run seed')
  check(f.required_soul_count==2 and not f.multi_soul_pack_consumed,'one-use real two-Soul opening marker')
  check(f.collection_search.copy_alternatives[2]=='j_blueprint' and f.collection_search.future_acquisition_verified==false,'copy alternatives are conditional metadata')
  local recipe=assert(opening.parse_filter(f,'b_red',8,result.found.seed))
  check(recipe.legendary_targets[1]=='j_yorick' and recipe.legendary_targets[2]=='j_perkeo','current normal opening module accepts exact recipe')
  check(not e.api.launch(result.found,'owner') and e.starts==1,'launch receipt cannot be reused')
end
for _,change in ipairs({'profile','population','unknown','input','run','seed','state','round'})do
  local e=env();e.begin()
  if change=='profile'then e.goal.profile_id=2
  elseif change=='population'then e.complete('j_joker')
  elseif change=='unknown'then e.goal.by_key.j_joker.status='unknown';e.goal.counts.missing=149;e.goal.counts.unknown=1
  elseif change=='input'then e.input=1
  elseif change=='run'then e.g.GAME=copy(e.g.GAME)
  elseif change=='seed'then e.g.GAME.pseudorandom.seed='NEW'
  elseif change=='state'then e.g.STATE=4
  else e.g.GAME.round=2 end
  e.finish();local result=e.api.poll('owner')
  check(result.exited and result.status=='cancelled' and not result.found,'changed context rejects late found: '..change)
  check(e.starts==0 and e.cancels>0,'context change never starts game: '..change)
end
do
  local e=env();e.begin();check(not e.api.cancel('other','wrong'),'foreign stop rejected')
  check(e.api.cancel('owner','user stopped'),'owned stop accepted')
  check(e.B.native_search_busy and not e.api.poll('owner').exited,'stop retains active native latch until actual exit')
  e.finish();local r=e.api.poll('owner');check(r.status=='cancelled' and not r.found and e.starts==0,'post-stop found never launches')
  local fresh=assert(e.api.prepare());assert(e.api.begin(fresh,'next'));check(e.seed==M.seed_at(101),'cancel does not reset cursor')
end
do
  local e=env();e.begin();e.finish('not_found','');local r=e.api.poll('owner')
  check(r.status=='not_found' and not r.found and e.B.collection_search_cursor==150,'miss advances by reported completed count')
  e.api.update();check(e.searches==1,'miss never renews search automatically')
end
do
  local e=env();e.begin();e.finish('timeout','');check(e.api.poll('owner').status=='timeout','timeout exposed honestly')
  e.api.update();check(e.searches==1 and e.starts==0,'timeout neither restarts nor launches')
end
for _,change in ipairs({'generation','token'})do
  local e=env();e.begin();e.finish()
  if change=='generation'then e.ready.generation=99 else e.ready.profile_token='wrong'end
  check(e.api.poll('owner').status=='error' and e.starts==0,'mismatched native binding rejected')
end
for _,block in ipairs({'checkpoint','saving','pending','overlay','paused','drag','lock','locked','text','state_incomplete','screenwipe','play','stop_use','ar_active','stage','state'})do
  local e=env();local r=assert(e.api.prepare())
  if block=='checkpoint'then e.B.Checkpoints.pending={}
  elseif block=='saving'then e.B.save_pending=true
  elseif block=='pending'then e.pending=true
  elseif block=='overlay'then e.g.OVERLAY_MENU={}
  elseif block=='paused'then e.g.SETTINGS.paused=true
  elseif block=='drag'then e.g.CONTROLLER.dragging.target={}
  elseif block=='lock'then e.g.CONTROLLER.locks.busy=true
  elseif block=='locked'then e.g.CONTROLLER.locked=true
  elseif block=='text'then e.g.CONTROLLER.text_input_hook={}
  elseif block=='state_incomplete'then e.g.STATE_COMPLETE=false
  elseif block=='screenwipe'then e.g.screenwipe={}
  elseif block=='play'then e.g.play={cards={{}}}
  elseif block=='stop_use'then e.g.GAME.STOP_USE=1
  elseif block=='ar_active'then e.B.ar_active=true
  elseif block=='stage'then e.g.STAGE=9
  else e.g.STATE=99 end
  check(not e.api.begin(r,'owner') and e.searches==0,'unsafe begin rejected: '..block)
end
do
  local e=env();local f=e.found();e.g.OVERLAY_MENU={}
  local ok,why,retryable=e.api.launch(f,'owner')
  check(not ok and retryable and e.deletes==0,'unsettled launch waits without consuming result')
  e.g.OVERLAY_MENU=nil;check(e.api.launch(f,'owner') and e.starts==1,'same receipt launches after screen settles')
end
do
  local e=env();local f=e.found();f.receipt.result.screened=999
  check(not e.api.launch(f,'owner') and e.deletes==0,'modified found receipt cannot launch')
end
do
  local e=env();local f=e.found();e.complete('j_joker')
  check(not e.api.launch(f,'owner') and e.deletes==0,'new Gold award invalidates already-found result')
end
for _,failure in ipairs({'delete','start'})do
  local e=env();local f=e.found()
  e.delete_error=failure=='delete';e.start_error_game=failure=='start'
  check(not e.api.launch(f,'owner'),'original callback error exposed')
  check(not e.api.launch(f,'owner') and e.deletes==1,'exception cannot repeat consumed delete/start')
end
do
  local e=env();local f=e.found({deck_name='Zodiac Deck',interchangeable_copies=false,budget_ms=1000})
  assert(e.api.launch(f,'owner'))
  check(e.g.GAME.selected_back.effect.center==e.g.P_CENTERS.b_zodiac,'Zodiac selection exact')
  check(e.g.GAME.filter_info.collection_search.copy_alternatives[2]==nil and e.request.budget_ms==1000,'explicit copy-only and smaller budget preserved')
end
do
  local e=env();e.g.OVERLAY_MENU={};e.g.SETTINGS.paused=true;e.delay_close=true
  check(e.api.start_manual({}) and e.closed==1 and e.searches==0,'explicit manual start closes overlay before worker')
  e.api.update();check(e.searches==0,'delayed overlay exit waits without blocking')
  e.g.OVERLAY_MENU=nil;e.g.SETTINGS.paused=false;e.api.update()
  check(e.searches==1 and e.starts==0,'manual starts one worker after settle')
  e.finish();e.api.update();check(e.starts==1 and e.deletes==1,'manual found starts one run')
  for _=1,3 do e.api.update()end
  check(e.starts==1 and e.searches==1,'manual mode never autoplays or loops')
end
do
  local e=env();e.g.OVERLAY_MENU={};e.delay_close=true;assert(e.api.start_manual({}))
  assert(e.api.stop('manual cancelled'));e.g.OVERLAY_MENU=nil;e.api.update()
  check(e.searches==0 and e.starts==0,'stop while overlay closes prevents delayed search')
end
do
  local e=env();assert(e.api.start_manual({}));e.input=1;e.api.update()
  check(e.searches==0 and e.starts==0,'manual input before dispatch revokes queued consent')
end
do
  local e=env();e.start_error=true
  check(not e.api.begin(assert(e.api.prepare()),'owner'),'partial native start returns error')
  check(e.B.native_search_busy and e.cancels==1,'partial start cancellation retains native latch')
  e.finish();check(e.api.poll('owner').status=='error' or e.api.poll('owner').status=='cancelled','partial start late receipt rejected')
  check(e.starts==0,'partial start never launches game')
end
do
  local e=env();e.B.collection_search_cursor=2318107019761
  check(not e.api.begin(assert(e.api.prepare()),'owner'),'exhausted cursor never wraps into repeated automatic searches')
end
do
  local e=env();e.goal.metadata_status='unavailable'
  check(not e.api.prepare() and not e.api.start_manual({}) and e.searches==0,'unknown loaded history prevents manual search')
end
do
  local e=env();local request=assert(e.api.prepare());e.complete('j_joker')
  check(not e.api.begin(request,'owner') and e.searches==0,'population change between prepare and begin rejected')
end
do
  local e=env();e.B.collection_search_cursor=nil
  local facade=M.attach(e.B,{runtime=e.runtime,query=query,gold=gold,game=function()return e.g end,
    progress=function()return e.goal end,wall_time=function()return 1000 end})
  assert(facade.begin(assert(facade.prepare()),'clock'))
  check(e.seed==M.seed_at(1001),'cursor initialization uses independent wall time, never game RNG')
end
do
  local e=env();local f=e.found();e.B.native_search_busy=true
  local ok,why,retryable=e.api.launch(f,'owner')
  check(not ok and retryable and e.deletes==0,'foreign native work blocks otherwise found launch')
end
do
  local e=env();local f=e.found();e.g.P_CENTERS.b_red.mod={}
  check(not e.api.launch(f,'owner') and e.deletes==0,'modified requested deck rejected before deletion')
end
do
  local e=env();e.g.STAGE=e.g.STAGES.MAIN_MENU;e.g.STATE=99;e.g.STATES.MENU=99
  check(e.api.begin(assert(e.api.prepare()),'menu'),'settled main menu can request a normal run')
end
do
  local e=env();e.g.PROFILES={[1]={joker_usage={}}};e.g.P_STAKES={}
  for level,name in ipairs({'white','red','green','black','blue','purple','orange','gold'})do
    e.g.P_STAKES['stake_'..name]={set='Stake',order=level,stake_level=level}
  end
  for _,key in ipairs(stickers.target_keys())do e.g.P_CENTERS[key]={key=key,set='Joker'}end
  local facade=M.attach(e.B,{runtime=e.runtime,query=query,gold=gold,stickers=stickers,game=function()return e.g end})
  check(facade.prepare().profile_id==1,'default progress path reads only already-loaded game tables')
end
do
  local e=env();e.g.LOADING={font={synthetic_font=true}}
  check(e.api.start_manual({}),'cached original boot font permits explicit manual Start')
  e.api.update();check(e.searches==1,'original boot-cache shape no longer blocks manual search dispatch')
  e.finish();e.api.update()
  check(e.starts==1 and e.g.LOADING.font.synthetic_font,'found receipt starts once while preserving the boot cache')
end
for _,value in ipairs({true,{}, {font={synthetic_font=true},active=true},{font='unexpected'},17,
    {font={synthetic_font=true},[1]='unknown_extra'},setmetatable({font={}},{})})do
  local e=env();e.g.LOADING=value
  check(e.api.start_manual({}),'loading guard remains deferred until fresh explicit-start update')
  e.api.update()
  check(e.searches==0 and e.starts==0 and e.api.status=='Waiting: Game loading is active.',
      'active/unknown loading shape blocks and explains the actual wait')
end
for _,block in ipairs({function(e)e.g.STATE_COMPLETE=false end,function(e)e.g.CONTROLLER.locked=true end,
    function(e)e.g.CONTROLLER.locks.frame=true end,function(e)e.g.CONTROLLER.locks.frame_set=true end,
    function(e)e.B.Checkpoints={pending={slot=1}}end,function(e)e.g.SAVING=true end,
    function(e)e.g.GAME.STOP_USE=1 end})do
  local e=env();e.g.LOADING={font={}};block(e)
  local queued=e.api.start_manual({})
  if queued then e.api.update()end
  check(e.searches==0 and e.starts==0 and (not queued or e.api.status:find('Waiting:',1,true)),
      'boot-cache exception preserves real transition/input/checkpoint/save/action guards and wait detail')
end
do
  local e=env();e.g.LOADING={font={}};e.g.STAGE=e.g.STAGES.MAIN_MENU;e.g.STATES.MENU=99;e.g.STATE=99;e.g.STATE_COMPLETE=false
  check(e.api.start_manual({}),'actual main-menu shape accepts explicit Start with persistent boot cache')
  e.api.update();check(e.searches==1,'main MENU needs no gameplay STATE_COMPLETE latch to begin search')
end
for _,complete in ipairs({false,true})do
  local e=env();e.g.LOADING={font={}};e.g.STAGE=e.g.STAGES.MAIN_MENU;e.g.STATES.MENU=99;e.g.STATE=98;e.g.STATE_COMPLETE=complete
  check(not e.api.can_begin(),'splash/demo/other menu states stay unavailable regardless of latch')
end
for _,block in ipairs({function(e)e.g.CONTROLLER.locked=true end,function(e)e.g.CONTROLLER.locks.frame=true end,
    function(e)e.g.CONTROLLER.dragging={target={}}end,function(e)e.g.OVERLAY_MENU={}end,
    function(e)e.B.Checkpoints={pending={slot=1}}end})do
  local e=env();e.g.LOADING={font={}};e.g.STAGE=e.g.STAGES.MAIN_MENU;e.g.STATES.MENU=99;e.g.STATE=99;e.g.STATE_COMPLETE=false
  block(e);check(not e.api.can_begin(),'settled-menu exception preserves input/overlay/checkpoint guards')
end
do
  local e=env()
  e.B.Advisor.settings_changed=function()
    e.changed=e.changed+1;e.invalidation_stopped=e.api.stop('Advisor settings changed.')
  end
  assert(e.api.start_manual({}));e.api.update();e.finish();e.api.update()
  check(e.starts==1 and e.changed==1,'successful manual launch still invalidates old advisor state once')
  check(e.invalidation_stopped==false,'completed manual owner is absent before settings invalidation')
  check(e.api.status=='Gold run started. Advisor play remains user-controlled.',
      'settings invalidation cannot overwrite successful manual launch status')
  e.api.update();check(e.starts==1 and not e.api.stop('late settings change'),
      'cleared manual owner cannot replay or turn a completed start into cancellation')
end
do
  local e=env();e.g.OVERLAY_MENU={};e.delay_close=true;assert(e.api.start_manual({}))
  check(e.api.stop('Advisor settings changed.')and e.api.status=='Advisor settings changed.',
      'a genuinely pending manual owner is still cancelled by settings invalidation')
  e.g.OVERLAY_MENU=nil;e.api.update();check(e.searches==0 and e.starts==0,'pending invalidation never dispatches later')
end
print('collection_product_fixture passed '..checks..' checks')
