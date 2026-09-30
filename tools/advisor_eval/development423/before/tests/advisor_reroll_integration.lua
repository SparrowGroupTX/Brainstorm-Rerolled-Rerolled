local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
Strategy.paid_reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
Strategy.paid_reroll.catalog=dofile('Brainstorm/Advisor/catalog_joker.lua')
local checks=0
local function check(x,s) checks=checks+1;assert(x,s) end
local s={phase='shop',dollars=13,bankrupt_at=-20,hand_size=8,hand_limit=5,joker_limit=5,
  jokers={},playing_cards={},hands={},modifiers={discard_cost=1},probabilities={normal=1},consumeables={},
  round_resets={hands=1,discards=6},current_round={},next_blind={key='bl_small',chips=600},reroll_cost=5,
  shop_forecast={edition_rate=1,slots=2,inflation=0,discount_percent=0,pools={
    {{key='j_joker',name='Joker',cost=2,rarity=1,source_set='Joker',source_config={mult=4},blueprint_compat=true}},{},{}},
    rates={joker=1,tarot=0,planet=0,playing=0,spectral=0}}}
for i,r in ipairs({2,2,4,4,6,6,8,8}) do s.playing_cards[i]={id='p:'..i,rank=r,suit='Spades',nominal=r,ability={}} end
local square={key='j_square',name='Square Joker',cost=4,ability={name='Square Joker',extra={chips=0,chip_mod=4}}}
s.shop_jokers={square}
local seen_cost=false
local scorer={score=function(state,indices)
  if #state.jokers==1 and state.jokers[1].key=='j_joker' then seen_cost=state.dollars==6 end
  return Scorer.score(state,indices)
end}
local context=Shop.new(s,scorer)
local after=Strategy.shop_sequence_api.after_joker_purchase(s,square)
local evidence=context:compare(s,after)
local base={action={kind='buy',area='shop_jokers',index=1},scoring_evidence=evidence}
local original=Snapshot.fingerprint(s)
local result=Strategy.shortfall_reroll(s,base,context)
check(result and result.action.kind=='reroll' and result.reroll_forecast.mode=='scoring_shortfall','Supported upgrade magnitude can beat a visible zero-impact growth purchase')
check(seen_cost,'Reroll comparison charges both refresh and purchase before scoring')
check(result.reroll_forecast.survival_reserve==6 and result.reroll_forecast.debt_limit==-20,'Reserve uses actual paid discards and debt metadata')
check(Snapshot.fingerprint(s)==original,'Catalog comparison does not mutate the current shop')
local no_meta=Snapshot.copy(s);no_meta.shop_forecast.edition_rate=nil
check(not Strategy.shortfall_reroll(no_meta,base,Shop.new(no_meta,Scorer)),'Unsupported edition metadata cannot invoke generic fallback over the existing buy')
local eternal=Snapshot.copy(s);eternal.modifiers.all_eternal=true
check(not Strategy.shortfall_reroll(eternal,base,Shop.new(eternal,Scorer)),'Unknown prospective Eternal compatibility cannot be treated as expendable catalog stock')
local tiny=Shop.new(s,Scorer,nil,{max_evaluations=1})
check(not Strategy.shortfall_reroll(s,base,tiny) and tiny.truncated,'Incomplete scoring returns no tactical reroll')
check(not Strategy.shortfall_reroll(s,{action={kind='open',area='shop_booster',index=1}},context),'Cannot replace an unprojected pack opening with a catalog comparison')
print('advisor_reroll_integration: '..checks..' checks passed')
