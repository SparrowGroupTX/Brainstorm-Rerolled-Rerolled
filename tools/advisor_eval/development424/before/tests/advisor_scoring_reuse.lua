local C=dofile('Brainstorm/Advisor/scoring.lua')
local Cache=dofile('Brainstorm/Advisor/score_cache.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local reference=SCORING_REFERENCE and dofile(SCORING_REFERENCE) or C
local checks=0
local function eq(a,b,label) checks=checks+1;assert(S.fingerprint(a)==S.fingerprint(b),label) end
local function j(name,extra) return {ability={name=name,extra=extra},blueprint_compat=true} end
local rows={{j('Joker')},{j('Blueprint'),j('Brainstorm')},
  {j('Spare Trousers',2),j('Square Joker',{chips=4,chip_mod=4})},
  {j('Runner',{chips=15,chip_mod=15}),j('Green Joker',{hand_add=1})},
  {j('Ride the Bus',1),j('Obelisk',.2)},
  {j('Midas Mask'),j('Vampire',.1),j('Hiker',5)},
  {j('Vampire',.1),j('Midas Mask'),j('Blueprint'),j('Hiker',5)},
  {j('Wee Joker',{chips=0,chip_mod=8}),j('Lucky Cat',.25)},
  {j('DNA'),j('Hologram',.25),j('Blueprint'),j('DNA')},
  {j('Baron',1.5),j('Mime',1),j('Blueprint'),j('Baron',1.5)}}
for variant,row in ipairs(rows) do
  local s={phase='hand',hand={},deck={},jokers=row,hands={},dollars=20,hand_size=6,
    hand_limit=5,hands_left=2,hands_played=0,discards_left=1,current_round={},
    blind={chips=99999},chips=0,modifiers={},probabilities={normal=1},playing_cards={}}
  for i,r in ipairs({2,2,13,13,6,8}) do
    local c={id='reuse:'..i,rank=r,suit=i%2==0 and 'Hearts' or 'Spades',
      enhancement=({'c_base','m_lucky','m_glass','m_steel','m_bonus','c_base'})[i],ability={}}
    s.hand[i]=c;s.playing_cards[i]=c
  end
  local cached,stats=Cache.new(C)
  local original=S.fingerprint(s)
  Search.combinations(6,5,function(indices)
    eq(cached.score(s,indices),reference.score(s,indices),'Complete score parity for mutable/copy row '..variant)
    eq(cached.lower_bound(s,indices),reference.lower_bound(s,indices),'Score-floor parity')
    local after,why=C.after_play(s,indices)
    local before,reason=reference.after_play(s,indices)
    eq(after,before,'Transition still owns detached writable cards and growth')
    eq(why,reason,'Unsupported transition reasons preserved')
    eq(S.fingerprint(s),original,'Ordinary/floor/transition scoring leaves input untouched')
  end)
  eq(stats().row_builds,1,'Only immutable row routing is reused')
  local changed=S.copy(s);changed.jokers[1].debuff=true
  eq(cached.score(changed,{1,2}),reference.score(changed,{1,2}),'Different row rebuilds copy routing')
  eq(stats().row_builds,2,'Changed row has a separate route')
end
print('scoring reuse: '..checks..' exact result, transition and mutation checks passed')
