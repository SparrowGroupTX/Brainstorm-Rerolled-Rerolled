-- Invented states only. Conditional held bonuses are never promised after draws.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH431_PATH then m.growth=dofile(GROWTH431_PATH) end
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function conditional(key)
 local j=F.joker(key,key=='j_raised_fist' and 'Raised Fist' or 'Blackboard')
 j.ability.effect=key=='j_raised_fist' and 'Socialized Mult' or nil
 if key=='j_blackboard' then j.ability.extra=3 end
 return j
end
local function state(key)
 local s=F.state(false);s.blind={key='bl_big',name='Big Blind',chips=900}
 s.hand={};s.deck={};s.consumeables={};s.hand_size=8
 for i,r in ipairs({13,13,2,4,6,8,10,12})do s.hand[i]=F.card('held431:h'..i,r,'Clubs',i==1 and 'm_mult' or nil)end
 for i=1,24 do s.deck[i]=F.card('held431:d'..i,2+i%8,'Hearts')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),conditional(key)}
 s.hands={Pair={chips=30,mult=5,level=3,l_chips=15,l_mult=1,played=9},
  ['High Card']={chips=5,mult=1,level=1,l_chips=10,l_mult=1,played=0}}
 F.population(s);return s
end
local function clear(s,indices)
 indices=indices or {1,2};local c=m.scoring.lower_bound(s,indices);c.indices=indices;return c
end
local function run(s,c,cap,modules)
 local before=m.snapshot.fingerprint(s)
 local r,n,d=m.growth.suggest(s,modules or m,c or clear(s),{exhaust_discards=true,max_evaluations=cap or 12})
 check(m.snapshot.fingerprint(s)==before,'complete input preserved')
 check(n<=(cap or 12),'same growth allowance');return r,n,d
end
for _,key in ipairs({'j_raised_fist','j_blackboard'})do
 local s=state(key);local c=clear(s);local r,n,d=run(s,c)
 if EXPECT_BASELINE431 then
  check(not r and table.concat(d.reasons,' '):find('Replacement draws',1,true),'baseline conditional-held rejection')
 else
  check(r and #r.action.indices==5,'full five admitted without '..key..' bonus')
  check(r.growth.held_floor.minimum==r.play.score and r.play.score>=s.blind.chips,'conservative floor receipt')
  local receipt=dofile('Brainstorm/Advisor/player_journal.lua').compact_yorick_review({growth=r,growth_diagnostics=d})
  check(receipt.held_floor.minimum==r.play.score and receipt.held_floor.copy_routes_preserved,'public receipt')
 end
end
if EXPECT_BASELINE431 then print('Baseline431: both conditional held bonus guards reproduced');return end
-- Copy routes, editions and unfavorable replacements: independently score the
-- original physical row, not the projected proof, after real transitions.
for _,key in ipairs({'j_raised_fist','j_blackboard'})do
 for _,variant in ipairs({'plain','copy','both','steel_red','glass','polychrome','disabled_copy','holo_joker'})do
  local s=state(key)
  if variant=='copy' or variant=='disabled_copy' then
   s.jokers={F.j('j_blueprint'),conditional(key),F.j('j_yorick'),F.j('j_perkeo'),F.j('j_brainstorm')}
   if variant=='disabled_copy' then s.jokers[2].blueprint_compat=false end
  elseif variant=='both' then s.jokers[4]=conditional(key=='j_raised_fist' and 'j_blackboard' or 'j_raised_fist')
  elseif variant=='steel_red' then s.hand[8]=F.card('held431:steel',12,'Clubs','m_steel');s.hand[8].seal='Red'
  elseif variant=='glass' then s.hand[1]=F.card('held431:glass',13,'Clubs','m_glass');s.hand[2]=F.card('held431:mult',13,'Clubs','m_mult')
  elseif variant=='polychrome' then s.hand[2].edition={polychrome=true,x_mult=1.5,type='polychrome'}
  elseif variant=='holo_joker' then s.jokers[3].edition={holo=true,mult=10,type='holo'} end
  F.population(s);local c=clear(s);local original=m.scoring.score(s,c.indices).score
  local r=run(s,c);check(r and #r.action.indices==5,'qualified variant '..key..'/'..variant)
  check(m.scoring.score(s,c.indices).score==original,'original scoring unaffected by private row')
  local after=assert(m.scoring.after_discard(s,r.action.indices))
  check(after.jokers[1].key==s.jokers[1].key and #after.jokers==#s.jokers,'real transition retains actual row')
  for _,draw in ipairs({'red_low','red_debuffed','black_high','steel_red'})do
   local future=F.copy(after)
   while #future.hand<8 do
    local i=#future.hand+1;local card=table.remove(future.deck)
    -- These are independent invented alternative populations, not predicted draws.
    card=F.card(card.id,draw=='black_high' and 13 or 2,draw=='black_high' and 'Clubs' or 'Hearts',draw=='steel_red' and 'm_steel' or nil)
    if draw=='red_debuffed' then card.debuff=true end
    if draw=='steel_red' then card.seal='Red' end
    future.hand[i]=card
   end
   F.population(future)
   F.permutations(r.play.indices,function(order)
    local actual=m.scoring.lower_bound(future,order)
    check(actual.legal and not actual.uncertain and actual.score>=r.play.score,'adverse draw/order stays above omission floor')
   end)
  end
 end
end
-- Enumerate every five-card replacement from one small, complete invented public
-- population. Also reverse held order without moving the retained scoring pair.
for _,key in ipairs({'j_raised_fist','j_blackboard'})do
 local s=state(key);s.deck={}
 for i,rank in ipairs({2,3,4,13,14,2})do
  s.deck[i]=F.card('population431:'..i,rank,i%2==0 and 'Hearts' or 'Clubs',i==2 and 'm_steel' or nil)
 end
 s.deck[1].debuff=true;s.deck[2].seal='Red';F.population(s)
 local r=run(s);check(r and #r.action.indices==5,'complete small population admitted')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 for excluded=1,6 do
  local future=F.copy(after);future.deck={F.copy(s.deck[excluded])}
  for i,c in ipairs(s.deck)do if i~=excluded then future.hand[#future.hand+1]=F.copy(c)end end
  for reverse=1,2 do
   F.permutations(r.play.indices,function(order)
    local actual=m.scoring.lower_bound(future,order)
    check(actual.legal and not actual.uncertain and actual.score>=r.play.score,'complete public draw family covers held minima and order')
   end)
   -- Retained original indices are the first two cards in this fixture.
   for i=3,5 do future.hand[i],future.hand[11-i]=future.hand[11-i],future.hand[i]end
  end
 end
end
do
 local s=state('j_raised_fist');local cached,stats=dofile('Brainstorm/Advisor/score_cache.lua').new(m.scoring)
 local scoped=F.copy(m);scoped.scoring=cached
 local c=cached.lower_bound(s,{1,2});c.indices={1,2};local original=c.score
 local r,n=run(s,c,12,scoped)
 check(r and r.play.bound_kind=='conditional_held_bonus_floor','floor labeled separately from exact score')
 check(cached.lower_bound(s,{1,2}).score==original,'original cached route survives private projection')
 check(stats().row_builds>1 and stats().score_calls==n+2,'separate row cache identity and exact charged calls')
end
-- Decisions are refreshed after every real discard/draw, before optional Tarot.
for _,key in ipairs({'j_raised_fist','j_blackboard'})do
 local s=state(key);s.consumeables={{id='held431:tarot',key='c_heirophant',ability={name='The Hierophant',set='Tarot'}}}
 for left=3,1,-1 do
  local before=m.snapshot.fingerprint(s)
  local r=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}})
  check(r.action.kind=='discard' and #r.action.indices==5,'Decision full discard '..key..'/'..left)
  check(r.evaluations<=140000 and (r.discard_preference_work or 0)<=12,'Decision computation limits')
  check(m.snapshot.fingerprint(s)==before,'Decision purity')
  local old=s.jokers[1].ability.yorick_discards;local population=#s.playing_cards
  s=assert(m.scoring.after_discard(s,r.action.indices))
  check(s.discards_left==left-1 and s.jokers[1].ability.yorick_discards==old-5,'real counters progress')
  check(#s.consumeables==1 and #s.playing_cards==population,'Tarot and population preserved')
  while #s.hand<8 do s.hand[#s.hand+1]=table.remove(s.deck)end
 end
end
-- A clear that genuinely needs the removable bonus must not qualify.
for _,growth in ipairs({'Yorick','Burnt'})do
 local s=state('j_raised_fist');s.blind.chips=2000
 if growth=='Yorick' then s.jokers[1].ability.yorick_discards=4
 else
  s.jokers[4]=F.joker('j_burnt','Burnt Joker')
  s.hand[3]=F.card('growth431:p1',3,'Clubs');s.hand[4]=F.card('growth431:p2',3,'Hearts')
 end
 F.population(s);local c=clear(s);local r=run(s,c)
 check(r and #r.action.indices==5,'new real '..growth..' growth completes omission floor')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 if growth=='Yorick' then check(after.jokers[1].ability.x_mult==5,'physical Yorick threshold applied before projection')
 else check(after.hands.Pair.level==4,'physical first-discard Pair level applied before projection')end
 check(r.play.score>=2000,'updated endpoint, not stale pre-discard row, establishes clear')
end
for _,key in ipairs({'j_raised_fist','j_blackboard'})do
 local s=state(key);local c=clear(s);s.blind.chips=c.score
 local r=run(s,c);check(not r,'bonus-dependent clear rejected: '..key)
end
for _,case in ipairs({
 {'coefficient',function(s)s.jokers[3]=conditional('j_blackboard');s.jokers[3].ability.extra=2 end},
 {'effect',function(s)s.jokers[3].ability.effect='' end},
 {'extra',function(s)s.jokers[3].ability.extra=2 end},
 {'negative deck nominal',function(s)s.deck[1].nominal=-5 end},
 {'negative held nominal',function(s)s.hand[8].nominal=-5 end},
 {'modified held arithmetic',function(s)s.deck[1].ability.h_mult=-1 end},
 {'modified Joker arithmetic',function(s)s.jokers[3].ability.mult=-1 end},
 {'modified edition',function(s)s.jokers[3].edition={holo=true,mult=11} end},
 {'unknown row',function(s)s.jokers[3].identity_redacted=true end},
 {'unknown deck',function(s)s.deck[1].unknown=true end},
 {'redacted deck',function(s)s.deck[1].identity_redacted=true end},
 {'unknown held',function(s)s.hand[8].identity_unknown=true end},
 {'back-facing held',function(s)s.hand[8].face_down=true end},
 {'concealed deck',function(s)s.deck[1].concealed=true end},
 {'unknown Joker',function(s)s.jokers[4]=F.joker('j_mod','Unknown')end},
 {'paid discard',function(s)s.modifiers.discard_cost=1 end},
 {'Hook',function(s)s.blind.key='bl_hook';s.blind.name='The Hook'end},
 {'generic profile',function(s)s.teacher_profile=nil end}})do
 local s=state('j_raised_fist');local c=clear(s);case[2](s);F.population(s)
 local r=run(s,c);check(not r,'safety rejection: '..case[1])
end
do
 local s=state('j_raised_fist')
 for _,c in ipairs(s.deck)do c.face_down=true;c.facing='back'end
 local r=run(s);check(r and #r.action.indices==5,'ordinary deck orientation does not conceal public composition')
end
do
 local s=state('j_raised_fist')
 s.hand[1]=F.card('budget431:glass',13,'Clubs','m_glass');s.hand[2]=F.card('budget431:mult',13,'Clubs','m_mult');F.population(s)
 local c=clear(s)
 local r,n=run(s,c,2);check(not r and n==1,'leave work for proof but cannot fit complete candidate')
 local r2,n2=run(s,c,4);check(r2 and n2==4,'exact-fit singleton probes plus both order floors')
end
-- This integration declines the new proof until every public-order product is
-- qualified; one raw later-world score must never restore the omitted bonus.
do
 local s=state('j_raised_fist');local b={worlds={{1},{1}},state_valid=true,epoch=1,inventory={s.jokers[1]}}
 local belief={validate=function()return true end,qualified_values=function()return true end,copy=F.copy}
 local scoped=F.copy(m);scoped.growth={suggest=function()
  return {action={kind='discard',indices={3,4,5,6,7}},growth={held_floor={minimum=1800}}},2,{}
 end}
 local scoring={lower_bound=function()return {legal=true,reliable_bound=true,uncertain=false,score=1800}end}
 local r,n,d=m.acorn_discard.retained(s,b,{immediate_clear_all_worlds=true,action={indices={1,2}}},scoring,m.scoring,belief,scoped)
 check(not r and n==3 and d.reason:find('conditional held-floor',1,true),'Acorn product refusal retains charged work')
end
print('Held floor431: '..count..' checks passed')
