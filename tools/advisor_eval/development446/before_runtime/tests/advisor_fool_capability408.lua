local p='Brainstorm/Advisor/';local S=dofile(p..'strategy.lua');local Snap=dofile(p..'snapshot.lua')
local C=dofile(p..'consumables.lua');local Pack=dofile(p..'pack_scoring.lua');S.consumables=C;S.pack_scoring=Pack
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local fool={id='f',key='c_fool',name='The Fool',cost=3,sell_cost=1,ability={name='The Fool',set='Tarot',consumeable={}}}
local s={phase='shop',teacher_profile='perkeo_yorick_win_v1',ante=2,dollars=9,bankrupt_at=0,
 joker_limit=5,consumable_limit=2,consumeable_buffer=0,jokers={{id='perkeo',key='j_perkeo',ability={name='Perkeo',set='Joker'}}},
 consumeables={},shop_jokers={fool},shop_vouchers={},shop_booster={},playing_cards={},hands={Pair={level=2,played=8}},
 modifiers={},last_tarot_planet='c_mercury'}
check(S.shop_sequence_api.card_value(s,fool)==0,'Unsupported owned Fool receives no future-copy purchase premium')
local advice=S.advise(s)
check(not (advice.action.kind=='buy' and advice.action.area=='shop_jokers'),'Empty Perkeo pool cannot force unsupported Fool acquisition')
s.consumeables={Snap.copy(fool)};s.shop_jokers={}
local clean=S.manage_teacher_stock(s)
check(clean and clean.action.kind=='sell','Already-owned unusable ordinary Fool may be liquidated')
s.consumeables[1].edition={negative=true};s.consumable_limit=3
check(S.manage_teacher_stock(s).action.kind=='sell','Negative unsupported stock evaluated with lost capacity')
s.consumeable_buffer=1;check(not S.manage_teacher_stock(s),'Creation buffer blocks cleanup');s.consumeable_buffer=0
s.modifiers.minus_hand_size_per_X_dollar=5;check(not S.manage_teacher_stock(s),'Cash hand-size modifier requires qualified transition')
s.modifiers={};s.last_tarot_planet='c_jupiter';s.hands={Flush={level=5,played=8}}
check(S.shop_sequence_api.card_value(s,fool)>0,'Existing Flush/Jupiter route retains acquisition value')
check(not S.manage_teacher_stock(s),'Productive Jupiter-copy stock preserved')
s.last_tarot_planet='c_fool';s.consumeables[2]={id='jup',key='c_jupiter',ability={name='Jupiter',set='Planet',consumeable={hand_type='Flush'}}}
local intermediate=S.manage_teacher_stock(s)
check(not intermediate or intermediate.action.index~=1,'Intermediate generated Jupiter route cannot liquidate its Fool')
local ordinary=Snap.copy(s);ordinary.teacher_profile=nil;ordinary.jokers={};ordinary.last_tarot_planet='c_jupiter';ordinary.consumeables={Snap.copy(fool)};ordinary.consumable_limit=2
check(S.shop_sequence_api.card_value(ordinary,fool)>0,'Existing zero-Joker main-Planet value unchanged; full transition covered in owned_fool_shop fixture')
print('advisor_fool_capability408: '..checks..' checks passed')
