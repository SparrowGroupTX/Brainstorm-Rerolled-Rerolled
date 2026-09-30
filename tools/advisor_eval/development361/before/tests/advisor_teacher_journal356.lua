-- Manufactured clocks, public observations and in-memory files only.
local M=dofile('Brainstorm/Advisor/player_journal.lua')
local Archive=dofile('Brainstorm/Advisor/player_log_archive.lua')
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(value)if type(value)~='table'then return value end;local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out end
local function test_journal()
  local time,enabled,observed,settled=0,true,0,true
  local context={version='fixture',run_instance='r1',seed='FIXTURE',stake=8,
    teacher='perkeo_yorick_win_v1',snapshot={phase='hand',dollars=5,hand={{id='1',rank=13}},
      route_blinds={Boss={key='bl_psychic',chips=600,boss=true}}},
    advice={status='current',action={kind='discard',indices={1,2,3,4,5}},timing={elapsed_seconds=1}}}
  local records={};local archive={physical_bytes=0}
  function archive:append(event,raw)records[#records+1]=copy(event);self.physical_bytes=self.physical_bytes+#raw;return true end
  function archive:prepare_collection(options)
    check(options.clear_existing==true,'explicit cleanup flag forwarded')
    self.physical_bytes=0;return true,{deleted_files={'manufactured'},deleted_bytes=10}
  end
  function archive:rotate(reason)self.last_rotation=reason;return true end
  local journal=M.new({enabled=function()return enabled end,archive=archive,now=function()return 'fixed'end,
    clock=function()return time end,settled=function()return settled end,
    observe=function()observed=observed+1;return copy(context)end})
  return journal,records,context,function(t)time=t end,function()return observed end,function(v)settled=v end
end

do
  local j,events,context,time,observed,settled=test_journal()
  j.error='old total byte cap';check(j:prepare_collection({clear_existing=true,collection_id='demo356'}),'fresh explicit preparation recovers stopped archive')
  check(not j.error and j.sequence==0 and j.collection_mode,'journal counters/error reset')
  check(j:collection_observe(),'initial observation')
  eq(#events,2,'one full state and one advice record')
  eq(events[1].kind,'teacher_observation','full public state kind')
  eq(events[1].observation_id,'demo356:1','stable full observation identity')
  eq(events[1].context.snapshot_schema,'brainstorm_public_snapshot_v1','explicit public schema')
  eq(events[2].kind,'teacher_advice','separate suggestion')
  eq(events[2].observation_sequence,1,'suggestion references public state')
  eq(events[2].context.snapshot,nil,'suggestion avoids snapshot duplication')
  eq(events[1].context.snapshot.route_blinds.Boss.key,'bl_psychic','public future boss retained')
  for i=1,24 do time(i/100);j:collection_observe()end
  eq(observed(),1,'sub-half-second polling does not capture again')
  time(.5);j:collection_observe();eq(observed(),2,'bounded half-second recapture')
  eq(#events,2,'unchanged observation and advice produce no writes')
  context.advice.timing.elapsed_seconds=2;time(1);j:collection_observe()
  eq(#events,2,'timing alone cannot duplicate suggestion')
  check(j:timing('performance_window',{huge='unused'}),'suppressed summary acknowledged to release collector')
  eq(#events,2,'unchanged performance windows do not append')
  local before=j:before('advisor_execute',{action={kind='discard',indices={1,2,3,4,5}}})
  eq(before,3,'action is a separate committed event')
  eq(events[3].advice_sequence,2,'action links exact suggestion')
  eq(events[3].observation_sequence,1,'action links pre-action state')
  context.snapshot.dollars=4;context.advice={status='computing'}
  time(2);j:collection_observe()
  j:after(before,true,nil,'returned')
  eq(events[#events].observation_sequence,1,'callback preserves original observation after state advances')
  eq(events[#events].advice_sequence,2,'callback preserves original suggestion after advice advances')
  eq(events[#events].details.action_sequence,before,'callback identifies exact request')
  eq(j.pending_actions[1],before,'successful callback retained for next settled observation')
  local count=#events
  time(31.9);j:collection_observe();eq(#events,count,'no warning before 30 seconds from last change')
  time(32);j:collection_observe();eq(events[#events].kind,'teacher_inactivity_warning','first inactivity warning')
  eq(events[#events].details.warning_deadline_seconds,30,'first warning deadline')
  eq(events[#events].details.next_deadline_seconds,90,'next warning interval is one minute')
  time(600);j:collection_observe();eq(#events,count+2,'missed warnings compact to one catch-up record')
  eq(events[#events].details.missed_deadlines,4,'catch-up records four additional missed deadlines')
  eq(events[#events].details.next_deadline_seconds,630,'warning cadence preserved after catch-up')
  settled(false);time(632);local captures=observed();j:collection_observe()
  eq(observed(),captures,'unsettled transitions do not take public snapshots')
  eq(events[#events].kind,'teacher_inactivity_warning','blocked transitions can still emit bounded warnings')
  settled(true);context.snapshot.dollars=3;time(633);j:collection_observe()
  eq(j.idle_warning_index,1,'state change resets idle schedule')
  local request=j:before('sell_card',{key='j_yorick'});j:after(request,false,'fixture exception','exception')
  eq(events[#events].kind,'action_callback_exception','exceptions are distinguishable from successful callbacks')
  eq(events[#events].details.callback_returned,false,'exception never creates success label')
  context.advice=nil;context.snapshot.dollars=2;time(633.5);j:collection_observe()
  local no_advice=j:before('manual_action',{})
  context.advice={status='current',action={kind='play',indices={1}}};time(634);j:collection_observe()
  j:after(no_advice,true)
  eq(events[#events].advice_sequence,nil,'callback cannot inherit advice published after a request that had no advice')
  context.snapshot.dollars=0/0
  local okay,reason=j:collection_observe();check(okay,'throttle avoids redundant capture even after an invalid state mutation')
  time(635);okay,reason=j:collection_observe();check(not okay and j.error,'malformed observations stop logging without throwing into game loop')
  j:end_collection('fixture');check(not j.collection_mode,'explicit collection end restores old logging mode')
end

do
  local expected={30,90,150,210,270,330,630,930,1230,1530,2130,2730,3330,3600,
    4800,6000,7200,8400,10800,13200,15600,18000,22800}
  for i,value in ipairs(expected)do eq(M.idle_warning_deadline(i),value,'deadline '..i)end
  check(not M.idle_warning_deadline(0),'invalid warning index rejected')
  local key,safe,raw=M.semantic_fingerprint({dollars=4,performance={at=2},hand={}})
  check(type(key)=='string'and #key<=8192 and type(raw)=='string','watchdog semantic key respects bounded transport')
  eq(safe.performance,nil,'performance excluded from semantic state')
  eq(key,M.semantic_fingerprint({hand={},performance={at=999},dollars=4}),'canonical order and timing do not change semantic key')
  check(key~=M.semantic_fingerprint({hand={},dollars=5}),'resource change changes semantic key')
  check(not M.semantic_fingerprint({bad=0/0}),'malformed semantic input returns an explicit failure')
end

local function memory_files()
  local files,dirs,removed={},{},{}
  local fs={}
  function fs.getInfo(path)
    if dirs[path]then return {type='directory'}end
    if files[path]then return {type='file',size=#files[path]}end
  end
  function fs.createDirectory(path)dirs[path]=true;return true end
  function fs.getDirectoryItems(path)
    local out={};for name in pairs(files)do if name:sub(1,#path+1)==path..'/'then out[#out+1]=name:sub(#path+2)end end
    table.sort(out);return out
  end
  function fs.append(path,raw)files[path]=(files[path]or'')..raw;return true end
  function fs.remove(path)removed[#removed+1]=path;files[path]=nil;return true end
  local function hash(raw)
    local n=0;for i=1,#raw do n=(n*31+raw:byte(i))%2147483647 end
    return string.format('%064x',n)
  end
  local options={fs=fs,encode=M.encode,encode_frame=M.encode_frame,hash=hash,session_name=function()return 'fixture'end,
    read_range=function(path,offset,length)return files[path]:sub(offset+1,offset+length)end}
  return fs,files,dirs,removed,options
end

do
  local fs,files,dirs,removed,options=memory_files()
  dirs.advisor_player_log_v1=true;dirs.advisor_player_log_v2=true
  files['advisor_player_log_v1/session-old.jsonl']='old'
  files['advisor_player_log_v2/session-old-000001.brj']='archive'
  files['advisor_player_log_v2/notes.txt']='keep'
  files['profile/save.jkr']='save';files['config.lua']='config'
  local archive=Archive.new(options)
  local event={sequence=1,context={},kind='fixture'}
  check(archive:append(event,assert(M.encode(event))),'manufactured active segment written')
  local active=archive.path
  local ok,receipt=archive:prepare_collection({clear_existing=true})
  check(ok and receipt.writer_closed_before_removal,'writer closed before owned log deletion')
  eq(#receipt.deleted_files,3,'old v1/v2 and active segment removed')
  check(not files[active],'active path no longer reused')
  eq(files['advisor_player_log_v2/notes.txt'],'keep','unrelated file inside observation directory preserved')
  eq(files['profile/save.jkr'],'save','save path never touched')
  eq(files['config.lua'],'config','configuration never touched')
  eq(receipt.remaining_bytes,4,'retained owned-directory bytes still count against cap')
  eq(archive.events,0,'event accounting restarted only after explicit verified cleanup')
  check(archive:append(event,assert(M.encode(event))),'new sequence starts after cleanup')
  eq(archive.events,1,'new segment accounting consistent')
end

do
  local fs,files,dirs,removed,options=memory_files()
  dirs.advisor_player_log_v2=true
  files['advisor_player_log_v2/session-a.brj']='a';files['advisor_player_log_v2/session-b.brj']='bb'
  local original=fs.remove
  function fs.remove(path)if path:find('session-b',1,true)then return nil,'manufactured removal failure'end;return original(path)end
  local archive=Archive.new(options)
  local ok,why,receipt=archive:prepare_collection({clear_existing=true})
  check(not ok and why:find('manufactured removal failure',1,true),'partial deletion failure is explicit')
  eq(#receipt.deleted_files,1,'partial receipt preserves completed deletion evidence')
  eq(files['advisor_player_log_v2/session-b.brj'],'bb','failed target remains')
  check(archive.closed and archive.error,'failed cleanup keeps writer stopped')
  check(not archive:append({sequence=1,context={}},'{}'),'failure never silently reopens old writer')
  fs.remove=original;check(archive:prepare_collection({clear_existing=true}),'explicit subsequent cleanup can recover')
  check(not archive.error and not archive.closed,'verified recovery clears writer failure')
end

do
  local fs,files,dirs,removed,options=memory_files()
  dirs.advisor_player_log_v2=true;files['advisor_player_log_v2/session-a.brj']='a'
  function fs.getDirectoryItems()return {'session-a.brj','../profile/save.jkr'}end
  local archive=Archive.new(options)
  check(not archive:prepare_collection({clear_existing=true}),'traversal name fails before deletion')
  eq(#removed,0,'entire target set validated before first mutation')
  eq(files['advisor_player_log_v2/session-a.brj'],'a','safe sibling preserved when catalog unsafe')
end

do
  local fs,files,dirs,removed,options=memory_files()
  dirs.advisor_player_log_v2=true;files['advisor_player_log_v2/session-old.brj']='old'
  local g={GAME={},SETTINGS={profile=1},STATE_COMPLETE=true,CONTROLLER={locks={}},STATES={},FUNCS={}}
  local A={player_log_archive=Archive,snapshot={capture=function()return {phase='hand',hand={}}end,fingerprint=function()return 'x'end}}
  local B={VERSION='fixture',config={advisor={player_logging=false,player_log_compression=false}}}
  local time=1
  local j=M.attach(A,B,{game=function()return g end,fs=fs,hash=options.hash,read_range=options.read_range,
    session_name=options.session_name,clock=function()return time end,now=function()return 'fixture'end})
  check(j:prepare_collection({clear_existing=true,collection_id='attached'}),'lazy live-shaped archive initializes for clear before first append')
  check(not files['advisor_player_log_v2/session-old.brj'],'explicit preparation clears only manufactured old log')
  B.config.advisor.player_logging=true;j:update(g)
  eq(j.events,2,'settled updater writes initial state and unavailable advice')
  local first=j:before('play_cards_from_highlighted',{selected={1}});j:after(first,true)
  local second=j:before('discard_cards_from_highlighted',{selected={2}});j:after(second,true)
  time=2;j:update(g)
  eq(#j.pending_actions,0,'settled observation consumes complete accepted callback sequence list')
  eq(j.pending_state,nil,'settled callback observation consumes pending state')
  local count=j.events;for i=1,100 do j:update(g)end
  eq(j.events,count,'unchanged frames produce no additional log writes')
  j:end_collection('complete')
  local before_paths={};for path in pairs(files)do before_paths[path]=true end
  check(j:event('normal_after_collection',{},{}),'normal logging can resume after explicit collection end')
  local new_paths=0;for path in pairs(files)do if not before_paths[path]then new_paths=new_paths+1 end end
  eq(new_paths,1,'normal events after collection end use a separate archive segment')
end

print('advisor_teacher_journal356: '..checks..' manufactured checks passed; no real logs or saves accessed')
