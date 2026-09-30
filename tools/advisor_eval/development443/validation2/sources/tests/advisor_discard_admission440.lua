-- Invented score surfaces isolate policy admission. Real Search/Decision and
-- physical discard transitions; never load or replay a captured run.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
local count=0;local function check(x,why)count=count+1;assert(x,why)end
local function state(key)
 local s=F.state(false);s.ante=5;s.hand_size=6;s.hand={};s.deck={};s.consumeables={}
 s.blind={key='bl_big',name='Big Blind',chips=75};s.hands_left=3;s.discards_left=3
 s.jokers={F.j('j_yorick')};s.jokers[1].ability.x_mult=6
 for i=1,6 do s.hand[i]=F.card('held440:'..i,i+2,'Clubs',key or 'c_base')end
 for i=1,8 do s.deck[i]=F.card('draw440:'..i,13,'Hearts')end
 F.population(s);return s
end
local function run(s,o)
 o=o or {};local calls,forced=0,{};local initial=m.snapshot.fingerprint(s)
 local scorer={after_discard=function(t,ix)
  local a,e=m.scoring.after_discard(t,ix)
  if a then a.discard_size440=#ix;if o.population_loss then e.population_delta=-1 end end
  return a,e
 end}
 function scorer.score(t,ix)
  calls=calls+1
  for i,c in ipairs(t.hand)do if(c.ability or{}).forced_selection then
   local have=false;for _,j in ipairs(ix)do if i==j then have=true end end
   check(have,'every evaluated Bell play includes the current forced physical card')
   if t.discard_size440 then forced[c.id]=true end
  end end
  local score=80
  if t.discard_size440 then score=o.redraw_score or(t.discard_size440==5 and o.five_fails and 20 or 80)end
  return {score=score,legal=true,uncertain=false,hand='High Card',indices=ix,scoring_indices=ix,warnings={}}
 end
 if o.continuation_loss then scorer.after_play=function(t,ix)
  local p=scorer.score(t,ix);local a=F.copy(t);a.hands_left=0;a.chips=t.discard_size440 and 0 or t.blind.chips
  return a,{},p
 end end
 local strategy={build_profile=function()return{horizon=o.final and 0 or 6,final=o.final or false}end}
 local modules={search=m.search,scoring=scorer,strategy=strategy}
 local r=m.decision.run(s,modules,nil,{prepared_scoring=false,search={samples=o.samples or 24,candidates=5,
  draw_targets=false,resource_samples=o.continuation_loss and 4 or 0,max_evaluations=o.cap or 140000,fast_clear=o.fast}})
 -- Search charges forced-card-rejected proposals before invoking the scorer.
 -- On Bell these rejected slots are still budgeted work, not missing calls.
 check(s.blind.key=='bl_final_bell'and r.evaluations>=calls or r.evaluations==calls,
  'complete score accounting '..tostring(r.evaluations)..'/'..calls)
 check(r.evaluations<=(o.cap or 140000),'caller cap')
 check(m.snapshot.fingerprint(s)==initial,'caller cards/inventory unchanged')
 return r,forced
end
for _,key in ipairs({'c_base','m_mult','m_bonus','m_glass'})do
 local s=state(key);local r=run(s,{five_fails=true})
 check(r.action.kind=='discard' and #r.action.indices==4,'largest safe four gets growth credit '..key)
 check(r.risky_yorick_clear.safe_batch_preference and not r.risky_yorick_clear.full_batch_preference,'small safe-batch exception is explicit')
 check(r.risky_yorick_clear.qualified_five_count==0,'failed five is never forced')
end
for _,edition in ipairs({'foil','holo','polychrome','Red','perma_bonus','created'})do
 local s=state('m_mult')
 for _,c in ipairs(s.hand)do
  if edition=='Red'then c.seal='Red'
  elseif edition=='perma_bonus'then c.ability.perma_bonus=20
  elseif edition=='created'then c.ability.hands_played_at_create=7;c.ability.order=2
  else c.edition=edition=='foil'and{foil=true,chips=50}or edition=='holo'and{holo=true,mult=10}or{polychrome=true,x_mult=1.5}end
 end
 local r=run(s);check(r.action.kind=='discard'and #r.action.indices==5,'canonical scoring value is not a resource veto '..edition)
end
for _,mult in ipairs({9,13,1048576})do
 local s=state('m_mult');s.jokers[1].ability.x_mult=mult;s.ante=8
 s.blind={key='bl_final_bell',name='Cerulean Bell',chips=75,boss=true};s.hand[6].ability.forced_selection=true
 local r,forced=run(s,{final=true,five_fails=true})
 check(r.action.kind=='discard'and #r.action.indices==4,'mature final Bell comparison is admitted')
 local has=false;for _,i in ipairs(r.action.indices)do has=has or i==6 end;check(has,'current forced card is really discarded')
 local n=0;for _ in pairs(forced)do n=n+1 end;check(n>1,'new Bell forced identities vary across matched worlds')
 check(r.risky_yorick_clear.mature_or_final_scope and r.risky_yorick_clear.required_fraction==1,'mature/final all-world requirement')
 local J=dofile('Brainstorm/Advisor/player_journal.lua');local receipt=J.compact_yorick_review(r)
 check(receipt.risk.safe_batch_preference and receipt.risk.mature_or_final_scope,'public final arbitration receipt')
end
local negatives={
 {'Gold',function(s)for i,c in ipairs(s.hand)do s.hand[i]=F.card(c.id,c.rank,'Clubs','m_gold')end end,{}},
 {'Steel',function(s)for i,c in ipairs(s.hand)do s.hand[i]=F.card(c.id,c.rank,'Clubs','m_steel')end end,{}},
 {'Blue',function(s)for _,c in ipairs(s.hand)do c.seal='Blue'end end,{}},
 {'Purple',function(s)for _,c in ipairs(s.hand)do c.seal='Purple'end end,{}},
 {'Gold seal',function(s)for _,c in ipairs(s.hand)do c.seal='Gold'end end,{}},
 {'modified',function(s)for _,c in ipairs(s.hand)do c.ability.h_mult=3 end end,{}},
 {'unknown field',function(s)for _,c in ipairs(s.hand)do c.ability.callback440=true end end,{}},
 {'unknown edition',function(s)for _,c in ipairs(s.hand)do c.edition={polychrome=true,x_mult=2}end end,{}},
 {'cash',function(s)s.modifiers.discard_cost=1 end,{}},
 {'population',function()end,{population_loss=true}},
 {'partial',function()end,{samples=23}},
 {'failure',function()end,{redraw_score=20}},
 {'104percent mature',function(s)s.jokers[1].ability.x_mult=13;s.blind.chips=77 end,{}},
 {'104percent final',function(s)s.blind.chips=77 end,{final=true}},
 {'explicit fast',function(s)s.jokers[1].ability.x_mult=13 end,{fast=true}},
 {'cap',function()end,{cap=100}},
 {'continuation veto',function()end,{continuation_loss=true}},
 {'outside teacher',function(s)s.teacher_profile=nil end,{}},
 {'no future horizon outside comparison',function(s)s.teacher_profile=nil end,{final=true}}}
for _,v in ipairs(negatives)do local s=state('m_mult');v[2](s);local r=run(s,v[3])
 check(r.action.kind=='play','guard remains '..v[1]);check(not r.risky_yorick_clear or not r.risky_yorick_clear.selected,'honest refusal '..v[1])
end
-- Actual scoring/Decision integration, not the manufactured arithmetic above.
-- A high level Pair and Three of a Kind avoids the Bell category-downgrade trap;
-- score margins are produced by real cards and physical copy/Joker effects.
for _,size in ipairs({6,12})do
 local A=dofile('tests/fixtures/modules436.lua');local s=state('m_mult')
 s.ante=8;s.discards_left=4;s.hand_size=size;s.blind={key='bl_final_bell',name='Cerulean Bell',chips=100,boss=true}
 for i=7,size do s.hand[i]=F.card('large440:'..i,13,'Clubs','m_mult')end
 s.hand[size].ability.forced_selection=true;s.jokers[1].ability.x_mult=13
 s.hands={['High Card']={chips=40,mult=5,level=5,played=3},Pair={chips=80,mult=8,level=6,played=8},['Three of a Kind']={chips=90,mult=9,level=5,played=4}}
 F.population(s);local before=m.snapshot.fingerprint(s);local r=A.decision.run(s,A,nil,{prepared_scoring=false})
 check(r.action.kind=='discard'and #r.action.indices==5,'actual final Bell uses five-card discard')
 check(r.risky_yorick_clear and r.risky_yorick_clear.compared and r.risky_yorick_clear.sampled_clears==24,'actual complete common-world evidence')
 check(r.evaluations<=140000 and m.snapshot.fingerprint(s)==before,'actual production budgets/immutability')
end
-- A nine-card Photograph/Chad row needs to keep five Spades. Its four neutral
-- spares can be replaced, while a five-card replacement loses the Glass Flush.
-- This exercises the reported mechanism with invented cards/levels/identities.
do
 local A=dofile('tests/fixtures/modules436.lua');local s=state();s.hand_size=9;s.hand={};s.deck={}
 local ranks={14,12,10,9,8,6,5,4,3};local flush={true,false,true,true,true,true,false,false,false}
 for i,r in ipairs(ranks)do s.hand[i]=F.card('flush440:'..i,r,flush[i]and'Spades'or'Clubs',(i==1 or i==3)and'm_glass'or'c_base')end
 for i=1,10 do s.deck[i]=F.card('future440:'..i,2+i%7,'Hearts')end
 s.jokers={F.j('j_perkeo'),F.j('j_yorick'),F.joker('j_photograph','Photograph',{extra=2}),F.j('j_hanging_chad')}
 s.jokers[2].ability.x_mult=5;s.blind={key='bl_small',name='Small Blind',debuff={},chips=1}
 F.population(s);local clear=A.scoring.lower_bound(s,{1,3,4,5,6});s.blind.chips=math.floor(clear.score*.75)
 local portfolio=A.growth.suggest_portfolio;local one_play_comparison=false
 A.growth.suggest_portfolio=function(t,mods,selected,alternatives,options)
  if options.disable_two_play then one_play_comparison=true end
  return portfolio(t,mods,selected,alternatives,options)
 end
 local r=A.decision.run(s,A,nil,{prepared_scoring=false})
 check(one_play_comparison,'sampled-short upgrade requests a one-play-only comparison')
 check(r.action.kind=='discard','actual Photograph/Chad Glass row discards before its Flush')
 check(#r.action.indices==4,'actual four spares are preferred over an unsafe five')
 check(r.risky_yorick_clear and r.risky_yorick_clear.safe_batch_preference,'actual small-batch arbitration bypasses only utility taper')
 check(r.risky_yorick_clear.sampled_clears==24 and r.evaluations<=140000,'actual strong comparison remains bounded')
end
-- The existing two-play generator remains real; only the one-play proposal is
-- controlled here. A competing two-play candidate may otherwise hide it or
-- reserve the work needed to discover it. The new caller opts out before either
-- action, not merely after receiving a two-play result.
do
 local A=dofile('tests/fixtures/modules436.lua');local R=dofile('tests/fixtures/repair416.lua')
 local s=R.state();s.hand_size=8;s.hand={};s.deck={};s.ante=6
 for i,r in ipairs({13,13,12,12,2,4,6,8})do
  s.hand[i]=R.card('competing440:'..i,r,i%2==0 and'Spades'or'Clubs',i==1 and'm_mult'or i==2 and'm_glass'or nil)
 end
 for i,r in ipairs({2,3,5,7,9,10})do s.deck[i]=R.card('competing-draw440:'..i,r,'Hearts',i==2 and'm_steel'or nil)end
 s.hands.Pair={chips=60,mult=10,level=4,played=1,played_this_round=0}
 s.jokers={R.joker('j_yorick','Yorick',{x_mult=4,yorick_discards=12,extra={discards=23,xmult=1}}),
  R.joker('j_brainstorm','Brainstorm',{effect='Copycat'}),R.joker('j_blue_joker','Blue Joker',{extra=2})}
 s.jokers[3].ability.effect=nil
 s.blind={key='bl_final_vessel',name='Violet Vessel',boss=true,chips=1,debuff={}};R.population(s)
 local p=A.scoring.score(s,{1,2});p.indices={1,2};s.blind.chips=p.score
 for _,needed in ipairs({1,8})do
  local given
  A.growth.suggest=function(t,mods,anchor,options)
   given=options.max_evaluations
   local d={reasons={},bounded_growth=true};local work=math.min(needed,given)
   if given<needed then return nil,work,d end
   return {action={kind='discard',area='hand',indices={6,7,8}},play=p,merit=0,
    growth={kind='discard',exhaust_discards=true}},work,d
  end
  local ordinary,n=A.growth.suggest_portfolio(s,A,p,{}, {exhaust_discards=true,max_evaluations=12})
  check(ordinary and ordinary.growth.two_play and #ordinary.action.indices==4,'competing real two-play result is eligible')
  check(given==6 and n<=12,'ordinary portfolio reserves bounded two-play work')
  local single,work,d=A.growth.suggest_portfolio(s,A,p,{}, {exhaust_discards=true,max_evaluations=12,disable_two_play=true})
  check(single and not single.growth.two_play and #single.action.indices==3,'one-play proposal stays visible')
  check(given==12 and work==needed and not d.retained_two_play,'no reservation or rejected two-play work consumes upgrade allowance')
 end
end
print('Discard admission440: '..count..' checks passed')
