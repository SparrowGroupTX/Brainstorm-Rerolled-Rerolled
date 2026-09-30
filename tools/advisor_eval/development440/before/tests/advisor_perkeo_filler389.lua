-- Independently manufactured Perkeo placeholder and exact shop-stock contrasts.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function eq(a,b,why) check(a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v) return Snapshot.copy(v) end
local function item(key,name,set,negative)
  local hand=({c_mercury='Pair',c_venus='Three of a Kind'})[key]
  local config=hand and {hand_type=hand} or
    key=='c_tower' and {mod_conv='m_stone',max_highlighted=1} or
    key=='c_moon' and {suit_conv='Clubs',max_highlighted=3} or {}
  return {id='manufactured:'..key..(negative and ':negative' or ':ordinary'),key=key,name=name,
    cost=3,sell_cost=1,edition=negative and {negative=true} or nil,
    ability={name=name,set=set,consumeable=config}}
end
local function state()
  local s={phase='shop',ante=2,win_ante=8,teacher_profile='perkeo_yorick_win_v1',dollars=24,
    jokers={{id='manufactured:perkeo',key='j_perkeo',name='Perkeo',
      ability={name='Perkeo',set='Joker'},blueprint_compat=true}},
    consumeables={},consumable_limit=2,consumeable_buffer=0,
    shop_jokers={},shop_booster={},shop_vouchers={},playing_cards={},hand={},deck={},
    hands={Pair={played=8,level=3,chips=30,mult=4},['Three of a Kind']={played=0,level=1,chips=30,mult=3}},
    joker_limit=5,modifiers={},interest_cap=25,interest_amount=1,bankrupt_at=0,
    reroll_cost=5,blind={key='bl_small',chips=100}}
  for i=1,52 do s.playing_cards[i]={id='manufactured:playing:'..i,rank=(i-1)%13+2,
    suit='Spades',enhancement='c_base'} end
  return s
end
local function stock(s) return S.manage_teacher_stock(s) end
local function settled_sale(s,index)
  local after=copy(s);local sold=table.remove(after.consumeables,index)
  after.dollars=after.dollars+sold.sell_cost
  if sold.edition and sold.edition.negative then after.consumable_limit=after.consumable_limit-1 end
  return after
end

do
  local s=state();local tower=item('c_tower','The Tower','Tarot')
  s.shop_jokers={tower}
  local before=Snapshot.fingerprint(s);local advice=S.advise(s)
  eq(advice.action.kind,'buy','a cheap early filler can seed an otherwise empty Perkeo pool')
  eq(advice.action.index,1,'the known Tower offer is the actual seed')
  eq(Snapshot.fingerprint(s),before,'shop seed valuation leaves the public state unchanged')
  s.shop_jokers[2]=item('c_strength','Strength','Tarot')
  advice=S.advise(s)
  eq(advice.action.index,2,'the empty-pool premium cannot make Tower beat a viable rank source')
  s.shop_jokers[3]=item('c_death','Death','Tarot')
  advice=S.advise(s)
  eq(advice.action.index,3,'a visible superior source beats temporary Stone filler')
  s.consumeables={tower};s.shop_jokers={}
  check(not stock(s),'the sole ordinary filler stays while no better source exists')
  s.consumeables={item('c_tower','The Tower','Tarot',true)};s.consumable_limit=3
  check(not stock(s),'the sole Negative filler stays while it is the only Perkeo source')
end

do
  local s=state();s.consumeables={item('c_tower','The Tower','Tarot'),
    item('c_tower','The Tower','Tarot',true)};s.consumable_limit=3
  local before=Snapshot.fingerprint(s);local sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.area=='consumeables' and
    sale.action.index==2 and not sale.action.followup,
    'a Negative Tower copy is sold one settled action at a time while ordinary filler remains')
  local after=settled_sale(s,sale.action.index)
  eq(after.consumable_limit,2,'Negative sale removes its granted capacity')
  eq(#after.consumeables,1,'ordinary placeholder remains for the next Perkeo exit')
  check(not stock(after),'refresh after sale keeps the now-sole source')
  eq(Snapshot.fingerprint(s),before,'sale proposal does not mutate or consume the observed inventory')
  local at_threshold=copy(s);at_threshold.dollars=25
  local capped=stock(at_threshold)
  check(capped and sale.stock_review.merit>capped.stock_review.merit,
    'crossing the public $25 interest threshold raises the sale merit')
  s.consumeable_buffer=1
  check(not stock(s),'pending consumable creation blocks speculative inventory cleanup')
  s.consumeable_buffer=0;s.consumeables[2].ability.eternal=true
  check(not stock(s),'Eternal Negative consumable is not sold')
  s.consumeables[2].ability.eternal=nil;s.consumeables[2].sell_cost=nil
  check(not stock(s),'missing sale price cannot fund a speculative sell')
  s.consumeables[2].sell_cost=1;s.consumeables[2].unknown=true
  check(not stock(s),'unknown physical identity cannot be selected for sale')
  s.consumeables[2].unknown=nil;s.consumable_limit=nil
  check(not stock(s),'missing exact capacity cannot authorize Negative filler disposal')
  s.consumable_limit=3;s.modifiers.minus_hand_size_per_X_dollar=5
  check(not stock(s),'cash-sensitive hand-size rule blocks unscored filler sale')
  s.modifiers={no_interest=true}
  local no_interest=stock(s)
  check(no_interest and no_interest.stock_review.merit<sale.stock_review.merit,
    'disabled interest receives no fabricated threshold reward')
end

do
  local s=state();s.consumeables={item('c_tower','The Tower','Tarot'),item('c_death','Death','Tarot')}
  local sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.index==1,
    'retained Death makes the Stone filler obsolete even when it is ordinary')
  s.consumeables={item('c_tower','The Tower','Tarot'),item('c_empress','The Empress','Tarot')}
  sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.index==1,
    'a useful non-Planet enhancement is not misclassified as weak filler')
  s.consumeables={item('c_mercury','Mercury','Planet'),item('c_venus','Venus','Planet')}
  s.used_vouchers={v_observatory=true}
  sale=stock(s)
  check(not sale,'secondary Observatory Planet remains a live scoring resource')
  s.used_vouchers={}
  sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.index==2,
    'without Observatory the off-plan Planet can leave while the preferred source stays')
  s.consumeables={item('c_mercury','Mercury','Planet'),item('c_mercury','Mercury','Planet',true)}
  s.used_vouchers={v_observatory=true}
  s.consumable_limit=3
  sale=stock(s)
  check(not sale or sale.action.index~=1 and sale.action.index~=2,
    'matching Observatory Planet copies are not blanket-sold')
  s.used_vouchers={}
  sale=stock(s)
  check(not sale or sale.action.kind~='sell',
    'useful repeated target Planets remain available without Observatory')
end

do
  local s=state();s.consumable_limit=1
  s.consumeables={item('c_tower','The Tower','Tarot')}
  s.shop_jokers={item('c_death','Death','Tarot')}
  local sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.area=='consumeables' and
    sale.stock_review.visible_replacement=='c_death',
    'full ordinary pool can retire a filler for a visible funded superior source')
  s._shop_scoring={truncated=true}
  check(not stock(s),'a truncated shared shop comparison cannot license selling the sole source')
  s._shop_scoring=nil
  local decided=Decision.run(s,{strategy=S})
  check(decided.action.kind=='sell' and decided.action.index==sale.action.index and
    not decided.action.followup,
    'complete shop decision publishes only the settled first sale')
  local after=settled_sale(s,sale.action.index)
  decided=Decision.run(after,{strategy=S})
  eq(decided.action.kind,'buy','settled sale is followed by fresh visible purchase advice')
  eq(decided.action.index,1,'the actual superior offer is still chosen after reobservation')
  s.consumeables[2]=item('c_tower','The Tower','Tarot',true)
  s.consumable_limit=2
  sale=stock(s)
  check(sale and sale.action.kind=='sell' and
    not (s.consumeables[sale.action.index].edition or {}).negative,
    'a Negative sale is not mistaken for a free ordinary slot before buying')
  after=settled_sale(s,sale.action.index)
  check(#after.consumeables<after.consumable_limit,'ordinary filler sale really opens the slot')
  s.consumeables={s.consumeables[1]};s.consumable_limit=1
  s.shop_jokers[1].cost=100
  sale=stock(s)
  check(not sale or not sale.stock_review.visible_replacement,
    'unaffordable visible offer cannot license a last-source sale-to-buy plan')
  s.shop_jokers[1].cost=3;s.shop_jokers[1].face_down=true
  sale=stock(s)
  check(not sale or not sale.stock_review.visible_replacement,
    'concealed offer cannot license a known replacement sale')
end

do
  local s=state();s.consumeables={item('c_moon','The Moon','Tarot'),
    item('c_moon','The Moon','Tarot',true)};s.consumable_limit=3
  local sale=stock(s)
  check(sale and sale.action.index==2,'non-Flush suit-conversion Negative is temporary filler')
  s.hands.Flush={played=12,level=3,chips=45,mult=4};s.hands.Pair.played=0
  sale=stock(s)
  check(not sale or sale.action.kind~='sell',
    'a suit Tarot is not blanket-sold when the public plan actually favors Flush')
  s.consumeables={item('c_tower','The Tower','Tarot'),item('c_tower','The Tower','Tarot',true)}
  s.consumable_limit=3;s.teacher_profile='collection_progress'
  check(not stock(s),'collection profile retains its own consumable policy')
  s.teacher_profile='perkeo_yorick_win_v1';s.jokers={}
  check(not stock(s),'no active Perkeo copying source disables the stock manager')
end

do
  local s=state();s.consumeables={item('c_hanged_man','The Hanged Man','Tarot',true)}
  s.consumable_limit=3;s.playing_cards={}
  for i=1,28 do s.playing_cards[i]={id='manufactured:held:'..i,rank=(i-1)%13+2,suit='Spades'} end
  local sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.index==1,
    'exhausted Negative Hanged Man has zero useful removals and is sold')
  s=state();s.consumeables={item('c_strength','Strength','Tarot'),
    item('c_strength','Strength','Tarot'),item('c_strength','Strength','Tarot',true)}
  s.consumable_limit=3
  sale=stock(s)
  check(sale and sale.action.kind=='sell' and sale.action.index==3,
    'Negative Strength beyond the public useful-stock cap can become cash')
end

print('advisor_perkeo_filler389: '..checks..' manufactured checks passed')
