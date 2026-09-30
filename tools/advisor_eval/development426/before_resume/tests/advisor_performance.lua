-- Manufactured collector only: no game state, source callbacks or real clock.
local M=dofile('Brainstorm/Advisor/performance.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function equal(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function near(a,b,label)check(type(a)=='number'and math.abs(a-b)<1e-8,label)end
local function size(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function setup(enabled)
  local c={value=0,enabled=enabled~=false,reads=0}
  local p=M.new({enabled=function()if c.enabled_error then error('enabled broke')end;return c.enabled end,
    clock=function()c.reads=c.reads+1;if c.clock_error then error('clock broke')end;return c.value end})
  return p,c
end
do
  local p,c=setup(false)
  equal(p:now(),nil,'off returns no clock');equal(c.reads,0,'off performs no wall clock callback')
  equal(p:begin_frame(.1),nil,'off frame returns no time');equal(p:begin_decision({phase='hand'}),nil,'off decision absent')
  p:record('game_update',1);equal(p.window,nil,'off stores no metrics')
  p:flush({timing=function()error('off emitted')end});equal(c.reads,0,'off flush performs no clock callback')
  c.enabled_error=true;equal(p:now(),nil,'enabled callback failure is harmless');equal(c.reads,0,'failed consent reads no clock')
  c.enabled_error=nil;c.enabled=true;c.value=1;equal(p:now(),1,'enable initializes window')
  p:record('game_update',.4);local generation=p.generation
  c.enabled=false;p:now();equal(p.generation,generation+1,'disable invalidates outstanding generation')
  equal(p.window,nil,'disable discards current metrics');equal(p.pending,nil,'disable discards pending window')
  equal(p.last_frame,nil,'disable removes frame continuity')
end
do
  local p,c=setup()
  for _,invalid in ipairs({-1,math.huge,-math.huge,'clock'})do
    c.value=invalid;local n=p.clock_failures;equal(p:now(),nil,'invalid clock rejected '..tostring(invalid))
    equal(p.clock_failures,n+1,'invalid clock counted')
  end
  c.value=0/0;equal(p:now(),nil,'NaN clock rejected')
  c.clock_error=true;equal(p:now(),nil,'throwing clock rejected');c.clock_error=nil
  c.value=3;equal(p:begin_frame(.016),3,'valid clock recovers')
  c.value=2;equal(p:now(),nil,'backwards clock rejected');equal(p.last_frame,nil,'clock failure breaks frame gap continuity')
  c.value=4;local t,gap=p:begin_frame(.016);equal(t,4,'clock catches up safely');equal(gap,nil,'gap after failed clock is unknown')
  c.value=5;near(p:finish('game_update',4),5,'finish returns end time for next phase')
  c.value=5;equal(p:finish('game_update',6),nil,'future start rejected');equal(p.window.metrics.game_update.count,1,'invalid interval not recorded')
end
do
  local p,c=setup();p:now()
  local values={0,.001,.004,.008,.016,.033,.05,.1,.25,1,5,6}
  for _,v in ipairs(values)do p:record('game_update',v)end
  local m=p.window.metrics.game_update
  equal(m.count,#values,'all valid samples counted');equal(#m.histogram,11,'histogram size is fixed')
  equal(m.histogram[1],2,'zero and first boundary share first bucket')
  for i=2,11 do equal(m.histogram[i],1,'boundary histogram bucket '..i)end
  equal(m.max_seconds,6,'max keeps overflow sample');near(m.total_seconds,12.462,'sum keeps seconds')
  p:record('invented',1);p:record('game_update',-1);p:record('game_update',math.huge);p:record('game_update',0/0)
  equal(size(p.window.metrics),1,'unknown label cannot grow metric map');equal(m.count,#values,'invalid durations are absent')
  for i=1,1000 do p:record('game_update',.002)end
  equal(#m.histogram,11,'many samples keep bounded histogram');equal(size(p.window.metrics),1,'many samples keep bounded map')
end
do
  local p,c=setup();local token=p:begin_decision({phase='shop',hand={secret=true}})
  c.value=.02;p:resume_finished(token,0)
  c.value=1;p:now();c.value=1.03;p:resume_finished(token,1)
  c.value=2;local r=p:finish_decision(token,'completed',{evaluations=47,action={kind='buy'},secret='omit'})
  equal(r.phase,'shop','phase only metadata');near(r.active_seconds,.05,'active sums resumes only')
  near(r.elapsed_seconds,2,'elapsed includes waiting between resumes');near(r.max_resume_seconds,.03,'maximum resume independent of waiting')
  equal(r.resume_calls,2,'resume count');equal(r.evaluations,47,'completed result score count');equal(r.action_kind,'buy','bounded action kind')
  equal(r.secret,nil,'result internals not copied');equal(token.hand,nil,'input snapshot not retained')
  equal(#p.window.decisions,1,'one receipt recorded');equal(p:finish_decision(token,'completed',{}),nil,'duplicate completion rejected')
  equal(#p.window.decisions,1,'duplicate completion adds no receipt')
  for _,status in ipairs({'cancelled','error'})do
    local a=p:begin_decision({phase='hand'});c.value=c.value+.01
    local receipt=p:finish_decision(a,status,{evaluations=1000,action={kind='play'}})
    equal(receipt.status,status,'terminal diagnostic status '..status)
    equal(receipt.evaluations,nil,'non-completed evaluations omitted '..status)
    equal(receipt.action_kind,nil,'non-completed action omitted '..status)
  end
  local a=p:begin_decision({phase=string.rep('x',33)});equal(a.phase,'unknown','oversized phase bounded')
  p:resume_finished(a,nil);equal(p:finish_decision(a,'completed',{evaluations=1}),nil,'incomplete resume suppresses exact receipt')
  a=p:begin_decision({phase='hand'});c.enabled=false;p:now();c.enabled=true;p:now()
  equal(p:finish_decision(a,'completed',{evaluations=1}),nil,'token cannot cross consent generation')
  a=p:begin_decision({phase='hand'});equal(p:finish_decision(a,'unsupported',{}),nil,'unknown status not relabeled')
end
do
  local p,c=setup()
  for i=1,40 do
    local token=p:begin_decision({phase='hand'});c.value=c.value+.01
    check(p:finish_decision(token,'completed',{})~=nil,'finished caller receipt '..i)
  end
  equal(#p.window.decisions,32,'decision retention capped');equal(p.window.decisions_dropped,8,'decision truncation explicit')
  for i=1,20 do
    local start,gap=p:begin_frame(.016);c.value=c.value+i/10
    p:end_frame(start,gap,{state=1,stage=2,ante=3,round=4,paused=false,dragging=true,advisor_worker=true,
      auto_active=false,game_speed=16,seed='private',snapshot={},nan=0/0})
  end
  equal(#p.window.slow_frames,8,'slow frame retention capped');equal(p.window.slow_frames_dropped,12,'slow truncation explicit')
  local minimum=math.huge
  for _,row in ipairs(p.window.slow_frames)do
    minimum=math.min(minimum,math.max(row.update_seconds,row.frame_interval_seconds or 0))
    equal(size(row.flags),9,'only whitelisted scalar flags retained');equal(row.flags.seed,nil,'no seed in flags')
    equal(row.flags.snapshot,nil,'no snapshot in flags')
  end
  check(minimum>=1.29,'largest slow intervals retained after truncation')
end
do
  local p,c=setup();p:now();p:record('game_update',.2)
  local writes={};local log={}
  function log:timing(kind,payload)
    writes[#writes+1]=payload;equal(kind,'performance_window','single compact event kind')
    check(p.window~=payload,'rotation precedes sink callback')
    p:record('journal.append',.07)
    p:flush(self,{state=2}) -- Must not recursively enter the sink.
    c.value=c.value+.08;return true
  end
  c.value=4.999;p:flush(log);equal(#writes,0,'no write before five seconds')
  c.value=5;p:flush(log,{state=2,seed='omit'})
  equal(#writes,1,'first due flush writes once');equal(p.pending,nil,'accepted exact pending receipt acknowledged')
  equal(writes[1].metrics['journal.append'],nil,'sink metrics not added to emitted window')
  near(p.window.metrics['journal.append'].total_seconds,.07,'sink metrics belong to following window')
  near(p.window.metrics.performance_emit.total_seconds,.08,'emission duration recorded separately')
  equal(writes[1].flags.seed,nil,'window flags omit unapproved fields')
  local original=writes[1];p:flush(log);equal(#writes,1,'same moment cannot emit twice')
  c.value=9.999;p:flush(log);equal(#writes,1,'subsequent interval shorter than five seconds suppressed')
  c.value=10;p:flush(log);equal(#writes,2,'next window can emit after five seconds')
  check(writes[2]~=original,'subsequent event owns a different window')
  near(original.metrics.game_update.total_seconds,.2,'acknowledged prior window remains unchanged')
end
do
  local p,c=setup();p:now();p:record('game_update',.1)
  local attempts={};local accept=false;local fail=false;local log={}
  function log:timing(kind,payload)
    attempts[#attempts+1]=payload
    p:record('journal.append',.03)
    if fail then error('manufactured sink error')end
    return accept
  end
  c.value=5;p:flush(log);local pending=p.pending
  check(pending~=nil,'rejected write keeps pending window');equal(pending,attempts[1],'pending identity matches rejected payload')
  p:record('advisor_update',.5)
  c.value=10;fail=true;p:flush(log)
  equal(p.pending,pending,'throwing write retains same pending window');equal(attempts[2],pending,'retry writes exact same pending receipt')
  equal(pending.metrics.advisor_update,nil,'new metrics never mutate pending payload')
  for i=1,40 do local token=p:begin_decision({phase='shop'});p:finish_decision(token,'completed',{})end
  equal(#p.window.decisions,32,'failed sink current decisions remain bounded');equal(p.window.decisions_dropped,8,'failed sink preserves dropped count')
  equal(#pending.decisions,0,'pending owns only pre-rotation decisions')
  c.value=15;fail=false;accept=true;p:flush(log)
  equal(p.pending,nil,'only accepted retry clears pending');equal(attempts[3],pending,'accepted retry still exact original window')
  near(p.window.metrics.advisor_update.total_seconds,.5,'current totals survive pending acknowledgement')
  c.value=20;p:flush(log);equal(#attempts,4,'accumulated current window emits at next due time')
  check(attempts[4]~=pending,'new accumulated window is not old receipt')
  equal(attempts[4].decisions_dropped,8,'explicit truncation survives emission')
end
do
  local p,c=setup();p:now();p:record('game_update',1);c.value=5
  p:flush({});equal(p.pending,nil,'unavailable sink does not rotate away current data')
  equal(p.window.metrics.game_update.count,1,'unavailable sink retains bounded metrics')
  local writes=0;p:flush({timing=function()writes=writes+1;return true end})
  equal(writes,1,'available sink can emit immediately after prior missing sink')
  equal(p:finish('game_update',nil),nil,'nil start never records a duration')
end
do
  -- Aggregate resume wall is observed work even if recording began mid-worker.
  -- It need not own a complete decision receipt and is inclusive, not additive.
  local p,c=setup();p:now();c.value=.02;p:resume_finished(nil,0)
  near(p.window.metrics['decision.resume'].total_seconds,.02,'unowned actual resume contributes to aggregate')
  equal(#p.window.decisions,0,'unowned resume invents no completed decision')
  local token=p:begin_decision({phase='hand'});c.value=.03
  local receipt=p:finish_decision(token,'completed',{})
  c.value=.04;p:resume_finished(token,.03)
  equal(token.resume_calls,0,'done token receives no duplicate owned resume')
  equal(receipt.resume_calls,0,'completed receipt remains unchanged')
  equal(#p.window.decisions,1,'stray resume adds no second receipt')
  near(p.window.metrics['decision.resume'].total_seconds,.03,'actual aggregate work remains separate from owned receipt')
end
do
  local p,c=setup();p:now();local writes=0
  local sink={timing=function()writes=writes+1;return true end}
  for i=1,1000 do
    c.value=i;p:begin_frame(.016);p:record('game_update',.01)
    p:flush(sink,{idle_menu=true})
  end
  equal(writes,0,'idle title screen emits no periodic log writes')
  equal(p.pending,nil,'idle wait does not rotate a pending record')
  equal(p.window.metrics.game_update.count,1000,'idle measurements remain in the fixed memory window')
  equal(#p.window.metrics.game_update.histogram,11,'idle duration does not enlarge histogram storage')
  p:flush(sink,{idle_menu=false});equal(writes,1,'activity resumes bounded timing emission')
  c.value=1001;p:flush(sink,{idle_menu=false});equal(writes,1,'returning activity does not bypass five-second write interval')
  c.enabled=false;p:flush(sink,{idle_menu=true})
  equal(p.window,nil,'explicit opt-out still drops the bounded idle tail')
end
print('advisor_performance: '..checks..' checks passed')
