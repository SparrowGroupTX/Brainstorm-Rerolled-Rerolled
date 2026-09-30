-- Append before advisor_runtime.lua's final print; uses its existing setup/complete helpers.
do
  local A=setup();G.STATE=G.STATES.ROUND_EVAL
  A.decision.run=function()return {kind='strategy',evaluations=0,
    strategy={title='Cash Out',lines={'Synthetic completed round.'}},action={kind='cash_out'}}end
  local root={elements={},states={visible=true},config={}}
  function root:get_UIE_by_ID(id)return self.elements[id]end
  G.round_eval=root
  local detached={elements={},config={major=root},states={visible=true}}
  function detached:get_UIE_by_ID(id)return self.elements[id]end
  detached.UIRoot={UIBox=detached,states={visible=true},config={}}
  local button={UIBox=detached,parent=detached.UIRoot,states={visible=true},config={id='cash_out_button'}}
  detached.elements.cash_out_button=button;G.I={UIBOX={detached}}
  local calls=0;G.FUNCS.cash_out=function(e)equal(e,button,'runtime passes original detached cash-out element');calls=calls+1 end
  complete(A)
  local key,generation,result=A.published_key,A.published_generation,A.result
  for _=1,5 do
    local ready,why=A.can_execute()
    check(ready==false and type(why)=='string' and #why>0,'runtime exposes an explicit cash-out wait reason')
    local accepted,reason=A.execute(key,generation)
    check(accepted==false and type(reason)=='string' and #reason>0,'early manual Execute returns its readiness reason')
    equal(A.result,result,'unready live button does not invalidate complete advice')
    equal(A.execution_key,nil,'unready live button does not consume the execution latch')
  end
  equal(calls,0,'nothing cashes out while detached button is still disabled')
  equal(A.published_key,key,'UI readiness does not change the public-state publication')
  button.config.button='cash_out'
  check(A.can_execute(),'the same public-state advice becomes executable when its button enables')
  check(A.execute(key,generation),'runtime dispatches once through original detached button')
  equal(calls,1,'exactly one cash-out callback')
  check(not A.execute(key,generation) and calls==1,'same-frame repeated click cannot cash out twice')
end
do
  local A=setup();G.STATE=G.STATES.ROUND_EVAL
  A.decision.run=function()return {kind='strategy',evaluations=0,
    strategy={title='Cash Out',lines={}},action={kind='cash_out'}}end
  local root={elements={},config={},states={visible=true}}
  function root:get_UIE_by_ID(id)return self.elements[id]end
  local button={config={button='cash_out'},states={visible=true},UIBox=root}
  root.elements.cash_out_button=button;G.round_eval=root
  G.FUNCS.cash_out=function()error('Original synthetic cash-out failure')end
  complete(A)
  local accepted,reason=A.execute(A.published_key,A.published_generation)
  check(accepted==false and type(reason)=='string' and reason:find('Original synthetic cash-out failure',1,true),
    'runtime preserves original callback error text rather than returning false as a reason')
  check(A.execution_key~=nil and not A.can_execute(),'an attempted failing callback retains the duplicate latch')
end
