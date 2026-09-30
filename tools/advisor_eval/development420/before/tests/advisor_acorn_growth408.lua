-- Invented public inventories: no game source, captured state or concealed lookup.
local p='Brainstorm/Advisor/'
local B=dofile(p..'acorn_belief.lua');local O=dofile(p..'acorn_ordering.lua')
local D=dofile(p..'decision.lua');local S=dofile(p..'scoring.lua');local Snap=dofile(p..'snapshot.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function j(k,n,a)a=a or {};a.name=n;a.set='Joker';return {key=k,ability=a,blueprint_compat=true}end
local function green(v)return j('j_green_joker','Green Joker',{mult=v,extra={hand_add=1,discard_sub=1}})end
local function misprint()return j('j_misprint','Misprint',{effect='Random Mult',extra={min=0,max=23}})end
local function state(js)
  local s={phase='hand',hands_left=4,discards_left=3,hand_limit=5,hand_size=5,chips=0,dollars=20,
    blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000},hands={},deck={},playing_cards={},consumeables={},
    modifiers={},probabilities={normal=1},hand={},jokers={},public_joker_belief=assert(B.start(js,'invented408',{public_before_shuffle=true}))}
  for i=1,5 do s.hand[i]={id='p'..i,rank=i+2,nominal=i+2,suit='Clubs',enhancement='c_base',ability={}} end
  for i=1,#js do s.jokers[i]=setmetatable({face_down=true},{__index=function()error('concealed identity read')end}) end
  return s
end
local function modules(score)return {acorn_belief=B,acorn_ordering=O,scoring=score or S}end
for _,v in ipairs({0,1,10}) do for count=1,5 do for _,debuff in ipairs({false,true}) do
  local g=green(v);g.debuff=debuff
  local s=state({g,j('j_blueprint','Blueprint'),j('j_brainstorm','Brainstorm'),
    j('j_yorick','Yorick',{x_mult=2,yorick_discards=2,extra={discards=5,xmult=1}})})
  local b=s.public_joker_belief;local prior=Snap.fingerprint(b)
  local after=assert(B.advance_public(b,{epoch=b.epoch,kind='discard',discarded_count=count,observed_complete=true}))
  check(after.state_valid,'Qualified growth remains valid')
  for n,w in ipairs(b.worlds) do
    local raw=Snap.copy(s);raw.jokers={};local indices={}
    for i=1,count do indices[i]=i end
    for i,x in ipairs(w) do raw.jokers[i]=Snap.copy(b.inventory[x]) end
    local exact=assert(S.after_discard(raw,indices))
    for i,x in ipairs(w) do check(Snap.fingerprint(exact.jokers[i].ability)==Snap.fingerprint(after.inventory[x].ability),'Physical Green/Yorick transition matches scoring in every copied order') end
  end
  check(Snap.fingerprint(b)==prior,'Pure transition')
end end end
do
  local s=state({green(10),j('j_blueprint','Blueprint'),j('j_brainstorm','Brainstorm')})
  local b=s.public_joker_belief
  for slot=1,3 do
    local observed=B.observe(b,{epoch=b.epoch,type='rendered_status',phase='play',qualified_render=true,slot=slot,channel='mult',amount=11,text='+11 Mult'})
    check(observed.supported and #observed.worlds>0,'Early increment popup remains compatible with physical/copy routes')
    local after=B.advance_public(observed,{epoch=b.epoch,kind='play',observed_complete=true})
    s.public_joker_belief=after
    for _,c in ipairs(after.inventory) do if c.key=='j_green_joker' then check(c.ability.mult==11,'Physical play growth once') end end
    local result=D.run(s,modules())
    check(result.action and result.acorn_diagnostics.complete,'Next decision supports advanced Green')
  end
  check(not B.advance_public(b,{epoch='stale',kind='play',observed_complete=true}),'Stale epoch rejected')
  check(not B.advance_public(b,{epoch=b.epoch,kind='play',observed_complete=false}),'Unsettled action rejected')
end
do
  local s=state({misprint(),j('j_blackboard','Blackboard',{extra=3}),j('j_blueprint','Blueprint')})
  s.hand={s.hand[1]};local floor,mean=0,0
  local watched=setmetatable({lower_bound=function(a,b)floor=floor+1;return S.lower_bound(a,b)end,
    score=function()mean=mean+1;error('No random-mean probe before floor')end},{__index=S})
  local result=D.run(s,modules(watched),nil,{acorn_belief={max_evaluations=6,max_order_evaluations=0}})
  check(result.action and result.acorn_diagnostics.complete,'Misprint without Lucky reaches production decision')
  check(floor==result.evaluations and mean==0 and floor==6,'Each complete world charged once at floor')
  local a,n,d=O.suggest(s,s.public_joker_belief,watched,B,{max_evaluations=5,max_order_evaluations=0})
  check(not a and n<=5 and not d.complete,'Cap minus one publishes no partial action')
  local next_b=B.advance_public(s.public_joker_belief,{epoch='invented408',kind='play',observed_complete=true})
  check(next_b.state_valid,'Canonical Misprint/Blackboard continuity')
  s.public_joker_belief=next_b;check(D.run(s,modules()).action,'Next play remains supported')
end
for _,bad in ipairs({green(1),misprint(),j('j_blackboard','Blackboard',{extra=3})}) do
  bad.ability.custom=true
  for _,debuff in ipairs({false,true}) do
    bad.debuff=debuff;local s=state({bad});local calls=0
    local a,n,d=O.suggest(s,s.public_joker_belief,{score=function()calls=calls+1 end},B)
    check(not a and calls==0 and not d.complete,'Modified form rejected before any scoring, including debuffed')
    check(not B.advance_public(s.public_joker_belief,{epoch='invented408',kind='play',observed_complete=true}).state_valid,'Modified continuity rejected')
  end
end
print('advisor_acorn_growth408: '..checks..' checks passed')
for _,edition in ipairs({{custom_effect=true},{holo=true,type='foil'},{holo=true,mult=11}}) do
  local c=misprint();c.edition=edition;local s=state({c})
  check(not D.run(s,modules()).action,'Custom/contradictory remembered Joker edition cannot reach an action')
  check(not B.advance_public(s.public_joker_belief,{epoch='invented408',kind='play',observed_complete=true}).state_valid,'Unknown Joker edition cannot continue')
end
local scores={}
for _,edition in ipairs({{holo=true,type='holo',mult=10},{type='holo'},'holo'}) do
  local c=misprint();c.edition=edition;local s=state({c});s.hand={s.hand[1]}
  local r=D.run(s,modules());check(r.action and r.acorn_diagnostics.complete,'Canonical remembered edition remains supported')
  scores[#scores+1]=r.play.score
end
check(scores[1]==scores[2] and scores[2]==scores[3],'Equivalent remembered Joker edition representations yield identical floors')
print('advisor_acorn_editions408: '..checks..' checks passed')
for _,edition in ipairs({{holo=true,type='holo',mult=10},{type='holo'},'holo'}) do
  local c=j('j_joker','Joker',{mult=4});c.edition=edition
  local b=assert(B.start({c},'popup408',{public_before_shuffle=true}))
  local seen=B.observe(b,{epoch=b.epoch,type='rendered_status',phase='play',qualified_render=true,
    slot=1,channel='mult',amount=10,text='+10 Mult'})
  check(seen.supported and #seen.worlds==1,'Canonical Holo popup retains true ordinary-Joker world for every representation')
  local advanced=B.advance_public(seen,{epoch=b.epoch,kind='play',observed_complete=true})
  check(advanced.state_valid,'Equivalent popup representation preserves next-action continuity')
end
print('advisor_acorn_popup408: '..checks..' checks passed')
