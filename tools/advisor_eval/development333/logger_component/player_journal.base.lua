-- Opt-in JSONL observations at action entry and callback outcome. This never
-- evaluates advice, advances RNG, reads saves, or alters retry metadata.
local M={MAX_EVENT_BYTES=1048576,MAX_SESSION_BYTES=33554432,MAX_TOTAL_BYTES=1073741824,MAX_EVENTS=2048}
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
function M.new(deps)
  local J={events=0,bytes=0,sequence=0,status='Recording is off.',suppressed=0}
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
  function J:enabled()return deps.enabled and deps.enabled()==true end
  local function fail(why)
    J.error=tostring(why);J.status='Recording stopped: '..J.error
    if deps.notice then deps.notice(J.status) end;return false,J.error
  end
  function J:event(kind,details,observation)
    if not self:enabled() then self.status='Recording is off.';return false end
    if self.error then return false,self.error end
    if not deps.archive and self.events>=M.MAX_EVENTS then return fail('Session event limit reached; existing logs are preserved.') end
    local p=performance();local total_started=tick(p)
    local monotonic,clock_reason=event_clock()
    local observed_started=tick(p)
    local ok,entry=pcall(function()
      local context=observation or deps.observe()
      self.sequence=self.sequence+1
      return {schema=1,sequence=self.sequence,kind=kind,at=deps.now(),
        monotonic_seconds=monotonic,monotonic_status=monotonic~=nil and 'available' or 'unavailable',
        monotonic_reason=clock_reason,context=context,details=details or {}}
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
  function J:timing(kind,details)
    return self:event(kind,details,{}) -- compact; never observes a full snapshot
  end
  function J:before(kind,details)
    if not self:enabled() or self.suppressed>0 then return nil end
    local ok,sequence=self:event('action_requested',{action=kind,input=details,source=self.source or 'player_callback'})
    return ok and sequence or nil
  end
  function J:after(sequence,accepted,reason)
    if sequence then self:event('action_callback_result',{action_sequence=sequence,callback_returned=accepted,
      reason=reason,completion='Callback result only; queued effects may still be pending.'},{})
      if accepted then self.pending_state=sequence end
    end
  end
  return J
end
local callbacks={'play_cards_from_highlighted','discard_cards_from_highlighted','buy_from_shop','use_card',
  'sell_card','reroll_shop','skip_booster','toggle_shop','cash_out','select_blind','skip_blind'}
function M.attach(A,B,deps)
  deps=deps or {};local fs=deps.fs or love and love.filesystem
  local archive
  if not deps.append then
    archive={}
    function archive:append(entry,bytes)
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
      local okay,why=self.inner:append(entry,bytes)
      self.physical_bytes=self.inner.physical_bytes;return okay,why
    end
    function archive:rotate(reason)if self.inner then self.inner:rotate(reason)end end
  end
  local function observe()
    local g=deps.game and deps.game() or G;local s=A.snapshot.capture(g)
    local current=s and A.snapshot.fingerprint(s)==A.published_key and A.published_game==g.GAME
    local game=g.GAME or {};local profile=(g.SETTINGS or {}).profile
    return {version=B.VERSION,profile=profile,seed=(game.pseudorandom or {}).seed,stake=game.stake,
      run_round=game.round,won_field=game.won,game_over=g.STATES and g.STATE==g.STATES.GAME_OVER,
      snapshot=M.public_snapshot(s),snapshot_scope='Detached public observation; concealed identities redacted; shop catalog forecast omitted.',
      advice={status=current and 'current' or A.result and 'stale' or A.worker and 'computing' or 'unavailable',
        timing=current and A.last_decision_result==A.result and A.last_decision_timing or nil,
        title=A.display and A.display.title,lines=A.lines,action=A.result and A.result.action}}
  end
  local J=M.new({enabled=function()return B.config.advisor.player_logging==true end,append=deps.append,
    clock=deps.clock,performance=function()return A.performance end,
    now=deps.now or function()return os.date('!%Y-%m-%dT%H:%M:%SZ') end,observe=deps.observe or observe,archive=archive,
    notice=deps.notice or function()
      if saveManagerAlert then saveManagerAlert('Recording stopped. Open Advisor > Recording status.') end
    end})
  A.player_log=J
  function J:update(g)
    g=g or G
    if not self:enabled() or not self.pending_state or not g or not g.GAME then return end
    local terminal=g.STATES and (g.STATE==g.STATES.GAME_OVER or g.STATE==g.STATES.NEW_ROUND and g.GAME.won)
    local busy=not g.STATE_COMPLETE or g.screenwipe or (g.GAME.STOP_USE or 0)>0 or (g.CONTROLLER or {}).locked
    for _,locked in pairs((g.CONTROLLER or {}).locks or {}) do if locked then busy=true end end
    if busy and not terminal then return end
    local sequence=self.pending_state;self.pending_state=nil
    self:event('state_after_actions',{latest_action_sequence=sequence,
      observation='First settled observation after callbacks; not proof every queued event completed.'})
  end
  function J:install_hooks(g)
    g=g or G;if not g or not g.FUNCS then return end
    self.hooks=self.hooks or {}
    for _,name in ipairs(callbacks) do
      local original=g.FUNCS[name]
      if type(original)=='function' and original~=self.hooks[name] then
        local function wrapped(...)
          local args={...};local selected={};local e=args[1]
          for _,card in ipairs(g.hand and g.hand.highlighted or {}) do
            for i,c in ipairs(g.hand.cards or {}) do if c==card then selected[#selected+1]=i end end
          end
          local ref=type(e)=='table' and e.config and e.config.ref_table
          local center=type(ref)=='table' and ref.config and ref.config.center
          local sequence=J:before(name,{selected=selected,key=center and center.key,button=type(e)=='table' and e.config and e.config.id})
          local function packed(...)return {n=select('#',...),...} end
          local outcome=packed(pcall(original,...));local ok=outcome[1]
          J:after(sequence,ok and outcome[2]~=false,not ok and tostring(outcome[2]) or nil)
          if not ok then error(outcome[2],0) end
          return unpack(outcome,2,outcome.n)
        end
        self.hooks[name]=wrapped;g.FUNCS[name]=wrapped
      end
    end
  end
  J:install_hooks()
  return J
end
return M
