-- Manufactured post-acquisition retention with actual production dependencies.
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
local function run(s,b,cap,modules)
 local result,work,diagnostics;local yields=0
 local worker=coroutine.create(function()result,work,diagnostics=R.suggest(s,modules or A,b,cap or 8000,function()yields=yields+1;coroutine.yield()end)end)
 repeat local ok,why=coroutine.resume(worker);check(ok,tostring(why))until coroutine.status(worker)=='dead'
 return result,work,diagnostics,yields
end
do
 local s=state();local fingerprint=S.fingerprint(s);local calls=0;local original=A.scoring.lower_bound
 A.scoring.lower_bound=function(...)calls=calls+1;return original(...)end
 local result,work,d,yields=run(s,base())
 A.scoring.lower_bound=original
 check(result and d.complete,'retention protects newly acquired missing Joker from a generic replacement')
 eq(result.action.kind,'leave_shop','keeps cargo instead of selling it for a completed Joker')
 eq(d.before_missing,0,'paid incumbent would have zero missing identities');eq(d.after_missing,1,'hold retains one missing identity')
 eq(work,calls,'all actual floors are charged');check(work>0 and work<=8000,'reserved sub-budget is sufficient for this complete fixture')
 check(d.minimum_opening_score>=1250 and d.comparisons==1,'both paid and hold endpoints share four complete next-blind worlds')
 eq(d.held_certificate.inventory_count_before,14,'full mixed inventory retained')
 eq(S.fingerprint(s),fingerprint,'comparison cannot mutate the observed state')
 check(yields>0,'real scorer uses yield-safe worker boundaries')
 local bought=S.copy(s);bought.jokers[5].edition={negative=true,type='negative'};bought.joker_limit=6
 result,work,d=run(bought,base());check(result and d.complete,'selling a Negative target still retains exact Joker capacity in the compared incumbent')
 local seq=base();seq.action.followup=nil;seq.shop_sequence={complete=true,actions={{kind='sell',area='jokers',index=5},{kind='buy',area='shop_jokers',index=1}}}
 check(run(s,seq),'an exact completed shop_sequence is supported')
 seq.shop_sequence.actions[1].index=4;local none,w=run(s,seq);check(not none and w==0,'mismatched sequence cannot protect an imagined endpoint')
 local two=state();two.shop_jokers[1].edition={negative=true,type='negative'}
 two.shop_jokers[2]=joker('j_joker','second','Joker',{mult=4});two.completionist_goal.by_key.j_joker={status='complete'}
 local plan={action={kind='sell',area='jokers',index=5},shop_sequence={complete=true,actions={
  {kind='sell',area='jokers',index=5},{kind='buy',area='shop_jokers',index=1},{kind='buy',area='shop_jokers',index=1}}}}
 result,work,d=run(two,plan);check(result and d.complete,'two exact buys preserve changing offer indices and Negative Joker capacity')
end
do
 local s=state();s.jokers[4]=joker('j_crazy','duplicate','Crazy Joker',{t_mult=12,type='Straight'})
 local result,work,d=run(s,base());check(not result and work==0 and d.complete,'selling a duplicate preserves distinct cargo and needs no override')
 s=state();s.completionist_goal.by_key.j_golden.status='missing'
 result,work,d=run(s,base());check(not result and work==0 and d.complete,'replacing one distinct missing identity with another does not lower distinct count')
 s=state();s.hands={};for _,name in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'})do s.hands[name]={chips=1,mult=1,level=1,played=0}end
 result,work,d=run(s,base());check(not result and d.complete and work>0,'insufficient hold survival margin leaves ordinary sale available')
 s=state();result,work,d=run(s,base(),1);check(not result and work<=1 and not d.complete,'a bounded incomplete comparison never blocks ordinary action or exceeds allowance')
 local calls=0;local original=A.scoring.lower_bound
 A.scoring.lower_bound=function(...)calls=calls+1;local r=original(...);r.warnings={'unqualified fixture warning'};return r end
 result,work,d=run(s,base());A.scoring.lower_bound=original
 check(not result and not d.complete and work==calls and calls>0,'failed score qualification still charges every actual floor call')
 result,work,d=run(s,base(),0);check(not result and work==0,'no work is invented with zero remaining allowance')
 s=state();s.consumeables[1].tarot_hold_source.supported=false
 result,work=run(s,base());check(not result and work==0,'unsupported whole inventory retains ordinary action')
 s=state();s.jokers[5].ability.eternal=true
 result,work=run(s,base());check(not result and work==0,'illegal paid Eternal sale is not used as a counterfactual')
 s=state();s.dollars=-100
 result,work=run(s,base());check(not result and work==0,'unfunded complete incumbent does not qualify')
 s=state();s.dollars=1;s.shop_jokers[1].cost=0;s.jokers[1].ability.rental=true
 result,work,d=run(s,base());check(not result and d.complete and d.liquidity.shortfall>0,'retention cannot spend away a supported rental reserve')
 s=state();local unsupported=base();unsupported.action.followup={kind='use',area='consumeables',index=1}
 result,work=run(s,unsupported);check(not result and work==0,'Tarot use is outside the retained hold family')
end
do
 local s=state();eq(R.reserve(s,50000),8000,'retention reserve stays inside existing full shop budget')
 eq(R.reserve(s,117),117,'low caller allowance is respected');eq(R.reserve(s,0),0,'zero caller allowance')
 s.completionist_goal.by_key.j_crazy.status='complete';eq(R.reserve(s,50000),0,'ordinary all-completed row loses no budget')
 s=state();s.completionist_goal=nil;eq(R.reserve(s,50000),0,'goal optout leaves ordinary budget unchanged')
 s=state();s.next_blind.key='bl_final_acorn';s.next_blind.boss=true;eq(R.reserve(s,50000),0,'unsupported boss leaves budget unchanged')
 s=state();s.ante=7;eq(R.reserve(s,50000),0,'earlier Ante leaves ordinary budget unchanged')
 for _,key in ipairs({'bl_final_vessel','bl_final_leaf'})do s=state();s.next_blind.key=key;s.next_blind.boss=true;eq(R.reserve(s,50000),8000,'supported final boss reserves retention capacity')end
end
print('PASS bounded Gold retention '..checks..' checks')
