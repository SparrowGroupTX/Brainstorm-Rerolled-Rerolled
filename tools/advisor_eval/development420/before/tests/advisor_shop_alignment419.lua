-- Invented shop states only. No captured observations or original game execution.
local P='Brainstorm/Advisor/'
local S=dofile(STRATEGY419_PATH or P..'strategy.lua')
local Snap=dofile(P..'snapshot.lua');local Seq=dofile(P..'shop_sequences.lua')
local C=dofile(P..'consumables.lua');S.consumables=C;S.liquidity=dofile(P..'liquidity.lua')
local count=0
local function check(v,m)count=count+1;assert(v,m)end
local function j(key,id,extra)
 local names={j_perkeo='Perkeo',j_yorick='Yorick',j_brainstorm='Brainstorm',j_blueprint='Blueprint',j_burnt='Burnt Joker',j_joker='Joker',j_trading='Trading Card',j_banner='Banner'}
 local a={set='Joker',name=names[key] or key};for k,v in pairs(extra or {})do a[k]=v end
 return {id=id,key=key,name=a.name,ability=a,cost=3,sell_cost=2,blueprint_compat=key~='j_trading'}
end
local function planet(key,hand)
 return {id='offer:'..key,key=key,name=key,cost=3,sell_cost=1,ability={set='Planet',name=key,consumeable={hand_type=hand}}}
end
local function state()
 local s={phase='shop',ante=2,win_ante=8,teacher_profile='perkeo_yorick_win_v1',dollars=6,
 jokers={j('j_perkeo','perkeo'),j('j_yorick','yorick',{x_mult=3,eternal=true,yorick_discards=5,extra={discards=23,xmult=1}}),j('j_brainstorm','copy',{rental=true})},
 consumeables={},consumable_limit=2,consumeable_buffer=0,joker_limit=5,
 shop_jokers={planet('c_neptune','Straight Flush')},shop_booster={},shop_vouchers={},reroll_cost=5,
 hands={Pair={played=7,level=3,chips=35,mult=4},['Straight Flush']={played=0,level=1,chips=100,mult=8}},
 playing_cards={},hand={},deck={},round_resets={hands=4,discards=4},round_bonus={},modifiers={},bankrupt_at=0,
 next_blind={key='bl_big',label='Big',ante=2,chips=500},blind={key='bl_small',chips=300},interest_cap=25}
 for i=1,40 do s.playing_cards[i]={id='made:'..i,rank=2+(i%13),suit='Clubs',enhancement='c_base'} end
 return s
end
local function world(clear)
 local t={};for i=1,4 do t[i]={clear=clear,progress=clear and 1 or .5}end
 return {complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=clear and 4 or 0,worlds=t}}
end
local function evidence(after,rescue)
 local retained=false;local order={};local source
 for i,c in ipairs(after.jokers or {})do if c.key=='j_perkeo' then retained=true end;if c.key=='j_yorick' then source=i end end
 if source then order[1]=source end
 for i=1,#(after.jokers or {})do if i~=source then order[#order+1]=i end end
 return {samples=4,ratio=retained and 1.2 or 4,adjustment=20,before_mean=1000,after_mean=retained and 1200 or 4000,
 before_target=500,after_target=500,complete_finishing=true,before_finishing=world(not rescue),after_finishing=world(true),
 before_readiness={supported=true,status=rescue and 'sampled_deficit' or 'sampled_safe'},after_readiness={supported=true,status='sampled_safe'},
 common_worlds={kind='shop_four_common_worlds_v1',samples=4,world_ids={1,2,3,4},family_key='invented419'},
 after_ordering={samples=4,order=order},reason='Invented complete comparison.'}
end
local function context(fail_alternative)
 local ctx={evaluations=0,max_evaluations=50000,truncated=false}
 function ctx:compare(before,after)
  self.evaluations=self.evaluations+4;local e=evidence(after)
  if fail_alternative then for _,c in ipairs(after.jokers)do if c.key=='j_perkeo' then e.after_finishing=world(false) end end end
  return e
 end
 function ctx:readiness()return {supported=true,status='sampled_safe'}end
 return ctx
end
for _,ante in ipairs({1,2,4,7,8})do
 local s=state();s.ante=ante;s.next_blind.ante=ante
 local fp=Snap.fingerprint(s);local a=S.advise(s)
 check(a.action.kind=='buy' and a.action.index==1,'initial cheap stock bought at ante '..ante)
 check(Snap.fingerprint(s)==fp,'valuation is detached')
 local after=assert(Seq.transition(s,a.action,{strategy=S,consumables=C}))
 check(after.dollars==3 and #after.consumeables==1,'only actual payment funds acquisition')
 local _,info=S.inventory_value(after);check(info.stock_option>0,'retained whole-pool option')
 local used=assert(C.apply(after,1,{}));local loss,_,last=S.preservation_cost(after,used,1)
 check(last and loss>0,'sole template preserved through owned-use comparison')
 check(not Seq.transition(after,{kind='use',area='consumeables',index=1},{strategy=S,consumables=C}),'graph cannot cash activation credit by consuming template')
 check(S.advise(after).action.kind=='leave_shop','fresh shop advice retains sole stock through exit')
 local duplicate=Snap.copy(after.consumeables[1]);duplicate.id='new-negative';duplicate.edition={negative=true}
 after.consumeables[2]=duplicate;after.consumable_limit=3
 local sale=S.manage_teacher_stock(after)
 check(sale and sale.action.kind=='sell' and sale.action.index==2,'duplicate filler can become cash while source stays')
end
do
 local s=state();s.dollars=5
 check(S.advise(s).action.kind~='buy','seed cannot consume rental reserve')
 local after=assert(Seq.transition(s,{kind='buy',area='shop_jokers',index=1},{strategy=S,consumables=C}))
 check(not S.shop_sequence_admission(s,after,evidence(after)),'graph shares actual seed reserve')
 s=state();s.modifiers.discard_cost=1;s.dollars=9
 check(S.advise(s).action.kind~='buy','seed reserves all paid discards as well as rental')
 s=state();s.shop_jokers[2]=planet('c_mercury','Pair');s.dollars=12
 check(S.advise(s).action.index==2,'superior visible first source wins')
 s=state();s.ante=8;s.next_blind={label='Boss',boss=true,ante=8}
 local after=assert(Seq.transition(s,{kind='buy',area='shop_jokers',index=1},{strategy=S,consumables=C}))
 local _,info=S.inventory_value(after);check(info.stock_option==0,'no future economic runway before final boss')
 s=state();s.shop_jokers[1].unknown=true
 local _,unknown=S.inventory_value(s,{s.shop_jokers[1]});check(unknown.stock_option==0,'unknown stock not qualified')
 s=state();s.teacher_profile='collection_progress'
 check(S.advise(s).action.kind~='buy','generic profile does not inherit teacher stock preference')
end
for _,phase in ipairs({'shop','pack'})do
 local s=state();s.phase=phase;s.ante=5;s.dollars=100;local t=j('j_trading','trading',{extra=3,rental=true});t.cost=1
 local after=Snap.copy(s);after.jokers[#after.jokers+1]=t;after.dollars=99
 local ok,why=S.joker_admission(s,t,after,evidence(after))
 check(not ok and why.kind=='teacher_single_discard_acquisition','Trading acquisition rejected in '..phase)
 check(not S.shop_sequence_admission(s,after,evidence(after)),'sequence cannot bypass Trading guard')
 check(S.joker_admission(s,t,after,evidence(after,true)),'real paired survival rescue remains eligible')
 s.jokers={j('j_perkeo','perkeo')};check(not S.joker_admission(s,t,after),'teacher rule also without Yorick')
 s.teacher_profile='collection_progress';check(S.joker_admission(s,t,after),'generic Trading strategy preserved')
end
do
 local s=state();s.dollars=27;local ordinary=j('j_joker','ordinary',{mult=4});ordinary.cost=3
 local after=Snap.copy(s);after.jokers[#after.jokers+1]=ordinary;after.dollars=24
 local ok,why=S.joker_admission(s,ordinary,after,evidence(after));check(not ok and why.kind=='teacher_early_economy_guard','early ordinary buy preserves reserve')
 after.dollars=28;check(S.joker_admission(s,ordinary,after,evidence(after)),'at $25 plus rental floor admits ordinary buy')
 after.dollars=27;check(not S.joker_admission(s,ordinary,after,evidence(after)),'one below floor rejected')
 check(S.joker_admission(s,ordinary,after,evidence(after,true)),'complete paired rescue can spend early buffer')
 local broken=evidence(after,true);broken.after_finishing.selected.worlds[4].clear=false
 check(not S.joker_admission(s,ordinary,after,broken),'one failing rescue world rejects waiver')
 local other=j('j_joker','second',{mult=4});after.jokers[#after.jokers+1]=other;after.dollars=26
 check(not S.shop_sequence_admission(s,after,evidence(after)),'combined multi-buy endpoint obeys floor')
 ordinary.cost=0;after.jokers[#after.jokers]=nil;check(S.joker_admission(s,ordinary,after),'free nonrental ordinary choice is not a paid economy drain')
 ordinary.ability.rental=true;check(not S.joker_admission(s,ordinary,after),'free rental still spends future cash')
 ordinary.ability.rental=nil;ordinary.cost=3;s.phase='pack';check(S.joker_admission(s,ordinary,after),'pack selection has no ordinary cash debit')
 s.phase='shop';s.ante=4;check(S.joker_admission(s,ordinary,after),'early-only conservatism ends after ante3')
 s.ante=2;s.teacher_profile='collection_progress';check(S.joker_admission(s,ordinary,after),'generic acquisition preserved')
end
for _,phase in ipairs({'shop','pack'})do
 local s=state();s.ante=4;s.dollars=30;s.joker_limit=3
 s.jokers={j('j_yorick','yorick',{x_mult=4,eternal=true,extra={discards=23,xmult=1}}),j('j_perkeo','perkeo'),j('j_joker','filler',{mult=4})}
 s.consumeables={{id='source',key='c_death',name='Death',cost=3,sell_cost=1,ability={set='Tarot',name='Death'}}}
 s.shop_jokers={j('j_brainstorm','new-copy')};s.phase=phase
 if phase=='pack' then s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.pack_cards=s.shop_jokers;s.shop_jokers={} end
 local a=S.advise(s,{shop_scoring=context()})
 check(a.action.kind=='sell' and a.action.index==3,'safe same-copy alternative retains Perkeo in '..phase)
 local vacant=assert(Seq.transition(s,a.action,{strategy=S}))
 local fresh=S.advise(vacant,{shop_scoring=context()})
 check(fresh.action.kind==(phase=='pack' and 'choose' or 'buy') and fresh.action.index==1,'fresh vacancy still acquires same copy')
 local fallback=S.advise(s,{shop_scoring=context(true)})
 check(fallback.action.kind=='sell' and fallback.action.index==2,'only supported slot can still exchange Perkeo in '..phase)
end
-- Explicit surplus spending is one fresh action, after normal purchases.
for _,ante in ipairs({6,7,8})do
 local s=state();s.ante=ante;s.dollars=36;s.shop_jokers={};local base={action={kind='leave_shop'}}
 local a=S.late_cash_spend(s,base)
 check((a~=nil)==(ante>=7),'late spending starts at ante7')
 if a then check(a.action.kind=='reroll' and a.late_spend_review.cash_after==31,'refresh preserves $25 plus rental reserve')end
 s.dollars=32;check(not S.late_cash_spend(s,base),'indivisible paid action cannot cross reserved buffer')
 s.dollars=36;s.shop_booster={{key='p_buffoon_normal_1',name='Buffoon Pack',cost=4,ability={set='Booster'}}}
 a=S.late_cash_spend(s,base)
 if ante>=7 then check(a and a.action.kind=='open','use affordable visible pack before otherwise idle cash')end
 check(not S.late_cash_spend(s,{action={kind='buy',area='shop_jokers',index=1}}),'never displace a chosen purchase')
 s.teacher_profile='collection_progress';check(not S.late_cash_spend(s,base),'generic spending unchanged')
end
-- Production paid Planet comparison must retain the source, and the decision
-- fallback must enforce the late spending preference too.
do
 local Shop=dofile(P..'shop_scoring.lua');local Score=dofile(P..'scoring.lua');local D=dofile(P..'decision.lua')
 local s=state();s.hand_size=5;s.hand_limit=5;s.playing_cards={}
 for i=1,12 do s.playing_cards[i]={id='production:'..i,rank=8,suit='Clubs',nominal=8,ability={},enhancement='c_base'}end
 local r=D.run(s,{strategy=S,scoring=Score,shop_scoring=Shop,shop_sequences=Seq,consumables=C},nil,{prepared_scoring=false})
 check(r.action.kind=='buy' and r.action.index==1,'production comparison buys initial Neptune stock: '..tostring(r.action.kind)..' / '..tostring(r.strategy and r.strategy.title)..' / '..tostring(r.evaluations)..' / '..table.concat(r.strategy and r.strategy.lines or {},' | '))
 check(r.evaluations<=50000,'production keeps shared shop cap')
 local after=assert(Seq.transition(s,r.action,{strategy=S,consumables=C}));local fresh=D.run(after,{strategy=S,scoring=Score,shop_scoring=Shop,shop_sequences=Seq,consumables=C},nil,{prepared_scoring=false})
 check(fresh.action.kind=='leave_shop','production graph retains source after actual paid transition')
 s=state();s.ante=7;s.dollars=34;s.shop_jokers={};s.jokers={};s.shop_forecast=nil
 r=D.run(s,{strategy=S});check(r.action.kind=='reroll','final decision spends late surplus even without a catalog forecast')
end
-- Discard-hostile acquisitions share the teacher rule, even without Yorick.
for _,key in ipairs({'j_banner','j_ramen'})do
 local x=state();x.ante=6;x.dollars=100;x.jokers={j('j_perkeo','perkeo')}
 local c=j(key,'conflict');local after=Snap.copy(x);after.jokers[2]=c
 check(not S.joker_admission(x,c,after,evidence(after)),'reject optional discard conflict '..key)
 check(S.joker_admission(x,c,after,evidence(after,true)),'real current rescue remains possible '..key)
 x.phase='pack';check(not S.joker_admission(x,c,after,evidence(after)),'free pack cannot bypass discard conflict '..key)
end
do
 local x=state();local after=Snap.copy(x);after.dollars=2
 after.consumeables={{id='strong',key='c_death',sell_cost=1,ability={set='Tarot',name='Death'}}}
 local _,info=S.inventory_value(after)
 check(info.stock_active and info.stock_option==60,'strong stock retains the same once-per-pool activation value')
 check(not S.shop_sequence_admission(x,after,evidence(after)),'strong initial-stock graph cannot spend rental reserve either')
 local owned=j('j_trading','owned',{extra=3});x.jokers[4]=owned
 local value=S.owned_joker_value(x,owned);check(value>0,'already-owned Trading value is not erased to force an unproved sale')
 -- Directly selectable Negative alternative must not hide the safe victim for
 -- the same Brainstorm. Its admission is retained independently of ranking.
 x=state();x.phase='pack';x.ante=4;x.dollars=30;x.joker_limit=3
 x.jokers={j('j_yorick','yorick',{x_mult=4,eternal=true,extra={discards=23,xmult=1}}),j('j_perkeo','perkeo'),j('j_joker','filler',{mult=4})}
 x.consumeables={{id='source',key='c_death',sell_cost=1,ability={set='Tarot',name='Death'}}}
 local other=j('j_cavendish','negative',{extra={Xmult=3}});other.edition={negative=true}
 x.pack_type='BUFFOON_PACK';x.pack_choices=1;x.pack_cards={j('j_brainstorm','new-copy'),other};x.shop_jokers={}
 local ctx=context();local compare=ctx.compare
 function ctx:compare(before,after)
  local e=compare(self,before,after)
  for _,c in ipairs(after.jokers)do if c.id=='negative' then e.after_mean=20000;e.ratio=20;e.adjustment=50 end end
  return e
 end
 local a=S.advise(x,{shop_scoring=ctx})
 check(not (a.action.kind=='sell' and a.action.index==2),'attractive direct Negative option cannot make Perkeo the victim over an admitted safe alternative')
end
print('Shop alignment419: '..count..' manufactured checks passed')
