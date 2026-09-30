-- Manufactured production Decision integration for the fixed-row retention policy.
-- Ordinary advice is focused to an exact declared paid incumbent. Transitions,
-- whole-inventory qualification, four-world scores, phase copying and retries
-- retain their actual initialized production implementations.
package.preload.nativefs=function()return {read=function(p)local f=assert(io.open(p,'rb'));local x=f:read('*a');f:close();return x end}end
Brainstorm={PATH='Brainstorm',config={}}
local f=assert(io.open('Brainstorm/Advisor/runtime.lua','rb'));local source=f:read('*a');f:close()
local boundary=assert(source:find('\nfunction A.defaults()',1,true))
local A=assert(loadstring(source:sub(1,boundary-1)..'\nreturn A','@manufactured_retention_modules'))()
local R=dofile('Brainstorm/Advisor/gold_retention.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local S=A.snapshot
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function joker(key,id,name,ability)
 ability=ability or {};ability.name=name;ability.set='Joker'
 return {key=key,id=id,name=name,ability=ability,cost=5,base_cost=5,sell_cost=2,debuff=false,face_down=false,pinned=false,blueprint_compat=true}
end
local function state()
 local s={phase='shop',ante=8,win_ante=8,dollars=170,bankrupt_at=0,joker_limit=5,consumable_limit=16,
  consumeable_buffer=0,consumeables=F.state().consumeables,consumeable_usage_total={tarot=8},
  jokers={joker('j_yorick','y','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
   joker('j_perkeo','p','Perkeo',{eternal=true}),joker('j_brainstorm','b','Brainstorm',{eternal=true}),
   joker('j_scary_face','s','Scary Face',{extra=30}),joker('j_crazy','missing','Crazy Joker',{t_mult=12,type='Straight'})},
  shop_jokers={joker('j_golden','gold','Golden Joker',{extra=4})},shop_booster={},shop_vouchers={},
  next_blind={key='bl_big',name='Big Blind',boss=false,chips=1000,ante=8},blind={key='bl_small',disabled=true,chips=500},
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
local function base()return {action={kind='sell',area='jokers',index=5,followup={kind='buy',area='shop_jokers',index=1}}}end
math.random=function()error('No RNG in manufactured retention fixtures')end;pseudorandom=math.random

local function shallow(t) local out={};for k,v in pairs(t)do out[k]=v end;return out end
local original_strategy=A.strategy
A.strategy=shallow(original_strategy)
A.strategy.advise=function()return base()end
A.strategy.shortfall_reroll=nil
A.economy=nil
A.shop_sequences=shallow(A.shop_sequences)
A.shop_sequences.suggest=function()return nil,{complete=true}end
A.shop_sequences.with_continuation=function(value)return value end
local calls,floors=0,0
local raw_score,raw_floor=A.scoring.score,A.scoring.lower_bound
A.scoring.score=function(...)calls=calls+1;return raw_score(...)end
A.scoring.lower_bound=function(...)floors=floors+1;return raw_floor(...)end
local function decide(s,options)
 local result,yields=nil,0
 local worker=coroutine.create(function()
  result=A.decision.run(s,A,function()yields=yields+1;coroutine.yield()end,options)
 end)
 repeat local ok,why=coroutine.resume(worker);check(ok,tostring(why))until coroutine.status(worker)=='dead'
 return result,yields
end
do
 local s=state();local fingerprint=S.fingerprint(s)
 check(A.gold_retention==R or A.gold_retention and A.gold_retention.suggest,'production runtime loads retention')
 local raw_leave={kind='strategy',action={kind='leave_shop'},strategy={action={kind='leave_shop'}},evaluations=0}
 local unguarded=A.phase_copy.apply(s,A,raw_leave)
 check(unguarded.action and unguarded.action.kind=='reorder_jokers','real phase copying would replace an unqualified leave with a Perkeo reorder')
 check(unguarded.phase_copy and unguarded.phase_copy.events_after>unguarded.phase_copy.events_before,'the otherwise suggested reorder really adds Perkeo copy events')
 eq(unguarded.phase_copy_incumbent.action.kind,'leave_shop','the ordinary copy suggestion supersedes leaving')
 local reordered=A.phase_copy.reorder(s,unguarded.action.order)
 check(S.fingerprint(reordered.jokers)~=S.fingerprint(s.jokers),'the unguarded proposal actually changes the assumed fixed physical row')
 local before_calls,before_floors=calls,floors
 local result,yields=decide(s)
 check(result.gold_retention_diagnostics and result.gold_retention_diagnostics.complete,'real Decision performs the full retention comparison')
 check(result.strategy.gold_retention,'a qualified hold receipt is retained on the actual strategy')
 eq(result.action.kind,'leave_shop','the qualified fixed-row hold is delivered without an unproved extra Perkeo reorder')
 eq(result.strategy.action.kind,'leave_shop','strategy and final action agree on the proved hold policy')
 check(not result.phase_copy,'no unrelated copying proof is attached to the fixed-row hold')
 check(not result.phase_copy_incumbent,'the retention result was not silently postprocessed into a different action')
 eq(result.evaluations,calls-before_calls,'the production result charges every actual score pass')
 eq(result.evaluations,floors-before_floors,'all retention scoring is warning-free supported-floor work')
 eq(result.score_cache.score_calls,calls-before_calls,'the real cache receipt retains all work')
 check(result.evaluations>0 and result.evaluations<=50000,'positive complete comparison stays inside the existing shop allowance')
 eq(result.gold_retention_diagnostics.before_missing,0,'the exact paid incumbent would lose the last missing identity')
 eq(result.gold_retention_diagnostics.after_missing,1,'the delivered hold retains it')
 eq(result.gold_retention_diagnostics.held_certificate.copy_events,1,'the receipt credits only the current row copy event')
 eq(S.fingerprint(result.gold_retention_diagnostics.held_certificate.current_order),S.fingerprint(s.jokers),'the proof names the unchanged actual row')
 check(yields>0,'the production scoring worker cooperatively yields')
 eq(S.fingerprint(s),fingerprint,'Decision and unguarded inspection leave manufactured input unchanged')
 local pending=decide(s,{retry={matched=true,pending=true,reloads_used=3}})
 check(pending.gold_retention_diagnostics and pending.gold_retention_diagnostics.complete,'pending retry still retains the diagnostic proof')
 check(pending.action==nil and pending.strategy.action==nil,'pending retry blocks both executable action representations')
 check(pending.retry and pending.retry.review_only and pending.retry.status=='pending','existing persistent retry guard remains authoritative')
 eq(pending.retry.reloads_used,3,'retention cannot reset the persistent retry count')
 local unavailable=decide(s,{retry={unavailable=true,reason='manufactured unavailable metadata'}})
 check(unavailable.action==nil and unavailable.strategy.action==nil,'unavailable retry metadata likewise grants no action')
 eq(unavailable.retry.status,'unavailable','retry uncertainty is preserved')
end
print('advisor_gold_retention_runtime: '..checks..' actual production Decision checks; '..calls..' score passes; '..floors..' supported floors')
