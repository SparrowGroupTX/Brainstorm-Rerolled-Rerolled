local C=dofile('Brainstorm/Advisor/consumables.lua')
local D=dofile('Brainstorm/Advisor/deck_development.lua');C.deck_development=D
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,r,e) return {id=id,rank=r,nominal=math.min(r,10),suit='Spades',enhancement=e or 'c_base',ability={}} end
local function joker(key,n,a) a=a or {};a.name=n;return {key=key,name=n,ability=a} end
local function state()
  local s={phase='hand',ante=2,win_ante=8,hand={},playing_cards={},deck={},jokers={},hands={},
    consumeables={{key='c_hanged_man',ability={name='The Hanged Man',set='Tarot',consumeable={remove_card=true,max_highlighted=2}}}},
    consumable_limit=2,blind={chips=20},chips=0,hands_left=3,hand_size=8,hand_limit=5,discards_left=3,dollars=20,
    consumeable_usage_total={all=0,tarot=0},modifiers={}}
  for i=1,20 do local c=card('c'..i,i<=8 and 13 or (i<=10 and 12 or 2));s.playing_cards[i]=c;if i<=10 then s.hand[i]=c else s.deck[#s.deck+1]=c end end
  return s
end
do
 local s=state();s.jokers={joker('j_caino','Caino',{caino_xmult=1,extra=1}),joker('j_blueprint','Blueprint'),joker('j_glass','Glass Joker',{x_mult=1,extra=0.75})}
 s.hand[9].enhancement='m_glass';s.hand[10].debuff=true
 local after=assert(C.apply(s,1,{9,10}))
 eq(#after.hand,8,'removes both hand cards');eq(#after.playing_cards,18,'removes from entire population')
 eq(#after.deck,10,'does not confuse hand deletion with unseen draws');eq(after.jokers[1].ability.caino_xmult,2,'only active face counts')
 eq(after.jokers[2].ability.caino_xmult,nil,'Blueprint does not duplicate permanent growth')
 eq(after.jokers[3].ability.x_mult,1.75,'Glass Joker grows once');eq(#s.hand,10,'original hand immutable')
 eq(after.consumeable_usage_total.tarot,1,'Tarot usage');eq(#after.consumeables,0,'spent inventory')
 s.hand[9].enhancement='m_stone';s.jokers[2]=joker('j_pareidolia','Pareidolia')
 eq(assert(C.apply(s,1,{9})).jokers[1].ability.caino_xmult,2,'Pareidolia makes nondebuffed Stone a face')
 s.jokers[2].debuff=true;eq(assert(C.apply(s,1,{9})).jokers[1].ability.caino_xmult,1,'debuffed Pareidolia does not affect Stone')
 s.consumeables[1].edition={negative=true};eq(assert(C.apply(s,1,{9})).consumable_limit,1,'Negative use removes extra slot')
 s.playing_cards={};eq(C.apply(s,1,{9}),nil,'unknown population withheld')
end
do
 local s=state();s.hand[1],s.hand[9]=s.hand[9],s.hand[1]
 s.jokers={joker('j_caino','Caino',{caino_xmult=1,extra=1})}
 local base=Score.score(s,{2,3,4,5,6});base.indices={2,3,4,5,6}
 local use,cost=assert(C.develop(s,Score,base,{strategy=S}))
 eq(use.action.kind,'use','Canio investment selected despite clear');eq(cost<=6,true,'bounded scoring checks')
 eq(use.action.targets[1],1,'off-plan face preferred to held Kings')
 eq(use.play.indices[1],1,'retained finishing card remapped after early deletion')
 eq(use.play.score>=20,true,'retained hand still clears')
 for _,i in ipairs(use.action.targets) do eq(i~=2 and i~=3 and i~=4 and i~=5 and i~=6,true,'reserved scorer protected') end
 s.jokers[#s.jokers+1]=joker('j_perkeo','Perkeo')
 eq(C.develop(s,Score,base,{strategy=S}),nil,'last useful copying source preserved')
 s.jokers={};s.ante=8;s.blind.boss=true
 eq(C.develop(s,Score,base,{strategy=S}),nil,'final clear avoids development')
 s.ante=2;s.blind.boss=nil;s.challenge=nil;s.probabilities={normal=4}
 s.jokers={joker('j_caino','Caino',{caino_xmult=1,extra=3})}
 for _,c in ipairs(s.playing_cards) do c.enhancement='m_glass' end
 eq(D.targets(s,s.consumeables[1],S.build_profile(s),base,S),nil,'certain Glass depletion protected without challenge ID')
 s.probabilities.normal=1
 eq(D.targets(s,s.consumeables[1],S.build_profile(s),base,S)~=nil,true,'lower actual break risk permits useful growth despite same Glass population')
 s.challenge='c_fragile_1'
 eq(D.targets(s,s.consumeables[1],S.build_profile(s),base,S)~=nil,true,'obsolete challenge label does not override actual rules')
 for i=1,10 do s.playing_cards[i].ability.perma_debuff=true end
 eq(D.targets(s,s.consumeables[1],S.build_profile(s),base,S),nil,'thin usable population protected despite many physical cards')
end
do
 local s=state();s.hand[9].enhancement='m_steel';s.hand[10].enhancement='m_stone'
 s.jokers={joker('j_steel_joker','Steel Joker',{steel_tally=1}),joker('j_stone','Stone Joker',{stone_tally=1}),joker('j_drivers_license',"Driver's License",{driver_tally=2})}
 local after=assert(C.apply(s,1,{9,10}))
 eq(after.jokers[1].ability.steel_tally,0,'Steel population tally refreshed')
 eq(after.jokers[2].ability.stone_tally,0,'Stone population tally refreshed')
 eq(after.jokers[3].ability.driver_tally,0,'enhancement population tally refreshed')
 eq(D.remap_indices(s,after,{9}),nil,'deleted finish cannot be remapped')
end
do
 local s=state();s.teacher_profile='perkeo_yorick_win_v1'
 for i=21,30 do local c=card('c'..i,2);s.playing_cards[i]=c;s.deck[#s.deck+1]=c end
 eq(#assert(C.apply(s,1,{9,10})).playing_cards,28,'win-first Hanged may remove exactly to physical reserve')
 s.playing_cards[30]=nil;s.deck[#s.deck]=nil
 eq(C.apply(s,1,{9,10}),nil,'win-first Hanged cannot remove two below reserve')
 eq(#assert(C.apply(s,1,{9})).playing_cards,28,'a single supported removal can reach reserve')
 s.playing_cards[29]=nil;s.deck[#s.deck]=nil
 eq(C.apply(s,1,{9}),nil,'win-first Hanged cannot shrink an already 28-card deck')
end
print('advisor deck development: '..checks..' checks passed')
