-- Entirely invented states; no captured snapshot is executed or scored.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if DECISION425_PATH then m.decision=dofile(DECISION425_PATH) end
local J=dofile('Brainstorm/Advisor/player_journal.lua')
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function state(key)
 local s=F.state(false);s.ante=4;s.hand={};s.deck={};s.hand_size=8
 s.blind={key='bl_big',name='Big Blind',chips=300}
 for i,r in ipairs({13,13,2,4,6,8,10,12})do s.hand[i]=F.card('held425:'..i,r,'Clubs')end
 for i=1,24 do s.deck[i]=F.card('draw425:'..i,13,'Hearts')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo')};s.jokers[1].ability.x_mult=4
 s.hands={Pair={chips=10,mult=2,level=1,l_chips=15,l_mult=1,played=10},
  ['High Card']={chips=5,mult=1,level=1,l_chips=10,l_mult=1,played=0}}
 local names={c_heirophant='The Hierophant',c_empress='The Empress',c_mercury='Mercury'}
 s.consumeables={}
 for i=1,3 do s.consumeables[i]={id='stock425:'..i,key=key,
  edition=i>1 and {negative=true,type='negative'} or nil,
  ability={name=names[key],set=key=='c_mercury' and 'Planet' or 'Tarot'}}end
 F.population(s);return s
end
local options={prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}}
local function run(s,modules,opts)
 local before=m.snapshot.fingerprint(s)
 local r=m.decision.run(s,modules or m,nil,opts or options)
 check(m.snapshot.fingerprint(s)==before,'decision preserves its complete input')
 check(r.evaluations<=140000,'ordinary work stays bounded')
 return r
end
do
 local s=state('c_heirophant');local r=run(s)
 if EXPECT_BASELINE425 then
  check(r.action.kind=='use' and r.consumable and r.consumable.development,'baseline uses optional Hierophant first')
  check(r.risky_yorick_clear.search_selected and r.risky_yorick_clear.selected_cards==5,'baseline displaced a selected full discard')
  print('Baseline425 Hierophant overrides selected discard confirmed');return
 end
 check(r.action.kind=='discard' and #r.action.indices==5,'qualified five-card discard beats optional Hierophant')
 check(r.risky_yorick_clear.development_deferred_for_discard,'deferral is recorded')
 check(not r.consumable and r.risky_yorick_clear.selected,'final arbitration retains discard')
 local public=J.compact_yorick_review(r)
 check(public.risk.development_deferred_for_discard and public.risk.selected,'public receipt separates deferral and final selection')
end
-- Refresh on invented draws, retaining real physical counters and inventory.
for _,key in ipairs({'c_heirophant','c_empress','c_mercury'})do
 local s=state(key)
 for left=3,1,-1 do
  local r=run(s)
  check(r.action.kind=='discard' and #r.action.indices==5,key..' discards first with '..left..' remaining')
  check(r.risky_yorick_clear.development_deferred_for_discard,key..' optional development was compared and deferred')
  local before=s.jokers[1].ability.yorick_discards
  s=assert(m.scoring.after_discard(s,r.action.indices))
  check(s.discards_left==left-1 and s.jokers[1].ability.yorick_discards==before-5,'one physical five-card transition')
  check(#s.consumeables==3,'deferred inventory remains intact')
  while #s.hand<8 do s.hand[#s.hand+1]=table.remove(s.deck)end
  F.population(s)
 end
 local r=run(s)
 check(r.action.kind=='use' and r.consumable and r.consumable.development,key..' becomes available after last discard')
 check(not r.risky_yorick_clear or not r.risky_yorick_clear.development_deferred_for_discard,'no stale deferral on refreshed decision')
end
do
 local s=state('c_heirophant');s.consumeables[#s.consumeables+1]={id='death425',key='c_death',
  edition={negative=true,type='negative'},ability={name='Death',set='Tarot'}}
 local r=run(s)
 check(r.action.kind=='discard' and #r.action.indices==5,'held Death cannot route selected five through play fallback')
 check(r.risky_yorick_clear.selected,'held Death keeps selected search proof')
end
do
 local s=state('c_mercury');s.hands.Pair={chips=100,mult=10,level=10,l_chips=15,l_mult=1,played=10}
 s.blind.chips=5400
 local r=run(s)
 check(r.action.kind=='use' and r.consumable and not r.consumable.development,'actual Planet rescue is still selected')
 check(r.consumable.play.score>=5400 and r.play.score<5400,'rescue crosses a real scoring shortfall')
 check(not r.risky_yorick_clear or not r.risky_yorick_clear.development_deferred_for_discard,'rescue is not mislabeled as deferral')
end
-- Manufactured arbitration doubles isolate negative routing and exact work;
-- the integration cases above use the real scorer, search and consumables.
local function seam(change_s,change_r,extra,opts)
 local s=state('c_heirophant');if change_s then change_s(s)end
 local base={kind='discard',evaluations=29,play={score=400,legal=true,uncertain=false,indices={1,2},hand='Pair'},
  discard={indices={3,4,5,6,7}},risky_yorick_clear={selected=true,compared=true,exact_transition=true,samples=24}}
 if change_r then change_r(base)end
 local scoped={scoring=m.scoring,search={run=function()return F.copy(base)end},consumables={
  suggest=function()return {action={kind='use',area='consumeables',index=1},development={utility=20}},7,{evaluations=7}end,
  develop=function()return {action={kind='use',area='consumeables',index=1},development={utility=20}},1,{}end}}
 for k,v in pairs(extra or {})do scoped[k]=v end
 local r=run(s,scoped,opts)
 return r
end
do
 local r=seam()
 check(r.action.kind=='discard' and r.evaluations==36,'deferred comparison still charges all seven consumed evaluations')
end
for _,case in ipairs({
 {'generic profile',function(s)s.teacher_profile=nil end,nil},
 {'no remaining discards',function(s)s.discards_left=0 end,nil},
 {'nonqualified discard',nil,function(r)r.risky_yorick_clear.selected=false end},
 {'incomplete comparison',nil,function(r)r.risky_yorick_clear.compared=false end},
 {'short comparison',nil,function(r)r.risky_yorick_clear.samples=23 end},
 {'unsupported transition',nil,function(r)r.risky_yorick_clear.exact_transition=false end},
 {'conflicting incumbent',nil,function(r)r.action={kind='play',area='hand',indices={1,2}}end},
 {'different discard indices',nil,function(r)r.action={kind='discard',area='hand',indices={1,2,3,4,5}}end},
 {'continuation rejected discard',nil,function(r)r.kind='play';r.risky_yorick_clear.selected=false end}})do
 local r=seam(case[2],case[3])
 check(r.action.kind=='use','optional use remains available for '..case[1])
 check(not r.risky_yorick_clear.development_deferred_for_discard,'no deferral without qualified incumbent: '..case[1])
end
do
 local r=seam(nil,nil,{consumables={suggest=function()
  return {action={kind='use',area='consumeables',index=1},play={score=800}},5,{}
 end}})
 check(r.action.kind=='use' and not r.risky_yorick_clear.selected,'nondevelopment rescue can still supersede')
 check(r.risky_yorick_clear.search_selected,'original proposal remains visible after override')
end
for _,kind in ipairs({'ordering','phase_copy','retry'})do
 local extra,opts={},F.copy(options)
 if kind=='ordering' then extra.ordering={suggest=function()return {action={kind='reorder_jokers',order={2,1}}},3,{}end}
 elseif kind=='phase_copy' then extra.phase_copy={apply=function(s,modules,r)
  r.action={kind='reorder_jokers',order={2,1}};return r
 end}
 else opts.retry={unavailable=true}end
 local r=seam(nil,nil,extra,opts);local risk=J.compact_yorick_review(r).risk
 check(risk.development_deferred_for_discard and risk.search_selected,'proposal-level deferral survives '..kind)
 check(not risk.selected and not risk.final_action_matches_search,'final selection is honest after '..kind)
 check(risk.final_action_kind==(kind~='retry' and 'reorder_jokers' or nil),'final action kind reflects '..kind)
end
do
 local r=seam(nil,nil,{phase_copy={apply=function(s,modules,r)
  r.discard={indices={1,2}};r.action={kind='discard',area='hand',indices={1,2}};return r
 end}})
 check(not r.risky_yorick_clear.selected,'a replacement discard cannot impersonate the original proposal')
 check(not J.encode(J.compact_yorick_review(r)):find('proposal_indices',1,true),'public scalar receipt omits private proposal indices')
end
print('Discard development425: '..count..' manufactured assertions passed')
