-- Test the actual product callback with a detached FFI stand-in. Never load a
-- native DLL, initialize a game, or call any gameplay action.
local file=assert(io.open('Brainstorm/Core/Brainstorm.lua','rb'))
local core=file:read('*a');file:close()
local first=assert(core:find('function(seed, challenge, targets, later)',1,true))
local last=assert(core:find('\n  end})',first,true))
local body=core:sub(first,last+5)
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local calls,freed={},{}
local native={}
function native.brainstorm_set_search_thread_mode(mode) calls.mode=mode end
function native.brainstorm_challenge_opening_v1(...) calls.v1={...};return 'v1-pointer' end
function native.brainstorm_challenge_opening_v2(...) calls.v2={...};return 'v2-pointer' end
function native.free_result(pointer) freed[#freed+1]=pointer end
local environment={Brainstorm={config={ar_prefs={native_cpu_mode='balanced'}}},
  ensureImmolateLoaded=function()return native end,
  ffi={string=function(pointer)return 'json:'..pointer end},pcall=pcall,error=error}
local chunk=assert(loadstring('return '..body));setfenv(chunk,environment)
local search=chunk()
check(search('SEED1','c_xray_1','j_perkeo')=='json:v1-pointer','v1 default result')
check(calls.v1[1]=='SEED1' and calls.v1[3]=='j_perkeo' and not calls.v2,'default keeps v1 ABI')
check(freed[1]=='v1-pointer' and calls.mode==0,'default release and balanced mode')
environment.Brainstorm.config.ar_prefs.native_cpu_mode='maximum'
local later={target_key='j_blueprint',deadline=4,rare_pool_mask='11111111111111111111'}
check(search('SEED2','c_city_1','j_yorick,j_perkeo',later)=='json:v2-pointer','v2 result')
check(calls.v2[4]=='j_blueprint' and calls.v2[5]==4 and calls.v2[6]==later.rare_pool_mask,'v2 typed query forwarded')
check(calls.mode==1 and freed[2]=='v2-pointer','v2 release and maximum mode')
environment.ffi.string=function()error('decode failed')end
local ok,why=pcall(search,'SEED2','c_city_1','',later)
check(not ok and tostring(why):find('decode failed',1,true),'decode failure stays explicit')
check(freed[3]=='v2-pointer','native allocation freed even on decode error')
native.brainstorm_challenge_opening_v2=nil
ok=pcall(search,'SEED2','c_city_1','',later)
check(not ok and #freed==3,'missing v2 cannot silently fall back to an unfiltered opening')
print('advisor_native_dispatch: '..checks..' checks passed')
