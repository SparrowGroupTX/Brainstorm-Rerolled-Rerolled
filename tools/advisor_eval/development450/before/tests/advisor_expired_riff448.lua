-- Invented uniform-rank shop; no captured policy or scorer replay.
local T=dofile('tests/fixtures/shop433.lua');local F,m,j=T.F,T.m,T.joker
m.shop_scoring.blind_start=dofile('Brainstorm/Advisor/blind_start.lua')
if SHOP448_PATH then
 local old=m.shop_scoring;m.shop_scoring=dofile(SHOP448_PATH)
 for k,v in pairs(old)do if type(v)=='table'then m.shop_scoring[k]=v end end
end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=T.state();s.dollars=40;s.rental_rate=3;s.ante=3
 s.next_blind={key='bl_big',name='Big Blind',chips=900,ante=3}
 s.jokers={j('j_abstract'),F.j('j_yorick'),j('j_riff_raff'),j('j_square'),F.j('j_perkeo')}
 s.jokers[2].ability.x_mult=4
 s.jokers[3].ability.perishable=true;s.jokers[3].ability.perish_tally=0;s.jokers[3].debuff=true
 s.jokers[3].sell_cost=1
 s.shop_jokers={j('j_brainstorm','copy448')};s.shop_jokers[1].cost=1;s.shop_jokers[1].ability.rental=true
 return s
end
local function preview(s)
 local fingerprint=m.snapshot.fingerprint(s)
 local ctx=m.shop_scoring.new(s,m.scoring,nil,{max_evaluations=50000})
 local r=ctx:readiness(s)
 check(m.snapshot.fingerprint(s)==fingerprint,'preview preserves public input')
 check(ctx.evaluations<=50000,'shop ceiling respected')
 return r,ctx
end
local s=state();local r,ctx=preview(s)
if EXPECT_BASELINE448 then
 check(not r.supported and r.reason=='Blind-start Joker changes are left to the existing strategy.','old preview rejects expired generator')
 check(ctx.evaluations==0,'old admission rejects before scoring')
 local d=m.decision.run(s,m,nil,{prepared_scoring=false})
 check(not d.action or d.action.kind~='sell','old Decision does not open copy slot')
 print('Baseline448: '..n..' checks; expired Riff-raff blocks copy comparison');return
end
check(r.supported,'expired Riff-raff preview supported')
check(r.samples==4,'complete four opening worlds')
local pure=m.snapshot.fingerprint(s)
local d=m.decision.run(s,m,nil,{prepared_scoring=false})
check(m.snapshot.fingerprint(s)==pure,'Decision does not modify input')
check(d.action.kind=='sell'and d.action.index==3,'sell expired Riff-raff for copy')
local sold=assert(m.shop_sequences.transition(s,d.action,m))
check(#sold.jokers==4 and sold.dollars==41,'real sale frees one slot and pays one dollar')
local fresh=m.decision.run(sold,m,nil,{prepared_scoring=false})
check(fresh.action.kind=='buy'and fresh.action.index==1,'fresh settled shop buys Brainstorm')
local bought=assert(m.shop_sequences.transition(sold,fresh.action,m))
check(#bought.jokers==5 and bought.jokers[5].key=='j_brainstorm'and bought.dollars==40,'physical copy purchase funded')
check(bought.jokers[5].ability.rental and bought.dollars>=3,'rental obligation retained')
-- Replace only the permanently inactive callback identity with an independently
-- inert, debuffed Joker. Physical position, editions, value and rent stay exact.
for _,mode in ipairs({'plain','foil','holo','polychrome','negative','rental','blueprint','brainstorm'})do
 local x=state();local dead=x.jokers[3]
 if mode=='foil'then dead.edition={foil=true,chips=50,type='foil'}
 elseif mode=='holo'then dead.edition={holo=true,mult=10,type='holo'}
 elseif mode=='polychrome'then dead.edition={polychrome=true,x_mult=1.5,type='polychrome'}
 elseif mode=='negative'then dead.edition={negative=true,type='negative'};x.joker_limit=6
 elseif mode=='rental'then dead.ability.rental=true
 elseif mode=='blueprint'then x.jokers[2]=F.j('j_blueprint')
 elseif mode=='brainstorm'then x.jokers[1],x.jokers[3]=dead,F.j('j_brainstorm');dead=x.jokers[1]end
 local y=F.copy(x);local slot=mode=='brainstorm'and 1 or 3
 y.jokers[slot].key='j_joker';y.jokers[slot].name='Joker'
 y.jokers[slot].ability.name='Joker';y.jokers[slot].ability.effect='Mult'
 y.jokers[slot].ability.extra=nil;y.jokers[slot].ability.mult=4
 local xhash,yhash=m.snapshot.fingerprint(x),m.snapshot.fingerprint(y)
 local c=m.shop_scoring.new(x,m.scoring,nil,{max_evaluations=50000})
 local comparison=c:compare(x,y)
 check(comparison and comparison.samples==4 and comparison.common_worlds,'complete common worlds: '..mode)
 check(comparison.ratio==1 and comparison.before_mean==comparison.after_mean,'inactive identity cannot add score: '..mode)
 check(m.snapshot.fingerprint(x)==xhash and m.snapshot.fingerprint(y)==yhash,'both endpoints unchanged: '..mode)
 check(c.evaluations>0 and c.evaluations<=50000,'all comparison work charged: '..mode)
 -- Source copy semantics stop on a debuffed target. A huge live Joker behind
 -- it must not receive either copy route by skipping the physical dead slot.
 if mode=='blueprint'or mode=='brainstorm'then
  local hand=F.copy(x);hand.phase='hand';hand.blind={disabled=true};hand.hand={F.card('independent448',7,'Clubs')}
  hand.hands={['High Card']={chips=5,mult=1,level=1,played=0}}
  hand.jokers=mode=='blueprint'and {F.j('j_blueprint'),F.copy(dead),F.j('j_yorick')}or
   {F.copy(dead),F.j('j_brainstorm'),F.j('j_yorick')}
  hand.jokers[3].ability.x_mult=4
  local value=m.scoring.score(hand,{1})
  check(value.score==48,'independent (5+7)*1*4; copy cannot jump expired slot: '..mode)
 end
end
local negatives={
 {'active',function(x)x.debuff=false;x.ability.perish_tally=5 end},
 {'temporary debuff',function(x)x.ability.perishable=nil;x.ability.perish_tally=nil end},
 {'live tally',function(x)x.ability.perish_tally=1 end},
 {'missing tally',function(x)x.ability.perish_tally=nil end},
 {'fractional tally',function(x)x.ability.perish_tally=-.5 end},
 {'negative tally',function(x)x.ability.perish_tally=-1 end},
 {'text tally',function(x)x.ability.perish_tally='0'end},
 {'false expiry',function(x)x.ability.perishable=false end},
 {'numeric expiry',function(x)x.ability.perishable=1 end},
 {'perma only',function(x)x.ability.perishable=nil;x.ability.perma_debuff=true end},
 {'inconsistent debuff',function(x)x.debuff=false end},
 {'slicing',function(x)x.getting_sliced=true end},
 {'wrong name',function(x)x.name='Other'end},
 {'wrong ability',function(x)x.ability.name='Other'end},
 {'wrong set',function(x)x.ability.set='Other'end},
 {'modified generation',function(x)x.ability.extra=3 end},
 {'modified effect',function(x)x.ability.effect='Other'end},
 {'modified score',function(x)x.ability.mult=4 end},
 {'unknown field',function(x)x.ability.mod_callback=1 end},
 {'malformed rental',function(x)x.ability.rental=1 end},
 {'nonfinite metadata',function(x)x.ability.order=math.huge end},
 {'unknown generator',function(x)x.key='j_mod_generator'end},
 {'Madness',function(x)x.key='j_madness';x.name='Madness';x.ability.name='Madness'end}}
for _,field in ipairs({'face_down','unknown','identity_unknown','identity_redacted','concealed'})do
 negatives[#negatives+1]={field,function(x)x[field]=true end}
end
negatives[#negatives+1]={'facing',function(x)x.facing='back'end}
for _,case in ipairs(negatives)do
 local x=state();case[2](x.jokers[3]);local value,c=preview(x)
 check(not value.supported and c.evaluations==0,'unsupported expiry cannot bypass startup: '..case[1])
end
for _,restriction in ipairs({'eternal','pinned','negative'})do
 local x=state();local opts={prepared_scoring=false}
 if restriction=='eternal'then x.jokers[3].ability.eternal=true
 elseif restriction=='pinned'then x.jokers[3].pinned=true
 elseif restriction=='negative'then x.jokers[3].edition={negative=true,type='negative'}
 end
 local action=m.decision.run(x,m,nil,opts).action
 check(not action or action.kind~='sell'or action.index~=3,'protected or unfunded sale remains refused: '..restriction)
end
do
 local x=state();local y=F.copy(x);table.remove(y.jokers,3)
 local c=m.shop_scoring.new(x,m.scoring,nil,{max_evaluations=1})
 local comparison=c:compare(x,y)
 check(not comparison and c.truncated and c.evaluations<=1,'one-call budget cannot publish a partial comparison')
 local poor=state();poor.dollars=0
 local sale=m.decision.run(poor,m,nil,{prepared_scoring=false})
 -- Existing harmless expired-slot cleanup is separate from a certified funded
 -- copy route. It is not evidence that the rental purchase is affordable.
 if sale.action and sale.action.kind=='sell'and sale.action.index==3 then
  poor=assert(m.shop_sequences.transition(poor,sale.action,m))
 end
 local next_action=m.decision.run(poor,m,nil,{prepared_scoring=false}).action
 check(not next_action or next_action.kind~='buy','insufficient real rental reserve cannot fund copy purchase')
end
print('Expired Riff448: '..n..' manufactured assertions passed')
