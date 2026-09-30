-- Independently manufactured: tiny suited population, three-slot row, no seed/log input.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local function j(k,a,c) a=a or {};a.set='Joker';return {id=k,key=k,ability=a,blueprint_compat=true,cost=c or 0,sell_cost=2}end
local function state()
local s={phase='shop',ante=3,win_ante=8,dollars=80,bankrupt_at=0,joker_limit=3,consumable_limit=8,
 jokers={j('j_yorick',{name='Yorick',x_mult=6,extra={discards=23,xmult=1},yorick_discards=10,eternal=true}),
 j('j_perkeo',{name='Perkeo',eternal=true}),j('j_joker',{name='Joker',mult=4,perishable=true,perish_tally=0})},
 consumeables={},hand={},deck={},playing_cards={},hands={Flush={level=2,played=5,chips=50,mult=6}},
 shop_jokers={j('j_blueprint',{name='Blueprint'},35)},shop_vouchers={{key='v_grabber',cost=0,ability={set='Voucher'}}},shop_booster={},
 hand_size=8,hand_limit=5,round_resets={hands=3,discards=3},current_round={},modifiers={},probabilities={normal=1},
 blind={key='bl_small',name='Small Blind'},next_blind={key='bl_small',name='Small Blind',chips=18000},interest_cap=25,reroll_cost=5}
s.jokers[3].debuff=true
for i=1,12 do s.playing_cards[i]={id='manufactured:'..i,rank=i+1,nominal=math.min(10,i+1),suit='Hearts',ability={}}end
for i=1,6 do s.consumeables[i]={id='planet:'..i,key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}end

return s
end
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Sequence=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
local checks=0
local function check(v,msg)checks=checks+1;assert(v,msg)end
local function run(s,limit,decorate)
 local ctx=Shop.new(s,Score,nil,{max_evaluations=limit or 50000})
 if decorate then decorate(ctx)end
 local r=S.advise(s,{shop_scoring=ctx});return r,ctx
end
local original=state();local fingerprint=Snapshot.fingerprint(original)
local r,ctx=run(original)
check(r.action.kind=='sell' and r.action.index==3,'complete copy endpoint beats generic voucher winner')
check(r.action.followup.area=='shop_jokers' and r.action.followup.index==1,'one refreshed sale-first plan')
check(ctx.evaluations==4360 and not ctx.truncated,'same4360 calls as independently preserved baseline')
check(r.scoring_evidence and r.scoring_evidence.ratio==6,'real scorer supports sixfold manufactured opening improvement')
check(ctx.replacement_diagnostics.complete,'complete ordinary replacement family retained above broad inventory bound')
check(#ctx.replacement_diagnostics.candidates==3,'protected victims are recorded too')
check(Snapshot.fingerprint(original)==fingerprint,'full input and physical counters unchanged')
local again,ac=run(original)
check(Snapshot.fingerprint(r)==Snapshot.fingerprint(again) and ac.evaluations==ctx.evaluations,'deterministic choice and work')
local broad,why=Sequence.suggest(original,{strategy=S},r,ctx)
check(not broad and not why.complete and why.reason:find('admission bounds'),'broader graph retains four-consumable limit')
local sold=Sequence.transition(original,r.action,{strategy=S})
check(sold and sold.dollars==82 and #sold.jokers==2,'sale applies actual cash and row transition')
check(Snapshot.fingerprint(sold.consumeables)==Snapshot.fingerprint(original.consumeables),'held whole inventory unchanged')
local next_advice=run(sold)
check(next_advice.action.kind=='buy','sale does not enqueue a stale follow-up; fresh advice selects a legal purchase')
if next_advice.action.area=='shop_vouchers' then
 check(sold.shop_vouchers[next_advice.action.index].cost==0,'intervening manufactured voucher cannot consume reserved cash')
 sold.shop_vouchers={};sold.round_resets.hands=sold.round_resets.hands+1
 next_advice=run(sold)
end
check(next_advice.action.kind=='buy' and next_advice.action.area=='shop_jokers','fresh funded copy purchase after free voucher')
do
 local s=state();s.jokers[3].ability.eternal=true
 local a=run(s);check(a.action.kind~='sell','no Eternal sale')
 s=state();s.jokers[3].pinned=true
 a=run(s);check(a.action.kind~='sell','no pinned sale')
 s=state();s.jokers[3].edition={negative=true};s.joker_limit=3
 a=run(s);check(a.action.kind~='sell','Negative sale cannot manufacture ordinary slot')
 s=state();s.dollars=0;s.jokers[3].sell_cost=1
 a=run(s);check(a.action.kind~='sell','no unfunded purchase promise')
 s=state();s.jokers[3].key='j_credit_card';s.jokers[3].ability={set='Joker',name='Credit Card',extra=20};s.jokers[3].debuff=false
 s.bankrupt_at=-20;s.dollars=0;s.shop_jokers[1].cost=10
 a=run(s);check(a.action.kind~='sell','removed Credit Card allowance does not fund purchase')
end
do
 local s=state();s.shop_jokers[2]=Snapshot.copy(s.shop_jokers[1]);s.shop_jokers[2].id='other-copy';s.shop_jokers[2].key='j_brainstorm';s.shop_jokers[2].ability.name='Brainstorm';s.shop_jokers[2].cost=36
 local a,c=run(s);check(a.action.kind=='sell','all visible Joker endpoints considered')
 check(#c.replacement_diagnostics.candidates==6 and c.replacement_diagnostics.complete,'two offers by three victims receipts')
 local key=s.shop_jokers[a.action.followup.index].key
 s.shop_jokers[1],s.shop_jokers[2]=s.shop_jokers[2],s.shop_jokers[1]
 local b=run(s);check(b.action.kind=='sell' and s.shop_jokers[b.action.followup.index].key==key,'offer reordering preserves unequal-merit winner')
 local a,c=run(s,50000,function(context)
  local compare=context.compare
  context.compare=function(self,before,after)
   if after.jokers[#after.jokers].key=='j_brainstorm'then return nil end
   return compare(self,before,after)
  end
 end)
 check(not c.replacement_diagnostics.complete and a.action.kind~='sell','partial family cannot select evaluated prefix')
end
for _,limit in ipairs({0,1,50,500,4000})do
 local s=state();local a,c=run(s,limit)
 check(c.evaluations<=limit,'score allowance never exceeded')
 check(not c.replacement_diagnostics.complete and a.action.kind~='sell','unfinished replacement family rejected')
end
do
 local s=state();s.shop_jokers[1].key='j_unknown_effect';s.shop_jokers[1].ability={set='Joker'}
 local a,c=run(s);check(a.action.kind~='sell','unknown incoming effect not a replacement')
 s=state();s.shop_jokers[1].cost=200
 a,c=run(s);check(a.action.kind~='sell','expensive overkill is not forced')
 s=state();s.used_vouchers={v_observatory=true};s.consumeables[1].edition={negative=true}
 local f=Snapshot.fingerprint(s);a,c=run(s)
 check(Snapshot.fingerprint(s)==f,'Observatory and Negative inventory preserved at source')
end
do
 local modules={strategy=S,scoring=Score,shop_scoring=Shop,shop_sequences=Sequence}
 local a=Decision.run(state(),modules)
 local receipt=Journal.compact_replacement_review(a)
 check(receipt and receipt.complete and #receipt.candidates==3,'production Decision receipt reaches journal projection')
 check(receipt.final_action_kind==a.action.kind and receipt.final_action_index==a.action.index,'receipt identifies final arbitration action')
 a.shop_diagnostics.replacements.secret={hidden='must not serialize'}
 a.shop_diagnostics.replacements.candidates[1].worlds={hidden='must not serialize'}
 a.shop_diagnostics.replacements.candidates[1].ratio=0/0
 local clean=Journal.compact_replacement_review(a)
 check(clean.secret==nil and clean.candidates[1].worlds==nil and clean.candidates[1].ratio==nil,'no worlds, arbitrary payload or NaN serialized')
 check(Journal.compact_replacement_review({})==nil,'missing diagnostics remain absent')
end
print('replacement family365: '..checks..' checks passed')
