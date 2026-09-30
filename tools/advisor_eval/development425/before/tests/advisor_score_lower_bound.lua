local S=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(rank,e,suit) return {rank=rank or 14,enhancement=e or 'c_base',suit=suit or 'Spades',ability={}} end
local function joker(n,a) a=a or {};a.name=n;return {name=n,ability=a,blueprint_compat=true} end
local function snap(cards,jokers,prob)
  return {hand=cards or {card()},jokers=jokers or {},hands={},hands_left=3,hands_played=1,dollars=0,probabilities={normal=prob or 1},current_round={}}
end
local function bound(s,expected,label)
  local before=Snapshot.fingerprint(s)
  local r=S.lower_bound(s,{1})
  eq(r.score,expected,label..' score');eq(r.reliable_bound,true,label..' reliable')
  eq(r.uncertain,false,label..' no unsupported uncertainty');eq(Snapshot.fingerprint(s),before,label..' detached')
  eq(r.bound_kind,'supported_random_floor',label..' labeled')
  return r
end
math.random=function() error('no RNG') end
pseudorandom=function() error('no game RNG') end
bound(snap(),16,'deterministic hand')
local s=snap({card(14,'m_lucky')});bound(s,16,'Lucky failure');eq(S.score(s,{1}).uncertain,true,'normal mean remains uncertain')
s.probabilities.normal=5;bound(s,336,'guaranteed Lucky mult');eq(S.lower_bound(s,{1}).expected_dollars,0,'optional Lucky money excluded')
s.probabilities.normal=15;bound(s,336,'guaranteed Lucky outcomes');eq(S.lower_bound(s,{1}).expected_dollars,20,'guaranteed Lucky money included')
s=snap({card(14,'m_lucky')},{joker('Lucky Cat',{x_mult=2,extra=0.25})});bound(s,32,'Lucky Cat no speculative growth')
s.probabilities.normal=5;bound(s,756,'Lucky Cat guaranteed growth')
s.jokers={joker('Blueprint'),joker('Lucky Cat',{x_mult=2,extra=0.25})};bound(s,1701,'copy guaranteed physical Cat growth once')
s=snap({card(14,nil,'Hearts')},{joker('Bloodstone',{extra={odds=2,Xmult=1.5}})});bound(s,16,'Bloodstone failure')
s.probabilities.normal=2;bound(s,24,'Bloodstone guaranteed trigger')
s.jokers[1].ability.extra.Xmult=0.5;eq(S.lower_bound(s,{1}).reliable_bound,false,'negative random multiplier excluded')
s=snap(nil,{joker('Space Joker',{extra=4})});bound(s,16,'Space failure')
s.probabilities.normal=4;bound(s,52,'Space guaranteed upgrade')
s.jokers={joker('Blueprint'),joker('Space Joker',{extra=4})};bound(s,108,'copied Space guaranteed upgrades')
s=snap(nil,{joker('Misprint',{extra={min=2,max=8}})});bound(s,48,'Misprint minimum')
s=snap({card(13)},{joker('Business Card',{extra=2}),joker('Bull',{extra=2}),joker('Bootstraps',{extra={mult=2,dollars=5}})});s.dollars=4
bound(s,23,'Business earnings threshold failure');s.probabilities.normal=2;bound(s,81,'Business guaranteed earnings threshold')
s=snap({card(14),card(13)},{joker('Reserved Parking',{extra={odds=2,dollars=1}}),joker('Bull',{extra=2}),joker('Bootstraps',{extra={mult=2,dollars=5}})});s.dollars=4
bound(s,24,'Parking failure');s.probabilities.normal=2;bound(s,78,'Parking guaranteed threshold')
s=snap({card(14,'m_glass')},{joker('Misprint')});local r=bound(s,32,'Glass immediate score minimum');eq(r.glass_loss,0.25,'Glass probability not replaced by scoring floor')
s.probabilities.normal=4;r=bound(s,32,'Fragile immediate score minimum');eq(r.glass_loss,1,'certain Glass exposure retained')
s=snap();s.hand[1].face_down=true;eq(S.lower_bound(s,{1}).reliable_bound,false,'hidden identity stays unsupported')
s.hand[1].face_down=nil;s.hand[1].rank=nil;eq(S.lower_bound(s,{1}).reliable_bound,false,'unknown rank stays unsupported')
s=snap();s.blind={name='The Hook'};eq(S.lower_bound(s,{1}).reliable_bound,false,'Hook held card uncertainty stays unsupported')
s=snap(nil,{joker('DNA')});s.hands_played=0;eq(S.lower_bound(s,{1}).reliable_bound,false,'DNA new held cards stay unsupported')
s=snap(nil,{joker('Unknown mod Joker')});s.suppress_warnings=true;eq(S.lower_bound(s,{1}).reliable_bound,false,'suppressed warnings cannot fake bound')
s=snap({card(14,'m_custom')});eq(S.lower_bound(s,{1}).reliable_bound,false,'unknown enhancement stays unsupported')
s=snap();s.hand[1].ability.forced_selection=true;eq(S.lower_bound(s,{2}).reliable_bound,false,'illegal hand has no reliable bound')
s=snap({card(14,'m_lucky')});s.hand[1].ability.mult=-20;eq(S.lower_bound(s,{1}).reliable_bound,false,'negative Lucky effect excluded')
s=snap({card(14,'m_lucky')},{joker('Bull',{extra=-2})});eq(S.lower_bound(s,{1}).reliable_bound,false,'negative dollar scaling excluded')
local calls=0;local real=S.score;S.score=function(...) calls=calls+1;return real(...) end
S.lower_bound(snap(),{1});eq(calls,1,'bound requires one scoring pass');S.score=real
print('advisor score lower bound: '..checks..' checks passed')
