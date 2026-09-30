local C=dofile('tools/advisor_eval/engine_contract.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
check(C.trace_number(math.huge)=='{"nonfinite_number":"positive_infinity"}','positive diagnostic infinity remains explicit valid JSON')
check(C.trace_number(-math.huge)=='{"nonfinite_number":"negative_infinity"}','negative diagnostic infinity remains explicit valid JSON')
check(C.trace_number(0/0)=='{"nonfinite_number":"nan"}','NaN is an explicit unsupported numeric value, never zero')
check(C.trace_number(123.25)=='123.25','ordinary scores retain their exact numeric representation')
local long=string.rep('public cache composition;',1000)
local world={progress=.5,hands_used=4,discards_used=3,dollars_after=1,population_loss=0,finish_reward=0}
local original={action={kind='play',indices={1,2}},snapshot={fingerprint=long},
    readiness={resource_plan={observation_key=long},finishing={selected={worlds={world,world}}}},
    other={observation_key=long},short={observation_key='ordinary_short'},minimum_capacity=math.huge}
local hashed=0
local projected=C.trace_projection(original,function(value) check(value==long,'only the declared raw cache key is hashed');hashed=hashed+1;return string.rep('a',64) end)
check(hashed==1,'repeated large cache keys hash once per diagnostic projection')
check(projected.readiness.resource_plan.observation_key.trace_omitted=='raw_cache_observation_key','raw-key omission is explicitly labeled')
check(projected.readiness.resource_plan.observation_key.bytes==#long,'omitted cache bytes remain measurable')
check(projected.readiness.resource_plan.observation_key.sha256==string.rep('a',64),'exact cache equality remains independently bindable')
check(projected.snapshot.fingerprint==long,'source and policy fingerprints are never compacted')
check(projected.short.observation_key=='ordinary_short','small cache metadata stays unchanged')
check(projected.action.kind==original.action.kind and projected.action.indices[2]==2,'actual first-action semantics stay unchanged')
check(projected.readiness.finishing.selected.worlds[1].progress==.5,'complete policy outcome evidence stays intact')
projected.action.indices[1]=3;projected.readiness.finishing.selected.worlds[1].progress=.25
check(original.action.indices[1]==1 and world.progress==.5 and original.other.observation_key==long,'projection is detached and cannot alter policy or source state')
-- Compile only the serializer's lexical block: this never initializes original
-- source, G, an episode, a save, an executable or any policy module.
local file=assert(io.open('tools/advisor_eval/engine_run.lua','rb'));local source=file:read('*a');file:close()
local body=assert(source:match('(local function json%(value%).-)local function trace'))
local json=assert(loadstring('local contract=...\n'..body..'\nreturn json'))(C)
local encoded=json({score=10,minimum_capacity=math.huge,negative=-math.huge,unknown=0/0})
check(encoded:find('"score":10') and encoded:find('"nonfinite_number":"positive_infinity"'),'actual trace serializer uses explicit nonfinite encoding')
check(not encoded:find(':inf') and not encoded:find(':nan'),'actual trace serializer emits no invalid bare numeric tokens')
print('advisor_engine_trace: '..checks..' checks passed')
