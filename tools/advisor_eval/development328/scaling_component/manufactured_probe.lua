-- Manufactured finite ordinary deck; no player snapshot imported or executed.
local S=dofile('tools/advisor_eval/development328/scaling_component/strategy_probe.lua')
local function j(key,name,a,cost)
 a=a or {};a.name=name;a.set='Joker'
 return {id=key,key=key,name=name,ability=a,blueprint_compat=true,cost=cost or 0,sell_cost=2}
end
local s={phase='shop',ante=5,dollars=60,bankrupt_at=0,joker_limit=5,consumable_limit=2,
 jokers={j('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=11}),
 j('j_perkeo','Perkeo'),j('j_sly','Sly Joker',{t_chips=50,type='Pair'}),
 j('j_greedy_joker','Greedy Joker',{extra={s_mult=3,suit='Diamonds'}}),
 j('j_trio','The Trio',{x_mult=3,type='Three of a Kind',perishable=true,perish_tally=3,rental=true})},
 consumeables={},hand={},deck={},playing_cards={},shop_jokers={j('j_blueprint','Blueprint',{eternal=true},10)},
 shop_booster={},shop_vouchers={},hand_size=8,hand_limit=5,hands={Pair={level=2,played=5},['Three of a Kind']={level=3,played=4}},
 round_resets={hands=4,discards=3},current_round={},blind={key='bl_small',name='Small Blind'},
 modifiers={scaling=3},probabilities={normal=1},interest_cap=25,reroll_cost=5}
for suit_index,suit in ipairs({'Hearts','Clubs','Diamonds','Spades'}) do
 for rank=2,14 do s.playing_cards[#s.playing_cards+1]={id='test:'..suit..rank,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit,enhancement='c_base',ability={}} end
end
local function show(label,r)
 print(label,r.title,r.action.kind,r.action.index or '-',r.action.followup and r.action.followup.index or '-')
 for _,line in ipairs(r.lines or {}) do print(line) end
end
show('bare heuristic',S.advise(s))
S.synergies=dofile('Brainstorm/Advisor/synergies.lua')
S.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua')
S.liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
show('wired heuristic',S.advise(s))
local d=S._debug;local before=d.build(s,d.stats(s));print('beforebuild',before)
for i,c in ipairs(s.jokers) do
 local sold=d.sell(s,i);local cand=d.best(sold,d.stats(sold),d.engine(sold));print('victim',i,c.key,'candidate',cand and cand.card.key,'score',cand and cand.score,'known',cand and cand.known)
 if cand then local after=d.buy(sold,cand.card);local gain=d.build(after,d.stats(after))-before;print('gain',gain,'penalty',d.penalty(sold,cand.card.cost,cand.card,after),'merit',gain-d.penalty(sold,cand.card.cost,cand.card,after)-6) end
end
