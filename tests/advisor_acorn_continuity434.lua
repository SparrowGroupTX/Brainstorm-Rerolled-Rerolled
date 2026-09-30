-- Invented inventories and public events only; no captured run is executed.
local p='Brainstorm/Advisor/'
local F=dofile('tests/fixtures/retained418.lua')
local B=dofile(p..'acorn_belief.lua')
local O=dofile(p..'acorn_ordering.lua');local D=dofile(p..'decision.lua')
local S=dofile(p..'scoring.lua');local Snap=dofile(p..'snapshot.lua')
local Public=dofile(p..'acorn_public.lua')
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function joker(key)
 local road=key=='j_hit_the_road'
 local j=F.joker(key,road and 'Hit the Road' or 'Campfire',{extra=road and 0.5 or 0.25,x_mult=2.5})
 j.ability.effect=road and 'Jack Discard Effect' or nil
 j.ability.type='';j.ability.hands_played_at_create=41
 return j
end
local function state(row)
 local s=F.state(false);s.blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000}
 s.hand={};s.deck={};s.hands={['High Card']={chips=5,mult=1,level=1,played=3},Pair={chips=10,mult=2,level=1,played=6}}
 for i,r in ipairs({11,11,4,7,9})do s.hand[i]=F.card('invented434:'..i,r,'Clubs')end
 F.population(s);s.public_joker_belief=assert(B.start(row,'made434',{public_before_shuffle=true}));s.jokers={}
 for i=1,#row do s.jokers[i]=setmetatable({face_down=true},{__index=function()error('Hidden Joker identity accessed')end})end
 return s
end
local function event(b,kind,n)return {epoch=b.epoch,kind=kind,discarded_count=n,discarded_jacks=kind=='discard' and 2 or nil,observed_complete=true}end
for _,key in ipairs({'j_campfire','j_hit_the_road'})do
 local b=state({joker(key),F.j('j_yorick'),F.j('j_perkeo')}).public_joker_belief
 local after=assert(B.advance_public(b,event(b,'play')))
 if EXPECT_BASELINE434 then
  check(not after.state_valid and after.value_gap=='This Joker has unqualified changes during public actions.',
   'exact previous module reproduces unsupported '..key)
 else check(after.state_valid,'canonical completed play remains qualified: '..key)end
end
if EXPECT_BASELINE434 then print('Baseline434: '..count..' unsupported causes reproduced');return end
for _,key in ipairs({'j_campfire','j_hit_the_road'})do for _,debuff in ipairs({false,true})do
 for _,edition in ipairs({'base','holo','negative'})do
  local j=joker(key);j.debuff=debuff;j.ability.eternal=true;j.ability.rental=true;j.ability.perishable=true;j.ability.perish_tally=2
  if edition~='base' then j.edition=edition=='holo' and {holo=true,mult=10,type='holo'} or {negative=true,type='negative'}end
  local row={j,F.j('j_blueprint'),F.j('j_brainstorm'),F.j('j_yorick')}
  local s=state(row);local b=s.public_joker_belief;local original=Snap.fingerprint(b)
  for _,kind in ipairs({'play','discard'})do
   local targets=kind=='play' and {1} or {1,2,3,4,5}
   local advanced=assert(B.advance_public(b,event(b,kind,#targets)))
   check(advanced.state_valid and B.qualified_values(advanced),'qualified physical transition')
   check(Snap.fingerprint(b)==original,'belief input preserved')
   for _,world in ipairs(b.worlds)do
    local raw=Snap.copy(s);raw.jokers={};raw.public_joker_belief=nil
    for i,index in ipairs(world)do raw.jokers[i]=Snap.copy(b.inventory[index])end
    local exact=assert((kind=='play' and S.after_play or S.after_discard)(raw,targets))
    for i,index in ipairs(world)do
     check(Snap.fingerprint(exact.jokers[i].ability)==Snap.fingerprint(advanced.inventory[index].ability),
      'real scorer agrees for every public copied order: '..key..'/'..kind)
    end
   end
  end
  -- Opaque effects and their copies must not acquire identities from guessed
  -- amounts: each real target/copy world survives arbitrary rendered values.
  for slot=1,#row do for _,channel in ipairs({'chips','mult','x_mult'})do
   local next_b=B.observe(b,{epoch=b.epoch,type='rendered_status',phase='play',qualified_render=true,
    slot=slot,channel=channel,amount=987,text='arbitrary'})
   for _,world in ipairs(b.worlds)do
    if B.signatures(b,world,slot)==nil then
     local found=false;for _,remaining in ipairs(next_b.worlds)do if table.concat(world,',')==table.concat(remaining,',')then found=true end end
     check(found,'opaque identity world never eliminated by popup amount')
    end
   end
  end end
 end
end end
-- Actual next Decision on both affected row families, with fresh public state.
for _,key in ipairs({'j_campfire','j_hit_the_road'})do
 local extra=key=='j_campfire' and F.joker('j_popcorn','Popcorn',{extra=4,mult=12}) or F.joker('j_bull','Bull',{extra=2})
 extra.ability.effect=nil
 local s=state({joker(key),F.j(key=='j_campfire' and 'j_blueprint' or 'j_brainstorm'),F.j('j_perkeo'),F.j('j_yorick'),extra})
 s.hand={s.hand[1],s.hand[2]};F.population(s)
 local b=s.public_joker_belief;local before=Snap.fingerprint(s)
 local modules={scoring=S,acorn_belief=B,acorn_ordering=O}
 local first=D.run(s,modules,nil,{acorn_belief={max_order_evaluations=0}})
 check(first.action and first.acorn_diagnostics.complete and first.evaluations<=140000,'first whole-world decision')
 s.public_joker_belief=assert(B.advance_public(b,event(b,'play')))
 s.hands['High Card'].played=4;s.hands_left=s.hands_left-1;s.hands_played=1
 local second=D.run(s,modules,nil,{acorn_belief={max_order_evaluations=0}})
 check(second.action and second.acorn_diagnostics.complete and second.evaluations<=140000,'next whole-world decision remains executable')
 check(Snap.fingerprint(b)==Snap.fingerprint(state({joker(key),F.j(key=='j_campfire' and 'j_blueprint' or 'j_brainstorm'),F.j('j_perkeo'),F.j('j_yorick'),extra}).public_joker_belief),'pure public advancement')
 check(before~=Snap.fingerprint(s),'fresh public counters changed')
end
-- Reject modified forms before scoring, even when currently debuffed.
local mutations={
 function(j)j.ability.extra=6 end,function(j)j.ability.extra={}end,function(j)j.ability.effect='custom'end,
 function(j)j.ability.name='Counterfeit'end,function(j)j.ability.custom=true end,
 function(j)j.ability.h_mult=1 end,function(j)j.ability.mult=1 end,function(j)j.ability.x_mult=1.3 end,
 function(j)j.ability.set='Tarot'end,function(j)j.ability.type='Pair'end,
 function(j)j.edition={holo=true,mult=11}end}
for _,key in ipairs({'j_campfire','j_hit_the_road'})do for _,debuff in ipairs({false,true})do for _,mutate in ipairs(mutations)do
 local j=joker(key);mutate(j);j.debuff=debuff;local s=state({j,F.j('j_blueprint')});local calls=0
 local a,n,diag=O.suggest(s,s.public_joker_belief,{score=function()calls=calls+1;error('must not score modified form')end},B)
 check(not a and not diag.complete and n==0 and calls==0,'modified form rejected before score')
 check(not B.advance_public(s.public_joker_belief,event(s.public_joker_belief,'play')).state_valid,'modified advancement rejected')
end end end
-- Real observer settlement with poisoned concealed payloads, repeated actions,
-- and no duplicate advancement. Nothing reads a remembered physical identity.
for _,key in ipairs({'j_campfire','j_hit_the_road'})do
 local front={joker(key),F.j('j_blueprint'),F.j('j_brainstorm'),F.j('j_yorick'),F.j('j_perkeo')};local reads=0
 local g={GAME={round=9,round_resets={ante=4},current_round={hands_left=4,hands_played=0,discards_left=3,discards_used=0}},
  STATES={SELECTING_HAND=1,ROUND_EVAL=2,GAME_OVER=3},STATE=1,STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},
  hand={highlighted={}},play={cards={}},jokers={cards={}}}
 local visible_payload={}
 for i,j in ipairs(front)do
  local card={facing='front',sprite_facing='front',VT={x=i},states={visible=true}};g.jokers.cards[i]=card;visible_payload[card]=j
 end
 local tracker=Public.new({belief=B,card=function(card)check(card.facing=='front','no hidden recapture');reads=reads+1;return visible_payload[card] or card end})
 tracker:remember(g);tracker:before_hide(g)
 for _,back in ipairs(g.jokers.cards)do
  back.facing='back';back.sprite_facing='back';visible_payload[back]=nil
  setmetatable(back,{__index=function(_,k)if k=='ability' or k=='config' or k=='key' or k=='id' or k=='sort_id'then error('hidden read '..k)end end})
 end
 tracker:sync(g);local initial_reads=reads
 for _,kind in ipairs({'play','discard','play'})do
  g.hand.highlighted={};for i,rank in ipairs({11,11,3,5,7})do local c=F.card('public:'..i,rank,'Clubs');c.facing='front';g.hand.highlighted[i]=c end;tracker:begin_action(kind,g);g.STATE_COMPLETE=false
  local revision=tracker.belief.revision;tracker:sync(g);check(tracker.belief.revision==revision,'unsettled action does not advance')
  local r=g.GAME.current_round
  if kind=='play' then r.hands_left=r.hands_left-1;r.hands_played=r.hands_played+1
  else r.discards_left=r.discards_left-1;r.discards_used=r.discards_used+1 end
  g.STATE_COMPLETE=true;tracker:sync(g)
  check(tracker.belief.state_valid and tracker.belief.revision==revision+1,'settled observer remains qualified')
  tracker:sync(g);check(tracker.belief.revision==revision+1,'duplicate observation cannot advance twice')
  local captured=state(front);captured.hand={captured.hand[1]};captured.jokers={}
  captured.hands_left=r.hands_left;captured.hands_played=r.hands_played
  captured.discards_left=r.discards_left;captured.discards_used=r.discards_used
  captured.hands['High Card'].played=3+r.hands_played
  tracker:capture(g,captured)
  check(captured.jokers[1].identity_redacted and captured.public_joker_belief.state_valid,'public capture remains redacted and qualified')
  local advice=D.run(captured,{scoring=S,acorn_belief=B,acorn_ordering=O},nil,{acorn_belief={max_order_evaluations=0}})
  check(advice.action and advice.acorn_diagnostics.complete and advice.evaluations<=140000,'observer to Decision stays supported across play/discard/play')
 end
 check(reads==initial_reads+(key=='j_hit_the_road' and 5 or 0),'only visible Road playing cards are additionally captured')
end
-- Compound affected row and actual public rank semantics, including Stone,
-- debuffed and concealed playing cards. Copies do not repeat physical growth.
do
 local row={joker('j_campfire'),joker('j_hit_the_road'),F.j('j_blueprint'),F.j('j_yorick'),F.j('j_perkeo')}
 local b=assert(B.start(row,'compound434',{public_before_shuffle=true}))
 local cards={F.card('jack434',11,'Clubs'),F.card('stone434',11,'Clubs'),F.card('debuff434',11,'Clubs')}
 cards[2].enhancement='m_stone';cards[3].debuff=true
 check(B.discarded_jacks(cards)==1,'only visible non-Stone nondebuff Jack counts')
 local after=assert(B.advance_public(b,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=3,discarded_jacks=B.discarded_jacks(cards)}))
 check(after.state_valid and B.qualified_values(after),'combined Campfire/Road remains qualified')
 for _,j in ipairs(after.inventory)do
  if j.key=='j_hit_the_road'then check(j.ability.x_mult==3,'one physical half-X increment despite copy')end
  if j.key=='j_campfire'then check(j.ability.x_mult==2.5,'Campfire stable without a sale')end
 end
 for _,kind in ipairs({'sale','use','round'})do check(not B.advance_public(b,{epoch=b.epoch,kind=kind,observed_complete=true}).state_valid,'unqualified mutation remains blocked '..kind)end
 for _,value in ipairs({-1,4,0.5})do check(not B.advance_public(b,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=3,discarded_jacks=value}).state_valid,'invalid Jack count rejected')end
 check(not B.advance_public(b,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=3}).state_valid,'unknown Jack count never assumes zero')
 local hidden=setmetatable({face_down=true},{__index=function()error('concealed playing-card payload read')end})
 check(B.discarded_jacks({hidden})==nil,'concealed rank unavailable without inspecting payload')
 local debuffed=F.copy(b);for _,j in ipairs(debuffed.inventory)do if j.key=='j_hit_the_road'then j.debuff=true end end
 check(B.advance_public(debuffed,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=3}).state_valid,'debuffed physical Road needs no rank assumption')
end
print('Acorn continuity434: '..count..' manufactured assertions passed')
