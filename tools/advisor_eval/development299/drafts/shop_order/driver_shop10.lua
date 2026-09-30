-- Appended only to a reviewed frozen dependency prefix. No source dispatcher,
-- original game, filesystem loaders, retry journal, saves or action execution.
local s=assert(PROFILE_INPUT,'Missing frozen public snapshot')
assert(s.phase=='shop','M10 requires a preserved public shop decision')
local initial=modules.snapshot.fingerprint(s)
local profile,stack,instrumented={},{},{}
local function packed(...) return {n=select('#',...),...} end
local function timed(object,key,label)
  local original=object and object[key];if type(original)~='function' then return end
  instrumented[#instrumented+1]={object=object,key=key,original=original}
  object[key]=function(...)
    local frame={child=0};stack[#stack+1]=frame
    local start=os.clock();local out=packed(pcall(original,...));local elapsed=os.clock()-start
    stack[#stack]=nil
    if stack[#stack] then stack[#stack].child=stack[#stack].child+elapsed end
    local row=profile[label] or {calls=0,inclusive_seconds=0,self_seconds=0};profile[label]=row
    row.calls=row.calls+1;row.inclusive_seconds=row.inclusive_seconds+elapsed
    row.self_seconds=row.self_seconds+math.max(0,elapsed-frame.child)
    if not out[1] then error(out[2],0) end
    return unpack(out,2,out.n)
  end
end
timed(modules.search,'run','search')
for _,name in ipairs({'economy','ordering','hand_ordering','boss_rescue','mixed_rescue','multi_discard',
  'growth','blind_prep','blind_routing','shop_sequences','two_hand_finish','resource_finish'}) do timed(modules[name],'suggest',name) end
timed(modules.strategy,'advise','strategy')
timed(modules.consumables,'suggest','consumables')
timed(modules.consumables,'develop','consumables_develop')
for _,key in ipairs({'score','classify','lower_bound','after_play','after_discard'}) do timed(modules.scoring,key,'scoring_'..key) end
if modules.sampled_outcomes then
  for _,key in ipairs({'fill','after_play','roll'}) do timed(modules.sampled_outcomes,key,'sampled_'..key) end
end
local function json(value,active)
  if value==nil then return 'null' end
  if type(value)=='boolean' then return tostring(value) end
  if type(value)=='number' then return contract.trace_number(value) end
  if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
    local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return e[c] or string.format('\\u%04x',string.byte(c)) end)..'"' end
  assert(type(value)=='table','Unsupported decision result value: '..type(value))
  active=active or {};assert(not active[value],'Cyclic decision result');active[value]=true
  local out={}
  if #value>0 then for _,v in ipairs(value) do out[#out+1]=json(v,active) end;active[value]=nil;return '['..table.concat(out,',')..']' end
  local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys) do out[#out+1]=json(key,active)..':'..json(value[key],active) end
  active[value]=nil;return '{'..table.concat(out,',')..'}'
end
-- No options argument and no additional branch search: all product limits stay.
local started=os.clock();local result=decision.run(s,modules);local elapsed=os.clock()-started
assert(modules.snapshot.fingerprint(s)==initial,'Captured policy mutated its input')
local decision_score_calls=score_calls
for _,entry in ipairs(instrumented) do entry.object[entry.key]=entry.original end
local a=result and result.action
local audit={scope='No action dispatched or rescored',source_qualified=false,score_calls=0,status='unsupported',reason='Only detached shop decisions and their existing projections are compared.'}
assert(modules.snapshot.fingerprint(s)==initial,'Selected action audit mutated its input')
return json({type='captured_snapshot_pair_decision',input_unchanged=true,input_fingerprint=initial,
  action_fingerprint=modules.snapshot.fingerprint(a),action=a,result=result,
  score_calls=decision_score_calls,legality_audit=audit,components=profile,
  decision_elapsed_seconds=elapsed,options='product_defaults_no_overrides',
  retry_context='disabled_clean',source_execution=false,terminal_evidence=false})
