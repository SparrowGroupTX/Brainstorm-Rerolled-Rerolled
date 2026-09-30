local F=dofile('tests/fixtures/repair416.lua');local m=F.modules()
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local s=F.state();s.blind={key='bl_mouth',name='The Mouth',only_hand='Pair',chips=1000}
s.hand={F.card('a',2,'Clubs'),F.card('b',7,'Hearts'),F.card('c',10,'Spades','m_glass')}
s.jokers={F.joker('j_green_joker','Green Joker',{mult=3,extra={hand_add=1,discard_sub=1}})}
s.first_used_hand_level=2;F.population(s)
local before=m.snapshot.fingerprint(s)
local after,effect,actual=m.scoring.after_play(s,{1,2,3})
check(after and effect.blocked_mouth and actual.score==0,'legal blocked Mouth play is an exact zero-score transition')
check(after.jokers[1].ability.mult==3,'blocked hand skips Green before-scoring growth')
check(#after.hand==0 and #after.playing_cards==#s.playing_cards,'blocked Glass is moved, not shattered or destroyed')
check(after.hands_left==2 and after.hands_played==1 and after.discards_left==3,'only actual play resource is spent')
check(after.hands['High Card'].played==1 and after.blind.only_hand=='Pair','category usage advances without changing Mouth lock')
check(after.first_used_hand_level==2,'blocked hand does not spend first scored-hand upgrade')
check(m.snapshot.fingerprint(s)==before,'input remains detached')
s.jokers={F.joker('j_matador','Matador',{extra=8})}
check(not m.scoring.after_play(s,{1,2,3}),'unmodeled debuffed-hand income stays unsupported')
s.jokers={F.joker('j_ice_cream','Ice Cream',{extra={chips=100,chip_mod=5}})}
check(not m.scoring.after_play(s,{1,2,3}),'unmodeled post-hand decay stays unsupported')
s.jokers={F.joker('j_custom','Green Joker',{mult=3})}
check(not m.scoring.after_play(s,{1,2,3}),'custom Joker name cannot impersonate a qualified callback')
s.jokers={};s.hand[1].rank=1;s.hand[1].base.id=1
check(not m.scoring.after_play(s,{1,2,3}),'invalid public rank cannot seed a zero-score continuation')

-- Strong scarce Two Pair loses its next hand; smaller repeatable Pair clears.
s=F.state();s.blind={key='bl_mouth',name='The Mouth',chips=300};s.discards_left=0;s.hands_left=2
s.hand={F.card('h1',6,'Clubs'),F.card('h2',6,'Hearts'),F.card('h3',8,'Spades'),F.card('h4',8,'Diamonds'),
 F.card('h5',14,'Hearts'),F.card('h6',13,'Clubs'),F.card('h7',11,'Diamonds')}
s.deck={};for i=1,12 do s.deck[i]=F.card('d'..i,4,({'Hearts','Spades','Diamonds','Clubs'})[(i-1)%4+1]) end
s.hands.Pair={level=1,chips=40,mult=3,s_chips=40,s_mult=3,l_chips=15,l_mult=1,played=0}
F.population(s)
local r=m.search.run(s,m.scoring,{max_evaluations=140000,fast_clear=false,draws=m.draws})
check(r.mouth_lock_comparison and r.mouth_lock_comparison.complete,'zero-discard first lock receives a complete category comparison')
check(r.play.hand=='Pair','cumulative comparison selects repeatable Pair over stronger immediate Two Pair')
check(r.evaluations<=140000,'new comparison shares ordinary allowance')
local a=assert(m.scoring.after_play(s,r.play.indices));a=assert(m.draws.fill(a,a.deck))
local next=m.search.run(a,m.scoring,{max_evaluations=140000,fast_clear=false,draws=m.draws})
a=assert(m.scoring.after_play(a,next.play.indices))
check(a.chips>=300,'real detached manufactured continuation clears in two hands')
local small=m.search.run(s,m.scoring,{max_evaluations=120,fast_clear=false,draws=m.draws})
check(not small.mouth_lock_comparison and small.evaluations<=120,'small cap never publishes a partial category preference')
local flipped=F.copy(s);flipped.modifiers.flipped_cards=4
check(not m.search.run(flipped,m.scoring,{max_evaluations=140000,fast_clear=false}).mouth_lock_comparison,'unsupported hidden replacement process is not treated as visible')
print('Mouth planning416: '..checks..' checks passed')
