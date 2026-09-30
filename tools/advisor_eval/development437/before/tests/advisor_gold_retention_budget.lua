-- Manufactured Decision integration: acquisition, ordinary scoring and the
-- retention reserve share one allowance; protected exits keep their fixed row.
local D=dofile('Brainstorm/Advisor/decision.lua')
local R=dofile('Brainstorm/Advisor/gold_retention.lua')
local checks=0
local function eq(a,b,why)checks=checks+1;assert(a==b,why..': '..tostring(a)..' ~= '..tostring(b))end
local function check(v,why)checks=checks+1;assert(v,why)end
local function setup(o)
 o=o or {}
 local c={floors=0,scores=0,contexts=0,advise=0,fallback=0,post=0}
 local s={phase='shop',ante=8,win_ante=8,jokers={{key='j_crazy',id='missing'}},
  next_blind={key='bl_big',ante=8,boss=false,chips=1000},
  completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
   eligibility={eligible=true},by_key={j_crazy={status='missing'}}}}
 local m={scoring={lower_bound=function()c.floors=c.floors+1;return {score=100}end,
  score=function()c.scores=c.scores+1;return {score=100}end}}
 local function sale()return {title='Ordinary replacement',action={kind='sell',area='jokers',index=1,
  followup={kind='buy',area='shop_jokers',index=1}},lines={},warnings={}}end
 m.gold_acquisition={suggest=function(state,mods,y,options)
  c.acquisition_limit=options.max_evaluations
  for i=1,o.acquisition or 7 do mods.scoring.lower_bound(state,{1})end
  return nil,o.acquisition or 7,{complete=false,reason='Manufactured acquisition comparison was insufficient.'}
 end}
 m.shop_scoring={new=function(state,scorer,y,options)
  c.contexts=c.contexts+1;c.ordinary_limit=options.max_evaluations
  local count=math.min(c.ordinary_limit,o.ordinary_spent or c.ordinary_limit)
  for i=1,count do scorer.score(state,{1})end
  return {evaluations=count,truncated=o.truncated==true}
 end}
 m.strategy={advise=function(state,options)
  c.advise=c.advise+1;if not options then c.fallback=c.fallback+1 end
  local result=sale();result.from_fallback=not options;return result
 end}
 m.gold_retention={reserve=R.reserve,suggest=function(state,mods,base,remaining,yield)
  c.retention_limit=remaining;c.retention_base_fallback=base.from_fallback
  if R.reserve(state,remaining)==0 or o.no_override then return nil,0,{complete=true,reason='No applicable retained cargo.'}end
  local attempts=o.retention_mode=='over' and remaining+2 or o.retention_calls or 6
  for i=1,attempts do mods.scoring.lower_bound(state,{1})end
  local result={title='Keep cargo',action={kind='leave_shop'},gold_retention={after_missing=1},lines={},warnings={}}
  return result,o.retention_mode=='wrong' and 0 or attempts,{complete=true,after_missing=1}
 end}
 if o.phase_copy then m.phase_copy={apply=function(state,mods,result)
  c.post=c.post+1;result.action={kind='reorder_jokers',order={1}};return result
 end}end
 return s,m,c
end
do
 local s,m,c=setup();local options={shop_scoring={max_evaluations=50000,custom=true}}
 local r=D.run(s,m,nil,options)
 eq(c.acquisition_limit,50000,'acquisition retains the total caller cap')
 eq(c.ordinary_limit,41993,'ordinary scoring excludes spent acquisition and8000 reserved retention')
 eq(c.retention_limit,8000,'retention receives the unspent reserved capacity')
 eq(c.floors,13,'actual acquisition and retention floors counted')
 eq(r.evaluations,c.floors+c.scores,'aggregate includes all actual work')
 eq(r.evaluations,42006,'unused reserve is not invented work')
 eq(r.action.kind,'leave_shop','completed retention replaces the ordinary sale')
 eq(r.gold_retention_diagnostics.reserved_evaluations,8000,'reserve is explicit in current diagnostics')
 eq(options.shop_scoring.max_evaluations,50000,'caller options are unchanged')
end
do
 local s,m,c=setup({ordinary_spent=11})
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=50000}})
 eq(c.retention_limit,49982,'retention can use both reserved and unused ordinary allowance')
 eq(r.evaluations,24,'aggregate reports only executed work')
end
do
 local s,m,c=setup({truncated=true})
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=50000}})
 eq(c.advise,2,'ordinary truncation restarts its whole advice family')
 eq(c.fallback,1,'the fallback does not create another scoring context')
 eq(c.contexts,1,'ordinary spent work is never reset')
 eq(c.retention_base_fallback,true,'retention compares the actual fallback incumbent')
 eq(r.action.kind,'leave_shop','remaining reserved capacity can complete retention after ordinary truncation')
 eq(r.evaluations,c.floors+c.scores,'truncated ordinary work is still charged')
end
for _,mode in ipairs({'wrong','over'})do
 local s,m,c=setup({retention_mode=mode})
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
 eq(c.ordinary_limit,0,'small caller budget is not exceeded by the reservation')
 eq(c.retention_limit,13,'spent acquisition is charged before lower-cap retention')
 eq(r.action.kind,'sell','bad retention accounting cannot suppress ordinary advice')
 eq(r.gold_retention_diagnostics.complete,false,'accounting failure is explicit')
 eq(c.floors,mode=='over' and 20 or 13,'underlying floors are strictly capped')
 eq(r.evaluations,c.floors+c.scores,'mismatched or exhausted work remains charged')
 check(r.evaluations<=20,'all three stages remain within the caller budget')
end
do
 local s,m,c=setup({acquisition=0,retention_calls=3})
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=5}})
 eq(c.ordinary_limit,0,'five-score caller retains its entire small reserve')
 eq(c.retention_limit,5,'five-score caller bounds the retained comparison')
 eq(r.evaluations,3,'unused small reserve is free');eq(r.action.kind,'leave_shop','complete small fixture can retain')
end
do
 local s,m,c=setup({acquisition=20})
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
 eq(c.ordinary_limit,0,'exhausted acquisition leaves no ordinary work')
 eq(c.retention_limit,0,'exhausted acquisition leaves no retention work')
 eq(r.evaluations,20,'a reservation never renews exhausted work');eq(r.action.kind,'sell','no remaining proof leaves incumbent')
end
do
 local s,m,c=setup({phase_copy=true});s.completionist_goal=nil
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
 eq(c.acquisition_limit,nil,'goal optout skips acquisition')
 eq(c.ordinary_limit,20,'goal optout reserves nothing')
 eq(c.floors,0,'goal optout has no goal-specific scoring')
 eq(c.post,1,'ordinary optout still receives phase-copy processing')
 eq(r.action.kind,'reorder_jokers','ordinary postprocessor remains active')
end
do
 local s,m,c=setup({acquisition=0,phase_copy=true});s.completionist_goal.by_key.j_crazy.status='complete'
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
 eq(c.ordinary_limit,20,'no held missing identity reserves nothing')
 eq(c.floors,0,'no held missing identity performs no retention floors')
 eq(c.post,1,'ordinary completed row still receives postprocessing')
end
do
 local s,m,c=setup({phase_copy=true})
 local r=D.run(s,m,nil,{shop_scoring={max_evaluations=20}})
 eq(c.post,0,'qualified fixed-row retention exit bypasses the reordering postprocessor')
 eq(r.action.kind,'leave_shop','protected exit retains the compared physical row')
 local s2,m2,c2=setup({phase_copy=true,retention_mode='wrong'})
 local r2=D.run(s2,m2,nil,{shop_scoring={max_evaluations=20}})
 eq(c2.post,1,'invalid retention proof does not bypass ordinary postprocessing')
 eq(r2.action.kind,'reorder_jokers','an unprotected result still follows ordinary phase-copy behavior')
end
print('PASS Gold retention shared budget '..checks..' checks')
