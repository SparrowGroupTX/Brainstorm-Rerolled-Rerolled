-- Invented uniform-rank deck and rental funding endpoints, never a run replay.
local T=dofile('tests/fixtures/shop433.lua');local F,m,j=T.F,T.m,T.joker
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state(cash)
 local s=T.state();s.dollars=cash;s.rental_rate=3;s.joker_limit=5
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),j('j_shortcut'),j('j_abstract')}
 s.jokers[1].ability.x_mult=8
 s.jokers[3].ability.rental=true;s.jokers[3].sell_cost=1
 s.jokers[4].ability.rental=true;s.jokers[4].ability.eternal=true
 s.shop_jokers={j('j_brainstorm','fund446')};s.shop_jokers[1].cost=15;s.shop_jokers[1].ability.eternal=true
 return s
end
local s=state(14);local hash=m.snapshot.fingerprint(s)
local r=m.decision.run(s,m,nil,{prepared_scoring=false})
check(r.action.kind~='sell','do not liquidate first for an unqualified follow-up purchase')
local found
for _,e in ipairs(r.shop_diagnostics.replacements.candidates)do
 if e.sale_index==3 and e.offer_index==1 then found=e end
end
check(found and found.merit>=26 and found.reason=='copy_funding_reserve_shortfall',
 'high original-row merit cannot bypass the final purchase reserve')
check(found.cash_after==0 and found.required_reserve==3 and found.reserve_shortfall,'receipt identifies surviving rental obligation')
check(m.snapshot.fingerprint(s)==hash,'public input remains unchanged')
local funded=state(17)
local sale=m.decision.run(funded,m,nil,{prepared_scoring=false})
check(sale.action.kind=='sell' and sale.action.index==3,'adequately funded rental removal remains available')
local pending=assert(m.shop_sequences.prepare_commitment(funded,sale.strategy,m))
local sold=assert(m.shop_sequences.transition(funded,sale.action,m))
sold.shop_sequence_commitment=m.shop_sequences.observe_commitment(sold,pending,m)
local fresh=m.decision.run(sold,m,nil,{prepared_scoring=false})
check(fresh.action.kind=='buy' and fresh.action.index==1,'fresh settled sale reaches the actual copy purchase')
local bought=assert(m.shop_sequences.transition(sold,fresh.action,m))
check(bought.dollars==3 and bought.jokers[#bought.jokers].key=='j_brainstorm','purchase retains the real remaining rental reserve')
for _,cash in ipairs({14,17})do
 local x=state(cash);x.bankrupt_at=-20;x.jokers[4]=j('j_credit_card')
 x.jokers[4].ability.rental=true;x.jokers[4].ability.eternal=true
 local a=m.decision.run(x,m,nil,{prepared_scoring=false})
 if cash==14 then
  check(a.action.kind~='sell','borrowing capacity never masquerades as remaining rental cash')
  local e
  for _,c in ipairs(a.copy_acquisition_diagnostics.replacements.candidates)do if c.sale_index==3 then e=c end end
  check(e and e.reason=='copy_funding_reserve_shortfall' and e.required_reserve==3,'Credit Card shortfall uses the direct raw-cash predicate')
 else
  check(a.action.kind=='sell' and a.action.index==3,'actual funded Credit Card endpoint remains eligible')
  local y=assert(m.shop_sequences.transition(x,a.action,m))
  local b=m.decision.run(y,m,nil,{prepared_scoring=false})
  check(b.action.kind=='buy','funded borrowing-row sale still reaches the fresh purchase')
 end
end
for _,case in ipairs({'eternal','pinned','negative','budget'})do
 local x=state(17);local opts={prepared_scoring=false}
 if case=='eternal'then x.jokers[3].ability.eternal=true
 elseif case=='pinned'then x.jokers[3].pinned=true
 elseif case=='negative'then x.jokers[3].edition={negative=true,type='negative'}
 else opts.shop_scoring={max_evaluations=1}end
 local a=m.decision.run(x,m,nil,opts).action
 check(not a or a.kind~='sell' or a.index~=3,'protected/incomplete funding not selected: '..case)
end
print('Copy funding446: '..n..' manufactured assertions passed')
