-- Exact production dependency wiring and Decision.run on manufactured data.
-- Only runtime.lua's pure module initialization prefix is executed; no hooks,
-- UI, update loop, filesystem journal, game object or gameplay callback runs.
package.preload.nativefs=function()
  return {read=function(path)
    local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close();return bytes
  end}
end
Brainstorm={PATH='Brainstorm',config={}}
local f=assert(io.open('Brainstorm/Advisor/runtime.lua','rb'));local text=f:read('*a');f:close()
local boundary=assert(text:find('\nfunction A.defaults()',1,true))
local A=assert(loadstring(text:sub(1,boundary-1)..'\nreturn A','@manufactured_runtime_module_initialization'))()
local Support=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(key,id,name,ability)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {key=key,id=id,name=name,ability=ability,cost=5,base_cost=5,sell_cost=2,debuff=false,
    face_down=false,pinned=false,blueprint_compat=true}
end
local s={phase='shop',ante=8,win_ante=8,dollars=170,bankrupt_at=0,joker_limit=5,consumable_limit=16,
  consumeable_buffer=0,consumeables=Support.state().consumeables,consumeable_usage_total={tarot=8},
  jokers={joker('j_yorick','y','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
    joker('j_perkeo','p','Perkeo',{eternal=true}),joker('j_brainstorm','b','Brainstorm',{eternal=true}),
    joker('j_scary_face','s','Scary Face',{extra=30}),joker('j_golden','g','Golden Joker',{extra=4})},
  shop_jokers={joker('j_crazy','offer','Crazy Joker',{t_mult=12,type='Straight'})},shop_booster={},shop_vouchers={},
  next_blind={key='bl_big',name='Big Blind',boss=false,chips=1000,ante=8},blind={key='bl_small',disabled=true,chips=500},
  hand_size=4,hand_limit=5,hands_left=4,discards_left=3,round_resets={hands=4,discards=3},current_round={},
  modifiers={},probabilities={normal=1},hands={},playing_cards={},hand={},deck={},ordering_safe=true,jokers_shuffling=false,
  interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',shop_forecast={inflation=0,discount_percent=0},
  used_vouchers={},completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
    eligibility={eligible=true},by_key={j_crazy={status='missing'}}}}
for _,j in ipairs(s.jokers) do s.completionist_goal.by_key[j.key]={status='complete'} end
for _,hand in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind',
    'Straight Flush','Five of a Kind','Flush House','Flush Five'}) do s.hands[hand]={chips=100,mult=10,level=10,played=1} end
for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}} end
math.random=function() error('No RNG belongs in this manufactured dependency fixture') end;pseudorandom=math.random
local calls,floors=0,0;local score,lower=A.scoring.score,A.scoring.lower_bound
A.scoring.score=function(...) calls=calls+1;return score(...) end
A.scoring.lower_bound=function(...) floors=floors+1;return lower(...) end
check(A.shop_scoring.blind_finishing==A.blind_finishing,'production finishing dependency is active')
check(A.shop_scoring.blind_prep==A.blind_prep and A.blind_prep.blind_start==A.shop_scoring.blind_start,'production startup/preparation dependencies are active')
check(A.shop_scoring.paired_deck and A.shop_scoring.work_cost and A.score_cache,'production paired population, work cost and score-cache modules are active')
local original=A.snapshot.fingerprint(s)
local yields=0
local function decide(snapshot)
  local result
  local worker=coroutine.create(function()
    result=A.decision.run(snapshot,A,function() yields=yields+1;coroutine.yield('score_budget_boundary') end)
  end)
  repeat
    local ok,why=coroutine.resume(worker)
    check(ok,'the actual Decision worker must resume across its score budget yield: '..tostring(why))
  until coroutine.status(worker)=='dead'
  return result
end
local result=decide(s)
check(result.gold_acquisition_diagnostics and result.gold_acquisition_diagnostics.complete,'actual Decision prioritizes the complete acquisition with production dependencies')
eq(result.action.kind,'sell','the actual decision publishes the required completed-Joker sale')
eq(result.action.followup.kind,'buy','the missing-target continuation survives phase-copy postprocessing')
eq(result.evaluations,calls,'decision reports every actual score pass under production score caching')
eq(result.evaluations,floors,'all charged score work uses reliable floors')
eq(result.score_cache.score_calls,calls,'the score cache receipt includes every acquisition floor call')
check(calls<=50000,'production decision retains the shared shop cap')
eq(result.gold_acquisition_diagnostics.after_missing,1,'the actual production chain prioritizes one missing identity')
eq(result.gold_acquisition_diagnostics.selected.hold_certificate.inventory_count_before,14,'all fourteen mixed Negative Tarots are certified')
local sold=assert(A.shop_sequences.transition(s,result.action,A));local before=calls
local next=decide(sold)
check(next.gold_acquisition_diagnostics and next.gold_acquisition_diagnostics.complete,'fresh actual Decision still completes the target purchase')
eq(next.action.kind,'buy','fresh decision buys the visible missing Joker')
eq(next.evaluations,calls-before,'the second production decision independently charges its actual calls')
local bought=assert(A.shop_sequences.transition(sold,next.action,A))
eq(bought.jokers[#bought.jokers].key,'j_crazy','the exact paid physical target is retained')
eq(A.snapshot.fingerprint(bought.consumeables),A.snapshot.fingerprint(s.consumeables),'the real transition chain preserves every original Tarot')
eq(A.snapshot.fingerprint(s),original,'production dependency scoring and all detached transitions preserve input')
check(yields>0,'the real bounded Shop comparisons yielded cooperatively in Lua 5.1')
print('gold acquisition coroutine runtime wiring: '..checks..' checks; '..calls..' actual floor passes; '..yields..' yields; sale and fresh purchase, no source/game execution')
