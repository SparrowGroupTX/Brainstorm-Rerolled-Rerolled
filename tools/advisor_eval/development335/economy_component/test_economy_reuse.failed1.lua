-- Manufactured cash plans: inspect complete payouts, counts and actual actions.
local E=dofile('tools/advisor_eval/development335/economy_component/economy.lua')
local C=dofile('tools/advisor_eval/development335/economy_component/consumables.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function cash(i,key)
  key=key or 'c_hermit'
  return {id='cash:'..i,key=key,edition={type='negative',negative=true},cost=8,sell_cost=4,
    face_down=false,debuff=false,ability={set='Tarot',name=key=='c_hermit' and 'The Hermit' or 'Temperance',
      extra=key=='c_hermit' and 20 or 50,consumeable={}}}
end
local function state(n)
  local inventory={};for i=1,n do inventory[i]=cash(i) end
  return {phase='shop',consumeables=inventory,dollars=20,consumable_limit=2+n,joker_limit=5,
    jokers={{id='egg',key='j_egg',name='Egg',sell_cost=30,ability={name='Egg',set='Joker'}}},
    playing_cards={},hand={},deck={},hands={},modifiers={},bankrupt_at=0,ante=2,
    shop_jokers={{key='j_joker',cost=2,ability={set='Joker'}}},shop_vouchers={},shop_booster={},reroll_cost=5}
end
local buy={title='Buy Joker',action={kind='buy',area='shop_jokers',index=1}}
local function probe(s,options)
  options=options or {};local calls,counts={},{}
  local strategy={advise=function(after)
    calls[#calls+1]=after
    counts[#after.consumeables]=(counts[#after.consumeables] or 0)+1
    return buy
  end}
  if options.preserve then strategy.preservation_cost=options.preserve end
  local before=Snapshot.fingerprint(s)
  local result=E.suggest(s,strategy,options.consumables or C,buy)
  eq(Snapshot.fingerprint(s),before,'Planning leaves original cash, inventory and metadata unchanged')
  return result,calls,counts
end

do
  local s=state(10);local result,calls,counts=probe(s)
  eq(#calls,2,'Ten equivalent cash copies require one single and one two-use preview')
  eq(counts[9],1,'The first preview keeps nine copies')
  eq(counts[8],1,'The second preview keeps eight copies')
  eq(calls[1].dollars,40,'First capped Hermit adds $20')
  eq(calls[2].dollars,60,'Two identical Hermits remain a distinct $40 payout')
  eq(calls[1].consumable_limit,11,'One Negative use removes one added slot')
  eq(calls[2].consumable_limit,10,'Two Negative uses remove two added slots')
  eq(calls[1].consumeables[1].id,'cash:2','First preview removes the earliest physical copy')
  eq(calls[2].consumeables[1].id,'cash:3','Second preview removes the next physical copy')
  eq(result.action.index,1,'Executable action selects a real earliest copy')
  eq(result.title,'Use The Hermit (+$20)','Only the first payout is displayed as the action')
  check(table.concat(result.lines,' '):find('The Hermit (+$20)',1,true),'Follow-up payout remains explicit')
  local again=probe(s);eq(Snapshot.fingerprint(result),Snapshot.fingerprint(again),'Repeated advice is identical')
  local after=C.apply(s,result.action.index,{})
  local next_result,next_calls=probe(after)
  eq(#next_calls,2,'Recalculation reevaluates the remaining inventory')
  eq(next_result.action.index,1,'Fresh action uses the shifted actual inventory index')
end

do
  local s=state(10)
  for i=6,10 do s.consumeables[i]=cash(i,'c_temperance') end
  local result,calls,counts=probe(s)
  eq(#calls,6,'Two classes compare two singles and all four legal two-use class choices')
  eq(counts[9],2,'Both first-use cash effects are compared')
  eq(counts[8],4,'Same-class and cross-class second uses remain complete')
  eq(result.action.index,6,'Higher combined two-Temperance payout selects the first Temperance')
  eq(result.title,'Use Temperance (+$30)','Physical selected payout is not multiplied by inventory size')
  s.dollars=5;s.jokers[1].sell_cost=11
  result=probe(s)
  eq(result.action.index,6,'Temperance before Hermit retains the nonlinear doubling benefit')
end

do
  local s=state(1);local _,calls=probe(s)
  eq(#calls,1,'One physical copy cannot become a two-use sequence')
  s=state(2);s.consumeables[2].edition=nil
  local _,distinct=probe(s);eq(#distinct,4,'Ordinary versus Negative preserves both ordered two-use routes')
  s=state(3);s.consumeables[2].ability.extra=10
  local _,separated=probe(s);eq(#separated,9,'A different intervening payout keeps separated copies distinct')
  s=state(3);s.consumeables[2]={key='c_pluto',id='planet',ability={set='Planet'}}
  local _,separated_by_other=probe(s);eq(#separated_by_other,4,'A noncash card ends the adjacent class')
  s=state(2);s.consumeables[2].copy_source={schema=1,unsupported=true}
  local _,metadata=probe(s);eq(#metadata,4,'Different copy metadata is not merged')
  s=state(3)
  local _,fallback=probe(s,{consumables={apply=C.apply}})
  eq(#fallback,9,'A provider without explicit equivalence retains physical comparisons')
end

do
  local s=state(2);local observations=0
  local result,calls=probe(s,{preserve=function(before,after,index)
    observations=observations+1
    check(before.consumeables[index]~=nil,'Preservation gets the actual removed physical card')
    return 0,'Keep final copy',#after.consumeables==0
  end})
  eq(observations,2,'Preservation is recomputed after each distinct use')
  eq(#calls,2,'The guarded second route is independently previewed')
  check(not table.concat(result.lines,' '):find('Then reassess: use ',1,true),'The last-source guard blocks the two-use continuation')
  s=state(10)
  s.jokers[2]={id='perkeo',key='j_perkeo',name='Perkeo',ability={name='Perkeo',set='Joker'},blueprint_compat=true}
  result=E.suggest(s,S,C,S.advise(s))
  check(result and result.action.kind=='use' and result.action.index==1,'Actual strategy preserves useful payout with many Perkeo copies')
  local after=C.apply(s,1,{})
  local _,value=S.inventory_value(after)
  eq(value.probabilities.c_hermit,1,'All nine remaining Hermits still form the complete copying pool')
  eq(#after.consumeables,9,'Actual use removes exactly one of the ten sources')
end

print('advisor_economy_reuse: '..checks..' checks passed')
