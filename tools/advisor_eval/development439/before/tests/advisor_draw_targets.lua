local Search=dofile('Brainstorm/Advisor/search.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank,suit) return {id=id,key='c_base',rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit,ability={},enhancement='c_base'} end
local function state()
  local s={phase='hand',ante=3,hand={},deck={},playing_cards={},jokers={},consumeables={},dollars=10,
    hand_size=8,hand_limit=5,hands_left=2,discards_left=1,hands_played=0,discards_used=0,
    blind={key='bl_small',chips=8000},chips=0,current_round={},modifiers={},probabilities={normal=1},
    hands={Straight={level=12,chips=360,mult=37,l_chips=30,l_mult=3,played=0}}}
  local held={Clubs={[14]=true,[9]=true},Diamonds={[2]=true,[7]=true,[9]=true},Hearts={[3]=true,[7]=true},Spades={[7]=true}}
  local by_key={}
  for _,suit in ipairs({'Clubs','Diamonds','Hearts','Spades'}) do for rank=2,14 do
    local c=card(suit..rank,rank,suit);s.playing_cards[#s.playing_cards+1]=c;by_key[c.id]=c
    if not (held[suit] or {})[rank] then s.deck[#s.deck+1]=c end
  end end
  for _,key in ipairs({'Clubs14','Diamonds2','Hearts3','Spades7','Hearts7','Diamonds7','Clubs9','Diamonds9'}) do s.hand[#s.hand+1]=by_key[key] end
  return s
end
local function selected(t) return table.concat(t.indices,',') end
do
  local s=state();local before=Snapshot.fingerprint(s);local targets=Search.draw_targets(s)
  local wheel
  for _,t in ipairs(targets) do
    check(t.completion_probability>0 and t.completion_probability<=1,'bounded composition probability')
    check(t.expected_score_hint>0,'finite positive ranking hint')
    if selected(t)=='4,5,6,7,8' then wheel=t end
  end
  check(wheel and wheel.category=='Straight','A23 wheel completion is represented')
  local function c(n,k) local v=1;for i=1,k do v=v*(n-i+1)/i end;return v end
  local expected=1-2*c(40,5)/c(44,5)+c(36,5)/c(44,5)
  check(math.abs(wheel.completion_probability-expected)<1e-12,'missing4 and5 use exact inclusion-exclusion without replacement')
  eq(Snapshot.fingerprint(s),before,'composition shortlist leaves input unchanged')
  local reversed=Snapshot.copy(s);local deck={};for i=#s.deck,1,-1 do deck[#deck+1]=s.deck[i] end;reversed.deck=deck
  eq(Snapshot.fingerprint(Search.draw_targets(reversed)),Snapshot.fingerprint(targets),'deck order is not an oracle')
  for _,c in ipairs(s.deck) do c.face_down=true end
  eq(Snapshot.fingerprint(Search.draw_targets(s)),Snapshot.fingerprint(targets),'ordinary deck backs retain public-composition completion coverage')
  s.deck[1].unknown=true;eq(#Search.draw_targets(s),0,'genuinely unknown deck identity still abstains');s.deck[1].unknown=nil
  s.hands.Straight.level=1;eq(#Search.draw_targets(s),0,'no new upgrade preference for base rows')
  s.hands.Straight.level=12;s.jokers={{key='j_yorick'}};eq(#Search.draw_targets(s),0,'protected Joker engines keep their original shortlist')
  s.jokers={};s.used_vouchers={v_observatory=true};eq(#Search.draw_targets(s),0,'Observatory inventory engine excluded')
  s.used_vouchers={};s.hand[1].face_down=true;eq(#Search.draw_targets(s),0,'concealed public hand excluded')
end
do
  local s=state();s.hands.Straight=nil;s.hands.Flush={level=5,chips=95,mult=12}
  s.deck={card('d1',4,'Clubs'),card('d2',5,'Clubs'),card('d3',6,'Clubs'),card('d4',8,'Clubs'),card('d5',10,'Spades'),card('d6',11,'Spades')}
  local t=Search.draw_targets(s);local clubs
  for _,v in ipairs(t) do if v.category=='Flush' and selected(v)=='2,3,4,5,6' then clubs=v end end
  -- At least three Clubs from five drawn out of four Clubs and two non-Clubs.
  check(clubs and math.abs(clubs.completion_probability-1)<1e-12,'flush tail uses finite population composition')
  s.deck[1].enhancement='m_wild';eq(#Search.draw_targets(s),0,'Wild suit semantics abstain from Flush hint')
  s.deck[1].enhancement=nil
  s.hand[1].ability.forced_selection=true
  for _,v in ipairs(Search.draw_targets(s)) do local found=false;for _,i in ipairs(v.indices) do if i==1 then found=true end end;check(found,'forced discard index remains legal') end
end
do
  for _,change in ipairs({{rank=1},{rank=2.5},{suit='unknown'},{nominal=math.huge},{unknown=true},{concealed=true}}) do
    for _,area in ipairs({'hand','deck'}) do
      local s=state();for k,v in pairs(change) do s[area][1][k]=v end
      eq(#Search.draw_targets(s),0,'malformed or concealed public card excludes shortlist hints')
    end
  end
end
do
  local s=state()
  -- A legally thinned rank population isolates the neglected upgraded wheel:
  -- unrelated high-rank redraws can still make pairs/full houses but cannot
  -- complete their tempting high Straight windows.
  local removed={[6]=true,[8]=true,[10]=true,[11]=true,[12]=true,[13]=true}
  local deck,population={},{}
  for _,c in ipairs(s.hand) do population[#population+1]=c end
  for _,c in ipairs(s.deck) do if not removed[c.rank] then deck[#deck+1]=c;population[#population+1]=c end end
  s.deck,s.playing_cards=deck,population
  local before=Snapshot.fingerprint(s)
  local old=Search.run(s,Score,{samples=24,resource_samples=0,draw_targets=false,fast_clear=false})
  local new=Search.run(s,Score,{samples=24,resource_samples=0,fast_clear=false})
  local diagnostics=new.search_diagnostics or {}
  check(diagnostics.upgraded_draw_targets and #diagnostics.upgraded_draw_targets>=1,'upgraded family gets a slot in complete real-score comparison')
  eq(diagnostics.discard_candidates,old.search_diagnostics.discard_candidates,'same number of discard candidates')
  check(new.evaluations<=140000,'ordinary score ceiling unchanged')
  check(not new.truncated and new.discard,'comparison completes')
  check(new.discard.mean>old.discard.mean,'missing high-value completion family improves matched estimated redraw outcome')
  eq(Snapshot.fingerprint(s),before,'real scoring is detached')
  local repeated=Search.run(s,Score,{samples=24,resource_samples=0,fast_clear=false})
  eq(Snapshot.fingerprint(new),Snapshot.fingerprint(repeated),'new comparison remains deterministic')
  print('draw-target comparison: prior mean '..old.discard.mean..', new mean '..new.discard.mean..', scores '..new.evaluations)
end
print('advisor_draw_targets: '..checks..' checks passed')
