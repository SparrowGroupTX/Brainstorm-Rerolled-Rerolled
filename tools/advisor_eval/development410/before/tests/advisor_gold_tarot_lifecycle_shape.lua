-- Manufactured raw-card shapes for preserved constructor/update/copy semantics.
-- Never invokes original Card functions, game callbacks, source code or RNG.
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local H,S=F.Hold,F.Snapshot;S.gold_tarot_hold=H
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function center(key,name,effect,order,config)
 return {key=key,name=name,effect=effect,order=order,config=config,set='Tarot',consumeable=true,cost=3}
end
local centers={
 center('c_empress','The Empress','Enhance',4,{mod_conv='m_mult',mod_num=2,max_highlighted=2}),
 center('c_sun','The Sun','Suit Conversion',20,{suit_conv='Hearts',mod_num=3,max_highlighted=3}),
 center('c_hanged_man','The Hanged Man','Card Removal',13,{remove_card=true,mod_num=2,max_highlighted=2}),
 center('c_temperance','Temperance','Joker Payout',15,{extra=50}),
 center('c_wheel_of_fortune','The Wheel of Fortune','Round Bonus',11,{extra=4}),
 center('c_judgement','Judgement','Random Joker',21,{}),
}
local function raw(c,id)
 -- Card:init supplies a plain empty front/base for a nonplaying Tarot.
 local card=F.raw('c_hermit',id,false)
 card.config.center=c
 card.params={bypass_discovery_center=true,bypass_discovery_ui=false,discover=true,bypass_back={x=0,y=2}}
 card.pinned=nil
 -- Card:set_ability holds the center config by reference for consumeables.
 card.ability.name,card.ability.effect,card.ability.order=c.name,c.effect,c.order
 card.ability.extra=S.copy(c.config.extra);card.ability.consumeable=c.config
 if c.key=='c_temperance' then card.ability.money=17 end
 return card
end
local function observe(card)
 G={P_CENTERS={[card.config.center.key]=card.config.center}}
 return S.card(card)
end
math.random=function()error('No RNG in lifecycle-shape fixture')end;pseudorandom=math.random;pseudoseed=math.random
for i,c in ipairs(centers)do
 local card=raw(c,1000+i);local before=S.fingerprint(card)
 local observed=observe(card)
 check(observed.tarot_hold_source.supported,'source-shaped constructor and bypass_back admitted for '..c.key)
 eq(S.fingerprint(card),before,'capture does not mutate the raw shape')
 eq(observed.pinned,false,'unset source pin is normalized by Snapshot')
 eq(observed.tarot_hold_source.params.bypass_back.y,2,'nested back presentation data survives the certificate')
 -- Card:update may assign consumeable.mod_num; because constructor stores a
 -- shared config table, the source center and ability must still agree.
 if c.config.max_highlighted then
  card.ability.consumeable.mod_num=math.min(5,c.config.max_highlighted)
  eq(card.ability.consumeable,c.config,'ordinary source update retains the shared config relation')
  check(observe(card).tarot_hold_source.supported,'settled use-only update remains certifiable')
 end
 if c.key=='c_temperance' then
  for _,money in ipairs({0,50})do
   card.ability.money=money
   local refreshed=observe(card)
   check(refreshed.tarot_hold_source.supported,'fresh Temperance display refresh remains certifiable')
   eq(refreshed.tarot_hold_source.ability.money,money,'certificate records the fresh public display without spending it')
  end
  card.ability.money=17
 end
 -- A new Perkeo copy starts nonplaying and then inherits the original params,
 -- base and every ability field. Manufacture that shape without invoking copy.
 local copied=raw(c,2000+i)
 copied.ability=S.copy(card.ability);copied.base=S.copy(card.base)
 copied.params=card.params;copied.params.playing_card=nil
 copied.pinned=card.pinned;copied.debuff=card.debuff
 copied.edition={negative=true,type='negative'};copied.cost=8;copied.sell_cost=4
 local negative=observe(copied)
 check(negative.tarot_hold_source.supported,'Negative copied shape with inherited back params admits '..c.key)
 local s=F.state();s.consumeables={observed,negative};s.consumable_limit=2
 local receipt,why=H.certify(s)
 check(receipt,why or 'whole inventory source/copy pair is closed under further unused copying')
 eq(receipt.inventory_count_before,2,'both original cards are retained')
 eq(receipt.inventory_count_after,4,'the manufactured Perkeo/Brainstorm row adds two symbolic copies')
 eq(receipt.free_slots_after,0,'Negative copying preserves exact full capacity')
 eq(receipt.generated_identity,'unresolved','copy identity remains unobserved')
 eq(receipt.generated_resale_credit,0,'no unobserved copied prices are used')
 eq(receipt.first_hand_consumable_actions,0,'all source use effects remain unexecuted')
 -- Capture and receipt data are detached even though original-source copies
 -- share their original params table. Neither may acquire later mutations.
 card.params.bypass_back.x=1
 eq(observed.tarot_hold_source.params.bypass_back.x,0,'public certificate owns its nested params data')
 eq(receipt.inventory_before[1].tarot_hold_source.params.bypass_back.x,0,'whole-inventory receipt remains detached')
 local stale=S.copy(observed);stale.ability.extra_value=4
 local invalid=F.state();invalid.consumeables={stale};invalid.consumable_limit=1
 check(not H.certify(invalid),'changed public ability cannot reuse the old certificate')
 local mutation=raw(c,3000+i);mutation.ability.h_size=1
 check(not observe(mutation).tarot_hold_source.supported,'source constructor with copied hand-size effect still rejects')
 mutation=raw(c,4000+i);mutation.ability.consumeable=S.copy(mutation.ability.consumeable)
 mutation.ability.consumeable.unexplained=true
 check(not observe(mutation).tarot_hold_source.supported,'unmatched use config cannot reuse a live center proof')
end
print('advisor_gold_tarot_lifecycle_shape: '..checks..' manufactured constructor/update/copy checks')
