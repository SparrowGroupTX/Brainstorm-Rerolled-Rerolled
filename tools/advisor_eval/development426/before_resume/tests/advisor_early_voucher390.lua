-- Independent manufactured early-shop resource trade; no captured state.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy;Shop.liquidity=Liquidity
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function joker(key,name,ability,cost)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {id='manufactured:'..key,key=key,ability=ability,cost=cost or 0,
    sell_cost=2,blueprint_compat=true}
end
local function state()
  local cards={}
  for i=1,28 do
    local rank=2+(i-1)%13
    cards[i]={id='manufactured:card:'..i,rank=rank,nominal=math.min(rank,10),
      suit=({'Hearts','Spades','Diamonds','Clubs'})[(i-1)%4+1],enhancement='c_base',ability={}}
  end
  return {phase='shop',ante=2,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=11,bankrupt_at=0,interest_cap=25,interest_amount=1,joker_limit=5,
    jokers={joker('j_yorick','Yorick',{x_mult=2,yorick_discards=10,extra={discards=23,xmult=1}}),
      joker('j_perkeo','Perkeo',{})},
    shop_jokers={joker('j_abstract','Abstract Joker',{extra=3},4)},
    shop_vouchers={{key='v_grabber',cost=10,ability={set='Voucher',name='Grabber',extra=1}}},
    shop_booster={},consumeables={},playing_cards=cards,hand={},deck={},
    hand_size=8,hand_limit=5,round_resets={hands=4,discards=3},current_round={},
    hands={['High Card']={level=1,played=3,chips=5,mult=1},Pair={level=1,played=2,chips=10,mult=2}},
    blind={key='bl_big',name='Big Blind',chips=900},
    next_blind={key='bl_small',name='Small Blind',chips=1000},
    modifiers={},probabilities={normal=1},reroll_cost=5}
end
local s=state();local original=Snapshot.fingerprint(s)
local ctx=Shop.new(s,Score,nil,{max_evaluations=50000})
local compare=ctx.compare
local joker_evidence,voucher_evidence,voucher_after
ctx.compare=function(self,before,after)
  local evidence=compare(self,before,after)
  if (after.used_vouchers or {}).v_grabber then
    voucher_evidence=evidence;voucher_after=after
  elseif #(after.jokers or {})>2 then joker_evidence=evidence end
  return evidence
end
local advice=Strategy.advise(s,{shop_scoring=ctx})
check(Snapshot.fingerprint(s)==original,'shop comparison leaves manufactured public state untouched')
check(ctx.evaluations<=50000 and not ctx.truncated,'complete shop comparison stays inside original cap')
check(voucher_after and voucher_after.dollars==1 and voucher_after.round_resets.hands==5,
  'Grabber preview spends cash and grants exactly one next-blind hand')
check(s.round_resets.hands==4 and not (s.used_vouchers or {}).v_grabber,
  'preview does not redeem the voucher in the source state')
check(voucher_evidence and voucher_evidence.complete_finishing and
  voucher_evidence.after_readiness.hands==5 and voucher_evidence.after_finishing.selected,
  'five-hand voucher receives a complete paired whole-blind comparison')
check(joker_evidence and joker_evidence.complete_finishing and
  joker_evidence.common_worlds.family_key==voucher_evidence.common_worlds.family_key,
  'voucher and visible scoring Joker share the same four declared worlds')
check(advice.action and advice.action.kind=='buy' and advice.action.area=='shop_jokers',
  'stronger visible scoring Joker is chosen in this manufactured next-blind trade')
do
  local t=state();t.shop_jokers={};t.shop_vouchers[1].ability.extra=2
  local context=Shop.new(t,Score,nil,{max_evaluations=50000})
  local compared=false;local prior=context.compare
  context.compare=function(self,before,after)
    if (after.used_vouchers or {}).v_grabber then compared=true end
    return prior(self,before,after)
  end
  Strategy.advise(t,{shop_scoring=context})
  check(not compared,'nonstandard hand-voucher payload never receives a fabricated transition')
  check(context.evaluations<=50000,'unsupported voucher shape retains shared cap')
end
do
  local t=state();t.round_resets.hands=5;t.shop_jokers={}
  local context=Shop.new(t,Score,nil,{max_evaluations=50000})
  local evidence;local prior=context.compare
  context.compare=function(self,before,after)
    local result=prior(self,before,after)
    if (after.used_vouchers or {}).v_grabber then evidence=result end
    return result
  end
  Strategy.advise(t,{shop_scoring=context})
  check(evidence and not evidence.complete_finishing and
    not evidence.after_finishing.supported,'six-hand endpoint remains explicitly outside the bounded policy')
  check(context.evaluations<=50000,'unsupported six-hand endpoint retains shared cap')
end
print('early voucher390: '..checks..' checks passed')
