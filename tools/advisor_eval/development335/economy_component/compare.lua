-- Complete manufactured cash planner outputs, using the real strategy ratings.
local Old=dofile('tools/advisor_eval/development335/economy_component/before_economy.lua')
local New=dofile('tools/advisor_eval/development335/economy_component/economy.lua')
local C=dofile('tools/advisor_eval/development335/economy_component/consumables.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local comparisons,old_calls,new_calls=0,0,0
local function run(E,s)
  local calls=0
  local provider=setmetatable({advise=function(after) calls=calls+1;return S.advise(after) end},{__index=S})
  local base=S.advise(s)
  local result=E.suggest(s,provider,C,base)
  return {result=result,base=base},calls
end
for _,n in ipairs({1,2,3,10}) do for _,money in ipairs({0,5,20}) do
  for _,pattern in ipairs({'hermit','temperance','grouped','alternating'}) do for mode=1,3 do
    local s={phase='shop',dollars=money,consumeables={},hand={},deck={},playing_cards={},hands={},
      jokers={{id='egg',key='j_egg',name='Egg',sell_cost=30,ability={name='Egg',set='Joker'}}},
      modifiers={},bankrupt_at=0,ante=2,joker_limit=5,consumable_limit=2+n,reroll_cost=5,
      shop_jokers={{key='j_joker',name='Joker',cost=2,ability={name='Joker',set='Joker'}}},
      shop_vouchers={},shop_booster={}}
    if mode==2 then s.modifiers.minus_hand_size_per_X_dollar=5;s.hand_size=8 end
    if mode==3 then s.jokers[2]={id='perkeo',key='j_perkeo',name='Perkeo',
      ability={name='Perkeo',set='Joker'},blueprint_compat=true} end
    for i=1,n do
      local hermit=pattern=='hermit' or pattern=='grouped' and i<=math.ceil(n/2) or pattern=='alternating' and i%2==1
      s.consumeables[i]={id='cash:'..i,key=hermit and 'c_hermit' or 'c_temperance',
        cost=8,sell_cost=4,debuff=false,face_down=false,edition={negative=true,type='negative'},
        ability={set='Tarot',name=hermit and 'The Hermit' or 'Temperance',extra=hermit and 20 or 50,consumeable={}}}
    end
    local before=Snapshot.fingerprint(s)
    local a,ac=run(Old,s);local b,bc=run(New,s)
    assert(Snapshot.fingerprint(a)==Snapshot.fingerprint(b),'Cash result mismatch '..n..' '..money..' '..pattern..' '..mode)
    assert(Snapshot.fingerprint(s)==before,'Input changed')
    assert(bc<=ac,'Representative planner added redundant preview requests')
    comparisons=comparisons+1;old_calls=old_calls+ac;new_calls=new_calls+bc
  end end
end end
assert(comparisons==144)
print('cash_reuse_comparison: cases='..comparisons..' old_strategy_previews='..old_calls..' new_strategy_previews='..new_calls)
