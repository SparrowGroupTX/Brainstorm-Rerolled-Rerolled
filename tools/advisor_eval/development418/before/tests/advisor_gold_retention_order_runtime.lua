-- Manufactured public states only; pure product dependencies, no player replay.
package.preload.nativefs=function()return {read=function(p)local f=assert(io.open(p,'rb'));local x=f:read('*a');f:close();return x end}end
Brainstorm={PATH='Brainstorm',config={}}
local f=assert(io.open('Brainstorm/Advisor/runtime.lua','rb'));local source=f:read('*a');f:close()
local boundary=assert(source:find('\nfunction A.defaults()',1,true))
local A=assert(loadstring(source:sub(1,boundary-1)..'\nreturn A','@manufactured_retention_order_modules'))()
local R=dofile('Brainstorm/Advisor/gold_retention.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local O=A.gold_order
local Q=A.shop_scoring

local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function cp(x)if type(x)~='table'then return x end;local r={};for k,v in pairs(x)do r[k]=cp(v)end;return r end
local function joker(key,id,name,ability)
 ability=ability or {};ability.name=name;ability.set='Joker'
 return {key=key,id=id,name=name,ability=ability,cost=5,base_cost=5,sell_cost=2,debuff=false,face_down=false,pinned=false,blueprint_compat=true}
end
local function state()
 local s={phase='shop',ante=8,win_ante=8,dollars=170,bankrupt_at=0,joker_limit=5,consumable_limit=16,
  consumeable_buffer=0,consumeables=F.state().consumeables,consumeable_usage_total={tarot=8},
  jokers={joker('j_perkeo','p','Perkeo',{eternal=true}),
   joker('j_yorick','y','Yorick',{x_mult=2,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
   joker('j_caino','c','Caino',{caino_xmult=5,extra=1}),
   joker('j_brainstorm','b','Brainstorm',{eternal=true}),
   joker('j_crazy','missing','Crazy Joker',{t_mult=12,type='Straight'})},
  shop_jokers={joker('j_golden','gold','Golden Joker',{extra=4})},shop_booster={},shop_vouchers={},
  next_blind={key='bl_big',name='Big Blind',boss=false,chips=15000,ante=8},blind={key='bl_small',disabled=true,chips=500},
  hand_size=4,hand_limit=5,hands_left=4,discards_left=3,round_resets={hands=4,discards=3},current_round={},
  modifiers={},probabilities={normal=1},hands={},playing_cards={},hand={},deck={},ordering_safe=true,jokers_shuffling=false,
  interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',shop_forecast={inflation=0,discount_percent=0},used_vouchers={},
  completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
   eligibility={eligible=true},by_key={j_crazy={status='missing'},j_golden={status='complete'}}}}
 for _,j in ipairs(s.jokers)do if j.key~='j_crazy'then s.completionist_goal.by_key[j.key]={status='complete'}end end
 for _,name in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'})do
  s.hands[name]={chips=100,mult=10,level=10,played=1}
 end
 for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}}end
 return s
end
local function base(s)
 local index;for i,j in ipairs(s.jokers)do if j.id=='missing'then index=i end end
 return {action={kind='sell',area='jokers',index=index,followup={kind='buy',area='shop_jokers',index=1}}}
end
-- The only policy stub is the ordinary shop-advice family, focused to a
-- complete declared sale/buy incumbent. Product scoring, acquisition,
-- retention, order projection, phase copying, cache and retries remain loaded
-- through the original production runtime, with its original Shop factory.
math.random=function()error('No RNG in manufactured Decision-order fixtures')end;pseudorandom=math.random
local function shallow(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
A.strategy=shallow(A.strategy)
A.strategy.advise=function(s)return base(s)end
A.strategy.shortfall_reroll=nil
A.economy=nil
A.shop_sequences=shallow(A.shop_sequences)
A.shop_sequences.suggest=function()return nil,{complete=true}end
A.shop_sequences.with_continuation=function(value)return value end
local calls,floors,phase_calls=0,0,0
local raw_score,raw_floor,raw_phase=A.scoring.score,A.scoring.lower_bound,A.phase_copy.apply
A.scoring.score=function(...)calls=calls+1;return raw_score(...)end
A.scoring.lower_bound=function(...)floors=floors+1;return raw_floor(...)end
A.phase_copy=shallow(A.phase_copy)
A.phase_copy.apply=function(...)phase_calls=phase_calls+1;return raw_phase(...)end
local function decide(s,options)
 local result,yields; yields=0
 local worker=coroutine.create(function()
  result=A.decision.run(s,A,function()yields=yields+1;coroutine.yield()end,options)
 end)
 repeat local ok,why=coroutine.resume(worker);check(ok,tostring(why))until coroutine.status(worker)=='dead'
 return result,yields
end
do
 local s=state();local signature=A.snapshot.fingerprint(s)
 check(O and O.family and O.apply,'original runtime loads the physical order helper')
 check(A.gold_retention and A.gold_retention.suggest,'original runtime loads retention')
 eq(A.shop_scoring,Q,'production Shop factory has not been replaced')
 local before_calls,before_floors,before_phase=calls,floors,phase_calls
 local result,yields=decide(s)
 check(result.gold_retention_diagnostics and result.gold_retention_diagnostics.complete,'real Decision accepts the complete retention order proof')
 eq(result.action.kind,'reorder_jokers','Decision returns the scoring arrangement before any paid sale')
 eq(result.strategy.action.kind,'reorder_jokers','final executable and strategy action representations agree')
 eq(result.action.followup,nil,'no unexecuted paid actions are queued')
 check(result.strategy.needs_refresh,'the single arrangement requires a fresh decision')
 check(result.strategy.gold_retention,'proof remains attached to its actual strategy')
 eq(phase_calls,before_phase,'qualified retention reorder bypasses phase-copy postprocessing')
 check(not result.phase_copy and not result.phase_copy_incumbent,'no unrelated exit-copy order overwrites the scoring proof')
 eq(result.evaluations,calls-before_calls,'every actual production score pass is charged')
 eq(result.evaluations,floors-before_floors,'every retained comparison uses supported score floors')
 eq(result.score_cache.score_calls,calls-before_calls,'real cache diagnostics retain exact work')
 eq(result.gold_retention_diagnostics.reserved_evaluations,8000,'existing reservation is preserved inside the shared cap')
 check(result.evaluations>0 and result.evaluations<=50000 and yields>0,'complete production work stays bounded and yields')
 local family=assert(O.family(s,A));local selected
 for _,row in ipairs(family.rows)do
  if A.snapshot.fingerprint(row.order)==A.snapshot.fingerprint(result.action.order)then selected=row end
 end
 check(selected,'actual action names a declared legal physical order')
 local fresh=assert(O.apply(s,selected));local fresh_signature=A.snapshot.fingerprint(fresh)
 local raw_leave={kind='strategy',action={kind='leave_shop'},strategy={action={kind='leave_shop'}},evaluations=0}
 local unguarded=raw_phase(fresh,A,raw_leave)
 check(unguarded.action and unguarded.action.kind=='reorder_jokers','real phase copying would otherwise undo this scoring arrangement')
 check(unguarded.phase_copy and unguarded.phase_copy.events_after>unguarded.phase_copy.events_before,'the competing order actually increases Perkeo copying')
 local undo=A.phase_copy.reorder(fresh,unguarded.action.order)
 eq(undo.jokers[1].key,'j_perkeo','the competing shop exit returns Brainstorm to Perkeo')
 for _=1,3 do
  before_phase=phase_calls
  local next_result=decide(fresh)
  check(next_result.gold_retention_diagnostics and next_result.gold_retention_diagnostics.complete,'fresh actual Decision completes its own hold comparison')
  eq(next_result.action.kind,'leave_shop','fresh scoring row exits directly instead of cycling back to Perkeo')
  eq(next_result.strategy.action.kind,'leave_shop','fresh strategy agrees with the final action')
  eq(next_result.gold_retention_diagnostics.arrangement_actions,0,'fresh row needs no remaining arrangement action')
  eq(phase_calls,before_phase,'qualified fresh leave remains protected from the real phase copier')
  check(not next_result.phase_copy_incumbent,'no hidden replacement of the compared leave occurs')
 end
 for _,point in ipairs({s,fresh})do
  local pending=decide(point,{retry={matched=true,pending=true,reloads_used=3}})
  check(pending.gold_retention_diagnostics and pending.gold_retention_diagnostics.complete,'retry keeps the completed diagnostic proof')
  check(pending.action==nil and pending.strategy.action==nil,'pending retry clears both executable action representations')
  check(pending.retry.review_only and pending.retry.status=='pending','pending persistent retry remains authoritative')
  eq(pending.retry.reloads_used,3,'retention order cannot renew or reset the persistent retry count')
  local unavailable=decide(point,{retry={unavailable=true,reason='manufactured unavailable retry metadata'}})
  check(unavailable.action==nil and unavailable.strategy.action==nil,'unavailable retry blocks both arrangement and leave')
  check(unavailable.retry.review_only and unavailable.retry.status=='unavailable','unknown retry metadata is not bypassed')
 end
 eq(A.snapshot.fingerprint(s),signature,'actual production integration does not mutate the original public state')
 eq(A.snapshot.fingerprint(fresh),fresh_signature,'fresh proof and phase-copy inspection preserve all public state')
 local ordinary=cp(fresh);ordinary.completionist_goal=nil
 before_phase=phase_calls
 local unprotected=decide(ordinary)
 eq(phase_calls,before_phase+1,'unqualified ordinary advice still receives normal phase-copy processing')
 eq(unprotected.action.kind,'sell','optout does not grant a collection-retention override')
 eq(A.shop_scoring,Q,'original Shop factory remains in use throughout')
end
print('PASS production Gold retention order '..checks..' checks; '..calls..' score passes; '..floors..' supported floors')
