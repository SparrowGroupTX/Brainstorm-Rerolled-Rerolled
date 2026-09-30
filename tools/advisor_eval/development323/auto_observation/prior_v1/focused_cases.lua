local function counters(x)
  local calls={snapshot=0,fingerprint=0,goal=0}
  local capture,fingerprint,goal=x.A.snapshot.capture,x.A.snapshot.fingerprint,x.A.gold_stickers.capture
  x.A.snapshot.capture=function(...)calls.snapshot=calls.snapshot+1;return capture(...)end
  x.A.snapshot.fingerprint=function(...)calls.fingerprint=calls.fingerprint+1;return fingerprint(...)end
  x.A.gold_stickers.capture=function(...)calls.goal=calls.goal+1;return goal(...)end
  function calls.reset()calls.snapshot=0;calls.fingerprint=0;calls.goal=0 end
  return calls
end
local function starting()
  local x=fixture();check(x.api:start(),'manufactured explicit start accepted')
  for _=1,4 do x.api:update()end
  check(x.stats().starts==1 and x.stats().actions==0,'fixture is starting before its first action')
  return x,counters(x)
end
do
  local x=fixture();local calls=counters(x)
  for _=1,120 do x.api:update()end
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==0,'idle frames never observe public state or metadata')
  check(x.stats().actions==0 and x.stats().begins==0,'idle frames never create work')
end
for _,case in ipairs({
  {name='worker',set=function(x)x.A.worker={}end,clear=function(x)x.A.worker=nil end},
  {name='execution',set=function(x)x.A.execution_key='pending'end,clear=function(x)x.A.execution_key=nil end},
  {name='transition',set=function(x)x.g.STATE_COMPLETE=false end,clear=function(x)x.g.STATE_COMPLETE=true end},
  {name='screenwipe',set=function(x)x.g.screenwipe={}end,clear=function(x)x.g.screenwipe=nil end},
  {name='card action',set=function(x)x.g.GAME.STOP_USE=1 end,clear=function(x)x.g.GAME.STOP_USE=0 end},
  {name='locked control',set=function(x)x.g.CONTROLLER.locked=true end,clear=function(x)x.g.CONTROLLER.locked=nil end},
  {name='input lock',set=function(x)x.g.CONTROLLER.locks.frame=true end,clear=function(x)x.g.CONTROLLER.locks.frame=nil end},
  {name='drag',set=function(x)x.g.CONTROLLER.dragging={target={}}end,clear=function(x)x.g.CONTROLLER.dragging=nil end},
  {name='text entry',set=function(x)x.g.CONTROLLER.text_input_hook={}end,clear=function(x)x.g.CONTROLLER.text_input_hook=nil end},
  {name='play animation',set=function(x)x.g.play.cards={{}}end,clear=function(x)x.g.play.cards={}end},
  {name='checkpoint pending',set=function(x)x.B.Checkpoints={pending={}}end,clear=function(x)x.B.Checkpoints=nil end},
  {name='saving',set=function(x)x.g.SAVING=true end,clear=function(x)x.g.SAVING=nil end},
  {name='loading',set=function(x)x.g.LOADING=true end,clear=function(x)x.g.LOADING=nil end},
})do
  local x,calls=starting();case.set(x)
  local original_lines=x.A.lines;x.A.lines=setmetatable({},{})
  local original_action=x.A.result.action;local action={kind='play'};action.circular=action;x.A.result.action=action
  local public_key=x.A.published_key
  for frame=1,120 do x.time(frame/120);x.api:update()end
  check(calls.snapshot==0 and calls.fingerprint==0,case.name..' never captures or fingerprints blocked advice')
  check(calls.goal==120,case.name..' continues to reread Gold metadata every tick')
  check(x.api:status().active and x.stats().actions==0 and x.A.published_key==public_key,
    case.name..' does not copy malformed unused advice, mutate publication, dispatch or stop before deadline')
  x.A.lines=original_lines;x.A.result.action=original_action;case.clear(x);calls.reset();x.api:update()
  check(x.stats().actions==1 and calls.snapshot==3,case.name..' release captures observation plus both exact execution gates')
  check(calls.fingerprint==6,case.name..' release freshly fingerprints action and public state at all three gates')
end
for _,field in ipairs({'paused','modal'})do
  local x,calls=starting()
  if field=='paused'then x.g.SETTINGS.paused=true else x.g.OVERLAY_MENU={}end
  x.api:update()
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==1,field..' stops without serializing public action data')
  check(not x.api:status().active and x.api:status().reason=='manual_pause' and x.stats().actions==0,
    field..' retains immediate manual-stop behavior')
end
do
  local x=fixture();check(x.api:start(),'search fixture starts');x.api:update();x.api:update()
  local calls=counters(x)
  -- Simulated pending search holds its own result until explicitly released.
  local oldpoll=x.search.poll;x.search.poll=function()return{request_id=1,exited=false,status='searching'}end
  x.A.result={action={kind='play'}};x.A.lines=setmetatable({},{})
  for frame=1,120 do x.time(frame/120);x.api:update()end
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==120,'owned search keeps only lifecycle/goal observation')
  check(x.api:status().active and x.stats().starts==0,'search does not dispatch stale published action')
  x.time(30);x.api:update()
  check(x.api:status().reason=='search_timeout' and x.api:status().search_draining,'exact search deadline still cancels and owns drain')
  x.search.poll=oldpoll;x.A.lines={};x.api:update()
  check(not x.api:status().search_draining and x.stats().starts==0,'late found result drains without launch after timeout')
end
do
  local x,calls=starting();x.api:update();check(x.stats().actions==1,'pending fixture dispatches once')
  x.A.worker={};calls.reset()
  for second=1,29 do x.time(second);x.g.GAME.chips=second+1;x.publish();calls.reset();x.api:update()
    check(calls.snapshot==0 and x.stats().actions==1,'changed blocked state never repeats a pending action')end
  x.time(30);calls.reset();x.api:update()
  check(x.api:status().reason=='action_observation_stalled' and not x.api:status().active,
    'changing state or fresh publication cannot renew pending action watchdog')
  check(calls.snapshot==0 and calls.goal==1,'deadline tick retains lifecycle checking without snapshot work')
end
do
  local x,calls=starting();x.g.CONTROLLER.dragging={target={}};x.api:update()
  local prior=x.A.published_key;x.g.GAME.chips=22;x.g.CONTROLLER.dragging=nil;calls.reset();x.api:update()
  check(x.stats().actions==0 and x.api:status().waiting_for=='fresh_advice' and calls.snapshot==1,
    'release recaptures changed state and refuses old publication')
  check(x.A.published_key==prior,'observation never repairs a stale published key')
  x.publish();calls.reset();x.api:update();check(x.stats().actions==1 and calls.snapshot==3,'new matching publication permits exactly one action')
end
do
  local x,calls=starting();x.g.CONTROLLER.dragging={target={}};x.api:update()
  x.A.retry_generation=x.A.retry_generation+1;x.g.CONTROLLER.dragging=nil;calls.reset();x.api:update()
  check(x.stats().actions==0 and x.api:status().waiting_for=='executable_action',
    'generation changed while blocked cannot dispatch prior publication')
end
for _,change in ipairs({'public_state','action','generation'})do
  local x,calls=starting();local once=true
  x.A.can_execute=function()
    if once then once=false
      if change=='public_state'then x.g.GAME.chips=x.g.GAME.chips+10
      elseif change=='action'then x.A.result.action.indices={2}
      else x.A.retry_generation=x.A.retry_generation+1 end
    end
    return true
  end
  x.api:update()
  check(x.stats().actions==0 and x.api:status().reason=='execute_failed',change..' changed after can_execute is caught before actual Execute')
  local consumed=x.api:status().actions;x.api:update()
  check(consumed==1 and x.api:status().actions==1,change..' consumes its uncertain attempt once and never retries')
end
do
  local x,calls=starting();x.A.worker={};x.g.STATE=99;x.g.GAME.won=true
  x.game_class.update_game_over(x.g);x.api:update()
  check(calls.snapshot==0 and calls.fingerprint==0 and calls.goal==1,'terminal observation bypasses irrelevant action serialization and rereads metadata')
  check(x.api:status().outcomes.losses==1 and x.api:status().outcomes.wins==0,'incidental won during GAME_OVER remains a loss despite worker activity')
end
do
  local x,calls=starting();x.g.CONTROLLER.dragging={target={}};x.api:update();calls.reset()
  x.g.PROFILES[1]={};x.api:update()
  check(not x.api:status().active and x.api:status().reason=='observation_unavailable',
    'loaded profile identity replacement while blocked still stops immediately')
  check(calls.snapshot==0 and calls.goal==0,'profile mismatch is rejected before observation')
end
print('advisor_auto_observation: '..checks..' checks passed')
