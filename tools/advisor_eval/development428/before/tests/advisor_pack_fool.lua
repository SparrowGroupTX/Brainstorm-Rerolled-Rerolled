local Pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
Strategy.consumables=Consumables;Strategy.pack_scoring=Pack
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
local modules={strategy=Strategy,consumables=Consumables,pack_scoring=Pack,shop_scoring=Shop,scoring=Scoring}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local copy=Snapshot.copy
local function fool()
  return {id='pack-fool',key='c_fool',name='The Fool',cost=3,
    ability={set='Tarot',name='The Fool',order=1,consumeable={}}}
end
local function state()
  local s={phase='pack',ante=2,dollars=9,bankrupt_at=0,jokers={},joker_limit=0,
    consumeables={},consumable_limit=2,consumeable_buffer=0,hand={},playing_cards={},deck={},
    hand_size=8,hand_limit=5,hands_played_total=5,hands={Straight={level=2,chips=60,mult=7,played=2}},
    modifiers={},current_round={},round_resets={hands=1,discards=0},probabilities={normal=1},
    last_tarot_planet='c_star',consumeable_usage_total={all=3,tarot=2,planet=1,spectral=0,tarot_planet=3},
    consumeable_usage={c_star={count=1,order=18,set='Tarot'}},
    next_blind={key='bl_big',chips=1200},next_blind_chips=1200,
    shop_forecast={consumable_pool_schema='source_shop_consumables_v1',discount_percent=0,inflation=0,
      consumable_used={c_star=true},tarot_pool={{key='c_star',name='The Star',cost=3,
        source_set='Tarot',source_order=18,source_effect='Suit Conversion',
        source_config={max_highlighted=3,mod_num=3,suit_conv='Diamonds'}}},
      planet_pool={{key='c_saturn',name='Saturn',cost=3,source_set='Planet',source_order=5,
        source_effect='Hand Upgrade',source_config={hand_type='Straight'}}}}}
  for i,rank in ipairs({13,11,10,8,8,7,6,4}) do
    local c={id='fool-pop:'..i,key='c_base',rank=rank,nominal=math.min(rank,10),
      suit=({'Hearts','Spades','Diamonds','Hearts','Clubs','Spades','Diamonds','Diamonds'})[i],ability={}}
    s.hand[i]=c;s.playing_cards[i]=c
  end
  return s
end
local random,randomseed=math.random,math.randomseed
math.random=function() error('Fool projection must not consume global RNG') end
math.randomseed=function() error('Fool projection must not reseed global RNG') end
do
  local s=state();local before=Snapshot.fingerprint(s)
  check(Pack.supports(fool()),'Fool declares its conditional exact projection')
  local after,transition=Pack.project(s,fool(),{},nil,modules)
  check(after and transition.kind=='use_pack_fool','known public identity creates a supported endpoint')
  check(#after.consumeables==1 and after.consumeables[1].key=='c_star','the previous Tarot enters held inventory')
  check(after.last_tarot_planet=='c_fool','the used Fool becomes the next previous-consumable identity')
  check(after.consumeable_usage_total.tarot==3 and after.consumeable_usage_total.tarot_planet==4 and
    after.consumeable_usage_total.all==4 and after.consumeable_usage_total.planet==1,
    'only the used Fool advances Tarot/all counters')
  check(after.consumeable_usage.c_fool.count==1 and after.consumeable_usage.c_fool.set=='Tarot' and
    after.consumeable_usage.c_star.count==1,'generated card is not recorded as used')
  check(after.consumeables[1].edition==nil and after.consumeables[1].cost==3 and
    after.consumeables[1].sell_cost==1 and after.consumeables[1].base_cost==3,
    'generated card is fresh and editionless with ordinary source price and resale')
  check(after.consumeables[1].ability.consumeable.suit_conv=='Diamonds' and
    after.consumeables[1].ability.hands_played_at_create==5,'the observed source config is copied into the generated ability')
  check(after.consumeables[1].nominal==0 and after.consumeables[1].base.nominal==0 and
    after.consumeables[1].base.times_played==0 and not after.consumeables[1].rank,
    'a fresh consumable has the original non-playing base metadata')
  check(transition.inventory_delta==1 and transition.population_delta==0 and transition.copy_used==false,
    'transition explicitly reports inventory generation without a copied effect')
  check(Snapshot.fingerprint(after.hand)==Snapshot.fingerprint(s.hand) and
    Snapshot.fingerprint(after.playing_cards)==Snapshot.fingerprint(s.playing_cards) and
    Snapshot.fingerprint(after.hands)==Snapshot.fingerprint(s.hands) and after.dollars==s.dollars,
    'the copy does not immediately transform cards, level a hand, alter population or pay money')
  check(Snapshot.fingerprint(s)==before,'projection preserves the original snapshot')
  check(Snapshot.fingerprint(after)==Snapshot.fingerprint(Pack.project(s,fool(),{},nil,modules)),
    'fresh projected identity and endpoint repeat deterministically')
end
do
  local s=state();s.consumeables={{id='owned-negative-star',key='c_star',edition={negative=true},
    ability={name='The Star',set='Tarot',consumeable={suit_conv='Diamonds',max_highlighted=3,mod_num=3}}}}
  s.consumable_limit=3
  local after=Pack.project(s,fool(),{},nil,modules)
  check(after and #after.consumeables==2 and after.consumeables[2].key=='c_star',
    'forced source creation permits an owned duplicate despite its used-key exclusion')
  check(after.consumeables[1].edition.negative and not after.consumeables[2].edition and after.consumable_limit==3,
    'Fool preserves the original Negative card and does not copy its edition or capacity')
  s.consumeable_usage.c_fool={count=2,order=1,set='Tarot'}
  check(Pack.project(s,fool(),{},nil,modules).consumeable_usage.c_fool.count==3,
    'existing Fool usage increments without replacing its history')
end
do
  local s=state();s.last_tarot_planet='c_saturn';s.shop_forecast.inflation=2;s.shop_forecast.discount_percent=25
  local after=Pack.project(s,fool(),{},nil,modules)
  check(after.consumeables[1].cost==4 and after.consumeables[1].sell_cost==2,
    'fresh cost uses observed inflation and discounted source floor rounding')
  check(after.hands.Straight.level==2 and after.consumeable_usage_total.planet==1,
    'a generated Planet is held without an invented level-up or Planet use')
  s.jokers={{key='j_astronomer',ability={name='Astronomer',set='Joker'}}}
  after=Pack.project(s,fool(),{},nil,modules)
  check(after.consumeables[1].cost==0 and after.consumeables[1].sell_cost==1,
    'active Astronomer applies the actual free-Planet price and minimum resale')
  s.jokers[1].debuff=true
  check(Pack.project(s,fool(),{},nil,modules).consumeables[1].cost==4,'debuffed Astronomer does not grant a free price')
end
for _,case in ipairs({
  {'missing last identity',function(s,c) s.last_tarot_planet=nil end},
  {'previous Fool',function(s,c) s.last_tarot_planet='c_fool' end},
  {'full held inventory',function(s,c) s.consumable_limit=0 end},
  {'pending generation',function(s,c) s.consumeable_buffer=1 end},
  {'missing public catalog',function(s,c) s.shop_forecast=nil end},
  {'old catalog schema',function(s,c) s.shop_forecast.consumable_pool_schema=nil end},
  {'absent eligible identity',function(s,c) s.shop_forecast.tarot_pool={} end},
  {'explicit banned identity',function(s,c) s.banned_keys={c_star=true} end},
  {'ambiguous identity',function(s,c) s.shop_forecast.tarot_pool[2]=copy(s.shop_forecast.tarot_pool[1]) end},
  {'malformed catalog row',function(s,c) s.shop_forecast.tarot_pool[2]='bad' end},
  {'unknown cost metadata',function(s,c) s.shop_forecast.inflation=nil end},
  {'nonfinite cost',function(s,c) s.shop_forecast.tarot_pool[1].cost=math.huge end},
  {'modified generated hand size',function(s,c) s.shop_forecast.tarot_pool[1].source_config.h_size=1 end},
  {'modified generated discards',function(s,c) s.shop_forecast.tarot_pool[1].source_config.d_size=1 end},
  {'modified Fool targets',function(s,c) c.ability.consumeable.max_highlighted=1 end},
  {'modified Fool type',function(s,c) c.ability.set='Spectral' end},
  {'modified Fool name',function(s,c) c.ability.name='Other effect' end},
  {'debuffed Fool',function(s,c) c.debuff=true end},
  {'unknown catalog order',function(s,c) s.shop_forecast.tarot_pool[1].source_order=nil end},
  {'malformed usage history',function(s,c) s.consumeable_usage.c_fool=1 end},
  {'missing existing usage count',function(s,c) s.consumeable_usage.c_fool={} end},
  {'malformed usage totals',function(s,c) s.consumeable_usage_total='unknown' end},
  {'partial usage totals',function(s,c) s.consumeable_usage_total.all=nil end},
  {'unknown Fool usage order',function(s,c) c.ability.order=nil end},
  {'active Perkeo inventory',function(s,c) s.jokers={{key='j_perkeo',ability={set='Joker',name='Perkeo'}}} end},
  {'copied Perkeo inventory',function(s,c) s.jokers={{key='j_blueprint',ability={set='Joker'}},
    {key='j_perkeo',ability={set='Joker',name='Perkeo'}}} end},
  {'Observatory inventory',function(s,c) s.used_vouchers={v_observatory=true} end},
}) do
  local s,c=state(),fool();case[2](s,c)
  local after,reason=Pack.project(s,c,{},nil,modules)
  check(not after and type(reason)=='string',case[1]..' remains explicit unsupported')
end

do
  local s=state();s.last_tarot_planet='c_temperance'
  s.shop_forecast.tarot_pool={{key='c_temperance',name='Temperance',cost=3,source_set='Tarot',
    source_order=15,source_effect='Joker Sell Value',source_config={extra=50}}}
  s.jokers={{key='j_egg',sell_cost=60,ability={set='Joker',name='Egg'}},
    {key='j_joker',sell_cost=2,debuff=true,ability={set='Joker',name='Joker'}}}
  local after=Pack.project(s,fool(),{},nil,modules)
  check(after and after.consumeables[1].ability.money==50 and after.dollars==9,
    'generated Temperance refreshes its capped payout without paying it or altering cash')
  s.jokers[1].sell_cost=6
  check(Pack.project(s,fool(),{},nil,modules).consumeables[1].ability.money==8,
    'Temperance includes the resale value of debuffed owned Jokers')
  s.jokers[1].sell_cost=nil
  check(not Pack.project(s,fool(),{},nil,modules),'unknown Temperance resale remains unsupported')
end
do
  local s=state()
  check(not Pack.project(s,fool(),{1},nil,modules),'unexpected hand targets are rejected')
  check(not Pack.project(s,fool(),{},{1,2,3,4,5,6,7,8},modules),'unexpected hand reordering is rejected')
  s.phase='hand';check(not Pack.project(s,fool(),{},nil,modules),'this slice does not alter owned Fool-use planning')
end
do
  local s=state();s.pack_cards={fool(),{id='pack-empress',key='c_empress',name='The Empress',cost=3,
    ability={set='Tarot',name='The Empress',consumeable={max_highlighted=2,mod_num=2,mod_conv='m_mult'}}}}
  local before=Snapshot.fingerprint(s)
  local result=Decision.run(s,modules)
  check(result.pack_diagnostics and result.pack_diagnostics.complete and not result.pack_diagnostics.tactical_fallback,
    'actual full pack decision completes the Fool and enhancement family together')
  check(not result.shop_diagnostics.truncated and result.evaluations<=50000,
    'the supported family stays within the unchanged shared shop budget')
  local copy_receipt=result.pack_diagnostics.comparisons[1].transition
  check(copy_receipt and copy_receipt.copy_used==false and copy_receipt.created_key=='c_star',
    'the real decision exposes inventory generation instead of an invented copied-use endpoint')
  check(Snapshot.fingerprint(s)==before,'the full decision leaves population and inventory unchanged')
  local missing=copy(s);missing.shop_forecast.tarot_pool={}
  local unavailable=Decision.run(missing,modules)
  check(unavailable.pack_diagnostics.tactical_fallback,'unresolved generated identity keeps the whole-family fallback')
  local capped=Decision.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
  check(capped.shop_diagnostics.truncated and capped.pack_diagnostics.tactical_fallback,
    'a shared scoring cutoff cannot preserve partially evaluated Fool credit')
  local protected=copy(s);protected.used_vouchers={v_observatory=true}
  local protected_before=Snapshot.fingerprint(protected)
  local retained=Decision.run(protected,modules)
  check(retained.pack_diagnostics.tactical_fallback and not retained.pack_diagnostics.complete and
    retained.pack_diagnostics.fallback_reason:find('Observatory',1,true),
    'an Observatory inventory keeps the existing strategic path without partial Fool tactical credit')
  check(Snapshot.fingerprint(protected)==protected_before,'inventory fallback leaves all protected state intact')
  print('advisor_pack_fool real score calls: '..result.evaluations)
end
math.random,math.randomseed=random,randomseed
print('advisor_pack_fool: '..checks..' checks passed')
