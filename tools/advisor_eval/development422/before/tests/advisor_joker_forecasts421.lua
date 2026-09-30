local P='Brainstorm/Advisor/';local F=dofile('tests/fixtures/retained418.lua')
local C=dofile(P..'conditional_value.lua');local Y=dofile(P..'synergies.lua');local S=dofile(P..'strategy.lua');S.synergies=Y
local n=0;local function check(x,t)n=n+1;assert(x,t)end
local function state()
 local s=F.state();s.phase='shop';s.ante=2;s.hands_left=2;s.next_blind={key='bl_big',ante=2}
 s.round_resets={hands=4,discards=3,reroll_cost=5};s.current_round={reroll_cost=5,reroll_cost_increase=0,free_rerolls=0}
 s.jokers={F.joker('j_hologram','Hologram',{x_mult=2})};s.dollars=40
 s.shop_forecast={slots=2,rental_rate=3,blind_rewards={Small=0,Big=0,Boss=0},rates={joker=1,tarot=0,planet=0,playing=0,spectral=0},
  pools={{{key='j_hanging_chad',rarity=1,cost=4}},{{key='j_hack',rarity=2,cost=6}},{{key='j_wee',rarity=3,cost=8}}}}
 s.modifiers={no_interest=true,no_extra_hand_money=true};return s
end
local s=state();local delayed=F.joker('j_delayed_grat','Delayed Gratification',{extra=2})
local r={supported=true,status='sampled_safe',hands=4,discards=3}
check(C.assess(s,delayed,{base_value=55,readiness=r}).cash_end_round==0,'teacher safe opener is not a no-discard policy')
local ordinary=F.copy(s);ordinary.teacher_profile=nil
check(C.assess(ordinary,delayed,{base_value=55,readiness=r}).cash_end_round==6,'generic no-discard control keeps legal payout')
local dna=F.joker('j_dna','DNA',{})
check(Y.forecast(s,dna).owned_bonus==35,'ordinary spare-hand opportunity')
s.next_blind.key='bl_needle';check(Y.forecast(s,dna).owned_bonus==0,'Needle removes false spare hand')
s.jokers[2]=F.joker('j_chicot','Chicot',{});check(Y.forecast(s,dna).owned_bonus==35,'Chicot restores real spare hands')
s=state();local candidate=F.joker('j_wee','Wee Joker',{extra={chips=0},perishable=true,perish_tally=1});candidate.cost=8
local h=Y.opportunities(s,candidate,4);check(h.future_shops==0 and #h.stages==1 and h.rerolls>0,'tally1 piece allows current partner searches only')
candidate.ability.perishable=false
for _,spec in ipairs({{'j_golden','Golden Joker',{extra=4},4},{'j_rocket','Rocket',{extra={dollars=7,increase=2}},7},{'j_cloud_9','Cloud 9',{extra=1},2}})do
 s=state();s.playing_cards={F.card('n1',9),F.card('n2',9),F.card('other',13)};local j=F.joker(spec[1],spec[2],spec[3]);j.ability.perishable=true;j.ability.perish_tally=1;s.jokers[2]=j
 check(Y.opportunities(s,candidate,4).projected_income==0,'expiration precedes cashout: '..spec[1])
 j.ability.perish_tally=2;check(Y.opportunities(s,candidate,4).projected_income==spec[4],'exactly one surviving payout: '..spec[1])
end
s=state();s.jokers[2]=F.joker('j_egg','Egg',{extra=3,perishable=true,perish_tally=1})
check(Y.opportunities(s,candidate,4).resale_growth==3,'Egg growth precedes expiration; no cash conflation')
s=state();s.jokers={F.joker('j_wee','Wee Joker',{extra={chips=0}}),F.joker('j_hanging_chad','Hanging Chad',{extra=2})}
local rich=Y.forecast(s,s.jokers[1]);local unknown=F.copy(s);unknown.shop_forecast=nil;local poor=Y.forecast(unknown,unknown.jokers[1])
check(#rich.existing==1 and #rich.potential==1 and rich.owned_bonus==poor.owned_bonus,'missing Hack is not owned synergy')
check(S.shop_sequence_api.build_value(s)==S.shop_sequence_api.build_value(unknown),'retained row cannot acquire speculative value from future metadata')
print('Joker forecasts421: '..n..' checks passed')
