-- Inert module doubles only: no source initialization, game decisions or files
-- outside repository source and this detached adapter are accessed.
local P='tools/advisor_eval/development299/drafts/complete_adapter315/'
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local source=read(P..'engine_run.lua')
local marker=assert(source:find('local function json(value)',1,true))
local prefix=source:sub(1,marker-1)..'\nreturn modules,wiring_receipt\n'
local verifier=dofile(P..'policy_wiring.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function dummy(name)return {__module_name=name,score=function()return{score=1}end,suggest=function()end,prepare=function()end,compare=function()end}end
local function build(enabled,missing)
  local loaded={}
  local env={PROBE_MONOTONIC_SECONDS=function()return 0 end,
    PROBE_GOLD_OBJECTIVE=enabled and {enabled=true} or {enabled=false,mode='off'},
    package={preload=setmetatable({}, {__index=function(_,key)return key~='probe_policy_'..tostring(missing) and function()end or nil end})}}
  env.require=function(key)
    if key=='probe_policy_wiring' then return verifier end
    if key=='probe_engine_contract' then return {trace_number=tostring} end
    check(key:match('^probe_policy_') or key=='probe_jokerless_opening','no live/source integration required')
    local name=key:gsub('^probe_policy_','')
    if not loaded[name] then loaded[name]=dummy(name) end
    return loaded[name]
  end
  setmetatable(env,{__index=_G})
  local chunk=assert(loadstring(prefix,'@inert_adapter_wiring'))
  setfenv(chunk,env)
  return chunk()
end
local modules,receipt=build(true)
check(receipt.gold_objective_enabled and not receipt.retry_enabled,'explicit Gold enabled and retry disabled')
check(receipt.kind=='complete_source_policy_wiring_315_v1' and #receipt.connections==34,'complete typed wiring graph')
check(modules.snapshot.certificate==modules.certificate,'Certificate capture connected before game initialization')
check(modules.shop_scoring.certificate==modules.certificate,'Certificate comparison connected')
check(modules.shop_scoring.bell_opening==modules.bell_opening,'Bell308 comparison connected')
check(modules.gold_perkeo.__module_name=='gold_perkeo','Gold goal receives empty-pool Perkeo projection')
check(modules.perkeo_inventory.__module_name=='perkeo_inventory','Perkeo whole-inventory projection available')
check(modules.gold_planet_policy.__module_name=='gold_planet_policy','owned Planet hold/use policy available')
check(modules.snapshot.perkeo_inventory==modules.perkeo_inventory,'Perkeo copy-source metadata connected before capture')
check(modules.strategy.pack_survival==modules.pack_survival,'pack survival policy connected')
check(modules.blind_finishing.pack_survival==modules.pack_survival,'terminal resource producer connected to pack comparison')
check(type(modules.hand_copy_preflight.prepare)=='function' and type(modules.hand_copy_preflight.compare)=='function','315 preflight complete interface connected')
local disabled,off=build(false)
check(disabled.gold_goal==nil and not off.gold_objective_enabled,'default-off never fabricates Gold objective context')
for _,name in ipairs({'gold_perkeo','perkeo_inventory','gold_planet_policy','bell_opening','certificate','pack_survival','hand_copy_preflight'}) do
  local okay,why=pcall(build,true,name)
  check(not okay and tostring(why):find('missing required315 policy module '..name,1,true),'missing '..name..' fails before decisions')
end
local function set(root,path,value)
  local parts={};for k in path:gmatch('[^.]+') do parts[#parts+1]=k end
  for i=1,#parts-1 do root=root[parts[i]] end;root[parts[#parts]]=value
end
for _,edge in ipairs(receipt.connections) do
  local m=build(true);set(m,edge.from,{})
  local okay,why=pcall(verifier.verify,m,{enabled=true})
  check(not okay and tostring(why):find('edge mismatch',1,true),'disconnected edge cannot pass: '..edge.from)
end
modules=build(true);modules.retry_memory={}
check(not pcall(verifier.verify,modules,{enabled=true}),'retry module injection fails the clean-attempt contract')

-- Compare the actual product initialization graph using the same inert
-- identity modules. This reads product code but cannot invoke original source.
local runtime=read('Brainstorm/Advisor/runtime.lua')
runtime=runtime:sub(1,assert(runtime:find('function A.defaults()',1,true))-1)..'\nreturn A\n'
local provided={}
local env={Brainstorm={PATH='synthetic',ChallengeOpening=dummy('challenge_opening'),JokerlessOpening=dummy('jokerless_opening')},PROVIDED=provided}
env.require=function(name)
  check(name=='nativefs','product graph requires only inert nativefs loader')
  return {read=function(path)
    local key=assert(path:match('/Advisor/([^/]+)%.lua$'))
    provided[key]=provided[key] or dummy(key)
    return 'return PROVIDED['..string.format('%q',key)..']'
  end}
end
env.load=function(text,name)local f=assert(loadstring(text,name));setfenv(f,env);return f end
setmetatable(env,{__index=_G})
local factory=assert(loadstring(runtime,'@inert_product_graph'));setfenv(factory,env)
local product=factory();local adapter=build(true)
local excluded={execution=true,retry_memory=true,retry_policy=true,retry_journal=true,challenge_route=true,
  opening=true,jokerless_opening=true}
local function compare(expected,actual,path,depth)
  if depth>3 then return end
  for key,v in pairs(expected) do if type(v)=='table' and type(key)=='string' and not (path=='' and excluded[key]) then
    local current=path=='' and key or path..'.'..key
    if v.__module_name then
      check(type(actual[key])=='table' and actual[key].__module_name==v.__module_name,'product module identity matches: '..current)
      compare(v,actual[key],current,depth+1)
    end
  end end
end
compare(product,adapter,'',0)
print('Source adapter wiring: '..checks..' inert checks passed; no source/game/policy decision execution')
