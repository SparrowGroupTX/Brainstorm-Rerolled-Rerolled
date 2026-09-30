local E=dofile('Brainstorm/Advisor/economy.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(x,m) checks=checks+1; assert(x,m) end
local function state(dollars,items,extra)
  local s={phase='shop',dollars=dollars,consumeables=items or {},hand={},deck={},playing_cards={},
    jokers={},hands={},modifiers={},shop_jokers={{key='j_joker',name='Joker',cost=2,ability={set='Joker'}}},
    shop_vouchers={},shop_booster={},joker_limit=5,consumable_limit=2,bankrupt_at=0,reroll_cost=5,ante=1}
  for k,v in pairs(extra or {}) do s[k]=v end
  return s
end
local function cash(key,extra) return {key=key,ability={set='Tarot',extra=extra}} end
local function advise(s) return E.suggest(s,S,C,S.advise(s)) end
local s=state(10,{cash('c_hermit',20)})
local r=advise(s)
check(r and r.action.kind=='use' and r.action.index==1,'use Hermit before an affordable purchase reduces its payout')
check(r.title=='Use The Hermit (+$10)','show actual current payout')
check(s.dollars==10 and #s.consumeables==1,'cash planning does not use the real card or change cash')
local after=C.apply(s,1,{})
check(S.advise(after).action.kind=='buy','ordinary purchase follows the payout')
check(advise(after)==nil,'used item cannot be suggested repeatedly')
check(advise(state(-4,{cash('c_hermit',20)}))==nil,'negative money cannot produce a Hermit payout')
check(advise(state(0,{cash('c_hermit',20)}))==nil,'zero payout is not recommended')
r=advise(state(30,{cash('c_hermit',20)},{shop_jokers={}}))
check(r and r.title=='Use The Hermit (+$20)','cash out capped Hermit even with no visible purchase')
check(advise(state(10,{cash('c_hermit',20)},{shop_jokers={}}))==nil,'retain uncapped Hermit when no spending or useful purchase exists')
local wait=state(10,{cash('c_hermit',20)},{shop_jokers={}})
check(S.advise(wait).action.kind=='leave_shop' and S.advise(C.apply(wait,1,{})).action.kind=='reroll',
  'no-purchase regression exercises a payout that would only unlock speculative paid rerolls')
check(advise(state(13,{cash('c_hermit',20)},{shop_jokers={}}))~=nil,
  'protect Hermit when a paid reroll was already the selected spend')
r=advise(state(1,{cash('c_hermit',20)}))
check(r and r.action.kind=='use','use a small payout when it enables a concrete scoring purchase')
s=state(5,{cash('c_temperance',50)},{jokers={{key='j_egg',ability={},sell_cost=11}}})
local base={title='Sell a Joker',action={kind='sell',area='jokers',index=1}}
r=E.suggest(s,S,C,base)
check(r and r.title=='Use Temperance (+$11)','Temperance collects resale before a planned Joker sale on any challenge')
check(advise(state(5,{cash('c_temperance',50)}))==nil,'Temperance with no resale payout is held')
s=state(10,{cash('c_hermit',20),cash('c_temperance',50)},
  {jokers={{key='j_egg',ability={},sell_cost=50}}})
r=advise(s)
check(r and r.action.index==2,'Temperance before Hermit maximizes the combined payout when both are useful')
local first=C.apply(s,r.action.index,{})
r=advise(first)
check(r and r.action.index==1 and r.title=='Use The Hermit (+$20)','next advice uses the now-capped Hermit')
s=state(10,{cash('c_hermit',20),cash('c_temperance',50)},
  {jokers={{key='j_egg',ability={},sell_cost=11}}})
r=advise(s)
check(r and r.action.index==2 and r.title=='Use Temperance (+$11)',
  'uncapped Temperance goes first when it raises a Hermit that is needed before spending')
check(table.concat(r.lines,' '):find('The Hermit (+$20)',1,true)~=nil,
  'first cash advice names the actual next money action instead of skipping ahead to a buy')
first=C.apply(s,r.action.index,{})
local decision=D.run(first,{strategy=S,consumables=C,economy=E})
check(decision.action.kind=='use' and decision.action.index==1 and decision.strategy.title=='Use The Hermit (+$20)',
  'real decision entry point preserves the profitable second cash action')
check(C.apply(first,decision.action.index,{}).dollars==41, 'Temperance then Hermit earns $31 rather than $21 in this shop')
check(s.dollars==10 and #s.consumeables==2 and s.jokers[1].sell_cost==11,
  'two-step money planning does not alter original inventory, cash, or resale')
s=state(5,{cash('c_temperance',50)}, {jokers={{key='j_egg',ability={},sell_cost=11}},
  shop_jokers={{key='j_joker',cost=2,ability={set='Joker'}},{key='j_blueprint',cost=8,ability={set='Joker'}}}})
s.jokers[#s.jokers+1]={key='j_blue_joker',blueprint_compat=true,ability={set='Joker'}}
check(S.advise(s).action.index==1 and S.advise(C.apply(s,1,{})).action.index==2,
  'funding regression has a cheap existing purchase and a better newly affordable purchase')
check(advise(s)~=nil, 'Temperance can unlock a better purchase even when a cheaper buy was already possible')
s=state(20,{cash('c_hermit',20)},{modifiers={minus_hand_size_per_X_dollar=5},shop_jokers={}})
check(advise(s)==nil,'Luxury Tax never cashes a cap just to shrink the next hand')
s=state(4,{cash('c_temperance',50)}, {jokers={{key='j_vagabond',ability={extra=4},sell_cost=50}},shop_jokers={}})
check(advise(s)==nil, 'capped Temperance does not turn off an active Vagabond without a restoring purchase')
s=state(4,{cash('c_hermit',20)}, {jokers={{key='j_vagabond',ability={extra=4},sell_cost=2}},
  shop_jokers={{key='j_joker',cost=5,ability={set='Joker'}}}})
check(advise(s)~=nil, 'a concrete purchase can spend cash back below Vagabond threshold')
local vagabond_after=C.apply(s,1,{})
vagabond_after.consumeables={cash('c_temperance',50)}; vagabond_after.jokers[1].sell_cost=50
check(advise(vagabond_after)==nil, 'a second cash payout cannot undo the purchase that would restore Vagabond')
s=state(8,{cash('c_temperance',50)}, {modifiers={minus_hand_size_per_X_dollar=5},
  jokers={{key='j_egg',ability={},sell_cost=2}},shop_jokers={{key='j_joker',cost=5,ability={set='Joker'}}}})
check(advise(s)==nil, 'Luxury Tax preserves the hand size after already-planned spending, not just current pre-purchase size')
s=state(10,{cash('c_hermit',20),{key='c_pluto',ability={set='Planet'}}},
  {consumable_limit=2,shop_jokers={{key='c_mercury',cost=2,ability={set='Planet'}}},
   hands={Pair={level=2,played=8}}})
s.consumeables[1].edition={negative=true}
check(advise(s)==nil, 'using a Negative money card removes its slot and cannot unlock a fictitious consumable purchase')
s=state(30,{cash('c_hermit',20)}, {shop_jokers={{key='c_wraith',cost=0,ability={set='Spectral'}}}})
check(S.advise(s).action.kind=='buy' and advise(s)~=nil, 'buying Wraith stores it and does not itself erase cash')
check(E.suggest(s,S,C,{title='Use Wraith',action={kind='use',area='consumeables',index=1}})==nil,
  'an existing immediate consumable-use action keeps priority over cash advice')
s=state(5,{cash('c_temperance',50)}, {joker_limit=2,bankrupt_at=-20,
  jokers={{key='j_credit_card',sell_cost=2,ability={extra=20}},
    {key='j_joker',sell_cost=2,ability={mult=4,eternal=true}}},
  shop_jokers={{key='j_card_sharp',cost=4,ability={extra={Xmult=3}}}}})
check(S.advise(s).action.kind=='sell', 'real strategy prepares a concrete replacement sale for the timing fixture')
decision=D.run(s,{strategy=S,consumables=C,economy=E})
check(decision.action.kind=='use' and decision.strategy.title=='Use Temperance (+$4)',
  'real decision uses Temperance while the sold Joker still contributes to its payout')
s.phase='hand'
check(advise(s)==nil,'tactical hand advice retains its separate consumable search')
s=state(10,{cash('c_hermit',20)})
s.consumeables[1].debuff=true
check(advise(s)==nil,'debuffed consumables are not used')
local old_random=math.random; math.random=function() error('cash planning used RNG') end
r=advise(state(20,{cash('c_hermit',20)}))
check(r and r.action.kind=='use','cash planning uses no game RNG')
math.random=old_random
print('advisor_economy: '..checks..' checks passed')
