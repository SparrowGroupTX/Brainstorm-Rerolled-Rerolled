-- Independent manufactured discrimination of the second repair.
local F=dofile('tests/fixtures/repair416.lua');local m=F.modules()
m.growth=dofile('tools/advisor_eval/runs/repair416_candidate2/policy/Brainstorm/Advisor/growth.lua')
local s=F.state();s.hand={F.card('a',12,'Clubs','m_mult'),F.card('b',12,'Spades'),F.card('c',11,'Hearts'),F.card('d',11,'Diamonds'),F.card('e',2,'Clubs')};s.hand_size=5
s.jokers={F.joker('j_joker','Joker',{mult=4}),F.joker('j_yorick','Yorick',{x_mult=4,yorick_discards=22,extra={discards=23,xmult=1}})}
s.blind.chips=600;F.population(s)
local a=m.scoring.score(s,{1,2});a.indices={1,2}
local b=m.scoring.score(s,{3,4});b.indices={3,4}
assert(a.score>=600 and b.score>=600,'both invented pairs actually clear')
local chosen=m.growth.select_clear(s,a,{a,b},{exhaust_discards=true})
assert(chosen==b,'baseline must select safe scored alternative instead of hazardous incumbent')
