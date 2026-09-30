-- Exercise the production factory: native absolute paths are not LOVE paths.
-- Inert nativefs/FileData/Thread doubles; no worker, source game or DLL executes.
local M=dofile('Brainstorm/Core/collection_search_runtime.lua')
local checks=0
local function check(v,s)checks=checks+1;assert(v,s)end
local file=assert(io.open('Brainstorm/Core/collection_search_worker.lua','rb'))
local installed_source=file:read('*a');file:close()
local old_love,old_nativefs=love,package.loaded.nativefs
local function request()
 return {schema=1,native_api_version=9,profile_id=1,voucher='',pack='',tag='Charm Tag',souls=2,observatory=false,
  observatory_deadline=0,perkeo=false,copymoney=false,retcon=false,bean=false,burglar=false,custom_filter='No Filter',
  target_rank='',target_suit='',specific_rank_min=0,any_rank_min=0,target_jokers='Yorick\31Perkeo',deck='Red Deck',
  target_locations='soul_pack\31soul_pack',stake_level=8,reject_perishable_targets=true,interchangeable_copies=true,
  missing_names='Joker',minimum_distinct=0,first_ante=1,last_ante=8,budget_ms=1000}
end
local function env(mode)
 local e={time=0,reads=0,data_calls=0,thread_calls=0,starts=0,cancels=0,channels={}}
 e.B={PATH='C:/Users/test/AppData/Roaming/Balatro/Mods/Brainstorm',NATIVE_FILE='preserved.dll'}
 package.loaded.nativefs={read=function(path)
  e.reads=e.reads+1;e.read_path=path
  if mode=='read_error' then error('native file read failed')end
  if mode=='missing' then return nil,'missing installed worker'end
  if mode=='wrong_type' then return true end
  if mode=='empty' then return '' end
  if mode=='oversize' then return string.rep('x',65537)end
  return installed_source
 end}
 love={timer={getTime=function()return e.time end},filesystem={
  newFileData=function(source,name)
   e.data_calls=e.data_calls+1
   check(source==installed_source,'FileData gets exact installed worker bytes')
   check(name=='brainstorm_collection_search_worker.lua','FileData uses a descriptive local name')
   if mode=='data_error' then error('FileData failed')end
   if mode=='data_nil' then return nil end
   e.data={kind='FileData',source=source,name=name};return e.data
  end},thread={}}
 love.thread.getChannel=function(name)
  if not e.channels[name] then e.channels[name]={queue={},push=function(self,v)self.queue[#self.queue+1]=v end,
   pop=function(self)return table.remove(self.queue,1)end}end
  return e.channels[name]
 end
 love.thread.newThread=function(data)
  e.thread_calls=e.thread_calls+1
  -- This is precisely the overload mismatch that previously failed in LOVE.
  assert(type(data)~='string','Could not open native absolute path in LOVE virtual filesystem')
  check(data==e.data and data.kind=='FileData','production newThread receives FileData, never a filename')
  if mode=='thread_error' then error('thread creation failed')end
  if mode=='thread_nil' then return nil end
  local thread={running=false,isRunning=function(self)return self.running end,getError=function()return nil end,
   start=function(self,...)
    self.args={...};e.starts=e.starts+1;self.running=true
    if mode=='start_error' then error('partial start failed')end
   end}
  e.thread=thread;return thread
 end
 e.api=M.attach(e.B,{native=function()return {
  brainstorm_set_search_thread_mode=function(n)e.mode=n end,
  brainstorm_cancel_v9=function()e.cancels=e.cancels+1 end}end})
 return e
end
do
 local e=env()
 check(e.reads==0 and e.starts==0,'attaching neither reads worker nor starts search')
 local ok=pcall(love.thread.newThread,e.B.PATH..'/Core/collection_search_worker.lua')
 check(not ok,'old absolute-filename factory reproduces virtual-filesystem failure')
 local q=request();local generation=assert(e.api.start(q,'11111111','profile:one'))
 check(generation==1 and e.reads==1 and e.starts==1,'production factory reads once and starts once')
 check(e.read_path==e.B.PATH..'/Core/collection_search_worker.lua','nativefs receives the installed absolute path')
 check(e.mode==1 and #e.thread.args==32,'maximum CPU and complete ABI retained')
 check(e.thread.args[1]==e.B.PATH..'/preserved.dll','native DLL absolute path retained')
 check(e.thread.args[2]=='Brainstorm.CollectionSearch.1.reply' and e.thread.args[3]=='Brainstorm.CollectionSearch.1.cancel'
  and e.thread.args[4]==1 and e.thread.args[5]=='11111111','thread transport identifiers retained')
 q.target_jokers='mutation'
 check(e.thread.args[22]=='Yorick\31Perkeo','request copied before worker launch')
 check(e.api.busy() and e.B.native_search_busy,'ownership held while fake thread runs')
 check(not e.api.start(request(),'22222222','profile:one'),'overlapping factory requests rejected')
 check(e.reads==1 and e.starts==1,'rejected overlap does not read or start again')
 assert(e.api.stop('explicit stop'));check(e.api.poll()==nil and e.api.busy(),'stop drains running thread')
 e.thread.running=false
 check(e.api.poll().status=='cancelled' and not e.B.native_search_busy,'native ownership releases after confirmed exit')
 check(e.reads==1 and e.starts==1,'no automatic restart after cancellation')
end
for _,mode in ipairs({'missing','wrong_type','read_error','empty','oversize','data_error','data_nil','thread_error','thread_nil'})do
 local e=env(mode);local generation,reason=e.api.start(request(),'11111111','profile:one')
 check(generation==nil and type(reason)=='string' and reason:find('Could not start native search',1,true),'factory failure reported: '..mode)
 check(e.api.status=='error' and e.api.last.status=='error' and not e.api.busy(),'unstarted failure finalized: '..mode)
 check(not e.B.native_search_busy and e.B.native_search_owner==nil,'unstarted ownership released: '..mode)
 check(e.starts==0 and e.cancels>=1,'no worker launch; cancellation remains safe: '..mode)
 if mode=='missing' or mode=='wrong_type' or mode=='read_error' or mode=='empty' or mode=='oversize' then
  check(e.data_calls==0 and e.thread_calls==0,'invalid bytes never reach LOVE: '..mode)
 end
 check(e.api.poll()==nil and e.starts==0,'failure has no retry or duplicate result: '..mode)
end
do
 local e=env('start_error');local generation,reason=e.api.start(request(),'11111111','profile:one')
 check(generation==nil and reason:find('partial start failed',1,true),'partial start error retained')
 check(e.api.busy() and e.B.native_search_busy and e.api.status=='stopping','running partial start keeps ownership')
 check(not e.api.start(request(),'22222222','profile:one'),'partial start blocks overlapping worker')
 e.thread.running=false
 check(e.api.poll().status=='error' and not e.B.native_search_busy,'partial start drains before releasing owner')
 check(e.starts==1 and e.reads==1,'partial start never silently retries')
end
love,package.loaded.nativefs=old_love,old_nativefs
print('advisor_collection_worker_loading: '..checks..' checks passed')
