-- Manufactured finite ordinary deck; no player snapshot imported or executed.
local function clone(v)if type(v)~='table' then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
local function j(key,name,a,cost)
 a=a or {};a.name=name;a.set='Joker'
 return {id=key,key=key,name=name,ability=a,blueprint_compat=true,cost=cost or 0,sell_cost=2}
end
local function manufactured()
 local s={phase='shop',ante=5,win_ante=8,dollars=60,bankrupt_at=0,joker_limit=5,consumable_limit=2,
 jokers={j('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=11}),
 j('j_perkeo','Perkeo'),j('j_sly','Sly Joker',{t_chips=50,type='Pair'}),
 j('j_greedy_joker','Greedy Joker',{extra={s_mult=3,suit='Diamonds'}}),
 j('j_trio','The Trio',{x_mult=3,type='Three of a Kind',perishable=true,perish_tally=3,rental=true})},
 consumeables={},hand={},deck={},playing_cards={},shop_jokers={j('j_blueprint','Blueprint',{eternal=true},10)},
 shop_booster={},shop_vouchers={},hand_size=8,hand_limit=5,hands={Pair={level=2,played=5,chips=25,mult=3},['Three of a Kind']={level=3,played=4,chips=70,mult=7}},
 round_resets={hands=4,discards=3},current_round={},blind={key='bl_small',name='Small Blind'},
 next_blind={key='bl_small',name='Small Blind',chips=12000},
 modifiers={scaling=3},probabilities={normal=1},interest_cap=25,reroll_cost=5,consumeable_buffer=0,deck_key='b_red'}
 for _,suit in ipairs({'Hearts','Clubs','Diamonds','Spades'}) do for rank=2,14 do
  s.playing_cards[#s.playing_cards+1]={id='test:'..suit..rank,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit,enhancement='c_base',ability={}}
 end end
 return s
end
local function call(path,nine,cap)
 local S=dofile(path);local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
 local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua');local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
 local L=dofile('Brainstorm/Advisor/liquidity.lua');L.snapshot=Snapshot
 for _,key in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'})do Finish[key]=dofile('Brainstorm/Advisor/'..key..'.lua')end
 Finish.strategy=S;Shop.blind_finishing=Finish;Shop.liquidity=L;Shop.strategy=S
 S.liquidity=L;S.consumables=dofile('Brainstorm/Advisor/consumables.lua')
 S.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua');S.conditional_value.liquidity=L
 S.synergies=dofile('Brainstorm/Advisor/synergies.lua')
 local s=manufactured();if nine then s.hand_size=9;s.used_vouchers={v_paint_brush=true} end;local before=Snapshot.fingerprint(s)
 local context=Shop.new(s,dofile('Brainstorm/Advisor/scoring.lua'),nil,{max_evaluations=cap});local r=S.advise(s,{shop_scoring=context})
 print(path,r.title,r.action.kind,r.action.index or '-',context.evaluations,context.truncated)
 for k,v in pairs(context.metrics)do if type(v)~='table' then print(k,v)end end
 assert(Snapshot.fingerprint(s)==before,'manufactured shop input mutated')
 return r,context
end
call('tools/advisor_eval/development328/scaling_component/strategy_baseline.lua')
call('tools/advisor_eval/development328/scaling_component/strategy_candidate.lua')
call('tools/advisor_eval/development328/scaling_component/strategy_baseline.lua',true)
call('tools/advisor_eval/development328/scaling_component/strategy_candidate.lua',true)
call('tools/advisor_eval/development328/scaling_component/strategy_baseline.lua',false,25000)
call('tools/advisor_eval/development328/scaling_component/strategy_candidate.lua',false,25000)
