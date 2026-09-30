-- Manufactured input and inert policy doubles only. Never reads C04 snapshots.
local P='tools/advisor_eval/development299/drafts/copy_compare22/'
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local driver=read(P..'driver.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function fingerprint(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,out={},{};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..fingerprint(v[k])end
  return '{'..table.concat(out,';')..'}'
end
local function run(mode,role)
  role=role or 'candidate';local setup=read(P..role..'_module_setup.lua')
  local clock_calls,raw_calls,decisions=0,0,0
  local loaded={}
  local env={PROFILE_ROLE=role,PROFILE_INPUT={phase='hand',hand={{id='one'},{id='two'},{id='three'}},dollars=20,completionist_goal={counts={missing=150,complete=0,total=150,unknown=0}}},
    package={preload=setmetatable({}, {__index=function()return function()end end})}}
  env.PROBE_MONOTONIC_SECONDS=function()clock_calls=clock_calls+1;return clock_calls*0.125 end
  env.require=function(name)
    check(name:match('^probe_policy_') or name=='probe_engine_contract','only frozen policy/trace dependencies')
    if name=='probe_engine_contract' then return {trace_number=function(v)return tostring(v)end} end
    if not loaded[name] then loaded[name]={} end
    local m=loaded[name]
    if name=='probe_policy_snapshot' then m.fingerprint=function(v) return tostring(v.dollars) end
    elseif name=='probe_policy_scoring' then m.score=function()raw_calls=raw_calls+1;return {score=10}end
    elseif name=='probe_policy_decision' then m.run=function(s,a,options)
      decisions=decisions+1
      check(options==nil and a.retry_memory==nil,'unchanged product defaults and clean retry')
      for _=1,(mode=='cap' and 140001 or 100) do a.scoring.score(s,{1}) end
      if mode=='throw' then error('synthetic policy failure') end
      if mode=='mutate' then s.dollars=21 end
      if mode=='metadata' then s.unfingerprinted_metadata='changed' end
      if mode=='hybrid' then s.hand.foo='changed' end
      if mode=='hole' then s.hand[2]=nil end
      if mode=='sparse' then s.hand[100]='changed' end
      if mode=='cycle' then s.hand.self=s.hand end
      return {action={kind='play',indices={1}},evaluations=100,
        score_cache={capacity=8192,stored=10,hits=90,misses=10,score_calls=100}}
    end end
    return m
  end
  setmetatable(env,{__index=_G})
  local text=setup..(mode=='wire' and '\nA.snapshot.certificate=nil\n' or '\n')..driver
  local chunk=assert(loadstring(text,'@synthetic_copy_driver'));setfenv(chunk,env)
  local okay,result=pcall(chunk)
  return okay,result,{clock_calls=clock_calls,raw_calls=raw_calls,decisions=decisions}
end
local okay,result,c=run('normal','baseline')
check(okay and c.decisions==1,'complete installed314 initialization with inert modules')
okay,result,c=run('normal')
check(okay and result:find('"status":"complete"',1,true),'complete manufactured decision output')
check(result:find('"input_unchanged":true',1,true),'input invariant retained')
check(c.raw_calls==100 and c.decisions==1,'one complete decision, no selected-action rescore')
check(c.clock_calls==2,'wall timer runs twice for whole decision, never per score')
check(result:find('"decision_wall_seconds":0.125',1,true),'exact supplied wall interval')
check(result:find('"capacity":8192',1,true),'cache receipt retained')
okay,result,c=run('cap')
check(okay and result:find('CAPTURED_SCORE_CAP:140000',1,true),'cap error is preserved in partial receipt')
check(c.raw_calls==140000 and c.decisions==1,'hard cap prevents the140001st real score call')
check(result:find('"status":"error"',1,true),'cap does not invent completed output')
okay,result,c=run('mutate')
check(okay and result:find('"input_unchanged":false',1,true),'input mutation remains visible for rejection')
okay,result,c=run('metadata')
check(okay and result:find('"input_unchanged":false',1,true),'full input serialization catches metadata outside policy fingerprint')
for _,mode in ipairs({'hybrid','hole','sparse','cycle'}) do
  okay,result,c=run(mode)
  check(okay and result:find('"input_unchanged":false',1,true),'structural receipt catches '..mode..' array mutation')
end
okay,result,c=run('throw')
check(okay and result:find('synthetic policy failure',1,true),'policy error remains visible without retry')
check(c.decisions==1 and c.raw_calls==100,'failed decision is not rerun')
okay,result,c=run('wire')
check(not okay and c.decisions==0,'disconnected Certificate graph fails before decision')
print('M22 driver: '..checks..' synthetic checks passed; no captured evaluation')
