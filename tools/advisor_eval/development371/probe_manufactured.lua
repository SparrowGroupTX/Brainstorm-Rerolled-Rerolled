-- Independent tiny manufactured shop/pack probes; no captured game state.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local function j(key,name,a,cost,sell)
  a=a or {};a.set='Joker';a.name=name
  return {id='manufactured:'..key,key=key,ability=a,blueprint_compat=true,cost=cost or 0,sell_cost=sell or 2}
end
local s={phase='shop',ante=2,win_ante=8,teacher_profile='perkeo_yorick_win_v1',dollars=9,bankrupt_at=0,
  joker_limit=5,consumable_limit=2,jokers={
    j('j_yorick','Yorick',{x_mult=6,extra={discards=23,xmult=1},yorick_discards=17}),
    j('j_perkeo','Perkeo',{}),
    j('j_ice_cream','Ice Cream',{extra={chips=5,chip_mod=5}},0,2)},
  consumeables={},hand={},deck={},playing_cards={},hands={Flush={level=2,played=4,chips=50,mult=6}},
  shop_jokers={j('j_blueprint','Blueprint',{},10)},shop_vouchers={},shop_booster={},
  hand_size=8,hand_limit=5,round_resets={hands=3,discards=3},current_round={},modifiers={},probabilities={normal=1},
  blind={key='bl_small',name='Small Blind'},next_blind={key='bl_small',name='Small Blind',chips=20000},
  interest_cap=25,reroll_cost=5}
for i=1,12 do s.playing_cards[i]={id='manufactured:card:'..i,rank=i+1,nominal=math.min(10,i+1),suit='Hearts',ability={}} end
local ctx=Shop.new(s,Score,nil,{max_evaluations=50000})
local baseline=ctx:compare(s,s)
print('baseline',baseline and baseline.before_readiness.status,baseline and baseline.complete_finishing,
  baseline and baseline.before_finishing and baseline.before_finishing.known_mechanics,
  not not (baseline and baseline.common_worlds and baseline.common_worlds.family_key))
local a=S.advise(s,{shop_scoring=ctx})
print('shop_action',a.action.kind,a.action.index,a.action.followup and a.action.followup.index,'eval',ctx.evaluations)
local d=ctx.replacement_diagnostics
print('receipt',d and d.complete,d and d.reason,d and #d.candidates)
if d then for _,c in ipairs(d.candidates) do print('endpoint',c.sale_index,c.offer_index,c.key,c.reason,c.merit,c.ratio,c.compared,c.admitted) end end
local burglar=j('j_burglar','Burglar',{extra=3})
local p={phase='pack',ante=1,win_ante=8,jokers={},round_resets={discards=3,hands=4}}
print('burglar_blank',S.shop_sequence_api.card_value(p,burglar))
p.jokers={j('j_yorick','Yorick',{x_mult=1,extra={discards=23,xmult=1},yorick_discards=23})}
print('burglar_yorick',S.shop_sequence_api.card_value(p,burglar))
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
Shop.blind_finishing=dofile('Brainstorm/Advisor/blind_finishing.lua')
Shop.blind_finishing.strategy=S;Shop.strategy=S
for _,module in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
 Shop.blind_finishing[module]=dofile('Brainstorm/Advisor/'..module..'.lua')
end
local safe=Snapshot.copy(s);safe.dollars=60;safe.next_blind.chips=100
local safe_context=Shop.new(safe,Score,nil,{max_evaluations=50000})
local safe_pair=safe_context:compare(safe,safe)
print('safe_baseline',safe_pair and safe_pair.before_readiness.status,
  safe_pair and safe_pair.complete_finishing,
  safe_pair and safe_pair.before_finishing and safe_pair.before_finishing.known_mechanics,
  safe_pair and safe_pair.before_finishing and safe_pair.before_finishing.selected and
    safe_pair.before_finishing.selected.clearing_samples,
  safe_pair and safe_pair.before_finishing and safe_pair.before_finishing.samples,
  safe_context.evaluations)
if safe_pair and safe_pair.before_finishing then
 print('finish_reason',safe_pair.before_finishing.reason,safe_pair.before_finishing.complete,
  safe_pair.before_finishing.supported,safe_pair.before_finishing.all_worlds_clear)
end
