-- Manufactured adapter integration only; no captured game or experiment lease.
local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local Adapter=dofile('tools/advisor_eval/continuation_adapter.lua')
Adapter.evidence=dofile('tools/advisor_eval/continuation_evidence.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function state(duplicate)
 local s=F.state();s.hand_size=5;s.hand={};s.deck={};s.hands_left=3
 for i,r in ipairs({2,11,11,7,9})do s.hand[i]=F.card('acorn:h'..i,r,'Clubs')end
 for i,r in ipairs({3,4,5,6,8,10})do s.deck[i]=F.card('acorn:d'..i,r,'Hearts')end
 s.hands={['High Card']={chips=5,mult=1,level=1,played=0},Pair={chips=10,mult=2,level=1,played=0}}
 s.blind={key='bl_final_acorn',name='Amber Acorn',boss=true,chips=1000000000}
 local row={F.joker('j_yorick','Yorick',{extra={xmult=1,discards=23},x_mult=2,yorick_discards=2}),
  F.joker('j_green_joker','Green Joker',{extra={hand_add=1,discard_sub=1},mult=5}),
  F.joker('j_hit_the_road','Hit the Road',{extra=0.5,x_mult=1,effect='Jack Discard Effect'}),
  F.joker('j_burnt','Burnt Joker',{extra=4}),F.joker('j_blueprint','Blueprint',{effect='Copycat'}),
  F.joker('j_brainstorm','Brainstorm',{effect='Copycat'})}
 if duplicate then row={F.joker('j_perkeo','Perkeo',{}),F.joker('j_perkeo','Perkeo',{}),row[1]}end
 s.public_joker_belief=assert(A.acorn_belief.start(row,'invented438',{public_before_shuffle=true}))
 s.jokers={};for i=1,#row do s.jokers[i]=setmetatable({}, {__index=function()error('Concealed payload read')end})end
 F.population(s);return s
end
local function input(s,seed,cap)
 local ids={};for i,c in ipairs(s.deck)do ids[i]=c.id end
 return {mode='continuation',policy_first=true,snapshot=s,world_order=ids,world_seed=seed,world=1,
  action_cap=cap or 4,sorting='rank',case='manufactured_acorn438',role='policy'}
end
for _,seed in ipairs({438,439,440,441})do
 local s=state();local calls=0;local public={}
 local modules=setmetatable({decision={run=function(t)
  calls=calls+1;public[calls]=F.copy(t)
  check(t.world_seed==nil and t.world_order==nil,'No private random input enters policy')
  check(t.public_joker_belief.state_valid and #t.public_joker_belief.worlds==720,'Complete conservative public worlds persist')
  for _,j in ipairs(t.jokers)do check(j.face_down and j.key==nil and j.id==nil and j.ability==nil,'Physical row never enters policy')end
  local ix={}
  if calls==1 then for i,c in ipairs(t.hand)do if c.rank==2 then ix={i}end end
  elseif calls==2 then for i,c in ipairs(t.hand)do if c.rank==11 then ix[#ix+1]=i end end
  elseif calls==3 then return {action={kind='reorder_jokers',order={2,3,4,5,6,1}},evaluations=0}
  else ix={1}end
  return {action={kind=calls==2 and 'discard'or 'play',indices=ix,area='hand'},evaluations=0}
 end}},{__index=A})
 local r=Adapter.run(modules,input(s,seed))
 check(r.status=='action_cap'and calls==4,'Qualified play/discard/reorder/play sequence completes')
 check(r.discards==1 and r.cards_discarded==2 and r.plays==2,'Completed actions counted exactly once')
 check(r.remaining_discards==2 and r.resources.hands_left==1 and r.resources.population==11,'Physical resources conserved')
 for _,j in ipairs(public[3].public_joker_belief.inventory)do
  if j.key=='j_yorick'then check(j.ability.x_mult==3 and j.ability.yorick_discards==23,'Physical Yorick grows once regardless of copies')end
  if j.key=='j_hit_the_road'then check(j.ability.x_mult==2,'Two visible Jacks advance Road exactly once each')end
  if j.key=='j_green_joker'then check(j.ability.mult==5,'Green play and discard effects cancel')end
 end
 check(public[3].hands.Pair.level>=2 and public[3].hands.Pair.level<=4,'Burnt and actual copied targets update public hand level')
 check(public[2].hands['High Card'].played==1 and public[2].hands_left==2,'First play hand history reaches subsequent policy')
 check(public[4].public_joker_belief.revision==3,'Reorder advances same public belief once')
 check(not r.acorn.popup_filtering and not r.acorn.private_order_exported,'Missing popup refinement disclosed')
 local encoded=A.player_journal.encode(r)
 check(not encoded:find('private%-acorn:')and not encoded:find('acorn%-order'),'Private ordinal/order not exported in receipts')
end
local duplicate=state(true);local calls=0
local m=setmetatable({decision={run=function(s)calls=calls+1;return {action={kind='discard',indices={1,2}},evaluations=0}end}},{__index=A})
local r=Adapter.run(m,input(duplicate,438,1))
check(r.status=='action_cap'and calls==1 and r.cards_discarded==2,'Equal public inventory entries retain representative physical ordinals')
local bad=state();bad.public_joker_belief.state_valid=false
check(Adapter.run(m,input(bad,438,1)).status=='unsupported','Invalid belief remains unsupported')
for _,size in ipairs({0,5,7})do
 local mismatch=state();mismatch.jokers={}
 for i=1,size do mismatch.jokers[i]=setmetatable({}, {__index=function()error('Hidden count check payload read')end})end
 local before=calls;local stopped=Adapter.run(m,input(mismatch,438,1))
 check(stopped.status=='unsupported'and stopped.reason:find('slot count'),'Missing or stale public slot count is rejected')
 check(calls==before,'Count mismatch never reaches policy or physical transitions')
end
local uses=setmetatable({decision={run=function(s)return {action={kind='use',area='consumeables',index=1},evaluations=0}end}},{__index=A})
local used=Adapter.run(uses,input(state(),438,1));check(used.status=='unsupported'and used.reason:find('consumable'),'Unqualified Acorn consumable transition is explicit')
local divergence=setmetatable({scoring=setmetatable({after_discard=function(s,ix)
 local t,e=A.scoring.after_discard(s,ix);t.jokers[1].ability.extra_value=999;return t,e
end},{__index=A})},{__index=m})
local diverged=Adapter.run(divergence,input(state(),438,1))
check(diverged.status=='unsupported'and diverged.reason:find('disagrees'),'Private/public ability disagreement stops certification')
local unsupported=state(true)
unsupported.public_joker_belief=assert(A.acorn_belief.start({F.joker('j_dna','DNA',{})},'inventedDNA',{public_before_shuffle=true}))
unsupported.jokers={setmetatable({}, {__index=function()error('Hidden DNA read')end})}
local stopped=Adapter.run(m,input(unsupported,438,1))
check(stopped.status=='unsupported'and stopped.cards_discarded==0,'Unqualified population-changing family is not treated as inert')
-- One actual public-belief Decision exercises production wiring and stays bounded.
local live=state(true);live.hand={live.hand[1],live.hand[2]};live.hand_size=2;live.blind.chips=1;F.population(live)
local actual=Adapter.run(A,input(live,438,1))
check(actual.status=='action_cap'and actual.steps[1].action.kind=='discard'and actual.score_evaluations<=140000,
 'Actual Decision uses available discard through the qualified private transition')
live.discards_left=0
local clear=Adapter.run(A,input(live,438,1))
check(clear.status=='supported_clear'and clear.score_evaluations<=140000,
 'Actual Decision with exhausted discards clears through the qualified private transition')
print('Acorn adapter438: '..checks..' checks passed')
