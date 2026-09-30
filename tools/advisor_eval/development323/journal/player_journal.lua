-- Opt-in JSONL observations at action entry and callback outcome. This never
-- evaluates advice, advances RNG, reads saves, or alters retry metadata.
local M={MAX_EVENT_BYTES=1048576,MAX_SESSION_BYTES=33554432,MAX_TOTAL_BYTES=134217728,MAX_EVENTS=2048}
local function plain_copy(value,depth,seen,budget,omit_catalog)
  depth,seen,budget=depth or 0,seen or {},budget or {n=0}
  budget.n=budget.n+1;assert(depth<=24 and budget.n<=100000,'Observation exceeds its structure bound.')
  local t=type(value)
  if t=='number' then assert(value==value and math.abs(value)<math.huge,'Nonfinite observation.');return value end
  if t=='string' then assert(#value<=262144,'Observation string exceeds its bound.');return value end
  if t=='boolean' then return value end
  if t~='table' then return nil end
  assert(not seen[value],'Cyclic observation.');seen[value]=true;local out={}
  for k,v in pairs(value) do
    if (type(k)=='string' or type(k)=='number') and not (depth==0 and omit_catalog and k=='shop_forecast') then
      out[k]=plain_copy(v,depth+1,seen,budget)
    end
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
  -- This top-level catalog is never part of a public journal record. Omit it
  -- before traversing instead of copying its full speculative catalog first.
  -- Nested fields with the same name remain ordinary observed data.
  local safe=plain_copy(snapshot,0,nil,nil,true)
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
  function J:enabled()return deps.enabled and deps.enabled()==true end
  local function fail(why)
    J.error=tostring(why);J.status='Recording stopped: '..J.error
    if deps.notice then deps.notice(J.status) end;return false,J.error
  end
  function J:event(kind,details,observation)
    if not self:enabled() then self.status='Recording is off.';return false end
    if self.error then return false,self.error end
    if not deps.archive and self.events>=M.MAX_EVENTS then return fail('Session event limit reached; existing logs are preserved.') end
    local ok,entry=pcall(function()
      local context=observation or deps.observe()
      self.sequence=self.sequence+1
      return {schema=1,sequence=self.sequence,kind=kind,at=deps.now(),context=context,details=details or {}}
    end)
    if not ok then return fail(entry) end
    local bytes,why=M.encode(entry);if not bytes then return fail(why) end
    if not deps.archive and self.bytes+#bytes>M.MAX_SESSION_BYTES then return fail('Session byte limit reached; existing logs are preserved.') end
    local written,result,reason
    if deps.archive then written,result,reason=pcall(deps.archive.append,deps.archive,entry,bytes)
    else written,result,reason=pcall(deps.append,bytes,M.MAX_TOTAL_BYTES)end
    if not written or not result then return fail(reason or result or 'Journal write failed.') end
    self.events=self.events+1;self.bytes=self.bytes+#bytes
    self.physical_bytes=deps.archive and deps.archive.physical_bytes or self.bytes
    self.status='Recording '..self.events..' events; '..tostring(self.physical_bytes)..' stored bytes.'
    if deps.archive and type(kind)=='string'and (kind:match('^checkpoint') or kind=='auto_run' and type(details)=='table'and details.event=='run_finished')then
      deps.archive:rotate(kind)
    end
    return true,self.sequence
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
    -- A fresh action-time observation is still captured. Only skip the costly
    -- fingerprint when a published result cannot belong to this live game.
    local current=s and A.published_key~=nil and A.published_game==g.GAME and
      A.snapshot.fingerprint(s)==A.published_key
    local game=g.GAME or {};local profile=(g.SETTINGS or {}).profile
    return {version=B.VERSION,profile=profile,seed=(game.pseudorandom or {}).seed,stake=game.stake,
      run_round=game.round,won_field=game.won,game_over=g.STATES and g.STATE==g.STATES.GAME_OVER,
      snapshot=M.public_snapshot(s),snapshot_scope='Detached public observation; concealed identities redacted; shop catalog forecast omitted.',
      advice={status=current and 'current' or A.result and 'stale' or A.worker and 'computing' or 'unavailable',
        title=A.display and A.display.title,lines=A.lines,action=A.result and A.result.action}}
  end
  local J=M.new({enabled=function()return B.config.advisor.player_logging==true end,append=deps.append,
    now=deps.now or function()return os.date('!%Y-%m-%dT%H:%M:%SZ') end,observe=deps.observe or observe,archive=archive,
    notice=deps.notice or function(text)if saveManagerAlert then saveManagerAlert(text) end end})
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
