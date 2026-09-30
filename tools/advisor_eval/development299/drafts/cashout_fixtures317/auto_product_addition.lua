-- Append before advisor_auto_run_product.lua's final print; manufactured fixture only.
do
  local Execution=dofile('Brainstorm/Advisor/execution.lua')
  local x=fixture();assert(x.api:start())
  for _=1,4 do x.api:update()end
  check(x.stats().starts==1 and x.stats().actions==0,'cash-out fixture starts its synthetic normal run before any play')
  x.g.STATES.ROUND_EVAL=3;x.g.STATE=3
  local root={elements={},config={},states={visible=true}}
  function root:get_UIE_by_ID(id)return self.elements[id]end
  x.g.round_eval=root
  local detached={elements={},config={major=root},states={visible=true}}
  function detached:get_UIE_by_ID(id)return self.elements[id]end
  detached.UIRoot={UIBox=detached,states={visible=true},config={}}
  local button={config={id='cash_out_button'},states={visible=true},UIBox=detached,parent=detached.UIRoot}
  detached.elements.cash_out_button=button;x.g.I={UIBOX={detached}}
  local callback_count=0
  x.g.FUNCS.cash_out=function(e)check(e==button,'automatic cash-out dispatch retains original detached element');callback_count=callback_count+1 end
  x.A.result={action={kind='cash_out'}}
  x.A.published_key=x.A.snapshot.fingerprint(x.A.snapshot.capture(x.g));x.A.published_generation=x.A.retry_generation
  x.A.can_execute=function()return Execution.button_ready(x.g,x.A.result.action)end
  local original_execute=x.A.execute
  x.A.execute=function(...)
    local accepted,reason=Execution.execute(x.g,{kind='cash_out'})
    if not accepted then return false,reason end
    return original_execute(...)
  end
  local function event_count(name)
    local count=0;for _,row in ipairs(x.events)do if row.data and row.data.event==name then count=count+1 end end;return count
  end
  local attempts=event_count('action_attempt')
  local _,reason=Execution.button_ready(x.g,{kind='cash_out'})
  for second=1,5 do
    x.time(second);x.api:update()
    local status=x.api:status_report()
    check(status.busy and status.text:find(reason,1,true),'waiting automatic status exposes the exact live cash-out reason')
    check(event_count('action_attempt')==attempts and x.stats().actions==0 and callback_count==0,
      'unavailable button consumes neither action attempt nor callback')
  end
  button.config.button='cash_out';x.api:update()
  check(callback_count==1 and x.stats().actions==1 and event_count('action_attempt')==attempts+1,
    'one enabling transition permits exactly one automatic cash-out')
  x.api:update()
  check(callback_count==1 and x.stats().actions==1,'unchanged publication cannot automatically repeat cash-out')
  check(x.api:status().active,'successful cash-out does not stop automatic mode')
end
do
  local x=fixture();assert(x.api:start())
  for _=1,4 do x.api:update()end
  x.A.execute=function()return false,'Specific synthetic cash-out callback failure' end
  x.api:update()
  local status=x.api:status()
  check(not status.active and status.reason=='execute_failed' and status.detail=='Specific synthetic cash-out callback failure',
    'a consumed automatic execution failure keeps its original string reason and stops without retry')
  local before=x.stats().actions;x.api:update();check(x.stats().actions==before,'failed execution is never automatically retried')
end
