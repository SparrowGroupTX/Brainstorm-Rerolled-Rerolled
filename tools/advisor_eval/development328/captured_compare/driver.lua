-- Captured public decision only. No source, capture, execution or action rescore.
local s=assert(PROFILE_INPUT,'Missing frozen public snapshot')
assert(s.phase=='hand' or s.phase=='shop' or s.phase=='pack' or s.phase=='blind','Unsupported public phase')
assert(type(PROFILE_SCORE_CAP)=='number','Missing registered score cap')
local contract=require('probe_engine_contract')
local wiring=require('probe_policy_wiring').verify(A,{enabled=true})
assert(A.opening==nil and A.jokerless_opening==nil,'Live opening integration present')
assert(s.retry_context==nil and s._retry==nil,'Retry data is not admitted')
local initial=A.snapshot.fingerprint(s)
local score_calls=0;local raw_score=A.scoring.score
local function deadline()
 if PROBE_DEADLINE_EXCEEDED() then error('CAPTURED_WALL_TIMEOUT:30',0)end
end
A.scoring.score=function(...)
 deadline()
 if score_calls>=PROFILE_SCORE_CAP then error('CAPTURED_SCORE_CAP:'..PROFILE_SCORE_CAP,0)end
 score_calls=score_calls+1;return raw_score(...)
end
local hook=debug.sethook
hook(deadline,'',5000)
local wall=PROBE_MONOTONIC_SECONDS();local cpu=os.clock()
local okay,result=pcall(A.decision.run,s,A)
hook()
local elapsed=PROBE_MONOTONIC_SECONDS()-wall;local cpu_elapsed=os.clock()-cpu
A.scoring.score=raw_score
local unchanged=A.snapshot.fingerprint(s)==initial
local omitted={depth=0,nodes=0,string_bytes=0,cycles=0,unsupported_values=0}
local budget={nodes=1400}
local function prefix(value,count)
 while count>0 do
  local byte=value:byte(count+1)
  if not byte or byte<128 or byte>=192 then break end
  count=count-1
 end
 return value:sub(1,count)
end
local function project(value,depth,seen)
 budget.nodes=budget.nodes-1
 if budget.nodes<0 then omitted.nodes=omitted.nodes+1;return {omitted='node_limit'}end
 if type(value)=='string'then
  if #value>512 then local text=prefix(value,512);omitted.string_bytes=omitted.string_bytes+#value-#text;return {prefix=text,bytes=#value,omitted='string_tail'}end
  return value
 end
 if type(value)=='number'then
  if value~=value or math.abs(value)==math.huge then omitted.unsupported_values=omitted.unsupported_values+1;return {omitted='nonfinite'}end
  return value
 end
 if value==nil or type(value)=='boolean'then return value end
 if type(value)~='table'then omitted.unsupported_values=omitted.unsupported_values+1;return {omitted='unsupported_type',kind=type(value)}end
 if depth>8 then omitted.depth=omitted.depth+1;return {omitted='depth_limit'}end
 if seen[value] then omitted.cycles=omitted.cycles+1;return {omitted='cycle'}end
 seen[value]=true
 local out,keys={},{}
 for key in pairs(value)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 for i,key in ipairs(keys)do
  if i>64 then omitted.nodes=omitted.nodes+#keys-64;out.__omitted_keys=#keys-64;break end
  if type(key)=='string'or type(key)=='number'then
   out[key]=project(value[key],depth+1,seen)
  else omitted.unsupported_values=omitted.unsupported_values+1 end
 end
 seen[value]=nil;return out
end
local function json(value,seen,full)
 if full then
  full.nodes=full.nodes-1;assert(full.nodes>=0,'Full result node limit')
  if full.nodes%512==0 then deadline()end
 end
 local function scalar(text)
  if full then full.bytes=full.bytes-#text;assert(full.bytes>=0,'Full result byte limit')end
  return text
 end
 if value==nil then return scalar('null') end
 if type(value)=='boolean'then return scalar(tostring(value))end
 if type(value)=='number'then
  assert(value==value and math.abs(value)<math.huge,'Nonfinite result number')
  return scalar(contract.trace_number(value))
 end
 if type(value)=='string'then return scalar('"'..value:gsub('[%z\1-\31\\"]',function(c)
  local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
  return e[c]or string.format('\\u%04x',string.byte(c))end)..'"')end
 assert(type(value)=='table','Unsupported report type')
 seen=seen or {};assert(not seen[value],'Cyclic report');seen[value]=true
 local parts,keys={},{};for key in pairs(value)do keys[#keys+1]=key end
 local array=#value>0 and #keys==#value
 if array then for _,key in ipairs(keys)do if type(key)~='number'or key%1~=0 or key<1 or key>#value then array=false end end end
 if array then
  for _,item in ipairs(value)do parts[#parts+1]=json(item,seen,full)end
  seen[value]=nil;return '['..table.concat(parts,',')..']'
 end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 for _,key in ipairs(keys)do
  assert(not full or type(key)=='string','Full result has non-JSON table keys')
  parts[#parts+1]=json(tostring(key),seen,full)..':'..json(value[key],seen,full)
 end
 seen[value]=nil;return '{'..table.concat(parts,',')..'}'
end
-- Preserve the selected action before large diagnostic families consume the
-- summary node allowance. Full result evidence remains independent below.
local action=okay and result and project(result.action,0,{})or nil
local projected=okay and project(result,0,{})or nil
local error_text=not okay and tostring(result)or not unchanged and 'Captured policy mutated its input.'or nil
local status=okay and unchanged and 'complete'or 'error'
if error_text and error_text:find('CAPTURED_WALL_TIMEOUT',1,true)then status='timeout'end
local report={type='captured_public_decision328',status=status,input_unchanged=unchanged,
 input_fingerprint_bytes=#initial,score_calls=score_calls,reported_evaluations=okay and result and result.evaluations or nil,
 decision_wall_seconds=elapsed,decision_cpu_seconds=cpu_elapsed,
 action=action,result_summary=projected,
 error=error_text and prefix(error_text,2048)or nil,wiring=wiring,omissions=omitted,
 decision_cap=PROFILE_SCORE_CAP,source_execution=false,action_dispatch=false,selected_action_rescore=false,
 retry_context='disabled_clean',qualification=false,terminal_evidence=false,
 public_input_gaps={shop_forecast_absent=s.shop_forecast==nil,deck_absent=s.deck==nil,
  normal_opening_absent=s.normal_opening==nil,completionist_goal_absent=s.completionist_goal==nil},
 scope='One decision using supplied redacted public fields unchanged; missing mechanics/context is not reconstructed.'}
local encoded=json(report)
if #encoded>61440 then
 report.result_summary=nil;report.result_summary_omitted_bytes=#encoded
 report.omissions.output_limit=61440;encoded=json(report)
end
assert(#encoded<=65536,'Bounded report exceeded64KiB')
local full_ok,full_json
if okay then full_ok,full_json=pcall(json,result,nil,{nodes=500000,bytes=16646144})end
if full_ok and #full_json+131072<=16777216 then
 report.full_result_status='preserved'
 report.full_result_json_bytes=#full_json
 return '{"summary":'..json(report)..',"full_result":'..full_json..'}'
end
report.full_result_status='unavailable'
report.full_result_gap=okay and prefix(tostring(full_json or 'Full result output cap exceeded'),2048)or 'Policy failed before a result was produced.'
if report.full_result_gap:find('CAPTURED_WALL_TIMEOUT',1,true)then report.status='timeout'end
return '{"summary":'..json(report)..'}'
