local S=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function c(id,r,e) return {id=id,rank=r,suit='Spades',enhancement=e or 'c_base',ability={}} end
local function j(n,a) a=a or {};a.name=n;return {ability=a} end
local a,b,d=c(1,13,'m_glass'),c(2,2,'m_steel'),c(3,3,'m_stone')
local s={hand={a,b},playing_cards={a,b,d},deck={d},discards_left=2,discards_used=0,dollars=10,
 jokers={j('Trading Card',{extra=3}),j('Caino',{caino_xmult=1,extra=1}),j('Glass Joker',{x_mult=1,extra=0.75}),
 j('Steel Joker',{steel_tally=1}),j('Stone Joker',{stone_tally=1}),j("Driver's License",{driver_tally=3})}}
local t,e=assert(S.after_discard(s,{1}))
eq(#t.playing_cards,2);eq(#t.hand,1);eq(#t.deck,1);eq(t.playing_cards[1].id,2)
eq(t.dollars,13);eq(e.population_delta,-1);eq(e.destroyed_indices[1],1);eq(e.destroyed_cards[1].shattered,true)
eq(t.jokers[2].ability.caino_xmult,2);eq(t.jokers[3].ability.x_mult,1.75)
eq(t.jokers[4].ability.steel_tally,1);eq(t.jokers[5].ability.stone_tally,1);eq(t.jokers[6].ability.driver_tally,2)
eq(#s.playing_cards,3);eq(s.hand[1].shattered,nil);eq(s.dollars,10);eq(s.jokers[2].ability.caino_xmult,1)
t=assert(S.after_discard(s,{2}));eq(t.jokers[4].ability.steel_tally,0);eq(t.jokers[2].ability.caino_xmult,1)
a.debuff=true;t=assert(S.after_discard(s,{1}));eq(t.jokers[2].ability.caino_xmult,1);eq(t.jokers[3].ability.x_mult,1.75)
a.debuff=false;s.discards_used=1;t=assert(S.after_discard(s,{1}));eq(#t.playing_cards,3);eq(t.dollars,10)
s.discards_used=0;s.playing_cards={b,d};eq(S.after_discard(s,{1}),nil,'incomplete population rejects')
s.playing_cards={a,a,b};eq(S.after_discard(s,{1}),nil,'duplicate IDs reject')
s.playing_cards={a,b,d};s.jokers[1].debuff=true;t=assert(S.after_discard(s,{1}));eq(#t.playing_cards,3)
local called={}
local prepared={classify=function(snapshot,selected,raw) called.classify=true;return raw(snapshot,selected) end,
 flags=function(jokers,raw) called.flags=true;return raw(jokers) end}
S.score(s,{1},nil,nil,prepared);eq(called.classify,true);eq(called.flags,true)
print('Trading population: '..checks..' checks passed')
