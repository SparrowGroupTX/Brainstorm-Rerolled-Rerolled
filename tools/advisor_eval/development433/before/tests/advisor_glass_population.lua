local S=dofile('Brainstorm/Advisor/scoring.lua')
local Copy=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,r,e) return {id=id,rank=r,suit='Spades',enhancement=e or 'c_base',ability={extra=4}} end
local function joker(n,a) a=a or {};a.name=n;return {name=n,ability=a,blueprint_compat=true} end
local function snap()
  local h={card('king',13,'m_glass'),card('low',2,'m_glass'),card('held',3,'m_glass')}
  local d={card('draw',8,'m_glass')}
  local p=Copy.copy(h);p[#p+1]=Copy.copy(d[1])
  return {hand=h,deck=d,playing_cards=p,jokers={},hands={},hands_left=3,hands_played=1,
    chips=0,dollars=5,hand_size=8,probabilities={normal=4},current_round={}}
end
local function after(s,sel,context)
  local before=Copy.fingerprint(s)
  local state,effects=S.after_play(s,sel,context)
  eq(Copy.fingerprint(s),before,'input remains detached')
  assert(state,effects);return state,effects
end
math.random=function() error('no global RNG') end
pseudorandom=function() error('no game RNG') end
local s=snap();local t,e=after(s,{1,2})
eq(#t.hand,1,'both selected leave hand')
eq(t.hand[1].id,'held','held Glass survives')
eq(#t.playing_cards,3,'only scored Glass removed from population')
eq(t.playing_cards[1].id,'low','unscored played Glass remains')
eq(#t.deck,1,'remaining draw population unchanged')
eq(t.deck[1].id,'draw','draw Glass survives')
eq(#e.destroyed_indices,1,'one destruction roll despite played extras')
eq(e.destroyed_indices[1],1,'correct scoring card destroyed')
eq(e.population_delta,-1,'population metadata')
eq(e.destroyed_cards[1].shattered,true,'shattered metadata')
eq(t.chips,S.score(s,{1,2}).score,'destroying happens after immediate scoring')

s=snap();s.jokers={joker('Glass Joker',{x_mult=1,extra=0.75}),joker('Caino',{caino_xmult=1,extra=1}),
  joker('Blueprint'),joker('Caino',{caino_xmult=2,extra=2}),joker("Driver's License",{driver_tally=4,extra=3})}
s.modifiers={debuff_played_cards=true}
t=after(s,{1})
eq(t.jokers[1].ability.x_mult,1.75,'Glass Joker grows after shatter')
eq(t.jokers[2].ability.caino_xmult,2,'Canio counts face before permanent debuff')
eq(t.jokers[4].ability.caino_xmult,4,'Blueprint does not duplicate destruction growth')
eq(t.jokers[5].ability.driver_tally,3,'License loses destroyed enhancement')
eq(t.chips,S.score(s,{1}).score,'new destruction growth does not alter completed score')
t.hand={card('next',14)}
eq(S.score(t,{1}).score,896,'future score uses grown physical and copied Canio')
s.jokers[1].debuff=true;s.jokers[2].debuff=true;s.jokers[4].debuff=true
t=after(s,{1});eq(t.jokers[1].ability.x_mult,1,'debuffed Glass Joker stays fixed');eq(t.jokers[2].ability.caino_xmult,1,'debuffed Canio stays fixed')

s=snap();s.jokers={joker('Pareidolia'),joker('Caino',{caino_xmult=1,extra=1})}
t=after(s,{2});eq(t.jokers[2].ability.caino_xmult,2,'Pareidolia destroyed rank counts as face')
s.jokers[1].debuff=true;t=after(s,{2});eq(t.jokers[2].ability.caino_xmult,1,'debuffed Pareidolia does not count non-face')

s=snap();s.probabilities.normal=1
local state,why=S.after_play(s,{1});eq(state,nil,'unknown Glass outcome blocked');eq(not not why:match('Glass'),true,'Glass blocker explained')
t,e=after(s,{1},{glass_outcomes={[1]=false}});eq(#t.playing_cards,4,'explicit sampled survival');eq(e.sampled_glass,true,'sampled state labeled')
t=after(s,{1},{glass_outcomes={[1]=true}});eq(#t.playing_cards,3,'explicit sampled destruction')
state=S.after_play(s,{1},{glass_outcomes={[1]=1}});eq(state,nil,'truthy non-boolean sample rejected')
s.probabilities.normal=0;t=after(s,{1},{glass_outcomes={[1]=true}});eq(#t.playing_cards,4,'zero chance cannot be forced to break')
s.probabilities.normal=4;t=after(s,{1},{glass_outcomes={[1]=false}});eq(#t.playing_cards,3,'certain destruction cannot be forced to survive')
s.hand[1].debuff=true;t=after(s,{1});eq(#t.playing_cards,4,'debuffed Glass survives')
s.hand[1].debuff=false;s.hand[1].ability.extra=8;state=S.after_play(s,{1});eq(state,nil,'live denominator overrides challenge certainty')
s.hand[1].ability.extra=2;s.probabilities.normal=2;t=after(s,{1});eq(#t.playing_cards,3,'custom live odds reach certainty')

s=snap();s.jokers={joker('Vampire',{x_mult=1,extra=0.1})};t=after(s,{1});eq(#t.playing_cards,4,'Vampire prevents Glass destruction');eq(t.playing_cards[1].enhancement,'c_base','stripped card persists')
s.jokers={joker('Midas Mask')};t=after(s,{1});eq(#t.playing_cards,4,'Midas prevents Glass destruction');eq(t.playing_cards[1].enhancement,'m_gold','replacement enhancement persists')
s=snap();s.jokers={joker('Splash'),joker('Glass Joker',{x_mult=1,extra=0.75})};t,e=after(s,{1,2});eq(#t.playing_cards,2,'Splash destroys both scored Glass');eq(t.jokers[2].ability.x_mult,2.5,'one growth per shattered card')
s=snap();s.jokers={joker('Hanging Chad',{extra=2}),joker('Glass Joker',{x_mult=1,extra=0.75})};s.hand[1].seal='Red';t,e=after(s,{1});eq(#e.destroyed_cards,1,'retriggers do not multiply destruction');eq(t.jokers[2].ability.x_mult,1.75,'retriggered Glass grows once')
print('advisor Glass population: '..checks..' checks passed')
