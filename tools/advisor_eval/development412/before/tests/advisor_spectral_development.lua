local C=dofile('Brainstorm/Advisor/consumables.lua')
local D=dofile('Brainstorm/Advisor/deck_development.lua');C.deck_development=D
D.spectral=dofile('Brainstorm/Advisor/spectral_development.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(i,r,e) return {id='p'..i,rank=r,nominal=math.min(r,10),suit='Spades',enhancement=e or 'c_base',base={id=r,times_played=7},ability={}} end
local function owned(key,name,extra,negative) return {key=key,edition=negative and {negative=true} or nil,ability={name=name,set='Spectral',extra=extra,consumeable={max_highlighted=1}}} end
local function state(c)
 local s={phase='hand',ante=2,win_ante=8,hand={},playing_cards={},deck={},jokers={},consumeables={c},consumable_limit=2,
  hands={},hand_size=8,hand_limit=5,discards_left=3,hands_left=3,blind={chips=10},chips=0,modifiers={},dollars=20}
 for i=1,20 do local p=card(i,i<=8 and 13 or i%10+2);s.playing_cards[i]=p;if i<=10 then s.hand[i]=p else s.deck[#s.deck+1]=p end end
 return s
end
do
 for _,spec in ipairs({{'c_talisman','Talisman','Gold'},{'c_deja_vu','Deja Vu','Red'},{'c_trance','Trance','Blue'},{'c_medium','Medium','Purple'}}) do
  local s=state(owned(spec[1],spec[2],spec[3]));s.hand[1].seal='Gold'
  local after=assert(C.apply(s,1,{1}))
  eq(after.hand[1].seal,spec[3],spec[2]..' seal replaced');eq(after.playing_cards[1].seal,spec[3],spec[2]..' full population synced')
  eq(after.consumeable_usage_total.spectral,1,'Spectral usage');eq(after.last_tarot_planet,nil,'Spectrals do not replace Fool history')
 end
 local s=state(owned('c_deja_vu','Deja Vu','Blue'));eq(C.apply(s,1,{1}),nil,'modified seal declined')
end
do
 local s=state(owned('c_cryptid','Cryptid',2));s.hand[1].enhancement='m_steel';s.hand[1].seal='Red';s.hand[1].face_down=true;s.hand[1].ability.perma_bonus=25;s.hand[1].edition={polychrome=true}
 s.jokers={{key='j_hologram',ability={name='Hologram',x_mult=1,extra=0.25}},{key='j_blueprint',ability={name='Blueprint'}},{key='j_steel_joker',ability={name='Steel Joker',steel_tally=1}}}
 local a=assert(C.apply(s,1,{1}))
 eq(#a.hand,12,'Cryptid adds two held cards');eq(#a.playing_cards,22,'Cryptid adds full deck population');eq(#a.deck,10,'copies are not unknown draws')
 eq(a.hand[11].seal,'Red','copy retains seal');eq(a.hand[11].ability.perma_bonus,25,'copy retains permanent bonus');eq(a.hand[11].edition.polychrome,true,'copy retains edition')
 eq(a.hand[11].base.times_played,0,'copy base history reset');eq(a.hand[11].face_down,false,'new copy is face up');eq(a.hand[11].id~=a.hand[12].id,true,'unique physical identities')
 eq(a.jokers[1].ability.x_mult,1.5,'two physical additions grow Hologram once each');eq(a.jokers[2].ability.x_mult,nil,'Blueprint does not duplicate permanent growth');eq(a.jokers[3].ability.steel_tally,3,'full Steel tally refreshed')
 eq(#s.hand,10,'copy is detached');s.consumeables[1].ability.extra=3;eq(C.apply(s,1,{1}),nil,'modified copy count declined')
 s.consumeables[1].ability.extra=2;s.playing_cards=s.hand;eq(#assert(C.apply(s,1,{1})).playing_cards,12,'shared fixture arrays do not double insert')
end
do
 local s=state(owned('c_deja_vu','Deja Vu','Red'));s.hand[8].enhancement='m_steel'
 local base=Scoring.score(s,{1,2,3,4,5});base.indices={1,2,3,4,5}
 local use=assert(C.develop(s,Scoring,base,{strategy=S}));eq(use.action.targets[1],8,'Red prefers retained Steel King')
 s=state(owned('c_trance','Trance','Blue'));s.consumeables[2]={key='c_strength',ability={name='Strength',set='Tarot'}}
 base=Scoring.score(s,{1,2,3,4,5});base.indices={1,2,3,4,5}
 use=assert(C.develop(s,Scoring,base,{strategy=S}));eq(use.action.targets[1]>8,true,'Blue prefers off-plan held card')
 s.consumeables[1].edition={negative=true};eq(C.develop(s,Scoring,base,{strategy=S}),nil,'Negative Trance cannot invent a free generation slot')
 s=state(owned('c_medium','Medium','Purple'));s.round_resets={discards=0};eq(D.targets(s,s.consumeables[1],S.build_profile(s),nil,S),nil,'Purple declined without future discards')
 s=state(owned('c_cryptid','Cryptid',2));s.hand[2].enhancement='m_steel';s.hand[2].seal='Red'
 base=Scoring.score(s,{1,3,4,5,6});base.indices={1,3,4,5,6};use=assert(C.develop(s,Scoring,base,{strategy=S}));eq(use.action.targets[1],2,'Cryptid picks reusable upgraded King')
 local candidates=C.rescue_candidates(s,S,1);eq(#candidates,1,'mixed rescue candidate cap');eq(candidates[1].name,'Cryptid','mixed rescue shares exact action model')
 s.hand[1].ability.forced_selection=true;eq(C.apply(s,1,{2}),nil,'forced target legality retained')
end
do
 local s=state(owned('c_cryptid','Cryptid',2));s.blind.chips=100000
 local hand={};for i=1,8 do hand[i]=s.hand[i] end;s.hand=hand
 local calls=0;local scorer={score=function(st,indices) calls=calls+1;return Scoring.score(st,indices) end}
 local _,evaluations=C.suggest(s,scorer,{play={score=0,indices={1},hand='High Card'}},nil,{strategy=S,max_evaluations=700})
 eq(calls<=700,true,'expanded-hand enumeration stays in score budget');eq(evaluations,calls,'expanded-hand scoring work reported exactly')
 eq(calls,637,'one complete ten-card comparison fits while a second is withheld')
 s=state(owned('c_cryptid','Cryptid',2));s.hand={s.hand[1],s.hand[2],s.hand[3]};s.blind.chips=700
 local base=Scoring.score(s,{1,2,3});base.indices={1,2,3}
 local use=C.suggest(s,Scoring,{play=base},nil,{strategy=S,max_evaluations=100})
 eq(use~=nil,true,'Cryptid can rescue a losing three-of-kind by creating five-of-kind')
 eq(use.play.score>=700,true,'new hand indices are scored in a rescue')
end
print('advisor Spectral development: '..checks..' checks passed')
