-- Complete manufactured sale-funded plan, fresh production valuation and arbitration.
local p='Brainstorm/Advisor/'
local M=dofile(p..'shop_sequences.lua');local S=dofile(p..'strategy.lua');local Snap=dofile(p..'snapshot.lua')
local Shop=dofile(p..'shop_scoring.lua');local Score=dofile(p..'scoring.lua');local D=dofile(p..'decision.lua')
local J=dofile(p..'player_journal.lua');local Finish=dofile(p..'blind_finishing.lua')
for _,n in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do Finish[n]=dofile(p..n..'.lua') end
Finish.strategy=S;Shop.blind_finishing=Finish;Shop.strategy=S
local modules={strategy=S,shop_sequences=M,shop_scoring=Shop,scoring=Score}
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function j(id,key,name,mult,cost)return {id=id,key=key,name=name,ability={name=name,set='Joker',mult=mult},cost=cost,base_cost=cost,sell_cost=5}end
local s={phase='shop',ante=2,round=4,dollars=0,bankrupt_at=0,joker_limit=5,consumable_limit=2,
 jokers={j('old','j_popcorn','Popcorn',0,10)},consumeables={},shop_jokers={j('one','j_joker','Joker',4,2),j('two','j_joker','Joker',4,2)},
 shop_vouchers={{id='voucher',key='v_telescope',cost=5,ability={set='Voucher'}}},shop_booster={},
 playing_cards={},hand={},deck={},hands={},hand_size=8,hand_limit=5,round_resets={hands=4,discards=3},current_round={},
 modifiers={},probabilities={normal=1},shop_forecast={discount_percent=0,inflation=0},
 next_blind={key='bl_small',name='Small Blind',chips=80},next_blind_chips=80}
for i=1,8 do s.playing_cards[i]={id='p'..i,rank=i+1,nominal=i+1,suit='Clubs',ability={}} end
local actions={{kind='sell',area='jokers',index=1},{kind='buy',area='shop_jokers',index=1},{kind='buy',area='shop_jokers',index=1}}
local proposal={action=actions[1],shop_sequence={complete=true,actions=actions,titles={'Sell expired Popcorn','Buy Joker one','Buy Joker two'}}}
local original=Snap.fingerprint(s)
check(not M.prepare_commitment(s,proposal,modules),'Opening-only promise cannot bind a sale')
local incomplete={compare=function()return {after_readiness={supported=true},ratio=4}end}
check(not M.qualify_sale(s,proposal,modules,incomplete),'No sale prequalification from incomplete finishing, even with supported opening')
check(M.qualify_sale(s,proposal,modules,Shop.new(s,Score)),'Every post-sale endpoint prequalified using the same fresh contract')
local lease=assert(M.prepare_commitment(s,proposal,modules))
check(M.observe_commitment(s,lease,modules)==nil,'Queued sale without physical changes must preserve original snapshot fingerprint')
check(lease.steps[1].id=='one' and lease.steps[2].id=='two' and lease.cash_after==1,'Every remaining physical offer, shifted index and endpoint cash bound')
local sold=assert(M.transition(s,actions[1],modules));sold.shop_sequence_commitment=M.observe_commitment(sold,lease,modules)
check(sold.shop_sequence_commitment.status=='matched','Exact projected sale matches fresh public state')
local result=D.run(sold,modules)
check(result.action.kind=='buy' and result.action.area=='shop_jokers' and result.action.index==1,'Production decision preserves funded plan over voucher incumbent')
check(result.shop_diagnostics.continuation.status=='revalidated' and result.evaluations>0 and result.evaluations<=50000,'Fresh complete comparison charged')
local receipt=J.compact_shop_sequence_review(result)
check(receipt.plan.id==lease.id and receipt.steps[1].id=='one' and receipt.steps[2].id=='two','Compact public receipt identifies remaining physical offers')
check(not J.encode(receipt):find('expected',1,true),'No matching key or full sampled states journaled')
local lease2=assert(M.prepare_commitment(sold,result.strategy,modules))
check(Snap.fingerprint(M.observe_commitment(sold,lease2,modules))==Snap.fingerprint(sold.shop_sequence_commitment),'Queued second buy preserves prior public disposition before settlement')
local bought=assert(M.transition(sold,result.action,modules));bought.shop_sequence_commitment=M.observe_commitment(bought,lease2,modules)
local second=D.run(bought,modules)
check(second.action.kind=='buy' and second.strategy.shop_sequence.steps[1].id=='two','Second purchase separately revalidated after actual index shift')
check(not M.prepare_commitment(bought,second.strategy,modules),'Final accepted action clears remaining plan')
for _,change in ipairs({function(x)x.shop_jokers[1].cost=3 end,function(x)x.shop_jokers[1].id='replacement' end,
 function(x)x.dollars=4 end,function(x)x.round=5 end,function(x)x.probabilities.normal=2 end,
 function(x)x.shop_vouchers[1].cost=4 end,function(x)x.joker_limit=4 end}) do
 local changed=Snap.copy(sold);change(changed)
 changed.shop_sequence_commitment=M.observe_commitment(changed,lease,modules)
 check(changed.shop_sequence_commitment.status=='public_context_changed','Changed public context invalidates binding')
 local r,d=M.resume(changed,modules,{compare=function()error('Stale context must not score')end})
 check(not r and not d.complete,'Stale continuation cannot publish an action')
end
local noid=Snap.copy(s);noid.shop_jokers[2].id=nil
check(not M.prepare_commitment(noid,proposal,modules),'No irreversible plan without physical offer IDs')
local tiny=D.run(sold,modules,nil,{shop_scoring={max_evaluations=0}})
check(tiny.action==nil and tiny.kind=='unsupported' and tiny.evaluations==0 and tiny.shop_diagnostics.continuation.complete==false,'Budget exhaustion does not reuse old score evidence')
local unavailable={compare=function()return {after_readiness={supported=true},complete_finishing=true,samples=4,
 before_finishing={selected={mean_progress=1}},after_finishing={selected={mean_progress=1}},ratio=1}end}
check(not M.resume(sold,modules,unavailable),'A summary without complete paired worlds cannot certify continuation')
check(Snap.fingerprint(s)==original,'Whole process leaves initial input unchanged')
-- Endpoint admission is shared with direct acquisition and protects a durable teacher core.
local core=Snap.copy(s);core.teacher_profile='perkeo_yorick_win_v1'
core.jokers={{id='engine',key='j_yorick',ability={name='Yorick',x_mult=2,extra={discards=23,xmult=1},yorick_discards=7}}}
local after=Snap.copy(core);after.jokers={j('bridge','j_ice_cream','Ice Cream',0,1)}
local ok,why=S.shop_sequence_admission(core,after,{ratio=4})
check(not ok and why.kind=='core_sequence_horizon_guard','High opening ratio alone cannot sell durable core for temporary power')
local finish={complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=4,mean_progress=1,worlds={}}}
local deficit=Snap.copy(finish);deficit.selected.clearing_samples=0;deficit.selected.mean_progress=.5
for i=1,4 do finish.selected.worlds[i]={clear=true,progress=1};deficit.selected.worlds[i]={clear=false,progress=.5} end
local rescue={complete_finishing=true,samples=4,before_finishing=deficit,after_finishing=finish,
 before_target=100,after_target=100,common_worlds={kind='shop_four_common_worlds_v1',samples=4,family_key='invented',world_ids={1,2,3,4}},
 before_readiness={supported=true,status='sampled_deficit'},after_readiness={supported=true,status='sampled_safe'}}
check(S.shop_sequence_admission(core,after,rescue),'Existing complete immediate rescue exception preserved')
print('advisor_shop_continuation408: '..checks..' checks passed')
