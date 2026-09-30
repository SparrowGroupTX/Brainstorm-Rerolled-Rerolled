-- Manufactured finite hands and public metadata, never captured run states.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
m.two_hand_finish=dofile(FINISH451_PATH or 'Brainstorm/Advisor/two_hand_finish.lua')
m.sampled_outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
m.multi_discard=dofile('Brainstorm/Advisor/multi_discard.lua')
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function card(id,r,suit,tie)
 local c=F.card(id,r,suit);local v={Spades=.04,Hearts=.03,Clubs=.02,Diamonds=.01}
 c.base.suit_nominal=v[suit];c.base.suit_nominal_original=v[suit]/10;c.base.face_nominal=r>=11 and r<=13 and (r-10)/10 or 0
 c.sort_tie=tie;return c
end
local function state()
 local s=F.state(false);s.hand={};s.deck={};s.ante=5;s.hands_left=2;s.discards_left=0;s.discards_used=3;s.hands_played=2
 s.hand_size=4;s.hand_sort='desc';s.current_round={hands_left=2,discards_left=0,hands_played=2,discards_used=3}
 s.jokers={F.j('j_perkeo'),F.j('j_yorick')};s.jokers[2].ability.x_mult=3
 s.hands={['Two Pair']={chips=80,mult=5,level=4,l_chips=20,l_mult=1,played=2},
  Pair={chips=10,mult=2,level=1},['High Card']={chips=5,mult=1,level=1}}
 for i,r in ipairs({12,12,8,8})do s.hand[i]=card('made-held451:'..i,r,i%2==0 and 'Hearts'or 'Clubs',i/100)end
 for i,r in ipairs({6,6,3,3})do s.deck[i]=card('made-draw451:'..i,r,i%2==0 and 'Spades'or 'Diamonds',i/200)end
 s.consumeables={{id='made-uranus451',key='c_uranus',name='Uranus',ability={name='Uranus',set='Planet',consumeable={hand_type='Two Pair'}},edition={negative=true,type='negative'}}}
 s.consumable_limit=3;s.blind={key='bl_flint',name='The Flint',chips=1300};F.population(s);return s
end
local function incumbent(s)
 local p=m.scoring.score(s,{1,2,3,4});p.indices={1,2,3,4};return {kind='play',play=p}
end
local function run(s,r,options,overrides)
 local modules={};for k,v in pairs(m)do modules[k]=v end
 for k,v in pairs(overrides or {})do modules[k]=v end
 local calls=0;local scorer=modules.scoring;modules.scoring=setmetatable({},{__index=scorer})
 modules.scoring.score=function(...)calls=calls+1;return scorer.score(...)end
 modules.scoring.after_play=function(...)calls=calls+1;return scorer.after_play(...)end
 local hash=m.snapshot.fingerprint(s);local result_hash=m.snapshot.fingerprint(r)
 local out,work,d=m.two_hand_finish.suggest(s,modules,r,nil,options)
 check(work==calls and work<=math.min(12000,(options or {}).max_evaluations or 12000),'all scores and transitions charged')
 check(m.snapshot.fingerprint(s)==hash and m.snapshot.fingerprint(r)==result_hash,'snapshot and incumbent unchanged')
 return out,work,d
end
if EXPECT_BASELINE451 then
 local s=state();local r,w,d=run(s,incumbent(s))
 check(not r and w==0 and d.reason:find('remaining discard',1,true),'old two-hand specialist declines before evaluating last Planet')
 print('Baseline451: '..n..' checks; no-discard Planet comparison omitted');return
end
do
 local s=state();local p=incumbent(s);check(p.play.score==684,'independent Flint initial arithmetic: (40+36)*3*3')
 local r,w,d=run(s,p)
 check(r and r.action.kind=='use' and r.action.index==1 and d.complete,'last Uranus used after complete two-hand comparison')
 check(d.no_discard_planet and d.completed_outer==4 and d.first_actions==3,'two hold branches and one use across all four worlds')
 check(r.baseline_probability==0 and r.no_use_probability==0 and r.probability==1,'all four manufactured use worlds win, hold worlds lose')
 local after=assert(m.consumables.apply(s,1,{}));check(#after.consumeables==0 and after.consumable_limit==2,'physical Negative use consumes source and capacity')
 check(m.scoring.score(after,{1,2,3,4}).score==774,'independent Flint upgrade rounds Mult to same three but adds chips')
 local played=assert(m.scoring.after_play(after,{1,2,3,4}));local drawn=assert(m.draws.fill(played,played.deck))
 check(m.scoring.score(drawn,{1,2,3,4}).score==612,'independent final Two Pair arithmetic')
 check(played.chips+612==1386 and 684+522==1206,'independent two-hand use and hold totals straddle1300')
 check(d.consumable_offers[1].protected_last_source and d.consumable_offers[1].inventory_cost>0,'real preservation cost charges the last Perkeo source')
 for i,branch in ipairs(d.candidates)do
  check(#branch.worlds==4,'every branch has four complete public world receipts')
  for _,world in ipairs(branch.worlds)do
   check(table.concat(world.first_indices,',')=='1,2,3,4','use and both hold branches match initial play in symmetric case')
   check(world.first_score==(i==3 and 774 or 684),'actual first transition retains exact Flint score')
   check(world.inventory_after_use==(i==3 and 0 or 1) and world.capacity_after_use==(i==3 and 2 or 3),'full inventory and Negative capacity retained through refill')
   check(world.hands==2 and world.discards==0,'two scoring hands, no invented discard')
  end
 end
 local rev=F.copy(s);rev.deck={};for i=#s.deck,1,-1 do rev.deck[#rev.deck+1]=s.deck[i]end;F.population(rev)
 local again,_,same=run(rev,incumbent(rev))
 check(again and m.snapshot.fingerprint(d.candidates)==m.snapshot.fingerprint(same.candidates),'common worlds ignore unseen deck order')
 local _,_,same2=run(s,incumbent(s));check(m.snapshot.fingerprint(d)==m.snapshot.fingerprint(same2),'repeat is deterministic')
end
-- An inferior incumbent cannot manufacture a reason to consume: include the
-- complete greedy current-play hold policy, with its real continuation.
do
 local s=state();s.blind.chips=750;local p=m.scoring.score(s,{1,2});p.indices={1,2}
 local r,_,d=run(s,{kind='play',play=p})
 check(not r and d.complete and d.candidates[2].probability==1 and d.candidates[1].probability<1,'stronger hold plan prevents unnecessary Planet use')
 check(d.consumable_offers[1].no_use_probability==1,'cost comparison uses best compared hold, not weak incumbent')
 for _,world in ipairs(d.candidates[3].worlds)do check(table.concat(world.first_indices,',')=='1,2','use keeps exactly the actual weak incumbent indices')end
end
do
 local s=state();local expensive=setmetatable({preservation_cost=function()return 100,'manufactured expensive source',true end},{__index=m.strategy})
 local r,_,d=run(s,incumbent(s),nil,{strategy=expensive})
 check(not r and d.complete and d.candidates[3].probability==1,'complete apparent survival gain still respects preservation cost')
 check(d.consumable_offers[1].required_uplift==1.15,'explicit inventory and extra action conversion remains unchanged')
 s.used_vouchers={v_observatory=true}
 r,_,d=run(s,incumbent(s))
 check(not r and d.complete and d.candidates[1].probability==1,'retained Observatory Planet already clears over two hands')
 check(d.candidates[1].worlds[1].first_score==1026 and d.candidates[3].worlds[1].first_score==774,'use loses held Observatory factor instead of carrying it forward')
 local p=state();p.consumeables[1].key='c_pluto';p.consumeables[1].name='Pluto';p.consumeables[1].ability.name='Pluto';p.consumeables[1].ability.consumeable.hand_type='High Card'
 r,_,d=run(p,incumbent(p))
 check(not r and d.complete and d.consumable_offers[1].uplift==0,'unhelpful hand-type upgrade cannot replace action')
end
do
 local s=state();local other=F.copy(s.consumeables[1]);other.id='second-uranus451';other.edition=nil;s.consumeables[2]=other
 local r,_,d=run(s,incumbent(s))
 check(r and d.complete and d.first_actions==4,'both physical Planet uses compared with two holds')
 for index=1,2 do
  local after=assert(m.consumables.apply(s,index,{}))
  check(#after.consumeables==1 and after.consumeables[1].id==s.consumeables[3-index].id,'exact physical retained source identity')
  check(d.consumable_offers[index].capacity_after==(index==1 and 2 or 3),'Negative capacity follows exact consumed edition')
  check(not d.consumable_offers[index].protected_last_source,'another usable identical source remains')
 end
 s=state();s.jokers={F.j('j_perkeo'),F.j('j_brainstorm'),F.j('j_yorick')};s.jokers[3].ability.x_mult=3
 r,_,d=run(s,incumbent(s));check(d.complete and d.consumable_offers[1].protected_last_source,'Perkeo-copy row has exact supported transitions and charged source')
 local simple=state();local after=assert(m.consumables.apply(simple,1,{}));local cost=m.strategy.preservation_cost(simple,after,1)
 check(d.consumable_offers[1].inventory_cost>cost,'copying Perkeo increases actual future-source loss')
 s=state();s.jokers={F.j('j_perkeo'),F.j('j_blueprint'),F.j('j_yorick')};s.jokers[3].ability.x_mult=3;s.blind.chips=3900
 r,_,d=run(s,incumbent(s));check(r and d.complete and d.candidates[3].worlds[1].first_score==2322,'Blueprint copies Yorick in exact first-play score')
end
-- Scope and visibility rejection happen before any decision work.
do
 for _,area in ipairs({'hand','deck','jokers','consumeables'})do
  for _,flag in ipairs({'unknown','identity_unknown','identity_redacted','concealed','getting_sliced'})do
   local s=state();local p=incumbent(s);s[area][1][flag]=true
   local r,w,d=run(s,p);check(not r and w==0 and not d.complete,area..' '..flag..' declines before work')
  end
 end
 for _,area in ipairs({'hand','jokers','consumeables'})do
  for _,flag in ipairs({'face_down','facing'})do
   local s=state();local p=incumbent(s);s[area][1][flag]=flag=='facing' and 'back' or true
   local r,w=run(s,p);check(not r and w==0,'unobserved area back cannot enter comparison')
  end
 end
 local s=state();for _,c in ipairs(s.deck)do c.face_down=true;c.facing='back'end
 local r,_,d=run(s,incumbent(s));check(r and d.complete,'deck backs retain known public composition, not draw order')
 for _,alter in ipairs({function(s)s.discards_left=nil end,function(s)s.discards_left='0'end,
   function(s)s.hands_left=1 end,function(s)s.teacher_profile='other'end,
   function(s)s.hand_size=9 end,function(s)s.hand_size=0/0 end,function(s)s.current_round.discards_left=1 end,
   function(s)s.consumeables[1].key='c_black_hole'end,function(s)s.deck[1].id=s.hand[1].id end,
   function(s)s.hand[1].id=1;s.deck[1].id='1'end,function(s)s.deck[1].id={}end,
   function(s)s.hand_size=0 end,function(s)s.hand_size=4.5 end,function(s)s.current_round.hands_left=3 end})do
  s=state();local p=incumbent(s);alter(s);local r,w=run(s,p);check(not r and w==0,'out-of-scope state adds no comparison')
 end
 s=state();s.blind.chips=600;local r,w=run(s,incumbent(s));check(not r and w==0,'immediate supported clear preserved')
 for _,field in ipairs({'fast_clear','consumable','ordering','hand_ordering','boss_rescue','mixed_rescue','growth'})do
  s=state();local p=incumbent(s);p[field]={};r,w=run(s,p);check(not r and w==0,'existing '..field..' remains primary')
 end
 for _,action in ipairs({{kind='use',index=1},{kind='play',indices={1,2}}})do
  s=state();local p=incumbent(s);p.action=action;r,w=run(s,p);check(not r and w==0,'unmatched incumbent action cannot silently change first play')
 end
end
-- Unsupported metadata/late worlds and budget cuts invalidate every branch.
do
 local s=state();s.consumeables[1].ability.consumeable.hand_type='Pair'
 local r,_,d=run(s,incumbent(s));check(not r and not d.complete,'modified Planet rejected by actual use contract')
 s=state();s.blind.key='bl_fish';s.blind.name='The Fish'
 r,_,d=run(s,incumbent(s));check(not r and not d.complete,'concealed future Fish cannot be scored as public')
 s=state();s.consumeables[2]=F.copy(s.consumeables[1]);s.consumeables[2].id='second451'
 s.consumeables[3]=F.copy(s.consumeables[1]);s.consumeables[3].id='third451'
 r,_,d=run(s,incumbent(s));check(not r and not d.complete and d.consumable_scope_declined,'third eligible source declines whole family, not inventory-prefix shortlist')
 s=state();local calls=0;local broken=setmetatable({score=function(...)
  local p=m.scoring.score(...);calls=calls+1;if calls==17 then p.uncertain=true end;return p end},{__index=m.scoring})
 r,_,d=run(s,incumbent(s),nil,{scoring=broken});check(not r and not d.complete,'uncertain future score aborts all paired comparisons')
 local transitions=0;local late=setmetatable({after_play=function(...)
  transitions=transitions+1;if transitions==8 then return nil,'manufactured late transition failure'end
  return m.scoring.after_play(...)end},{__index=m.scoring})
 r,_,d=run(s,incumbent(s),nil,{scoring=late})
 check(not r and not d.complete and d.completed_outer==2,'third-world unsupported transition invalidates completed paired prefix')
 local _,full=run(s,incumbent(s))
 for _,cap in ipairs({0,14,16,full-1})do
  local r,w,d=run(s,incumbent(s),{max_evaluations=cap})
  check(not r and not d.complete and w==cap,'exhaustion never authorizes a partial comparison')
 end
 r,_,d=run(s,incumbent(s),{max_evaluations=full});check(r and d.complete,'exact complete-work allowance admits')
end
do
 local s=state();local seen={};local paired=setmetatable({fill=function(...)
  local args={...};local next_state,why=m.sampled_outcomes.fill(...)
  if next_state then
   local ids={};for _,c in ipairs(next_state.hand)do ids[#ids+1]=c.id end
   local key=args[5]..':'..args[6];seen[key]=seen[key]or{}
   seen[key][#seen[key]+1]=table.concat(ids,',')
  end
  return next_state,why end},{__index=m.sampled_outcomes})
 local r,_,d=run(s,incumbent(s),nil,{sampled_outcomes=paired});local worlds=0
 for _,receipts in pairs(seen)do
  worlds=worlds+1;check(#receipts==3 and receipts[1]==receipts[2] and receipts[2]==receipts[3],'all compared branches get identical sorted refill for same physical first play')
 end
 check(r and d.complete and worlds==4,'exactly four public draw worlds, never branch-dependent random streams')
 s=state();s.hand[1].key='m_glass';s.hand[1].enhancement='m_glass';s.hand[1].ability.effect='Glass Card';s.hand[1].ability.name='Glass Card';s.hand[1].ability.x_mult=2;s.hand[1].ability.extra=4
 s.blind.chips=2400;F.population(s);r,_,d=run(s,incumbent(s))
 check(d.complete and d.candidates[1].population_loss>0,'Glass remains charged and uses supported sampled destruction transition')
 s=state();s.hand[1].enhancement='m_custom_unknown';F.population(s)
 r,_,d=run(s,incumbent(s));check(not r and not d.complete,'unknown scoring effect invalidates entire family')
end
-- Eight-card support and real arbitration, not direct specialist output only.
do
 local s=state();s.hand_size=8
 for i,r in ipairs({14,11,7,2})do s.hand[#s.hand+1]=card('spare451:'..i,r,i%2==0 and 'Spades'or'Diamonds',i/300)end
 F.population(s);local r,w,d=run(s,incumbent(s))
 check(d.complete and w<=12000 and d.completed_outer==4,'eight-card complete family stays inside specialist cap')
 s=state();local hash=m.snapshot.fingerprint(s)
 local result=m.decision.run(s,m,nil,{prepared_scoring=false,search={max_evaluations=140000}})
 check(result.action and result.action.kind=='use' and result.action.index==1 and result.two_hand_finish,'real Decision selects specialized owned use after ordinary last-source retention')
 check(result.two_hand_finish_diagnostics.complete and result.evaluations<=140000,'Decision complete comparison respects aggregate bound')
 check(m.snapshot.fingerprint(s)==hash,'Decision keeps snapshot pure')
 print('Planet finish451 Decision work: '..result.evaluations..'; eight-card specialist work: '..w)
end
print('Planet finish451: '..n..' manufactured assertions passed')
