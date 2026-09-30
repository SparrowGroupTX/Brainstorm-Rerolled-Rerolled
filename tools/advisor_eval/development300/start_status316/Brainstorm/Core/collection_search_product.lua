-- User-armed product facade. Reads loaded collection metadata only. Search and
-- run launch are separate, owned, one-use operations; no autoplay or save I/O.
local M={}
-- Original boot_timer retains G.LOADING={font=Font} after startup.
-- It is display cache, not active loading. Unknown shapes and true still block.
local function loading_pending(value)
  if value==nil or value==false then return false end
  if type(value)~='table' or getmetatable(value)~=nil then return true end
  local font=rawget(value,'font')
  if type(font)~='userdata' and type(font)~='table' then return true end
  for key in next,value do if key~='font' then return true end end
  return false
end
-- Diagnostic names only: never stringify live values or userdata addresses.
local function diagnostic_fields(value,active_only)
  local names={}
  for key,item in next,value do
    if not active_only or item then
      names[#names+1]=type(key)=='string' and key:gsub('%c','?'):sub(1,24) or ('<'..type(key)..' key>')
    end
  end
  table.sort(names)
  if #names>4 then while #names>4 do table.remove(names)end;names[#names+1]='...' end
  return #names>0 and table.concat(names,', ') or 'none'
end
local function loading_reason(value)
  local shape=type(value)
  if shape=='table'then shape=shape..(getmetatable(value)~=nil and ' with metatable' or ' fields: '..diagnostic_fields(value))end
  return 'Game loading is active ('..shape..').'
end
local function settled_main_menu(g)
  return g and g.STAGES and g.STATES and g.STAGES.MAIN_MENU~=nil and g.STATES.MENU~=nil
    and g.STAGE==g.STAGES.MAIN_MENU and g.STATE==g.STATES.MENU
end
local DOMAIN=2318107019761
local CHARS='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local COEFF={66231629136,1892332261,54066636,1544761,44136,1261,36,1}
local function whole(n,lo,hi)return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi end
local function plain(t)return type(t)=='table' and getmetatable(t)==nil end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  if not plain(a) or not plain(b) then return false end
  for k,v in pairs(a)do if not equal(v,b[k])then return false end end
  for k in pairs(b)do if a[k]==nil then return false end end
  return true
end
local function owner_ok(v)return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c')end
function M.seed_at(index)
  if not whole(index,1,DOMAIN-1)then return nil end
  local out={}
  for _,coefficient in ipairs(COEFF)do
    if index>0 then
      local digit=math.floor((index-1)/coefficient)
      if digit>34 then return nil end
      index=index-1-digit*coefficient;table.insert(out,1,CHARS:sub(digit+1,digit+1))
    end
  end
  return table.concat(out)
end
function M.seed_id(seed)
  if type(seed)~='string' or #seed==0 or #seed>8 or seed:find('[^1-9A-Z]')then return nil end
  local index=0
  for i=1,#seed do index=index+1+(CHARS:find(seed:sub(-i,-i),1,true)-1)*COEFF[i]end
  return index
end
local native_fields={'voucher','pack','tag','souls','observatory','observatory_deadline','perkeo','copymoney',
  'retcon','bean','burglar','custom_filter','target_rank','target_suit','specific_rank_min','any_rank_min',
  'target_jokers','deck','target_locations','stake_level','reject_perishable_targets','interchangeable_copies',
  'missing_names','minimum_distinct','first_ante','last_ante','budget_ms'}
local deck_keys={['Red Deck']='b_red',['Zodiac Deck']='b_zodiac'}
local primary_names={j_yorick='Yorick',j_caino='Canio',j_triboulet='Triboulet',j_chicot='Chicot'}
local function primary(q)
  local key=q.primary_legendary_key or 'j_yorick';local name=primary_names[key]
  if not name or q.primary_legendary_name~=nil and q.primary_legendary_name~=name then return nil end
  if key~='j_yorick' and not (q.opening_adapted==true and q.legendary_fallback==true and q.quota_mode=='auto' and q.first_ante==1)then return nil end
  local burnt=q.burnt_required~=false
  if q.target_jokers~=table.concat({name,'Brainstorm',burnt and 'Burnt Joker' or '','Perkeo',''},'\31') or
    q.target_locations~=table.concat({'soul_pack','by_ante_5',burnt and 'by_ante_5'or'ante_1','soul_pack','ante_1'},'\31')then return nil end
  return key,name
end
local function opening_status(q)
  local _,name=primary(q)
  return q.opening_adapted and (name..' + Perkeo. ')or ''
end
local function run_identity(g)
  local game=g and g.GAME
  return {game=game,stage=g and g.STAGE,state=g and g.STATE,round=game and game.round,
    seed=game and game.pseudorandom and game.pseudorandom.seed}
end
local function same_run(a,g)
  local b=run_identity(g)
  return a.game==b.game and a.stage==b.stage and a.state==b.state and a.round==b.round and a.seed==b.seed
end
function M.attach(B,deps)
  assert(type(B)=='table','Brainstorm table required');deps=deps or {}
  local api={status='Search is idle. Starting replaces the current run.'}
  local prepared=setmetatable({},{__mode='k'})
  local active,manual,manual_request_owner
  local game=deps.game or function()return G end
  local runtime=deps.runtime or B.CollectionSearchRuntime
  local query=deps.query or B.CollectionSearch
  local gold=deps.gold or (B.Advisor and B.Advisor.gold_search)
  local stickers=deps.stickers or (B.Advisor and B.Advisor.gold_stickers)
  local input_token=deps.input_token or function()return B.collection_search_input_generation or 0 end
  local now=deps.now or function()return love.timer.getTime()end
  local function clock(job)
    local ok,t=pcall(now)
    if not ok or type(t)~='number' or t~=t or t<0 or t==math.huge or job and job.latest and t<job.latest then return nil end
    if job then job.latest=t end
    return t
  end
  local function input()
    local ok,value=pcall(input_token)
    if ok and (whole(value,0,9007199254740991) or type(value)=='string' and #value<512)then return value end
  end
  local function event(kind,data)
    if deps.on_event then pcall(deps.on_event,kind,data)
    elseif B.Advisor and B.Advisor.player_log then pcall(function()B.Advisor.player_log:event(kind,data)end)end
  end
  local function progress()
    if not gold or type(gold.choices)~='function' then return nil,'Gold search metadata is unavailable.' end
    local ok,goal=pcall(function()
      if deps.progress then return deps.progress() end
      return stickers and stickers.capture(game(),{enabled=true})
    end)
    if not ok or not goal then return nil,'Loaded Gold progress is unavailable.' end
    local checked,choices,detail=pcall(gold.choices,goal)
    if not checked or not choices or type(detail)~='table' or detail.unknown_count~=0 then
      return nil,'Gold progress must have complete, known vanilla records.'
    end
    local id=detail.profile_id
    if not (whole(id,1,9007199254740991) or type(id)=='string' and #id>0 and #id<256 and not id:find('%c'))then
      return nil,'The loaded active profile identity is unavailable.'
    end
    local keys={};for _,row in ipairs(choices)do keys[#keys+1]=row.key end;table.sort(keys)
    local token=type(id)..':'..#tostring(id)..':'..tostring(id)..'|'..table.concat(keys,',')
    if #token>4096 then return nil,'The loaded Gold population token is too large.' end
    return {goal=goal,token=token,profile_id=id,missing_count=#keys}
  end
  local function safe(g)
    if not g or not g.GAME or not g.STAGES or not g.STATES then return nil,'The game menu is unavailable.' end
    if B.ar_active then return nil,'A normal reroll is active.' end
    if B.Checkpoints and B.Checkpoints.pending then return nil,'Checkpoint request is pending.' end
    if B.Checkpoints and B.Checkpoints.saving then return nil,'Checkpoint save is pending.' end
    if B.save_pending then return nil,'Brainstorm save is pending.' end
    if B.checkpoint_busy then return nil,'Checkpoint operation is busy.' end
    if g.SAVING then return nil,'Game saving is active.' end
    if loading_pending(g.LOADING)then return nil,loading_reason(g.LOADING) end
    if deps.pending then
      local ok,pending=pcall(deps.pending,g)
      if not ok or pending then return nil,'A game save or transition is pending.' end
    end
    local stop_use=g.GAME.STOP_USE
    if stop_use~=nil and (type(stop_use)~='number' or stop_use~=stop_use or stop_use<0)then return nil,'The pending game action state is unavailable.' end
    if not g.STATE_COMPLETE and not settled_main_menu(g) then return nil,'Game transition incomplete.' end
    if g.screenwipe then return nil,'Screen transition active.' end
    if g.OVERLAY_MENU then return nil,'Menu is still open.' end
    if (g.SETTINGS or {}).paused then return nil,'Game is paused.' end
    if (stop_use or 0)>0 then return nil,'Card action pending.' end
    local c=g.CONTROLLER
    if type(c)~='table' then return nil,'Game input controller is unavailable.' end
    if c.text_input_hook then return nil,'Finish text entry.' end
    if c.locked then return nil,'Controls are settling.' end
    if c.dragging and c.dragging.target then return nil,'Release the dragged card.' end
    if c.locks~=nil and type(c.locks)~='table' then return nil,'The game control locks are unavailable.' end
    for _,locked in pairs(c.locks or {})do if locked then return nil,'Input locks active: '..diagnostic_fields(c.locks,true)..'.' end end
    if g.play and g.play.cards and #g.play.cards>0 then return nil,'Wait for the played cards to settle.' end
    local allowed=settled_main_menu(g)
    if g.STAGE==g.STAGES.RUN then
      for _,name in ipairs({'SELECTING_HAND','SHOP','BLIND_SELECT','ROUND_EVAL','GAME_OVER'})do
        if g.STATES[name]~=nil and g.STATE==g.STATES[name]then allowed=true end
      end
    end
    if not allowed then return nil,'Wait for a stable menu, hand, shop, blind or result screen.' end
    return true
  end
  function api.can_begin()
    if active and not active.exited or manual or B.native_search_busy or runtime and runtime.busy() then
      return nil,'Another search or start request is active.'
    end
    return safe(game())
  end
  function api.prepare(options)
    local p,why=progress();if not p then return nil,why end
    if not query or type(query.prepare)~='function' then return nil,'The collection query builder is unavailable.' end
    local ok,q,reason=pcall(query.prepare,p.goal,gold,options)
    if not ok or not q then return nil,ok and reason or 'The collection request could not be prepared.' end
    if not primary(q)then return nil,'The opening identity and native target recipe are inconsistent.'end
    local requested=q.budget_ms;q.budget_ms=math.min(requested,27000)
    B.collection_product_generation=(whole(B.collection_product_generation,0,9007199254740990)and B.collection_product_generation or 0)+1
    local request={schema=1,request_id=B.collection_product_generation,profile_id=p.profile_id,profile_token=p.token,
      query=q,requested_budget_ms=requested}
    prepared[request]={snapshot=copy(request),begun=false}
    return request
  end
  local function bound(job)
    local p,why=progress()
    if not p or p.token~=job.request.profile_token then return nil,why or 'The active profile or missing Gold population changed.' end
    if input()~=job.input then return nil,'Manual input changed the search context.' end
    if not same_run(job.identity,game())then return nil,'The current run changed after this search was requested.' end
    return p
  end
  local function cursor()
    local index=B.collection_search_cursor
    if index==nil then
      local ok,seconds=pcall(deps.wall_time or os.time)
      if not ok or not whole(seconds,0,9007199254740991)then return nil,'An independent seed cursor could not be initialized.' end
      index=seconds%(DOMAIN-1)+1;B.collection_search_cursor=index
    end
    if not whole(index,1,DOMAIN-1)then return nil,'The independent seed cursor is exhausted or invalid.' end
    return index
  end
  function api.begin(request,owner)
    if not owner_ok(owner) then return nil,'An explicit search owner is required.' end
    local record=prepared[request]
    if not record or record.begun or not equal(request,record.snapshot)then return nil,'The prepared request is stale, modified or already used.' end
    local allowed,why=api.can_begin();if not allowed then return nil,why end
    if not runtime or type(runtime.start)~='function' or type(runtime.poll)~='function' then return nil,'The asynchronous search runtime is unavailable.' end
    local p,reason=progress();if not p or p.token~=request.profile_token then return nil,reason or 'The loaded Gold population changed.' end
    local stamp=input();if stamp==nil then return nil,'Input ownership is unavailable.' end
    local index,err=cursor();if not index then return nil,err end
    local seed=M.seed_at(index)
    local job={owner=owner,request=copy(record.snapshot),input=stamp,identity=run_identity(game()),start_index=index,
      start_seed=seed,exited=false,status='searching',stage=1,stage_receipts={}}
    job.effective_query=copy(job.request.query)
    if job.request.query.burnt_fallback==true then
      local t=clock(job);if not t then return nil,'A monotonic clock is required for the bounded Burnt fallback.' end
      job.started=t;job.deadline=t+job.request.query.budget_ms/1000
      job.effective_query.budget_ms=math.max(1,math.min(9000,math.floor(job.request.query.budget_ms/3)))
    end
    job.native_reserved_ms=job.effective_query.budget_ms
    -- Consume before dispatch, including partially started workers. Never retry
    -- a start failure using the same request or initial index.
    record.begun=true;active=job;B.collection_search_cursor=index+1
    local ok,generation,failure=pcall(runtime.start,job.effective_query,seed,job.request.profile_token)
    job.generation=ok and generation or nil
    if not generation or not ok then
      job.status='error';job.reason=ok and failure or 'Native search dispatch failed.'
      job.cancelled=true;runtime.stop(job.reason)
      job.exited=not runtime.busy();api.status=job.reason
      return nil,job.reason
    end
    api.status=opening_status(job.effective_query)..(job.deadline and ('Searching with Burnt first ('..tostring(job.effective_query.budget_ms/1000)..'s).') or
      ('Searching for the Gold opening (native limit '..tostring(job.request.query.budget_ms/1000)..' seconds).'))
    event('collection_search_started',{request_id=request.request_id,generation=generation,owner=owner,
      profile_id=request.profile_id,start_seed=seed,requested_budget_ms=request.requested_budget_ms,budget_ms=job.request.query.budget_ms,
      first_phase_budget_ms=job.effective_query.budget_ms,burnt_fallback=job.request.query.burnt_fallback==true,
      primary_legendary_key=job.effective_query.primary_legendary_key or 'j_yorick',opening_adapted=job.effective_query.opening_adapted==true})
    return request.request_id
  end
  local function output(job)
    return {request_id=job.request.request_id,generation=job.generation,exited=job.exited,status=job.status,
      found=job.found,reason=job.reason}
  end
  function api.cancel(owner,reason)
    if not active or active.owner~=owner then return false end
    local job=active;job.cancelled=true;job.found=nil;job.found_snapshot=nil
    job.status=job.exited and 'cancelled' or 'stopping';job.reason=tostring(reason or 'Stopped by the user.'):sub(1,512)
    if not job.exited then runtime.stop(job.reason)end
    api.status=job.reason;return true
  end
  local function native_matches(done,job)
    if not plain(done.request) or done.request.profile_id~=job.request.profile_id then return false end
    for _,key in ipairs(native_fields)do if done.request[key]~=job.effective_query[key]then return false end end
    return true
  end
  local function relax_burnt(job)
    if not job.deadline or job.stage~=1 or job.cancelled or job.request.query.burnt_fallback~=true then return false end
    local t=clock(job)
    if not t then job.status='error';job.reason='Search clock became unavailable or moved backwards.';return false end
    local remaining=math.min(job.request.query.budget_ms-job.native_reserved_ms,math.floor((job.deadline-t)*1000))
    if remaining<1 then
      if t>=job.deadline then job.status='timeout';job.reason='The original search wall budget is exhausted.'
      else job.reason='No Burnt fallback allocation remains in this request.' end
      return false
    end
    local valid,why=bound(job);local allowed,reason=safe(game())
    if not valid or not allowed or B.native_search_busy or runtime.busy()then
      job.reason=why or reason or 'The previous native worker has not exited.';return false
    end
    local q=copy(job.request.query)
    local _,name=primary(q)
    if not name or q.burnt_required==false then
      job.status='error';job.reason='The fixed opening changed before its Burnt fallback.';return false
    end
    q.target_jokers=table.concat({name,'Brainstorm','','Perkeo',''},'\31')
    q.target_locations=table.concat({'soul_pack','by_ante_5','ante_1','soul_pack','ante_1'},'\31')
    q.burnt_required=false;q.budget_ms=remaining
    local index,err=cursor();if not index then job.status='error';job.reason=err;return false end
    job.stage=2;job.start_index=index;job.start_seed=M.seed_at(index);job.effective_query=q
    job.native_reserved_ms=job.native_reserved_ms+remaining
    job.exited=false;job.status='searching';job.reason=nil;B.collection_search_cursor=index+1
    local ok,generation,failure=pcall(runtime.start,q,job.start_seed,job.request.profile_token)
    job.generation=ok and generation or nil
    if not ok or not generation then
      job.cancelled=true;job.stop_status='error';job.reason=ok and failure or 'Burnt fallback dispatch failed.'
      runtime.stop(job.reason);job.exited=not runtime.busy();job.status=job.exited and 'error' or 'stopping'
      api.status=job.reason;return true
    end
    api.status=opening_status(q)..'Searching without required Burnt; same total time limit.'
    event('collection_search_burnt_relaxed',{request_id=job.request.request_id,generation=generation,stage=2,
      start_seed=job.start_seed,phase_budget_ms=remaining,total_native_reserved_ms=job.native_reserved_ms,
      original_native_budget_ms=job.request.query.budget_ms,elapsed_seconds=t-job.started,
      effective_query=copy(q),prior_stage=copy(job.stage_receipts[1])})
    return true
  end
  function api.poll(owner)
    local job=active;if not job or job.owner~=owner then return nil,'This owner has no search request.' end
    local p,why=bound(job)
    if not p and not job.cancelled and not job.consumed then api.cancel(owner,why)end
    if job.exited then return output(job)end
    if job.deadline and not job.cancelled then
      local t=clock(job)
      if not t or t>=job.deadline then
        api.cancel(owner,t and 'The original search wall budget expired.' or 'Search clock became unavailable or moved backwards.')
        job.stop_status=t and 'timeout' or 'error'
      end
    end
    local done=runtime.poll(p and p.token or 'invalidated')
    if not done then return output(job)end
    if B.native_search_busy or runtime.busy()then
      api.cancel(owner,'A receipt arrived before its native worker exited.');job.stop_status='error';return output(job)
    end
    if job.deadline and not job.cancelled then
      local t=clock(job)
      if not t or t>=job.deadline then
        api.cancel(owner,t and 'The original search wall budget expired.' or 'Search clock became unavailable or moved backwards.')
        job.stop_status=t and 'timeout' or 'error'
      end
    end
    job.exited=true
    if done.generation~=job.generation or done.profile_token~=job.request.profile_token or not native_matches(done,job) then
      job.status='error';job.reason='A stale or mismatched native receipt was rejected.'
    elseif job.cancelled then job.status=job.stop_status or 'cancelled'
    else
      job.status=done.status;job.reason=done.reason
      job.stage_receipts[#job.stage_receipts+1]={stage=job.stage,start_index=job.start_index,start_seed=job.start_seed,
        burnt_required=job.effective_query.burnt_required~=false,allocated_budget_ms=job.effective_query.budget_ms,receipt=copy(done)}
      local native=done.result
      if native and whole(native.screened,0,DOMAIN-1)then
        local next_index=job.start_index+math.max(1,native.screened)
        if done.status=='found' then next_index=(M.seed_id(native.seed)or job.start_index)+1 end
        B.collection_search_cursor=math.max(B.collection_search_cursor or 1,next_index)
      end
      if (done.status=='not_found' or done.status=='timeout') and relax_burnt(job)then return output(job)end
      if done.status=='found' and native and M.seed_id(native.seed)then
        local receipt=copy(done)
        if job.deadline then
          receipt.stages=copy(job.stage_receipts);receipt.burnt_relaxed=job.stage==2
          receipt.original_native_budget_ms=job.request.query.budget_ms;receipt.total_native_reserved_ms=job.native_reserved_ms
          receipt.elapsed_search_seconds=job.latest-job.started
        end
        job.found={seed=native.seed,request_id=job.request.request_id,generation=job.generation,
          profile_token=job.request.profile_token,receipt=receipt}
        job.found_snapshot=copy(job.found)
        api.status=opening_status(job.effective_query)..'Opening found. Waiting to start the requested Gold run.'
      elseif done.status=='found' then job.status='error';job.reason='The native match has no valid receipt.'
      else api.status=done.reason or ('Search finished: '..tostring(done.status)..'.')end
    end
    if job.status~='found'then api.status=job.reason or ('Search finished: '..tostring(job.status)..'.')end
    event('collection_search_finished',{request_id=job.request.request_id,generation=job.generation,status=job.status,
      reason=job.reason,receipt=copy(done),cursor_semantics='match_plus_one_or_completed_count; interrupted parallel chunks are not a contiguous coverage claim'})
    return output(job)
  end
  local function filter_info(job)
    local q=job.effective_query;local seed=job.found.seed;local params={seed}
    for _,field in ipairs(native_fields)do params[#params+1]=q[field]end
    local key=primary(q);if not key then return nil end
    local targets={{key=key,location='soul_pack',edition='any'},
      {key='j_brainstorm',location='by_ante_5',edition='any'},
      {key='j_burnt',location='by_ante_5',edition='any'},
      {key='j_perkeo',location='soul_pack',edition='any'}}
    if q.burnt_required==false then table.remove(targets,3)end
    return {native_api_version=9,stake_level=8,soul_count=2,required_soul_count=2,joker_targets=q.target_jokers,
      joker_target_locations=q.target_locations,no_perishable_jokers=true,observatory_deadline=0,deck_name=q.deck,
      multi_soul_pack_consumed=false,filter_params=params,
      normal_opening={schema=1,kind='normal_two_soul_v1',deck_key=deck_keys[q.deck],stake=8,seed=seed,
        required_souls=2,no_perishable_targets=true,targets=targets},
      collection_search={schema=1,request_id=job.request.request_id,interchangeable_copies=q.interchangeable_copies,
        copy_alternatives=q.interchangeable_copies and {'j_brainstorm','j_blueprint'}or {'j_brainstorm'},
        minimum_distinct=q.minimum_distinct,first_ante=q.first_ante,last_ante=q.last_ante,route=q.route,
        quota_mode=q.quota_mode,burnt_required=q.burnt_required~=false,burnt_relaxed=job.stage==2,
        primary_legendary_key=key,opening_adapted=q.opening_adapted==true,opening_note=q.opening_note,
        original_native_budget_ms=job.request.query.budget_ms,total_native_reserved_ms=job.native_reserved_ms,
        profile_id=job.request.profile_id,profile_token=job.request.profile_token,receipt=copy(job.found.receipt),
        future_acquisition_verified=false}}
  end
  function api.launch(found,owner)
    local job=active
    if not job or owner~=job.owner or not job.exited or job.status~='found' or job.cancelled or job.consumed or
      found~=job.found or not equal(found,job.found_snapshot)then return nil,'This search result is stale, modified, stopped or already consumed.',false end
    local p,why=bound(job)
    if not p then api.cancel(owner,why);return nil,why,false end
    if B.native_search_busy or runtime.busy()then return nil,'Wait for the native worker to exit.',true end
    local g=game();local allowed,reason=safe(g);if not allowed then return nil,reason,true end
    local center=(g.P_CENTERS or {})[deck_keys[job.request.query.deck]]
    if type(center)~='table' or center.key~=deck_keys[job.request.query.deck] or center.set~='Back' or center.mod or center.mod_id then
      api.cancel(owner,'The requested vanilla deck is unavailable.');return nil,job.reason,false
    end
    local make_back=deps.back or Back
    if type(make_back)~='function' and type(make_back)~='table' then return nil,'The deck constructor is unavailable.',false end
    local ok,new_back=pcall(make_back,center)
    if not ok or not new_back or not new_back.effect or new_back.effect.center~=center then return nil,'The requested deck could not be prepared.',false end
    local info=filter_info(job)
    if not info then api.cancel(owner,'The opening receipt no longer matches its native target recipe.');return nil,job.reason,false end
    -- Receipt is spent before the first game mutation. An exception after
    -- delete/start may leave a transition pending; it must never replay launch.
    job.consumed=true;job.status='launching';api.status='Starting the requested Gold run.'
    local started,failure=pcall(function()
      g.GAME.selected_back=new_back;g.GAME.viewed_back=nil
      g.challenge_tab=nil;g.run_setup_seed=false;g.forced_seed=nil
      if deps.delete_run then deps.delete_run(g)else g:delete_run()end
      if deps.start_run then deps.start_run(g,{stake=8,seed=found.seed})else g:start_run({stake=8,seed=found.seed})end
      assert(type(g.GAME)=='table','Run initialization did not return a game')
      g.GAME.used_filter=true;g.GAME.filter_info=info;g.GAME.seeded=false
    end)
    job.status=started and 'started' or 'error'
    job.reason=not started and ('Run start failed after its receipt was consumed: '..tostring(failure))or nil
    -- The completed manual owner must leave before settings invalidation calls
    -- stop(). It no longer owns a pending search after this successful start.
    if started and manual and manual.owner==owner then manual=nil end
    api.status=started and 'Gold run started. Advisor play remains user-controlled.'or job.reason
    event('collection_run_start',{request_id=job.request.request_id,seed=found.seed,deck_key=center.key,stake=8,
      status=job.status,reason=job.reason})
    if started and B.Advisor and type(B.Advisor.settings_changed)=='function' then pcall(B.Advisor.settings_changed)end
    return started or nil,job.reason,false
  end
  function api.start_manual(options)
    if manual or active and not active.exited or B.native_search_busy or runtime and runtime.busy()then return nil,'A search is already active.' end
    if not runtime or type(runtime.start)~='function' or type(runtime.poll)~='function' or type(runtime.busy)~='function' then
      return nil,'The asynchronous search runtime is unavailable.'
    end
    local request,why=api.prepare(options);if not request then api.status=tostring(why);return nil,why end
    local g=game()
    if B.ar_active or B.Checkpoints and B.Checkpoints.pending then return nil,'Wait for the current reroll or checkpoint operation.' end
    if g and g.OVERLAY_MENU then
      local exit=deps.exit_overlay or (g.FUNCS and g.FUNCS.exit_overlay_menu)
      if type(exit)~='function' then return nil,'The current overlay cannot be closed safely.' end
      local ok,err=pcall(exit);if not ok then return nil,'The overlay could not close: '..tostring(err)end
    end
    manual={owner='manual:'..request.request_id,request=request,input=input(),identity=run_identity(game()),phase='waiting'}
    manual_request_owner=manual.owner
    api.status='Waiting for the menu to close before searching.'
    return true,request.request_id
  end
  -- Public observation only: reading status cannot arm, poll or cancel work.
  function api.status_report()
    local job=active and active.owner==manual_request_owner and active or nil
    local requested=manual_request_owner~=nil
    return {requested=requested,busy=manual~=nil or job~=nil and not job.exited,
      text=api.status,phase=manual and manual.phase or job and job.status or requested and 'stopped' or 'idle',
      owner=requested and (manual~=nil or not active or job~=nil) and 'manual' or nil}
  end
  function api.stop(reason)
    local stopped=manual~=nil;manual=nil
    if active and not active.consumed then stopped=api.cancel(active.owner,reason)or stopped end
    if stopped then api.status=tostring(reason or 'Stopped by the user.')end
    return stopped
  end
  function api.update()
    local pending=manual
    if pending then
      local p,why=progress()
      if not p or p.token~=pending.request.profile_token or input()~=pending.input or not same_run(pending.identity,game())then
        api.stop(why or 'The requested search context changed.');pending=nil
      end
    end
    if pending and pending.phase=='waiting'then
      local allowed,why=safe(game())
      if not allowed then api.status='Waiting: '..tostring(why) end
      if allowed and not B.native_search_busy and not runtime.busy()then
        manual=nil
        local id,why=api.begin(pending.request,pending.owner)
        if id then pending.phase='searching';manual=pending else api.status=tostring(why)end
      end
    end
    if active and not active.exited then api.poll(active.owner)end
    if manual and manual.phase=='searching' and active and active.exited then
      if active.status=='found'then
        local launched,why,retryable=api.launch(active.found,manual.owner)
        if launched or not retryable then manual=nil end
        if why then api.status=why end
      else manual=nil end
    end
  end
  B.CollectionSearchProduct=api;return api
end
return M
