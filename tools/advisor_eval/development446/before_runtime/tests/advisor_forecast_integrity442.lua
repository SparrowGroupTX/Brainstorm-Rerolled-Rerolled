-- Manufactured states only: source-shaped public sorting and resource counters.
local F=dofile('tests/fixtures/retained418.lua');local A=dofile('tests/fixtures/modules436.lua')
if SEARCH442_PATH then A.search=dofile(SEARCH442_PATH) end
local count=0;local function check(x,why)count=count+1;assert(x,why)end
local suits={Spades=.04,Hearts=.03,Clubs=.02,Diamonds=.01}
local function card(id,r,s,key,tie)
 local c=F.card(id,r,s,key);c.sort_tie=tie or .9
 c.base={id=r,suit=s,nominal=r==14 and 11 or math.min(r,10),face_nominal=r>=11 and(r-10)/10 or 0,
  suit_nominal=suits[s],suit_nominal_original=suits[s]/10};return c
end
local function ids(s)local r={};for _,c in ipairs(s.hand)do r[#r+1]=c.id end;return table.concat(r,',')end
do
 local s={hand_sort='desc',hand={card('low',2,'Spades'),card('high',13,'Diamonds'),card('middle',7,'Clubs')}}
 local before=A.snapshot.fingerprint(s)
 for _,v in ipairs({{'desc','high,middle,low'},{'asc','low,middle,high'},
  {'suit desc','low,middle,high'},{'suit asc','high,middle,low'}})do
  s.hand_sort=v[1];local sorted=assert(A.draws.sort_hand(s));check(ids(sorted)==v[2],'source automatic order '..v[1])
  check(sorted.draw_order_scope=='public_automatic_sort','order receipt')
 end
 s.hand_sort='desc';check(A.snapshot.fingerprint(s)==before,'sort is detached')
 local tie={hand_sort='desc',hand={card('later',13,'Clubs','c_base',.1),card('earlier',13,'Clubs','c_base',.9)}}
 check(ids(assert(A.draws.sort_hand(tie)))=='earlier,later','physical tie data precedes arbitrary ID order')
 tie.hand[1].base.suit_nominal_original=.004
 tie.hand[1].sort_tie=.899
 check(ids(assert(A.draws.sort_hand(tie)))=='later,earlier','source original-suit term precedes physical tie')
 local stone=card('stone',14,'Spades');stone.ability.effect='Stone Card'
 s.hand={stone,card('plain',2,'Diamonds')}
 check(ids(assert(A.draws.sort_hand(s)))=='plain,stone','Stone uses negative suit multiplier')
 for _,change in ipairs({function(t)t.hand_sort='order'end,function(t)t.hand[2].sort_tie=nil end,
  function(t)t.hand[2].base.face_nominal=0/0 end,function(t)t.hand[2]=F.copy(t.hand[1])end})do
  local t=F.copy(s);change(t);local no,why=A.draws.sort_hand(t)
  check(not no and type(why)=='string','invalid declared metadata is not silently approximated')
 end
 s.hand_sort=nil;check(assert(A.draws.sort_hand(s)).draw_order_scope=='legacy_append_order_unverified','historical metadata absence is explicit')
 local live={playing_card=3,unique_val=.875,base=F.copy(tie.hand[1].base),config={center={key='c_base'}},ability={}}
 live.get_nominal=function()error('live method must not run')end
 check(A.snapshot.card(live).sort_tie==.875,'capture copies deterministic metadata without live methods')
end
-- Every refill sorts, including physical forced-card identity across Bell sort.
do
 local s=F.state();s.hand_sort='desc';s.hand_size=3;s.hand={card('held',2,'Clubs')}
 s.blind={key='bl_final_bell',name='Cerulean Bell',chips=10}
 local out=assert(A.draws.fill(s,{card('draw',13,'Spades')},{bell_roll=0}))
 check(ids(out)=='draw,held','refill applies automatic sorting')
 check(out.hand[2].ability.forced_selection and not out.hand[1].ability.forced_selection,'sort moves the forced card, not the forced slot')
 check(not s.hand[1].ability.forced_selection,'refill input unchanged')
end
-- The actual card scorer exposes the append-versus-sorted arithmetic mismatch.
do
 local s=F.state();s.hand_sort='desc';s.hand={};s.deck={};s.jokers={};s.consumeables={}
 for i,r in ipairs({2,3,4,5,13})do s.hand[i]=card('order:'..i,r,'Spades',i==5 and'm_glass'or'm_mult',.9-i*.01)end
 F.population(s);local selected={1,2,3,4,5}
 local append=A.scoring.score(s,selected);local sorted=assert(A.draws.sort_hand(s));local actual=A.scoring.score(sorted,selected)
 check(append.score>actual.score and append.hand==actual.hand,'real Mult/Glass scoring depends on settled order')
 local target=(append.score+actual.score)/2
 check(append.score>target and actual.score<target,'a claimed clear can disappear without losing any card')
end
local function state()
 local s=F.state();s.ante=5;s.hand_size=6;s.hand={};s.deck={};s.consumeables={};s.hand_sort='desc'
 s.blind={key='bl_big',name='Big Blind',chips=75};s.hands_left=3;s.discards_left=3
 s.jokers={F.j('j_yorick')};s.jokers[1].ability.x_mult=6
 for i=1,6 do s.hand[i]=card('held:'..i,i+2,'Clubs','c_base',.9-i*.01)end
 for i=1,8 do s.deck[i]=card('draw:'..i,13,'Hearts','c_base',.5-i*.01)end
 F.population(s);return s
end
local function run(kind)
 local s=state();local calls=0
 if kind=='arm'then s.blind={key='bl_arm',name='The Arm',chips=75};s.hands={['High Card']={level=1,played=0},Pair={level=6,played=8}}end
 local scoring={after_discard=function(t,ix)local after,e=A.scoring.after_discard(t,ix);if after then after.after442=true end;return after,e end}
 function scoring.score(t,ix)
  calls=calls+1;local score=80;local cost=t.after442 and(kind=='population_cost' or kind=='glass_loss')and 1 or 0
  if kind=='sort'and t.after442 and t.hand[1].id:find('draw:',1,true)then score=20 end
  local p={score=score,legal=true,uncertain=false,hand=kind=='arm'and t.after442 and'Pair'or'High Card',indices=ix,scoring_indices=ix,warnings={}}
  if kind=='population_cost'or kind=='glass_loss'then p[kind]=cost end
  return p
 end
 local mods={search=A.search,scoring=scoring,draws=A.draws,strategy={build_profile=function()return{horizon=6}end}}
 local before=A.snapshot.fingerprint(s)
 local r=A.decision.run(s,mods,nil,{prepared_scoring=false,search={samples=24,candidates=5,draw_targets=false,resource_samples=0,max_evaluations=140000}})
 check(r.evaluations==calls and calls<=140000,'all score work remains charged '..kind)
 check(A.snapshot.fingerprint(s)==before,'input preserved '..kind)
 return r
end
for _,kind in ipairs({'sort','population_cost','glass_loss','arm','safe'})do
 local r=run(kind)
 if EXPECT_OLD442 or kind=='safe'then check(r.action.kind=='discard','safe/old counterfactual admits discard '..kind)
 else
  check(r.action.kind=='play','forecast refuses invented order/resource benefit '..kind)
  if kind~='sort'then
   check(r.risky_yorick_clear.resource_regressions==24,'all adverse completed worlds are retained')
   local pub=A.player_journal.compact_yorick_review(r)
   check(pub.risk.resource_regressions==24 and pub.risk.sorting_scope=='public_automatic_sort','bounded public refusal evidence')
  end
 end
end
-- Strength/suit changes recalculate the source fields; Death keeps the target's
-- physical identity and tie break even when copying the source's rank/suit.
do
 local s=state();s.hand[1]=card('left',12,'Clubs','c_base',.125);s.hand[2]=card('right',13,'Spades','m_glass',.875)
 s.consumeables={{key='c_death',ability={name='Death',set='Tarot'}}};F.population(s)
 local after=assert(A.consumables.apply(s,1,{1,2}))
 check(after.hand[1].id=='left'and after.hand[1].sort_tie==.125,'Death keeps physical destination tie')
 check(after.hand[1].rank==13 and after.hand[1].suit=='Spades','Death copies card properties')
 check(after.hand[1].base.suit_nominal_original==.002,'Death preserves destination first suit')
 check(A.draws.sort_hand(after),'Death copies remain separately sortable')
 local close=F.copy(s);close.hand[1].sort_tie=.9000001;close.hand[2].sort_tie=.9
 local transformed=assert(A.consumables.apply(close,1,{1,2}))
 local sorted=assert(A.draws.sort_hand(transformed));local li,ri
 for i,c in ipairs(sorted.hand)do if c.id=='left'then li=i elseif c.id=='right'then ri=i end end
 check(ri<li,'original suit outranks close physical ties after Death')
 for _,spec in ipairs({{'c_strength','Strength',13,'Clubs'},{'c_world','The World',12,'Spades'}})do
  local t=F.copy(s);t.consumeables={{key=spec[1],ability={name=spec[2],set='Tarot'}}}
  local a=assert(A.consumables.apply(t,1,{1}))
  check(a.hand[1].rank==spec[3]and a.hand[1].suit==spec[4],'transformed base stays current')
  check(a.hand[1].base.face_nominal==(spec[3]-10)/10 and a.hand[1].base.suit_nominal==suits[spec[4]],'transformed sorting fields stay current')
  check(a.hand[1].sort_tie==.125 and A.draws.sort_hand(a),'physical transform is sortable')
 end
end
-- Search's multi-play continuation must not reassign Bell by the old slot after
-- the authoritative refill has moved the one forced physical card by sorting.
if not EXPECT_OLD442 then
 local s=state();s.blind={key='bl_final_bell',name='Cerulean Bell',chips=100000}
 s.hand[1].ability.forced_selection=true
 local base=A.scoring;local seen=0
 local proxy=setmetatable({}, {__index=base})
 proxy.score=function(t,ix)
  if t.draw_order_scope=='public_automatic_sort' and (t.hands_played or 0)>0 then
   local forced=0;for _,c in ipairs(t.hand)do if(c.ability or{}).forced_selection then forced=forced+1 end end
   check(forced==1,'multi-play continuation has exactly one Bell forced physical card');seen=seen+1
  end
  return base.score(t,ix)
 end
 local mods={};for k,v in pairs(A)do mods[k]=v end;mods.scoring=proxy
 local r=A.decision.run(s,mods,nil,{prepared_scoring=false,search={resource_samples=4,max_evaluations=140000}})
 check(seen>0 and r.resource_comparison and r.resource_comparison.samples>=4,'real remaining-hand comparison exercises sorted Bell refill')
 check(r.evaluations<=140000,'physical Bell continuation remains within ordinary budget')
 mods.sampled_outcomes=nil
 local fallback=A.decision.run(s,mods,nil,{prepared_scoring=false,search={resource_samples=4,max_evaluations=140000}})
 check(not fallback.resource_comparison,'declared automatic sort rejects incomplete continuation adapter')
end
print('Forecast integrity442: '..count..' checks passed')
