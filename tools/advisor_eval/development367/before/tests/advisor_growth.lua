local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={scoring=Scoring,strategy=Strategy,search=Search,consumables=Consumables}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank,suit) return {id=id,rank=rank,suit=suit or 'Spades',enhancement='c_base',ability={}} end
local function joker(key,name,ability) ability=ability or {};ability.name=name;return {key=key,name=name,ability=ability,blueprint_compat=true} end
local function state()
  local s={phase='hand',ante=1,blind={chips=1200},chips=0,hands_left=3,hands_played=0,discards_left=3,discards_used=0,
    current_round={},dollars=20,hand_size=5,hand_limit=5,modifiers={},jokers={joker('j_joker','Joker',{mult=100})},
    hand={card('a',14),card('b',2,'Hearts'),card('c',3,'Clubs'),card('d',4,'Diamonds'),card('e',5,'Hearts')},
    deck={},hands={},consumeables={},probabilities={normal=1}}
  for i=1,12 do s.deck[i]=card('k'..i,i<=8 and 13 or 6,i%2==0 and 'Hearts' or 'Spades') end
  s.playing_cards={};for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end
  for _,c in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=c end
  s.hands['Four of a Kind']={level=3,chips=120,mult=13,l_chips=30,l_mult=3,played=9,visible=true}
  return s
end
local function clear(s,indices)
  local p=Scoring.score(s,indices or {1});p.indices=indices or {1};return p
end
local function suggest(s,p,options) return Growth.suggest(s,modules,p or clear(s),options) end

local s=state();s.jokers[#s.jokers+1]=joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}})
local g,n,d=suggest(s)
check(g and g.action.kind=='discard','safe early state invests one Yorick discard')
eq(#g.action.indices,4,'larger discard values residual Yorick progress')
eq(g.growth.effects.yorick_growth,0,'residual progress does not invent immediate XMult')
check(n<=12 and d.bounded_growth,'fixed score budget')
local after=Scoring.after_discard(s,g.action.indices)
eq(after.jokers[2].ability.yorick_discards,19,'exact progress matches selected count')
check(Scoring.score(after,g.play.indices).score>=s.blind.chips,'retained finish works without favorable draw')
eq(s.jokers[2].ability.yorick_discards,23,'growth does not mutate input')
s.hands_played=1
check(suggest(s)~=nil,'Yorick can invest after a play if the retained clear is still safe')
s.hands_played=0;s.discards_used=1
check(suggest(s)~=nil,'Yorick can invest remaining discards after a real draw')
s.discards_used=0;s.ante=8;s.blind.boss=true
eq(suggest(s),nil,'final challenge blind finishes now')
s.ante=1;s.blind.boss=false;s.blind.chips=1550
eq(suggest(s),nil,'fragile marginal clear does not invest')
s.blind.chips=1200;s.modifiers.discard_cost=10
eq(suggest(s),nil,'paid-discard costs can reverse growth')
s.modifiers={};s.jokers[2].ability.x_mult=20
eq(suggest(s),nil,'mature distant Yorick growth can be worth less than action cost')
s.jokers[2].ability.x_mult=1;s.jokers[2].ability.yorick_discards=1
g=suggest(s)
check(g and g.growth.effects.yorick_growth==1,'near-threshold investment uses exact growth')
s.jokers[#s.jokers+1]=joker('j_blackboard','Blackboard',{extra=3})
eq(suggest(s),nil,'Blackboard draw dependency fails closed')
s.jokers[#s.jokers]=joker('j_raised_fist','Raised Fist')
eq(suggest(s),nil,'Raised Fist draw dependency fails closed')
s.jokers[#s.jokers]=joker('j_blue_joker','Blue Joker',{extra=2})
eq(suggest(s),nil,'Blue Joker deck depletion cannot invalidate the retained clear')
s.jokers[#s.jokers]=joker('j_shoot_the_moon','Shoot the Moon')
eq(suggest(s),nil,'automatic held-card sorting cannot reorder Moon and Steel arithmetic')
s.jokers[#s.jokers]=nil;s.blind.key='bl_final_bell'
eq(suggest(s),nil,'Bell draw-forcing hazard fails closed')
s.blind.key=nil;s.hand[2].seal='Purple';s.hand[3].seal='Purple';s.hand[4].seal='Purple';s.hand[5].seal='Purple'
eq(suggest(s),nil,'unsupported discard generation fails closed')

s=state();s.jokers[#s.jokers+1]=joker('j_burnt','Burnt Joker')
s.hand={card('a',14),card('b',7,'Hearts'),card('c',7,'Clubs'),card('d',7),card('e',2,'Hearts'),card('f',2)}
s.hands.Pair={level=1,chips=10,mult=2,l_chips=15,l_mult=1,played=5}
s.hands['Three of a Kind']={level=1,chips=30,mult=3,l_chips=20,l_mult=2,played=0}
s.hands['Full House']={level=12,chips=315,mult=26,l_chips=25,l_mult=2,played=20}
g=suggest(s)
check(g and g.growth.effects.burnt_hand=='Pair','Burnt marginal gain can favor attainable Pair over highest-level most-used Full House: '..tostring(g and g.growth.effects.burnt_hand))
s.hands.Pair={level=20,chips=295,mult=21,l_chips=15,l_mult=1,played=5}
s.jokers[#s.jokers+1]=joker('j_zany','Zany Joker',{type='Three of a Kind',t_mult=12})
g=suggest(s)
check(g and g.growth.effects.burnt_hand=='Three of a Kind','Burnt selection changes with levels and conditional Joker: '..tostring(g and g.growth.effects.burnt_hand))
s.discards_used=1
eq(suggest(s),nil,'Burnt investment stops after first discard')

s=state();s.consumeables={{key='c_death',ability={name='Death',set='Tarot'}}}
for _,c in ipairs(s.deck) do c.face_down=true end
g,n,d=suggest(s)
check(g and g.action.kind=='play' and g.growth.kind=='death_cycle','strong early state cycles for missing Death source')
check(g~=nil,'ordinary face-down deck orientation does not prevent safe investment')
check(g.growth.target_probability>0 and g.growth.target_probability<=1,'Death draw chance uses composition')
eq(g.growth.target_probability,Growth.hit_probability(#s.deck,g.growth.eligible_targets,g.growth.draws),'Death probability follows eligible pool and actual draws')
check(g.growth.draws>0,'Death plan has actual future draws')
for _,index in ipairs(g.action.indices) do check(index~=1 and index~=g.growth.recipient_original_index,'setup preserves finish and Death recipient') end
local setup=Scoring.score(s,g.action.indices)
check(setup.score<s.blind.chips,'setup does not end blind before planned draw')
after=Scoring.after_play(s,g.action.indices)
check(after.hands_left>=1,'setup reserves finishing hand')
check(Scoring.score(after,g.play.indices).score>=s.blind.chips-after.chips,'retained finish survives target-search miss')
eq(s.hands_played,0,'setup projection does not mutate input')
check(n<=12,'Death setup/internal transition/finish scores fit cap')
s.hand[2].rank=13
eq(suggest(s),nil,'existing useful Death source prevents unnecessary cycling')
s.hand[2].rank=2
s.deck={};for i=1,12 do s.deck[i]=card('weak'..i,2) end
eq(suggest(s),nil,'no eligible drawable targets prevents cycling')
s=state();s.consumeables={{key='c_death',ability={name='Death',set='Tarot'}}};s.blind.chips=500
eq(suggest(s),nil,'every setup already clears: no future draw claimed')
s.blind.chips=1200;s.modifiers.debuff_played_cards=true
eq(suggest(s),nil,'permanent card damage prohibits setup investment')
s.modifiers={};s.jokers[#s.jokers+1]=joker('j_perkeo','Perkeo')
eq(suggest(s),nil,'Perkeo last useful Death source retained')
s.jokers[#s.jokers]=nil;s.hands_left=1
eq(suggest(s),nil,'single remaining hand never burned looking for source')
s.hands_left=3;s.hand[3].enhancement='m_glass';s.hand[4].enhancement='m_glass';s.hand[5].enhancement='m_glass'
eq(suggest(s),nil,'Glass setup exposure rejected')
s=state();s.jokers[#s.jokers+1]=joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}})
s.hand[2].rank=14;s.hand[2].enhancement='m_mult'
eq(suggest(s,clear(s,{1,2})),nil,'multiple scoring cards with order-sensitive enhancement fail closed')
s.hand[2].enhancement='c_base';s.jokers[#s.jokers+1]=joker('j_hanging_chad','Hanging Chad',{extra=2})
eq(suggest(s,clear(s,{1,2})),nil,'Hanging Chad first-card chips cannot be invalidated by automatic sorting')
s.jokers[#s.jokers]=nil;s.modifiers.flipped_cards=4
eq(suggest(s),nil,'randomly concealed draw modifier prevents investment')
s.modifiers={};s.deck={};for i=1,201 do s.deck[i]=card('big'..i,13) end
eq(suggest(s),nil,'unusually large decks cannot exceed bounded development scan')
s=state();s.consumeables={{key='c_death',ability={name='Death',set='Tarot'}}}
local original=Scoring.score;local calls=0
Scoring.score=function(...) calls=calls+1;return original(...) end
local p=clear(s);calls=0
g,n=Growth.suggest(s,modules,p,{max_evaluations=3})
check(calls<=3 and n<=3,'actual scorer calls including after_play obey caller cap')
eq(calls,n,'reported calls include transition-internal scoring')
Scoring.score=original
local real_modules={scoring=Scoring,strategy=Strategy,search=Search,consumables=Consumables,growth=Growth,
  ordering=dofile('Brainstorm/Advisor/ordering.lua'),hand_ordering=dofile('Brainstorm/Advisor/hand_ordering.lua'),
  boss_rescue=dofile('Brainstorm/Advisor/boss_rescue.lua'),economy=dofile('Brainstorm/Advisor/economy.lua'),
  shop_scoring=dofile('Brainstorm/Advisor/shop_scoring.lua')}
s=state();s.jokers[#s.jokers+1]=joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}})
calls=0;Scoring.score=function(...) calls=calls+1;return original(...) end
local decision=Decision.run(s,real_modules)
Scoring.score=original
check(decision.fast_clear and decision.growth,'real decision takes bounded growth fast path')
eq(decision.action,decision.growth.action,'published action is the completed growth action')
check(calls<=66 and decision.evaluations<=66,'whole real decision and transition-internal scores stay bounded')
eq(calls,decision.evaluations,'whole real decision reports actual scoring work')
eq(Growth.hit_probability(10,2,2),1-(8/10)*(7/9),'without-replacement draw odds')
eq(Growth.hit_probability(10,0,3),0,'no target probability')
eq(Growth.hit_probability(10,10,1),1,'certain target probability')
print('advisor growth: '..checks..' checks passed')
