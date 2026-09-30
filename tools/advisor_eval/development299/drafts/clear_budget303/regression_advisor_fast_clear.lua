local Search=dofile('tools/advisor_eval/development299/drafts/clear_budget303/search.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('tools/advisor_eval/development299/drafts/clear_budget303/decision.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function card(i,r) return {id=i,rank=r,suit=i%2==0 and 'Hearts' or 'Spades',ability={},enhancement='c_base'} end
local function state(n)
  local s={phase='hand',hand={},deck={},playing_cards={},jokers={},consumeables={{key='c_strength'}},
    hands={},hand_limit=5,hand_size=8,hands_left=4,discards_left=3,dollars=20,chips=0,
    blind={key='bl_small',chips=300},current_round={},modifiers={},probabilities={normal=1}}
  for i=1,n do s.hand[i]=card(i,13) end
  for i=n+1,8 do s.hand[i]=card(i,i-4) end
  for i=1,8 do s.playing_cards[i]=s.hand[i] end
  return s
end
local forbidden=function() error('expensive specialist ran after reliable clear') end
local modules={search=Search,scoring=Scoring,consumables={suggest=forbidden},
  ordering={suggest=forbidden},hand_ordering={suggest=forbidden},boss_rescue={suggest=forbidden}}
for _,n in ipairs({4,5}) do
  local s=state(n)
  s.jokers={{key='j_joker',ability={name='Joker',mult=4}},{key='j_joker',ability={name='Joker',mult=4}}}
  local before=Snapshot.fingerprint(s)
  local r=Decision.run(s,modules)
  check(r.fast_clear and r.fast_clear.specialists_skipped,'whole decision takes fast path')
  check(r.evaluations<=48 and r.fast_clear.conservation_evaluations<=16,'fixed global fast bound')
  check(r.action.kind=='play' and Search.reliable_clear(r.play,300),'reliable legal clear')
  check(not r.play_complete,'early return never claims exhaustive coverage')
  check(Snapshot.fingerprint(s)==before,'input untouched')
  check(Snapshot.fingerprint(r)==Snapshot.fingerprint(Decision.run(s,modules)),'stable deterministic decision')
end
do
  local s=state(4); s.blind.chips=2000;s.chips=1700
  check(Decision.run(s,modules).fast_clear,'uses remaining target')
  s.hand[8].ability.forced_selection=true;s.blind={key='bl_psychic',chips=300}
  local r=Decision.run(s,modules)
  check(#r.play.indices==5 and r.play.indices[5]==8,'boss/forced-card legality retained')
end
do
  local s=state(4);s.blind.chips=100
  s.hand[1].enhancement='m_glass';s.hand[1].ability.extra=4
  local r=Decision.run(s,modules)
  check(r.fast_clear and r.play.glass_loss==0,'cheap clear saves Glass')
  s.hand={card(1,13)};s.hand[1].enhancement='m_glass';s.blind.chips=25;s.hand_size=1
  r=Decision.run(s,modules)
  check(r.fast_clear and r.play.glass_loss>0,'sole clearing Glass play remains allowed')
  s.probabilities.normal=4
  check(Scoring.score(s,{1}).glass_loss==1,'Fragile live probability changes exposure')
end
do
  local s=state(4);s.blind={key='bl_arm',chips=50}
  s.hands['Pair']={chips=100,mult=10,level=8,l_chips=15,l_mult=1,played=20}
  local r=Decision.run(s,modules)
  check(r.fast_clear and r.play.arm_cost==0,'Arm conserves upgraded hand with a cheap clear')
end
do
  local s=state(4);s.blind.chips=100000
  local r=Search.run(s,Scoring)
  check(not r.fast_clear and r.play_complete,'no clear keeps exhaustive fallback')
  local fake={score=function(_,indices) return {score=1000000,hand='High Card',legal=true,uncertain=true} end}
  r=Search.run(s,fake)
  check(not r.fast_clear and r.play_complete,'random expected overkill cannot claim reliable fast clear')
  s.hand={card(1,14),card(2,2)};s.deck={card(3,3)};s.hand_size=2
  local trials=0
  fake.score=function(t) if t~=s then trials=trials+1 end;return {score=1000000,hand='High Card',legal=true,uncertain=true} end
  r=Search.run(s,fake,{samples=4,resource_samples=0})
  check(trials>0 and not r.fast_clear,'uncertain overkill retains discard fallback instead of ending search')
end
do
  local s=state(4)
  -- Force a clear absent from the seed list to test stop during fallback.
  local fake={score=function(_,a)
    local wins=table.concat(a,',')=='1,5'
    return {score=wins and 400 or 0,hand='Pair',legal=true}
  end}
  local r=Search.run(s,fake)
  check(r.clear_shortcut and not r.fast_clear and r.evaluations<218,'fallback is an ordinary clear shortcut')
  check(r.clear_shortcut.conservation_evaluations<=16,'fallback conservation stays bounded')
  s=state(4); for i=9,100 do s.hand[i]=card(i,2) end
  r=Search.run(s,Scoring)
  check(r.fast_clear and r.evaluations<=48,'extreme hands can take same bounded clear path')
end
print('advisor_fast_clear: '..checks..' checks passed')
