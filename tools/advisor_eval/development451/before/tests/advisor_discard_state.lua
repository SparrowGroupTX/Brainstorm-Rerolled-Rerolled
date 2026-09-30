local scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1; assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(rank,suit,enhancement)
  return {rank=rank,suit=suit or 'Spades',enhancement=enhancement or 'c_base',ability={}}
end
local function joker(name,ability)
  ability=ability or {}; ability.name=name
  return {name=name,ability=ability,blueprint_compat=true}
end
local function snap(cards,jokers)
  return {hand=cards,jokers=jokers or {},deck={},playing_cards=cards,hands={},dollars=20,
    hands_left=4,discards_left=3,discards_used=0,hand_size=8,joker_limit=5,current_round={},modifiers={},probabilities={normal=1}}
end
local function yorick(counter,threshold,gain)
  return joker('Yorick',{yorick_discards=counter,x_mult=1,extra={discards=threshold or 23,xmult=gain or 1}})
end

local s=snap({card(13),card(12),card(11),card(10),card(9)}, {joker('Blueprint'),yorick(1,2,0.5),joker('Brainstorm')})
s.hand[1].debuff=true
local t,e=scoring.after_discard(s,{5,3,1,2,4})
eq(t.jokers[2].ability.x_mult,2.5,'multiple live Yorick thresholds')
eq(t.jokers[2].ability.yorick_discards,2,'Yorick resets counter per card')
eq(e.yorick_growth,1.5,'growth metadata excludes copies')
eq(s.jokers[2].ability.yorick_discards,1,'input counter remains unchanged')
eq(s.jokers[2].ability.x_mult,1,'input strength remains unchanged')
eq(#s.hand,5,'input hand remains unchanged')
eq(#t.hand,0,'discarded cards leave hand')
eq(t.playing_cards[1].ability.discarded,true,'population discarded state')
eq(t.discards_left,2,'discard resource spent')
eq(t.discards_used,1,'first-discard opportunity spent')
eq(t.current_round.discards_used,1,'nested round count')
s.jokers[2].debuff=true
t=scoring.after_discard(s,{1})
eq(t.jokers[2].ability.x_mult,1,'debuffed Yorick does not grow')
s.jokers[2].debuff=false
s.jokers[2].ability.yorick_discards=nil
eq(scoring.after_discard(s,{1}),nil,'missing live counter fails closed')

s=snap({card(7),card(7,'Hearts'),card(7,'Clubs'),card(2),card(2,'Hearts'),card(14)},
  {joker('Blueprint'),joker('Burnt Joker'),joker('Brainstorm')})
s.hands['Full House']={level=2,chips=65,mult=6,s_chips=40,s_mult=4,l_chips=25,l_mult=2,played=7,played_this_round=1,visible=false}
t,e=scoring.after_discard(s,{5,4,3,2,1})
eq(e.burnt_hand,'Full House','actual Full House category')
eq(e.burnt_levels,3,'Burnt valid copy chain')
eq(t.hands['Full House'].level,5,'Burnt copies upgrade level')
eq(t.hands['Full House'].chips,140,'Burnt level chips')
eq(t.hands['Full House'].mult,12,'Burnt level mult')
eq(t.hands['Full House'].played,7,'upgrade does not count as played')
eq(t.hands['Full House'].played_this_round,1,'upgrade preserves round usage')
eq(t.hands['Full House'].visible,false,'upgrade does not unlock hand visibility')
eq(t.hands.Pair,nil,'contained Pair not upgraded')
eq(s.hands['Full House'].level,2,'input level remains unchanged')
eq(#t.hand,1,'remaining card retained')
eq(t.hand[1].rank,14,'correct card retained')
s.discards_used=1
t,e=scoring.after_discard(s,{1,2})
eq(e.burnt_levels,0,'second discard does not upgrade')
s.discards_used=0
s.jokers[2].debuff=true
t,e=scoring.after_discard(s,{1,2})
eq(e.burnt_levels,0,'debuffed Burnt cannot be copied')
s.jokers[2].debuff=false; s.jokers[1].debuff=true
t,e=scoring.after_discard(s,{1,2})
eq(e.burnt_levels,1,'debuffed intermediate blocks copied chain')
s.jokers={joker('Blueprint'),joker('Brainstorm')}
t,e=scoring.after_discard(s,{1,2})
eq(e.burnt_levels,0,'copy loop terminates')
s.jokers={joker('Burnt Joker')}; s.discards_left=0; s.modifiers.discard_cost=5
t,e=scoring.after_discard(s,{1,2},{hook=true})
eq(e.burnt_levels,0,'Hook never triggers Burnt')
eq(t.discards_left,0,'Hook does not spend discard')
eq(t.discards_used,0,'Hook does not spend first discard')
eq(t.dollars,20,'Hook is free')
eq(scoring.after_discard(s,{1}),nil,'normal discard needs resource')
s.discards_left=3; s.hand={card(10),card(11),card(12),card(13),card(14)}
t,e=scoring.after_discard(s,{1,2,3,4,5})
eq(e.burnt_hand,'Straight Flush','Royal uses Straight Flush')
eq(t.hands['Straight Flush'].level,2,'missing vanilla hand uses defaults')
s.blind={name='The Mouth',only_hand='Pair'}
t,e=scoring.after_discard(s,{1,2,3,4,5})
eq(e.burnt_hand,'Straight Flush','play restriction does not forbid discard upgrade')

s=snap({card(11),card(11,'Hearts'),card(12)}, {joker('Blueprint'),joker('Green Joker',{mult=5,extra={discard_sub=2}}),
  joker('Ramen',{x_mult=1.015,extra=0.01}),joker('Joker Stencil'),joker('Swashbuckler')})
s.jokers[3].edition={negative=true};s.jokers[3].ability.eternal=true;s.joker_limit=6
s.jokers[1].sell_cost=4;s.jokers[2].sell_cost=2;s.jokers[3].sell_cost=5;s.jokers[4].sell_cost=3
s.modifiers={discard_cost=2,minus_hand_size_per_X_dollar=5};s.dollars=20
s.hand[1].ability.forced_selection=true
eq(scoring.after_discard(s,{2,3}),nil,'ordinary discard includes forced Bell card')
t=scoring.after_discard(s,{1,2})
eq(t.jokers[2].ability.mult,3,'Green loses once despite multiple cards/copy')
eq(#t.jokers,4,'Ramen expires even if eternal')
eq(t.joker_limit,5,'Negative Ramen removes extra slot')
eq(t.jokers[3].ability.x_mult,2,'Stencil capacity after Ramen expires')
eq(t.jokers[4].ability.mult,9,'Swashbuckler after Ramen expires')
eq(t.dollars,18,'discard cost once per action')
eq(t.hand_size,9,'paid discard adjusts Luxury Tax hand size')
eq(t.hand[1].ability.forced_selection,nil,'discard clears Bell forcing')
eq(s.hand[1].ability.forced_selection,true,'input forced flag unchanged')

s=snap({card(11,'Hearts'),card(11,'Diamonds'),card(12,'Hearts')},
  {joker('Blueprint'),joker('Mail-In Rebate',{extra=5}),joker('Castle',{extra={chips=0,chip_mod=3}}),
    joker('Hit the Road',{x_mult=1,extra=0.5}),joker('Faceless Joker',{extra={faces=3,dollars=5}}),joker('Smeared Joker')})
s.current_round={mail_card={id=11},castle_card={suit='Hearts'}}
t,e=scoring.after_discard(s,{1,2,3})
eq(e.dollars,25,'copied Mail and Faceless payouts')
eq(t.jokers[3].ability.extra.chips,9,'Castle uses Smeared suits')
eq(t.jokers[4].ability.x_mult,2,'Hit Road per Jack')
s.hand[2].debuff=true
t,e=scoring.after_discard(s,{1,2,3})
eq(e.dollars,10,'debuffed cards excluded from Mail and Faceless')
eq(t.jokers[3].ability.extra.chips,6,'debuffed card excluded from Castle')
eq(t.jokers[4].ability.x_mult,1.5,'debuffed Jack excluded from Hit Road')

s=snap({card(14),card(2)}, {joker('Trading Card',{extra=3})})
eq(scoring.after_discard(s,{1}),nil,'Trading destruction fails closed')
eq(type(scoring.after_discard(s,{1,2})),'table','Trading non-trigger can transition')
s.jokers={};s.hand[1].seal='Purple'
eq(scoring.after_discard(s,{1}),nil,'selected Purple generation fails closed')
eq(type(scoring.after_discard(s,{2})),'table','retained Purple does not block transition')
eq(scoring.after_discard(s,{2,2}),nil,'duplicate rejected')
eq(scoring.after_discard(s,{}),nil,'empty rejected')
eq(scoring.after_discard(s,{3}),nil,'invalid index rejected')

s=snap({card(13,'Spades','m_glass'),card(2,'Hearts'),card(3,'Clubs','m_glass')},{joker('Hanging Chad',{extra=2})})
local r=scoring.score(s,{1,2})
eq(r.glass_loss,0.25,'single scoring Glass one roll despite retriggers')
eq(#r.glass_exposure,1,'unscored or held Glass does not roll')
eq(r.glass_exposure[1].index,1,'Glass exposure index')
s.hand[1].ability.extra=2;s.probabilities.normal=4
eq(scoring.score(s,{1}).glass_loss,1,'live Fragile probability clamps to certainty')
s.hand[1].debuff=true
eq(scoring.score(s,{1}).glass_loss,0,'debuffed Glass does not break')
s.hand[1].debuff=false;s.jokers={joker('Vampire',{x_mult=1,extra=0.1})}
eq(scoring.score(s,{1}).glass_loss,0,'Vampire strips Glass before destruction')
s.jokers={joker('Midas Mask')}
eq(scoring.score(s,{1}).glass_loss,0,'Midas replaces Glass before destruction')

-- A live next-hand score changes only because exact discard growth is carried.
s=snap({card(2),card(14)}, {joker('Blueprint'),yorick(1)})
eq(scoring.score(s,{2}).score,16,'before Yorick threshold cannot clear 30')
t=scoring.after_discard(s,{1})
eq(scoring.score(t,{1}).score,64,'after threshold physical and copied strength clear 30')
local original_random=math.random
math.random=function() error('detached transition used global RNG') end
eq(type(scoring.after_discard(s,{1})),'table','transition avoids global RNG')
math.random=original_random
print('advisor discard state: '..checks..' checks passed')
