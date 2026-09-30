local Value=dofile('Brainstorm/Advisor/conditional_value.lua')
local copy=dofile('Brainstorm/Advisor/snapshot.lua').copy
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(key,extra) return {key=key,cost=4,ability={set='Joker',extra=extra}} end
local function state()
  return {phase='shop',dollars=4,jokers={},consumeables={},playing_cards={},ante=2,win_ante=8,
    next_blind={key='bl_small',chips=800},round_resets={hands=1,discards=6},modifiers={}}
end
local safe={supported=true,status='sampled_safe',hands=1,discards=6,samples=4,
  opening_hands={'Pair','Pair','Pair','Pair'},opening_sizes={2,2,2,2}}
local deficit={supported=true,status='sampled_deficit',hands=1,discards=6,samples=4,
  requires_discards=true,opening_hands={'Straight','Straight','Straight','Straight'}}
local function assess(s,j,r,base,cost)
  return Value.assess(s,j,{readiness=r,base_value=base or 55,purchase_cost=cost})
end

local s=state();local delayed=joker('j_delayed_grat',2)
local low=assess(s,delayed,deficit)
equal(low.cash_before_blind,0,'cashout cannot finance the current shop')
equal(low.cash_end_round,0,'a scoring deficit does not budget conditional retained-discard cash')
equal(low.rating,0,'do not spend last money on untriggered income')
check(low.discard_conflict and low.reason:find('does not prove',1,true),'sampled deficit is not proof discards are required')
local high=assess(s,delayed,safe)
equal(high.cash_end_round,12,'safe no-discard finish retains all six actual discards')
check(high.rating>=55 and high.payback_rounds==1,'worthwhile safely-ahead income remains attractive')
check(high.cash_before_blind==0 and high.timing=='cashout_after_clear','do not move end-round cash earlier')
local uncertain=assess(s,delayed,{supported=false,status='unsupported'})
check(uncertain.cash_end_round>0 and uncertain.cash_end_round<high.cash_end_round,'unknown trigger receives explicitly bounded heuristic utility')
check(uncertain.reason:find('heuristic',1,true),'uncertain trigger is disclosed')
s.next_blind={key='bl_water',boss=true};equal(assess(s,delayed,safe).cash_end_round,0,'Water removes the retained discards')
s.jokers={joker('j_chicot')};equal(assess(s,delayed,safe).cash_end_round,12,'Chicot preserves discards against Water')
s.next_blind={key='bl_small'};s.jokers={joker('j_burglar')}
equal(assess(s,delayed,safe).cash_end_round,0,'Burglar removes the retained discards')

s=state();local golden=joker('j_golden',4)
local regular=assess(s,golden,safe)
equal(regular.cash_end_round,4,'Golden payout')
equal(regular.payback_rounds,1,'one-round income payback')
golden.ability.rental=true;s.rental_rate=3
local rental=assess(s,golden,safe)
equal(rental.net_cash,1,'actual rental is subtracted from payback cash')
equal(rental.payback_rounds,4,'rental delays recovery of purchase cost')
check(rental.rating<regular.rating,'payback beyond bounded horizon lowers income value')
s.rental_rate=4;equal(assess(s,golden,safe).payback_rounds,nil,'non-positive rental return has no payback')
golden.ability.rental=false;golden.ability.perishable=true;golden.ability.perish_tally=1
equal(assess(s,golden,safe).cash_end_round,0,'perishable expires before cashout')
golden.ability.perish_tally=2
equal(assess(s,golden,safe).payout_rounds,1,'perishable provides only its real remaining payout')
golden.debuff=true;equal(assess(s,golden,safe).cash_end_round,0,'debuffed income cannot pay')
golden.debuff=false;golden.ability.perishable=false
golden.ability.perma_debuff=true;equal(assess(s,golden,safe).cash_end_round,0,'permanently debuffed income cannot pay')
golden.ability.perma_debuff=false
s.dollars=5
equal(assess(s,golden,safe).purchase_interest_loss,1,'purchase crosses current interest threshold')
s.modifiers.no_interest=true
equal(assess(s,golden,safe).purchase_interest_loss,0,'disabled interest has no opportunity cost')
s.phase='pack';equal(assess(s,golden,safe).purchase_cost,0,'revealed pack choice is free')
s.phase='shop';s.jokers={golden};equal(assess(s,golden,safe).purchase_cost,0,'owned row valuation is not another purchase')

s=state();s.next_blind={key='bl_plant',boss=true}
local rocket=joker('j_rocket',{dollars=1,increase=2})
equal(assess(s,rocket,safe).cash_end_round,3,'Rocket grows before boss cashout')
s.next_blind={key='bl_small'};equal(assess(s,rocket,safe).cash_end_round,1,'no imaginary boss increment on Small')
local cloud=joker('j_cloud_9',2)
s.playing_cards={{rank=9},{rank=9,debuff=true},{rank=9,enhancement='m_stone'},{rank=8}}
equal(assess(s,cloud,safe).cash_end_round,4,'Cloud9 uses current rank tally excluding Stone')
s.playing_cards=nil;check(not assess(s,cloud,safe).supported,'Cloud9 missing deck is explicit')
local satellite=joker('j_satellite',2)
s.consumeable_usage={a={set='Planet',count=10},b={set='Planet',count=1},c={set='Tarot',count=1}}
equal(assess(s,satellite,safe).cash_end_round,4,'Satellite counts distinct Planets rather than activations')
s.consumeable_usage=nil;check(not assess(s,satellite,safe).supported,'Satellite missing history is explicit')
local moon=joker('j_to_the_moon',1)
s.dollars=10;equal(assess(s,moon,safe).cash_end_round,1,'Moon uses post-purchase interest thresholds')
s.dollars=4;equal(assess(s,moon,safe).cash_end_round,0,'Moon cannot bootstrap interest from later cashout income')
s.dollars=25;s.modifiers.no_interest=true
equal(assess(s,moon,safe).cash_end_round,0,'Moon cannot create disabled interest')
s.modifiers.no_interest=nil
equal(Value.assess(s,moon,{readiness=safe,base_value=50,no_interest=true}).cash_end_round,0,'caller legacy no-interest rule is preserved')

s=state();local gift=joker('j_gift',1);s.jokers={joker('j_swashbuckler'),joker('j_egg',3)}
s.consumeables={{key='c_temperance'}}
local gift_safe=assess(s,gift,safe,72)
equal(gift_safe.resale_growth,4,'Gift counts real owned cards plus incoming Joker')
equal(gift_safe.cash_end_round,0,'resale growth is not liquid income')
equal(gift_safe.rating,72,'preserve safe existing Gift/Swashbuckler/Temperance valuation')
check(assess(s,gift,deficit,72).rating<72,'resale growth after danger is discounted')
local egg=joker('j_egg',3);egg.ability.perishable=true;egg.ability.perish_tally=1
equal(assess(s,egg,safe).resale_growth,3,'resale grows before perishable callback unlike cashout payout')

for _,key in ipairs({'j_trousers','j_runner','j_square','j_green_joker','j_constellation','j_hologram','j_red_card'}) do
  local growth=joker(key,{chips=0});growth.ability.mult=0;growth.ability.x_mult=1
  equal(assess(s,growth,safe,58).adjustment,0,key..' safe growth investment is preserved')
  check(assess(s,growth,deficit,58).adjustment<0,key..' unscaled growth is not a next-blind rescue by itself')
  growth.ability.mult=20;growth.ability.extra.chips=120;growth.ability.x_mult=3
  equal(assess(s,growth,deficit,58).adjustment,0,key..' mature scoring value is preserved')
end
local constellation=joker('j_constellation',0.1);constellation.ability.x_mult=1
s.consumeables={{key='c_earth',ability={set='Planet'}}}
local available=assess(s,constellation,deficit,58)
equal(available.opportunities,1,'owned Planet is a timely available growth opportunity')
s.consumeables={}
check(available.adjustment>assess(s,constellation,deficit,58).adjustment,'timely available growth is less penalized')
local square=joker('j_square',{chips=0});local four=copy(safe);four.opening_sizes={4,2,4,2}
equal(assess(s,square,four).opening_trigger_samples,2,'Square counts actual four-card sample plays only')
for _,key in ipairs({'j_perkeo','j_yorick','j_burnt','j_modded_unknown'}) do
  equal(assess(s,joker(key),deficit),nil,key..' is outside this bounded forecast')
end
for _,key in ipairs({'j_business','j_faceless','j_todo_list','j_reserved_parking','j_mail','j_rough_gem','j_ticket','j_trading'}) do
  local c=joker(key)
  local guarded=assess(s,c,deficit,55)
  check(not guarded.supported and guarded.cash_during_blind==nil,key..' does not invent unverified trigger cash')
  check(guarded.rating<55,key..' speculative income is discounted during scoring deficit')
  equal(assess(s,c,safe,55).rating,55,key..' worthwhile safe investment retains contextual utility')
end
s.ante=8;s.next_blind={key='bl_final_vessel',boss=true}
equal(assess(s,golden,safe).rating,0,'cash after final boss cannot finance another challenge blind')

local old_random=math.random;math.random=function() error('conditional valuation must not use RNG') end
s=state();local before=copy(s);local once=assess(s,delayed,safe)
local twice=assess(s,delayed,safe)
equal(once.rating,twice.rating,'deterministic valuation')
equal(s.dollars,before.dollars,'cash unchanged');equal(s.round_resets.discards,before.round_resets.discards,'resources unchanged')
math.random=old_random
print('Conditional value checks: '..checks)
