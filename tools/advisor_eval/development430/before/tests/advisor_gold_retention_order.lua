-- Manufactured public states only; pure product dependencies, no player replay.
package.preload.nativefs=function()return {read=function(p)local f=assert(io.open(p,'rb'));local x=f:read('*a');f:close();return x end}end
Brainstorm={PATH='Brainstorm',config={}}
local f=assert(io.open('Brainstorm/Advisor/runtime.lua','rb'));local source=f:read('*a');f:close()
local boundary=assert(source:find('\nfunction A.defaults()',1,true))
local A=assert(loadstring(source:sub(1,boundary-1)..'\nreturn A','@manufactured_retention_order_modules'))()
local R=dofile('Brainstorm/Advisor/gold_retention.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local O=dofile('Brainstorm/Advisor/gold_order.lua')
local Q=dofile('Brainstorm/Advisor/shop_scoring.lua')
A.gold_order=O;A.shop_scoring=Q
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
math.random=function()error('No RNG in manufactured retention-order fixtures')end;pseudorandom=math.random
local function run(s,b,cap,modules)
 local result,work,diagnostics;local yields=0
 local worker=coroutine.create(function()result,work,diagnostics=R.suggest(s,modules or A,b or base(s),cap or 8000,function()yields=yields+1;coroutine.yield()end)end)
 repeat local ok,why=coroutine.resume(worker);check(ok,tostring(why))until coroutine.status(worker)=='dead'
 return result,work,diagnostics,yields
end
local function altered(field,value)
 local m={};for k,v in pairs(A)do m[k]=v end;m[field]=value;return m
end
do
 local s=state();local fingerprint=A.snapshot.fingerprint(s);local calls=0;local original=A.scoring.lower_bound
 A.scoring.lower_bound=function(...)calls=calls+1;return original(...)end
 local r,w,d,yields=run(s)
 A.scoring.lower_bound=original
 check(r and d.complete,'complete order family rescues an otherwise under-margin retained row')
 eq(r.action.kind,'reorder_jokers','paid sale is replaced only by an actual first physical reorder')
 eq(r.action.area,'jokers','actual Joker row action');eq(r.action.followup,nil,'no unexecuted paid continuation is queued')
 check(r.needs_refresh,'advice refresh required after the single action')
 eq(w,calls,'all actual score floors are charged');check(w>0 and w<=8000 and yields>0,'complete scoring respects the unchanged reserve')
 check(d.preflight.complete and d.preflight.supported and d.preflight.fits,'family costs proven before scoring')
 eq(d.comparisons,d.rows,'every declared held row receives a full comparison')
 check(d.rows>1 and d.rows<=6,'bounded family includes current and canonical rows')
 check(not d.holds[1].eligible and d.holds[1].action_count==0,'current row cannot meet the requested margin')
 check(d.minimum_opening_score>=18750,'selected scoring row clears the full 125 percent target')
 eq(d.before_missing,0,'incumbent sells the unique target');eq(d.after_missing,1,'retained cargo unchanged')
 eq(d.arrangement_actions,1,'one actual arrange action is charged')
 eq(d.held_certificate.inventory_count_before,14,'whole original inventory is certified for the selected row')
 eq(A.snapshot.fingerprint(s),fingerprint,'root state is unchanged')
 local family=assert(O.family(s,A));local chosen
 for _,row in ipairs(family.rows)do if row.key==r.gold_retention.order_key then chosen=row end end
 check(chosen,'selected physical order was declared before scoring')
 local fresh=assert(O.apply(s,chosen));local again,_,ad=run(fresh)
 check(again and ad.complete,'fresh settled order receives complete advice')
 eq(again.action.kind,'leave_shop','current eligible row wins over another reorder after refresh')
 eq(ad.arrangement_actions,0,'settled row has no remaining arrangement cost')
 for _=1,2 do local repeat_result=run(fresh);eq(repeat_result.action.kind,'leave_shop','repeated fresh advice cannot cycle back to an exit-copy order')end
 local viable=state();viable.next_blind.chips=1000
 local v,_,vd=run(viable);check(v and vd.complete,'current viable row is still protected')
 eq(v.action.kind,'leave_shop','surplus score from another order cannot outweigh the current zero-action exit')
end
do
 local s=state();local calls=0;local original=A.scoring.lower_bound
 A.scoring.lower_bound=function(...)calls=calls+1;return original(...)end
 local small,w,d=run(s,nil,120)
 A.scoring.lower_bound=original
 check(not small and d.complete,'budget-only fallback evaluates the complete current-row family')
 check(d.order_budget_fallback and d.fallback_preflight.fits,'expanded cost falls back before scoring')
 eq(d.rows,1,'fallback declares only the current row');eq(w,calls,'fallback exact floor accounting')
 eq(d.comparisons,1,'fallback never scores a selected expanded prefix')
 local none,nw,nd=run(s,nil,1)
 check(not none and not nd.complete and nw==0,'even the smaller family is declined before any score when it cannot fit')
end
do
 local function order_wrapper(transform)
  return {apply=O.apply,family=function(s,m)local f,w=O.family(s,m);if f then transform(f)end;return f,w end}
 end
 local s=state();local r,w,d=run(s,nil,8000,altered('gold_order',order_wrapper(function(f)f.complete=false end)))
 check(not r and w==0 and not d.complete,'partial family cannot silently choose a supported prefix')
 r,w=run(s,nil,8000,altered('gold_order',order_wrapper(function(f)f.rows[#f.rows+1]=cp(f.rows[1])end)))
 check(not r and w==0,'duplicate declared rows reject before scoring')
 local bad={family=O.family,apply=function(s,row)local p,why=O.apply(s,row);if p and row.action_count==1 then p.dollars=p.dollars+1 end;return p,why end}
 r,w=run(s,nil,8000,altered('gold_order',bad));check(not r and w==0,'order projection cannot invent cash')
 bad={family=O.family,apply=function(s,row)local p,why=O.apply(s,row);if p and row.action_count==1 then p.consumeables[1].cost=99 end;return p,why end}
 r,w=run(s,nil,8000,altered('gold_order',bad));check(not r and w==0,'order projection cannot change original consumables')
 bad={family=O.family,apply=function(s,row)local p,why=O.apply(s,row);if p and row.action_count==1 then p.jokers[1].ability.extra=99 end;return p,why end}
 r,w=run(s,nil,8000,altered('gold_order',bad));check(not r and w==0,'order projection cannot alter a physical Joker')
 local missing=state();missing.consumeables[1].tarot_hold_source.supported=false
 r,w=run(missing);check(not r and w==0,'whole-inventory qualification remains mandatory')
 local unsafe={new=function(...)
  local c=Q.new(...);c.preflight_family=function()return {complete=false,supported=false,fits=false,required_evaluations=0}end;return c
 end}
 r,w,d=run(s,nil,8000,altered('shop_scoring',unsafe));check(not r and w==0 and not d.order_budget_fallback,'mechanical preflight failure cannot masquerade as budget-only fallback')
 local changing={new=function(...)
  local c=Q.new(...);local compare=c.compare;local n=0
  c.compare=function(self,...)
   local e=compare(self,...);n=n+1;if e and n==2 then e.common_worlds.family_key='different-family' end;return e
  end;return c
 end}
 r,w,d=run(s,nil,8000,altered('shop_scoring',changing));check(not r and w>0 and not d.complete,'all pairs must share the identical world family')
 local late={new=function(...)
  local c=Q.new(...);local compare=c.compare;local n=0
  c.compare=function(self,...)
   n=n+1;local e=compare(self,...);if n==3 then return nil end;return e
  end;return c
 end}
 r,w,d=run(s,nil,8000,altered('shop_scoring',late));check(not r and w>0 and not d.complete,'an eligible earlier row cannot survive a later unsupported comparison')
 local pin=state();pin.jokers[1].pinned=true
 r,w,d=run(pin);check(not r and d.complete,'physical pinned Perkeo prevents pretending Brainstorm can copy a different first Joker')
end
print('PASS bounded Gold retention order '..checks..' checks')
