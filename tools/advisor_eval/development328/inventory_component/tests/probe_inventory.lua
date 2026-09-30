local Before=dofile('tools/advisor_eval/development328/inventory_component/baseline/strategy.lua')
local After=dofile('tools/advisor_eval/development328/inventory_component/Brainstorm/Advisor/strategy.lua')
local function joker(key,name,sell,extra)
  local c={key=key,name=name,cost=sell*2,sell_cost=sell,ability={name=name,set='Joker',x_mult=1}}
  for k,v in pairs(extra or {}) do c.ability[k]=v end
  return c
end
local function make(inventory)
  local s={phase='shop',ante=4,win_ante=8,dollars=3,bankrupt_at=0,joker_limit=3,consumable_limit=2,
    jokers={joker('j_perkeo','Perkeo',10),joker('j_yorick','Yorick',10,{x_mult=12,yorick_discards=12,extra={discards=23,xmult=1}}),
      joker('j_joker','Joker',1,{mult=4})},consumeables=inventory or {},playing_cards={},hand={},deck={},shop_jokers={},shop_booster={},shop_vouchers={},
    hands={Pair={level=4,played=12,chips=55,mult=5,l_chips=15,l_mult=1}},interest_cap=25,modifiers={},reroll_cost=5}
  for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do for r=2,14 do
    s.playing_cards[#s.playing_cards+1]={id=#s.playing_cards+1,rank=r,suit=suit,ability={}}
  end end
  s.shop_jokers={joker('j_blueprint','Blueprint',5,{effect='Copycat'})}
  return s
end
for _,inventory in ipairs({{},{{key='c_mercury',ability={set='Planet'}}},{{key='c_mercury',ability={set='Planet'}},{key='c_mercury',edition={negative=true},ability={set='Planet'}}},{{key='c_hermit',ability={set='Tarot'}}}}) do
  local s=make(inventory)
  local before=Before.advise(s);local after=After.advise(s)
  print('CASE',#inventory,before.title,after.title)
  print('VALUES',Before.shop_sequence_api.build_value(s),After.shop_sequence_api.replacement_value(s),After.inventory_value(s))
end
for _,inventory in ipairs({{},{{key='c_mercury',ability={set='Planet'}},{key='c_mercury',edition={negative=true},ability={set='Planet'}}}}) do
 local s=make(inventory);s.phase='pack';s.pack_choices=1;s.pack_cards=s.shop_jokers;s.shop_jokers={}
 s.jokers[2].ability.eternal=true;s.jokers[3].ability.eternal=true
 print('PACK',#inventory,Before.advise(s).title,After.advise(s).title)
end
