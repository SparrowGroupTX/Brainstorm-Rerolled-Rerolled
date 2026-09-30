-- Manufactured states only. Source names are frozen data, not source execution.
-- Check row catalog agreement separately from paid transition and score support.
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local H=F.Hold
local Goal=dofile('Brainstorm/Advisor/gold_goal.lua')
local Perkeo=dofile('Brainstorm/Advisor/gold_perkeo.lua')
local S=F.Snapshot
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
math.random=function() error('No RNG is allowed in manufactured row support fixtures') end
pseudorandom=math.random;pseudoseed=math.random
local source_names={}
for line in ([=[
j_8_ball=8 Ball
j_abstract=Abstract Joker
j_acrobat=Acrobat
j_ancient=Ancient Joker
j_arrowhead=Arrowhead
j_astronomer=Astronomer
j_banner=Banner
j_baron=Baron
j_baseball=Baseball Card
j_blackboard=Blackboard
j_bloodstone=Bloodstone
j_blue_joker=Blue Joker
j_blueprint=Blueprint
j_bootstraps=Bootstraps
j_brainstorm=Brainstorm
j_bull=Bull
j_burglar=Burglar
j_burnt=Burnt Joker
j_business=Business Card
j_caino=Caino
j_campfire=Campfire
j_card_sharp=Card Sharp
j_cartomancer=Cartomancer
j_castle=Castle
j_cavendish=Cavendish
j_ceremonial=Ceremonial Dagger
j_certificate=Certificate
j_chaos=Chaos the Clown
j_chicot=Chicot
j_clever=Clever Joker
j_cloud_9=Cloud 9
j_constellation=Constellation
j_crafty=Crafty Joker
j_crazy=Crazy Joker
j_credit_card=Credit Card
j_delayed_grat=Delayed Gratification
j_devious=Devious Joker
j_diet_cola=Diet Cola
j_dna=DNA
j_drivers_license=Driver's License
j_droll=Droll Joker
j_drunkard=Drunkard
j_duo=The Duo
j_dusk=Dusk
j_egg=Egg
j_erosion=Erosion
j_even_steven=Even Steven
j_faceless=Faceless Joker
j_family=The Family
j_fibonacci=Fibonacci
j_flash=Flash Card
j_flower_pot=Flower Pot
j_fortune_teller=Fortune Teller
j_four_fingers=Four Fingers
j_gift=Gift Card
j_glass=Glass Joker
j_gluttenous_joker=Gluttonous Joker
j_golden=Golden Joker
j_greedy_joker=Greedy Joker
j_green_joker=Green Joker
j_gros_michel=Gros Michel
j_hack=Hack
j_half=Half Joker
j_hallucination=Hallucination
j_hanging_chad=Hanging Chad
j_hiker=Hiker
j_hit_the_road=Hit the Road
j_hologram=Hologram
j_ice_cream=Ice Cream
j_idol=The Idol
j_invisible=Invisible Joker
j_joker=Joker
j_jolly=Jolly Joker
j_juggler=Juggler
j_loyalty_card=Loyalty Card
j_luchador=Luchador
j_lucky_cat=Lucky Cat
j_lusty_joker=Lusty Joker
j_mad=Mad Joker
j_madness=Madness
j_mail=Mail-In Rebate
j_marble=Marble Joker
j_matador=Matador
j_merry_andy=Merry Andy
j_midas_mask=Midas Mask
j_mime=Mime
j_misprint=Misprint
j_mr_bones=Mr. Bones
j_mystic_summit=Mystic Summit
j_obelisk=Obelisk
j_odd_todd=Odd Todd
j_onyx_agate=Onyx Agate
j_oops=Oops! All 6s
j_order=The Order
j_pareidolia=Pareidolia
j_perkeo=Perkeo
j_photograph=Photograph
j_popcorn=Popcorn
j_raised_fist=Raised Fist
j_ramen=Ramen
j_red_card=Red Card
j_reserved_parking=Reserved Parking
j_ride_the_bus=Ride the Bus
j_riff_raff=Riff-raff
j_ring_master=Showman
j_rocket=Rocket
j_rough_gem=Rough Gem
j_runner=Runner
j_satellite=Satellite
j_scary_face=Scary Face
j_scholar=Scholar
j_seance=Seance
j_seeing_double=Seeing Double
j_selzer=Seltzer
j_shoot_the_moon=Shoot the Moon
j_shortcut=Shortcut
j_sixth_sense=Sixth Sense
j_sly=Sly Joker
j_smeared=Smeared Joker
j_smiley=Smiley Face
j_sock_and_buskin=Sock and Buskin
j_space=Space Joker
j_splash=Splash
j_square=Square Joker
j_steel_joker=Steel Joker
j_stencil=Joker Stencil
j_stone=Stone Joker
j_stuntman=Stuntman
j_supernova=Supernova
j_superposition=Superposition
j_swashbuckler=Swashbuckler
j_throwback=Throwback
j_ticket=Golden Ticket
j_to_the_moon=To the Moon
j_todo_list=To Do List
j_trading=Trading Card
j_tribe=The Tribe
j_triboulet=Triboulet
j_trio=The Trio
j_troubadour=Troubadour
j_trousers=Spare Trousers
j_turtle_bean=Turtle Bean
j_vagabond=Vagabond
j_vampire=Vampire
j_walkie_talkie=Walkie Talkie
j_wee=Wee Joker
j_wily=Wily Joker
j_wrathful_joker=Wrathful Joker
j_yorick=Yorick
j_zany=Zany Joker
]=]):gmatch('[^\r\n]+') do local key,label=line:match('^(j_[%w_]+)=(.+)$');source_names[key]=label end
if row_fixture_scope~='mixed' then
  local admitted=0
  for key,name in pairs(source_names) do
    local s=F.state();local j=F.joker(key,name,'fixture:'..key)
    -- Cartomancer can share the exit-only dependency proof, while its distinct
    -- startup generation still needs the caller's exact capacity qualification.
    local expected=Goal.stable_card(j,Perkeo) or key=='j_cartomancer'
    s.jokers[#s.jokers+1]=j
    local receipt,why=H.certify(s)
    eq(receipt~=nil,not not expected,'exact source-name membership '..key..' / '..tostring(why))
    if expected then
      admitted=admitted+1
      check(receipt.original_inventory_unchanged and not receipt.generation_used_for_score,'wider row grants only unused-inventory equivalence')
      eq(S.fingerprint(receipt.inventory_before),S.fingerprint(s.consumeables),'all original card fields retained')
      local before=S.fingerprint(s)
      s.jokers[#s.jokers].ability.name='Counterfeit '..name
      check(not H.certify(s),'known key with a mismatched source ability rejects '..key)
      s.jokers[#s.jokers].ability.name=name;s.jokers[#s.jokers].name='Counterfeit '..name
      check(not H.certify(s),'known key with a mismatched display identity rejects '..key)
      s.jokers[#s.jokers].name=name
      eq(S.fingerprint(s),before,'qualification checks never mutate the row')
    end
  end
  eq(admitted,110,'current stable/Perkeo identities plus Cartomancer exit-only identity')
  for _,key in ipairs({'j_cartomancer','j_abstract','j_banner','j_mime','j_baron','j_caino'}) do
    local s=F.state();s.jokers={F.joker('j_perkeo','Perkeo','p'),F.joker(key,source_names[key],'target'),F.joker('j_brainstorm','Brainstorm','copy')}
    eq(H.certify(s).copy_events,2,'unrelated '..key..' keeps the physical Perkeo/copy count')
    s.jokers[1],s.jokers[2]=s.jokers[2],s.jokers[1]
    eq(H.certify(s).copy_events,1,'Brainstorm on '..key..' does not create an invented Perkeo event')
    s.jokers[1]=F.joker('j_blueprint','Blueprint','blue')
    eq(H.certify(s).copy_events,3,'Blueprint then Perkeo allows both physical copy chains')
    s.jokers[2].blueprint_compat=false
    eq(H.certify(s).copy_events,1,'target compatibility still gates every copied chain')
  end
  local s=F.state();s.jokers[3]=F.joker('j_unknown','Abstract Joker','unknown')
  check(not H.certify(s),'a known name never admits an unknown key')
  for _,key in ipairs({'j_madness','j_ceremonial','j_riff_raff','j_certificate','j_marble','j_vampire'}) do
    s=F.state();s.jokers[3]=F.joker(key,source_names[key],'excluded')
    check(not H.certify(s),'automatic destruction/population/startup outside this row boundary '..key)
  end
end
do
local prefix='Brainstorm/Advisor/'
local A=dofile('Brainstorm/Advisor/gold_acquisition.lua')
local Snapshot=dofile(prefix..'snapshot.lua')
local Goal=dofile(prefix..'gold_goal.lua')
local Shop=dofile(prefix..'shop_scoring.lua')
local Score=dofile(prefix..'scoring.lua')
local Strategy=dofile(prefix..'strategy.lua')
local Sequences=dofile(prefix..'shop_sequences.lua')
local Liquidity=dofile(prefix..'liquidity.lua')
local Perkeo=dofile(prefix..'gold_perkeo.lua')
Strategy.liquidity=Liquidity;Liquidity.snapshot=Snapshot
local mods={gold_goal=Goal,shop_scoring=Shop,scoring=Score,strategy=Strategy,shop_sequences=Sequences,liquidity=Liquidity,gold_perkeo=Perkeo}
local copy=Snapshot.copy
local function module_copy(source) local out={};for key,value in pairs(source) do out[key]=value end;return out end
local function joker(key,id,name,ability)
  ability=ability or {};ability.set='Joker';ability.name=name
  return {key=key,id=id,name=name,ability=ability,cost=5,base_cost=5,sell_cost=2,debuff=false,face_down=false,pinned=false,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=8,win_ante=8,dollars=170,bankrupt_at=0,joker_limit=1,consumable_limit=2,
    consumeable_buffer=0,consumeables={},jokers={joker('j_joker','owned','Joker',{mult=4})},
    shop_jokers={joker('j_crazy','offer','Crazy Joker',{t_mult=12,type='Straight'})},shop_booster={},shop_vouchers={},
    next_blind={key='bl_big',name='Big Blind',boss=false,chips=100,ante=8},hand_size=4,hand_limit=5,
    hands_left=4,discards_left=3,round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    hands={},playing_cards={},hand={},deck={},ordering_safe=true,jokers_shuffling=false,
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',shop_forecast={inflation=0,discount_percent=0},
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={eligible=true},by_key={j_joker={status='complete'},j_crazy={status='missing'}}}}
  for _,name in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind',
      'Straight Flush','Five of a Kind','Flush House','Flush Five'}) do s.hands[name]={chips=100,mult=10,level=10,played=1} end
  for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}} end
  return s
end
local calls=0;local actual=Score.lower_bound
local counted={lower_bound=function(...)
  calls=calls+1;return actual(...)
end,score=function() error('Acquisition may not use a random-score mean') end}
mods.scoring=counted
local function advise(s,options,modules)
  local prior=calls;local advice,work,d=A.suggest(s,modules or mods,nil,options)
  eq(work,calls-prior,'every underlying floor call is charged exactly once')
  check(work<=math.min(50000,options and options.max_evaluations or 50000),'the declared common shop allowance is respected')
  return advice,work,d
end
math.random=function() error('No RNG belongs in the manufactured family') end;pseudorandom=math.random

local variants={
  {key='j_abstract',name='Abstract Joker',ability={extra=3}},
  {key='j_banner',name='Banner',ability={extra=30}},
  {key='j_mime',name='Mime',ability={}},
  {key='j_baron',name='Baron',ability={extra=1.5}},
}
for _,variant in ipairs(variants) do
  local s=state();s.joker_limit=5;s.next_blind.chips=1000
  s.jokers={joker('j_yorick','y','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
    joker('j_perkeo','p','Perkeo',{eternal=true}),joker('j_brainstorm','b','Brainstorm',{eternal=true}),
    joker('j_scary_face','s','Scary Face',{extra=30}),joker('j_golden','g','Golden Joker',{extra=4})}
  for _,j in ipairs(s.jokers) do s.completionist_goal.by_key[j.key]={status='complete'} end
  s.consumeables=F.state().consumeables;s.consumable_limit=16;s.consumeable_usage_total={tarot=8}
  s.shop_jokers[2]=joker(variant.key,'offer:2',variant.name,copy(variant.ability))
  s.completionist_goal.by_key[variant.key]={status='missing'}
  local configured=module_copy(mods);configured.gold_tarot_hold=H
  local before=Snapshot.fingerprint(s)
  -- An unused prospective Negative from either qualified source class must
  -- leave actual scoring unchanged, including count-based and held-card Jokers.
  local scoring=copy(s);scoring.hand={copy(s.playing_cards[1]),copy(s.playing_cards[2]),copy(s.playing_cards[3]),copy(s.playing_cards[4])}
  scoring.jokers[#scoring.jokers+1]=copy(s.shop_jokers[2])
  local base_score=Score.lower_bound(scoring,{1,2,3,4})
  for _,tarot in ipairs({'c_magician','c_hermit'}) do
    local added=copy(scoring);added.consumeables[#added.consumeables+1]=F.observe(F.raw(tarot,'prospective:'..tarot,true))
    added.consumable_limit=added.consumable_limit+1
    eq(Score.lower_bound(added,{1,2,3,4}).score,base_score.score,'unused Negative '..tarot..' leaves first-hand score unchanged with '..variant.name)
  end
  local advice,work,d=advise(s,nil,configured)
  check(advice and d.complete and d.projection_complete,'the full mixed-offer family completes with '..variant.name..': '..tostring(d.reason))
  eq(#d.endpoints,5,'hold plus two legal completed-original sales for each of two offers')
  local observed={}
  for _,endpoint in ipairs(d.endpoints) do
    if #endpoint.actions>0 then
      local buy=endpoint.actions[#endpoint.actions]
      observed[buy.index]=(observed[buy.index] or 0)+1
      eq(endpoint.hold_certificate.inventory_count_before,14,'every endpoint keeps the whole mixed Tarot inventory')
      eq(endpoint.evidence.common_worlds.family_key,d.endpoints[1].evidence.common_worlds.family_key,'different target offers use exactly the same world family')
    end
  end
  eq(observed[1],2,'the original supported offer is fully compared')
  eq(observed[2],2,'the newly covered offer is fully compared, not dropped after another success')
  eq(Snapshot.fingerprint(s),before,'mixed-offer family leaves input unchanged')
  local sold=assert(Sequences.transition(s,advice.action,configured))
  local buy,_,after=advise(sold,nil,configured)
  check(buy and after.complete and buy.action.kind=='buy','fresh post-sale state buys a visible missing Joker')
end
end
print('advisor_gold_tarot_rows: '..checks..' manufactured source-identity and complete mixed-offer checks passed')
