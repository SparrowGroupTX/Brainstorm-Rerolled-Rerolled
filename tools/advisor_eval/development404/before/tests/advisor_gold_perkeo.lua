-- Detached synthetic fixtures only: no original source, player profile, or RNG.
local path='Brainstorm/Advisor/'
local P=dofile(path..'gold_perkeo.lua')
local Goal=dofile(path..'gold_goal.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity
local mods={strategy=Strategy,shop_sequences=Sequences,shop_scoring=Shop,
  liquidity=Liquidity,gold_perkeo=P}
local count=0
local function check(x,m) count=count+1;assert(x,m) end
local function eq(a,b,m) check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local copy=Snapshot.copy
local function card(key,id,name,a)
  a=a or {};a.set='Joker';a.name=name
  return {key=key,id=id,name=name,ability=a,cost=5,sell_cost=5,base_cost=5,
    debuff=false,pinned=false,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=8,win_ante=8,dollars=20,bankrupt_at=0,joker_limit=2,
    consumable_limit=2,consumeable_buffer=0,consumeables={},
    jokers={card('j_joker','engine','Joker',{mult=4,eternal=true}),card('j_perkeo','p','Perkeo')},
    shop_jokers={card('j_golden','offer','Golden Joker',{extra=4})},
    shop_booster={},shop_vouchers={},hand_size=4,hand_limit=5,hands_left=4,discards_left=3,
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',hands={},playing_cards={},hand={},deck={},
    next_blind={key='bl_final_vessel',name='Violet Vessel',boss=true,ante=8,chips=100},
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={status='eligible',eligible=true},by_key={j_joker={status='complete'},j_perkeo={status='complete'},
        j_golden={status='missing'},j_blueprint={status='complete'},j_brainstorm={status='complete'}}}}
  for _,h in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
      'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}) do
    s.hands[h]={level=20,chips=100,mult=20,played=1}
  end
  for i=1,12 do s.playing_cards[i]={id='pc'..i,rank=2+i%8,nominal=2+i%8,
    suit=({'Spades','Hearts','Clubs','Diamonds'})[1+i%4],ability={}} end
  return s
end
local function suggest(s,modules)
  local ctx=Shop.new(s,Score,nil,{max_evaluations=50000})
  local a,d=Goal.suggest(s,modules or mods,{action={kind='leave_shop'}},ctx)
  check(ctx.evaluations<=50000,'no score cap increase')
  return a,d,ctx
end
do
  local s=state();local before=Snapshot.fingerprint(s)
  local out,r=P.project(s)
  check(out and r.supported,'empty Perkeo exit has exact transition')
  eq(Snapshot.fingerprint(out),before,'zero-copy transition preserves every detached field')
  eq(r.copy_events,0,'empty pool generates zero cards')
  eq(#r.physical_sources,1,'single Perkeo source is identified')
  eq(r.physical_sources[1].perkeo_id,'p','physical identity remains bound')
  check(r.all_legal_arrangements_same_inventory,'zero inventory is arrangement invariant')
  eq(r.first_hand_consumable_actions,0,'no first-hand consumable action is invented')
  local a,d=suggest(s)
  check(a and d.complete and d.evidence_complete,'real scorer completes empty-pool cargo replacement')
  eq(a.action.kind,'sell','full physical row requires actual sale first')
  eq(a.action.index,2,'sell the completed Perkeo')
  eq(d.selected.actions[2].kind,'buy','full paid endpoint includes the missing Joker purchase')
  eq(d.selected.cash_after,20,'sale and purchase use actual prices')
  eq(d.incumbent.shop_exit.scope,'empty_perkeo_shop_exit','reference includes explicit exit certificate')
  eq(d.selected.shop_exit.scope,'no_perkeo','sale endpoint no longer has a copying actor')
  eq(d.after_missing,1,'only newly carried actual missing identity gains objective credit')
  eq(Snapshot.fingerprint(s),before,'complete comparison does not mutate input')
  check(not Goal.stable_card(s.jokers[2]),'Perkeo remains outside unconditional stable whitelist')
end
do
  local s=state();s.joker_limit=3;s.jokers[2].edition={negative=true,type='negative'}
  s.used_vouchers={v_observatory=true};s.consumable_limit=4
  local out,r=P.project(s)
  check(out and r.observatory_inventory_unchanged,'empty Observatory inventory unchanged')
  eq(out.consumable_limit,4,'voucher-created capacity retained')
  eq(out.joker_limit,3,'Negative Joker capacity retained on exit')
  local a,d=suggest(s)
  check(a and d.complete,'exact negative-capacity paid comparison completes')
  eq(a.action.kind,'buy','free physical capacity need not discard completed Perkeo')
  local found
  for _,p in ipairs(d.endpoints) do if #p.actions==2 and p.actions[1].kind=='sell' then found=p end end
  check(found,'legal negative sale then buy included')
  eq(#found.jokers,2,'Negative sale projects exact final row')
  eq(found.shop_exit.scope,'no_perkeo','sold Negative Perkeo cannot copy')
end
do
  local s=state();s.jokers={card('j_blueprint','bp','Blueprint'),card('j_perkeo','p','Perkeo'),
    card('j_brainstorm','bs','Brainstorm')};s.joker_limit=3
  local out,r=P.project(s)
  eq(#r.physical_sources,3,'Blueprint and Brainstorm chain resolve to Perkeo')
  eq(r.copy_events,0,'three potential activations still generate zero without a pool')
  s.jokers[2].ability.perishable=true;s.jokers[2].ability.perish_tally=0
  out,r=P.project(s);eq(#r.physical_sources,0,'expired Perkeo and copying chains generate nothing')
  s.jokers[2].ability.perishable=nil;s.jokers[2].ability.perish_tally=nil
  s.jokers[1],s.jokers[2]=s.jokers[2],s.jokers[1];s.jokers[1].pinned=true
  out,r=P.project(s);check(out and r.all_legal_arrangements_same_inventory,'pinned arrangement needs no invented move')
  eq(out.jokers[1].id,'p','pinned physical order preserved')
end
do
  for _,mutate in ipairs({
    function(s) s.consumeable_buffer=1 end,
    function(s) s.consumeable_buffer=nil end,
    function(s) s.consumeables={{id='x',key='c_mercury',ability={set='Planet'}}} end,
    function(s) s.consumeables={hidden_pending=true} end,
    function(s) s.jokers[2].blueprint_compat=nil end,
    function(s) s.jokers[2].ability.name='Custom Perkeo' end,
    function(s) s.jokers[2].face_down=true end,
    function(s) s.jokers[2].id=s.jokers[1].id end,
    function(s) s.jokers[2].ability.perishable=true;s.jokers[2].ability.perish_tally=nil end,
    function(s) s.ordering_safe=false end,
    function(s) s.jokers_shuffling=true end}) do
    local s=state();mutate(s)
    local out,why=P.project(s);check(not out and type(why)=='string','unknown/in-flight projection is explicit')
    local a,d=suggest(s);check(not a and not d.complete,'unsupported endpoint cannot grant cargo credit')
  end
  local s=state();s.consumeables={
    {id='p1',key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}},
    {id='p2',key='c_mercury',edition={negative=true},ability={set='Planet',consumeable={hand_type='Pair'}}}}
  s.consumable_limit=3;s.used_vouchers={v_observatory=true}
  local a,d,c=suggest(s)
  check(not a and not d.complete,'same-name ordinary/Negative pool is not silently treated as exact')
  eq(c.evaluations,0,'unsupported nonempty pool declines before scoring')
  s=state();local without=copy(mods);without.gold_perkeo=nil
  a,d=suggest(s,without);check(not a and not d.complete,'missing projection module fails closed')
end
do
  local s=state();s.completionist_goal.by_key.j_perkeo.status='missing'
  local a,d=suggest(s)
  check(not a and d.complete,'trading one missing key for one other does not invent progress')
  s=state();s.jokers[2].ability.eternal=true
  a,d=suggest(s);check(not a and d.complete,'Eternal completed Perkeo is not sold')
  s=state();s.jokers[2].pinned=true
  a,d=suggest(s);check(not a and d.complete,'pinned completed Perkeo is not sold')
end
print('gold Perkeo empty-exit: '..count..' checks passed; synthetic exact comparison only')
