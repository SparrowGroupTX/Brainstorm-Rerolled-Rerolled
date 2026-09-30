local G=dofile('Brainstorm/Advisor/growth.lua')
local W=dofile('Brainstorm/Advisor/policy_weights.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function c(id,r) return {id=id,rank=r,suit='Spades',enhancement='c_base',ability={}} end
local s={phase='hand',ante=1,blind={chips=1200},chips=0,hands_left=3,hands_played=0,discards_left=3,discards_used=0,
 current_round={},dollars=20,hand_size=5,hand_limit=5,modifiers={},jokers={
 {key='j_joker',ability={name='Joker',mult=100}},
 {key='j_yorick',ability={name='Yorick',x_mult=2,yorick_discards=23,extra={discards=23,xmult=1}}}},
 hand={c('a',14),c('b',2),c('c',3),c('d',4),c('e',5)},deck={},playing_cards={},hands={},consumeables={}}
for _,card in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=card end
local clear=S.score(s,{1});clear.indices={1}
local modules={scoring=S,strategy=Strategy,search=Search}
local original,n=G.suggest(s,modules,clear);eq(original~=nil,true)
G.policy_weights=W
local same,count=G.suggest(s,modules,clear)
eq(same.action.kind,original.action.kind);eq(table.concat(same.action.indices,','),table.concat(original.action.indices,','))
eq(same.merit,original.merit);eq(count,n)
local values=W.values()
G.policy_weights={get=function(key) return values[key] end}
values.growth_action_cost=12;eq(G.suggest(s,modules,clear),nil,'cost can favor immediate finish')
values.growth_action_cost=4;values.growth_utility_scale=.5;eq(G.suggest(s,modules,clear),nil,'low growth weight can favor finish')
values.growth_action_cost=8;values.growth_utility_scale=1;eq(G.suggest(s,modules,clear),nil)
values.growth_utility_scale=1.5;eq(G.suggest(s,modules,clear)~=nil,true,'larger horizon value can justify cost')
clear.score=1201;eq(G.suggest(s,modules,clear),nil,'weights cannot bypass finishing safety gate')
eq(s.jokers[2].ability.yorick_discards,23);eq(W.get('growth_action_cost'),4)
print('weighted growth: '..checks..' checks passed')
