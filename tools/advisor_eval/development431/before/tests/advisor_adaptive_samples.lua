local Search=dofile('Brainstorm/Advisor/search.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local function c(i)return {id=i,rank=i+2,suit='Spades',ability={}}end
local s={hand={c(1),c(2)},deck={c(3),c(4)},hand_size=2,discards_left=1,hands_left=1,hand_limit=5,
  dollars=0,blind={chips=100},chips=0,jokers={},hands={},modifiers={}}
local scorer={after_discard=Score.after_discard,score=function(t,indices)
  local score=10
  if (t.discards_used or 0)>0 then for _,i in ipairs(indices) do if t.hand[i].id==1 then score=100 end end end
  return {score=score,legal=true,hand='High Card',scoring_indices=indices}
end}
local full=Search.run(s,scorer,{adaptive_samples=false})
local reduced=Search.run(s,scorer,{})
assert(full.kind==reduced.kind and table.concat(full.discard.indices,',')==table.concat(reduced.discard.indices,','))
assert(full.discard.count==24 and reduced.discard.count==13)
assert(reduced.evaluations<full.evaluations)
assert(reduced.search_diagnostics.adaptive_samples.uncomputed_tail==11)
assert(reduced.discard.wins>11,'even all remaining rival successes cannot reverse the action')
scorer.score=function(t,indices) return {score=(t.discards_used or 0)>0 and 100 or 10,legal=true,hand='High Card',scoring_indices=indices} end
local ties=Search.run(s,scorer,{})
assert(ties.discard.count==24 and not ties.search_diagnostics.adaptive_samples,'ties do not justify stopping')
print('adaptive samples: 6 checks; score calls '..full.evaluations..' -> '..reduced.evaluations..'; exact planned-set action retained')
