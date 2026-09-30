local P='Brainstorm/Advisor/';local F=dofile('tests/fixtures/retained418.lua');local m=F.modules();local S=m.strategy
S.joker_plan=dofile(P..'joker_plan.lua');S.conditional_value=dofile(P..'conditional_value.lua');S.synergies=dofile(P..'synergies.lua')
m.shop_scoring=dofile(P..'shop_scoring.lua');m.shop_sequences=dofile(P..'shop_sequences.lua')
local n=0;local function check(x,t)n=n+1;assert(x,t)end
local centers={};for _,c in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do centers[c.key]=c end
local function card(k)local c=F.copy(centers[k]);c.id=k;c.ability.mult=c.ability.mult or 0;c.ability.t_chips=c.ability.t_chips or 0;c.sell_cost=2;return c end
local function state()
 local s=F.state();s.phase='pack';s.ante=2;s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.hand={};s.deck={}
 s.jokers={F.j('j_yorick'),F.j('j_perkeo')};s.jokers[1].ability.x_mult=2
 s.round_resets={hands=4,discards=3};s.next_blind={key='bl_big',label='Big',ante=2,chips=900}
 s.hands={Pair={level=3,played=12,chips=40,mult=4},['High Card']={level=1,played=0,chips=5,mult=1}}
 s.playing_cards={};for i=1,24 do s.playing_cards[i]=F.card('decision:'..i,13,({'Clubs','Spades','Diamonds','Hearts'})[i%4+1],i%3==0 and 'm_mult' or 'c_base')end
 return s
end
local function choose(s,k)
 local a=m.decision.run(s,m,nil,{prepared_scoring=false})
 check(a.action.kind=='choose' and s.pack_cards[a.action.index].key==k,'complete production pack chose '..k..', got '..tostring(a.action.kind)..':'..tostring(a.action.index))
 check(a.evaluations<=50000 and a.strategy.pack_diagnostics.complete,'complete shared-budget comparison')
 local after=S.shop_sequence_api.after_joker_purchase(s,s.pack_cards[a.action.index]);check(after.dollars==s.dollars and after.jokers[#after.jokers].key==k,'free endpoint retains selected card')
 return a
end
local s=state();s.pack_cards={card('j_red_card'),card('j_hanging_chad')};choose(s,'j_hanging_chad')
s=state();s.pack_cards={card('j_order'),card('j_duo')};choose(s,'j_duo')
s=state();s.pack_cards={card('j_hack'),card('j_triboulet')};choose(s,'j_triboulet')
s=state();s.pack_cards={card('j_red_card'),card('j_burnt')};s.pack_cards[2].edition={polychrome=true,type='polychrome',x_mult=1.5};choose(s,'j_burnt')
-- Full row uses the same contextual values at both physical sale endpoints.
s=state();s.jokers[#s.jokers+1]=card('j_order');s.joker_limit=3;s.pack_cards={card('j_duo')}
local a=S.advise(s)
check(a.action.kind=='sell' and a.action.index==3,'unsupported Straight effect is the replacement victim, preserving core')
local sold=S.shop_sequence_api.after_joker_sale(s,3);check(sold and #sold.jokers==2 and sold.jokers[1].key=='j_yorick' and sold.jokers[2].key=='j_perkeo','sale model preserves core')
local acquired=S.shop_sequence_api.after_joker_purchase(sold,s.pack_cards[1]);check(S.shop_sequence_api.replacement_value(acquired)>S.shop_sequence_api.replacement_value(s),'whole-row utility agrees with incoming pair upgrade')
print('Joker decisions421: '..n..' checks passed')
