-- Independent manufactured tests for bounded Strength stock and shop commitments.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function joker(key,rarity,eternal)
  local name=({j_perkeo='Perkeo',j_yorick='Yorick',j_blueprint='Blueprint',
    j_brainstorm='Brainstorm'})[key] or key
  return {key=key,name=name,rarity=rarity or 2,sell_cost=4,blueprint_compat=true,
    ability={name=name,set='Joker',eternal=eternal or nil,x_mult=key=='j_yorick' and 1 or nil}}
end
local function strength()
  return {key='c_strength',name='Strength',sell_cost=4,edition={negative=true},
    ability={name='Strength',set='Tarot',consumeable={max_highlighted=2,min_highlighted=1}}}
end
local function state()
  local s={phase='shop',ante=1,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=11,interest_cap=25,interest_amount=1,bankrupt_at=0,joker_limit=5,
    consumable_limit=2,jokers={joker('j_perkeo'),joker('j_yorick')},consumeables={},
    shop_jokers={},shop_booster={},shop_vouchers={},hand={},playing_cards={},deck={},
    hands={Pair={played=4,level=1,chips=10,mult=2}},modifiers={},
    round_resets={hands=4,discards=3},blind={chips=600}}
  for rank=2,14 do for i=1,4 do
    s.playing_cards[#s.playing_cards+1]={id='manufactured:'..rank..':'..i,rank=rank,
      suit='Spades',enhancement='c_base'}
  end end
  return s
end
local function rescue()
  return {samples=4,before_target=1500,after_target=1500,complete_finishing=true,
    common_worlds={kind='shop_four_common_worlds_v1',samples=4,family_key='manufactured',world_ids={1,2,3,4}},
    before_finishing={complete=true,supported=true,known_mechanics=true,samples=4,
      selected={clearing_samples=2,worlds={{clear=true},{clear=true},{clear=false},{clear=false}}}},
    after_finishing={complete=true,supported=true,known_mechanics=true,samples=4,
      selected={clearing_samples=4,worlds={{clear=true},{clear=true},{clear=true},{clear=true}}}}}
end

do
  local s=state();s.ante=5;s.dollars=60
  for i=1,12 do s.consumeables[i]=strength() end
  s.consumable_limit=14
  local _,value=S.inventory_value(s)
  equal(value.direct,36,'uncommitted mixed deck credits only two Strength uses')
  local action=S.manage_teacher_stock(s)
  check(action and action.action.kind=='sell' and action.action.index==1,
    'surplus Negative Strength is sold instead of copied indefinitely')
  equal(#s.consumeables,12,'review leaves observed physical inventory unchanged')
  equal(s.consumable_limit,14,'review leaves Negative capacity unchanged')
  local sold=0
  while action and action.action.kind=='sell' and action.action.area=='consumeables' do
    local selected=s.consumeables[action.action.index]
    check(selected and selected.key=='c_strength' and selected.edition.negative,
      'each proposed surplus sale names a physical Negative Strength')
    table.remove(s.consumeables,action.action.index)
    s.consumable_limit=s.consumable_limit-1
    check(#s.consumeables<=s.consumable_limit,'each proposed Negative sale preserves capacity')
    sold=sold+1;check(sold<=12,'stock review converges under fresh observations')
    action=S.manage_teacher_stock(s)
  end
  check(sold>=10 and sold<=11,'mixed early plan trims twelve copies to at most two')
  check(#s.consumeables>=1 and #s.consumeables<=2,'finite reserve keeps a physical source')
  equal(s.consumable_limit,14-sold,'capacity removed once per sold Negative')
  s.consumeables={strength()};s.consumable_limit=3
  check(not S.manage_teacher_stock(s),'useful final Strength source remains')
  s.playing_cards={};s.hands={['Five of a Kind']={played=12,level=4,chips=200,mult=12}}
  for i=1,20 do s.playing_cards[i]={id='king:'..i,rank=13,suit='Spades'} end
  for i=1,8 do s.playing_cards[20+i]={id='queen:'..i,rank=12,suit='Spades'} end
  equal(S.build_profile(s).rank,13,'public full deck commits to Kings')
  s.consumeables={};for i=1,5 do s.consumeables[i]=strength() end
  s.consumable_limit=7
  local _,five=S.inventory_value(s)
  s.consumeables[6]=strength();s.consumable_limit=8
  local _,six=S.inventory_value(s)
  equal(five.direct,six.direct,'rank plan has finite predecessor and horizon capacity')
  check(five.direct>36,'rank commitment values more useful Strength stock than mixed deck')
  s.playing_cards[1].identity_redacted=true
  local _,unknown=S.inventory_value(s)
  check(unknown.direct>six.direct,'unknown population is not falsely classified as surplus')
end

do
  local s=state();s.ante=2
  local green=joker('j_green_joker',1,true)
  local allowed,why=S.joker_admission(s,green,nil,nil)
  check(not allowed and why.kind=='win_first_permanent_slot_guard',
    'early Eternal common without complete rescue is refused')
  local evidence=rescue()
  evidence.after_finishing.selected.clearing_samples=3
  check(not S.joker_admission(s,green,nil,evidence),'partial improvement is not a rescue')
  evidence=rescue();evidence.common_worlds.world_ids[4]=5
  check(not S.joker_admission(s,green,nil,evidence),'unpaired comparison is not a rescue')
  evidence=rescue();evidence.uncertain=true
  check(not S.joker_admission(s,green,nil,evidence),'uncertain comparison is not a rescue')
  check(S.joker_admission(s,green,nil,rescue()),'complete sampled rescue may justify early permanent slot')
  green.edition={negative=true}
  check(S.joker_admission(s,green,nil,nil),'Negative common does not consume ordinary slot')
  green.edition=nil;s.ante=6
  check(S.joker_admission(s,green,nil,nil),'short remaining horizon retains ordinary comparison')
  s.ante=2;s.teacher_profile=nil
  check(S.joker_admission(s,green,nil,nil),'other objective is unaffected')
end

do
  local s=state()
  s.shop_jokers={joker('j_blueprint',3)};s.shop_jokers[1].cost=10
  s.shop_booster={{key='p_buffoon_normal_1',name='Buffoon Pack',cost=4,
    ability={set='Booster'}}}
  local advice=S.advise(s)
  equal(advice.action.kind,'buy','known copy Joker wins close unknown-pack tie')
  equal(advice.action.area,'shop_jokers','copy acquisition occurs before pack expense')
  equal(advice.action.index,1,'visible Blueprint is selected')
  check(advice.copy_opportunity_review and
    advice.copy_opportunity_review.reason=='known_copy_offer_at_risk',
    'opportunity cost is explicitly reported')
  s.bankrupt_at=-20;advice=S.advise(s)
  check(not advice.copy_opportunity_review,
    'Credit Card room means the pack does not make Blueprint unaffordable')
  s.bankrupt_at=0
  s.dollars=14;advice=S.advise(s)
  check(not advice.copy_opportunity_review,'pack does not forfeit still-affordable copy offer')
  s.dollars=11;s.shop_jokers[1].ability.perishable=true
  advice=S.advise(s)
  check(not advice.copy_opportunity_review,'short-lived copy offer receives no durable override')
  s.shop_jokers[1].ability.perishable=nil;s.teacher_profile=nil
  advice=S.advise(s)
  check(not advice.copy_opportunity_review,'other profile retains its own choice')
  s.teacher_profile='perkeo_yorick_win_v1';s.dollars=9
  advice=S.advise(s)
  check(not advice.copy_opportunity_review,'currently unaffordable Blueprint is not revived')
  s.dollars=11;s.jokers={joker('j_perkeo'),joker('j_yorick'),joker('j_wily'),
    joker('j_jolly'),joker('j_even_steven')}
  advice=S.advise(s)
  check(not advice.copy_opportunity_review,'full Joker row has no direct Blueprint purchase')
end

do
  local s=state();s.shop_jokers={joker('j_blueprint',3)};s.shop_jokers[1].cost=10
  s.shop_booster={{key='p_buffoon_normal_1',name='Buffoon Pack',cost=4,
    ability={set='Booster'}}}
  local evidence=rescue()
  evidence.before_finishing.selected.clearing_samples=4
  evidence.before_finishing.selected.worlds={{clear=true},{clear=true},{clear=true},{clear=true}}
  evidence.after_finishing.selected.clearing_samples=3
  evidence.after_finishing.selected.worlds={{clear=true},{clear=true},{clear=true},{clear=false}}
  evidence.adjustment=0;evidence.reason='Manufactured paired next-blind comparison.'
  s._shop_scoring={readiness=function()return {supported=false,status='unresolved',reason='Unknown next blind.'} end,
    compare=function()return copy(evidence) end}
  local advice=S.advise(s)
  check(not advice.copy_opportunity_review and not
    (advice.action.area=='shop_jokers' and advice.action.index==1),
    'complete sampled survival dominance excludes Blueprint before tie protection')
  check(advice.survival_rejections and advice.survival_rejections['buy:shop_jokers:1'],
    'rejected offered copy has an auditable survival receipt')
end

do
  local s=state();s.phase='pack';s.pack_cards={joker('j_green_joker',1,true)}
  local advice=S.advise(s)
  equal(advice.action.kind,'skip_pack','early Eternal common pack choice needs a rescue receipt')
  local evidence=rescue();evidence.adjustment=0;evidence.reason='Manufactured paired rescue.'
  s._shop_scoring={readiness=function()return {supported=false,status='unresolved',reason='Unknown next blind.'} end,
    compare=function()return copy(evidence) end}
  advice=S.advise(s)
  equal(advice.action.kind,'choose','complete supported rescue admits pack Eternal common')
  equal(advice.action.index,1,'pack chooses the explicitly rescued physical offer')
end
print('advisor_win_first_resources386: '..checks..' manufactured checks passed')
