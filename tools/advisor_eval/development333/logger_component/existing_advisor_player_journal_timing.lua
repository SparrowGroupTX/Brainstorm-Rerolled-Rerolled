-- Manufactured timestamps, collector and append sink only; no player files,
-- source executable, gameplay or wall-clock benchmark.
local M=dofile('tools/advisor_eval/development333/logger_component/player_journal.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function contains(text,value,label)check(text:find(value,1,true),label)end
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end

do
  local time=1234.5
  local lines,metrics={},{}
  local observed,clock_calls=0,0
  local p={now=function()return time end,record=function(_,name,seconds)
    metrics[name]=metrics[name] or {count=0,seconds=0}
    metrics[name].count=metrics[name].count+1;metrics[name].seconds=metrics[name].seconds+seconds
  end}
  local log=M.new({enabled=function()return true end,performance=p,
    clock=function()clock_calls=clock_calls+1;return time end,now=function()return '2026-09-15T08:30:00Z'end,
    observe=function()observed=observed+1;time=time+0.125;return {snapshot={dollars=25},advice={status='current'}}end,
    append=function(bytes)time=time+0.5;lines[#lines+1]=bytes;return true end})
  local original=M.encode
  M.encode=function(...)time=time+0.25;return original(...)end
  local first=log:before('play',{indices={1,2}})
  eq(first,1,'existing first action sequence retained')
  contains(lines[1],'"at":"2026-09-15T08:30:00Z"','UTC timestamp retained')
  contains(lines[1],'"monotonic_seconds":1234.5','timestamp anchored before observation/encoding/append')
  contains(lines[1],'"monotonic_status":"available"','clock availability explicit')
  eq(clock_calls,1,'one monotonic anchor per new event')
  eq(metrics['journal.observe'].seconds,0.125,'observation elapsed time')
  eq(metrics['journal.encode'].seconds,0.25,'encode elapsed time')
  eq(metrics['journal.append'].seconds,0.5,'append elapsed time')
  eq(metrics['journal.total'].seconds,0.875,'total journal elapsed time')
  local summary=copy(metrics)
  check(log:timing('performance_summary',{metrics=summary}),'compact timing event appends')
  eq(observed,1,'timing event does not capture a snapshot')
  contains(lines[2],'"context":{}','timing event has explicit empty context')
  contains(lines[2],'"sequence":2','timing event uses ordinary continuous sequence')
  contains(lines[2],'"journal.append":{"count":1,"seconds":0.5}','written summary covers only preceding append')
  eq(metrics['journal.append'].count,2,'timing append enters the following summary')
  eq(metrics['journal.total'].seconds,1.625,'timing event overhead measured without recursion')
  eq(#lines,2,'measurement itself creates no additional event')
  eq(summary['journal.append'].count,1,'supplied summary remains unchanged')
  log:after(first,true)
  eq(observed,1,'callback outcome still avoids snapshot observation')
  contains(lines[3],'"action_sequence":1','callback retains action link')
  eq(log.pending_state,1,'accepted callback still schedules settled observation')
  eq(log.sequence,3,'all new events share one unchanged sequence')
  M.encode=original
end

do
  local clock,capture,append,perf=0,0,0,0
  local log=M.new({enabled=function()return false end,
    clock=function()clock=clock+1;return 1 end,now=function()error('No disabled event')end,
    observe=function()capture=capture+1;return{}end,append=function()append=append+1;return true end,
    performance={now=function()perf=perf+1;return 1 end,record=function()error('No disabled metric')end}})
  check(not log:event('off'),'ordinary disabled event remains off')
  check(not log:timing('performance_summary',{}),'compact disabled event remains off')
  check(not log:before('play',{}),'disabled callback remains off')
  eq(clock+capture+append+perf,0,'disabled logging does no timing/capture/write work')
  eq(log.sequence,0,'disabled events do not consume sequence')
end

do
  local original_love=love
  local fixtures={
    {'missing',nil,'clock_unavailable'},
    {'wrong type','clock','clock_unavailable'},
    {'throws',function()error('private clock error')end,'clock_failed'},
    {'nil',function()return nil end,'invalid_clock_value'},
    {'string',function()return '12'end,'invalid_clock_value'},
    {'negative',function()return -1 end,'invalid_clock_value'},
    {'nan',function()return 0/0 end,'invalid_clock_value'},
    {'infinity',function()return math.huge end,'invalid_clock_value'},
  }
  love=nil
  for _,case in ipairs(fixtures)do
    local line
    local log=M.new({enabled=function()return true end,clock=case[2],now=function()return 'UTC'end,
      observe=function()return{}end,append=function(bytes)line=bytes;return true end})
    check(log:event('clock_case'),case[1]..' clock cannot stop logging')
    check(not log.error,case[1]..' clock does not set recorder failure')
    contains(line,'"monotonic_status":"unavailable"',case[1]..' availability explicit')
    contains(line,'"monotonic_reason":"'..case[3]..'"',case[1]..' bounded reason')
    check(not line:find('"monotonic_seconds":',1,true),case[1]..' invalid numeric stamp omitted')
  end
  local time,lines=10,{}
  local log=M.new({enabled=function()return true end,clock=function()return time end,now=function()return 'UTC'end,
    observe=function()return{}end,append=function(bytes)lines[#lines+1]=bytes;return true end})
  check(log:event('first'),'first clock sample')
  time=9;check(log:event('regressed'),'clock regression remains nonfatal')
  contains(lines[2],'"monotonic_reason":"clock_regressed"','backward clock cannot pretend to be monotonic')
  time=10;check(log:event('equal'),'equal clock timestamps allowed')
  contains(lines[3],'"monotonic_seconds":10','last successful monotonic anchor preserved')
  time=10.125;check(log:event('recovered'),'clock recovers')
  contains(lines[4],'"monotonic_seconds":10.125','subsecond precision retained')
  love={timer={getTime=function()return 42.125 end}}
  local fallback
  log=M.new({enabled=function()return true end,now=function()return 'UTC'end,
    observe=function()return{}end,append=function(bytes)fallback=bytes;return true end})
  check(log:event('fallback'),'LOVE clock used when no clock injected')
  contains(fallback,'"monotonic_seconds":42.125','default LOVE clock anchor')
  love=original_love
end

do
  for _,kind in ipairs({'throw_now','nan_now','negative_duration','throw_record'})do
    local now_calls,records,line=0,0,nil
    local p={now=function()
      now_calls=now_calls+1
      if kind=='throw_now'then error('clock failed')end
      if kind=='nan_now'then return 0/0 end
      if kind=='negative_duration'then return 100-now_calls end
      return now_calls
    end,record=function()records=records+1;if kind=='throw_record'then error('metric failed')end end}
    local log=M.new({enabled=function()return true end,performance=p,clock=function()return 9 end,
      now=function()return 'UTC'end,observe=function()return{}end,append=function(bytes)line=bytes;return true end})
    check(log:event(kind),kind..' performance instrumentation is nonfatal')
    check(not log.error and line,kind..' event survives measurement failure')
    if kind~='throw_record'then eq(records,0,kind..' invalid elapsed duration never recorded')end
  end
end

do
  local time,metrics,notices,attempts=100,{},0,0
  local p={now=function()return time end,record=function(_,name,value)metrics[name]=(metrics[name]or 0)+value end}
  local log=M.new({enabled=function()return true end,clock=function()return time end,performance=p,
    now=function()return 'UTC'end,observe=function()time=time+0.25;return{}end,
    append=function()attempts=attempts+1;time=time+0.5;return false,'disk full'end,
    notice=function()notices=notices+1 end})
  local ok,why=log:timing('performance_summary',{unchanged=true})
  check(not ok and why=='disk full','failed compact append propagates existing failure')
  eq(metrics['journal.append'],0.5,'failed append time is still diagnostic work')
  eq(metrics['journal.total'],0.5,'failed compact event total measured')
  eq(log.events,0,'failed event never counted as committed')
  eq(log.bytes,0,'failed event never claims stored bytes')
  eq(log.sequence,1,'failed append retains existing sequence semantics')
  check(not log:event('again'),'failed recorder does not retry itself')
  eq(attempts,1,'no second append after error')
  eq(notices,1,'failure notice remains once')
  eq(metrics['journal.append'],0.5,'no metric consumption/renewal after error')
end

do
  local time,records,observations,played=1,{},0,0
  local g={GAME={pseudorandom={seed='MANUFACTURED'}},SETTINGS={profile=1},STATE_COMPLETE=true,
    STATES={},CONTROLLER={locks={}},FUNCS={play_cards_from_highlighted=function()played=played+1;return true end}}
  local A={snapshot={capture=function()observations=observations+1;return {phase='hand',hand={}}end,
    fingerprint=function()return 'same'end},published_key='same',published_game=g.GAME,result={action={kind='play'}},lines={}}
  local B={VERSION='test',config={advisor={player_logging=true}}}
  local log=M.attach(A,B,{clock=function()return time end,game=function()return g end,
    append=function(bytes)time=time+0.125;records[#records+1]=bytes;return true end,now=function()return 'UTC'end})
  local metrics={}
  A.performance={now=function()return time end,record=function(_,name,value)metrics[name]=(metrics[name]or 0)+value end}
  log:install_hooks(g)
  check(g.FUNCS.play_cards_from_highlighted(),'clock integration preserves real-shaped callback result')
  eq(played,1,'callback exactly once')
  eq(observations,1,'action entry captures complete public state')
  eq(metrics['journal.append'],0.25,'collector attached after journal creation is resolved dynamically')
  log:update(g)
  eq(observations,2,'settled state remains recorded exactly once')
  for i=1,120 do log:update(g)end
  eq(observations,2,'idle frames produce no extra public observation')
  eq(#records,3,'action/request/settled linkage remains bounded')
  contains(records[3],'"latest_action_sequence":1','settled observation links action request')
end

print('player_journal_timing: '..checks..' manufactured checks passed; elapsed wall time only')
