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
  local e={starts=0,deletes=0,searches=0,cancels=0,changed=0,closed=0,input=0,events={},now=0,calls={}}
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
      e.calls[#e.calls+1]=copy(q)
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
    now=function()return e.now end,pending=function()return e.pending end,
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
-- Synthetic worker receipts and clocks only. No native/source invocation.
local strict_targets='Yorick\31Brainstorm\31Burnt Joker\31Perkeo\31'
local relaxed_targets='Yorick\31Brainstorm\31\31Perkeo\31'
local function staged(e,options)
  options=options or {};options.burnt_fallback=true
  return e.begin(options)
end
do
  local e=env();local request=staged(e)
  check(request.query.budget_ms==27000 and request.requested_budget_ms==30000,'one request retains27s native/30s product ceiling')
  check(e.request.budget_ms==9000 and e.request.target_jokers==strict_targets,'first phase requires Burnt with at most9s')
  check(e.api.status:find('Burnt first',1,true),'first phase names its stronger request')
  e.now=.1;e.finish();local result=e.api.poll('owner')
  check(result.exited and result.status=='found'and e.searches==1,'immediate strict success never starts fallback')
  check(#result.found.receipt.stages==1 and not result.found.receipt.burnt_relaxed,'strict success preserves one exact stage receipt')
  check(e.api.launch(result.found,'owner'),'strict result remains launchable')
  check(#e.g.GAME.filter_info.normal_opening.targets==4 and e.g.GAME.filter_info.collection_search.burnt_required,
    'strict result keeps the actual mandatory Burnt target')
end
do
  local e=env();local request=staged(e,{minimum_distinct=4,first_ante=4,last_ante=8})
  e.now=1;e.finish('not_found','');local pending=e.api.poll('owner')
  check(not pending.exited and pending.status=='searching'and pending.request_id==request.request_id and pending.generation==2,
    'one logical request owns a fresh second native generation')
  check(e.searches==2 and e.live and e.B.native_search_busy and e.request.budget_ms==18000,'second phase is capped by the unspent18s allocation')
  check(e.request.target_jokers==relaxed_targets and e.request.target_locations=='soul_pack\31by_ante_5\31ante_1\31soul_pack\31ante_1',
    'only Burnt fixed requirement is removed with valid five-slot timing')
  check(e.request.minimum_distinct==4 and e.request.first_ante==4 and e.request.last_ante==8 and
    e.request.reject_perishable_targets and e.request.interchangeable_copies and e.request.tag=='Charm Tag',
    'fallback preserves strict missing quota, window, copy and no-Perishable opening guards')
  check(e.request.missing_names:find('Burnt Joker',1,true),'still-missing Burnt remains eligible quota credit; relaxation does not fake progress')
  check(e.seed==M.seed_at(150) and e.B.collection_search_cursor==151,'fallback uses the advanced independent cursor, not a silent reset')
  check(e.api.status:find('without required Burnt',1,true),'waiting status explicitly identifies relaxed Burnt')
  e.now=2;e.finish();local done=e.api.poll('owner')
  local receipt=done.found.receipt
  check(receipt.burnt_relaxed and #receipt.stages==2 and receipt.total_native_reserved_ms==27000 and receipt.original_native_budget_ms==27000,
    'both native stage receipts and nonrenewed cumulative cap are retained')
  check(receipt.stages[1].receipt.status=='not_found'and receipt.stages[1].allocated_budget_ms==9000 and
    receipt.stages[2].receipt.request.target_jokers==relaxed_targets,'failure and actual relaxed query remain separately auditable')
  check(e.api.launch(done.found,'owner'),'owned relaxed match can launch once')
  local info=e.g.GAME.filter_info
  check(info.filter_params[18]==relaxed_targets and #info.normal_opening.targets==3 and
    info.normal_opening.targets[3].key=='j_perkeo'and not info.collection_search.burnt_required,
    'launched filter and explicit recipe do not falsely retain mandatory Burnt')
  local route=assert(opening.parse_filter(info,'b_red',8,e.g.GAME.pseudorandom.seed))
  check(route.legendary_targets[1]=='j_yorick'and route.legendary_targets[2]=='j_perkeo',
    'relaxed metadata is accepted by the real normal-opening parser')
  check(not e.api.launch(done.found,'owner')and e.starts==1,'relaxed receipt is still one use')
end
do
  local e=env();staged(e);e.now=9.5;e.finish('timeout','');e.api.poll('owner')
  check(e.searches==2 and e.request.budget_ms==17500,'drained strict timeout receives only original27s wall remainder')
  e.now=27;e.finish();local result=e.api.poll('owner')
  check(result.status=='timeout'and not result.found and e.starts==0,'a match at the original deadline cannot launch')
  check(e.searches==2,'no third phase renews an exhausted request')
end
do
  local e=env();staged(e);e.now=28;e.finish('not_found','');local result=e.api.poll('owner')
  check(result.status=='timeout'and e.searches==1 and not result.found,'delayed first receipt cannot start fallback after the outer native envelope')
end
do
  local e=env();staged(e,{budget_ms=3000});check(e.request.budget_ms==1000,'short explicit budgets split proportionally')
  e.now=.5;e.finish('not_found','');e.api.poll('owner')
  check(e.request.budget_ms==2000 and e.calls[1].budget_ms+e.calls[2].budget_ms==3000,'small request never gets30 seconds by fallback')
end
do
  local e=env();e.begin({burnt_fallback=false});check(e.request.budget_ms==27000,'explicit required Burnt retains single full phase')
  e.finish('not_found','');local result=e.api.poll('owner')
  check(result.exited and result.status=='not_found'and e.searches==1,'explicit fallback-off never relaxes')
end
for _,status in ipairs({'error','invalid','busy','cancelled'})do
  local e=env();staged(e);e.finish(status,'');local result=e.api.poll('owner')
  check(result.exited and result.status==status and e.searches==1 and not result.found,'errors and cancellations do not become fallback: '..status)
end
for _,change in ipairs({'input','profile','population','run','state','generation','query'})do
  local e=env();staged(e);e.finish('not_found','')
  if change=='input'then e.input=e.input+1
  elseif change=='profile'then e.goal.profile_id=2
  elseif change=='population'then e.complete('j_joker')
  elseif change=='run'then e.g.GAME=copy(e.g.GAME)
  elseif change=='state'then e.g.STATE=4
  elseif change=='generation'then e.ready.generation=99
  elseif change=='query'then e.ready.request.target_jokers=relaxed_targets end
  local result=e.api.poll('owner')
  check(result.exited and (result.status=='cancelled'or result.status=='error')and e.searches==1 and not result.found,
    'changed/foreign first-phase context cannot start fallback: '..change)
end
for _,stage in ipairs({1,2})do
  local e=env();staged(e)
  if stage==2 then e.finish('not_found','');e.api.poll('owner')end
  e.api.cancel('owner','user stop');check(e.live and e.B.native_search_busy,'cancellation keeps worker ownership until actual exit')
  e.finish();local result=e.api.poll('owner')
  check(result.status=='cancelled'and not result.found and e.searches==stage and e.starts==0,
    'late found after stop cannot launch or restart: phase'..stage)
end
do
  local e=env();staged(e);e.finish('not_found','');e.api.poll('owner');e.finish();e.ready.generation=1
  local result=e.api.poll('owner');check(result.status=='error'and not result.found,'old generation cannot impersonate relaxed phase')
end
for _,bad_time in ipairs({-1,0/0,math.huge})do
  local e=env();e.now=bad_time;local request=assert(e.api.prepare({burnt_fallback=true}))
  check(not e.api.begin(request,'owner')and e.searches==0,'invalid clock prevents staged dispatch')
end
do
  local e=env();e.now=5;staged(e);e.now=4;e.finish('not_found','')
  local result=e.api.poll('owner');check(result.status=='error'and e.searches==1,'backward clock never renews stage allowance')
end
do
  local e=env();staged(e);e.now=26.9;e.finish()
  local poll=e.runtime.poll;e.runtime.poll=function(token)local value=poll(token);e.now=27.1;return value end
  local result=e.api.poll('owner');check(result.status=='timeout'and not result.found,'poll-return timing is rechecked before accepting a late match')
end
do
  local e=env();staged(e);e.finish('not_found','');e.start_error=true
  local first=e.api.poll('owner')
  check(e.searches==2 and not first.exited and e.live and e.cancels==1,'partially failed second dispatch is cancelled and drained without new phase')
  e.finish();local done=e.api.poll('owner')
  check(done.exited and done.status=='error'and not done.found and e.starts==0,'partial relaxed startup cannot revive a found receipt')
end
do
  local e=env();staged(e);e.finish('not_found','')
  local poll=e.runtime.poll;e.runtime.poll=function(token)local value=poll(token);e.live=true;e.B.native_search_busy=true;return value end
  local result=e.api.poll('owner')
  check(not result.exited and result.status=='stopping'and e.searches==1 and e.cancels==1,
    'an early receipt does not release the actual native worker or start phase two')
end
do
  local e=env();check(query.prepare(e.goal,gold,{burnt_fallback='yes'})==nil,'nonboolean relaxation option is rejected')
  local q=assert(query.prepare(e.goal,gold,{}));check(q.burnt_fallback==false and q.burnt_required==true,'manual query default remains an exact required-Burnt request')
end

print('advisor_burnt_fallback: '..checks..' checks passed')
