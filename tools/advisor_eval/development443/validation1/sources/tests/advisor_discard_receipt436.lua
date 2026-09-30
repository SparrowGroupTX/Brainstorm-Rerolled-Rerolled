-- Final-arbitration seam; real Lucky floor/ceiling and budget accounting.
local F=dofile('tests/fixtures/repair416.lua');local S=dofile('Brainstorm/Advisor/scoring.lua')
local D=dofile('Brainstorm/Advisor/decision.lua');local J=dofile('Brainstorm/Advisor/player_journal.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function state(target)
 local s=F.state();s.jokers={};s.blind.chips=target
 s.hand[1]=F.card('lucky',13);s.hand[1].enhancement='m_lucky';s.hand[1].ability.mult=20;s.hand[1].ability.p_dollars=20
 F.population(s);return s
end
local function run(target,limit,scorer)
 local s=state(target);local p=S.score(s,{1});p.indices={1}
 return D.run(s,{scoring=scorer or S,search={run=function()return {kind='play',play=p,evaluations=0,
  action={kind='play',area='hand',indices={1}}}end}},nil,{search={max_evaluations=limit or 12}})
end
local r=run(1000);local d=r.discard_before_clear
check(d.status=='not_finishing'and d.reason=='selected_play_cannot_clear','Impossible random clear diagnosed honestly')
check(d.final_play_score==15 and d.final_play_upper_bound==315,'Exact conditional score bounds')
check(r.evaluations==2 and d.evaluations==2,'Both bounds charged')
local c=J.compact_discard_before_clear(r);check(c.final_play_upper_bound==315,'Public receipt preserves upper bound')
r=run(100);d=r.discard_before_clear
check(d.status=='exception'and d.reason:find('does not establish a clearing probability',1,true),'Range inclusion is not calibrated odds')
r=run(1000,1);d=r.discard_before_clear
check(r.evaluations==1 and d.final_play_upper_bound==nil,'No upper score beyond caller allowance')
check(d.reason:find('unresolved',1,true),'Exhausted bound cannot claim possibility or impossibility')
for _,ceiling in ipairs({{legal=true,score=1,uncertain=true,reliable_bound=true},
 {legal=true,score=1,reliable_bound=false},{legal=false,score=1,reliable_bound=true},
 {legal=true,score=0/0,reliable_bound=true}})do
 local scorer=setmetatable({upper_bound=function()return ceiling end},{__index=S})
 r=run(1000,12,scorer)
 check(r.discard_before_clear.reason:find('unresolved',1,true),'Unsupported ceiling rejected')
 check(r.evaluations==2,'Rejected ceiling still charged')
end
print('Discard receipt436: '..checks..' checks passed')
