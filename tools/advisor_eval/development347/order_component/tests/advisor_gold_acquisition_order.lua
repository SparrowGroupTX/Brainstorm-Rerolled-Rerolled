-- Manufactured public shop only. Production dependencies, no captured replay,
-- source/game execution, saves, search, hidden draws, or terminal attempt.
package.preload.nativefs=function()
 return {read=function(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end}
end
Brainstorm={PATH='Brainstorm',config={}}
local f=assert(io.open('Brainstorm/Advisor/runtime.lua','rb'));local source=f:read('*a');f:close()
local boundary=assert(source:find('\nfunction A.defaults()',1,true))
local A=assert(loadstring(source:sub(1,boundary-1)..'\nreturn A','@manufactured_gold_acquisition_order_dependencies'))()
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local copy=A.snapshot.copy
local function fingerprint(s)return A.snapshot.fingerprint(s)end
local function joker(key,id,name,a)
 local j=F.joker(key,name,id);j.ability=a or {};j.ability.name=name;j.ability.set='Joker';return j
end
local function state()
 local s=F.state()
 s.jokers={joker('j_perkeo','p','Perkeo',{eternal=true}),
  joker('j_yorick','y','Yorick',{x_mult=2,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
  joker('j_caino','c','Caino',{caino_xmult=10,extra=1,eternal=true}),
  joker('j_scary_face','a','Scary Face',{extra=30}),joker('j_brainstorm','b','Brainstorm',{eternal=true})}
 s.ante=8;s.win_ante=8;s.dollars=80;s.bankrupt_at=0;s.joker_limit=5;s.consumable_limit=16
 s.shop_jokers={joker('j_crazy','offer','Crazy Joker',{t_mult=12,type='Straight'})}
 s.shop_booster={};s.shop_vouchers={};s.consumeable_usage_total={tarot=8}
 s.next_blind={key='bl_small',name='Small Blind',boss=false,chips=90000,ante=8}
 s.blind={key='bl_big',name='Big Blind',boss=false,disabled=true,chips=50000}
 s.hand_size=4;s.hand_limit=5;s.hands_left=4;s.discards_left=3;s.round_resets={hands=4,discards=3}
 s.current_round={};s.modifiers={};s.probabilities={normal=1};s.hands={};s.hand={};s.deck={}
 s.interest_cap=25;s.interest_amount=1;s.rental_rate=3;s.deck_key='b_red';s.shop_forecast={inflation=0,discount_percent=0}
 s.completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',
  held_status='complete',eligibility={eligible=true},by_key={j_crazy={status='missing'}}}
 for _,j in ipairs(s.jokers)do s.completionist_goal.by_key[j.key]={status='complete'}end
 for _,name in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
  'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'})do
  s.hands[name]={chips=100,mult=10,level=10,played=1}
 end
 for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,
  suit=({'Hearts','Clubs','Spades','Diamonds'})[1+i%4],ability={}}end
 return s
end
local function forbidden()error('Manufactured acquisition cannot use RNG or a mean-score path')end
math.random=forbidden;pseudorandom=forbidden;pseudoseed=forbidden
local lower,score=A.scoring.lower_bound,A.scoring.score
local calls,score_calls,scored_rows=0,0,{}
A.scoring.score=function(...)score_calls=score_calls+1;return score(...)end
A.scoring.lower_bound=function(s,selected)
 calls=calls+1
 local ids={};for _,j in ipairs(s.jokers)do ids[#ids+1]=j.id end
 scored_rows[table.concat(ids,':')]=true
 local result=lower(s,selected)
 check(result and (result.legal==false or result.reliable_bound and result.bound_kind=='supported_random_floor'),
  'every charged selection has an actual supported score floor')
 check(not result.uncertain and (not result.warnings or next(result.warnings)==nil),'all score-floor warnings remain explicit')
 return result
end
local function advise(s,options)
 local before,before_scores=calls,score_calls;local result
 local worker=coroutine.create(function()
  result={A.gold_acquisition.suggest(s,A,function()coroutine.yield()end,options)}
 end)
 repeat local ok,why=coroutine.resume(worker);check(ok,'real production worker resumes: '..tostring(why))until coroutine.status(worker)=='dead'
 eq(result[2],calls-before,'every underlying score-floor call is charged once')
 eq(result[2],score_calls-before_scores,'each floor uses exactly one actual score evaluation')
 check(result[2]<=math.min(50000,options and options.max_evaluations or 50000),'the normal shared shop score allowance stays bounded')
 return unpack(result)
end
local function evidence(d)
 check(d.complete and d.projection_complete,'the whole order/purchase family completes: '..tostring(d.reason))
 check(d.order_preflight.complete and d.order_preflight.fits,'whole-family cost fits before scoring')
 eq(d.order_preflight.required_evaluations,d.evaluations,'all preflight score work is exact')
 local world
 for _,endpoint in ipairs(d.endpoints)do
  local e=endpoint.evidence
  eq(e.samples,4,'all endpoints include all four public composition worlds')
  world=world or e.common_worlds.family_key
  eq(e.common_worlds.family_key,world,'every endpoint uses the same public composition worlds')
  for _,r in ipairs({e.before_readiness,e.after_readiness})do
   eq(r.ordering.action_count,0,'score evidence assumes only the physically projected fixed row')
   eq(r.ordering.layouts,1,'no hypothetical future row optimization enters the score')
   eq(#r.opening_scores,4,'all four exact opening scores are recorded')
   for i,index in ipairs(r.ordering.order)do eq(index,i,'each endpoint uses its actual fixed row')end
  end
  check(endpoint.hold_certificate.original_inventory_unchanged,'all original Tarot cards are protected')
  eq(endpoint.hold_certificate.first_hand_consumable_actions,0,'the score does not spend held Tarot cards')
 end
end
do
 local s=state();local original=fingerprint(s);local order=A.gold_order
 check(order and order.family and order.apply,'production runtime wires the actual order helper')
 A.gold_order=nil
 local old,oldwork,old_diag=advise(s)
 A.gold_order=order
 check(not old and old_diag.complete and oldwork>0,'the identical fixed-row-only control completes but fails the required margin: '..tostring(old_diag.reason)..'; work='..tostring(oldwork)..'; action='..tostring(old and old.action.kind))
 eq(#old_diag.endpoints,2,'fixed-row control covers hold and legal Scary Face sale/buy')
 for _,endpoint in ipairs(old_diag.endpoints)do
  check(endpoint.minimum_opening_score<112500,'copying Perkeo instead of Caino misses the declared next-blind margin')
 end
 local a,work,d=advise(s);evidence(d)
 check(a and a.action.kind=='reorder_jokers','the real first action explicitly changes copy target before any paid action')
 check(a.action.followup==nil and a.action.continuation==nil,'reorder does not queue a sale or buy using stale indices')
 check(a.needs_refresh,'an actual reorder must be followed by fresh advice')
 eq(d.after_missing,1,'the complete proposed paid endpoint adds only one distinct missing Joker')
 eq(d.selected.setup_actions,1,'the selected endpoint charges the actual reorder')
 eq(d.selected.actions[2].kind,'sell','the proposed endpoint requires an actual sale')
 eq(d.selected.actions[3].kind,'buy','the proposed endpoint requires an actual purchase')
 for _,value in ipairs(d.selected.evidence.after_readiness.opening_scores)do
  check(value>=112500,'each complete world retains the requested 25 percent margin')
 end
 local chosen
 for _,row in ipairs(d.order_family.rows)do
  if fingerprint(row.order)==fingerprint(a.action.order)then chosen=row end
 end
 check(chosen~=nil,'the published action is a member of the fully compared legal family')
 local arranged=assert(order.apply(s,chosen))
 eq(arranged.jokers[1].id,'c','Brainstorm now targets the actual physical Caino')
 eq(arranged.dollars,80,'the reorder spends no cash')
 eq(fingerprint(arranged.consumeables),fingerprint(s.consumeables),'all fourteen native-shape Negative Tarots remain unchanged')
 eq(fingerprint(arranged.playing_cards),fingerprint(s.playing_cards),'the complete public population is conserved')
 local sale,_,after_order=advise(arranged);evidence(after_order)
 check(sale and sale.action.kind=='sell','fresh advice sells immediately instead of oscillating back to Perkeo')
 eq(arranged.jokers[sale.action.index].id,'a','the fresh index refers to the actual Scary Face after rearrangement')
 check(sale.action.index~=4,'the fixture exercises a changed sale index')
 eq(sale.action.followup.kind,'buy','the freshly planned sale names the visible followup')
 local sold=assert(A.shop_sequences.transition(arranged,sale.action,A))
 eq(sold.dollars,82,'the actual sale proceeds are credited once')
 local buy,_,after_sale=advise(sold);evidence(after_sale)
 check(buy and buy.action.kind=='buy','fresh sale state buys immediately without a reorder cycle')
 eq(sold.shop_jokers[buy.action.index].id,'offer','the physical visible missing offer is purchased')
 local bought=assert(A.shop_sequences.transition(sold,buy.action,A))
 eq(bought.dollars,78,'reorder, sale and purchase produce exact net cash')
 eq(#bought.jokers,5,'the actual acquisition fills the original five-slot row')
 eq(bought.jokers[5].key,'j_crazy','the actual purchased missing Joker remains in the row')
 eq(fingerprint(bought.consumeables),fingerprint(s.consumeables),'the entire owned inventory is still unchanged after paid transitions')
 eq(fingerprint(bought.playing_cards),fingerprint(s.playing_cards),'all playing cards remain conserved after paid transitions')
 local done,donework,done_diag=advise(bought)
 check(not done and done_diag.complete and donework==0,'no redundant acquisition starts after the target is held')
 eq(fingerprint(s),original,'all comparisons and transition projections leave the original snapshot unchanged')
 -- Preflight chooses a complete smaller family before seeing any score. This
 -- is an explicit fixed-row fallback, not a scored prefix of the larger one.
 calls=0;scored_rows={}
 local fallback,fallbackwork,fd=advise(s,{max_evaluations=oldwork})
 check(not fallback and fd.complete,'a bounded complete fallback cannot falsely rescue the fixed-row control')
 eq(fd.order_fallback,'current_row_before_scoring','expanded family is discarded before score evaluation')
 check(fd.order_preflight_expanded.required_evaluations>oldwork,'expanded family exceeds the deliberately smaller allowance')
 eq(fallbackwork,oldwork,'fallback exactly matches the full fixed-row control cost')
 for signature in pairs(scored_rows)do check(signature:sub(1,2)=='p:','no expanded reorder receives a score during fallback')end
 calls=0
 local short,shortwork,sd=advise(s,{max_evaluations=oldwork-1})
 check(not short and not sd.complete and shortwork==0 and calls==0,'insufficient complete fixed-row cost declines before any score is spent')
 print('gold_order acquisition evidence: fixed='..oldwork..' expanded='..work..
  ' selected_minimum='..d.selected.minimum_opening_score..' target='..s.next_blind.chips..
  ' fresh_sale_index='..sale.action.index..' net_cash='..bought.dollars..
  ' fallback='..fallbackwork..' insufficient='..shortwork)
end
print('advisor_gold_acquisition_order: '..checks..' checks passed')
