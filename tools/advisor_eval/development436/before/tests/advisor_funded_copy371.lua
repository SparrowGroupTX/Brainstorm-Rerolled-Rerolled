-- Manufactured free-slot liquidity bridge; no captured seed or state.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Sequence=dofile('Brainstorm/Advisor/shop_sequences.lua')
local checks=0
local function check(value,why) checks=checks+1;assert(value,why) end
local function j(key,name,a,cost,sell)
  a=a or {};a.set='Joker';a.name=name
  return {id='manufactured:'..key,key=key,ability=a,blueprint_compat=true,cost=cost or 0,sell_cost=sell or 2}
end
local function state()
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
  return s
end
local function advise(s,limit)
  local context=Shop.new(s,Score,nil,{max_evaluations=limit or 50000})
  return Strategy.advise(s,{shop_scoring=context}),context
end

local s=state();local original=Snapshot.fingerprint(s)
local advice,ctx=advise(s)
check(advice.action.kind=='sell' and advice.action.index==3 and
  advice.action.followup.kind=='buy' and advice.action.followup.index==1,
  'a free slot still compares and selects the funded visible copy endpoint')
check(ctx.replacement_diagnostics and ctx.replacement_diagnostics.complete and
  ctx.replacement_diagnostics.selected_sale==3 and ctx.replacement_diagnostics.selected_offer==1,
  'whole sale/offer family and selected endpoint are recorded')
check(#ctx.replacement_diagnostics.candidates==3 and ctx.evaluations<=50000,
  'every visible victim is accounted within the old shop cap')
check(advice.replacement.cash_after_purchase==1 and advice.scoring_evidence.common_worlds,
  'actual sale/purchase cash and paired public worlds determine merit')
check(Snapshot.fingerprint(s)==original,'candidate comparison leaves input and physical counters intact')
local sold=Sequence.transition(s,advice.action,{strategy=Strategy})
check(sold and sold.dollars==11 and #sold.jokers==2,'sale settles $2 before a fresh purchase decision')
local fresh=advise(sold)
check(fresh.action.kind=='buy' and fresh.action.area=='shop_jokers' and fresh.action.index==1,
  'fresh advice buys only the still-visible and newly affordable Blueprint')

local direct=state();direct.dollars=10
local choice=advise(direct)
check(choice.action.kind~='sell','an already-affordable free-slot purchase never requires liquidation')
local poor=state();for _,owned in ipairs(poor.jokers) do owned.sell_cost=0 end
choice=advise(poor)
check(choice.action.kind~='sell','insufficient actual sale proceeds cannot promise a purchase')
local protected=state();protected.jokers[3].ability.eternal=true
choice=advise(protected)
check(choice.action.kind~='sell' or choice.action.index~=3,'Eternal victim cannot fund the copy')
protected=state();protected.jokers[3].pinned=true
choice=advise(protected)
check(choice.action.kind~='sell' or choice.action.index~=3,'pinned victim cannot fund the copy')
local capped=state();choice,ctx=advise(capped,500)
check(ctx.evaluations<=500 and choice.action.kind~='sell' and
  ctx.replacement_diagnostics and not ctx.replacement_diagnostics.complete,
  'an incomplete common-world family never executes its favorable prefix')
local again,again_ctx=advise(state())
check(Snapshot.fingerprint(advice)==Snapshot.fingerprint(again) and ctx.evaluations<=500 and again_ctx.evaluations<=50000,
  'uncapped result is deterministic without extra budget')
print('advisor_funded_copy371: '..checks..' checks passed')
