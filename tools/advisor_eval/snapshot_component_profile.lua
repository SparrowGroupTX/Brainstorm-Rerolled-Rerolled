-- Appended to the frozen source adapter's module-setup prefix. There is no
-- original game state, dispatcher, callback, opening search or action execution.
local input=assert(PROFILE_INPUT,'Missing frozen detached input')
local s=assert(input.decision_started.snapshot,'Missing captured snapshot')
modules.decision=decision
local initial=modules.snapshot.fingerprint(s)
local profile,stack={},{}
local function packed(...) return {n=select('#',...),...} end
local function timed(object,key,label)
  local original=object and object[key];if type(original)~='function' then return end
  object[key]=function(...)
    local frame={child=0};stack[#stack+1]=frame
    local start=os.clock();local output=packed(pcall(original,...));local elapsed=os.clock()-start
    stack[#stack]=nil
    if stack[#stack] then stack[#stack].child=stack[#stack].child+elapsed end
    local entry=profile[label] or {calls=0,inclusive_seconds=0,self_seconds=0};profile[label]=entry
    entry.calls=entry.calls+1;entry.inclusive_seconds=entry.inclusive_seconds+elapsed
    entry.self_seconds=entry.self_seconds+math.max(0,elapsed-frame.child)
    if not output[1] then error(output[2],0) end
    return unpack(output,2,output.n)
  end
end
for _,name in ipairs({'search','decision'}) do timed(modules[name],'run',name) end
for _,name in ipairs({'economy','ordering','hand_ordering','boss_rescue','mixed_rescue','multi_discard',
  'growth','blind_prep','blind_routing','shop_sequences','two_hand_finish','resource_finish'}) do timed(modules[name],'suggest',name) end
timed(modules.strategy,'advise','strategy')
timed(modules.consumables,'suggest','consumables')
timed(modules.consumables,'develop','consumables_develop')
timed(modules.scoring,'score','score')
timed(modules.scoring,'classify','score_classify')
timed(modules.scoring,'lower_bound','score_lower_bound')
timed(modules.strategy.conditional_value,'assess','conditional_value')
if modules.shop_scoring then
  local original=modules.shop_scoring.new
  if original then modules.shop_scoring.new=function(...)
    local context=original(...)
    timed(context,'compare','shop_compare');timed(context,'readiness','shop_readiness')
    return context
  end end
end
local function json(value)
  if value==nil then return 'null' end
  if type(value)=='boolean' or type(value)=='number' then return tostring(value) end
  if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
    local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return e[c] or string.format('\\u%04x',string.byte(c)) end)..'"' end
  assert(type(value)=='table','Unsupported profile result value')
  local out={}
  if #value>0 then for _,v in ipairs(value) do out[#out+1]=json(v) end;return '['..table.concat(out,',')..']' end
  local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys) do out[#out+1]=json(key)..':'..json(value[key]) end
  return '{'..table.concat(out,',')..'}'
end
-- Deliberately no options argument: preserve every product default and budget.
local started=os.clock();local result=modules.decision.run(s,modules);local elapsed=os.clock()-started
assert(modules.snapshot.fingerprint(s)==initial,'Detached profiling mutated its input')
local expected=input.source_profile
local parity={action_available=input.source_action~=nil,metrics_available=expected~=nil,
  action_matches=input.source_action and modules.snapshot.fingerprint(result.action)==modules.snapshot.fingerprint(input.source_action) or nil,
  score_calls_match=expected and score_calls==expected.score_calls or nil,
  evaluations_match=expected and result.evaluations==expected.evaluations or nil}
-- Preserve false mismatches rather than losing them through Lua's and/or idiom.
if input.source_action then parity.action_matches=modules.snapshot.fingerprint(result.action)==modules.snapshot.fingerprint(input.source_action) end
if expected then parity.score_calls_match=score_calls==expected.score_calls;parity.evaluations_match=result.evaluations==expected.evaluations end
parity.complete=not not (parity.action_available and parity.metrics_available and parity.action_matches and parity.score_calls_match and parity.evaluations_match)
local decision_fingerprint=modules.snapshot.fingerprint(result)
return json({type='detached_decision_component_profile',step=input.step,phase=s.phase,
  elapsed_seconds=elapsed,clock='instrumented Lua os.clock',input_fingerprint=initial,
  input_unchanged=true,decision_fingerprint=decision_fingerprint,action=result.action,
  action_fingerprint=modules.snapshot.fingerprint(result.action),evaluations=result.evaluations,
  score_calls=score_calls,source_parity=parity,search_truncated=result.truncated or false,
  score_cache=result.score_cache,components=profile,options='product_defaults_no_overrides'})
