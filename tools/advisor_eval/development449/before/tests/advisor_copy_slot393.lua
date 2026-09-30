-- Manufactured last-slot shop choice; no captured game state is evaluated.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function joker(key)
  local names={j_yorick='Yorick',j_perkeo='Perkeo',j_jolly='Jolly Joker',
    j_sly='Sly Joker',j_brainstorm='Brainstorm',j_blueprint='Blueprint'}
  local name=names[key] or key
  return {key=key,name=name,rarity=key=='j_brainstorm' and 3 or 2,
    sell_cost=4,blueprint_compat=true,ability={name=name,set='Joker',
      x_mult=key=='j_yorick' and 1 or nil}}
end
local function state()
  local s={phase='shop',ante=3,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=14,interest_cap=25,interest_amount=1,bankrupt_at=0,joker_limit=5,
    consumable_limit=2,jokers={joker('j_yorick'),joker('j_perkeo'),
      joker('j_8_ball'),joker('j_egg')},consumeables={},
    shop_jokers={joker('j_brainstorm')},shop_booster={{key='p_buffoon_normal_1',
      name='Buffoon Pack',cost=4,ability={set='Booster'}}},shop_vouchers={},
    hand={},playing_cards={},deck={},hands={Pair={played=5,level=2,chips=25,mult=3}},
    modifiers={},round_resets={hands=4,discards=3},blind={chips=1600}}
  s.shop_jokers[1].cost=10;s.shop_jokers[1].ability.eternal=true
  for rank=2,14 do for i=1,4 do
    s.playing_cards[#s.playing_cards+1]={id='synthetic:'..rank..':'..i,
      rank=rank,suit='Spades',enhancement='c_base'}
  end end
  return s
end

local s=state()
local advice=S.advise(s)
check(advice.action.kind=='buy' and advice.action.area=='shop_jokers' and
  advice.action.index==1,'last-slot risk favors the visible durable copy before Buffoon')
check(advice.copy_opportunity_review and
  advice.copy_opportunity_review.reason=='known_copy_offer_at_risk' and
  advice.copy_opportunity_review.resource=='joker_slot',
  'last-slot opportunity is auditable as a slot risk')
check(s.dollars-s.shop_booster[1].cost>=s.shop_jokers[1].cost,
  'manufactured case has no cash-forfeiture explanation')

local function no_slot_override(changed,label)
  local result=S.advise(changed)
  check(not result.copy_opportunity_review or
    result.copy_opportunity_review.resource~='joker_slot',label)
end
local controls={
  {'two available slots',function(x) x.joker_limit=6 end},
  {'Negative copy supplies capacity',function(x) x.shop_jokers[1].edition={negative=true} end},
  {'Arcana pack cannot fill a Joker slot',function(x)
    x.shop_booster[1].key='p_arcana_normal_1';x.shop_booster[1].name='Arcana Pack' end},
  {'Unknown Buffoon-like pack is not assumed to contain Jokers',function(x)
    x.shop_booster[1].key='p_buffoon_custom_1' end},
  {'Rental copy has no durable override',function(x) x.shop_jokers[1].ability.rental=true end},
  {'Perishable copy has no durable override',function(x) x.shop_jokers[1].ability.perishable=true end},
  {'Debuffed offer is not promoted',function(x) x.shop_jokers[1].debuff=true end},
  {'Redacted offer is not promoted',function(x) x.shop_jokers[1].identity_redacted=true end},
  {'Already owned copy is not promoted',function(x) x.jokers[4]=joker('j_blueprint') end},
  {'Late ante is outside the opening gate',function(x) x.ante=6 end},
  {'Other profile keeps its own choice',function(x) x.teacher_profile=nil end},
  {'Noninteger slot capacity is unsupported',function(x) x.joker_limit=5.5 end},
}
for _,case in ipairs(controls) do
  local changed=state();case[2](changed);no_slot_override(changed,case[1])
end
local cash=state();cash.jokers={joker('j_yorick'),joker('j_perkeo')}
cash.dollars=11
local cash_advice=S.advise(cash)
check(cash_advice.copy_opportunity_review and
  cash_advice.copy_opportunity_review.resource=='cash',
  'existing cash-forfeiture safeguard remains independent of slot risk')

print('advisor_copy_slot393: '..checks..' manufactured checks passed')
