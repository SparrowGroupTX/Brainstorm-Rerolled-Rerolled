-- Manufactured offer families, not captured game states.
local P='Brainstorm/Advisor/';local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
local S=dofile(STRATEGY420_PATH or P..'strategy.lua');m.strategy=S
S.conditional_value=dofile(P..'conditional_value.lua')
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=F.state();s.phase='pack';s.ante=2;s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.hand={};s.deck={}
 s.jokers={F.j('j_yorick'),F.j('j_perkeo')};s.jokers[1].ability.x_mult=2
 s.round_resets={hands=4,discards=3};s.next_blind={key='bl_big',label='Big',ante=2,chips=900}
 s.hands={Pair={level=1,played=3,chips=10,mult=2},['High Card']={level=1,played=0,chips=5,mult=1}}
 s.playing_cards={};for i=1,28 do s.playing_cards[i]=F.card('burnt-manufactured:'..i,2+i%13,({'Clubs','Spades','Diamonds','Hearts'})[i%4+1])end
 local b=F.joker('j_burnt','Burnt Joker',{extra=4});b.edition={polychrome=true,type='polychrome',x_mult=1.5}
 b.cost=13;b.sell_cost=6
 local r=F.joker('j_red_card','Red Card',{extra=3});r.ability.effect=nil;r.cost=5
 s.pack_cards={b,r};return s
end
local s=state();local a=S.advise(s)
check(a.action.kind=='choose' and a.action.index==1,'Polychrome Burnt outranks an unscaled Red Card with a real discard horizon')
local value,reason,known=S.owned_joker_value(s,s.pack_cards[1])
check(known and reason:find('First-discard',1,true),'Burnt has explicit qualified growth value instead of generic unknown rating')
local none=F.copy(s);none.round_resets.discards=0
check(S.owned_joker_value(none,none.pack_cards[1])<value,'no available discards removes Burnt growth opportunity')
none=F.copy(s);none.jokers[3]=F.joker('j_burglar','Burglar',{extra=3})
check(S.owned_joker_value(none,none.pack_cards[1])<value,'Burglar removes the discard horizon')
none=F.copy(s);none.ante=8;none.next_blind={key='bl_water',boss=true,ante=8}
check(S.owned_joker_value(none,none.pack_cards[1])<value,'final Water cannot receive nonexistent later discard value')
none.jokers[3]=F.joker('j_chicot','Chicot',{})
check(S.owned_joker_value(none,none.pack_cards[1])>21,'Chicot restores the final-blind growth opportunity')
none=F.copy(s);none.pack_cards[1].ability.perishable=true;none.pack_cards[1].ability.perish_tally=0
check(S.advise(none).action.index~=1,'expired Burnt is not automatically preferred')
none=F.copy(s);none.pack_cards[2].ability.mult=60
check(S.advise(none).action.index==2,'already developed Red Card can still win the complete endpoint comparison')
none=F.copy(s);none.teacher_profile=nil
local _,_,ordinary_known=S.owned_joker_value(none,none.pack_cards[1])
check(not ordinary_known,'other objective profiles retain their prior rating contract')
-- Exercise actual scoring and shared-budget final pack arbitration.
m.shop_scoring=dofile(P..'shop_scoring.lua');m.shop_sequences=dofile(P..'shop_sequences.lua')
local decision=m.decision.run(s,m,nil,{prepared_scoring=false})
check(decision.action.kind=='choose' and decision.action.index==1,'production scored pack chooses Polychrome Burnt over unscaled Red Card')
check(decision.evaluations<=50000 and decision.strategy.pack_diagnostics.complete,'complete production choice stays inside shared shop budget')
local after=S.shop_sequence_api.after_joker_purchase(s,s.pack_cards[decision.action.index])
check(after.jokers[#after.jokers].key=='j_burnt' and after.jokers[#after.jokers].edition.polychrome and after.dollars==s.dollars,
 'the compared free-pack endpoint retains Burnt and its edition without charging its shop sticker price')
print('Burnt valuation420: '..n..' checks passed')
