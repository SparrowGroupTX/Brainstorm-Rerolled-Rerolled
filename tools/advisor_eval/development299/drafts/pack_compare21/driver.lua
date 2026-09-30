-- Appended to frozen runtime initialization only. No game source, capture,
-- action dispatch, rescore, live filesystem, retry context or per-score timers.
local contract=require('probe_engine_contract')
local s=assert(PROFILE_INPUT,'Missing frozen public pack state')
assert(s.phase=='pack' and type(s.completionist_goal)=='table','Captured Gold pack required')
local wiring=require('probe_policy_wiring').verify(A,{enabled=true})
assert(A.opening==nil and A.jokerless_opening==nil,'Live opening integration reached comparison')
local initial=A.snapshot.fingerprint(s)
local score_calls=0
local original_score=A.scoring.score
A.scoring.score=function(...)
  if score_calls>=50000 then error('CAPTURED_SCORE_CAP:50000',0) end
  score_calls=score_calls+1
  return original_score(...)
end
local function json(value,active)
  if value==nil then return 'null' end
  if type(value)=='boolean' then return tostring(value) end
  if type(value)=='number' then return contract.trace_number(value) end
  if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
    local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return e[c] or string.format('\\u%04x',string.byte(c)) end)..'"' end
  assert(type(value)=='table','Unsupported decision result: '..type(value))
  active=active or {};assert(not active[value],'Cyclic decision result');active[value]=true
  local parts={}
  if #value>0 then
    for _,item in ipairs(value) do parts[#parts+1]=json(item,active) end
    active[value]=nil;return '['..table.concat(parts,',')..']'
  end
  local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys) do parts[#parts+1]=json(key,active)..':'..json(value[key],active) end
  active[value]=nil;return '{'..table.concat(parts,',')..'}'
end
collectgarbage('collect')
local wall_start=PROBE_MONOTONIC_SECONDS();local cpu_start=os.clock()
local okay,result=pcall(A.decision.run,s,A)
local cpu_elapsed=os.clock()-cpu_start;local wall_elapsed=PROBE_MONOTONIC_SECONDS()-wall_start
A.scoring.score=original_score
local unchanged=A.snapshot.fingerprint(s)==initial
return json({type='captured_pack_decision',status=okay and 'complete' or 'error',
  input_unchanged=unchanged,input_fingerprint=initial,score_calls=score_calls,
  decision_wall_seconds=wall_elapsed,decision_cpu_seconds=cpu_elapsed,
  result=okay and result or nil,error=not okay and tostring(result) or nil,
  action=okay and result and result.action or nil,
  wiring=wiring,score_cache=okay and result and result.score_cache or nil,
  decision_cap=50000,source_execution=false,action_dispatch=false,
  selected_action_rescore=false,retry_context='disabled_clean',gold_context='unchanged_source_snapshot',
  qualification=false,terminal_evidence=false})
