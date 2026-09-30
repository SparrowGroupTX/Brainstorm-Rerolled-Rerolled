-- One manufactured reproduction, not captured-policy evaluation.
local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local s=F.state();s.hand={};s.deck={};s.hand_size=8;s.blind.chips=100;s.ante=3
for i=1,8 do s.hand[i]=F.card('h'..i,13)end
for i=1,18 do s.deck[i]=F.card('d'..i,13)end
s.jokers={F.joker('j_yorick','Yorick',{x_mult=2,yorick_discards=15,extra={discards=23,xmult=1}})};F.population(s)
local opt={strategy=A.strategy,draws=A.draws,sampled_outcomes=A.sampled_outcomes,
 samples=24,candidates=16,max_evaluations=140000,fast_clear=false,win_first_yorick_clear_discard=true}
local r=A.search.run(s,A.scoring,opt)
print(assert(A.player_journal.encode({kind=r.kind,cards=r.discard and #r.discard.indices,risk=r.risky_yorick_clear,
 comparison=r.resource_comparison,evaluations=r.evaluations})))
