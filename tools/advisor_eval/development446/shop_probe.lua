local T=dofile('tests/fixtures/shop433.lua');local F,m,j=T.F,T.m,T.joker
local s=T.state();s.dollars=13;s.rental_rate=3;s.joker_limit=5
s.jokers={F.j('j_yorick'),F.j('j_perkeo'),j('j_shortcut'),j('j_abstract')}
s.jokers[1].ability.x_mult=8
s.jokers[3].ability.rental=true;s.jokers[3].sell_cost=2
s.jokers[4].ability.rental=true;s.jokers[4].ability.eternal=true
s.shop_jokers={j('j_brainstorm','fund446')};s.shop_jokers[1].cost=15;s.shop_jokers[1].ability.eternal=true
local r=m.decision.run(s,m,nil,{prepared_scoring=false})
local d=r.strategy and r.strategy.copy_acquisition_review
local function walk(x,path)
 if type(x)~='table'then return end
 if x.reason or x.action then print(path,x.reason,x.action and x.action.kind,x.action and x.action.index,x.merit,x.cash_after,x.required_reserve)end
 for k,v in pairs(x)do if type(v)=='table'then walk(v,path..'.'..tostring(k))end end
end
walk(r,'result')
