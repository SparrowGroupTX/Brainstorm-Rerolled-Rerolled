local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua');Liquidity.snapshot=Snapshot
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.liquidity=Liquidity
Strategy.liquidity=Liquidity;Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua');Strategy.conditional_value.liquidity=Liquidity
Shop.strategy=Strategy
local function joker(key,name,ability,cost)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {id=key,key=key,name=name,ability=ability,cost=cost or 0,sell_cost=1,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=2,dollars=5,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={joker('j_bull','Bull',{extra=2})},consumeables={},hands={},modifiers={},probabilities={normal=1},hand_size=5,hand_limit=1,
    round_resets={hands=4,discards=0},current_round={},playing_cards={},
    next_blind={key='bl_small',chips=95},next_blind_chips=95,
    shop_jokers={joker('j_golden','Golden Joker',{extra=4},3)},shop_booster={},shop_vouchers={},reroll_cost=5}
  for i=1,24 do s.playing_cards[i]={id='c'..i,rank=14,suit='Hearts',ability={}} end
  return s
end
local modules={strategy=Strategy,scoring=Scorer,shop_scoring=Shop,consumables=Strategy.consumables,shop_sequences=Sequences}
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
do
  local s=state();local before=Snapshot.fingerprint(s);local result=Decision.run(s,modules)
  local rejected=result.strategy.survival_rejections['buy:shop_jokers:1']
  check(result.action.kind=='leave_shop','decline income purchase which destroys every supported next-blind finish')
  check(rejected and rejected.key=='j_golden' and rejected.evidence.before_finishing.selected.clearing_samples==4 and
    rejected.evidence.after_finishing.selected.clearing_samples==0,'the real Bull cash loss remains reviewable as four clears becoming zero')
  check(result.shop_diagnostics.sequences.complete,'all visible rescue endpoints are evaluated before keeping cash')
  for _,p in ipairs(result.shop_diagnostics.sequences.plans) do
    if #p.actions>0 then check(p.survival_dominated,'none of the unrescued buy/sale endpoints acquires delayed-utility credit') end
  end
  check(Snapshot.fingerprint(s)==before,'dominance checks preserve source cash and inventory')
  check(Snapshot.fingerprint(result)==Snapshot.fingerprint(Decision.run(s,modules)),'full guarded decision is deterministic')
end
do
  local s=state();s.consumeables={{id='pluto',key='c_pluto',cost=3,sell_cost=1,
    ability={name='Pluto',set='Planet',consumeable={hand_type='High Card'}}}}
  local result=Decision.run(s,modules)
  local diag=result.shop_diagnostics.sequences
  check(diag.complete,'a known owned Planet keeps the rescue graph fully compared')
  local dominated,rescued=false,false
  for _,p in ipairs(diag.plans) do
    if p.actions[1] and p.actions[1].kind=='buy' then
      if #p.actions==1 then dominated=dominated or p.survival_dominated end
      if #p.actions>=2 and not p.survival_dominated and p.readiness=='sampled_safe' then rescued=true end
    end
  end
  check(dominated and rescued,'unsafe intermediate Golden buy is retained when a complete owned-Planet continuation restores survival')
  local first=diag.best_by_first_action['buy:shop_jokers:1']
  check(first and #first.actions>=2 and first.readiness.status=='sampled_safe',
    'the retained buy-first alternative carries its completed rescue rather than its unsafe immediate endpoint')
end
do
  local s=state();s.next_blind.chips=50;s.next_blind_chips=50
  local result=Decision.run(s,modules)
  check(result.action.kind=='buy' and result.action.index==1,'worthwhile income remains buyable when both complete endpoints clear')
  local e=result.strategy.scoring_evidence
  check(e.complete_finishing and not Strategy.survival_dominated(e),'safe investment receives no survival rejection')
  local incomplete=Snapshot.copy(e);incomplete.complete_finishing=false
  check(not Strategy.survival_dominated(incomplete),'an incomplete comparison cannot establish dominance')
  incomplete=Snapshot.copy(e);incomplete.after_finishing.known_mechanics=false
  check(not Strategy.survival_dominated(incomplete),'unknown mechanics do not fabricate a dominance proof')
end
print('advisor_shop_survival: '..checks..' checks passed')
