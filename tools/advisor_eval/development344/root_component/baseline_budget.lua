-- Manufactured integration: collection work and ordinary work share one cap.
local D=dofile('tools/advisor_eval/development344/root_component/before/Brainstorm/Advisor/decision.lua')
local checks=0
local function eq(a,b,why) checks=checks+1;assert(a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local function setup(mode)
  local calls,ordinary,contexts,seen_limit=0,0,0,nil
  local mods={scoring={lower_bound=function() calls=calls+1;return {score=100} end}}
  local buy={title='Target',action={kind='buy',area='shop_jokers',index=1},lines={},warnings={}}
  mods.gold_acquisition={suggest=function(s,m,y,o)
    seen_limit=o.max_evaluations
    if mode=='none' then return nil,0,{complete=true,reason='No target.'} end
    for i=1,mode=='over' and 25 or 7 do m.scoring.lower_bound(s,{1}) end
    if mode=='wrong' then return buy,1,{complete=true} end
    if mode=='win' or mode=='over' then return buy,7,{complete=true} end
    return nil,7,{complete=false,reason='Insufficient complete margin.'}
  end}
  mods.shop_scoring={new=function(s,m,y,o)
    contexts=contexts+1;ordinary=o and o.max_evaluations or 50000
    return {evaluations=ordinary,truncated=ordinary==0}
  end}
  mods.strategy={advise=function() return {title='Leave',action={kind='leave_shop'},lines={},warnings={}} end}
  local state={phase='shop',jokers={},completionist_goal={}}
  return state,mods,function() return calls,ordinary,contexts,seen_limit end
end
do
  local s,m,count=setup('win');local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
  local calls,ordinary,contexts,limit=count()
  eq(r.action.kind,'buy','completed objective action precedes ordinary scoring')
  eq(r.evaluations,7,'actual objective calls reported');eq(calls,7,'actual calls')
  eq(contexts,0,'ordinary work never starts after complete collection choice');eq(limit,20,'caller cap preserved')
end
do
  local s,m,count=setup('fail');local options={shop_scoring={max_evaluations=20,custom=true}}
  local r=D.run(s,m,nil,options);local calls,ordinary=count()
  eq(r.action.kind,'leave_shop','incomplete family falls back');eq(ordinary,13,'failed work reduces remaining budget')
  eq(r.evaluations,20,'total budget includes unsuccessful work');eq(calls,7,'actual floor calls counted')
  eq(options.shop_scoring.max_evaluations,20,'caller options untouched')
  eq(r.gold_acquisition_diagnostics.reason,'Insufficient complete margin.','fallback retains compact diagnosis source')
end
for _,mode in ipairs({'wrong','over'}) do
  local s,m,count=setup(mode);local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
  local calls,ordinary=count()
  eq(r.action.kind,'leave_shop','invalid accounting cannot publish a buy')
  eq(calls,mode=='over' and 20 or 7,'underlying scorer never exceeds caller limit')
  eq(ordinary,20-calls,'all actual work charged on malformed result')
  eq(r.evaluations,20,'aggregate cap preserved');eq(r.gold_acquisition_diagnostics.complete,false,'bad accounting explicit')
end
do
  local s,m,count=setup('none');local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
  local calls,ordinary=count();eq(calls,0,'nonapplicable work is free');eq(ordinary,20,'nonapplicable keeps ordinary allowance')
  eq(r.evaluations,20,'ordinary accounting unchanged')
end
do
  local s,m,count=setup('win');s.completionist_goal=nil
  local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
  local calls,ordinary=count();eq(calls,0,'optout does not run collection');eq(ordinary,20,'optout ordinary allowance unchanged')
  eq(r.action.kind,'leave_shop','optout ordinary action unchanged')
end
do
  local s,m,count=setup('win');m.opening={advice=function() return {action={kind='opening'}} end}
  local r=D.run(s,m,nil);local calls,ordinary,contexts=count()
  eq(r.action.kind,'opening','declared opening still precedes acquisition');eq(calls,0,'no opening collection calls');eq(contexts,0,'no opening ordinary calls')
end
print('gold acquisition budget: '..checks..' checks passed')
