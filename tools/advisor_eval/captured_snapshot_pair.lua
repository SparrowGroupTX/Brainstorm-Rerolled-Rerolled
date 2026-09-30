-- Appended only to a reviewed frozen dependency prefix. No source dispatcher,
-- original game, filesystem loaders, retry journal, saves or action execution.
local s=assert(PROFILE_INPUT,'Missing frozen public snapshot')
assert(s.phase=='hand','Captured pair requires a hand decision')
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
local audit={scope='modeled_selected_action_only',source_qualified=false,score_calls=0,status='unsupported'}
local a=result and result.action
if a and (a.kind=='play' or a.kind=='discard') then
  local count=type(a.indices)=='table' and #a.indices or 0
  local valid=s.phase=='hand' and count>=1 and count<=math.min(5,s.hand_limit or 5)
  local chosen={}
  for key,index in pairs(a.indices or {}) do
    if type(key)~='number' or key%1~=0 or key<1 or key>count or type(index)~='number' or index%1~=0 or
      not (s.hand or {})[index] or chosen[index] then valid=false else chosen[index]=true end
  end
  for i,card in ipairs(s.hand or {}) do if (card.ability or {}).forced_selection and not chosen[i] then valid=false end end
  local round=s.current_round or {}
  local left=a.kind=='play' and (s.hands_left or round.hands_left or 0) or (s.discards_left or round.discards_left or 0)
  valid=valid and left>0
  audit.status=valid and 'legal' or 'illegal';audit.static_selection_legal=valid
  if valid and a.kind=='play' then
    -- A single separate score audit is registered inside this worker's15s cap.
    -- It is not included in the policy's decision score count or search budget.
    local predicted=raw_score(s,a.indices)
    audit.score_calls=1;audit.prediction=predicted
    audit.status=predicted.legal==false and 'illegal' or 'legal'
  end
else audit.reason='This detached audit covers only play/discard; other actions retain unsupported legality.' end
assert(modules.snapshot.fingerprint(s)==initial,'Selected action audit mutated its input')
return json({type='captured_snapshot_pair_decision',input_unchanged=true,input_fingerprint=initial,
  action_fingerprint=modules.snapshot.fingerprint(a),action=a,result=result,
  score_calls=decision_score_calls,legality_audit=audit,components=profile,
  decision_elapsed_seconds=elapsed,options='product_defaults_no_overrides',
  retry_context='disabled_clean',source_execution=false,terminal_evidence=false})
