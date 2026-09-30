-- Invented rental/slot state, never a captured run replay.
local T=dofile('tests/fixtures/shop433.lua');local F,m,j=T.F,T.m,T.joker
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=T.state();s.dollars=4;s.joker_limit=6;s.rental_rate=3
 s.jokers={j('j_abstract'),F.j('j_yorick'),j('j_red_card'),j('j_clever'),F.j('j_perkeo')}
 s.jokers[1].edition={negative=true,type='negative'}
 s.jokers[3].ability.rental=true;s.jokers[3].sell_cost=1
 s.jokers[3].edition={polychrome=true,type='polychrome',x_mult=1.5}
 s.shop_jokers={j('j_blueprint','rental-copy434')};s.shop_jokers[1].ability.rental=true;s.shop_jokers[1].cost=1
 return s
end
local s=state();local before=m.snapshot.fingerprint(s)
local result=m.decision.run(s,m,nil,{prepared_scoring=false})
check(result.action and result.action.kind=='sell'and result.action.index==3,'sell expendable rental to fund copy reserve: '..tostring(result.action and result.action.kind))
check(result.evaluations<=50000 and result.strategy.copy_acquisition_review.complete,'complete focused supported acquisition')
local compact=dofile('Brainstorm/Advisor/player_journal.lua').compact_copy_death_review(result)
local direct=compact.focused_direct.candidates[1]
check(direct.reason=='copy_cash_reserve_shortfall'and direct.cash_after==3 and direct.required_reserve==6,'direct affordability reports real reserve gap')
local pending=assert(m.shop_sequences.prepare_commitment(s,result.strategy,m))
local sold=assert(m.shop_sequences.transition(s,result.action,m))
sold.shop_sequence_commitment=m.shop_sequences.observe_commitment(sold,pending,m)
local fresh=m.decision.run(sold,m,nil,{prepared_scoring=false})
check(fresh.action and fresh.action.kind=='buy'and fresh.action.index==1,'fresh physical sale permits actual Blueprint buy')
local bought=assert(m.shop_sequences.transition(sold,fresh.action,m))
check(bought.dollars==4 and #bought.jokers==5 and bought.jokers[5].key=='j_blueprint','exact cash, capacity and new copy endpoint')
check(m.snapshot.fingerprint(s)==before,'proposal never mutates observed state')
for _,case in ipairs({'funded_direct','eternal_rental','pinned_rental','insufficient_cash','incomplete_budget','ordinary_offer'})do
 local x=state();local opts={prepared_scoring=false}
 if case=='funded_direct'then x.dollars=20
 elseif case=='eternal_rental'then x.jokers[3].ability.eternal=true
 elseif case=='pinned_rental'then x.jokers[3].pinned=true
 elseif case=='insufficient_cash'then x.dollars=0
 elseif case=='incomplete_budget'then opts.shop_scoring={max_evaluations=1}
 elseif case=='ordinary_offer'then x.shop_jokers[1]=j('j_joker');x.shop_jokers[1].cost=1 end
 local r=m.decision.run(x,m,nil,opts)
 if case=='funded_direct'then check(r.action.kind=='buy','funded direct copy needs no sale')
 elseif case=='insufficient_cash' or case=='ordinary_offer' then
  check(not(r.strategy and r.strategy.copy_reserve_funding),'no invalid focused-copy funding '..case)
 else check(r.action.kind~='sell'or r.action.index~=3,'no invalid reserve-funded sale '..case)end
end
print('Copy reserve434: '..n..' manufactured assertions passed')
