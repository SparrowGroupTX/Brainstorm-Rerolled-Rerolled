local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua');Liquidity.snapshot=Snapshot
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.liquidity=Liquidity
Strategy.liquidity=Liquidity;Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua');Strategy.conditional_value.liquidity=Liquidity
Shop.strategy=Strategy
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
local function joker(key,name,ability,cost)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {id=key,key=key,name=name,ability=ability,cost=cost or 0,sell_cost=1,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=2,dollars=10,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={},consumeables={},hands={},modifiers={},probabilities={normal=1},hand_size=5,hand_limit=1,
    round_resets={hands=4,discards=3},current_round={},playing_cards={},
    next_blind={key='bl_small',chips=150},next_blind_chips=150,
    shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5}
  for i=1,24 do s.playing_cards[i]={id='c'..i,rank=2+(i-1)%13,
    suit=({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],ability={}} end
  return s
end
local old_random,old_seed=math.random,math.randomseed
math.random=function() error('Whole-blind forecast touched game RNG') end
math.randomseed=function() error('Whole-blind forecast reseeded game RNG') end
do
  local s=state();s.jokers={joker('j_green_joker','Green Joker',{mult=0,extra={hand_add=1,discard_sub=1}})}
  local before=Snapshot.fingerprint(s);local ctx=Shop.new(s,Scorer);local r=ctx:readiness(s)
  check(r.finishing and r.finishing.complete,'real scoring growth completes all paired policies')
  check(r.opening_max*4<r.target and r.cumulative_mean>r.target and r.status=='sampled_safe',
    'actual Green growth clears despite the old repeated-opening deficit proxy')
  check(Snapshot.fingerprint(s)==before,'whole-blind projections preserve the endpoint')
  check(r.finishing.samples==4 and #r.finishing.policies==2,'both complete global policies retain the same four composition worlds')
  local n=ctx.evaluations;local again=ctx:readiness(s)
  check(Snapshot.fingerprint(r)==Snapshot.fingerprint(again) and ctx.evaluations==n,'deterministic endpoint reuse avoids repeated transitions')
  for _,p in ipairs(r.finishing.policies) do for _,w in ipairs(p.worlds) do
    local total,hands,discards=0,0,0
    for _,a in ipairs(w.actions) do
      if a.kind=='play' then total=total+a.score;hands=hands+1 else discards=discards+1 end
    end
    check(total==w.score and hands==w.hands_used and discards==w.discards_used,'reported resources and cumulative score come from actual actions')
  end end
end
do
  local s=state();s.jokers={joker('j_ice_cream','Ice Cream',{extra={chips=30,chip_mod=20}})}
  local r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing.complete and r.opening_max*4>=r.target and r.cumulative_mean<r.target and r.status=='sampled_deficit',
    'Ice Cream expiration exposes a cumulative loss hidden by repeated opening capacity')
end
do
  local s=state();s.dollars=3
  s.jokers={joker('j_green_joker','Green Joker',{mult=0,extra={hand_add=1,discard_sub=1}})}
  s.shop_jokers={joker('j_golden','Golden Joker',{extra=4},3)}
  local modules={strategy=Strategy,scoring=Scorer,shop_scoring=Shop,consumables=Strategy.consumables}
  Shop.blind_finishing=nil;local prior=Decision.run(s,modules)
  Shop.blind_finishing=Finish;local after=Decision.run(s,modules)
  check(prior.action.kind=='leave_shop' and after.action.kind=='buy' and after.action.index==1,
    'a real complete-growth plan restores a timely Golden investment rejected by the opening-only policy')
  check(after.strategy.readiness.status=='sampled_safe','the changed action carries its completed survival evidence')
end
do
  local s=state();s.jokers={joker('j_green_joker','Green Joker',{mult=0,extra={hand_add=1,discard_sub=1}}),
    joker('j_mystic_summit','Mystic Summit',{mult=15,d_remaining=0})}
  local r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing and r.finishing.complete,'actual Green/Summit discard paths bypass contradictory invented temporal states')
  local e=Shop.new(s,Scorer):compare(s,s)
  check(e.complete_finishing and not e.temporal,'actual whole-blind support contains no assumed last-hand or free spent-discard forecast')
  s=state();s.jokers={joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
  r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing.complete and r.cumulative_mean>4*r.opening_mean,
    'Card Sharp repeated-hand growth follows actual prior played categories across the blind')
  s=state();s.jokers={joker('j_acrobat','Acrobat',{extra=3})}
  r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing.complete and r.cumulative_mean>4*r.opening_mean,
    'the actual final playable hand receives Acrobat instead of a separate representative assumption')
end
do
  local s=state();s.dollars=3
  s.jokers={joker('j_ice_cream','Ice Cream',{extra={chips=30,chip_mod=20}})}
  s.shop_jokers={joker('j_joker','Joker',{mult=4},3)}
  local result=Decision.run(s,{strategy=Strategy,scoring=Scorer,shop_scoring=Shop,consumables=Strategy.consumables})
  local evidence=result.strategy.scoring_evidence
  check(result.action.kind=='buy' and evidence and evidence.timely_scoring and
    evidence.timely_scoring_basis=='complete_paired_blind_progress',
    'emergency purchase urgency follows the same complete cumulative progress used by readiness')
  check(evidence.before_readiness.status=='sampled_deficit' and evidence.after_readiness.status=='sampled_safe',
    'actual affordable scoring repairs the Ice Cream attrition deficit in every compared world')
end
do
  local s=state();s.modifiers.discard_cost=1;s.dollars=3
  s.jokers={joker('j_green_joker','Green Joker',{mult=0,extra={hand_add=1,discard_sub=1}})}
  local ctx=Shop.new(s,Scorer);local r=ctx:readiness(s)
  local reserve=Liquidity.estimate(s,r)
  check(r.resource_plan and r.resource_plan.observation_key==Liquidity.observation_key(s),
    'the resource certificate binds the actual purchase endpoint, not the projected hand')
  check(r.resource_plan.all_worlds_clear and r.resource_plan.max_discards_used==0 and reserve.discards_reserved==0,
    'completed play-only worlds release paid-discard cash without promising unseen draws')
  s.dollars=2
  check(Liquidity.estimate(s,r).discards_reserved==3,'cash-changing action invalidates the old endpoint certificate')
  local generous=Snapshot.copy(s);generous.dollars=20
  local rg=Shop.new(generous,Scorer):readiness(generous)
  check(rg.finishing.complete and #rg.finishing.policies[2].worlds==4,'a funded targeted-discard policy completes every world')
  for _,w in ipairs(rg.finishing.policies[2].worlds) do
    check(w.discards_used==1 and w.dollars_after==19,'actual paid discard dollars are carried through later plays')
  end
end
do
  local s=state();s.next_blind.chips=5
  for i=1,5 do s.playing_cards[i].enhancement='m_glass' end
  local before=Snapshot.fingerprint(s);local r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing.complete and r.finishing.all_worlds_clear,'sampled Glass outcomes remain complete within population-aware clear policies')
  check(r.finishing.selected.population_loss==0,'reliable cheap clears avoid gratuitous Glass exposure')
  for _,w in ipairs(r.finishing.selected.worlds) do
    local used={}
    for _,a in ipairs(w.actions) do for _,id in ipairs(a.card_ids or {}) do
      check(not used[id],'a played physical card cannot be redrawn from an exhausted population');used[id]=true
    end end
  end
  check(Snapshot.fingerprint(s)==before,'population sampling never marks the owned live cards destroyed')
end
do
  local s=state();s.next_blind.chips=1000;s.playing_cards={s.playing_cards[1]}
  local r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing.complete and r.finishing.selected.mean_hands_used==1 and r.status=='sampled_deficit',
    'a depleted deck terminates as an observed loss, not repeated use of the opening card')
  local unknown=state();unknown.next_blind={key='bl_fish',name='The Fish',boss=true,chips=150}
  r=Shop.new(unknown,Scorer):readiness(unknown)
  check(not r.finishing.complete and r.status=='unresolved' and r.finishing.reason:find('belief',1,true),
    'future concealed draws remain explicit even when shop normalization made deck cards face-up')
  unknown=state();unknown.jokers={joker('j_business','Business Card',{extra=2})}
  r=Shop.new(unknown,Scorer):readiness(unknown)
  check(not r.finishing.complete and r.status=='unresolved','conditional random income cannot finance deterministic continuation')
  local ctx=Shop.new(state(),Scorer,nil,{max_evaluations=90})
  local result=ctx:compare(state(),state())
  check(not result and ctx.truncated and ctx.evaluations<=90,'an incomplete admitted continuation discards the entire paired comparison within the shared cap')
end
math.random,math.randomseed=old_random,old_seed
print('advisor_blind_finishing: '..checks..' checks passed')
