-- Pure metadata for five user-managed checkpoint reloads. No saves, game,
-- filesystem, clocks or RNG are accessed. A reported losing continuation is
-- evidence about that observed line, never proof that its first action is bad.
local M={SCHEMA=1,LIMIT=5}
local MAX_KEY,MAX_ACTION,MAX_MARKS,MAX_ATTEMPTS=131072,4096,256,64
local phases={hand=true,shop=true,blind=true,pack=true,round=true}
local function integer(v,lo,hi) return type(v)=='number' and v==v and v%1==0 and v>=lo and v<=hi end
local function plain_table(v) return type(v)=='table' and getmetatable(v)==nil end
local function array_size(v,limit)
  if not plain_table(v) or #v>limit then return nil end
  local count=0
  for k in pairs(v) do if not integer(k,1,#v) then return nil end;count=count+1 end
  if count~=#v then return nil end
  return count
end
local ignored={id=true,sort_id=true,playing_card=true,blueprint_compat_ui=true,blueprint_compat_check=true}
local private={seed=true,pseudorandom=true,rng=true,rng_state=true,deck_order=true,draw_order=true,
  next_draw=true,future_cards=true,hidden_identity=true}
local function detached(value,public)
  local seen,nodes={},0
  local function visit(v,depth)
    nodes=nodes+1
    if nodes>8192 or depth>12 then error('Metadata exceeds its structural bound.') end
    local kind=type(v)
    if kind=='nil' or kind=='boolean' then return v end
    if kind=='number' then if v~=v or math.abs(v)==math.huge then error('Nonfinite metadata.') end;return v end
    if kind=='string' then if #v>(public and 2048 or MAX_KEY) then error('Metadata string is too large.') end;return v end
    if not plain_table(v) or seen[v] then error('Metadata must be acyclic plain data.') end
    seen[v]=true;local out={}
    for k,item in pairs(v) do
      if type(k)~='string' and not integer(k,1,8192) then error('Unsupported metadata key.') end
      if type(k)=='string' and #k>128 then error('Metadata key is too large.') end
      if not (public and ignored[k]) then
        if public and private[k] then error('Private-state metadata is not a public checkpoint.') end
        if public and (k=='unknown' or k=='uncertain' or k=='unsupported' or k=='concealed' or k=='face_down' or k=='wheel_flipped') and item then
          error('Unknown or concealed observation cannot mark a checkpoint.')
        end
        out[k]=visit(item,depth+1)
      end
    end
    seen[v]=nil;return out
  end
  local ok,result=pcall(visit,value,0)
  if not ok then return nil,result end
  return result
end
local function encode(value)
  if value==nil then return 'z' end
  if type(value)=='boolean' then return value and 'b1' or 'b0' end
  if type(value)=='number' then return 'n'..string.format('%.17g',value)..';' end
  if type(value)=='string' then return 's'..#value..':'..value end
  local keys,out={}, {'{'}
  for k in pairs(value) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)<type(b) end;return a<b end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k);out[#out+1]=encode(value[k]) end
  out[#out+1]='}';return table.concat(out)
end
local scalar_fields={'phase','challenge','round','ante','deck_key','opening_pack','dollars','bankrupt_at',
  'rental_rate','win_ante','consumeable_buffer','chips','hands_left','discards_left','hands_played',
  'discards_used','hands_played_total','starting_deck_size','joker_limit','consumable_limit','hand_limit',
  'hand_size','blind_on_deck','pack_choices','pack_kind','reroll_cost','interest_cap','next_blind_chips',
  'skips','unused_discards','interest_amount','last_tarot_planet','first_used_hand_level'}
local table_fields={'hands','modifiers','blind','consumeable_usage_total','consumeable_usage','current_round',
  'round_resets','probabilities','blind_choices','blind_states','skip_tags','next_blind','route_blinds',
  'route_tags','active_tags','round_bonus','used_vouchers'}
local zones={'hand','jokers','consumeables','shop_jokers','shop_vouchers','shop_booster','pack_cards'}
local card_fields={'key','name','rank','nominal','suit','enhancement','edition','seal','debuff','ability',
  'cost','base_cost','sell_cost','rarity','blueprint_compat','vampired','pinned'}
local function concealed(card)
  return card.face_down or card.facing=='back' or card.unknown or card.concealed or card.uncertain or
    card.unsupported or (plain_table(card.ability) and card.ability.wheel_flipped)
end
local function composition_card(card)
  if not plain_table(card) or type(card.key)~='string' or card.key=='' or
    card.unknown or card.uncertain or card.unsupported or card.concealed or
    not integer(card.rank,2,14) or not ({Spades=true,Hearts=true,Clubs=true,Diamonds=true})[card.suit] then
    return nil,'Incomplete public playing-card composition.'
  end
  local out={};for _,k in ipairs(card_fields) do out[k]=card[k] end
  if out.ability~=nil then
    if not plain_table(out.ability) then return nil,'Malformed playing-card ability.' end
    local ability={}
    for k,v in pairs(out.ability) do
      if k~='wheel_flipped' and k~='forced_selection' and k~='discarded' then ability[k]=v end
    end
    out.ability=ability
  end
  local safe,reason=detached(out,true);if not safe then return nil,reason end
  return encode(safe)
end
-- This is exact equality of a bounded PUBLIC projection, not a hidden RNG or
-- save identity oracle. Public composition is included only after excluding
-- concealed held/outside cards. IDs partition zones but never enter the key;
-- sorted composition erases future draw order and arbitrary object addresses.
function M.public_key(snapshot)
  if not plain_table(snapshot) or not phases[snapshot.phase] then return nil,'Unsupported checkpoint phase.' end
  if snapshot.unknown or snapshot.uncertain or snapshot.unsupported or snapshot.concealed then return nil,'Unknown public observation.' end
  if not integer(snapshot.ante,1,1000000) or not integer(snapshot.round,0,1000000) then return nil,'Missing public ante/round identity.' end
  local out={}
  for _,k in ipairs(scalar_fields) do
    if type(snapshot[k])=='table' then return nil,'Expected a scalar public field.' end
    out[k]=snapshot[k]
  end
  for _,k in ipairs(table_fields) do
    if snapshot[k]~=nil and not plain_table(snapshot[k]) then return nil,'Expected plain public metadata.' end
    out[k]=snapshot[k]
  end
  for _,zone in ipairs(zones) do
    local cards=snapshot[zone] or {};local size=array_size(cards,512)
    if not size then return nil,'Malformed or oversized visible card area.' end
    out[zone]={}
    for i=1,size do
      local card=cards[i]
      if not plain_table(card) or concealed(card) then
        return nil,'Unknown or concealed visible card.'
      end
      if type(card.key)~='string' or card.key=='' then return nil,'Missing public card identity.' end
      local item={};for _,k in ipairs(card_fields) do item[k]=card[k] end
      out[zone][i]=item
    end
  end
  for _,zone in ipairs({'deck','playing_cards'}) do
    local size=array_size(snapshot[zone],512)
    if not size then return nil,'Missing bounded public population count.' end
    out[zone..'_count']=size
  end
  local population,occupied={},{}
  for _,card in ipairs(snapshot.playing_cards) do
    if not plain_table(card) or type(card.id)~='string' or #card.id==0 or #card.id>256 or population[card.id] then
      return nil,'Public population partition has missing or duplicate identities.'
    end
    population[card.id]=card
  end
  for _,zone in ipairs({'hand','deck'}) do
    for _,card in ipairs(snapshot[zone] or {}) do
      if not plain_table(card) or not population[card.id] or occupied[card.id] then return nil,'Public hand/deck partition is incomplete.' end
      occupied[card.id]=true
    end
  end
  -- Check visibility before inspecting any nondrawable card's identity payload.
  for id,card in pairs(population) do
    if not occupied[id] and concealed(card) then return nil,'Concealed outside cards prevent an exact public checkpoint.' end
  end
  out.remaining_composition={};out.population_composition={}
  local compositions={}
  for id,card in pairs(population) do
    local payload,reason=composition_card(card);if not payload then return nil,reason end
    compositions[id]=payload;out.population_composition[#out.population_composition+1]=payload
  end
  for _,zone in ipairs({'hand','deck'}) do
    for _,card in ipairs(snapshot[zone] or {}) do
      local payload,reason=composition_card(card);if not payload then return nil,reason end
      if payload~=compositions[card.id] then return nil,'Public card composition disagrees across observed zones.' end
      if zone=='deck' then out.remaining_composition[#out.remaining_composition+1]=payload end
    end
  end
  table.sort(out.remaining_composition);table.sort(out.population_composition)
  local safe,reason=detached(out,true);if not safe then return nil,reason end
  local key='retry-state-v1:'..encode(safe)
  if #key>MAX_KEY then return nil,'Public checkpoint exceeds its byte bound.' end
  return key
end
local function indices(values,limit,maximum,complete)
  local size=array_size(values,maximum);if not size or complete and size~=limit then return nil end
  local out,used={},{}
  for i=1,size do local n=values[i];if not integer(n,1,limit) or used[n] then return nil end;used[n]=true;out[i]=n end
  return out
end
local action_fields={kind=true,area=true,index=true,indices=true,targets=true,order=true,blind=true,followup=true}
local function canonical_action(current_phase,sizes,action)
  if not plain_table(action) then return nil,'Action must be plain data.' end
  for k in pairs(action) do if not action_fields[k] then return nil,'Unknown action field.' end end
  local kind=action.kind;local out={kind=kind};local required={kind=true}
  -- Existing sell advice may describe a future purchase, but execution only
  -- sells once and replans. Its line-start key describes that actual first move.
  if action.followup~=nil then
    local f=action.followup
    if kind~='sell' or not plain_table(f) or not ({buy=true,open=true,choose=true})[f.kind] or
      not ({shop_jokers=true,shop_vouchers=true,shop_booster=true,pack_cards=true})[f.area] or not integer(f.index,1,512) then
      return nil,'Unsupported descriptive action followup.'
    end
    for k in pairs(f) do if k~='kind' and k~='area' and k~='index' then return nil,'Unknown followup semantics.' end end
    required.followup=true
  end
  local function area(expected)
    if action.area~=nil and action.area~=expected then return false end
    out.area=expected;required.area=true;return true
  end
  if kind=='play' or kind=='discard' then
    if current_phase~='hand' or not area('hand') then return nil,'Action does not match the public phase/area.' end
    out.indices=indices(action.indices,sizes.hand,5)
    required.indices=true
    if not out.indices or #out.indices==0 then return nil,'Invalid ordered hand selection.' end
  elseif kind=='reorder_hand' or kind=='reorder_jokers' then
    local zone=kind=='reorder_hand' and 'hand' or 'jokers'
    if kind=='reorder_hand' and current_phase~='hand' and current_phase~='pack' then return nil,'Invalid hand-reorder phase.' end
    if not area(zone) then return nil,'Invalid reorder area.' end
    out.order=indices(action.order,sizes[zone],512,true);required.order=true
    if not out.order or #out.order==0 then return nil,'Invalid complete permutation.' end
  elseif kind=='use' or kind=='choose' or kind=='buy' or kind=='open' or kind=='buy_and_use' or kind=='sell' then
    local zone=action.area
    if kind=='use' then zone=zone or 'consumeables';if zone~='consumeables' then return nil,'Unknown use area.' end
    elseif kind=='choose' then zone=zone or 'pack_cards';if current_phase~='pack' or zone~='pack_cards' then return nil,'Invalid pack choice.' end
    elseif kind=='buy' then
      if current_phase~='shop' or not (zone=='shop_jokers' or zone=='shop_vouchers') then return nil,'Invalid shop purchase.' end
    elseif kind=='open' then
      zone=zone or 'shop_booster';if current_phase~='shop' or zone~='shop_booster' then return nil,'Invalid booster opening.' end
    elseif kind=='buy_and_use' then
      zone=zone or 'shop_jokers';if current_phase~='shop' or zone~='shop_jokers' then return nil,'Invalid immediate shop use.' end
    elseif not (zone=='jokers' or zone=='consumeables') then return nil,'Invalid owned sale.' end
    if not area(zone) or not integer(action.index,1,sizes[zone]) then return nil,'Action refers to an absent public card.' end
    out.index=action.index;required.index=true
    if kind=='use' or kind=='choose' or kind=='buy_and_use' then
      out.targets=indices(action.targets or {},sizes.hand,5);required.targets=true
      if not out.targets then return nil,'Invalid ordered consumable targets.' end
    end
  elseif kind=='select_blind' or kind=='skip_blind' then
    if current_phase~='blind' or not ({Small=true,Big=true,Boss=true})[action.blind] then return nil,'Invalid public blind choice.' end
    out.blind=action.blind;required.blind=true
  else
    local phase=({leave_shop='shop',reroll='shop',skip_pack='pack',cash_out='round'})[kind]
    if not phase or current_phase~=phase then return nil,'Unsupported action.' end
  end
  for k in pairs(action) do if not required[k] then return nil,'Extraneous action semantics.' end end
  local key='retry-action-v1:'..encode(out)
  if #key>MAX_ACTION then return nil,'Action exceeds its byte bound.' end
  return key
end
-- A caller comparing one immutable detached decision may validate its public
-- observation once. The closure retains only phase and area lengths, no card
-- references. Do not persist it or reuse it for another live observation.
function M.action_key_context(snapshot)
  local key,reason=M.public_key(snapshot);if not key then return nil,reason end
  local sizes={};for _,zone in ipairs(zones) do sizes[zone]=#(snapshot[zone] or {}) end
  local phase=snapshot.phase
  return function(action) return canonical_action(phase,sizes,action) end
end
function M.action_key(snapshot,action)
  local encoder,reason=M.action_key_context(snapshot);if not encoder then return nil,reason end
  return encoder(action)
end
local function run_id_ok(id) return type(id)=='string' and #id>0 and #id<=256 and not id:find('%c') end
local function exact_fields(value,allowed)
  if not plain_table(value) then return false end
  for k in pairs(value) do if not allowed[k] then return false end end
  return true
end
local function valid_key(key,prefix,limit)
  if type(key)~='string' or #key<=#prefix or #key>limit or key:sub(1,#prefix)~=prefix then return false end
  local payload=key:sub(#prefix+1);local pos,nodes=1,0
  local function parse(depth)
    nodes=nodes+1;if nodes>8192 or depth>12 then error('Encoded key exceeds bound.') end
    local token=payload:sub(pos,pos);pos=pos+1
    if token=='z' then return nil
    elseif token=='b' then
      local value=payload:sub(pos,pos);pos=pos+1
      if value~='0' and value~='1' then error('Invalid boolean.') end;return value=='1'
    elseif token=='n' then
      local finish=payload:find(';',pos,true);if not finish or finish-pos>32 then error('Invalid number.') end
      local value=tonumber(payload:sub(pos,finish-1));pos=finish+1
      if not value or value~=value or math.abs(value)==math.huge then error('Invalid number.') end;return value
    elseif token=='s' then
      local finish=payload:find(':',pos,true);if not finish or finish-pos>6 then error('Invalid string length.') end
      local length=tonumber(payload:sub(pos,finish-1))
      if not integer(length,0,MAX_KEY) or finish+length>#payload then error('Invalid string.') end
      pos=finish+length+1;return payload:sub(finish+1,finish+length)
    elseif token=='{' then
      local out={}
      while payload:sub(pos,pos)~='}' do
        if pos>#payload then error('Unclosed table.') end
        local k=parse(depth+1)
        if type(k)~='string' and not integer(k,1,8192) then error('Invalid encoded key.') end
        if out[k]~=nil then error('Duplicate encoded key.') end
        local v=parse(depth+1);if v==nil then error('Nil table value.') end;out[k]=v
      end
      pos=pos+1;return out
    end
    error('Unknown encoded token.')
  end
  local ok,value=pcall(parse,0)
  return ok and plain_table(value) and pos==#payload+1 and encode(value)==payload
end
local function validated(journal,run_id)
  if not run_id_ok(run_id) then return nil,'Missing stable public run identity.' end
  local copy,reason=detached(journal,false);if not copy then return nil,reason or 'Malformed retry journal.' end
  if not exact_fields(copy,{schema=true,run_id=true,limit=true,reloads_used=true,marks=true,checkpoint=true,reports=true}) or
    copy.schema~=M.SCHEMA or copy.run_id~=run_id or copy.limit~=M.LIMIT or
    not integer(copy.reloads_used,0,M.LIMIT) or not integer(copy.marks,0,MAX_MARKS) or
    not array_size(copy.reports,M.LIMIT) or #copy.reports~=copy.reloads_used then return nil,'Malformed or mismatched retry journal.' end
  local previous_sequence,reported=0,{}
  for _,entry in ipairs(copy.reports) do
    if not exact_fields(entry,{checkpoint_sequence=true,action_key=true}) or
      not integer(entry.checkpoint_sequence,1,copy.marks) or entry.checkpoint_sequence<previous_sequence or
      not valid_key(entry.action_key,'retry-action-v1:',MAX_ACTION) then return nil,'Malformed run-wide reload reports.' end
    reported[entry.checkpoint_sequence]=reported[entry.checkpoint_sequence] or {}
    if reported[entry.checkpoint_sequence][entry.action_key] then return nil,'Duplicate run-wide reload report.' end
    reported[entry.checkpoint_sequence][entry.action_key]=true
    previous_sequence=entry.checkpoint_sequence
  end
  local cp=copy.checkpoint
  if cp==nil then if copy.marks~=0 or copy.reloads_used~=0 then return nil,'Missing checkpoint history.' end;return copy end
  if not exact_fields(cp,{key=true,attempts=true,failures=true,pending=true,sequence=true}) or
    not valid_key(cp.key,'retry-state-v1:',MAX_KEY) or cp.sequence~=copy.marks or copy.marks<1 or
    not array_size(cp.attempts,MAX_ATTEMPTS) or not array_size(cp.failures,M.LIMIT) or #cp.failures>copy.reloads_used then
    return nil,'Malformed checkpoint journal.'
  end
  local attempted,failed={},{ }
  for _,key in ipairs(cp.attempts) do
    if not valid_key(key,'retry-action-v1:',MAX_ACTION) or attempted[key] then return nil,'Malformed attempted action journal.' end
    attempted[key]=true
  end
  for index,entry in ipairs(cp.failures) do
    if not exact_fields(entry,{action_key=true,scope=true,reload=true}) or entry.scope~='reported_line_start' or
      not attempted[entry.action_key] or failed[entry.action_key] or not integer(entry.reload,1,copy.reloads_used) then return nil,'Malformed reported failure journal.' end
    local report=copy.reports[entry.reload]
    if report.checkpoint_sequence~=cp.sequence or report.action_key~=entry.action_key or cp.attempts[index]~=entry.action_key then return nil,'Reported failure disagrees with the run counter.' end
    if failed.reload and entry.reload<=failed.reload then return nil,'Failure counters must increase.' end
    failed[entry.action_key]=true;failed.reload=entry.reload
  end
  if cp.pending~=nil and (type(cp.pending)~='string' or not attempted[cp.pending] or failed[cp.pending]) then return nil,'Unrecorded or stale pending action.' end
  local current_reports=0;for _ in pairs(reported[cp.sequence] or {}) do current_reports=current_reports+1 end
  if current_reports~=#cp.failures or #cp.attempts~=#cp.failures+(cp.pending and 1 or 0) or
    cp.pending and cp.attempts[#cp.attempts]~=cp.pending then return nil,'Checkpoint attempt history is incomplete.' end
  return copy
end
function M.new(run_id)
  if not run_id_ok(run_id) then return nil,'Missing stable public run identity.' end
  return {schema=M.SCHEMA,run_id=run_id,limit=M.LIMIT,reloads_used=0,marks=0,reports={}}
end
function M.import(journal,run_id) return validated(journal,run_id) end
function M.export(ledger)
  if not plain_table(ledger) then return nil,'Malformed retry ledger.' end
  return validated(ledger,ledger.run_id)
end
function M.mark(ledger,run_id,snapshot)
  local out,reason=validated(ledger,run_id);if not out then return nil,reason end
  local key;key,reason=M.public_key(snapshot);if not key then return nil,reason end
  if out.checkpoint and out.checkpoint.key==key then return out end
  if out.marks>=MAX_MARKS then return nil,'Checkpoint metadata allowance exhausted.' end
  out.marks=out.marks+1
  out.checkpoint={key=key,sequence=out.marks,attempts={},failures={}}
  return out
end
local function matched(ledger,run_id,snapshot)
  local out,reason=validated(ledger,run_id);if not out then return nil,reason end
  local key;key,reason=M.public_key(snapshot);if not key then return nil,reason end
  if not out.checkpoint or out.checkpoint.key~=key then return nil,'The public state does not match the marked checkpoint.' end
  return out
end
function M.record(ledger,run_id,snapshot,action)
  local out,reason=matched(ledger,run_id,snapshot);if not out then return nil,reason end
  local key;key,reason=M.action_key(snapshot,action);if not key then return nil,reason end
  local cp=out.checkpoint
  if cp.pending then return nil,'A recorded line is already pending.' end
  for _,entry in ipairs(cp.failures) do if entry.action_key==key then return nil,'That line start was already reported; it is not a new retry.' end end
  for _,previous in ipairs(cp.attempts) do if previous==key then return nil,'That action is stale in this checkpoint journal.' end end
  if #cp.attempts>=MAX_ATTEMPTS then return nil,'Attempt metadata allowance exhausted.' end
  cp.attempts[#cp.attempts+1]=key;cp.pending=key
  return out
end
function M.failed(ledger,run_id,restored_snapshot)
  local out,reason=matched(ledger,run_id,restored_snapshot);if not out then return nil,reason end
  if out.reloads_used>=M.LIMIT then return nil,'All five manual reloads have been recorded for this run.' end
  local cp=out.checkpoint
  if not cp.pending then return nil,'No executed checkpoint line is recorded.' end
  out.reloads_used=out.reloads_used+1
  out.reports[#out.reports+1]={checkpoint_sequence=cp.sequence,action_key=cp.pending}
  cp.failures[#cp.failures+1]={action_key=cp.pending,scope='reported_line_start',reload=out.reloads_used}
  cp.pending=nil
  return out
end
function M.context(ledger,run_id,snapshot)
  local out,reason=validated(ledger,run_id)
  if not out then return {active=false,reason=reason,failed_actions={},valid=false} end
  local result={active=false,valid=true,reloads_used=out.reloads_used,reloads_remaining=M.LIMIT-out.reloads_used,
    limit=M.LIMIT,failed_actions={},evidence='user_reported_public_checkpoint',pending=out.checkpoint and out.checkpoint.pending or nil}
  local key;key,reason=M.public_key(snapshot)
  if not key or not out.checkpoint or out.checkpoint.key~=key then result.reason=reason or 'The public checkpoint is not restored.';return result end
  result.matched=true;result.checkpoint_sequence=out.checkpoint.sequence
  result.attempts=#out.checkpoint.attempts;result.failures=#out.checkpoint.failures
  for _,entry in ipairs(out.checkpoint.failures) do result.failed_actions[entry.action_key]=true end
  result.active=#out.checkpoint.failures>0 and not out.checkpoint.pending
  return result
end
return M
