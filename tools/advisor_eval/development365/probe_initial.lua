-- Independently manufactured: tiny suited population, three-slot row, no seed/log input.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local function j(k,a,c) a=a or {};a.set='Joker';return {id=k,key=k,ability=a,blueprint_compat=true,cost=c or 0,sell_cost=2}end
local s={phase='shop',ante=3,win_ante=8,dollars=80,bankrupt_at=0,joker_limit=3,consumable_limit=8,
 jokers={j('j_yorick',{name='Yorick',x_mult=6,extra={discards=23,xmult=1},yorick_discards=10,eternal=true}),
 j('j_perkeo',{name='Perkeo',eternal=true}),j('j_joker',{name='Joker',mult=4})},
 consumeables={},hand={},deck={},playing_cards={},hands={Flush={level=2,played=5,chips=50,mult=6}},
 shop_jokers={j('j_blueprint',{name='Blueprint'},20)},shop_vouchers={{key='v_grabber',cost=0,ability={set='Voucher'}}},shop_booster={},
 hand_size=8,hand_limit=5,round_resets={hands=3,discards=3},current_round={},modifiers={},probabilities={normal=1},
 blind={key='bl_small',name='Small Blind'},next_blind={key='bl_small',name='Small Blind',chips=18000},interest_cap=25,reroll_cost=5}
for i=1,12 do s.playing_cards[i]={id='manufactured:'..i,rank=i+1,nominal=math.min(10,i+1),suit='Hearts',ability={}}end
for i=1,6 do s.consumeables[i]={id='planet:'..i,key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}end
local ctx=Shop.new(s,Score,nil,{max_evaluations=50000})
local compare=ctx.compare;local evidence
ctx.compare=function(self,b,a)local e=compare(self,b,a);if a.jokers[3].key=='j_blueprint'then evidence=e end;return e end
local result=S.advise(s,{shop_scoring=ctx})
print(result.action.kind,result.action.area,result.action.index,ctx.evaluations,ctx.truncated,evidence and evidence.ratio)
return s,S,Shop,Score,result,ctx
