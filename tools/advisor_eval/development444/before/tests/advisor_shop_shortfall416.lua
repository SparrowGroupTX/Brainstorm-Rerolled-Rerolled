local F=dofile('tests/fixtures/repair416.lua');local m=F.modules();local p=ADVISOR416_ROOT or 'Brainstorm/Advisor/'
local Shop=dofile(p..'shop_scoring.lua');local Finish=dofile(p..'blind_finishing.lua')
local L=dofile(p..'liquidity.lua');L.snapshot=m.snapshot;m.strategy.liquidity=L
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do Finish[name]=dofile(p..name..'.lua') end
Finish.strategy=m.strategy;Shop.strategy=m.strategy;Shop.blind_finishing=Finish;Shop.liquidity=L;m.shop_scoring=Shop
local R=dofile(p..'paid_reroll.lua');R.catalog=dofile(p..'catalog_joker.lua');R.liquidity=L;m.strategy.paid_reroll=R
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function fixture()
 local s=F.state();s.phase='shop';s.dollars=23;s.hand={};s.deck={};s.playing_cards={};s.hand_size=3;s.hand_limit=1
 s.round_resets={hands=2,discards=0};s.next_blind={key='bl_small',name='Small Blind',chips=10000};s.next_blind_chips=10000
 s.jokers={F.joker('j_yorick','Yorick',{x_mult=1,yorick_discards=18,extra={discards=23,xmult=1}}),F.joker('j_perkeo','Perkeo')}
 s.shop_jokers={};s.shop_vouchers={};s.shop_booster={};s.reroll_cost=5;s.interest_cap=25
 for i=1,12 do s.playing_cards[i]=F.card('p'..i,14,'Clubs') end
 s.shop_forecast={edition_rate=1,slots=2,inflation=0,discount_percent=0,rental_rate=3,used={},
  pools={{},{},{{key='j_blueprint',name='Blueprint',cost=10,rarity=3,source_set='Joker',source_config={},blueprint_compat=true}}},
  rates={joker=20,tarot=0,planet=0,playing=0,spectral=0}}
 return s
end
local s=fixture();local before=m.snapshot.fingerprint(s);local ctx=Shop.new(s,m.scoring,nil,{max_evaluations=12000})
local proof=m.strategy.shortfall_fallback_evidence(s,ctx)
check(proof and proof.complete,'complete actual incumbent and paid-miss policies establish sampled shortfall')
check(ctx.evaluations>0 and ctx.evaluations<=12000,'reserved comparison remains inside shared shop allowance')
check(proof.evidence.before_finishing.selected.clearing_samples==0,'all four declared incumbent samples fail')
local base={action={kind='leave_shop'}};local receipt={}
check(not m.strategy.surplus_reroll(s,base,{}),'ordinary exploration would preserve the interest reserve')
local r=m.strategy.shortfall_fallback(s,base,receipt,proof)
check(r and r.action.kind=='reroll' and r.reroll_forecast.mode=='shortfall_catalog_opportunity','certified fallback releases interest for a supported chance of an upgrade')
check(receipt.reroll_surplus_diagnostics.cash_after>=12 and receipt.reroll_surplus_diagnostics.interest_floor==0,'paid miss preserves purchase capacity')
check(m.snapshot.fingerprint(s)==before,'proof and recommendation leave cash and inventory untouched')
-- Isolate the downstream budget failure while using real scoring for the
-- reserved comparison. Optional candidate advice is deliberately incomplete.
local strategy=setmetatable({advise=function(_,options)
 if options and options.shop_scoring then options.shop_scoring.truncated=true;return {action={kind='buy',area='shop_jokers',index=1},lines={},warnings={}} end
 return {action={kind='leave_shop'},lines={},warnings={}}
end},{__index=m.strategy})
local scoped={strategy=strategy,shop_scoring=Shop,scoring=m.scoring}
local decision=m.decision.run(s,scoped,nil,{shop_scoring={max_evaluations=12000}})
check(decision.action.kind=='reroll' and decision.shop_diagnostics.truncated,'whole-decision fallback retains complete independent survival evidence')
check(decision.evaluations==ctx.evaluations and decision.evaluations<=12000,'reserved scores charged once even after fallback')
local tiny=m.decision.run(s,scoped,nil,{shop_scoring={max_evaluations=1}})
check(tiny.action.kind=='leave_shop' and tiny.evaluations<=1,'incomplete reserved proof never releases cash')
for _,change in ipairs({function(e)e.complete_finishing=false end,function(e)e.uncertain=true end,
 function(e)e.before_finishing.selected.clearing_samples=1 end,function(e)e.after_finishing.selected.worlds[4].score=0 end,
 function(e)e.before_finishing.selected.worlds[4].score=0/0 end,function(e)e.after_finishing.known_mechanics=false end}) do
 local e=F.copy(proof.evidence);change(e)
 check(not m.strategy.shortfall_fallback_evidence(s,{compare=function()return e end}),'invalid, partial or worsening paid-miss evidence rejected')
end
local bad=fixture();bad.dollars=16
check(not m.strategy.shortfall_fallback_evidence(bad,ctx),'fee plus purchase floor cannot be borrowed')
bad=fixture();bad.jokers[3]=F.joker('j_bull','Bull',{extra=2})
local worse=m.strategy.shortfall_fallback_evidence(bad,Shop.new(bad,m.scoring,nil,{max_evaluations=12000}))
check(not worse,'actual cash-scaling score loss disqualifies the paid miss')
bad=fixture();bad.shop_forecast.pools={{},{},{}}
check(not m.strategy.shortfall_fallback(bad,base,{},proof),'sampled failure alone cannot invent a catalog upgrade')
local fresh=fixture();fresh.dollars=18;fresh.reroll_cost=6
local fresh_proof=m.strategy.shortfall_fallback_evidence(fresh,Shop.new(fresh,m.scoring,nil,{max_evaluations=12000}))
check(fresh_proof and m.strategy.shortfall_fallback(fresh,base,{},fresh_proof),'fresh paid miss can spend exactly to twelve dollars')
fresh.dollars=17;check(not m.strategy.shortfall_fallback_evidence(fresh,ctx),'one dollar below next miss floor stops further spending')
print('shop shortfall416: '..checks..' checks passed')
