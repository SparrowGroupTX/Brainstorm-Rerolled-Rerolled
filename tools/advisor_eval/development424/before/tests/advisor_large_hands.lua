-- Turtle Bean gives +5 hand size in vanilla: an ordinary eight-card hand can
-- therefore contain thirteen cards. These are detached regression states,
-- never observations of a completed run or estimates of a challenge win rate.
local Search=dofile('Brainstorm/Advisor/search.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Ordering=dofile('Brainstorm/Advisor/ordering.lua')
-- These fixtures explicitly exercise exhaustive fallback budgets. Fast-clear
-- large-hand coverage lives in advisor_fast_clear.lua.
local function exhaustive(state,scorer,options)
  options=options or {}; options.fast_clear=false
  return Search.run(state,scorer,options)
end
local checks=0
local function check(v,label) assert(v,label); checks=checks+1 end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank)
  return {id=id,rank=rank,suit='Spades',nominal=rank==14 and 11 or math.min(rank,10),enhancement='c_base',ability={}}
end
local function state(n)
  local s={phase='hand',hand={},deck={},jokers={},hands={},consumeables={},modifiers={},probabilities={normal=1},
    hand_size=n,hand_limit=5,blind={chips=16,name='The Mouth',key='bl_mouth',only_hand='High Card'},
    chips=0,dollars=20,hands_left=3,hands_played=0,discards_left=0,discards_used=0,current_round={}}
  for i=1,n do s.hand[i]=card('h'..i,2) end
  s.hand[n]=card('h'..n,14); s.playing_cards=s.hand
  return s
end
local function contains(indices,index) for _,i in ipairs(indices) do if i==index then return true end end return false end
local old_random,old_seed,old_pseudo,old_pseudoseed=math.random,math.randomseed,pseudorandom,pseudoseed
math.random=function() error('large-hand advisor consumed global RNG') end
math.randomseed=function() error('large-hand advisor seeded global RNG') end
pseudorandom=function() error('large-hand advisor consumed game RNG') end
pseudoseed=function() error('large-hand advisor consumed game seed') end

do
  local s=state(13)
  s.jokers={{key='j_turtle_bean',ability={name='Turtle Bean',extra={h_size=5,h_mod=1}}}}
  local before=Snapshot.fingerprint(s)
  local result=exhaustive(s,Scoring)
  equal(result.kind,'play','Turtle Bean hand has executable play advice')
  equal(result.play.indices[1],13,'winning card after old twelve-card limit is considered')
  equal(result.play.score,16,'actual scoring model verifies last-card clear')
  equal(result.evaluations,2379,'every thirteen-card subset through five is scored')
  check(result.play_complete,'thirteen-card current-play enumeration is complete')
  equal(result.search_diagnostics.continuation_hand_limit,12,'separate continuation cap is disclosed')
  equal(Snapshot.fingerprint(s),before,'Turtle Bean snapshot is unchanged')
  equal(Snapshot.fingerprint(result),Snapshot.fingerprint(exhaustive(s,Scoring)),'Turtle Bean recommendations are deterministic')
end

do
  local s=state(20)
  local result=exhaustive(s,Scoring)
  equal(result.play.indices[1],20,'twenty-card exact search includes last card')
  equal(result.evaluations,21699,'twenty-card exact enumeration fits the default budget')
  check(result.play_complete and not result.truncated,'twenty-card current play is not claimed truncated')
end

do
  local s=state(13); s.blind.chips=100; s.discards_left=2
  for i=1,10 do s.deck[i]=card('d'..i,14); s.deck[i].ability.perma_bonus=100 end
  local before=Snapshot.fingerprint(s)
  local trials,seen={},{}
  local scorer={score=function(trial,indices)
    if trial~=s and not seen[trial] then
      seen[trial]=true; local drawn={}
      for _,c in ipairs(trial.hand) do if c.id:sub(1,1)=='d' then drawn[#drawn+1]=c.id end end
      trials[#trials+1]=drawn
    end
    return Scoring.score(trial,indices)
  end}
  local result=exhaustive(s,scorer)
  check(result.discard and result.discard.count>=4,'enlarged discard search completes enough fair rounds')
  equal(result.search_diagnostics.discard_candidates,14,'shortlist shrinks to fit four paired thirteen-card rounds')
  check(result.search_diagnostics.discard_shortlist_reduced,'candidate reduction is disclosed')
  equal(result.kind,'discard','clear-producing redraw beats the losing thirteen-card hand')
  check(result.evaluations<=140000,'play plus discard comparisons share the hard budget')
  for sample=0,result.discard.count-1 do
    local first=sample*result.search_diagnostics.discard_candidates
    local longest={}
    for i=1,result.search_diagnostics.discard_candidates do if #trials[first+i]>#longest then longest=trials[first+i] end end
    for i=1,result.search_diagnostics.discard_candidates do
      for j,id in ipairs(trials[first+i]) do equal(id,longest[j],'candidate draws share the same paired deck order') end
    end
  end
  equal(Snapshot.fingerprint(s),before,'large-hand sampling leaves all nested state unchanged')
end

do
  local s=state(20); s.blind.chips=100; s.discards_left=2
  for i=1,8 do s.deck[i]=card('d'..i,14); s.deck[i].ability.perma_bonus=100 end
  local result=exhaustive(s,Scoring,{samples=4})
  equal(result.search_diagnostics.discard_candidates,1,'twenty-card budget retains one useful large redraw')
  equal(#result.discard.indices,5,'single affordable candidate represents a substantial redraw')
  equal(result.discard.count,4,'twenty-card draw comparison is complete')
  check(result.evaluations<=140000,'twenty-card default work remains bounded')
end

do
  local s=state(100)
  local before=Snapshot.fingerprint(s)
  local result=exhaustive(s,Scoring,{max_evaluations=5000})
  check(result.play and result.play.legal~=false,'extreme hand receives a legal bounded proposal')
  check(contains(result.play.indices,100),'bounded pool uses original indices beyond the old limit')
  check(result.truncated and not result.play_complete,'extreme-hand approximation is explicitly incomplete')
  check(result.evaluations<=5000,'extreme hand never explodes past custom budget')
  equal(Snapshot.fingerprint(s),before,'fallback does not shrink or mutate the actual hand')
  s.hand[100].ability.forced_selection=true
  s.blind={chips=100000,key='bl_psychic',name='The Psychic'}
  result=exhaustive(s,Scoring,{max_evaluations=1})
  equal(result.evaluations,1,'forced-card fallback respects even a one-evaluation budget')
  check(result.play and contains(result.play.indices,100),'forced late card is included before budget exhaustion')
  equal(#result.play.indices,5,'fallback also honors Psychic minimum selection size')
end

do
  local s=state(13); s.blind.chips=200
  s.consumeables={{key='c_pluto',name='Pluto',ability={set='Planet',consumeable={hand_type='High Card'}}}}
  local b=exhaustive(s,Scoring)
  local before=Snapshot.fingerprint(s)
  local use,evaluations,diagnostics=Consumables.suggest(s,Scoring,b)
  check(use and contains(use.play.indices,13),'planet comparison scores an enlarged hand including its last card')
  equal(evaluations,2379,'one consumable scores every thirteen-card legal selection')
  check(evaluations<=25000,'enlarged consumable work stays within its own budget')
  equal(Snapshot.fingerprint(s),before,'enlarged consumable evaluation is detached')
  use,evaluations,diagnostics=Consumables.suggest(s,Scoring,b,nil,{max_evaluations=2378})
  equal(use,nil,'incomplete consumable comparison is never published')
  equal(evaluations,0,'unaffordable full comparison is declined before scoring')
  check(diagnostics.truncated and #diagnostics.warnings>0,'skipped consumable comparison is disclosed')
  s=state(21)
  use,evaluations,diagnostics=Consumables.suggest(s,Scoring,{})
  equal(evaluations,0,'consumable target generation stops above twenty cards')
  check(diagnostics.truncated and #diagnostics.warnings>0,'extreme consumable size has an explicit explanation')
end

do
  local s=state(13); s.blind.chips=200
  s.jokers={{key='j_cavendish',ability={name='Cavendish',extra={Xmult=3}},blueprint_compat=true},
    {key='j_joker',ability={name='Joker',mult=4},blueprint_compat=true}}
  local before=Snapshot.fingerprint(s)
  local reorder,evaluations,diagnostics=Ordering.suggest(s,Scoring,exhaustive(s,Scoring))
  check(reorder and contains(reorder.play.indices,13),'enlarged Joker-order search retains the winning late card')
  equal(table.concat(reorder.action.order,','),'2,1','flat Mult is moved before XMult')
  check(reorder.play.score>=200,'the proposed order clears according to the real scorer')
  equal(diagnostics.partial_orders,0,'each reported order uses the same completed subset comparison')
  check(evaluations<=30000,'enlarged order work stays within its own budget')
  equal(Snapshot.fingerprint(s),before,'enlarged Joker ordering is detached')
  s=state(21); s.jokers={{key='j_joker'},{key='j_joker'}}
  reorder,evaluations,diagnostics=Ordering.suggest(s,Scoring,{})
  equal(evaluations,0,'extreme order search stops before subset generation')
  check(diagnostics.truncated and diagnostics.reason,'extreme order-search limit is disclosed')
end

math.random,math.randomseed,pseudorandom,pseudoseed=old_random,old_seed,old_pseudo,old_pseudoseed
print('advisor_large_hands: '..checks..' checks passed')
