-- Opt-in elapsed-wall diagnostics. No game state capture, RNG or scoring policy.
-- Nested measurements overlap: never add them to their parent phase totals.
local M={}
local buckets={.001,.004,.008,.016,.033,.05,.1,.25,1,5}
local labels={}
for _,name in ipairs({'update_argument_dt','frame_interval','update_total','game_update',
  'checkpoint_update','search_update','journal_update','advisor_update','auto_update','legacy_reroll',
  'original_draw','advisor_hud_draw','draw_total','performance_emit','snapshot.capture',
  'snapshot.fingerprint','advisor.refresh','advisor.present','decision.resume',
  'journal.observe','journal.encode','journal.append','journal.total'}) do labels[name]=true end
local function finite(v) return type(v)=='number' and v==v and v>=0 and v<math.huge end
local function scalar_flags(values)
  local out={}
  for _,key in ipairs({'state','stage','ante','round','paused','dragging','advisor_worker','auto_active','game_speed'}) do
    local v=type(values)=='table' and values[key]
    if type(v)=='boolean' or finite(v) then out[key]=v end
  end
  return out
end
function M.new(deps)
  deps=deps or {}
  local P={generation=0,serial=0,decision_serial=0,clock_failures=0}
  function P:now()
    local ok,on=pcall(deps.enabled or function()return false end)
    if not ok or not on then
      if self.on then self.generation=self.generation+1 end
      self.on=false;self.last_frame=nil;self.last_clock=nil;self.window=nil;self.pending=nil;self.last_emit=nil
      return nil
    end
    self.on=true
    local clock=deps.clock or (love and love.timer and love.timer.getTime)
    local valid,t=false,nil
    if type(clock)=='function' then valid,t=pcall(clock) end
    if not valid or not finite(t) or self.last_clock and t<self.last_clock then
      self.clock_failures=self.clock_failures+1;self.last_frame=nil
      return nil
    end
    self.last_clock=t
    if not self.window then self.window=self:new_window(t) end
    return t
  end
  function P:new_window(t)
    self.serial=self.serial+1
    local bounds={};for i,v in ipairs(buckets) do bounds[i]=v end
    return {schema=1,window_id=self.serial,clock_scope='process_monotonic',units='seconds',
      start_seconds=t,bucket_upper_seconds=bounds,metrics={},slow_frames={},decisions={},
      slow_frames_dropped=0,decisions_dropped=0}
  end
  function P:record(name,seconds)
    if not self.on or not self.window or not labels[name] or not finite(seconds) then return end
    local metrics=self.window.metrics;local m=metrics[name]
    if not m then
      local h={};for i=1,#buckets+1 do h[i]=0 end
      m={count=0,total_seconds=0,max_seconds=0,histogram=h};metrics[name]=m
    end
    m.count=m.count+1;m.total_seconds=m.total_seconds+seconds;m.max_seconds=math.max(m.max_seconds,seconds)
    local i=1;while buckets[i] and seconds>buckets[i] do i=i+1 end
    m.histogram[i]=m.histogram[i]+1
  end
  function P:finish(label,start)
    if not finite(start) then return nil end
    local t=self:now()
    if t and t>=start then self:record(label,t-start);return t end
  end
  function P:begin_frame(dt)
    local t=self:now();if not t then return end
    local gap=self.last_frame and t-self.last_frame
    self.last_frame=t
    self:record('frame_interval',gap);self:record('update_argument_dt',dt)
    return t,gap
  end
  function P:end_frame(start,gap,flags)
    local t=self:finish('update_total',start);if not t then return end
    if t-start>=.1 or finite(gap) and gap>=.1 then
      local w=self.window
      local item={at_seconds=t,update_seconds=t-start,frame_interval_seconds=gap,flags=scalar_flags(flags)}
      if #w.slow_frames<8 then w.slow_frames[#w.slow_frames+1]=item
      else
        -- Keep the eight largest combined stalls, with explicit truncation.
        w.slow_frames_dropped=w.slow_frames_dropped+1
        local least=1
        local function size(x)return math.max(x.update_seconds or 0,x.frame_interval_seconds or 0)end
        for i=2,8 do if size(w.slow_frames[i])<size(w.slow_frames[least]) then least=i end end
        if size(item)>size(w.slow_frames[least]) then w.slow_frames[least]=item end
      end
    end
  end
  function P:begin_decision(s)
    local t=self:now();if not t then return end
    self.decision_serial=self.decision_serial+1
    local phase=type(s)=='table' and s.phase
    if type(phase)~='string' or #phase>32 then phase='unknown' end
    return {decision_id=self.decision_serial,generation=self.generation,phase=phase,
      started_seconds=t,active_seconds=0,resume_calls=0,max_resume_seconds=0}
  end
  function P:resume_finished(token,start)
    local t=self:finish('decision.resume',start)
    if not token or token.done or token.generation~=self.generation then return end
    if not t then token.incomplete=true;return end
    local elapsed=t-start
    token.resume_calls=token.resume_calls+1;token.active_seconds=token.active_seconds+elapsed
    token.max_resume_seconds=math.max(token.max_resume_seconds,elapsed)
  end
  function P:finish_decision(token,status,result)
    if not token or token.done then return end
    token.done=true
    local t=self:now()
    if not t or token.incomplete or token.generation~=self.generation then return end
    if status~='completed' and status~='cancelled' and status~='error' then return end
    local receipt={decision_id=token.decision_id,phase=token.phase,status=status,
      started_seconds=token.started_seconds,finished_seconds=t,elapsed_seconds=t-token.started_seconds,
      active_seconds=token.active_seconds,resume_calls=token.resume_calls,max_resume_seconds=token.max_resume_seconds}
    if status=='completed' and type(result)=='table' then
      if finite(result.evaluations) then receipt.evaluations=result.evaluations end
      local kind=type(result.action)=='table' and result.action.kind
      if type(kind)=='string' and #kind<=32 then receipt.action_kind=kind end
    end
    local w=self.window
    if #w.decisions<32 then w.decisions[#w.decisions+1]=receipt else w.decisions_dropped=w.decisions_dropped+1 end
    return receipt
  end
  function P:flush(journal,flags)
    if self.flushing then return end
    local t=self:now();if not t or not journal or type(journal.timing)~='function' then return end
    local due=self.last_emit or self.window.start_seconds
    if t-due<5 then return end
    self.last_emit=t
    if not self.pending then
      self.pending=self.window;self.pending.end_seconds=t;self.pending.flags=scalar_flags(flags)
      self.pending.clock_failures=self.clock_failures;self.clock_failures=0
      self.window=self:new_window(t)
    end
    -- Rotate BEFORE append. Timing the summary itself belongs to the next
    -- window; only acknowledge the exact window represented by this write.
    self.flushing=true
    local ok,accepted=pcall(journal.timing,journal,'performance_window',self.pending)
    self.flushing=false
    if ok and accepted then self.pending=nil end
    self:finish('performance_emit',t)
  end
  return P
end
return M
