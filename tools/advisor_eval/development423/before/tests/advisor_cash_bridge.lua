local M=dofile('Brainstorm/Core/jokerless_opening.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local F=dofile('tests/jokerless_opening_fixture.lua')
local checks=0;local function check(v,label)checks=checks+1;assert(v,label)end
local copy=Snapshot.copy
local function planet(key,hand,name,id)
 return {id=id,key=key,name=name,cost=0,base_cost=3,sell_cost=1,
  ability={set='Planet',name=name,couponed=true,consumeable={hand_type=hand},extra_value=0}}
end
local function state()
 return {phase='shop',dollars=9,bankrupt_at=0,jokers={},modifiers={},consumeables={},
  consumeable_buffer=0,consumable_limit=2,shop_forecast={inflation=0,discount_percent=0},
  shop_jokers={planet('c_uranus','Two Pair','Uranus','free:1')},
  shop_vouchers={{id='wanted:1',key='v_crystal_ball',name='Crystal Ball',cost=10,ability={set='Voucher'}}}}
end
local purchase={kind='buy',area='shop_vouchers',index=1}
local options={source_shop={{key='c_uranus',set='Planet'},{key='c_jupiter',set='Planet'}},protected_keys={c_jupiter=true}}
local random,seed=math.random,math.randomseed
math.random=function()error('Cash bridge must not consume global RNG')end
math.randomseed=function()error('Cash bridge must not reseed global RNG')end
do
 local s=state();local before=Snapshot.fingerprint(s)
 local r=M.cash_bridge(s,purchase,options)
 check(r and r.action.kind=='buy' and r.action.area=='shop_jokers' and r.action.index==1,'generic declared voucher receives the first free-buy step')
 check(r.cash_bridge.action_count==3 and r.cash_bridge.cash_before==9 and r.cash_bridge.cash_after_sale==10 and
  r.cash_bridge.cash_after_purchase==0 and r.cash_bridge.source_id=='free:1','three actual actions and exact cash arithmetic are published')
 check(r.cash_bridge.actions[2].kind=='sell' and r.cash_bridge.actions[3].area=='shop_vouchers','copy is sold rather than used to pay for the declared item')
 check(Snapshot.fingerprint(s)==before and Snapshot.fingerprint(r)==Snapshot.fingerprint(M.cash_bridge(s,purchase,options)),
  'conditional path is pure and deterministic')
 r.cash_bridge.comparisons[1].source_key='changed'
 check(s.shop_jokers[1].key=='c_uranus','receipt does not alias the snapshot')
 s.consumeables[1]=table.remove(s.shop_jokers,1)
 local held=M.cash_bridge(s,purchase,options)
 check(held and held.action.kind=='sell' and held.action.area=='consumeables' and held.cash_bridge.action_count==2,
  'fresh observation identifies the unique qualified held continuation')
 check(held.cash_bridge.source_id==r.cash_bridge.source_id,'the observed held card retains the source identity')
 s.shop_vouchers[1].cost=11
 check(not M.cash_bridge(s,purchase,options),'a changed visible target price invalidates the incomplete cash path')
 s.shop_vouchers[1].cost=10;s.consumeables={};s.dollars=10
 check(not M.cash_bridge(s,purchase,options),'already affordable purchase needs no financing actions')
end
for _,case in ipairs({
 {'insufficient net cash',function(s,o)s.dollars=8 end},
 {'borrow limit insufficient',function(s,o)s.dollars=3;s.bankrupt_at=-5 end},
 {'already affordable with signed debt',function(s,o)s.dollars=5;s.bankrupt_at=-5 end},
 {'full capacity',function(s,o)s.consumable_limit=0 end},
 {'pending inventory generation',function(s,o)s.consumeable_buffer=1 end},
 {'mixed original inventory',function(s,o)s.consumeables={planet('c_pluto','High Card','Pluto','held:1'),planet('c_uranus','Two Pair','Uranus','held:2')} end},
 {'protected target Planet',function(s,o)o.protected_keys.c_uranus=true end},
 {'unqualified original source',function(s,o)o.source_shop={} end},
 {'duplicate original source',function(s,o)o.source_shop[2]=copy(o.source_shop[1]) end},
 {'unexpected stock identity',function(s,o)s.shop_jokers[1].key='c_saturn' end},
 {'missing stable identity',function(s,o)s.shop_jokers[1].id=nil end},
 {'colliding stable identity',function(s,o)s.shop_jokers[1].id='wanted:1' end},
 {'target identity missing',function(s,o)s.shop_vouchers[1].id=nil end},
 {'unknown target price',function(s,o)s.shop_vouchers[1].cost=math.huge end},
 {'nonfree stock',function(s,o)s.shop_jokers[1].cost=1 end},
 {'unknown resale',function(s,o)s.shop_jokers[1].sell_cost=nil end},
 {'inconsistent resale',function(s,o)s.shop_jokers[1].sell_cost=5 end},
 {'not couponed',function(s,o)s.shop_jokers[1].ability.couponed=nil end},
 {'Negative',function(s,o)s.shop_jokers[1].edition={negative=true} end},
 {'other edition',function(s,o)s.shop_jokers[1].edition={foil=true} end},
 {'debuffed',function(s,o)s.shop_jokers[1].debuff=true end},
 {'concealed',function(s,o)s.shop_jokers[1].face_down=true end},
 {'eternal',function(s,o)s.shop_jokers[1].ability.eternal=true end},
 {'modified hand resource',function(s,o)s.shop_jokers[1].ability.h_size=1 end},
 {'unknown Planet effect',function(s,o)s.shop_jokers[1].ability.consumeable.extra=1 end},
 {'wrong hand identity',function(s,o)s.shop_jokers[1].ability.consumeable.hand_type='Flush' end},
 {'inflation',function(s,o)s.modifiers.inflation=true end},
 {'previous inflation',function(s,o)s.shop_forecast.inflation=1 end},
 {'tax resources',function(s,o)s.modifiers.minus_hand_size_per_X_dollar=5 end},
 {'paid discards',function(s,o)s.modifiers.discard_cost=1 end},
 {'Joker sale effects',function(s,o)s.jokers={{key='j_campfire'}} end},
 {'Perkeo pool',function(s,o)s.jokers={{key='j_perkeo'}} end},
 {'Observatory',function(s,o)s.used_vouchers={v_observatory=true} end},
 {'alternate Observatory metadata',function(s,o)s.vouchers={v_observatory=true} end},
}) do
 local s,o=state(),copy(options);case[2](s,o)
 check(not M.cash_bridge(s,purchase,o),case[1]..' declines cash-only financing')
end
do
 local s=state();s.dollars=4;s.bankrupt_at=-5
 local r=M.cash_bridge(s,purchase,options)
 check(r and r.cash_bridge.cash_after_purchase==-5,'one dollar can reach the actual negative borrowing floor exactly')
 s.consumeables[1]=copy(s.shop_jokers[1]);s.consumeables[1].id='held:1'
 check(not M.cash_bridge(s,purchase,options),'a held key still present in stock is not the qualified continuation')
 s.shop_jokers={};s.consumeables[1].key='c_fool'
 check(not M.cash_bridge(s,purchase,options),'arbitrary held consumables cannot be liquidated')
end
do
 local recipe=M.predict(F.examples[2].seed,F.catalog)
 local s=state();s.challenge='c_jokerless_1';s.ante=1;s.round=1;s.blind_states={Small='Skipped'}
 s.filter_info={jokerless_opening=recipe,jokerless_catalog_signature=recipe.catalog_signature}
 s.shop_jokers={planet('c_pluto','High Card','Pluto','route:1')}
 s.shop_vouchers[1].key='v_telescope';s.shop_vouchers[1].name='Telescope';s.shop_booster={}
 local r=M.advice(s)
 check(r and r.cash_bridge and r.action.kind=='buy','declared opening voucher requests the generic financing helper')
 s.consumeables[1]=table.remove(s.shop_jokers,1)
 r=M.advice(s)
 check(r and r.cash_bridge and r.action.kind=='sell','route re-observes the qualified held Planet before its sale')
 s.dollars=s.dollars+s.consumeables[1].sell_cost;s.consumeables={}
 r=M.advice(s)
 check(r.action.kind=='buy' and r.action.area=='shop_vouchers' and not r.cash_bridge,'funded voucher becomes an ordinary newly checked purchase')
 s.dollars=4;s.bankrupt_at=-5;r=M.advice(s)
 check(not r or not r.action,'insufficient borrowing does not invent a now-missing bridge')
 s.dollars=5;r=M.advice(s)
 check(r.action.kind=='buy' and r.action.area=='shop_vouchers','voucher affordability uses cash minus the negative debt limit')
end
math.random,math.randomseed=random,seed
print('advisor_cash_bridge: '..checks..' checks passed')
