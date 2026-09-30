-- Existing facade only, manufactured metadata and mock receipts. This does not
-- load native code, start a worker, search seeds, launch a run, or read saves.
local M=dofile('Brainstorm/Core/collection_search_product.lua')
local Query=dofile('Brainstorm/Advisor/collection_search.lua')
local Gold=dofile('Brainstorm/Advisor/gold_search.lua')
local Stickers=dofile('Brainstorm/Advisor/gold_stickers.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r end
local function forbidden()error('No native worker, gameplay, randomness, persistence or save access in this fixture')end
math.random=forbidden;pseudorandom=forbidden;pseudoseed=forbidden
local function facade(seconds,restored)
 local e={starts=0,wall_calls=0,events={}}
 e.B={collection_search_cursor=restored,config={ar_filters={keep='current'},advisor={enabled=true}},writeConfig=forbidden}
 e.g={GAME={round=1,pseudorandom={seed='PUBLIC'}},STAGE=2,STAGES={MAIN_MENU=1,RUN=2},STATE=4,
  STATES={MENU=1,SELECTING_HAND=3,SHOP=4},STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},SETTINGS={profile=1}}
 e.goal={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
  counts={total=150,complete=0,missing=150,unknown=0},by_key={}}
 for _,key in ipairs(Stickers.target_keys())do e.goal.by_key[key]={key=key,status='missing'}end
 e.runtime={busy=function()return e.busy end,
  start=function(q,seed,token)
   e.starts=e.starts+1;e.start_index=assert(M.seed_id(seed));e.query=copy(q);e.token=token;e.busy=true
   e.cursor_at_dispatch=e.B.collection_search_cursor
   if e.start_failure then return nil,'manufactured dispatch failure'end
   return e.starts
  end,
  poll=function()
   if not e.ready then return nil end
   local r=e.ready;e.ready=nil;e.busy=false;return r
  end,
  stop=function()e.stopped=true end}
 e.api=M.attach(e.B,{runtime=e.runtime,query=Query,gold=Gold,game=function()return e.g end,
  progress=function()return e.goal end,input_token=function()return 0 end,
  wall_time=function()e.wall_calls=e.wall_calls+1;return seconds end,
  now=function()return 0 end,delete_run=forbidden,start_run=forbidden,back=forbidden,
  on_event=function(kind,data)e.events[#e.events+1]={kind=kind,data=copy(data)}end})
 function e.begin()
  local request=assert(e.api.prepare({burnt_fallback=false,minimum_distinct=0}))
  local accepted,why=e.api.begin(request,'fixture')
  return accepted,why,request
 end
 function e.finish(status,screened,match)
  e.ready={generation=e.starts,profile_token=e.token,request=copy(e.query),status=status,
   result={schema=1,status=status,screened=screened,seed=match and assert(M.seed_at(match))or nil}}
  return assert(e.api.poll('fixture'))
 end
 return e
end

-- Two isolated boots two minutes apart search overlapping prefixes. A mocked
-- sparse qualifying seed lies 100,000 indices beyond the first wall-time origin.
local wall=1900000000
local first_match=wall+100000
local second_match=wall+200000
do
 local first=facade(wall)
 eq(first.starts,0,'attaching a facade does not search')
 check(first.B.collection_search_cursor==nil,'attachment does not initialize a cursor')
 assert(first.begin())
 eq(first.start_index,wall+1,'first boot initializes from independent whole wall seconds')
 eq(first.cursor_at_dispatch,wall+2,'one index is reserved before the mocked dispatch')
 local found=first.finish('found',first_match-first.start_index+1,first_match)
 eq(found.status,'found','first valid mocked receipt is accepted')
 eq(M.seed_id(found.found.seed),first_match,'first boot receives the manufactured qualifying seed')
 eq(first.B.collection_search_cursor,first_match+1,'within boot the found receipt advances exactly to match plus one')
 assert(first.begin())
 eq(first.start_index,first_match+1,'the next search in the same boot starts beyond its prior match')
 local next_found=first.finish('found',second_match-first.start_index+1,second_match)
 eq(M.seed_id(next_found.found.seed),second_match,'the manufactured next match differs within one boot')
 eq(first.wall_calls,1,'one boot does not reinitialize its cursor from wall time')

 local restarted=facade(wall+120)
 assert(restarted.begin())
 eq(restarted.start_index,wall+121,'fresh facade advances its origin by only 120 indices')
 check(restarted.start_index<first_match,'the second fresh origin remains before the previous qualifying seed')
 local repeated=restarted.finish('found',first_match-restarted.start_index+1,first_match)
 eq(repeated.found.seed,found.found.seed,'two near-time fresh facades can receive the same qualifying seed')
 eq(restarted.B.collection_search_cursor,first_match+1,'the repeated match still advances correctly in that new boot')

 -- This simply supplies an explicit in-memory restored value. It implements
 -- no disk persistence and makes no claim about actual restart behavior.
 local continuity=facade(wall+120,first_match+1)
 assert(continuity.begin())
 eq(continuity.start_index,first_match+1,'restoring the prior validated cursor is sufficient to preserve deterministic continuity')
 eq(continuity.wall_calls,0,'a valid restored cursor needs no new random or wall origin')
 local distinct=continuity.finish('found',second_match-continuity.start_index+1,second_match)
 eq(M.seed_id(distinct.found.seed),second_match,'restored continuity skips the already accepted match in this modeled stream')
 eq(continuity.B.config.ar_filters.keep,'current','the fixture never rewrites current settings')
end

do
 local e=facade(wall,100)
 assert(e.begin());eq(e.B.collection_search_cursor,101,'initial dispatch spends one index')
 local miss=e.finish('not_found',50)
 eq(miss.status,'not_found','not-found remains an explicit result')
 eq(e.B.collection_search_cursor,150,'accepted miss advances by reported screened count from start')
 assert(e.begin());eq(e.start_index,150,'next dispatch uses that exact reported progress')
 local timeout=e.finish('timeout',25)
 eq(timeout.status,'timeout','timeout remains explicit')
 eq(e.B.collection_search_cursor,175,'accepted timeout advances by reported screened count')
 assert(e.begin());e.finish('not_found',0)
 eq(e.B.collection_search_cursor,176,'a zero-count receipt retains the pre-dispatch one-index reservation')
 assert(e.begin());check(e.api.cancel('fixture','manufactured cancellation'),'owned cancellation accepted')
 local cancelled=e.finish('found',10000,50000)
 eq(cancelled.status,'cancelled','cancelled late match remains cancelled')
 check(cancelled.found==nil,'cancelled match is not accepted')
 eq(e.B.collection_search_cursor,177,'cancelled results do not invent accepted screened progress')
 assert(e.begin());e.ready={generation=99,profile_token=e.token,request=copy(e.query),status='found',
  result={screened=1000,seed=M.seed_at(90000)}}
 eq(e.api.poll('fixture').status,'error','mismatched mocked receipt is rejected')
 eq(e.B.collection_search_cursor,178,'rejected receipt retains only its start reservation')
 check(e.events[#e.events].data.cursor_semantics:find('not a contiguous coverage claim',1,true),
  'existing log semantics do not turn parallel interrupted counts into proven contiguous coverage')
 eq(e.wall_calls,0,'valid existing cursor bypasses wall initialization throughout the boot')
end

do
 local e=facade(wall,300);e.start_failure=true
 local accepted,why,request=e.begin()
 check(not accepted and why=='manufactured dispatch failure','partial dispatch failure stays explicit')
 eq(e.B.collection_search_cursor,301,'failed dispatch still reserves the consumed start index')
 check(not e.api.begin(request,'fixture'),'failed request cannot be replayed')
 eq(e.starts,1,'spent request cannot dispatch twice')
 local exhausted=facade(wall,2318107019761)
 check(not exhausted.begin(),'exhausted cursor declines instead of wrapping')
 eq(exhausted.starts,0,'domain exhaustion starts no worker')
 eq(exhausted.wall_calls,0,'domain exhaustion never silently renews from wall time')
end
print('advisor_collection_cursor_review: '..checks..' checks passed; mock-only restart overlap reproduced')
