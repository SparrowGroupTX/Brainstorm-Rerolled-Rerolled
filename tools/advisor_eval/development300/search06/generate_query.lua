-- Pure installed313 query/facade fixture. No native, source or game callbacks.
local base='tools/advisor_eval/runs/legendary313_installed/policy/Brainstorm/'
local query=dofile(base..'Advisor/collection_search.lua')
local gold=dofile(base..'Advisor/gold_search.lua')
local stickers=dofile(base..'Advisor/gold_stickers.lua')
local product=dofile(base..'Core/collection_search_product.lua')
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local goal={schema=1,goal='gold_stickers',profile_id='synthetic_s06_only_canio',metadata_status='complete',
  catalog_status='complete',stake_status='complete',counts={total=150,complete=149,missing=1,unknown=0},by_key={}}
for _,key in ipairs(stickers.target_keys())do goal.by_key[key]={key=key,status=key=='j_caino'and'missing'or'complete'}end
local options={quota_mode='auto',minimum_distinct=0,legendary_fallback=true,burnt_fallback=true,
  first_ante=1,last_ante=8,deck_name='Red Deck',interchangeable_copies=true,budget_ms=30000}
local direct=assert(query.prepare(goal,gold,options))
assert(direct.primary_legendary_key=='j_caino'and direct.minimum_distinct==1 and direct.missing_names=='Canio')
assert(direct.opening_adapted and direct.reject_perishable_targets and direct.native_cpu_mode=='maximum')
local g={GAME={round=0,pseudorandom={seed='SYNTHETIC'}},STAGES={MAIN_MENU=1,RUN=2},STAGE=1,
  STATES={MENU=1},STATE=1,STATE_COMPLETE=false,LOADING={font={}},CONTROLLER={locks={},dragging={}},SETTINGS={}}
local B={collection_search_cursor=3000000001,Checkpoints={}}
local calls,live,ready={},false,nil
local runtime={busy=function()return live end,stop=function()error('Unexpected synthetic stop')end}
function runtime.start(q,seed,token)
  assert(not live);live=true;B.native_search_busy=true
  calls[#calls+1]={query=copy(q),seed=seed,profile_token=token,generation=#calls+1}
  return #calls
end
function runtime.poll()
  local out=ready;ready=nil
  if out then live=false;B.native_search_busy=false end
  return out
end
local api=product.attach(B,{game=function()return g end,runtime=runtime,query=query,gold=gold,stickers=stickers,
  progress=function()return goal end,input_token=function()return 0 end,now=function()return 0 end})
local request=assert(api.prepare(options));assert(api.begin(request,'S06-synthetic-preflight'))
assert(#calls==1 and calls[1].query.budget_ms==9000 and request.query.budget_ms==27000)
ready={generation=1,status='not_found',profile_id=request.profile_id,profile_token=request.profile_token,
  request=copy(calls[1].query),result={schema=1,status='not_found',seed='',screened=500,exact_candidates=1,
    seconds=0,budget_ms=9000,threads=1,route=calls[1].query.route}}
assert(not api.poll('S06-synthetic-preflight').exited)
assert(#calls==2 and calls[2].query.budget_ms==18000 and not calls[2].query.burnt_required)
assert(calls[2].query.target_jokers=='Canio\31Brainstorm\31\31Perkeo\31')
assert(calls[2].seed==product.seed_at(3000000501))
local function json(v)
  local kind=type(v)
  if kind=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
    if c=='\\'then return '\\\\'elseif c=='"'then return '\\"'else return string.format('\\u%04x',c:byte())end end)..'"'end
  if kind=='number'or kind=='boolean'then return tostring(v)end
  assert(kind=='table');local keys={};local array=true
  for k in pairs(v)do keys[#keys+1]=k;if type(k)~='number'then array=false end end
  table.sort(keys)
  local out={}
  if array then for i,k in ipairs(keys)do assert(k==i);out[i]=json(v[k])end;return '['..table.concat(out,',')..']'end
  for _,k in ipairs(keys)do out[#out+1]=json(k)..':'..json(v[k])end
  return '{'..table.concat(out,',')..'}'
end
print('S06_QUERY_JSON '..json({schema=1,synthetic=true,game_or_profile_file_access=false,native_calls=0,
  options=options,goal=goal,query=direct,product_request=request,phase_templates=calls,
  template_second_seed_note='Synthetic 500-screened miss only; actual phase2 cursor must derive from actual returned phase1 receipt.'}))
io.stdout:flush()
