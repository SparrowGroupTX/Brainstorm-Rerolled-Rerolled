local T=dofile('tests/fixtures/shop433.lua');local F,m,j=T.F,T.m,T.joker
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state(key)
 local s=T.state();s.jokers={F.j('j_yorick'),F.j('j_perkeo'),F.j('j_brainstorm'),j('j_misprint'),F.j('j_hanging_chad')}
 s.shop_jokers={j(key or 'j_blueprint','incoming433')};s.shop_jokers[1].cost=10
 return s
end
local old_random=math.random;math.random=function()error('Game RNG used by endpoint fixture')end
for _,key in ipairs({'j_blueprint','j_brainstorm'})do
 local s=state(key);local before=m.snapshot.fingerprint(s)
 local result=m.decision.run(s,m,nil,{prepared_scoring=false})
 check(result.action and result.action.kind=='sell' and result.action.index==4,'remove uncertain Misprint for '..key..': '..tostring(result.action and result.action.kind))
 check(result.strategy.copy_endpoint_certificate and result.strategy.copy_endpoint_certificate.completion_nonregression,'separate supported endpoint certificate')
 check(not result.strategy.scoring_evidence.complete_finishing and result.strategy.scoring_evidence.uncertain,'incumbent uncertainty remains explicit')
 check(result.evaluations<=50000 and result.strategy.shop_sequence.sale_revalidation_qualified,'real continuation prequalified within shared budget')
 local pending=assert(m.shop_sequences.prepare_commitment(s,result.strategy,m))
 local sold=assert(m.shop_sequences.transition(s,result.action,m))
 sold.shop_sequence_commitment=m.shop_sequences.observe_commitment(sold,pending,m)
 check(sold.shop_sequence_commitment.status=='matched','settled physical sale matches continuation')
 local fresh=m.decision.run(sold,m,nil,{prepared_scoring=false})
 check(fresh.action and fresh.action.kind=='buy' and fresh.action.index==1,'fresh advice completes funded '..key)
 check(fresh.shop_diagnostics.continuation.complete,'fresh remaining endpoint revalidated')
 check(m.snapshot.fingerprint(s)==before,'full public input unchanged')
 local compact=dofile('Brainstorm/Advisor/player_journal.lua').compact_copy_death_review(result)
 check(compact.copy_endpoint and compact.copy_endpoint.paired_score_improvement==false,'no paired improvement claim')
 local limit=result.evaluations
 local exact=m.decision.run(s,m,nil,{prepared_scoring=false,shop_scoring={max_evaluations=limit}})
 check(exact.action.kind=='sell' and exact.evaluations<=limit,'exact whole-family/continuation budget fits')
 local short=m.decision.run(s,m,nil,{prepared_scoring=false,shop_scoring={max_evaluations=1}})
 check(short.action.kind~='sell' and short.evaluations<=1,'insufficient budget cannot publish sale')
end
-- Exercise individual certificate boundaries by corrupting the real endpoint
-- receipt at the comparison seam. This changes no scorer result or live state.
for _,case in ipairs({'losing_world','world_ids','composition_id','order','source','unknown_target','reserve','incomplete','perkeo'})do
 local s=state();local context=m.shop_scoring.new(s,m.scoring,nil,{max_orders=4})
 local compare=context.compare
 function context:compare(a,b)
  local e=compare(self,a,b);if not e then return end
  if case=='losing_world' and e.after_finishing and e.after_finishing.selected then e.after_finishing.selected.worlds[4].clear=false
  elseif case=='world_ids' then e.common_worlds.world_ids[4]=3
  elseif case=='composition_id' and e.after_finishing and e.after_finishing.selected then e.after_finishing.selected.worlds[1].composition_world_id=2
  elseif case=='order' then e.after_ordering.order[2]=e.after_ordering.order[1]
  elseif case=='incomplete' then e.incomplete=true
  elseif case=='unknown_target' then e.after_target=nil end
  return e
 end
 if case=='source' then s.jokers[1].blueprint_compat=false
 elseif case=='reserve' then s.dollars=11;s.modifiers.discard_cost=3
 elseif case=='perkeo' then s.jokers[4].ability.eternal=true;s.jokers[5].ability.eternal=true end
 local a=m.strategy.copy_acquisition(s,context)
 check(not a or not a.copy_endpoint_certificate,'reject endpoint certificate '..case)
end
math.random=old_random
print('Copy endpoint433: '..n..' manufactured assertions passed')
