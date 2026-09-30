-- Manufactured cards and complete public populations, never captured replay.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH433_PATH then m.growth=dofile(GROWTH433_PATH) end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local centers={};for _,j in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do centers[j.key]=j end
local function joker(key)
 local c=centers[key];local j=F.joker(key,c.name,F.copy(c.ability));j.ability.effect=c.ability.effect
 j.blueprint_compat=c.blueprint_compat;return j
end
local function state(key)
 local s=F.state(false);s.blind={key='bl_big',name='Big Blind',chips=600};s.hand_size=8
 s.hand={};s.deck={};s.consumeables={};s.dollars=30
 for i,r in ipairs({13,13,2,4,6,8,10,12})do s.hand[i]=F.card('portfolio:h'..i,r,'Clubs',i==1 and 'm_mult' or nil)end
 for i=1,12 do s.deck[i]=F.card('portfolio:d'..i,2+i%8,'Hearts')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),joker(key)}
 s.hands={Pair={chips=30,mult=5,level=3,l_chips=15,l_mult=1,played=9},
  ['High Card']={chips=5,mult=1,level=1,l_chips=10,l_mult=1,played=0}}
 F.population(s);return s
end
local function clear(s,indices)local c=m.scoring.lower_bound(s,indices);c.indices=indices;return c end
-- A thin singleton clears before draws but not after Blue Joker's real debit.
do
 local s=state('j_blue_joker');local one=clear(s,{1});local pair=clear(s,{1,2});s.blind.chips=one.score
 local old=m.growth.suggest(s,m,one,{exhaust_discards=true,max_evaluations=12})
 check(not old,'thin singleton fails all real replacement-count debits')
 if EXPECT_BASELINE433 then check(not m.growth.suggest_portfolio,'baseline has no bounded fallback');print('Baseline433 discard portfolio gap reproduced');return end
 local before=m.snapshot.fingerprint(s)
 local r,work,d,anchor,selection=m.growth.suggest_portfolio(s,m,one,{one,pair},{exhaust_discards=true,max_evaluations=12})
 check(r and r.action.kind=='discard' and #r.action.indices==5,'strong Pair unlocks full five')
 check(anchor==pair and selection.portfolio_attempts==2,'second already-scored anchor actually tested')
 check(work<=12 and work==d.evaluations,'single shared allowance')
 check(r.growth.blue_joker_draw_cost.draws==5,'all five replacement draws debited')
 check(m.snapshot.fingerprint(s)==before,'no observed-state mutation')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 for i=1,5 do after.hand[#after.hand+1]=table.remove(after.deck)end
 local actual=m.scoring.lower_bound(after,r.play.indices)
 check(actual.score>=r.play.score and r.play.score>=s.blind.chips,'physical draw endpoint independent of forecast')
 local receipt=dofile('Brainstorm/Advisor/player_journal.lua').compact_yorick_review({growth_anchor_diagnostics=selection})
 check(receipt.anchor.portfolio_attempts==2,'bounded alternate-anchor receipt reaches journal')
 local decision=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}})
 check(decision.action.kind=='discard' and #decision.action.indices==5,'real Decision routes alternatives through full-five fallback')
 check((decision.discard_preference_work or 0)<=12 and decision.evaluations<=140000,'Decision shares original limits')
 for _,field in ipairs({'uncertain','population_cost','glass_loss','arm_cost','finish_reward'})do
  local bad=F.copy(pair);bad[field]=field=='uncertain' and true or field=='finish_reward' and -1 or 1
  local rejected=m.growth.suggest_portfolio(s,m,one,{bad},{exhaust_discards=true,max_evaluations=12})
  check(not rejected,'no fallback bypass for '..field)
 end
 local r0,w0=m.growth.suggest_portfolio(s,m,one,{pair},{exhaust_discards=true,max_evaluations=0})
 check(not r0 and w0==0,'zero work cannot mint a fallback proof')
end
-- Qualify exact vanilla families only. Independently check both scoring orders
-- after every five-card subset of a six-card public replacement population.
for _,key in ipairs({'j_abstract','j_bull','j_blue_joker','j_certificate','j_stuntman','j_faceless','j_odd_todd','j_scholar'})do
 for _,copied in ipairs({false,true})do
  local s=state(key);s.deck={}
  for i,r in ipairs({2,3,4,11,13,14})do s.deck[i]=F.card('family:'..i,r,'Hearts',i==2 and 'm_steel' or nil)end
  if copied then s.jokers={F.j('j_blueprint'),joker(key),F.j('j_yorick'),F.j('j_perkeo')}end
  F.population(s);local c=clear(s,{1,2});s.blind.chips=math.min(500,c.score)
  local r,work=m.growth.suggest(s,m,c,{exhaust_discards=true,max_evaluations=12,skip_singleton_probes=true})
  check(r and #r.action.indices==5,'canonical family full five '..key..' copied='..tostring(copied))
  check(work<=12,'family budget')
  local after=assert(m.scoring.after_discard(s,r.action.indices))
  for excluded=1,6 do
   local future=F.copy(after);future.deck={F.copy(s.deck[excluded])}
   for i,c in ipairs(s.deck)do if i~=excluded then future.hand[#future.hand+1]=F.copy(c)end end
   F.permutations(r.play.indices,function(order)
    local actual=m.scoring.lower_bound(future,order)
    check(actual.legal and not actual.uncertain and actual.score>=r.play.score,'complete family endpoint '..key)
   end)
  end
  -- The same name never qualifies arbitrary coefficients or unknown operations.
  local bad=F.copy(s);local j=bad.jokers[copied and 2 or 3]
  j.ability.extra={unmodeled=-10}
  local rejected=m.growth.suggest(bad,m,c,{exhaust_discards=true,max_evaluations=12,skip_singleton_probes=true})
  check(not rejected,'reject modified family '..key)
 end
end
-- Compound rows from the supported categories still use exact real counters.
do
 local s=state('j_bull');s.jokers[4]=joker('j_faceless');s.jokers[5]=joker('j_abstract')
 s.jokers[1].ability.yorick_discards=4
 for i=3,7 do s.hand[i]=F.card('faces:'..i,11,'Hearts')end;F.population(s)
 local c=clear(s,{1,2});local r=m.growth.suggest(s,m,c,{exhaust_discards=true,skip_singleton_probes=true})
 check(r and #r.action.indices==5,'Faceless income and Yorick threshold coexist')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 check(after.dollars>s.dollars and after.jokers[1].ability.x_mult==5,'actual discard pays income and advances physical growth')
 check(after.consumeables==nil or #after.consumeables==0,'no imaginary resource creation')
end
-- A seven-call residual allowance must retain the previously supported second
-- full-five variant. Chad needs both first-card rotations for each variant;
-- splitting seven in half would strand both anchors partway through a family.
do
 local s=state('j_blue_joker');s.jokers={F.j('j_yorick'),F.j('j_hanging_chad')}
 s.hand[2]=F.card('portfolio:h2',13,'Clubs','m_mult')
 s.hand[3]=F.card('retained:steel',2,'Hearts','m_steel')
 for i=4,8 do s.hand[i]=F.card('spare:'..i,2*(i-3),'Clubs')end
 s.hand[4]=F.card('spare:stone',2,'Clubs','m_stone')
 F.population(s);local pair=clear(s,{1,2});s.blind.chips=pair.score*0.9
 local old,work,why=m.growth.suggest(s,m,pair,{exhaust_discards=true,max_evaluations=7})
 print('DEBUG',pair.score,work,old and #old.action.indices,table.concat(why.reasons,'; ')); check(old and #old.action.indices==5 and work<=7,'existing complete second five-card proof fits seven')
 for _,i in ipairs(old.action.indices)do check(i~=3,'required held Steel retained')end
 local stronger=clear(s,{1,2,4})
 check(stronger.score>pair.score,'actual scoring Stone creates a stronger alternative')
 local r,n,d,anchor,selection=m.growth.suggest_portfolio(s,m,pair,{pair,stronger},{exhaust_discards=true,max_evaluations=7})
 check(r and #r.action.indices==5 and n<=7,'portfolio preserves prior complete first-anchor proof at residual cap')
 check(selection.portfolio_attempts==1 and anchor==pair,'real fallback exists but complete first proof retains its allowance')
end
-- A visible Faceless proof must not broaden the hidden identity-independent
-- discard contract, including when a Blueprint can reach that reward.
for _,copied in ipairs({false,true})do
 local s=state('j_faceless');s.blind={key='bl_wheel',name='The Wheel',chips=500}
 if copied then s.jokers={F.j('j_blueprint'),joker('j_faceless'),F.j('j_yorick'),F.j('j_perkeo')}end
 for i=3,8 do s.hand[i].face_down=true end;F.population(s)
 local r,work,d=m.growth.visible_retained(s,m,12)
 check(not d.hidden_discard_scope,'Faceless never earns identity-independent hidden reward scope')
 if r then for _,i in ipairs(r.action.indices)do check(i<=2,'hidden Faceless slots protected')end end
 check(work<=12,'concealed restriction preserves allowance')
end
print('Discard portfolio433: '..n..' manufactured assertions passed')

