local B=dofile(PROBE_MODULE)
local D=dofile(PROBE_DIRECTORY..'/draws.lua')
local O=dofile(PROBE_DIRECTORY..'/sampled_outcomes.lua')
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local names={bl_small='Small Blind',bl_house='The House',bl_fish='The Fish',bl_wheel='The Wheel',bl_mark='The Mark'}
local wheel_roll,flip_roll=0,0
function pseudoseed(key)return key end
function pseudorandom(key)return key=='wheel' and wheel_roll or flip_roll end
for _,key in ipairs({'bl_small','bl_house','bl_fish','bl_wheel','bl_mark'}) do
 for _,flip in ipairs({0,2,3}) do for _,phase in ipairs({0,1,2}) do
  for _,stone in ipairs({false,true}) do for _,pareidolia in ipairs({'none','joker','consumable'}) do
   cases=cases+1
   local s={hand={{id='held',rank=2,suit='Spades',face_down=true,ability={}}},deck={},hand_size=4,
    blind={key=key,name=names[key],prepped=phase==2},hands_played=phase==2 and 1 or 0,discards_used=phase==1 and 1 or 0,
    jokers={},consumeables={},modifiers=flip>0 and {flipped_cards=flip} or {},probabilities={normal=2}}
   if pareidolia~='none' then local area=pareidolia=='joker' and s.jokers or s.consumeables
    area[1]={key='j_pareidolia',ability={name='Pareidolia'}} end
   for i,rank in ipairs({11,2,13,14}) do
    s.deck[i]={id='deck:'..i,rank=rank,base={id=rank},suit='Spades',face_down=false,
      enhancement=stone and 'm_stone' or 'c_base',ability={effect=stone and 'Stone Card' or 'Base'}}
   end
   for seed=1,8 do
    local actual=assert(B.future_fill(s,{},D,O,seed,phase+1))
    eq(actual.hand[1].face_down,true,'retained hidden card stays hidden')
    eq(#actual.hand+#actual.deck,#s.hand+#s.deck,'draw population conservation')
    G={hand={cards={},config={card_limit=8}},deck={},jokers={cards=s.jokers},consumeables={cards=s.consumeables},
      GAME={modifiers=s.modifiers,probabilities=s.probabilities,current_round={hands_played=s.hands_played,discards_used=s.discards_used}}}
    G.GAME.blind=setmetatable(s.blind,{__index=Blind})
    for i=2,#actual.hand do
     local card=setmetatable(actual.hand[i],{__index=Card});local source_hidden
     function G.hand:emplace(_,_,keep_flipped)source_hidden=not not keep_flipped end
     local from={is=function()return true end,remove_card=function()return card end}
     wheel_roll=O.roll(seed,phase+1,'visibility',card.id)
     flip_roll=O.roll(seed,phase+1,'challenge-visibility',card.id)
     assert(CardArea.draw_card_from(G.hand,from))
     eq(card.face_down,source_hidden,key..' exact source new-card visibility')
    end
   end
  end end
 end end
end
-- The actual CardArea callback does not turn a discarded back face up. The
-- public posterior therefore must retain unknown nondrawable identities.
for _,facing in ipairs({'back','front'}) do
 local card={facing=facing,ability={},set_card_area=function()end,
   flip=function(self)self.facing=self.facing=='back' and 'front' or 'back'end}
 local discard={cards={},config={type='discard',card_limit=52},set_ranks=function()end,align_cards=function()end}
 CardArea.emplace(discard,card)
 eq(card.facing,facing,'source discard orientation does not reveal backs')
end
print('concealed continuation source parity: '..cases..' cases, '..checks..' comparisons')
