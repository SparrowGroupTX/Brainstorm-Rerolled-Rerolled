local S=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function c(id,r,e) return {id=id,rank=r,suit='Spades',enhancement=e or 'c_base',ability={},base={id=r,times_played=4,original_value='Queen'}} end
local function j(n,a) a=a or {};a.name=n;return {ability=a} end
local a,b=c(1,13,'m_steel'),c(2,2)
local s={hand={a,b},playing_cards={a,b},deck={},hands_left=4,hands_played=0,jokers={j('DNA'),j('Baron',{extra=1.5}),j('Hologram',{x_mult=1,extra=0.25})}}
local result=S.score(s,{1});eq(result.score,42);eq(result.uncertain,false)
local t,e=assert(S.after_play(s,{1}));eq(#t.hand,2);eq(#t.playing_cards,3);eq(e.created_count,1);eq(e.population_delta,1)
eq(t.jokers[3].ability.x_mult,1.25);eq(t.hand[2].rank,13);eq(t.hand[2].enhancement,'m_steel')
eq(t.hand[2].base.times_played,0);eq(t.hand[2].base.original_value,nil);eq(t.hand[2].ability.played_this_ante,true)
eq(t.hand[2].id==a.id,false);eq(t.playing_cards[1].base.times_played,5);eq(a.base.times_played,4);eq(#s.hand,2)
s.jokers={j('Blueprint'),j('DNA'),j('Brainstorm'),j('Hologram',{x_mult=1,extra=0.25})}
t,e=assert(S.after_play(s,{1}));eq(e.created_count,3);eq(#t.hand,4);eq(t.jokers[4].ability.x_mult,1.75)
eq(t.hand[2].id~=t.hand[3].id and t.hand[3].id~=t.hand[4].id,true)
s.jokers[2].debuff=true;t,e=assert(S.after_play(s,{1}));eq(e.created_count,0)
s.jokers={j('DNA')};s.hands_played=1;t,e=assert(S.after_play(s,{1}));eq(e.created_count,0)
s.hands_played=0;t,e=assert(S.after_play(s,{1,2}));eq(e.created_count,0)
s.jokers={j('DNA'),j('Vampire',{x_mult=1,extra=0.1})};t=assert(S.after_play(s,{1}));eq(t.hand[2].enhancement,'m_steel');eq(t.playing_cards[1].enhancement,'c_base')
s.jokers={j('Vampire',{x_mult=1,extra=0.1}),j('DNA')};t=assert(S.after_play(s,{1}));eq(t.hand[2].enhancement,'c_base')
s.jokers={j('DNA'),j('Hiker',{extra=5})};t=assert(S.after_play(s,{1}));eq(t.hand[2].ability.perma_bonus,nil);eq(t.playing_cards[1].ability.perma_bonus,5)
s.playing_cards={b};eq(S.after_play(s,{1}),nil);eq(S.score(s,{1}).uncertain,true)
s.playing_cards={a,b};a.enhancement='m_glass';s.probabilities={normal=4};t,e=assert(S.after_play(s,{1}));eq(e.population_delta,0);eq(#t.playing_cards,2);eq(t.hand[2].shattered,nil)
print('DNA population: '..checks..' checks passed')
