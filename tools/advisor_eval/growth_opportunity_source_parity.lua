local Value=dofile(PROBE_MODULE)
local cases,checks=0,0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
localize=function() return 'test' end
local order={'Flush Five','Flush House','Five of a Kind','Straight Flush','Four of a Kind','Full House','Flush','Straight','Three of a Kind','Two Pair','Pair','High Card'}
local definitions={
  j_trousers={name='Spare Trousers',mult=0,extra=2},
  j_runner={name='Runner',extra={chips=0,chip_mod=15}},
  j_square={name='Square Joker',extra={chips=0,chip_mod=4}},
  j_green_joker={name='Green Joker',mult=0,extra={hand_add=1,discard_sub=1}}}
local function hand(ranks,flush)
  local cards={}
  for i,r in ipairs(ranks) do cards[i]={rank=r,suit=flush and 'Hearts' or ({'Hearts','Clubs','Diamonds','Spades'})[(i-1)%4+1],
    get_id=function(self) return self.rank end,get_nominal=function(self) return self.rank end,
    is_suit=function(self,suit) return self.suit==suit end} end
  return cards
end
local function run(ranks,flush,four_fingers)
  G={jokers={cards={}},C={RED={},GREEN={},CHIPS={}}}
  find_joker=function(name) return name=='Four Fingers' and four_fingers and {true} or {} end
  local cards=hand(ranks,flush);local poker=evaluate_poker_hand(cards);local label
  for _,name in ipairs(order) do if next(poker[name]) then label=name;break end end
  for key,definition in pairs(definitions) do
    cases=cases+1
    local a=copy(definition);a.set='Joker'
    local original=setmetatable({ability=copy(a)},{__index=Card})
    original:calculate_joker({before=true,cardarea=G.jokers,full_hand=cards,poker_hands=poker})
    local grew=(original.ability.mult or 0)>(a.mult or 0) or
      (type(original.ability.extra)=='table' and (original.ability.extra.chips or 0)>0)
    local r={supported=true,status='unresolved',hands=1,samples=4,target=100,clearing_samples=1,
      opening_scores={100,10,10,10},opening_hands={label,label,label,label},opening_sizes={#cards,#cards,#cards,#cards}}
    local assessed=Value.assess({phase='shop',ante=2,dollars=10,jokers={},consumeables={}},
      {key=key,ability=a,cost=4},{base_value=58,readiness=r})
    check(assessed.clearing_trigger_unknown==1 or assessed.clearing_trigger_samples==(grew and 1 or 0),key..' original trigger '..label)
    check(assessed.clearing_trigger_unknown==1 or assessed.one_hand_trigger_conflict==not grew,key..' original nontrigger '..label)
    if grew then check(assessed.adjustment==0,key..' valid opportunity retained '..label) end
    if assessed.clearing_trigger_unknown==1 then check(assessed.adjustment==0,key..' ambiguity cannot invent conflict') end
  end
end
run({2,3,4,5,6});run({2,2,3,3,9});run({2,2,2,3,3});run({2,2,2,2,9});run({2,2,2,2,2})
run({2,4,6,8,10},true);run({2,2,3,3,9},true);run({2,2,2,3,3},true);run({2,2,2,2,2},true)
run({2,3,4,5},false,true);run({2,3,4,5,5},true,true);run({2,2,3,3},false,true)
print('growth opportunity source parity: '..cases..' cases, '..checks..' comparisons')
