-- Bounded asynchronous native bridge. No run launch, filters, game/profile/save
-- access, automatic retries or blocking thread waits.
local M={}
local function finite(n)return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function whole(n,lo,hi)return finite(n) and n%1==0 and n>=lo and n<=hi end
local function plain(t)return type(t)=='table' and getmetatable(t)==nil end
local function seed_ok(s)return type(s)=='string' and #s>0 and #s<=8 and not s:find('[^1-9A-Z]')end
local function token_ok(t)return type(t)=='string' and #t>0 and #t<=4096 or whole(t,1,9007199254740991)end

-- Strict flat JSON transport, deliberately separate from challenge_opening's
-- integer-only parser. Native strings are ASCII without escapes.
function M.decode(raw)
  if type(raw)~='string' or #raw>4096 then return nil end
  local i=1
  local function ws()
    while true do local c=raw:sub(i,i);if c~=' ' and c~='\t' and c~='\r' and c~='\n' then return end;i=i+1 end
  end
  local function string_value()
    ws();if raw:sub(i,i)~='"' then return nil end
    local last=raw:find('"',i+1,true);if not last then return nil end
    local s=raw:sub(i+1,last-1)
    if s:find('[\\%c]') or s:find('[\128-\255]') then return nil end
    i=last+1;return s
  end
  local function value()
    ws();if raw:sub(i,i)=='"' then return string_value() end
    local rest=raw:sub(i)
    if rest:sub(1,4)=='true' then i=i+4;return true end
    if rest:sub(1,5)=='false' then i=i+5;return false end
    local number=rest:match('^-?%d+%.%d+[eE][+-]?%d+') or rest:match('^-?%d+[eE][+-]?%d+')
      or rest:match('^-?%d+%.%d+') or rest:match('^-?%d+')
    if not number or number:gsub('^-',''):match('^0%d') then return nil end
    local n=tonumber(number);if not finite(n) then return nil end
    i=i+#number;return n
  end
  ws();if raw:sub(i,i)~='{' then return nil end;i=i+1
  local out,seen={},{}
  for _=1,24 do
    local key=string_value();if not key or #key>64 or seen[key] then return nil end
    seen[key]=true;ws();if raw:sub(i,i)~=':' then return nil end;i=i+1
    local v=value();if v==nil then return nil end;out[key]=v
    ws();local c=raw:sub(i,i);i=i+1
    if c=='}' then ws();if i<=#raw then return nil end;return out end
    if c~=',' then return nil end
  end
end

local fields={'voucher','pack','tag','souls','observatory','observatory_deadline','perkeo','copymoney',
  'retcon','bean','burglar','custom_filter','target_rank','target_suit','specific_rank_min','any_rank_min',
  'target_jokers','deck','target_locations','stake_level','reject_perishable_targets','interchangeable_copies',
  'missing_names','minimum_distinct','first_ante','last_ante','budget_ms'}
local strings={voucher=true,pack=true,tag=true,custom_filter=true,target_rank=true,target_suit=true,
  target_jokers=true,deck=true,target_locations=true,missing_names=true}
local booleans={observatory=true,perkeo=true,copymoney=true,retcon=true,bean=true,burglar=true,
  reject_perishable_targets=true,interchangeable_copies=true}
local bounds={souls={0,4},observatory_deadline={0,8},specific_rank_min={0,52},any_rank_min={0,52},
  stake_level={1,8},minimum_distinct={0,150},first_ante={1,8},last_ante={1,8},budget_ms={1,30000}}
local function request_copy(q,seed,profile)
  if not plain(q) or q.schema~=1 or q.native_api_version~=9 or not seed_ok(seed)
    or not token_ok(profile) or not token_ok(q.profile_id) then return nil,'Invalid bound collection-search request.' end
  local copy={schema=1,native_api_version=9,profile_id=q.profile_id};local args={seed}
  for _,key in ipairs(fields)do
    local v=rawget(q,key)
    if strings[key] then
      if type(v)~='string' or v:find('%z') or #v>(key=='missing_names' and 8192 or 1024) then return nil,'Invalid native string field: '..key end
    elseif booleans[key] then
      if type(v)~='boolean' then return nil,'Invalid native boolean field: '..key end
    elseif not whole(v,bounds[key][1],bounds[key][2]) then return nil,'Invalid native integer field: '..key end
    copy[key]=v;args[#args+1]=v
  end
  if copy.first_ante>copy.last_ante then return nil,'Reversed encounter window.' end
  return {request=copy,args=args}
end
local result_fields={schema=true,status=true,seed=true,screened=true,exact_candidates=true,seconds=true,
  budget_ms=true,threads=true,route=true,reason=true}
function M.validate_result(r,q)
  if not plain(r) or not plain(q) or not whole(q.budget_ms,1,30000) then return nil,'Malformed native result.' end
  for k in pairs(r)do if not result_fields[k] then return nil,'Unknown native result field.' end end
  if r.status=='invalid' or r.status=='busy' then
    for k in pairs(r)do if k~='status' then return nil,'Unexpected invalid/busy result fields.' end end
    return r
  end
  if r.status=='not_found' and r.reason=='impossible_fixed_deck_counts' and r.screened==0 then
    for k in pairs(r)do if k~='status' and k~='reason' and k~='screened' then return nil,'Malformed deterministic miss.' end end
    return r
  end
  if r.schema~=1 or r.reason~=nil or (r.status~='found' and r.status~='not_found' and r.status~='timeout' and r.status~='cancelled')
    or not whole(r.screened,0,2318107019761) or not whole(r.exact_candidates,0,r.screened)
    or not finite(r.seconds) or r.seconds<0 or r.seconds>q.budget_ms/1000+5
    or r.budget_ms~=q.budget_ms or not whole(r.threads,1,256)
    or r.route~='conditional_no_reroll_stock_and_buffoon' then return nil,'Native result does not match the bounded request.' end
  if r.status=='found' then
    if not seed_ok(r.seed) or r.screened<1 or r.exact_candidates<1 then return nil,'Native match has no valid seed/evaluation evidence.' end
  elseif r.seed~='' then return nil,'A nonmatching result cannot carry a playable seed.' end
  return r
end

function M.attach(B,deps)
  assert(type(B)=='table','Brainstorm table required');deps=deps or {}
  local api={status='idle',last=nil};local active
  local now=deps.now or function()return love.timer.getTime()end
  local new_thread=deps.new_thread or function(path)
    -- B.PATH is a native absolute path; LOVE's filename overload resolves its
    -- virtual filesystem instead. Load the installed bytes with nativefs and
    -- pass FileData, leaving the DLL's native path and thread protocol intact.
    local source,reason=require('nativefs').read(path)
    assert(type(source)=='string','Could not read collection search worker: '..tostring(reason or 'no bytes'))
    assert(#source>0 and #source<=65536,'Collection search worker has an invalid size')
    local data=assert(love.filesystem.newFileData(source,'brainstorm_collection_search_worker.lua'),'Worker FileData creation failed')
    return love.thread.newThread(data)
  end
  local channel=deps.channel or function(name)return love.thread.getChannel(name)end
  local parse=deps.parse or M.decode
  local function clock()
    local ok,t=pcall(now);if ok and finite(t) and t>=0 then return t end
  end
  local function event(kind,data)if type(deps.on_event)=='function' then pcall(deps.on_event,kind,data)end end
  local function running(job)
    if not job.thread then return false end
    local ok,value=pcall(function()return job.thread:isRunning()end)
    if not ok or type(value)~='boolean' then return nil end
    return value
  end
  local function cancel(job)
    if job.cancel and not job.cancel_sent then
      local ok=pcall(function()job.cancel:push(true)end);job.cancel_sent=ok
    end
    if job.lib then pcall(function()job.lib.brainstorm_cancel_v9()end) end
  end
  local function stop_as(status,reason)
    if not active then return false end
    if not active.stop_status then
      active.stop_status=status;active.reason=tostring(reason or status):sub(1,512)
      api.status='stopping';event('stopping',{generation=active.generation,status=status,reason=active.reason})
    end
    cancel(active);return true
  end
  local function finish(job,status,reason,result)
    local ended=clock()
    local out={generation=job.generation,status=status,reason=reason,profile_token=job.profile,
      profile_id=job.request.profile_id,request=job.request,result=result,raw_result=job.raw,
      elapsed_wall_seconds=ended and ended>=job.started and ended-job.started or nil,starts_run=false}
    active=nil;api.status=status;api.last=out
    if B.native_search_owner==job.owner then B.native_search_busy=false;B.native_search_owner=nil end
    event('finished',out)
    if type(deps.on_result)=='function' then pcall(deps.on_result,out) end
    return out
  end
  function api.busy()return active~=nil end
  function api.stop(reason)return stop_as('cancelled',reason or 'Stopped by the user.')end
  function api.start(request,seed,profile)
    if active or B.native_search_busy or B.ar_active then return nil,'Another native search is still active.' end
    local prepared,reason=request_copy(request,seed,profile);if not prepared then return nil,reason end
    local started=clock();if not started then return nil,'A reliable search clock is unavailable.' end
    if type(deps.native)~='function' or type(B.PATH)~='string' or type(B.NATIVE_FILE)~='string' then return nil,'Native search dependencies are unavailable.' end
    local generation=(whole(B.collection_search_generation,0,9007199254740990) and B.collection_search_generation or 0)+1
    B.collection_search_generation=generation
    local owner='Brainstorm.CollectionSearch.'..generation
    local job={generation=generation,owner=owner,profile=profile,request=prepared.request,
      started=started,latest=started,deadline=started+prepared.request.budget_ms/1000}
    active=job;api.status='starting';api.last=nil;B.native_search_busy=true;B.native_search_owner=owner
    local ok,err=pcall(function()
      -- Invalidates queued legacy-estimate callbacks before creating any worker.
      if type(B.invalidateSearchEstimate)=='function' then B.invalidateSearchEstimate()
      else B.search_estimate_generation=(tonumber(B.search_estimate_generation) or 0)+1 end
      job.reply=channel(owner..'.reply');job.cancel=channel(owner..'.cancel')
      job.lib=assert(deps.native(),'Native library unavailable')
      job.lib.brainstorm_set_search_thread_mode(1)
      job.thread=assert(new_thread(B.PATH..'/Core/collection_search_worker.lua'),'Worker creation failed')
      local args={B.PATH..'/'..B.NATIVE_FILE,owner..'.reply',owner..'.cancel',generation}
      for _,value in ipairs(prepared.args)do args[#args+1]=value end
      job.thread:start(unpack(args))
    end)
    if not ok then
      stop_as('error','Could not start native search: '..tostring(err))
      if running(job)==false then finish(job,'error',job.reason) end
      return nil,job.reason
    end
    api.status='searching';event('started',{generation=generation,profile_token=profile,request=job.request})
    return generation
  end
  function api.poll(current_profile)
    local job=active;if not job then return nil end
    if B.native_search_owner~=job.owner or B.native_search_busy~=true then stop_as('error','Native search ownership changed.')end
    local t=clock()
    if not t or t<job.latest then stop_as('error','Search clock became unavailable or moved backwards.')
    else job.latest=t;if t>=job.deadline then stop_as('timeout','The one-use search wall budget expired.')end end
    if current_profile~=nil and current_profile~=job.profile then stop_as('cancelled','The active profile token changed.')end
    if job.stop_status then cancel(job) end
    local protocol_error
    if job.reply then
      for _=1,8 do
        local ok,message=pcall(function()return job.reply:pop()end)
        if not ok then protocol_error='Could not read native worker replies.';break end
        if message==nil then break end
        if not plain(message) or not whole(message.generation,1,9007199254740991) then protocol_error='Malformed worker reply.';break end
        if message.generation==job.generation then
          if job.message then protocol_error='Duplicate worker reply.';break end
          if message.status~='complete' and message.status~='cancelled' and message.status~='error' then protocol_error='Unknown worker status.';break end
          for key in pairs(message)do
            if key~='generation' and key~='status' and key~='raw_result' and key~='error' then protocol_error='Unknown worker reply field.' end
          end
          if message.status=='complete' and type(message.raw_result)~='string'
            or message.raw_result~=nil and (type(message.raw_result)~='string' or #message.raw_result>4096)
            or message.error~=nil and (type(message.error)~='string' or #message.error>4096) then protocol_error='Malformed worker payload.' end
          if protocol_error then break end
          job.message=message;job.raw=message.raw_result
        end
      end
    end
    if protocol_error then stop_as('error',protocol_error)end
    if job.thread then
      local ok,err=pcall(function()return job.thread:getError()end)
      if not ok or err then stop_as('error','Native worker error: '..tostring(err))end
    end
    local live=running(job)
    if live==nil then stop_as('error','Native worker liveness is unknown.');return nil end
    if live then return nil end
    if job.stop_status then return finish(job,job.stop_status,job.reason)end
    local message=job.message
    if not message then return finish(job,'error','Native worker exited without a response.')end
    if message.status=='error' then return finish(job,'error',tostring(message.error or 'Native worker failed.'):sub(1,512))end
    if message.status=='cancelled' then return finish(job,'cancelled','Native worker was cancelled.')end
    local ok,result=pcall(parse,message.raw_result)
    if not ok then return finish(job,'error','Native result could not be decoded.')end
    local parsed,why=M.validate_result(result,job.request)
    if not parsed then return finish(job,'error',why)end
    return finish(job,parsed.status,nil,parsed)
  end
  api.update=api.poll
  B.CollectionSearchRuntime=api
  return api
end
return M
