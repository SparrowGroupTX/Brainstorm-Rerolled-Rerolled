-- Manufactured injected controller only: no game, worker, filesystem log or
-- source-policy replay. Projection changes exported receipts, never freshness.
local Auto=dofile('Brainstorm/Advisor/auto_run.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function shallow(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
local function descriptor(raw)
 return {schema=1,kind='manufactured_fingerprint_descriptor',status='available',byte_length=#raw,sha256=string.rep('a',64)}
end
local function project(record)
 local out={}
 for k,v in pairs(record)do
  if k=='fingerprint' or k=='before' or k=='after'then out[k]=descriptor(v)else out[k]=v end
 end
 return out
end
local function setup(projection)
 local h={time=0,logs={},searches=0,starts=0,executions=0,checks=0,projections={}}
 h.obs={profile_id=1,consent_generation=1,settings_generation=0,checkpoint_generation=0,manual_generation=0,
  ready=true,transition_ready=true,fingerprint='menu',advice_fingerprint='menu',action_token='advice:menu',
  goal={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
   counts={total=150,complete=145,missing=5,unknown=0},by_key={j_yorick={status='missing'}}}}
 local cb={now=function()return h.time end,observe=function()return h.obs end,
  log=function(record)h.logs[#h.logs+1]=record;return record.event~=h.reject end,
  search_start=function(request)h.searches=h.searches+1;h.request=request;return true end,
  search_poll=function(id)return h.poll or {request_id=id,status='running',exited=false}end,
  search_cancel=function()return true end,
  start_run=function()
   h.starts=h.starts+1;h.obs.run_id='run:1';h.obs.ready=false;h.obs.transition_ready=false;return true,nil,'run:1'
  end,
  can_execute=function(key,token)h.checks=h.checks+1;h.checked_key=key;h.checked_token=token;return true end,
  execute=function(key,token)h.executions=h.executions+1;h.executed_key=key;h.executed_token=token;return true end}
 if projection~=nil then
  if type(projection)=='function'then cb.project_log=function(record)
   h.projections[#h.projections+1]={event=record.event,fingerprint=record.fingerprint,before=record.before,after=record.after}
   return projection(record,h)
  end else cb.project_log=projection end
 end
 h.controller=Auto.new(cb)
 function h.arm()
  local accepted,why=h.controller.start();check(accepted,'explicit start succeeds: '..tostring(why))
  h.controller.tick();eq(h.searches,1,'one injected search callback')
  h.poll={request_id=h.request.request_id,status='found',exited=true,found={seed='MANUFACTURED'}}
  h.controller.tick();h.poll=nil;h.controller.tick();eq(h.starts,1,'one injected start callback')
  eq(h.controller.status().state,'starting','controller waits for settled run state')
 end
 function h.ready(key,token)
  h.obs.ready=true;h.obs.fingerprint=key;h.obs.advice_fingerprint=key;h.obs.action_token=token or 'advice:1'
  h.obs.action={kind='choose',area='pack_cards',index=3,targets={}}
  h.obs.advice={title='Choose Black Hole',lines={'Manufactured public action.'}}
 end
 return h
end
local function events(h,name)
 local out={};for _,record in ipairs(h.logs)do if record.event==name then out[#out+1]=record end end;return out
end
math.random=function()error('No random sampling in the controller fixture')end;pseudorandom=math.random
local huge=string.rep('private:public-state;',18000)
check(#huge>262144,'fixture really exceeds the unchanged generic string bound')
do
 local h=setup(project);h.arm();h.ready(huge)
 local result=h.controller.tick()
 check(result.active,'approved projection exports a bounded receipt before strict copying')
 eq(h.executions,1,'the accepted original action executes once')
 eq(h.checked_key,huge,'existing execution gate receives the exact full raw freshness key')
 eq(h.executed_key,huge,'actual injected Execute receives the exact full raw freshness key')
 eq(h.executed_token,'advice:1','original action-token binding is preserved')
 local attempt=events(h,'action_attempt');eq(#attempt,1,'one projected attempt receipt')
 eq(attempt[1].fingerprint.byte_length,#huge,'export records the full original key length')
 eq(attempt[1].fingerprint.sha256,string.rep('a',64),'export retains its manufactured digest descriptor')
 eq(attempt[1].action.kind,'choose','ordinary public action fields remain intact')
 eq(attempt[1].advice.title,'Choose Black Hole','public advice remains intact')
 local seen=false;for _,r in ipairs(h.projections)do if r.event=='action_attempt'then seen=r.fingerprint==huge end end
 check(seen,'projection sees the complete original key before the bounded clone')
 h.obs.action_token='advice:recalculated';h.controller.tick()
 eq(h.executions,1,'a new token cannot repeat an unchanged pending physical action')
 local next_key=huge..'settled-pack';h.ready(next_key,'advice:2');h.controller.tick()
 eq(h.executions,2,'a distinct full raw key with fresh advice can execute next')
 eq(h.executed_key,next_key,'second action keeps its exact new raw key')
 local observed=events(h,'action_observed');eq(#observed,1,'one change acknowledgment')
 eq(observed[1].before.byte_length,#huge,'prior raw identity is exported opaquely')
 eq(observed[1].after.byte_length,#next_key,'new raw identity is exported opaquely')
 eq(h.controller.status().actions,2,'projection never refunds consumed attempts')
 for _,r in ipairs(h.logs)do
  for _,key in ipairs({'fingerprint','before','after'})do check(r[key]==nil or type(r[key])=='table','raw freshness keys never fall through the projected log boundary')end
 end
end
do
 for _,projection in ipairs({false,function(r)return r end})do
  local h=projection==false and setup() or setup(projection);h.arm();h.ready('small-key');h.controller.tick()
  eq(h.executions,1,'legacy absent or identity projection retains normal execution')
  eq(events(h,'action_attempt')[1].fingerprint,'small-key','legacy small plain receipt remains identical')
 end
 local h=setup();h.arm();h.ready(huge)
 local status=h.controller.tick()
 eq(status.reason,'log_unavailable','without a projector the strict string bound is unchanged')
 eq(h.executions,0,'rejected unprojected payload never reaches Execute')
 eq(#events(h,'action_attempt'),0,'invalid raw payload is not sent to the logger')
 check(status.detail:find('plain finite values',1,true),'legacy strict-copy diagnostic is preserved')
end
do
 for _,invalid in ipairs({false,42,'not a function',{}})do
  local ok=pcall(setup,invalid);check(not ok,'present nonfunction projection is rejected at construction')
 end
end
local failures={
 {'throws',function()error('manufactured projection failure')end},
 {'nil',function()return nil end},
 {'scalar',function()return 'not a record' end},
 {'metatable',function(r)return setmetatable(shallow(r),{})end},
 {'oversized_remaining_field',function(r)local out=project(r);out.detail=huge;return out end},
 {'positive_infinity',function(r)local out=project(r);out.metric=math.huge;return out end},
 {'negative_infinity',function(r)local out=project(r);out.metric=-math.huge;return out end},
 {'nan',function(r)local out=project(r);out.metric=0/0;return out end},
 {'callback',function(r)local out=project(r);out.callback=function()end;return out end},
 {'cycle',function(r)local out=project(r);out.cycle=out;return out end},
}
for _,case in ipairs(failures)do
 local h=setup(function(record)if record.event=='action_attempt'then return case[2](record)end;return project(record)end)
 h.arm();h.ready(huge);local status=h.controller.tick()
 eq(status.reason,'log_unavailable','bad projection fails closed: '..case[1])
 eq(h.executions,0,'bad projection cannot execute: '..case[1])
 eq(#events(h,'action_attempt'),0,'bad projection never falls back to exporting raw fields: '..case[1])
 eq(status.actions,1,'failed attempt remains consumed: '..case[1])
 check(not status.active and not status.resume_available,'failed log cannot create an implicit continuation: '..case[1])
 h.controller.tick();h.controller.tick()
 eq(h.executions,0,'repeated updates do not retry a rejected action: '..case[1])
 eq(h.controller.status().actions,1,'repeated updates cannot renew the action count: '..case[1])
 check(not h.controller.resume(),'hard logging failure has no resumable allowance: '..case[1])
 eq(#events(h,'session_stopped'),1,'one separate finite stop record is preserved: '..case[1])
end
do
 local h=setup(project);h.arm();h.ready(huge);h.reject='action_attempt'
 local status=h.controller.tick()
 eq(status.reason,'log_unavailable','downstream journal rejection still stops the controller')
 eq(h.executions,0,'projected but unrecorded action cannot execute')
 eq(#events(h,'action_attempt'),1,'journal receives one valid projected attempt')
 eq(events(h,'action_attempt')[1].fingerprint.byte_length,#huge,'journal sees the descriptor, not the original key')
 h.controller.tick();h.controller.tick()
 eq(#events(h,'action_attempt'),1,'journal failure is not retried')
 eq(h.controller.status().actions,1,'journal failure does not reset the consumed attempt')
 check(not h.controller.resume(),'journal failure does not silently resume')
end
print('PASS auto-run pre-clone log projection '..checks..' checks')
