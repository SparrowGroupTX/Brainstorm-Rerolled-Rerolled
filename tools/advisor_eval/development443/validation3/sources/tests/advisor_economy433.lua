-- Invented shop offers and inventory only; no public-session replay.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules();local S=m.strategy
if STRATEGY433_PATH then S=dofile(STRATEGY433_PATH)end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function tarot(key,negative)
 return {id=key,key=key,name=key,cost=3,sell_cost=1,edition=negative and {negative=true} or nil,ability={name=key,set='Tarot'}}
end
local function planet(key,hand)
 return {id=key,key=key,name=key,cost=3,sell_cost=1,ability={name=key,set='Planet',consumeable={hand_type=hand}}}
end
local function state()
 local s=F.state(false);s.phase='shop';s.dollars=38;s.ante=3;s.reroll_cost=6;s.joker_limit=5
 s.shop_jokers={};s.shop_vouchers={};s.shop_booster={};s.consumeables={}
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),F.j('j_blueprint'),F.j('j_greedy_joker'),F.j('j_ice_cream')}
 s.hands={Flush={played=7,level=2,chips=50,mult=6,l_chips=15,l_mult=2},Pair={played=0,level=1,chips=10,mult=2}}
 s.round_resets={hands=4,discards=3};s.next_blind={key='bl_big',name='Big Blind',ante=3,chips=2000}
 return s
end
do
 local s=state();s.shop_booster={{key='p_buffoon_normal_1',name='Buffoon Pack',cost=3,ability={set='Booster'}}}
 local a=S.advise(s)
 if EXPECT_BASELINE433 then
  check(a.action.kind~='open','baseline full owned-Blueprint row refuses Buffoon')
 else
  check(a.action.kind=='open' and a.action.area=='shop_booster','owned Blueprint continues funded copy exploration')
  check(#s.jokers==5 and s.dollars==38,'no speculative sale before pack reveal')
  s.dollars=17;check(S.advise(s).action.kind~='open','future copy purchase cash protected')
  s.dollars=38;s.jokers[4].ability.eternal=true;s.jokers[5].ability.eternal=true
  check(S.advise(s).action.kind~='open','no disposable ordinary slot means no full-row pack speculation')
  s=state();s.shop_booster={{key='p_buffoon_normal_1',name='Buffoon',cost=3,ability={set='Booster'}}}
  s.jokers={F.j('j_yorick'),F.j('j_perkeo'),F.j('j_blueprint')};s.joker_limit=4;s.dollars=11
  s.shop_jokers={F.j('j_blueprint')};s.shop_jokers[1].cost=10
  local a=S.advise(s);check(a.action.kind=='buy' and a.action.area=='shop_jokers','visible affordable copy precedes unknown pack')
 end
end
for _,ante in ipairs({1,3,4,5,6,7,8})do
 local s=state();s.ante=ante;local target=ante>=7 and 25 or ante>=4 and 35 or 50;s.dollars=target+1;s.reroll_cost=7
 local base={action={kind='leave_shop'}};local a=S.late_cash_spend(s,base)
 if EXPECT_BASELINE433 then check(not a,'baseline indivisible cash cost blocked')else
  check(a and a.action.kind=='reroll' and a.late_spend_review.cash_after==target-6,'one spend crosses preferred target '..ante)
  check(a.late_spend_review.floor==a.late_spend_review.reserve,'target separated from hard reserve')
  s.dollars=target;check(not S.late_cash_spend(s,{action={kind='leave_shop'}}),'target equality stops preference')
  s.dollars=target+1;check(not S.late_cash_spend(s,{action={kind='buy'}}),'real purchase preempts cash rule')
  check(not S.late_cash_spend(s,{action={kind='leave_shop'}},{complete_paid_miss=true,lost_clear=true}),'proven survival loss veto')
  s.shop_booster={{key='p_arcana_normal_1',name='Arcana',cost=3,ability={set='Booster'}}}
  local a=S.late_cash_spend(s,{action={kind='leave_shop'}});check(a and a.action.kind=='open','useful visible pack precedes refresh')
 end
end
do
 local s=state();s.ante=7;s.dollars=34;s.reroll_cost=7;s.modifiers.discard_cost=10
 check(not S.late_cash_spend(s,{action={kind='leave_shop'}}),'mandatory discard reserve remains hard')
end
-- Ten held cards include eight Negative Worlds. Only the ordinary card can
-- release a slot; compare the whole remaining random Perkeo pool and cash.
do
 local s=state();s.dollars=35;s.consumable_limit=10;s.last_tarot_planet='c_jupiter'
 s.consumeables={tarot('c_world'),tarot('c_heirophant')}
 for i=3,10 do s.consumeables[i]=tarot('c_world',true);s.consumeables[i].id='negative:'..i end
 s.shop_jokers={tarot('c_fool'),planet('c_jupiter','Flush')}
 local before=m.snapshot.fingerprint(s);local a=S.manage_teacher_stock(s)
 if EXPECT_BASELINE433 then check(not a or not a.stock_review.visible_replacement,'baseline ordinary stock replacement not admitted')else
  check(a and a.action.kind=='sell' and a.stock_review.visible_replacement,'whole-pool visible replacement admitted')
  check(a.action.index<=2 and not s.consumeables[a.action.index].edition,'ordinary sale creates real capacity')
  check(m.snapshot.fingerprint(s)==before,'inventory/cash untouched by plan')
  local sold=table.remove(s.consumeables,a.action.index);s.dollars=s.dollars+sold.sell_cost
  local next=S.advise(s)
  check(next.action.kind=='buy' and next.action.area=='shop_jokers','fresh observation purchases useful visible stock: '..next.action.kind..' / '..tostring(next.stock_review and next.stock_review.index))
  local key=s.shop_jokers[next.action.index].key;check(key=='c_fool' or key=='c_jupiter','only supported stock source selected')
  check(#s.consumeables==9 and s.consumable_limit==10,'Negative slots retained, single ordinary vacancy')
 end
 -- An all-Negative full inventory cannot be turned into an ordinary slot.
 for _,c in ipairs(s.consumeables)do c.edition={negative=true}end;s.consumable_limit=#s.consumeables
 local a=S.manage_teacher_stock(s)
 check(not a or not a.stock_review.visible_replacement,'Negative sale cannot fund a nonexistent slot')
end
if EXPECT_BASELINE433 then print('Baseline433: Buffoon, spending and stock gaps reproduced');return end
-- A misleading Fool history, unknown stock, unaffordable target, or a filled
-- scoring resource must not become a fictitious exchange.
for _,case in ipairs({'fool_after_fool','unknown','unaffordable','buffer','observatory','secondary_observatory','cash_hand_size','cash_chip_cap'})do
 local s=state();s.consumable_limit=1;s.consumeables={tarot('c_world')};s.shop_jokers={tarot('c_fool')};s.last_tarot_planet='c_jupiter'
 if case=='fool_after_fool' then s.last_tarot_planet='c_fool'
 elseif case=='unknown' then s.consumeables[1].unknown=true
 elseif case=='unaffordable' then s.dollars=0;s.shop_jokers[1].cost=50
 elseif case=='buffer' then s.consumeable_buffer=1
 elseif case=='observatory' then s.consumeables={planet('c_jupiter','Flush')};s.used_vouchers={v_observatory=true}
 elseif case=='secondary_observatory' then
  s.consumeables={planet('c_mercury','Pair')};s.used_vouchers={v_observatory=true};s.shop_jokers[2]=planet('c_jupiter','Flush')
 elseif case=='cash_hand_size' then s.modifiers.minus_hand_size_per_X_dollar=5
 elseif case=='cash_chip_cap' then s.modifiers.chips_dollar_cap=true end
 local a=S.manage_teacher_stock(s);check(not a or not a.stock_review.visible_replacement,'no phantom exchange '..case)
 if case=='secondary_observatory' then check(not a,'secondary Observatory multiplier remains held')end
end
print('Economy433: '..n..' manufactured assertions passed')
