local R=dofile('Brainstorm/Advisor/challenge_route.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local opening={rare_names={j_blueprint='Blueprint'}}
local function card(key,ability) return {key=key,ability=ability or {}} end
local function state()
  return {phase='shop',challenge='c_city_1',ante=2,round=2,skips=1,dollars=12,bankrupt_at=0,joker_limit=5,
    jokers={card('j_yorick'),card('j_perkeo')},shop_jokers={},modifiers={},
    filter_info={challenge_opening=true,challenge_id='c_city_1',legendary_jokers={'j_yorick','j_perkeo'},
      later={target_key='j_blueprint',deadline=4,found_ante=3,shop=1,slot=2,rare_pool_keys={'j_blueprint','j_baron'},
        shop_slots=2,shop_rates={joker_rate=20,tarot_rate=4,planet_rate=4,playing_card_rate=0,spectral_rate=0,edition_rate=1}}},
    shop_forecast={slots=2,pools={[3]={{key='j_blueprint'},{key='j_baron'}}},used={},edition_rate=1,
      rates={joker=20,tarot=4,planet=4,playing=0,spectral=0}}}
end
local function inspect(s,a)return R.inspect(s,a,opening)end
local s=state();local before=Snapshot.fingerprint(s);local r=inspect(s)
check(r.status=='conditional' and not r.history_verified and not r.acquisition_verified and not r.retention_verified,'a native offer never becomes an acquisition/history proof')
check(r.location=='Ante 3, after previous Ante Boss, slot 2','location follows source ante rollover')
check(r.target_name=='Blueprint' and Snapshot.fingerprint(s)==before,'named public diagnostics preserve snapshot')
s.filter_info=nil;check(inspect(s)==nil,'ordinary and v1 runs unchanged')
s=state();s.jokers[3]=card('j_blueprint');r=inspect(s)
check(r.status=='observed_retained' and r.retention_verified and not r.history_verified and not r.acquisition_verified,'simultaneous current active retention distinct from provenance')
s.jokers[1].ability={perishable=true,perish_tally=0};r=inspect(s)
check(not r.retention_verified and #r.inactive==1,'expired Joker cannot satisfy retained engine')
s.jokers[1]=card('j_ceremonial');r=inspect(s)
check(not r.retention_verified and #r.missing==1,'sacrificed Legendary remains missing even with target acquired')
s=state();s.round=0;s.jokers={};r=inspect(s)
check(r.status=='conditional','opening setup does not fabricate attrition')
s=state();s.skips=2;r=inspect(s)
check(r.status=='incompatible_observation' and r.lines[1]:find('no longer applies',1,true),'extra skip withdraws pending forecast')
s=state();s.ante=4;r=inspect(s)
check(r.status=='incompatible_observation','passed offer is not still promised')
s=state();s.shop_forecast.used.j_baron=true;r=inspect(s)
check(r.status=='incompatible_observation','another Rare acquisition changes pool')
s.shop_jokers={{key='j_baron',rarity=3,cost=8}};r=inspect(s)
check(r.status=='conditional','unbought visible stock used flag is a transient exclusion, not an acquisition')
s.jokers[3]=card('j_baron');r=inspect(s)
check(r.status=='incompatible_observation','owned Rare remains excluded despite a same-key visible card')
s=state();s.shop_forecast.used.j_blueprint=true;r=inspect(s)
check(r.status=='incompatible_observation','an unseen target pool exclusion is not ignored')
s=state();s.shop_forecast.pools[3][3]={key='j_dna'};r=inspect(s)
check(r.status=='incompatible_observation','new unlock/profile availability changes forecast')
s=state();s.shop_forecast.rates.planet=32;r=inspect(s)
check(r.status=='incompatible_observation','changed item type rates withdraw forecast')
s=state();s.shop_forecast.special_shop_rules=true;r=inspect(s)
check(r.status=='incompatible_observation','forced shop override withdraws forecast')
s=state();s.jokers[3]=card('j_ring_master');r=inspect(s)
check(r.status=='incompatible_observation','Showman changes route')
s=state();s.phase='pack';s.pack_cards={{key='j_blueprint',cost=8}};s.pack_choices=1;r=inspect(s)
check(r.status=='incompatible_observation' and r.observed_offer.cost==0 and r.observed_offer.affordable,'actual free pack choice reported despite prior forecast invalidation')
s=state();s.shop_jokers={{key='j_blueprint',rarity=3,cost=10}};r=inspect(s)
check(r.observed_offer.affordable and r.observed_offer.immediate_capacity and not r.acquisition_verified,'observed affordable offer still is not ownership')
s.dollars=3;r=inspect(s);check(not r.observed_offer.affordable,'cash cost measured from actual card')
s.joker_limit=2;r=inspect(s)
check(not r.observed_offer.immediate_capacity and #r.observed_offer.replacement_slots==0,'never propose dropping required pair for target')
s.shop_jokers[1].edition={negative=true};r=inspect(s)
check(r.observed_offer.immediate_capacity,'Negative target adds capacity')
s.shop_jokers[1].edition=nil;s.joker_limit=3;s.jokers[3]=card('j_joker');r=inspect(s)
check(r.observed_offer.replacement_slots[1]==3,'legal expendable ordinary replacement remains visible')
s.jokers[3].pinned=true;r=inspect(s)
check(#r.observed_offer.replacement_slots==0,'pinned row member keeps existing strategy sale protection')
s.jokers[3].pinned=nil;s.jokers[3].ability.pinned=true;r=inspect(s)
check(#r.observed_offer.replacement_slots==0,'ability-pinned row member also protected')
s.jokers[3].ability.pinned=nil
s.joker_limit=0;r=inspect(s)
check(#r.observed_offer.replacement_slots==0,'one sale cannot invent capacity after a slot collapse')
s.joker_limit=3
s.jokers[3].edition={negative=true};r=inspect(s)
check(#r.observed_offer.replacement_slots==0,'selling Negative does not release net capacity')
s=state();check(inspect(s,{kind='reroll'}).proposed_action_changes_path,'reroll consequence explained')
check(inspect(s,{kind='skip_blind'}).proposed_action_changes_path,'later skip consequence explained')
s.shop_jokers={{key='j_baron',rarity=3,cost=8},{key='j_joker',rarity=1,cost=2},{key='j_blueprint',rarity=3,cost=10}}
check(inspect(s,{kind='buy',area='shop_jokers',index=1}).proposed_action_changes_path,'other Rare buy warns')
check(not inspect(s,{kind='buy',area='shop_jokers',index=2}).proposed_action_changes_path,'ordinary scoring purchase remains compatible')
check(not inspect(s,{kind='buy',area='shop_jokers',index=3}).proposed_action_changes_path,'actual target purchase remains compatible')
check(inspect(s,{kind='sell',area='jokers',index=1}).proposed_action_changes_path,'pair sale consequence explained')
check(inspect(s,{kind='buy',area='shop_booster',index=1}).proposed_action_changes_path,'pack opening consequence explained')
s.consumeables={{key='c_wraith'},{key='c_ankh'}}
check(inspect(s,{kind='use',area='consumeables',index=1}).proposed_action_changes_path,'Wraith generation consequence explained')
check(inspect(s,{kind='use',area='consumeables',index=2}).proposed_action_changes_path,'Ankh generation consequence explained')
s.phase='pack';s.opening_pack=true;s.pack_cards={{key='c_soul'}}
check(not inspect(s,{kind='choose',area='pack_cards',index=1}).proposed_action_changes_path,'required opening Soul remains compatible')
print('advisor_challenge_route: '..checks..' checks passed')
