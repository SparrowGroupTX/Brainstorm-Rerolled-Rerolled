-- Invented states only; no captured game is scored or executed.
local p='Brainstorm/Advisor/'
local F=dofile('tests/fixtures/retained418.lua')
local B=dofile(ACORN445_BASE and ACORN445_BASE..'acorn_belief.lua' or p..'acorn_belief.lua')
local O=dofile(ACORN445_BASE and ACORN445_BASE..'acorn_ordering.lua' or p..'acorn_ordering.lua')
local D=dofile(p..'decision.lua');local S=dofile(p..'scoring.lua');local Snap=dofile(p..'snapshot.lua')
local Public=dofile(p..'acorn_public.lua')
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function joker(key,size)
  if key=='j_bootstraps' then return F.joker(key,'Bootstraps',{extra={mult=2,dollars=5},effect=''}) end
  local j=F.joker(key,'Turtle Bean',{extra={h_mod=1,h_size=size or 5}});j.ability.effect=nil;j.blueprint_compat=false;return j
end
local function state(row,n)
  local s=F.state(false);s.blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000}
  s.hand={};s.deck={};s.dollars=10;s.hands_left=4;s.discards_left=3;s.hand_size=n or 3;s.hand_limit=5
  s.hands={['High Card']={chips=5,mult=1,level=1},Pair={chips=10,mult=2,level=1}}
  for i=1,n or 3 do s.hand[i]=F.card('made445:'..i,2+(i-1)%13,({'Clubs','Hearts','Spades','Diamonds'})[(i-1)%4+1]) end
  F.population(s);s.public_joker_belief=assert(B.start(row,'made445',{public_before_shuffle=true}));s.jokers={}
  for i=1,#row do s.jokers[i]=setmetatable({face_down=true},{__index=function()error('Hidden Joker payload accessed')end}) end
  return s
end
local function event(b,kind,n) return {epoch=b.epoch,kind=kind,discarded_count=n,observed_complete=true} end
if ACORN445_BASE then
  for _,key in ipairs({'j_bootstraps','j_turtle_bean'}) do
    local b=state({joker(key)}).public_joker_belief
    check(not B.advance_public(b,event(b,'play')).state_valid,'baseline invalidates stable '..key)
  end
  local s=state({joker('j_turtle_bean')},13)
  local action,n=O.suggest(s,s.public_joker_belief,{score=function()error('baseline must reject before scoring')end},B)
  check(not action and n==0,'baseline rejects legal13-card hand')
  print('Acorn445 baseline: '..count..' manufactured failures reproduced');return
end

-- Coefficients and Bean capacity do not change within a round; Yorick does.
for _,key in ipairs({'j_bootstraps','j_turtle_bean'}) do
 for _,size in ipairs(key=='j_turtle_bean' and {1,2,3,4,5} or {1}) do
  for _,debuff in ipairs({false,true}) do
   local j=joker(key,size);j.debuff=debuff;j.ability.eternal=true;j.ability.rental=true
   j.edition={holo=true,type='holo',mult=10}
   local s=state({j,F.j('j_blueprint'),F.j('j_brainstorm'),F.j('j_yorick')},5)
   local b=s.public_joker_belief;local original=Snap.fingerprint(b)
   for _,kind in ipairs({'play','discard'}) do
    local advanced=assert(B.advance_public(b,event(b,kind,5)))
    check(advanced.state_valid and B.qualified_values(advanced),'canonical stable transition')
    check(Snap.fingerprint(b)==original,'input belief remains immutable')
    for _,world in ipairs(b.worlds) do
     local raw=Snap.copy(s);raw.jokers={};raw.public_joker_belief=nil
     for i,index in ipairs(world) do raw.jokers[i]=Snap.copy(b.inventory[index]) end
     local exact=assert((kind=='play' and S.after_play or S.after_discard)(raw,{1,2,3,4,5}))
     for i,index in ipairs(world) do
      check(Snap.fingerprint(exact.jokers[i].ability)==Snap.fingerprint(advanced.inventory[index].ability),
        'pure scorer agrees for every retained copy world')
     end
    end
   end
  end
 end
end
-- Independent arithmetic: a 2 scores (5+2)*(1+2*floor(public dollars/5)).
do
 local s=state({joker('j_bootstraps')},1);local modules={scoring=S,acorn_belief=B,acorn_ordering=O}
 local b=s.public_joker_belief;s.public_joker_belief=assert(B.advance_public(b,event(b,'play')))
 for _,example in ipairs({{0,7},{4,7},{5,21},{9,21},{10,35},{24,63},{25,77}}) do
  s.dollars=example[1];local a=D.run(s,modules)
  check(a.action and a.play.score==example[2],'Bootstraps uses fresh public dollars, not popup or retained Mult')
  check(s.public_joker_belief.inventory[1].ability.mult==0,'no cached dollar-dependent Mult')
 end
 local raw=Snap.copy(s);raw.public_joker_belief=nil;raw.dollars=4
 raw.hand[1].seal='Gold';raw.jokers={joker('j_bootstraps'),F.j('j_blueprint')}
 local r=S.score(raw,{1});check(r.score==21,'supported in-hand Gold-seal income crosses the Bootstraps threshold')
end
-- New opaque effects, including copies, cannot be identified by guessed popups.
for _,key in ipairs({'j_bootstraps','j_turtle_bean'}) do
 local b=state({joker(key),F.j('j_blueprint'),F.j('j_brainstorm'),F.j('j_yorick')}).public_joker_belief
 for slot=1,4 do for _,channel in ipairs({'mult','chips','x_mult'}) do
  local after=B.observe(b,{epoch=b.epoch,type='rendered_status',phase='play',qualified_render=true,
    slot=slot,channel=channel,amount=997,text='arbitrary'})
  for _,world in ipairs(b.worlds) do if B.signatures(b,world,slot)==nil then
   local found=false;for _,retained in ipairs(after.worlds) do if table.concat(world,',')==table.concat(retained,',')then found=true end end
   check(found,'opaque actual/copy world survives unqualified popup amount')
  end end
 end end
 for _,kind in ipairs({'round_end','sell','use'}) do check(not B.advance_public(b,event(b,kind)).state_valid,'non-play/discard not admitted') end
 local stale=event(b,'play');stale.epoch='other';check(B.advance_public(b,stale)==nil,'stale event rejected')
 local incomplete=event(b,'play');incomplete.observed_complete=false;check(B.advance_public(b,incomplete)==nil,'incomplete event rejected')
end
local mutations={
 function(j)j.ability.extra={}end,function(j)j.ability.extra.custom=1 end,
 function(j)j.ability.effect='custom'end,function(j)j.ability.name='Counterfeit'end,
 function(j)j.ability.custom=true end,function(j)j.ability.h_mult=1 end,
 function(j)j.ability.mult=1 end,function(j)j.ability.x_mult=2 end,
 function(j)j.ability.set='Tarot'end,function(j)j.ability.type='Pair'end,
 function(j)j.edition={holo=true,mult=11}end,
 function(j)if j.key=='j_bootstraps' then j.ability.extra.mult=3 else j.ability.extra.h_mod=2 end end,
 function(j)if j.key=='j_bootstraps' then j.ability.extra.dollars=0 else j.ability.extra.h_size=0 end end,
 function(j)if j.key=='j_bootstraps' then j.ability.extra.dollars=6 else j.ability.extra.h_size=6 end end,
 function(j)if j.key=='j_bootstraps' then j.ability.extra.mult=-1 else j.ability.extra.h_size=1.5 end end}
for _,key in ipairs({'j_bootstraps','j_turtle_bean'}) do for _,debuff in ipairs({false,true}) do for _,mutate in ipairs(mutations) do
 local j=joker(key);mutate(j);j.debuff=debuff;local s=state({j});local calls=0
 local a,n=O.suggest(s,s.public_joker_belief,{score=function()calls=calls+1;error('modified inventory scored')end},B)
 check(not a and n==0 and calls==0,'modified form rejected before first score')
 check(not B.advance_public(s.public_joker_belief,event(s.public_joker_belief,'play')).state_valid,'modified form cannot advance')
end end end

-- Exact combinatorics + deterministic common-world coverage, not score proxies.
local function row(n)
 local r={joker('j_turtle_bean'),joker('j_bootstraps'),F.j('j_blueprint'),F.j('j_brainstorm'),F.j('j_yorick'),F.j('j_perkeo')}
 while #r>n do table.remove(r) end;return r
end
local function compare(s,budget,fail_at)
 local calls,seen=0,{}
 local score={score=function(projected,indices)
  calls=calls+1
  check(#indices>=1 and #indices<=s.hand_limit,'selection limit preserved')
  local used={};for _,i in ipairs(indices) do check(i>=1 and i<=#s.hand and not used[i],'physical selection legal');used[i]=true end
  for i,c in ipairs(s.hand) do if c.ability.forced_selection then check(used[i],'forced card retained') end end
  local order={};for _,j in ipairs(projected.jokers) do order[#order+1]=j.id end
  local key=table.concat(indices,',');seen[key]=seen[key] or {};check(not seen[key][table.concat(order,',')],'world/action scored once')
  seen[key][table.concat(order,',')]=true
  if calls==fail_at then return {score=0,uncertain=true} end
  return {score=#indices,legal=true,uncertain=false}
 end}
 local a,n,diag=O.suggest(s,s.public_joker_belief,score,B,{max_evaluations=budget,max_order_evaluations=0})
 check(n==calls and n<=budget,'complete score accounting and allowance')
 return a,n,diag,seen
end
for _,size in ipairs({1,4,5,6}) do
 local s=state(row(size),13);local a,n,diag,seen=compare(s,140000)
 local worlds=#s.public_joker_belief.worlds
 check(a and diag.complete and diag.legal_subsets==2379,'legal13-card complete family counted')
 check(diag.subsets==(size<=4 and 2379 or 64),'existing64-action shortlist retained')
 check(diag.all_legal_subsets==(size<=4),'exhaustive/shortlist distinction explicit')
 check(n==diag.subsets*worlds and diag.projected_state_allocations==worlds,'every retained action covers every world')
 for _,ws in pairs(seen) do local total=0;for _ in pairs(ws)do total=total+1 end;check(total==worlds,'no world omitted')end
end
do
 local s=state(row(5),13);s.hand[13].ability.forced_selection=true
 local a,n,diag=compare(s,140000);check(a and diag.legal_subsets==794 and diag.complete,'last physical card force filters exact13-card family')
 local repeat_a,repeat_n=compare(s,140000);check(table.concat(a.action.indices,',')==table.concat(repeat_a.action.indices,',') and n==repeat_n,'stable deterministic shortlist')
 local bad,used,failed=compare(s,140000,2);check(not bad and used==2 and not failed.complete,'incomplete world profile never published')
 local last,last_used,last_diag=compare(s,140000,diag.required_evaluations)
 check(not last and last_used==n and not last_diag.complete,'failure in final world never publishes a prefix')
 local low,spent=compare(s,15*120);check(not low and spent==0,'too-small allowance never scores partial shortlist')
 s.hand[14]=F.card('overflow445',7,'Spades')
 local oversized,calls=compare(s,140000);check(not oversized and calls==0,'14-card scope still bounded')
end
do
 local s=state(row(4),13)
 local exact,n,diag=compare(s,57096);check(exact and n==57096 and diag.all_legal_subsets,'exact-fit full-family budget')
 local short,spent=compare(s,57095);check(not short and spent==0,'one-call-insufficient full-family budget rejects before scoring')
 s.hand_limit=2;local limited,calls,d=compare(s,140000)
 check(limited and d.legal_subsets==91 and calls==91*24,'13-card hand honors smaller legal selection limit')
end
for _,limit in ipairs({0,-1,2.5,6,math.huge,'5',false}) do
 local s=state(row(1),13);s.hand_limit=limit
 local a,n=O.suggest(s,s.public_joker_belief,{score=function()error('invalid selection limit scored')end},B)
 check(not a and n==0,'invalid selection limit rejected')
end
for _,alias in ipairs({'face_down','identity_redacted','identity_unknown','unknown','concealed','facing'}) do
 local s=state(row(1),13);s.hand[13][alias]=alias=='facing' and 'back' or true
 local a,n=O.suggest(s,s.public_joker_belief,{score=function()error('concealed card scored')end},B)
 check(not a and n==0,'large hand does not admit hidden cards')
end
do
 local s=state(row(1),13);s.hand_limit=1
 local result=D.run(s,{scoring=S,acorn_belief=B,acorn_ordering=O},nil,{acorn_belief={max_order_evaluations=0}})
 check(result.action and result.acorn_diagnostics.complete and result.evaluations==13,'real Decision and scorer support a13-card hand')
 local large=state(row(5),13)
 local full=D.run(large,{scoring=S,acorn_belief=B,acorn_ordering=O},nil,{acorn_belief={max_order_evaluations=0}})
 check(full.action and full.acorn_diagnostics.complete and full.evaluations==64*120,
   'real scorer and Decision cover the13-card five-Joker shortlist in every world')
 check(full.acorn_diagnostics.all_legal_subsets==false,'real integration does not claim action optimality')
end

-- Actual tracker: fresh observations, no hidden payload reads, once per settlement.
for _,key in ipairs({'j_bootstraps','j_turtle_bean'}) do
 local front={joker(key),F.j('j_blueprint'),F.j('j_yorick')};local reads=0
 local g={GAME={round=5,round_resets={ante=3},current_round={hands_left=4,hands_played=0,discards_left=3,discards_used=0}},
  STATES={SELECTING_HAND=1,ROUND_EVAL=2,GAME_OVER=3},STATE=1,STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},
  hand={highlighted={}},play={cards={}},jokers={cards={}}}
 local payload={}
 for i,j in ipairs(front)do local card={facing='front',sprite_facing='front',VT={x=i},states={visible=true}};g.jokers.cards[i]=card;payload[card]=j end
 local tracker=Public.new({belief=B,card=function(card)check(card.facing=='front','never recapture concealed');reads=reads+1;return payload[card]end})
 tracker:remember(g);tracker:before_hide(g)
 for _,back in ipairs(g.jokers.cards)do back.facing='back';back.sprite_facing='back';payload[back]=nil
  setmetatable(back,{__index=function(_,k)if k=='ability' or k=='config' or k=='key' or k=='id' or k=='sort_id'then error('hidden read '..k)end end})end
 tracker:sync(g);local start_reads=reads
 for _,kind in ipairs({'play','discard','play'})do
  g.hand.highlighted={{},{},{},{},{}};tracker:begin_action(kind,g);g.STATE_COMPLETE=false
  local rev=tracker.belief.revision;tracker:sync(g);check(tracker.belief.revision==rev,'unsettled does not advance')
  local r=g.GAME.current_round
  if kind=='play' then r.hands_left=r.hands_left-1;r.hands_played=r.hands_played+1 else r.discards_left=r.discards_left-1;r.discards_used=r.discards_used+1 end
  g.STATE_COMPLETE=true;tracker:sync(g);check(tracker.belief.state_valid and tracker.belief.revision==rev+1,'settled transition qualified')
  tracker:sync(g);check(tracker.belief.revision==rev+1,'duplicate settlement no second advancement')
  local captured=state(front,1);captured.jokers={};captured.dollars=5*r.hands_played
  tracker:capture(g,captured)
  check(captured.jokers[1].identity_redacted and captured.public_joker_belief.state_valid,'public state stays redacted and valid')
  local next_advice=D.run(captured,{scoring=S,acorn_belief=B,acorn_ordering=O},nil,{acorn_belief={max_order_evaluations=0}})
  check(next_advice.action and next_advice.acorn_diagnostics.complete,'settled tracker-to-Decision remains available')
 end
 check(reads==start_reads,'zero concealed recaptures')
end
print('Acorn continuity445: '..count..' manufactured assertions passed')
