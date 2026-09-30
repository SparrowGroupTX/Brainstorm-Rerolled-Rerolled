-- Independently manufactured win-first inventory and admission cases.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(key,name,set,sell,extra)
 return {id='manufactured:'..key,key=key,name=name,sell_cost=sell or 2,
  ability={name=name,set=set,consumeable=extra or {}}}
end
local function state()
 local s={phase='shop',ante=5,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
  dollars=70,jokers={{key='j_perkeo',name='Perkeo',ability={name='Perkeo'}}},
  consumeables={},consumable_limit=2,playing_cards={},hand={},deck={},
  hands={['High Card']={played=20,level=4,chips=70,mult=5},['Three of a Kind']={played=0,level=1,chips=30,mult=3}},
  modifiers={},blind={key='bl_small',chips=100}}
 for i=1,28 do s.playing_cards[i]={id='manufactured:playing:'..i,rank=i%13+2,suit='Spades',enhancement='c_base'} end
 return s
end
do
 local s=state();local business=card('j_business','Business Card','Joker',4)
 business.ability.eternal=true;business.edition={polychrome=true,x_mult=1.5}
 local admitted,why=S.joker_admission(s,business,s)
 eq(admitted,false,'Polychrome does not justify an ordinary permanent speculative-income slot')
 eq(why.kind,'win_first_permanent_slot_guard','admission rejection remains auditable')
 s.jokers[#s.jokers+1]={key='j_pareidolia',ability={name='Pareidolia'}}
 eq(S.joker_admission(s,business,s),true,'known face-scoring support may justify a Business offer')
 s.jokers[2]=nil;business.edition={negative=true}
 eq(S.joker_admission(s,business,s),true,'Negative Business does not consume the ordinary slot')
 business.edition=nil;business.ability.eternal=nil;s.modifiers.all_eternal=true
 eq(S.joker_admission(s,business,s),false,'forced Eternal shop modifier is respected')
 s.modifiers.all_eternal=nil;s.teacher_profile=nil
 eq(S.joker_admission(s,business,s),true,'other profiles retain their own admission policy')
end
do
 local s=state()
 s.consumeables={card('c_venus','Venus','Planet',2,{hand_type='Three of a Kind'}),
  card('c_pluto','Pluto','Planet',2,{hand_type='High Card'})}
 local action=S.manage_teacher_stock(s)
 check(action and action.action.kind=='sell' and action.action.index==1,
  'off-target Planet diluting the stronger Perkeo source is sold at a full shop inventory')
 eq(#s.consumeables,2,'inventory review does not mutate the public stock')
 s.consumeables={card('c_pluto','Pluto','Planet',2,{hand_type='High Card'})}
 action=S.manage_teacher_stock(s)
 check(not action or action.action.kind~='sell','last useful target Planet is retained')
end
do
 local s=state();s.consumeables={card('c_hanged_man','The Hanged Man','Tarot',2,{remove_card=true,max_highlighted=2}),
  card('c_pluto','Pluto','Planet',2,{hand_type='High Card'})}
 local action=S.manage_teacher_stock(s)
 check(action and action.action.kind=='sell' and action.action.index==1,
  'unusable Hanged Man is removed from a full Perkeo copying pool')
 s.playing_cards[29]={id='manufactured:playing:29',rank=2,suit='Spades'}
 s.playing_cards[30]={id='manufactured:playing:30',rank=2,suit='Spades'}
 action=S.manage_teacher_stock(s)
 check(not action or action.action.kind~='sell' or action.action.index~=1,
  'a still-usable Hanged Man is not treated as exhausted stock')
end
do
 local s=state();s.ante=3;s.dollars=90
 s.consumeables={card('c_death','Death','Tarot',2,{})}
 s.shop_booster={card('p_standard_normal_1','Standard Pack','Booster',2,{})}
 s.shop_booster[1].cost=4
 local advice=S.advise(s)
 eq(advice.action.kind,'open','held Death without a strong source can justify inspecting a Standard Pack')
 eq(advice.action.area,'shop_booster','source search names the actually visible pack')
 s.playing_cards[1].enhancement='m_glass'
 advice=S.advise(s)
 check(advice.action.kind~='open','known Glass source removes the speculative Death-source premium')
end
print('advisor_win_first384: '..checks..' manufactured checks passed')
