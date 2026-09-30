-- Manufactured late-shop state using all production dependency wiring.
-- No captured state, source execution, gameplay callback, profile or RNG.
package.preload.nativefs=function()
  return {read=function(path)
    local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close();return bytes
  end}
end
Brainstorm={PATH='Brainstorm',config={}}
local f=assert(io.open('Brainstorm/Advisor/runtime.lua','rb'));local text=f:read('*a');f:close()
local boundary=assert(text:find('\nfunction A.defaults()',1,true))
local A=assert(loadstring(text:sub(1,boundary-1)..'\nreturn A','@manufactured_cartomancer_runtime_dependencies'))()
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local copy=A.snapshot.copy
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(key,id,name,ability)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {key=key,id=id,name=name,ability=ability,cost=5,base_cost=5,sell_cost=2,debuff=false,
    face_down=false,pinned=false,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=8,win_ante=8,dollars=170,bankrupt_at=0,joker_limit=6,consumable_limit=14,
    consumeable_buffer=0,consumeables=F.state().consumeables,consumeable_usage_total={tarot=8},
    jokers={joker('j_yorick','y','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
      joker('j_perkeo','p','Perkeo'),joker('j_brainstorm','b','Brainstorm',{eternal=true}),
      joker('j_caino','c','Caino',{caino_xmult=2,extra=1}),joker('j_cartomancer','ca','Cartomancer',{eternal=true}),
      joker('j_golden','g','Golden Joker',{extra=4,eternal=true})},
    shop_jokers={joker('j_crafty','offer','Crafty Joker',{t_chips=80,type='Flush',eternal=true})},shop_booster={},shop_vouchers={},
    next_blind={key='bl_final_leaf',name='Verdant Leaf',boss=true,disabled=false,chips=200000,ante=8,debuff={}},
    blind={key='bl_big',name='Big Blind',boss=false,disabled=true,chips=100000},
    hand_size=4,hand_limit=5,hands_left=4,discards_left=3,round_resets={hands=4,discards=3},current_round={},
    modifiers={},probabilities={normal=1},hands={},playing_cards={},hand={},deck={},ordering_safe=true,jokers_shuffling=false,
    interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',shop_forecast={inflation=0,discount_percent=0},
    used_vouchers={},completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={eligible=true},by_key={j_crafty={status='missing'}}}}
  s.jokers[2].edition={negative=true,type='negative'}
  for _,j in ipairs(s.jokers) do s.completionist_goal.by_key[j.key]={status='complete'} end
  for _,hand in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind',
      'Straight Flush','Five of a Kind','Flush House','Flush Five'}) do s.hands[hand]={chips=1000,mult=100,level=100,played=1} end
  for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}} end
  return s
end
math.random=function() error('No RNG in manufactured Cartomancer fixture') end;pseudorandom=math.random;pseudoseed=math.random
local calls,floors,leaf_calls=0,0,0
local score,lower=A.scoring.score,A.scoring.lower_bound
A.scoring.score=function(...) calls=calls+1;return score(...) end
A.scoring.lower_bound=function(s,selected)
  floors=floors+1
  if s.blind.key=='bl_final_leaf' then
    leaf_calls=leaf_calls+1
    check(s.blind.disabled==false,'a sale in the prior shop cannot disable the future Leaf')
    for _,c in ipairs(s.playing_cards) do check(c.debuff,'all Leaf playing cards remain debuffed in prospective scoring') end
  end
  local result=lower(s,selected)
  check(result.legal==false or result.reliable_bound and not result.uncertain,'admitted Cartomancer gives a reliable scoring floor')
  check(not result.warnings or next(result.warnings)==nil,'inactive Cartomancer produces no unmodeled scoring warning')
  return result
end
check(A.shop_scoring.gold_goal==A.gold_goal,'production Shop uses the same capacity-qualified Gold classifier')
check(A.shop_scoring.blind_finishing==A.blind_finishing and A.shop_scoring.blind_prep==A.blind_prep,'production planning dependencies are active')
local yields=0
local function run(fn)
  local result
  local worker=coroutine.create(function() result={fn(function() yields=yields+1;coroutine.yield() end)} end)
  repeat local ok,why=coroutine.resume(worker);check(ok,'real dependency worker resumes: '..tostring(why)) until coroutine.status(worker)=='dead'
  return unpack(result)
end
local function decide(s)
  return run(function(yield_fn) return A.decision.run(s,A,yield_fn) end)
end
local function advise(s,options)
  return run(function(yield_fn) return A.gold_acquisition.suggest(s,A,yield_fn,options) end)
end
do
  local s=state();local original=A.snapshot.fingerprint(s)
  check(A.gold_goal.cartomancer_inert(s,s.jokers[5]),'full settled inventory makes the source startup predicate false')
  check(A.gold_goal.stable_card(s.jokers[5],A.gold_perkeo,s),'Cartomancer admission is tied to this exact full state')
  check(not A.gold_goal.stable_card(s.jokers[5],A.gold_perkeo),'Cartomancer does not become unconditional stable support')
  local before_calls,before_floors=calls,floors
  local result=decide(s);local d=result.gold_acquisition_diagnostics
  check(d and d.complete and d.projection_complete,'production Decision completes six-Joker Leaf acquisition: '..tostring(d and d.reason))
  eq(result.action.kind,'sell','the full row must sell before buying')
  eq(result.action.index,4,'the one removable ordinary slot is Caino')
  eq(result.action.followup.kind,'buy','the exact paid continuation remains visible')
  eq(result.action.followup.index,1,'the continuation buys visible Crafty')
  eq(result.evaluations,calls-before_calls,'every actual scoring call is charged')
  eq(result.evaluations,floors-before_floors,'every scored comparison uses supported floors')
  check(result.evaluations<=50000,'the existing shared shop allowance is retained')
  eq(#d.endpoints,2,'hold and sale-Caino/buy-Crafty are the complete legal family')
  eq(d.after_missing,1,'only the actual added missing key receives objective value')
  local negative_blocked=false
  for _,e in ipairs(d.excluded) do
    if e.actions and e.actions[1].kind=='sell' and e.actions[1].index==2 then negative_blocked=true end
  end
  check(negative_blocked,'selling Negative Perkeo cannot invent an ordinary Joker slot')
  for _,e in ipairs(d.endpoints) do
    eq(e.evidence.samples,4,'four full common public worlds')
    eq(e.evidence.common_worlds.family_key,d.endpoints[1].evidence.common_worlds.family_key,'every legal endpoint uses the same draws')
    eq(e.hold_certificate.free_slots_after,0,'Perkeo adds a card and slot, preserving Cartomancer inactivity')
    eq(e.hold_certificate.inventory_count_after,e.hold_certificate.capacity_after,'post-copy inventory remains full')
    for _,r in ipairs({e.evidence.before_readiness,e.evidence.after_readiness}) do
      eq(r.ordering.layouts,1,'exactly one fixed current row is assumed')
      eq(r.ordering.action_count,0,'no unexecuted reorder is credited')
      for i,index in ipairs(r.ordering.order) do eq(index,i,'current row index is preserved') end
      for i=1,4 do check(r.opening_scores[i]>=250000,'every debuffed Leaf opening retains the declared margin') end
    end
  end
  local sold=assert(A.shop_sequences.transition(s,result.action,A))
  eq(sold.next_blind.disabled,false,'the paid shop sale leaves future Leaf enabled')
  local paid,charged=calls,floors
  local buy=decide(sold)
  check(buy.gold_acquisition_diagnostics and buy.gold_acquisition_diagnostics.complete,'fresh Decision completes the target purchase')
  eq(buy.action.kind,'buy','fresh shop state buys instead of reselling or leaving')
  eq(buy.evaluations,calls-paid,'fresh decision charges its own calls')
  eq(buy.evaluations,floors-charged,'fresh purchase uses supported floors')
  local bought=assert(A.shop_sequences.transition(sold,buy.action,A))
  eq(#bought.jokers,6,'the final physical row has six Jokers')
  eq(bought.jokers[6].key,'j_crafty','visible missing Crafty is retained')
  check(bought.jokers[6].ability.eternal,'the actual target Eternal status is preserved')
  eq(bought.dollars,167,'only exact sale and purchase cash effects are applied')
  eq(A.snapshot.fingerprint(bought.consumeables),A.snapshot.fingerprint(s.consumeables),'all original physical Tarots are unchanged')
  eq(A.snapshot.fingerprint(s),original,'all proof and scoring work leaves the original state unchanged')
  check(leaf_calls>0 and yields>0,'actual Leaf floor comparisons yielded cooperatively')
end
do
  local changes={
    {'unknown capacity',function(s) s.consumable_limit=nil end},
    {'string capacity',function(s) s.consumable_limit='14' end},
    {'one free slot',function(s) s.consumable_limit=15 end},
    {'pending buffer',function(s) s.consumeable_buffer=1 end},
    {'unknown buffer',function(s) s.consumeable_buffer=nil end},
    {'boolean buffer',function(s) s.consumeable_buffer=false end},
    {'wrong inventory type',function(s) s.consumeables='fourteen' end},
    {'metatable inventory',function(s) setmetatable(s.consumeables,{}) end},
    {'sparse inventory',function(s) s.consumeables[3]=nil end},
    {'non-card inventory',function(s) s.consumeables[3]=true end},
    {'named extra entry',function(s) s.consumeables.extra=s.consumeables[1] end},
    {'fractional capacity',function(s) s.consumable_limit=14.5 end},
    {'false source name',function(s) s.jokers[5].ability.name='Unknown' end},
    {'false public name',function(s) s.jokers[5].name='Unknown' end},
    {'unknown copy compatibility',function(s) s.jokers[5].blueprint_compat=nil end},
    {'startup destruction',function(s) s.jokers[5]=joker('j_madness','ca','Madness',{eternal=true}) end},
    {'startup population',function(s) s.jokers[5]=joker('j_marble','ca','Marble Joker',{eternal=true}) end},
  }
  for _,entry in ipairs(changes) do
    local s=state();entry[2](s)
    check(not A.gold_goal.cartomancer_inert(s,s.jokers[5]),'Cartomancer exact predicate rejects '..entry[1])
    local before=calls;local a,work,d=advise(s)
    check(not a and not d.complete and work==0 and calls==before,'the full acquisition declines before scoring for '..entry[1])
  end
  local s=state();local carto=s.jokers[5]
  carto.ability.perishable=true;carto.ability.perish_tally=nil
  check(not A.gold_goal.stable_card(carto,A.gold_perkeo,s),'unknown Cartomancer perish timing remains unsupported')
  s=state();local prior=calls;local a,work,d=advise(s,{max_evaluations=1})
  check(not a and not d.complete and work<=1 and work==calls-prior and d.truncated,'an incomplete budget never publishes a prior successful endpoint')
  s=state();s.next_blind={key='bl_final_acorn',name='Amber Acorn',boss=true,chips=200000,ante=8}
  a,work,d=advise(s);check(not a and not d.complete and work==0,'unknown final-order startup remains outside this family')
  s=state();local c=A.shop_scoring.new(s,A.scoring,nil,{max_evaluations=50000})
  local ordinary=c:compare(s,s)
  check(not ordinary or ordinary.incomplete or not ordinary.after_readiness or not ordinary.after_readiness.supported,'ordinary shop planning does not inherit the fixed-hold-only Cartomancer exception')
end
print('advisor_gold_cartomancer: '..checks..' checks; '..calls..' score calls; '..floors..' floors; '..leaf_calls..' Leaf floors; '..yields..' cooperative yields')
