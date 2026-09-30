local M=dofile('Brainstorm/Core/collection_search_runtime.lua')
local checks=0
local function check(v,s)checks=checks+1;assert(v,s)end
local function q()
 return {schema=1,native_api_version=9,profile_id=1,voucher='',pack='',tag='Charm Tag',souls=2,observatory=false,
  observatory_deadline=0,perkeo=false,copymoney=false,retcon=false,bean=false,burglar=false,custom_filter='No Filter',
  target_rank='',target_suit='',specific_rank_min=0,any_rank_min=0,target_jokers='Yorick\31Perkeo',deck='Red Deck',
  target_locations='soul_pack\31soul_pack',stake_level=8,reject_perishable_targets=true,interchangeable_copies=true,
  missing_names='Joker',minimum_distinct=0,first_ante=1,last_ante=8,budget_ms=1000}
end
local found='{"schema":1,"status":"found","seed":"ABCD","screened":50000,"exact_candidates":2,"seconds":1.01e-2,"budget_ms":1000,"threads":2,"route":"conditional_no_reroll_stock_and_buffoon"}'
local miss=found:gsub('"found"','"not_found"'):gsub('"ABCD"','""')
local function env(mode)
 local e={time=0,channels={},cancel_calls=0,starts=0,events={},results={}}
 e.B={PATH='mod',NATIVE_FILE='new.dll',config={ar_filters={keep='original'}},search_estimate_generation=4}
 e.B.invalidateSearchEstimate=function()e.B.search_estimate_generation=e.B.search_estimate_generation+1 end
 local function channel(name)
  if not e.channels[name] then e.channels[name]={queue={},push=function(self,v)self.queue[#self.queue+1]=v end,pop=function(self)return table.remove(self.queue,1)end}end
  return e.channels[name]
 end
 local deps={now=function()return e.time end,channel=channel,native=function()
  if mode=='load_error' then error('no library')end
  return {brainstorm_set_search_thread_mode=function(value)e.mode=value end,
   brainstorm_cancel_v9=function()e.cancel_calls=e.cancel_calls+1 end}
 end,new_thread=function(path)
  e.path=path
  local thread={running=false,start=function(self,...)
   e.starts=e.starts+1;self.args={...};self.running=true
   if mode=='start_error' then error('start error after becoming active')end
  end,isRunning=function(self)if e.unknown_live then error('liveness unavailable')end;return self.running end,
  getError=function()return e.worker_error end}
  e.thread=thread;return thread
 end,on_event=function(kind,data)e.events[#e.events+1]={kind=kind,data=data}end,
 on_result=function(result)e.results[#e.results+1]=result end}
 if mode=='parse_error' then deps.parse=function()error('decoder error')end end
 e.api=M.attach(e.B,deps)
 function e.send(raw,status,generation)
  channel(e.thread.args[2]):push({generation=generation or e.B.collection_search_generation,status=status or 'complete',raw_result=raw})
 end
 function e.exit(raw,status)if raw then e.send(raw,status)end;e.thread.running=false end
 return e
end
do
 local decoded=assert(M.decode(found));check(decoded.seconds==.0101,'fraction and exponent decoded')
 check(M.validate_result(decoded,q()),'valid complete result accepted')
 for _,raw in ipairs({'{}','{"status":"found","status":"found"}','{"status":"found"}junk',
  '{"seconds":01}','{"seconds":1.}','{"seconds":.1}','{"seconds":1e}','{"seconds":+1}',
  '{"seconds":1e999}','{"a":[1]}','{"a":null}','{"a":"\\u0061"}','{"a":{"b":2}}',
  '{"status":"found",}','{"status":"found"}\0','\11{"status":"found"}'})do check(M.decode(raw)==nil,'malformed flat JSON rejected')end
 check(M.decode('{ "status" : "invalid" }').status=='invalid','whitespace and minimal response')
 check(M.validate_result(M.decode('{"status":"invalid"}'),q()),'minimal invalid accepted')
 check(M.validate_result(M.decode('{"status":"busy"}'),q()),'minimal busy accepted')
 check(not M.validate_result(M.decode('{"status":"invalid","seed":"ABCD"}'),q()),'invalid cannot smuggle seed')
 check(M.validate_result(M.decode('{"status":"not_found","screened":0,"reason":"impossible_fixed_deck_counts"}'),q()),'deterministic miss accepted')
 for _,change in ipairs({{seed='A0CD'},{seed='123456789'},{schema=2},{status='win'},{screened=-1},
  {exact_candidates=50001},{exact_candidates=0},{budget_ms=1001},{threads=0},{threads=257},
  {seconds=100},{route='different'},{unknown=true},{reason=true}})do
  local r=assert(M.decode(found));for k,v in pairs(change)do r[k]=v end
  check(not M.validate_result(r,q()),'invalid bound native evidence rejected')
 end
 check(not M.validate_result(M.decode(found),{}),'malformed request cannot crash validation')
end
do
 local e=env();check(not e.api.busy() and e.starts==0,'attach starts no worker')
 local request=q();local generation=assert(e.api.start(request,'11111111','profile:one'))
 check(generation==1 and e.api.busy() and e.B.native_search_busy,'start holds busy latch')
 check(e.B.search_estimate_generation==5,'queued estimate invalidated')
 check(e.mode==1 and e.starts==1 and #e.thread.args==32,'one maximum-CPU worker with complete ABI')
 check(e.path=='mod/Core/collection_search_worker.lua' and e.thread.args[1]=='mod/new.dll','selected paths exact')
 request.target_jokers='changed';e.time=.05;e.send(found)
 check(e.api.poll('profile:one')==nil and e.api.busy(),'reply cannot release running thread')
 check(not e.api.start(q(),'22222222','profile:one'),'overlapping starts rejected')
 e.thread.running=false
 local result=assert(e.api.poll('profile:one'))
 check(result.status=='found' and result.result.seed=='ABCD' and result.starts_run==false,'qualified result returned without starting game')
 check(result.request.target_jokers~='changed' and result.profile_token=='profile:one','request and token retained immutably')
 check(not e.api.busy() and not e.B.native_search_busy and #e.results==1,'latch released only after actual exit')
 check(e.api.poll()==nil and e.B.config.ar_filters.keep=='original','one-use delivery and settings untouched')
 local second=assert(e.api.start(q(),'22222222','profile:two'))
 check(second==2 and e.thread.args[2]~='Brainstorm.CollectionSearch.1.reply','fresh unique channels/generation')
 e.send(found,'complete',1);e.exit(miss);check(e.api.poll().status=='not_found','stale generation ignored')
end
do
 local e=env();assert(e.api.start(q(),'11111111','p'))
 assert(e.api.stop('user stop'));local first=e.cancel_calls
 check(e.api.busy() and e.B.native_search_busy,'stop waits for native exit')
 e.api.poll();check(e.cancel_calls>first,'cancellation repeats across native-entry reset race')
 e.exit(found);local result=assert(e.api.poll())
 check(result.status=='cancelled' and result.result==nil and result.raw_result==found,'post-stop match logged but never accepted')
 check(e.starts==1 and not e.api.stop(),'no automatic restart or orphan stop')
end
do
 local e=env();assert(e.api.start(q(),'11111111','p'));e.time=1.001
 check(e.api.poll()==nil and e.api.status=='stopping' and e.B.native_search_busy,'wall timeout initiates cooperative cancellation')
 e.exit(found);check(e.api.poll().status=='timeout' and e.starts==1,'timeout never renews budget or accepts late match')
end
for _,case in ipairs({'backwards','bad_clock','profile','no_response','worker_error','malformed','duplicate','parse_error','bad_native','unknown_live','foreign_owner'})do
 local e=env(case=='parse_error' and case or nil);e.time=10;assert(e.api.start(q(),'11111111','p'))
 if case=='backwards' then e.time=9
 elseif case=='bad_clock' then e.time=0/0
 elseif case=='worker_error' then e.worker_error='worker broke'
 elseif case=='malformed' then e.channels[e.thread.args[2]]:push('bad message')
 elseif case=='duplicate' then e.send(found);e.send(found)
 elseif case=='bad_native' then e.send('{"status":"found"}')
 elseif case=='unknown_live' then e.unknown_live=true
 elseif case=='foreign_owner' then e.B.native_search_owner='different'
 elseif case=='parse_error' then e.send(found)end
 if case=='unknown_live' then
  check(e.api.poll()==nil and e.B.native_search_busy,'unknown liveness never unlocks shared native globals')
  e.unknown_live=false
 end
 if case~='no_response' and case~='malformed' and case~='duplicate' and case~='bad_native' and case~='parse_error' then e.send(found)end
 e.thread.running=false
 local result=assert(e.api.poll(case=='profile' and 'different profile' or nil))
 check(result.status==(case=='profile' and 'cancelled' or 'error'),case..' fails safely')
 check(result.result==nil and e.starts==1,case..' accepts no match and retries nothing')
 if case=='foreign_owner' then check(e.B.native_search_busy,'foreign owner latch is not cleared')end
end
do
 local e=env('start_error');check(not e.api.start(q(),'11111111','p'),'start exception reports failure')
 check(e.api.busy() and e.B.native_search_busy,'partially started worker retains exclusion')
 e.thread.running=false;check(e.api.poll().status=='error' and not e.B.native_search_busy,'partial start cleans up after exit')
 e=env('load_error');check(not e.api.start(q(),'11111111','p') and not e.api.busy() and not e.B.native_search_busy,'loader failure releases without worker')
 for _,change in ipairs({{budget_ms=30001},{minimum_distinct=false},{first_ante=9},{last_ante=0},
  {interchangeable_copies='yes'},{target_jokers={}},{target_jokers='Yorick\0Perkeo'},{native_api_version=8},{profile_id=false}})do
  e=env();local request=q();for k,v in pairs(change)do request[k]=v end
  check(not e.api.start(request,'11111111','p') and e.starts==0 and not e.B.native_search_busy,'malformed request rejected before native calls')
 end
 e=env();e.B.ar_active=true;check(not e.api.start(q(),'11111111','p'),'active normal search excluded')
 e=env();e.B.native_search_busy=true;check(not e.api.start(q(),'11111111','p') and e.B.native_search_busy,'foreign native job preserved')
end
print('collection_runtime fixture: '..checks..' checks passed')
