local Search=dofile('Brainstorm/Advisor/search.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function card(id,r) return {id=id,rank=r,suit='Spades',ability={},enhancement='c_base'} end
local function state()
  return {phase='hand',ante=1,hand={card(1,14),card(2,2)},deck={card(3,2),card(4,2)},
    hand_size=2,hand_limit=5,hands_left=3,discards_left=2,discards_used=0,hands_played=0,
    blind={key='bl_small',chips=40},chips=0,dollars=20,current_round={},probabilities={normal=1},modifiers={},
    hands={['High Card']={level=1,chips=5,mult=1,l_chips=10,l_mult=1,played=5}},jokers={}}
end
do
  local s=state();s.jokers={{key='j_yorick',ability={name='Yorick',x_mult=1,yorick_discards=1,extra={discards=23,xmult=1}}}}
  local before=Snapshot.fingerprint(s)
  local transitions=0
  local scorer={score=Score.score,classify=Score.classify,after_play=Score.after_play,
    after_discard=function(...) transitions=transitions+1;return Score.after_discard(...) end}
  local r=Search.run(s,scorer,{strategy=Strategy,samples=4,resource_samples=4})
  check(transitions>0 and r.discard,'sampled discards use detached transition')
  check(not r.search_diagnostics.continuation_skipped,'exact Yorick no longer blocks continuation')
  check(r.discard.mean>=32,'next-play estimate receives physical Yorick growth')
  check(Snapshot.fingerprint(s)==before,'all comparisons remain detached')
end
do
  local s=state();s.jokers={{key='j_burnt',ability={name='Burnt Joker'}}}
  local observed=false
  local scorer={classify=Score.classify,after_play=Score.after_play,after_discard=Score.after_discard,
    score=function(t,indices)
      if t~=s and (t.discards_used or 0)>0 and t.hands['High Card'].level==2 then observed=true end
      return Score.score(t,indices)
    end}
  local r=Search.run(s,scorer,{strategy=Strategy,samples=4,resource_samples=4})
  check(observed,'next-hand score uses Burnt first-discard levels')
  check(not r.search_diagnostics.continuation_skipped,'Burnt continuation is modeled')
  local p={hand='High Card'}
  local low=Search.hand_growth_value(s,'High Card',p)
  s.hands['High Card']={level=50,chips=495,mult=50,l_chips=10,l_mult=1,played=5}
  check(Search.hand_growth_value(s,'High Card',p)<low,'already mature level reduces marginal upgrade value')
  s.hands['Pair']={level=1,chips=10,mult=2,l_chips=15,l_mult=1,played=30};p.hand='Pair'
  check(Search.hand_growth_value(s,'Pair',p)>Search.hand_growth_value(s,'High Card',p),'new build changes preferred upgrade')
end
do
  local s=state();s.hand[1].seal='Purple'
  local r=Search.run(s,Score,{strategy=Strategy,samples=4,resource_samples=4})
  check(r.search_diagnostics.continuation_skipped~=nil,'unmodeled selected generation cannot become continuation evidence')
end
do
  local s=state();s.hand[1].ability.forced_selection=true
  local r=Search.run(s,Score,{strategy=Strategy,samples=4,resource_samples=4})
  check(r.discard~=nil,'forced-card discard still yields a legal candidate')
  local included=false;for _,i in ipairs(r.discard.indices) do if i==1 then included=true end end
  check(included,'all published discard candidates include Bell forced selection')
end
print('advisor_discard_search: '..checks..' checks passed')
