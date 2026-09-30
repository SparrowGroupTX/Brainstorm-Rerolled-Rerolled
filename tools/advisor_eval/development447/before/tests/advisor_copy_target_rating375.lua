-- Manufactured full-row copy valuation. This is not a recorded run state.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(ok,message) checks=checks+1;assert(ok,message) end
local function joker(key,name,ability,extra)
  ability=ability or {};ability.name=name;ability.set='Joker'
  local out={id='manufactured:'..key,key=key,ability=ability,cost=6,sell_cost=3}
  for k,v in pairs(extra or {}) do out[k]=v end
  return out
end
local function state(mult,compat)
  local yorick=joker('j_yorick','Yorick',
    {x_mult=mult,yorick_discards=12,extra={discards=23,xmult=1},eternal=true},
    {blueprint_compat=compat})
  local s={phase='shop',ante=5,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=64,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={yorick,
      joker('j_perkeo','Perkeo',{eternal=true}),
      joker('j_rocket','Rocket',{eternal=true,extra={dollars=2}}),
      joker('j_mr_bones','Mr. Bones',{eternal=true}),
      joker('j_supernova','Supernova',{mult=4})},
    consumeables={},hand={},playing_cards={},deck={},hands={Pair={level=2,played=7,chips=25,mult=3}},
    shop_jokers={joker('j_blueprint','Blueprint',{}, {cost=10,sell_cost=5})},
    shop_vouchers={},shop_booster={},hand_size=8,hand_limit=5,
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    blind={key='bl_big',name='Big Blind'},
    next_blind={key='bl_big',name='Big Blind',chips=14000},interest_cap=25,reroll_cost=5}
  for i=1,16 do
    local rank=2+(i-1)%13
    s.playing_cards[i]={id='manufactured:playing:'..i,rank=rank,nominal=math.min(rank,10),
      suit=({'Spades','Hearts','Clubs','Diamonds'})[(i-1)%4+1],enhancement='c_base',ability={}}
  end
  return s
end
local function advise(s)
  local context=Shop.new(s,Score,nil,{max_evaluations=50000})
  return Strategy.advise(s,{shop_scoring=context}),context
end

local developed=state(4,nil)
local before=Snapshot.fingerprint(developed)
local advice,context=advise(developed)
local receipt=context.replacement_diagnostics
check(receipt and receipt.complete and not context.truncated,'full visible replacement family completes')
check(advice.action and advice.action.kind=='sell' and advice.action.index==5 and
  advice.action.followup and advice.action.followup.kind=='buy' and advice.action.followup.index==1,
  'developed public Yorick makes the funded Blueprint replacement worthwhile')
check(receipt.selected_sale==5 and receipt.selected_offer==1 and context.evaluations<=50000,
  'selected full-row endpoint remains within the existing shop cap')
check(Snapshot.fingerprint(developed)==before,'comparison does not alter the public source row')

local incompatible=state(4,false)
local no_copy,no_copy_context=advise(incompatible)
check(no_copy.action.kind~='sell' and no_copy_context.replacement_diagnostics and
  no_copy_context.replacement_diagnostics.selected_sale==nil,
  'explicit copy incompatibility cannot earn the Yorick target premium')

local undeveloped=state(1,nil)
local no_growth,no_growth_context=advise(undeveloped)
check(no_growth.action.kind~='sell' and no_growth_context.replacement_diagnostics and
  no_growth_context.replacement_diagnostics.selected_sale==nil,
  'Yorick x1 receives no immediate scoring-copy premium')

print('advisor_copy_target_rating375: '..checks..' checks passed')
