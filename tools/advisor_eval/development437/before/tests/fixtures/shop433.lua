-- Shared invented-fixture wiring, not a production or captured-state adapter.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules();local P='Brainstorm/Advisor/'
for _,name in ipairs({'shop_scoring','shop_sequences','blind_finishing','liquidity','joker_plan','pack_survival','paired_deck'})do m[name]=dofile(P..name..'.lua')end
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'})do
 m[name]=m[name] or dofile(P..name..'.lua');m.blind_finishing[name]=m[name]
end
m.blind_finishing.strategy=m.strategy;m.blind_finishing.pack_survival=m.pack_survival
m.shop_scoring.blind_finishing=m.blind_finishing;m.shop_scoring.paired_deck=m.paired_deck;m.shop_scoring.strategy=m.strategy
m.liquidity.snapshot=m.snapshot;m.strategy.liquidity=m.liquidity;m.shop_scoring.liquidity=m.liquidity
m.strategy.joker_plan=m.joker_plan;m.strategy.pack_survival=m.pack_survival
local centers={};for _,j in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do centers[j.key]=j end
local function joker(key,id)
 local j=F.copy(assert(centers[key]));j.id=id or key;j.sell_cost=2;return j
end
local function state()
 local s=F.state(false);s.phase='shop';s.hand={};s.deck={};s.playing_cards={};s.hand_size=5
 for i=1,24 do s.playing_cards[i]=F.card('shop433:'..i,7,'Clubs')end
 s.hands={Pair={chips=55,mult=5,level=4,played=8,l_chips=15,l_mult=1}}
 s.jokers={};s.shop_jokers={};s.shop_booster={};s.shop_vouchers={};s.consumeables={}
 s.round_resets={hands=3,discards=3};s.current_round={};s.ante=4;s.dollars=29;s.joker_limit=5
 s.next_blind={key='bl_big',name='Big Blind',chips=1200,ante=4};s.reroll_cost=7
 s.bankrupt_at=0;s.interest_cap=25;s.interest_amount=1;return s
end
return {F=F,m=m,joker=joker,state=state}
