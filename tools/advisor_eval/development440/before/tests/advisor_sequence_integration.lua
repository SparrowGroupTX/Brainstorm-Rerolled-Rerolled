local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(x,s) checks=checks+1;assert(x,s) end
local calls=0
local context={evaluations=7,truncated=false,metrics={}}
local modules={strategy={advise=function(_,options)
  return {action={kind='leave_shop'},lines={},warnings={},has_context=options~=nil}
end},shop_scoring={new=function() return context end},shop_sequences={suggest=function(s,m,base,c)
  calls=calls+1
  check(s.phase=='shop' and c==context and base.action.kind=='leave_shop','Sequence sees the complete incumbent and shared context')
  return {action={kind='buy',area='shop_jokers',index=1},lines={},warnings={}},{complete=true,states=3}
end}}
local result=Decision.run({phase='shop'},modules)
check(result.action.kind=='buy' and result.shop_diagnostics.sequences.complete,'Complete sequence result is executable and reviewable')
check(result.evaluations==7 and calls==1,'Sequence evaluation counts use the same context')
modules.shop_sequences.suggest=function() context.truncated=true;return nil,{complete=false,reason='Budget exhausted'} end
result=Decision.run({phase='shop'},modules)
check(result.action.kind=='leave_shop' and not result.strategy.has_context,'Incomplete shared scoring falls back for the whole decision')
check(not result.shop_diagnostics.sequences.complete,'Failed sequence diagnostics survive fallback')
print('advisor_sequence_integration: '..checks..' checks passed')
