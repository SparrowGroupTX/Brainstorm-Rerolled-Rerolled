-- Manufactured public states and complete comparison witnesses, never captures.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules();local S=m.strategy
S.liquidity=dofile('Brainstorm/Advisor/liquidity.lua');S.paid_reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function planet(k,h)return {id=k,key=k,name=k,cost=3,sell_cost=1,ability={name=k,set='Planet',consumeable={hand_type=h}}}end
local function tarot(k)return {id=k,key=k,name=k,cost=3,sell_cost=1,ability={name=k,set='Tarot'}}end
local function state()
 local s=F.state(false);s.phase='shop';s.dollars=38;s.ante=3;s.reroll_cost=5;s.shop_jokers={};s.shop_vouchers={};s.shop_booster={}
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),F.j('j_brainstorm')};s.hands={Pair={played=8,level=3,chips=40,mult=4,l_chips=15,l_mult=1},Straight={played=0,level=1,chips=30,mult=4,l_chips=30,l_mult=3}}
 s.consumeables={planet('c_saturn','Straight')};s.consumable_limit=2;s.joker_limit=5;s.round_resets={hands=4,discards=3};s.round_bonus={};s.next_blind={key='bl_big',label='Big',ante=3,chips=2000}
 s.shop_forecast={slots=2,rates={joker=20,tarot=4,planet=4,playing=0,spectral=0},inflation=0,discount_percent=0,
  consumable_pool_schema='source_shop_consumables_v1',consumable_used={c_saturn=true},
  planet_pool={{key='c_mercury',name='Mercury',cost=3,source_set='Planet',source_effect='Hand Upgrade',source_config={hand_type='Pair'}}},
  tarot_pool={{key='c_death',name='Death',cost=3,source_set='Tarot',source_effect='Card Conversion',source_config={mod_conv='card',max_highlighted=2,min_highlighted=2}}}}
 return s
end
local function context(change)
 local ctx={evaluations=0,truncated=false}
 function ctx:compare(before,after)
  self.evaluations=self.evaluations+8;check(before.dollars-after.dollars==5,'paid miss actually debits reroll')
  local w={};for i=1,4 do w[i]={score=5000,clear=true,progress=1}end
  local f={complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=4,worlds=w}}
  local e={samples=4,complete_finishing=true,before_target=2000,after_target=2000,
   common_worlds={kind='shop_four_common_worlds_v1',samples=4,world_ids={1,2,3,4},family_key='manufactured423'},before_finishing=f,after_finishing=F.copy(f)}
  if change then change(e,self) end;return e
 end
 return ctx
end
do
 local s=state();local before=m.snapshot.fingerprint(s);local ctx=context();local a=S.copy_source_exploration(s,ctx)
 check(a and a.action.kind=='reroll' and #a.reroll_forecast.candidates==2,'mixed shop credits retainable Planet and Death even with Brainstorm owned')
 check(a.reroll_forecast.credited_slots==1 and ctx.evaluations==8,'one paired paid miss, first slot only')
 check(m.snapshot.fingerprint(s)==before and s.consumeables[1].key=='c_saturn','no hypothetical acquisition or seed deletion')
 local J=dofile('Brainstorm/Advisor/player_journal.lua');local review=J.compact_reroll_review({action=a.action,strategy=a,shop_diagnostics={copy_source=ctx.copy_source_diagnostics}})
 check(review.copy_source.complete_paid_miss and not review.copy_source.candidates,'journal retains scalar evidence, no catalog/world dump')
end
local controls={
 {'matching Saturn',function(s)s.hands.Straight.played=40;s.hands.Straight.level=8 end},
 {'useful Negative Death',function(s)local c=tarot('c_death');c.edition={negative=true};s.consumeables[2]=c;s.consumable_limit=3 end},
 {'unknown stock',function(s)s.consumeables[1].unknown=true end},
 {'cash floor',function(s)s.dollars=29 end},
 {'rental reserve',function(s)s.dollars=33;s.jokers[1].ability.rental=true end},
 {'paid discard reserve',function(s)s.dollars=35;s.modifiers.discard_cost=2 end},
 {'full ordinary slots',function(s)s.consumable_limit=1 end},
 {'missing catalog',function(s)s.shop_forecast=nil end},
 {'modified Death and irrelevant Planet',function(s)s.shop_forecast.tarot_pool[1].source_config.h_size=1;s.shop_forecast.planet_pool[1].source_config.hand_type='Straight Flush' end},
 {'duplicate metadata',function(s)s.shop_forecast.planet_pool[2]=F.copy(s.shop_forecast.planet_pool[1]) end},
 {'unknown Planet identity',function(s)s.shop_forecast.planet_pool[1].key='c_modded_planet';s.shop_forecast.tarot_pool={} end},
 {'modified Planet effect',function(s)s.shop_forecast.planet_pool[1].source_effect='Draw Cards';s.shop_forecast.tarot_pool={} end},
 {'modified Planet name',function(s)s.shop_forecast.planet_pool[1].name='Not Mercury';s.shop_forecast.tarot_pool={} end},
 {'modified Planet softlock',function(s)s.shop_forecast.planet_pool[1].source_config.softlock=true;s.shop_forecast.tarot_pool={} end},
 {'no future copy',function(s)s.next_blind={ante=8,boss=true} end},
 {'generic profile',function(s)s.teacher_profile='collection_progress' end}}
for _,v in ipairs(controls)do local s=state();v[2](s);local x=S.copy_source_exploration(s,context());check(not x,'no source hunt: '..v[1]..' / '..tostring(S.build_profile(s).hand)..' / '..tostring(x and x.reroll_forecast.candidates[1].key))end
for _,v in ipairs({
 {'incomplete',function(e)e.complete_finishing=false end},
 {'budget',function(e,c)c.truncated=true end},
 {'unpaired',function(e)e.common_worlds.world_ids[4]=3 end},
 {'cash-sensitive decline',function(e)e.after_finishing.selected.worlds[4].score=4999 end},
 {'uncertain',function(e)e.uncertain=true end},
 {'miss loses clear',function(e)e.after_finishing.selected.worlds[4].clear=false end}})do
 check(not S.copy_source_exploration(state(),context(v[2])),'reject '..v[1])
end
-- Observed secondary rank-repeat hands remain useful Perkeo scaling stock.
do
 local s=state();s.consumeables={tarot('c_judgement')};s.hands.Pair.played=0
 s.hands['Full House']={played=5,level=2,chips=65,mult=6};s.hands['Four of a Kind']={played=1,level=1,chips=60,mult=7,l_chips=30,l_mult=3}
 s.shop_jokers={planet('c_mars','Four of a Kind')};s.dollars=26
 local a=S.advise(s);check(a.action.kind=='buy','buy supported secondary Mars over keeping only Judgement: '..a.action.kind)
 s.consumeables[2]=planet('c_venus','Three of a Kind');s.hands['Three of a Kind']={played=2,level=1,chips=30,mult=3,l_chips=20,l_mult=2}
 s.shop_jokers={};a=S.manage_teacher_stock(s)
 check(a and a.action.kind=='sell' and a.action.index==1,'useful Venus displaces saturating Judgement even with Joker space')
 s.jokers[4]=F.j('j_ice_cream');s.jokers[5]=F.j('j_greedy_joker');s.shop_jokers={}
 a=S.manage_teacher_stock(s);check(a and a.action.kind=='sell' and a.action.index==1,'remove unusable Judgement from useful Venus pool')
 s=state();s.consumeables={};s.dollars=10;s.hands.Pair.played=0;s.hands.Pair.level=1;s.hands.Straight.played=2
 s.shop_jokers={planet('c_mercury','Pair'),tarot('c_lovers')}
 a=S.advise(s);check(a.action.kind=='buy' and a.action.index==1,'prefer broadly usable Pair scaling source over Wild filler')
end
-- Spending caps cannot introduce any Joker sale or weak Joker purchase.
for _,ante in ipairs({1,3,4,6,7,8})do
 local s=state();s.ante=ante;local target=ante>=7 and 25 or ante>=4 and 35 or 50;s.dollars=target+5
 s.shop_jokers={F.j('j_ice_cream')};s.joker_limit=#s.jokers
 local a=S.late_cash_spend(s,{action={kind='leave_shop'}})
 check(a and a.action.kind=='reroll' and a.late_spend_review.cash_after==target,'cash cap only spends existing surplus '..ante)
 check(not S.late_cash_spend(s,{action={kind='buy',index=1,area='shop_jokers'}}),'purchase wins over cash cap '..ante)
 s.dollars=target+4;check(not S.late_cash_spend(s,{action={kind='leave_shop'}}),'indivisible costs respect cap '..ante)
end
do
 local s=state();s.ante=7;s.modifiers.discard_cost=10;s.dollars=34
 check(not S.late_cash_spend(s,{action={kind='leave_shop'}}),'larger actual discard reserve protected')
end
do
 local s=state();s.ante=2;s.next_blind.ante=2;s.next_blind.chips=100;s.dollars=38
 m.shop_scoring=dofile('Brainstorm/Advisor/shop_scoring.lua')
 m.shop_scoring.blind_finishing=dofile('Brainstorm/Advisor/blind_finishing.lua')
 m.shop_scoring.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
 for _,k in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards','strategy','pack_survival'})do
  m.shop_scoring.blind_finishing[k]=m[k] or dofile('Brainstorm/Advisor/'..k..'.lua')
 end
 local r=m.decision.run(s,m,nil,{prepared_scoring=false})
 check(r.action.kind=='reroll' and r.strategy.reroll_forecast and r.strategy.reroll_forecast.mode=='perkeo_source_exploration',
  'production source hunt: '..tostring(r.action.kind)..' / '..tostring(r.shop_diagnostics and r.shop_diagnostics.copy_source and r.shop_diagnostics.copy_source.status))
 check(r.evaluations<=50000 and r.shop_diagnostics.copy_source.complete_paid_miss,'production paid miss completes inside shared shop budget')
 s.shop_jokers={planet('c_mercury','Pair')}
 r=m.decision.run(s,m,nil,{prepared_scoring=false})
 check(r.action.kind=='buy','visible useful stock takes priority over optional source hunt')
 s.shop_jokers={};r=m.decision.run(s,m,nil,{prepared_scoring=false,shop_scoring={max_evaluations=1}})
 check(r.action.kind~='reroll','unavailable paired proof does not bypass low shop allowance')
end
-- Inject complete manufactured comparison witnesses at the shop-scoring seam;
-- exercise real final arbitration, including the newly widened cash rule.
for _,case in ipairs({'lost_clear','less_overkill','same_score'})do
 local s=state();s.ante=1;s.next_blind.ante=1;s.dollars=55
 local provider={};for k,v in pairs(S)do provider[k]=v end
 provider.advise=function()return {action={kind='leave_shop'},lines={},warnings={}}end
 local scoped={strategy=provider,scoring=m.scoring,shop_scoring={new=function()
  return context(function(e)
   if case=='lost_clear' then e.after_finishing.selected.worlds[4].clear=false;e.after_finishing.selected.worlds[4].score=1900
   elseif case=='less_overkill' then e.after_finishing.selected.worlds[4].score=4999 end
  end)
 end}}
 local r=m.decision.run(s,scoped,nil,{prepared_scoring=false})
 check((r.action.kind=='leave_shop')==(case=='lost_clear'),'final cash cap respects actual lost clear '..case)
 if case=='lost_clear' then check(r.strategy.late_spend_review.status=='paid_miss_loses_clear','visible final rejection reason')end
 check(r.evaluations<=50000,'seam comparisons share actual decision count '..case)
end
print('Perkeo sources423: '..count..' manufactured assertions passed')
