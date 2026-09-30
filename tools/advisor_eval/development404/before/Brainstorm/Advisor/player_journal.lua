-- Opt-in JSONL observations at action entry and callback outcome. This never
-- evaluates advice, advances RNG, reads saves, or alters retry metadata.
local M={MAX_EVENT_BYTES=1048576,MAX_SESSION_BYTES=33554432,MAX_TOTAL_BYTES=10737418240,MAX_EVENTS=2048}
local function plain_copy(value,depth,seen,budget)
  depth,seen,budget=depth or 0,seen or {},budget or {n=0}
  budget.n=budget.n+1;assert(depth<=24 and budget.n<=100000,'Observation exceeds its structure bound.')
  local t=type(value)
  if t=='number' then assert(value==value and math.abs(value)<math.huge,'Nonfinite observation.');return value end
  if t=='string' then assert(#value<=262144,'Observation string exceeds its bound.');return value end
  if t=='boolean' then return value end
  if t~='table' then return nil end
  assert(not seen[value],'Cyclic observation.');seen[value]=true;local out={}
  for k,v in pairs(value) do
    if type(k)=='string' or type(k)=='number' then out[k]=plain_copy(v,depth+1,seen,budget) end
  end
  seen[value]=nil;return out
end
local function quoted(s)
  return '"'..s:gsub('[%z\1-\31\\"]',function(c)
    local known={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return known[c] or string.format('\\u%04x',string.byte(c))
  end)..'"'
end
local function json(v)
  local t=type(v)
  if t=='string' then return quoted(v) elseif t=='number' then return string.format('%.17g',v)
  elseif t=='boolean' then return v and 'true' or 'false' elseif t~='table' then return 'null' end
  local keys,array={},true
  for k in pairs(v) do keys[#keys+1]=k;if type(k)~='number' or k%1~=0 or k<1 or k>#v then array=false end end
  if #keys==0 then array=false end
  local out={}
  if array then for _,value in ipairs(v) do out[#out+1]=json(value) end;return '['..table.concat(out,',')..']' end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do out[#out+1]=quoted(tostring(k))..':'..json(v[k]) end
  return '{'..table.concat(out,',')..'}'
end
function M.encode(value)
  local ok,result=pcall(function()return json(plain_copy(value)) end)
  if not ok then return nil,tostring(result) end
  if #result>M.MAX_EVENT_BYTES then return nil,'Observation exceeds its byte bound.' end
  return result..'\n'
end
function M.encode_frame(value)
  local ok,result=pcall(function()return json(plain_copy(value))end)
  if not ok then return nil,tostring(result)end
  if #result>3145728 then return nil,'Archive frame exceeds its byte bound.'end
  return result..'\n'
end
function M.public_snapshot(snapshot)
  local safe=plain_copy(snapshot)
  if not safe then return nil end
  safe.shop_forecast=nil -- large catalog hypotheses, not a visible game screen
  local deck,hidden={},{}
  for _,card in ipairs(safe.deck or {}) do if card.id then deck[card.id]=true end end
  for _,card in ipairs(safe.hand or {}) do if card.face_down and card.id then hidden[card.id]=true end end
  for _,card in ipairs(safe.playing_cards or {}) do
    if card.id and card.face_down and not deck[card.id] then hidden[card.id]=true end
  end
  -- Ordinary remaining-deck backs are known composition. With genuine hidden
  -- held/outside cards, exposing the exact draw-pile assignment would reveal
  -- their identities by subtraction. Keep counts and redact those assignments.
  local concealment=next(hidden)~=nil
  if concealment then safe.drawpile_identity_redacted_for_concealment=true end
  for _,area in ipairs({'hand','deck','jokers','consumeables','playing_cards','shop_jokers','shop_vouchers','shop_booster','pack_cards'}) do
    for i,card in ipairs(safe[area] or {}) do
      local known_deck=(area=='deck' or area=='playing_cards') and deck[card.id]
      if hidden[card.id] or known_deck and concealment or card.face_down and not known_deck then
        safe[area][i]={id=card.id,face_down=true,identity_redacted=true}
      end
    end
  end
  return safe
end
function M.semantic_fingerprint(snapshot)
  local okay,safe=pcall(M.public_snapshot,snapshot)
  if not okay then return nil,tostring(safe)end
  if type(safe)~='table'then return nil,'Public observation is unavailable.'end
  -- Clocks/advice are event provenance, not state. Preserve all game counters,
  -- collection metadata and public current-ante blind context in the snapshot.
  for _,key in ipairs({'advice','at','captured_at','observed_at','monotonic_seconds','elapsed_seconds','performance'})do safe[key]=nil end
  local raw,why=M.encode(safe);if not raw then return nil,why end
  -- Compact deterministic transport identity, not a cryptographic digest.
  -- The journal compares the exact canonical bytes too before reusing a key.
  local a,b=0,0
  for i=1,#raw do local c=raw:byte(i);a=(a*131+c)%2147483647;b=(b*137+c)%2147483629 end
  return string.format('public356:%d:%08x%08x',#raw,a,b),safe,raw
end
-- Seconds from the last actual public state change. Catch-up emits one event,
-- carrying skipped deadlines, rather than replaying a burst of old warnings.
function M.idle_warning_deadline(index)
  if type(index)~='number'or index<1 or index%1~=0 then return nil end
  local initial={30,90,150,210,270,330,630,930,1230,1530,2130,2730,3330,3600}
  if index<=#initial then return initial[index]end
  local n=index-#initial;local group=math.floor((n-1)/4);local within=(n-1)%4+1
  if group>40 then return math.huge end
  return 3600+4800*(2^group-1)+within*1200*2^group
end
function M.new(deps)
  local J={events=0,bytes=0,sequence=0,status='Recording is off.',suppressed=0}
  local collection_prefix=deps.collection_prefix or 'teacher'
  assert(collection_prefix=='teacher' or collection_prefix=='manual','Invalid observation collection kind.')
  local collection_schema=collection_prefix=='teacher' and 'teacher_collection_v1' or 'manual_run_v1'
  local last_monotonic
  local function finite_clock(value)
    return type(value)=='number' and value==value and value>=0 and value<math.huge
  end
  local function event_clock()
    local clock=deps.clock
    if clock==nil then clock=love and love.timer and love.timer.getTime end
    if type(clock)~='function' then return nil,'clock_unavailable' end
    local ok,value=pcall(clock)
    if not ok then return nil,'clock_failed' end
    if not finite_clock(value) then return nil,'invalid_clock_value' end
    if last_monotonic and value<last_monotonic then return nil,'clock_regressed' end
    return value
  end
  local function performance()
    local value=deps.performance
    if type(value)=='function' then local ok,result=pcall(value);value=ok and result or nil end
    return type(value)=='table' and value or nil
  end
  local function tick(p)
    if not p or type(p.now)~='function' then return nil end
    local ok,value=pcall(p.now,p)
    return ok and finite_clock(value) and value or nil
  end
  local function measured(p,label,started)
    if started==nil or not p or type(p.record)~='function' then return end
    local finished=tick(p)
    if finished and finished>=started then pcall(p.record,p,label,finished-started) end
  end
  function J:enabled()return not self.preparing and deps.enabled and deps.enabled()==true end
  local function fail(why)
    J.error=tostring(why);J.status='Recording stopped: '..J.error
    if deps.notice then deps.notice(J.status) end;return false,J.error
  end
  function J:_event(kind,details,observation,reference)
    if not self:enabled() then self.status='Recording is off.';return false end
    if self.error then return false,self.error end
    if not deps.archive and self.events>=M.MAX_EVENTS then return fail('Session event limit reached; existing logs are preserved.') end
    local p=performance();local total_started=tick(p)
    local monotonic,clock_reason=event_clock()
    local observed_started=tick(p)
    local ok,entry=pcall(function()
      local context=observation or deps.observe()
      self.sequence=self.sequence+1
      local result={schema=1,sequence=self.sequence,kind=kind,at=deps.now(),
        monotonic_seconds=monotonic,monotonic_status=monotonic~=nil and 'available' or 'unavailable',
        monotonic_reason=clock_reason,context=context,details=details or {}}
      if self.collection_mode then
        result.collection_schema=collection_schema;result.collection_id=self.collection_id
        local ref=reference or self.observation_reference
        if ref then
          result.observation_id=ref.id;result.observation_sequence=ref.sequence
          if kind~=collection_prefix..'_observation'and kind~=collection_prefix..'_advice'then
            if ref.advice_bound then result.advice_sequence=ref.advice_sequence
            else result.advice_sequence=self.advice_reference and self.advice_reference.observation_id==ref.id and self.advice_reference.sequence or nil end
          end
        end
      end
      return result
    end)
    measured(p,'journal.observe',observed_started)
    local function failed(why) measured(p,'journal.total',total_started);return fail(why) end
    if not ok then return failed(entry) end
    local encode_started=tick(p)
    local bytes,why=M.encode(entry)
    measured(p,'journal.encode',encode_started)
    if not bytes then return failed(why) end
    if not deps.archive and self.bytes+#bytes>M.MAX_SESSION_BYTES then return failed('Session byte limit reached; existing logs are preserved.') end
    local written,result,reason
    local append_started=tick(p)
    if deps.archive then written,result,reason=pcall(deps.archive.append,deps.archive,entry,bytes)
    else written,result,reason=pcall(deps.append,bytes,M.MAX_TOTAL_BYTES)end
    measured(p,'journal.append',append_started)
    if not written or not result then return failed(reason or result or 'Journal write failed.') end
    self.events=self.events+1;self.bytes=self.bytes+#bytes
    if monotonic~=nil then last_monotonic=monotonic end
    self.physical_bytes=deps.archive and deps.archive.physical_bytes or self.bytes
    self.status='Recording '..self.events..' events; '..tostring(self.physical_bytes)..' stored bytes.'
    if deps.archive and type(kind)=='string'and (kind:match('^checkpoint') or kind=='auto_run' and type(details)=='table'and details.event=='run_finished')then
      deps.archive:rotate(kind)
    end
    -- Append duration becomes known only after the bytes have been verified.
    -- It belongs to the collector's next summary, never a recursive event or
    -- a rewrite of this already committed observation. No metrics are cleared.
    measured(p,'journal.total',total_started)
    return true,self.sequence
  end
  function J:_collection_context(context)
    local compact=plain_copy(context or {})
    if type(compact.snapshot)=='table'then
      local key,safe,raw=M.semantic_fingerprint(compact.snapshot)
      if not key then return fail(safe)end
      local scope=assert(M.encode({version=compact.version,profile=compact.profile,seed=compact.seed,
        run_instance=compact.run_instance,stake=compact.stake,run_round=compact.run_round,
        won_field=compact.won_field,game_over=compact.game_over,teacher=compact.teacher}))
      local semantic=scope..raw
      if semantic~=self.last_semantic then
        local ref={id=self.collection_id..':'..tostring(self.sequence+1),sequence=self.sequence+1}
        local full=plain_copy(compact);full.snapshot=safe;full.advice=nil
        full.snapshot_schema='brainstorm_public_snapshot_v1';full.semantic_fingerprint=key
        local okay,why=self:_event(collection_prefix..'_observation',{scope='Public state changed; no hidden future.'},full,ref)
        if not okay then return false,why end
        self.observation_reference=ref;self.last_semantic=semantic;self.last_advice=nil;self.advice_reference=nil
        self.last_semantic_at=event_clock();self.idle_warning_index=1
      end
      compact.snapshot=nil;compact.snapshot_schema=nil;compact.semantic_fingerprint=key
    end
    local advice=compact.advice
    if advice then
      local stable=plain_copy(advice);stable.timing=nil
      local key=assert(M.encode({advice=stable,teacher=compact.teacher,observation_id=self.observation_reference and self.observation_reference.id}))
      if key~=self.last_advice then
        local okay,why=self:_event(collection_prefix..'_advice',{scope='Recommendation only; not an executed action or verified outcome.'},compact)
        if not okay then return false,why end
        self.last_advice=key;self.advice_reference={sequence=why,observation_id=self.observation_reference and self.observation_reference.id}
      end
      compact.advice_timing=advice.status=='current'and advice.timing or nil
      compact.advice=nil
    end
    return true,compact
  end
  function J:event(kind,details,observation)
    if not self.collection_mode then return self:_event(kind,details,observation)end
    if not self:enabled()then return false end
    if self.error then return false,self.error end
    local okay,context=pcall(function()return observation or deps.observe()end)
    if not okay then return fail(context)end
    local called,accepted,compact=pcall(self._collection_context,self,context)
    if not called then return fail(accepted)end
    if not accepted then return false,compact end
    return self:_event(kind,details,compact)
  end
  function J:_idle_warning(current)
    if not current or not self.last_semantic_at then return true end
    local elapsed=current-self.last_semantic_at;local index=self.idle_warning_index or 1
    local first=M.idle_warning_deadline(index)
    if elapsed<first then return true end
    local crossed=0
    repeat index=index+1;crossed=crossed+1 until elapsed<M.idle_warning_deadline(index)
    self.idle_warning_index=index
    return self:_event(collection_prefix..'_inactivity_warning',{seconds_without_public_state_change=elapsed,
      warning_deadline_seconds=first,missed_deadlines=math.max(0,crossed-1),
      next_deadline_seconds=M.idle_warning_deadline(index),scope='No public state change; this is not a terminal loss.'},{})
  end
  function J:collection_observe(details)
    if not self.collection_mode or not self:enabled()or self.error then return false,self.error end
    local current=event_clock()
    if current and self.last_collection_poll and current-self.last_collection_poll<0.5 then
      local okay,why=self:_idle_warning(current);if not okay then return false,why end
      return true,self.observation_reference and self.observation_reference.id
    end
    if current then self.last_collection_poll=current end
    if deps.settled and not deps.settled()then return self:_idle_warning(current)end
    local okay,context=pcall(deps.observe)
    if not okay then return fail(context)end
    local called,accepted,why=pcall(self._collection_context,self,context)
    if not called then return fail(accepted)end
    if not accepted then return false,why end
    local emitted,error=self:_idle_warning(current)
    if not emitted then return false,error end
    return true,self.observation_reference and self.observation_reference.id
  end
  local function prepare_archive(self,options)
    options=options or {}
    if self.preparing then return nil,'Observation preparation is already running.'end
    local target=deps.archive
    if not target or type(target.prepare_collection)~='function'then return nil,'Collection archive preparation is unavailable.'end
    self.preparing=true
    local called,okay,receipt,partial=pcall(target.prepare_collection,target,options)
    self.preparing=false
    if not called or not okay then
      local why=tostring(called and receipt or okay);self.error=why;self.status='Recording stopped: '..why
      return nil,why,partial
    end
    self.events,self.bytes,self.sequence,self.physical_bytes=0,0,0,target.physical_bytes or 0
    self.error=nil;self.pending_state=nil;self.pending_actions={};self.action_observations={}
    self.observation_reference=nil;self.last_semantic=nil;self.last_advice=nil;self.advice_reference=nil;last_monotonic=nil
    self.last_collection_poll=nil;self.last_semantic_at=nil;self.idle_warning_index=1
    return true,receipt
  end
  function J:clear_logs()
    if self.pending_state or next(self.pending_actions or {}) or next(self.action_observations or {}) then
      return nil,'Wait for the current action and its observation to settle before clearing logs.'
    end
    local okay,receipt,partial=prepare_archive(self,{clear_existing=true})
    if not okay then return nil,receipt,partial end
    self.collection_mode=false;self.collection_id=nil;self.collection_receipt=nil
    self.status='Logs cleared. No run started.'
    return true,receipt
  end
  function J:prepare_collection(options)
    options=options or {}
    local id=options.collection_id
    if type(id)~='string'or #id<1 or #id>128 or not id:match('^[%w%._%-]+$')then return nil,'A bounded collection identity is required.'end
    local okay,receipt,partial=prepare_archive(self,options)
    if not okay then return nil,receipt,partial end
    self.collection_mode=true;self.collection_id=id;self.collection_receipt=receipt
    self.status='Teacher collection prepared; waiting for a public observation.'
    return true,receipt
  end
  function J:begin_manual(id)
    if collection_prefix~='manual' or self.events~=0 or self.collection_mode then return nil,'Manual writer is not fresh.' end
    if type(id)~='string'or #id<1 or #id>128 or not id:match('^[%w%._%-]+$')then return nil,'A bounded manual run identity is required.'end
    self.collection_mode=true;self.collection_id=id
    self.status='Manual run recording started.'
    return true
  end
  function J:end_collection(reason)
    if self.collection_mode and self:enabled()and not self.error then
      self:_event(collection_prefix..'_collection_ended',{reason=reason or 'Stopped',pending_action_sequences=self.pending_actions,
        scope='Pending callback actions have no subsequent settled observation in this collection.'}, {})
    end
    if self.collection_mode and deps.archive then deps.archive:rotate(collection_prefix..'_collection_ended')end
    self.collection_mode=false;self.observation_reference=nil;self.last_semantic=nil;self.last_advice=nil;self.advice_reference=nil
    self.pending_actions={};self.pending_state=nil;self.action_observations={}
    return true
  end
  function J:timing(kind,details)
    return self:event(kind,details,{}) -- compact; never observes a full snapshot
  end
  function J:before(kind,details)
    if not self:enabled() or self.suppressed>0 then return nil end
    local ok,sequence=self:event('action_requested',{action=kind,input=details,source=self.source or 'player_callback'})
    if ok and self.collection_mode then
      self.action_observations=self.action_observations or {}
      local ref=self.observation_reference
      if ref then self.action_observations[sequence]={id=ref.id,sequence=ref.sequence,advice_bound=true,
        advice_sequence=self.advice_reference and self.advice_reference.sequence}end
    end
    return ok and sequence or nil
  end
  function J:after(sequence,accepted,reason,outcome_kind)
    if sequence then
      local details={action_sequence=sequence,callback_returned=accepted,
        reason=reason,completion='Callback result only; queued effects may still be pending.'}
      if self.collection_mode then
        details.outcome_kind=outcome_kind or (accepted and 'returned' or 'rejected_or_exception')
        self:_event(outcome_kind=='exception'and 'action_callback_exception'or 'action_callback_result',details,{},
          self.action_observations and self.action_observations[sequence])
        if self.action_observations then self.action_observations[sequence]=nil end
        if accepted then self.pending_actions=self.pending_actions or {};self.pending_actions[#self.pending_actions+1]=sequence end
      else self:event('action_callback_result',details,{})end
      if accepted then self.pending_state=self.collection_mode and math.max(self.pending_state or 0,sequence)or sequence end
    end
  end
  return J
end
local callbacks={'play_cards_from_highlighted','discard_cards_from_highlighted','buy_from_shop','use_card',
  'sell_card','reroll_shop','skip_booster','toggle_shop','cash_out','select_blind','skip_blind'}
-- Bounded scalar review of the current decision only. Candidate families,
-- projected snapshots and memoization keys remain outside the journal.
local function compact_gold_review(result)
  if type(result)~='table' or getmetatable(result) then return nil end
  local out,fields,omitted={schema=1,status='current'},0,0
  local function scalar(prefix,source,key,kind,limit,out_key)
    local value=rawget(source,key)
    if value==nil then return end
    local valid=type(value)==kind
    if kind=='number' then
      valid=valid and value==value and value>=0 and value<=limit and value%1==0
    elseif kind=='string' then valid=valid and #value<=limit end
    if valid then
      out[prefix..(out_key or key)]=kind=='string' and value:gsub('[%z\1-\31]',' ') or value;fields=fields+1
    else omitted=omitted+1 end
  end
  local function endpoint_count(value,limit)
    if type(value)~='table' or getmetatable(value) then return nil end
    local count=0
    for key in next,value do
      count=count+1
      if count>limit or type(key)~='number' or key%1~=0 or key<1 or key>limit then return nil end
    end
    for i=1,count do if rawget(value,i)==nil then return nil end end
    return count
  end
  local function nested(source,key)
    local value=rawget(source,key)
    if value==nil then return nil end
    if type(value)=='table' and not getmetatable(value) then return value end
    omitted=omitted+1
  end
  local function preflight(prefix,value)
    if not value then return end
    for _,key in ipairs({'complete','supported','fits'}) do scalar(prefix,value,key,'boolean') end
    for _,key in ipairs({'required_evaluations','available_evaluations'}) do scalar(prefix,value,key,'number',1000000000) end
    scalar(prefix,value,'unique_profiles','number',128)
  end
  local slots=rawget(result,'gold_slot_diagnostics')
  local strategy=rawget(result,'strategy')
  if slots==nil and type(strategy)=='table' and not getmetatable(strategy) then slots=rawget(strategy,'gold_slot_diagnostics') end
  if type(slots)=='table' and not getmetatable(slots) then
    scalar('slots_',slots,'protected_offers','number',128)
    scalar('slots_',slots,'reason','string',512)
  end
  for _,entry in ipairs({{'acquisition_', 'gold_acquisition_diagnostics'},{'retention_', 'gold_retention_diagnostics'},{'final_', 'gold_diagnostics'},{'shop_', 'shop_diagnostics'}}) do
    local prefix,source=entry[1],rawget(result,entry[2])
    if type(source)=='table' and not getmetatable(source) then
      for _,key in ipairs({'complete','projection_complete','evidence_complete','truncated'}) do scalar(prefix,source,key,'boolean') end
      for _,key in ipairs({'scope','reason','unavailable_reason'}) do scalar(prefix,source,key,'string',512) end
      for _,key in ipairs({'evaluations','max_evaluations','comparisons','score_calls','context_evaluations'}) do scalar(prefix,source,key,'number',1000000000) end
      for _,key in ipairs({'before_missing','after_missing'}) do scalar(prefix,source,key,'number',150) end
      if rawget(source,'endpoints')~=nil then
        local count=endpoint_count(rawget(source,'endpoints'),128)
        if count then out[prefix..'endpoint_count']=count;fields=fields+1 else omitted=omitted+1 end
      end
      if prefix=='acquisition_' or prefix=='retention_' then
        local family=nested(source,'order_family')
        if family then
          local count=endpoint_count(rawget(family,'rows'),6)
          if count then out[prefix..'order_rows']=count;fields=fields+1 else omitted=omitted+1 end
        end
        if prefix=='acquisition_' then
          scalar(prefix,source,'order_fallback','string',512)
          preflight(prefix..'preflight_',nested(source,'order_preflight'))
          preflight(prefix..'expanded_preflight_',nested(source,'order_preflight_expanded'))
        else
          scalar(prefix,source,'rows','number',6)
          scalar(prefix,source,'order_budget_fallback','boolean')
          scalar(prefix,source,'arrangement_actions','number',1)
          if rawget(source,'fallback_preflight')~=nil then
            preflight(prefix..'preflight_',nested(source,'fallback_preflight'))
            preflight(prefix..'expanded_preflight_',nested(source,'preflight'))
          else preflight(prefix..'preflight_',nested(source,'preflight')) end
        end
      end
      local selected=rawget(source,'selected')
      if type(selected)=='table' and not getmetatable(selected) then
        scalar(prefix..'selected_',selected,'carried_missing','number',150)
        if prefix=='acquisition_' then scalar(prefix,selected,'setup_actions','number',1,'arrangement_actions') end
        for _,key in ipairs({'cash_after','minimum_opening_score','minimum_score_delta'}) do
          local value=rawget(selected,key)
          if value~=nil then
            if type(value)=='number' and value==value and math.abs(value)<=1e300 then
              out[prefix..'selected_'..key]=value;fields=fields+1
            else omitted=omitted+1 end
          end
        end
      end
    elseif source~=nil then omitted=omitted+1 end
  end
  if fields==0 and omitted==0 then return nil end
  if omitted>0 then out.omitted_fields=omitted end
  return out
end
-- Explicit scalar allowlist: never serialize endpoint states/world assignments.
function M.compact_replacement_review(result)
  local function plain(t)return type(t)=='table' and not getmetatable(t)end
  local shop=plain(result) and rawget(result,'shop_diagnostics')
  local source=plain(shop) and rawget(shop,'replacements')
  if not plain(source) then return end
  local function fields(from,to,keys)
    for _,key in ipairs(keys)do
      local v=rawget(from,key);local t=type(v)
      if t=='boolean' or t=='number' and v==v and math.abs(v)<=1e300 or t=='string' and #v<=128 then to[key]=v end
    end
  end
  local out={schema=1,candidates={}}
   fields(source,out,{'complete','scope','reason','evaluations','evaluations_before','selected_sale','selected_offer',
     'engine_retention_from_sale','engine_retention_to_sale','engine_retention_reason',
    'final_action_kind','final_action_area','final_action_index'})
  local entries=rawget(source,'candidates')
  if plain(entries) then
    for i=1,math.min(18,#entries)do
      local entry=rawget(entries,i)
      if plain(entry)then
        local row={};fields(entry,row,{'sale_index','offer_index','family_id','key','compared','purchase_rating','admitted',
           'ratio','score_kind','samples','common_worlds','reason','merit','cash_after','cost',
           'opening_mean_after','opening_clears_after',
          'perishable_exception','perishable_exception_reason','copy_exception','copy_exception_reason',
          'finishing_complete','finishing_supported','finishing_all_clear'})
        out.candidates[#out.candidates+1]=row
      end
    end
    if #entries>18 then out.truncated=true end
  end
  return out
end
-- Compact scalar admission trace for optional win-first Joker development.
-- The source catalog, scored worlds and future shop hypotheses stay private.
function M.compact_reroll_review(result)
  local function plain(t)return type(t)=='table' and not getmetatable(t)end
  local shop=plain(result) and rawget(result,'shop_diagnostics')
  local surplus=plain(shop) and rawget(shop,'reroll_surplus')
  local development=plain(shop) and rawget(shop,'reroll_development')
  local source=plain(surplus) and rawget(surplus,'status')=='admitted' and surplus or
    plain(development) and rawget(development,'status')~='out_of_scope' and development or surplus or development
  if not plain(source) then return end
  local fields={'schema','mode','status','cost','cost_cap','cash','cash_after',
    'purchase_floor','survival_reserve','interest_floor','required_after',
    'late_surplus','replaceable_slots','catalog_supported','funded_endpoints',
    'admitted_endpoints','catalog_candidates','comparison_count',
    'credited_first_slot_mass','required_first_slot_mass','utility','penalty',
    'miss_complete','expected_development_utility','best_heuristic_gain',
    'scoring_claim','credited_slots'}
  local function compact(source)
    if not plain(source) then return end
    local out={}
    for _,key in ipairs(fields) do
      local v=rawget(source,key);local t=type(v)
      if t=='boolean' or t=='number' and v==v and math.abs(v)<=1e300 or
          t=='string' and #v<=128 then out[key]=v end
    end
    return next(out) and out or nil
  end
  local out=compact(source) or {}
  out.development=compact(development)
  out.surplus=compact(surplus)
  local action=plain(result) and rawget(result,'action')
  if plain(action) and type(rawget(action,'kind'))=='string' then
    out.selected_action=rawget(action,'kind')
  end
  local strategy=plain(result) and rawget(result,'strategy')
  local forecast=plain(strategy) and rawget(strategy,'reroll_forecast')
  if plain(forecast) and type(rawget(forecast,'mode'))=='string' and
      #rawget(forecast,'mode')<=128 then out.selected_mode=rawget(forecast,'mode') end
  return next(out) and out or nil
end
-- Only public scalar admission/final-action fields; never scorer states,
-- sampled card orders, hidden identities or the prepared post-discard world.
function M.compact_yorick_review(result)
  local function plain(t)return type(t)=='table' and not getmetatable(t)end
  if not plain(result) then return nil end
  local out={schema=1}
  local function copy_fields(label,source,fields)
    if not plain(source) then return end
    local row={}
    for _,key in ipairs(fields) do
      local value=rawget(source,key);local kind=type(value)
      if kind=='boolean' or kind=='number' and value==value and math.abs(value)<=1e300 or
        kind=='string' and #value<=256 then row[key]=value end
    end
    if next(row) then out[label]=row end
  end
  copy_fields('risk',rawget(result,'risky_yorick_clear'),
    {'compared','samples','sampled_clears','required_fraction','bonus','taper','minimum_score','late_margin',
     'exact_transition','candidate_count','compared_five_count','qualified_count',
     'qualified_five_count','selected_cards','search_selected','selected',
     'final_action_kind','final_action_matches_search'})
  copy_fields('anchor',rawget(result,'growth_anchor_diagnostics'),
    {'considered','qualified','changed','selected_cards','selected_score'})
  local growth=rawget(result,'growth_diagnostics')
  copy_fields('growth',growth,{'bounded_growth','max_evaluations','candidates'})
  if plain(growth) and plain(rawget(growth,'reasons')) and out.growth then
    local reasons={}
    for i=1,math.min(2,#growth.reasons) do
      local reason=rawget(growth.reasons,i)
      if type(reason)=='string' and #reason<=256 then reasons[#reasons+1]=reason end
    end
    if #reasons>0 then out.growth.reasons=reasons end
  end
  if out.risk or out.anchor or out.growth then return out end
end
function M.compact_copy_death_review(result)
  if type(result)~='table' or getmetatable(result) then return nil end
  local out={schema=1}
  local function scalars(key,source)
    if type(source)~='table' or getmetatable(source) then return end
    local row={}
    for k,v in pairs(source) do
      if type(k)=='string' and #k<=64 and (type(v)=='boolean' or type(v)=='number' and
          v==v and math.abs(v)<=1e300 or type(v)=='string' and #v<=256) then row[k]=v end
    end
    if next(row) then out[key]=row end
  end
  scalars('acquisition',result.copy_acquisition_diagnostics)
  scalars('choice',result.strategy and result.strategy.copy_acquisition_review)
  scalars('death',result.consumable and result.consumable.development)
  scalars('fishing',result.growth and result.growth.growth and result.growth.growth.death_source)
  if out.acquisition or out.choice or out.death or out.fishing then
    local a=result.action or {};out.final_kind=a.kind;out.final_area=a.area;out.final_index=a.index
    return out
  end
end
function M.attach(A,B,deps)
  deps=deps or {};local fs=deps.fs or love and love.filesystem
  local callback_hooks=deps.callback_hooks or A.callback_hooks
  local archive
  if not deps.append then
    archive={}
    function archive:initialize()
      if not self.inner then
        local module=assert(deps.archive_module or A.player_log_archive,'Observation archive module is unavailable.')
        local function hash(raw)
          if deps.hash then return deps.hash(raw)end
          assert(love and love.data and love.data.hash,'Observation hashing is unavailable.')
          return (love.data.hash('sha256',raw):gsub('.',function(c)return string.format('%02x',string.byte(c))end))
        end
        local compress,decompress
        if B.config.advisor.player_log_compression~=false then
          compress=deps.compress or function(raw)
            assert(love and love.data and love.data.compress,'Observation compression is unavailable.')
            return love.data.compress('string','zlib',raw,6)
          end
          decompress=deps.decompress or function(raw)return love.data.decompress('string','zlib',raw)end
        end
        self.inner=module.new({fs=fs,encode=M.encode,encode_frame=M.encode_frame,hash=hash,
          compress=compress,decompress=decompress,read_range=deps.read_range,limits=deps.archive_limits,
          session_name=deps.session_name,identity=function()
            local g=deps.game and deps.game()or G
            return g and g.GAME,g and g.PROFILES and g.PROFILES[(g.SETTINGS or {}).profile]
          end})
      end
      return self.inner
    end
    function archive:append(entry,bytes)
      self:initialize()
      local okay,why=self.inner:append(entry,bytes)
      self.physical_bytes=self.inner.physical_bytes;return okay,why
    end
    function archive:rotate(reason)if self.inner then self.inner:rotate(reason)end end
    function archive:prepare_collection(options)
      self:initialize()
      local okay,receipt,partial=self.inner:prepare_collection(options)
      self.physical_bytes=self.inner.physical_bytes;return okay,receipt,partial
    end
  end
  local run_ids=setmetatable({},{__mode='k'});local run_serial=0
  local function observe()
    local g=deps.game and deps.game() or G;local s=A.snapshot.capture(g)
    -- A missing publication or different game already proves advice is not
    -- current. The full observation remains fresh in every case.
    local current=s and A.published_key~=nil and A.published_game==g.GAME and A.published_generation==A.retry_generation and
      A.snapshot.fingerprint(s)==A.published_key
    local game=g.GAME or {};local profile=(g.SETTINGS or {}).profile
    if not run_ids[game]then run_serial=run_serial+1;run_ids[game]='observed-game:'..run_serial end
    local collection=A.player_log and A.player_log.collection_mode
    return {version=B.VERSION,profile=profile,seed=(game.pseudorandom or {}).seed,stake=game.stake,
      run_instance=collection and run_ids[game]or nil,teacher=collection and plain_copy(A.teacher_profile)or nil,
      run_round=game.round,won_field=game.won,game_over=g.STATES and g.STATE==g.STATES.GAME_OVER,
      snapshot=M.public_snapshot(s),snapshot_scope='Detached public observation; concealed identities redacted; shop catalog forecast omitted.',
      advice={status=current and 'current' or A.result and 'stale' or A.worker and 'computing' or 'unavailable',
        timing=current and A.last_decision_result==A.result and A.last_decision_timing or nil,
        gold_review=current and compact_gold_review(A.result) or nil,
        replacement_review=current and M.compact_replacement_review(A.result) or nil,
        yorick_review=current and M.compact_yorick_review(A.result) or nil,
        copy_death_review=current and M.compact_copy_death_review(A.result) or nil,
      reroll_review=current and M.compact_reroll_review(A.result) or nil,
        title=A.display and A.display.title,lines=A.lines,action=A.result and A.result.action}}
  end
  A.player_log_observe=observe
  local J=M.new({enabled=function()return B.config.advisor.player_logging==true end,append=deps.append,
    clock=deps.clock,performance=function()return A.performance end,
    settled=function()
      local g=deps.game and deps.game()or G
      if not g or not g.GAME then return false end
      local c=g.CONTROLLER or {}
      local terminal=g.STATES and (g.STATE==g.STATES.GAME_OVER or g.STATE==g.STATES.NEW_ROUND and g.GAME.won)
      if terminal then return true end
      if not g.STATE_COMPLETE or g.screenwipe or (g.GAME.STOP_USE or 0)>0 or c.locked or
        c.dragging and c.dragging.target or c.text_input_hook or g.OVERLAY_MENU or (g.SETTINGS or {}).paused then return false end
      for _,locked in pairs(c.locks or {})do if locked then return false end end
      return true
    end,
    now=deps.now or function()return os.date('!%Y-%m-%dT%H:%M:%SZ') end,observe=deps.observe or observe,archive=archive,
    notice=deps.notice or function()
      if saveManagerAlert then saveManagerAlert('Recording stopped. Open Advisor > Recording status.') end
    end})
  A.player_log=J
  function J:update(g)
    g=g or G
    if not self:enabled() or not g or not g.GAME then return end
    if not self.collection_mode and not self.pending_state then return end
    local terminal=g.STATES and (g.STATE==g.STATES.GAME_OVER or g.STATE==g.STATES.NEW_ROUND and g.GAME.won)
    local busy=not g.STATE_COMPLETE or g.screenwipe or (g.GAME.STOP_USE or 0)>0 or (g.CONTROLLER or {}).locked
    for _,locked in pairs((g.CONTROLLER or {}).locks or {}) do if locked then busy=true end end
    if self.collection_mode then
      local c=g.CONTROLLER or {}
      busy=busy or g.OVERLAY_MENU or (g.SETTINGS or {}).paused or c.text_input_hook or c.dragging and c.dragging.target
    end
    if busy and not terminal then
      if self.collection_mode then self:collection_observe()end
      return
    end
    if self.collection_mode and not self.pending_state then self:collection_observe();return end
    local sequence=self.pending_state;self.pending_state=nil
    local pending=self.collection_mode and self.pending_actions or nil
    if self.collection_mode then table.sort(pending);self.pending_actions={}end
    self:event('state_after_actions',{latest_action_sequence=sequence,action_sequences=pending,
      observation='First settled observation after callbacks; not proof every queued event completed.'})
  end
  function J:install_hooks(g)
    g=g or G;if not g or not g.FUNCS then return end
    self.hooks=self.hooks or {}
    for _,name in ipairs(callbacks) do
      local original=g.FUNCS[name]
      -- Another owned observer may be the outer wrapper. Its recorded ancestry
      -- still contains this hook; wrapping again would multiply logging each frame.
      local installed=original==self.hooks[name] or callback_hooks and callback_hooks:contains(original,self.hooks[name])
      if type(original)=='function' and not installed then
        local function wrapped(...)
          local sequence
          local target=A.manual_log and A.manual_log:journal_for(g) or J
          -- These request details have no consumer when observation is off,
          -- suppressed by its owning action, or already stopped by an error.
          -- Keep the callback's protected call and exact return/error handling.
          if target:enabled() and target.suppressed<=0 and not target.error then
            local selected={};local e=select(1,...)
            for _,card in ipairs(g.hand and g.hand.highlighted or {}) do
              for i,c in ipairs(g.hand.cards or {}) do if c==card then selected[#selected+1]=i end end
            end
            local ref=type(e)=='table' and e.config and e.config.ref_table
            local center=type(ref)=='table' and ref.config and ref.config.center
            sequence=target:before(name,{selected=selected,key=center and center.key,button=type(e)=='table' and e.config and e.config.id})
          end
          local function packed(...)return {n=select('#',...),...} end
          local outcome=packed(pcall(original,...));local ok=outcome[1]
          target:after(sequence,ok and outcome[2]~=false,not ok and tostring(outcome[2]) or nil,not ok and 'exception'or outcome[2]==false and 'rejected'or 'returned')
          if not ok then error(outcome[2],0) end
          return unpack(outcome,2,outcome.n)
        end
        if callback_hooks then callback_hooks:record(wrapped,original)end
        self.hooks[name]=wrapped;g.FUNCS[name]=wrapped
      end
    end
  end
  J:install_hooks()
  return J
end
return M
