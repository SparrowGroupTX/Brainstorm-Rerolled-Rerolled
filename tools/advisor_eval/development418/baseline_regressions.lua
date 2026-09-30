-- Only independently invented states; never load a captured observation.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
local old=dofile('tools/advisor_eval/runs/repair417_candidate1/policy/Brainstorm/Advisor/growth.lua')
for _,chad in ipairs({false,true}) do
 local s=F.state(chad);local clear=F.clear(m,s)
 assert(not old.suggest(s,m,clear,{exhaust_discards=true,max_evaluations=12}),'baseline unexpectedly qualifies new effect family')
 assert(m.growth.suggest(s,m,clear,{exhaust_discards=true,max_evaluations=12}),'new family does not qualify')
 print('DISTINGUISHED '..(chad and 'complete Chad order floor' or 'Flower Pot/card-trigger additive row'))
end
local s=F.state(false);s.blind={key='bl_house',name='The House',chips=2000}
for i=6,8 do s.hand[i].face_down=true end;F.population(s)
assert(not old.visible_retained(s,m,12),'baseline unexpectedly qualifies hidden spare family')
assert(m.growth.visible_retained(s,m,12),'new hidden spare family does not qualify')
print('DISTINGUISHED public hidden-spare discard')
