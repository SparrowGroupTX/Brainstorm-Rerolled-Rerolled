-- Routine harness fixture. All source callbacks below are handwritten doubles;
-- no preserved source, executable ZIP, seed search or captured state is loaded.
POLICY_SCORING=dofile('Brainstorm/Advisor/scoring.lua')
POLICY_SNAPSHOT=dofile('Brainstorm/Advisor/snapshot.lua')
local harness=dofile('tools/advisor_eval/development287/lucky_source_truth.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
Card={}
function Card:calculate_seal(context)
  if context.repetition and self.seal=='Red' then return {repetitions=1} end
end
function Card:get_chip_mult()
  if pseudorandom('lucky_mult')<0.2 then self.lucky_trigger=true;return 20 end
  return 0
end
function Card:get_p_dollars()
  local result=0
  if pseudorandom('lucky_money')<1/15 then self.lucky_trigger=true;result=20 end
  if result>0 then
    G.GAME.dollar_buffer=G.GAME.dollar_buffer+result
    G.E_MANAGER:add_event(Event({func=function() G.GAME.dollar_buffer=0;return true end}))
  end
  return result
end
function eval_card(c,context)
  if context.repetition_only then return {seals=c:calculate_seal(context)} end
  return {chips=c.base.nominal,mult=c:get_chip_mult(),p_dollars=c:get_p_dollars()}
end
for _,mode in ipairs({'ordinary','red'}) do
  local emitted={}
  local rows,summary=harness.run(mode,function(row) emitted[#emitted+1]=row end)
  check(#rows==(mode=='red' and 16 or 4),'Exact finite case family')
  check(#emitted==#rows+1 and summary.passed,'Every case and final summary emitted')
  check(not summary.full_source_scoring_phase_qualified,'No source qualification claim')
  for _,row in ipairs(rows) do
    local mult,cash=1,0
    for _,event in ipairs(row.events) do mult=mult+(event.mult and 20 or 0);cash=cash+(event.dollars and 20 or 0) end
    check(row.source_score==(5+10*row.evaluations)*mult,'Distinct repetition outcomes reach score')
    check(row.source_cash_delta==cash and row.advisor_cash_delta==cash,'Distinct cash triggers applied once')
    check(row.random_calls==row.evaluations*2,'Exactly two triggers per evaluation')
    check(row.timeline[1].key=='lucky_mult' and row.timeline[2].key=='lucky_money','Ordering captured')
  end
end
local old_seal=Card.calculate_seal
Card.calculate_seal=function() return {repetitions=2} end
check(not pcall(harness.run,'red'),'Wrong source repetition count must fail')
Card.calculate_seal=old_seal
local old_cash=Card.get_p_dollars
Card.get_p_dollars=function(self) local n=old_cash(self);G.GAME.dollars=G.GAME.dollars+n;return n end
check(not pcall(harness.run,'ordinary'),'Double-paid getter fails')
Card.get_p_dollars=old_cash
local old_mult=Card.get_chip_mult
Card.get_chip_mult=function(self) local n=old_mult(self);return n+1 end
check(not pcall(harness.run,'ordinary'),'Conditional score mismatch fails')
Card.get_chip_mult=old_mult
check(not pcall(harness.run,'unbounded'),'Unknown truth-table mode fails')
print('Lucky source harness synthetic doubles: '..checks..' checks passed; no original source executed')
