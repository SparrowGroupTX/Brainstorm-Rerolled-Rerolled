local F=dofile('tests/fixtures/repair416.lua');local m=F.modules()
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function hidden()
 local s=F.state();s.blind={key='bl_wheel',name='The Wheel',chips=500}
 s.hand[7].face_down=true
 s.jokers={F.joker('j_yorick','Yorick',{x_mult=4,yorick_discards=20,extra={discards=23,xmult=1}}),
  F.joker('j_shoot_the_moon','Shoot the Moon',{extra=13})}
 F.population(s);return s
end
local s=hidden();local original=m.snapshot.fingerprint(s)
local suggestion,work,proof=m.growth.visible_retained(s,m,12)
check(suggestion and proof.complete,'visible Ace/held Queen proves a clear despite another concealed slot')
check(work<=12 and work>0,'visible proof respects twelve-call budget')
for _,i in ipairs(suggestion.action.indices) do check(i~=1 and i~=2 and i~=7,'only visible spare slots are discarded') end
check(m.snapshot.fingerprint(s)==original,'proof does not mutate public or hidden input')
local changed=F.copy(s);changed.hand[7],changed.deck[2]=changed.deck[2],changed.hand[7]
changed.hand[7].face_down=true;changed.deck[2].face_down=false;F.population(changed)
local other=m.growth.visible_retained(changed,m,12)
check(other and m.snapshot.fingerprint(other.action)==m.snapshot.fingerprint(suggestion.action),'hidden assignments with unchanged pooled composition cannot affect action')
local empty,used=m.growth.visible_retained(s,m,1)
check(not empty and used==0,'insufficient complete proof allowance abstains')
for _,key in ipairs({'j_blackboard','j_raised_fist'}) do
 local bad=hidden();bad.jokers[#bad.jokers+1]=F.joker(key,key=='j_blackboard' and 'Blackboard' or 'Raised Fist')
 check(not m.growth.visible_retained(bad,m,12),'identity-sensitive held mechanics stay outside zero-contribution proof')
end
local steel=hidden();steel.deck[1]=F.card('new-steel',3,'Clubs','m_steel');F.population(steel)
check(not m.growth.visible_retained(steel,m,12),'possible held Steel prevents a false Moon order proof')
local forced=hidden();forced.hand[7].ability.forced_selection=true;F.population(forced)
check(not m.growth.visible_retained(forced,m,12),'forced hidden slot is never selected or discarded as a placeholder')
local allhidden=hidden();for _,c in ipairs(allhidden.hand) do c.face_down=true end;F.population(allhidden)
check(not m.growth.visible_retained(allhidden,m,12),'sampled all-clear cannot substitute for a visible physical anchor')
local hidden_spares=hidden();for i=3,7 do hidden_spares.hand[i].face_down=true end;F.population(hidden_spares)
check(not m.growth.visible_retained(hidden_spares,m,12),'known winning Ace/Queen alone do not justify discarding unproved hidden spare cards')
local baron=hidden();baron.jokers[2]=F.joker('j_baron','Baron',{extra=1.5});baron.blind.chips=60
baron.hand[7]=F.card('concealed-king',13,'Hearts');baron.hand[7].face_down=true;F.population(baron)
check(m.growth.visible_retained(baron,m,12),'ordinary Baron held-King factor preserves a visible floor')
baron.jokers[2].ability.extra=0.5
check(m.scoring.score(baron,{1}).score<60,'actual concealed King shrinks score in the manufactured modified-Baron counterexample')
check(not m.growth.visible_retained(baron,m,12),'shrinking public Baron multiplier cannot disappear with hidden King placeholders')
baron.jokers[3]=F.joker('j_blueprint','Blueprint');baron.jokers[2],baron.jokers[3]=baron.jokers[3],baron.jokers[2]
check(not m.growth.visible_retained(baron,m,12),'copying a shrinking held factor cannot bypass qualification')
local badmoon=hidden();badmoon.jokers[2].ability.extra=-13
check(not m.growth.visible_retained(badmoon,m,12),'negative public held-Queen effect cannot be erased from hidden assignments')

-- Real Decision -> real transition -> real manufactured redraw -> fresh advice.
local calls=0;local raw=m.scoring
m.scoring=setmetatable({lower_bound=function(... )calls=calls+1;return raw.lower_bound(...)end,
 score=function(...)calls=calls+1;return raw.score(...)end},{__index=raw})
local r=m.decision.run(s,m,nil,{concealed_belief={copy_order=false}})
check(r.action.kind=='discard' and r.concealed_belief.scope=='visible_retained_floor','live decision path selects certified discard')
check(r.evaluations==calls and calls<=12,'all public proof calls charged exactly once')
local ace=s.hand[1].id
for n=3,1,-1 do
 r=m.decision.run(s,m,nil,{concealed_belief={copy_order=false}})
 check(r.action.kind=='discard' and r.discard_before_clear.selected,'fresh hidden advice continues spending safe discards')
 s=assert(raw.after_discard(s,r.action.indices))
 -- A mixed public redraw keeps one concealed slot and visible spare cards.
 -- A hand whose only spare cards are concealed has no visible discard proof.
 local rolls={};for i=1,12 do rolls[i]=1 end
 s=assert(m.draws.fill(s,s.deck,{visibility_rolls=rolls}))
 check(s.hand[1].id==ace,'same actual anchor survives each discard and draw')
end
r=m.decision.run(s,m,nil,{concealed_belief={copy_order=false}})
check(r.action.kind=='play' and s.discards_left==0,'finishes after exhausting discards')
check(raw.score(s,r.action.indices).score>=s.blind.chips,'manufactured actual played hand clears')

-- Independent pair-order permutations with Joker-stage Duo and per-card Smiley.
s=F.state();s.hand[1]=F.card('k1',13,'Clubs','m_mult');s.hand[2]=F.card('k2',13,'Spades','m_steel')
s.jokers={F.joker('j_yorick','Yorick',{x_mult=3,yorick_discards=19,extra={discards=23,xmult=1}}),
 F.joker('j_smiley','Smiley Face',{extra=5}),F.joker('j_duo','The Duo',{x_mult=2,type='Pair',effect='X1.5 Mult'})}
F.population(s)
local clear=raw.score(s,{1,2});clear.indices={1,2};s.blind.chips=clear.score-1
check(raw.score(s,{2,1}).score==clear.score,'permuting the independently qualified pair preserves score')
local kept=m.growth.suggest(s,m,clear,{exhaust_discards=true,max_evaluations=12})
check(kept and kept.action.kind=='discard','Smiley/Duo no longer create a false additive sorting exception')
local bad=F.copy(s);bad.jokers[2].ability.h_mult=1
check(not m.growth.suggest(bad,m,clear,{exhaust_discards=true,max_evaluations=12}),'modified held arithmetic is not whitelisted by name')
print('visible discard416: '..checks..' checks passed')
