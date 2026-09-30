local Search=dofile('Brainstorm/Advisor/search.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,label) check(math.abs(a-b)<1e-10,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(t) if type(t)~='table' then return t end;local c={};for k,v in pairs(t) do c[k]=clone(v) end;return c end
local function state(counts,size)
  local s={phase='hand',ante=1,win_ante=8,blind={chips=100},hand_size=size or 8,hand_limit=5,
    hand={},deck={},playing_cards={},modifiers={},jokers={},hands={
      Pair={level=1,played=0,chips=10,mult=2,l_chips=15,l_mult=1},
      ['Three of a Kind']={level=1,played=0,chips=30,mult=3,l_chips=20,l_mult=2},
      ['Four of a Kind']={level=1,played=0,chips=60,mult=7,l_chips=30,l_mult=3}}}
  local id=0
  for rank=2,14 do for n=1,counts[rank] or 0 do
    id=id+1
    local c={id='card'..id,rank=rank,suit=({'Spades','Hearts','Clubs','Diamonds'})[(n-1)%4+1],enhancement='c_base',ability={}}
    s.playing_cards[#s.playing_cards+1]=c
    if #s.hand<s.hand_size then s.hand[#s.hand+1]=c else s.deck[#s.deck+1]=c end
  end end
  return s
end
local function value(s,category) return Search.hand_growth_value(s,category,Strategy.build_profile(s)) end
local function brute(s,k)
  local draws=math.min(s.hand_size,#s.playing_cards)
  local counts,total,hits={},0,0
  local function visit(start,used)
    if used==draws then
      total=total+1;for _,n in pairs(counts) do if n>=k then hits=hits+1;break end end;return
    end
    for i=start,#s.playing_cards-(draws-used)+1 do
      local c=s.playing_cards[i];local rank=c.enhancement~='m_stone' and c.rank
      if rank then counts[rank]=(counts[rank] or 0)+1 end
      visit(i+1,used+1)
      if rank then counts[rank]=counts[rank]-1 end
    end
  end
  visit(1,0);return hits/total
end

-- Enumerate every unordered opening of small populations independently of the
-- runtime generating-function complement, including overlapping rank groups.
for _,counts in ipairs({{[7]=4,[8]=4},{[7]=3,[8]=2,[9]=1,[10]=1,[11]=1},{[2]=5,[3]=3,[4]=2}}) do
  for size=1,8 do
    local s=state(counts,size)
    for category,k in pairs({Pair=2,['Three of a Kind']=3,['Four of a Kind']=4}) do
      local info=Search.hand_growth_population(s,category)
      check(info and info.population==#s.playing_cards and info.draws==size,'explicit bounded population/sample metadata')
      near(info.frequency,brute(s,k),'exact rank frequency against complete enumeration '..category..'/'..size)
    end
  end
end
local s=state({[7]=4,[8]=4},4)
s.playing_cards[1].enhancement='m_stone';s.playing_cards[2].enhancement='m_stone'
for category,k in pairs({Pair=2,['Three of a Kind']=3,['Four of a Kind']=4}) do
  near(Search.hand_growth_population(s,category).frequency,brute(s,k),'Stone consumes a slot without contributing rank')
end

s=state({[7]=4,[8]=4})
check(value(s,'Four of a Kind')>value(s,'Three of a Kind'),'consolidated deck prefers larger sustainable absolute upgrade')
check(value(s,'Three of a Kind')>value(s,'Pair'),'incidental default Pair does not dictate a developed rank opportunity')
eq(Strategy.build_profile(s).hand,'Pair','test exercises default profile fallback')
local sparse=state({[7]=3,[8]=2,[9]=1,[10]=1,[11]=1})
check(value(sparse,'Three of a Kind')>value(sparse,'Pair'),'three-card rank build supports Three of a Kind')
eq(value(sparse,'Four of a Kind'),0,'impossible four-card rank has no public opportunity credit')
local normal_counts={};for rank=2,14 do normal_counts[rank]=4 end
local normal=state(normal_counts)
check(value(normal,'Pair')>value(normal,'Three of a Kind'),'ordinary unconsolidated deck keeps reliable Pair preference')
check(value(normal,'Three of a Kind')>value(normal,'Four of a Kind'),'rarer rank pattern does not win on printed gain alone')
s.hands['Three of a Kind']={level=20,played=30,chips=410,mult=41,l_chips=20,l_mult=2}
check(value(s,'Three of a Kind')>value(s,'Four of a Kind'),'levels and repeated successful use can preserve established Three of a Kind')
s=state({[7]=4,[8]=4})
local base=value(s,'Four of a Kind')
s.jokers={{key='j_zany',ability={name='Zany Joker',type='Three of a Kind'}}}
check(value(s,'Four of a Kind')>base,'Four of a Kind contains the conditional Three of a Kind Joker trigger')
s.jokers[1].debuff=true
near(value(s,'Four of a Kind'),base,'debuffed conditional Joker adds no preference')
s.jokers={};s.blind.only_hand='Pair'
near(value(s,'Four of a Kind'),base/2,'existing incompatible-only-hand caution is retained')
s.blind.disabled=true
near(value(s,'Four of a Kind'),base,'disabled boss restriction does not penalize the opportunity')
s.blind={boss=true};s.ante=8
eq(value(s,'Four of a Kind'),0,'terminal blind has no future development preference')
s.ante=7;s.blind={}
local short=Strategy.build_profile(s);short.horizon=1
check(Search.hand_growth_value(s,'Four of a Kind',short)<base,'shorter development horizon reduces added opportunity value')

-- Unavailable/malformed/modified populations do not become zero probability or
-- fabricated evidence. The historical preference remains available instead.
local base_state=state({[7]=4,[8]=4})
local invalid={
  function(x) x.playing_cards=nil end,
  function(x) x.playing_cards={} end,
  function(x) x.playing_cards[2].id=x.playing_cards[1].id end,
  function(x) x.playing_cards[2].unknown=true end,
  function(x) x.playing_cards[2].concealed=true end,
  function(x) x.playing_cards[2].rank=0/0 end,
  function(x) x.playing_cards[2].rank=15 end,
  function(x) x.playing_cards[2].enhancement='m_custom' end,
  function(x) x.playing_cards[2].ability.perma_debuff=true end,
  function(x) x.hand[1].face_down=true end,
  function(x) x.hand[1].rank=9 end,
  function(x) x.deck={{id='absent',rank=7}} end,
  function(x) x.hand_size=13 end,
  function(x) x.hand_limit=6 end,
  function(x) x.modifiers.flipped_cards=4 end,
  function(x) x.modifiers.custom_rank_rule=true end,
  function(x) x.modifiers.minus_hand_size_per_X_dollar=5 end,
  function(x) x.deck_key='b_plasma' end,
}
for i,mutate in ipairs(invalid) do
  local x=clone(base_state);mutate(x)
  eq(Search.hand_growth_population(x,'Four of a Kind'),nil,'unqualified population fallback '..i)
end
s=clone(base_state)
for _,c in ipairs(s.playing_cards) do c.face_down=true end
check(Search.hand_growth_population(s,'Four of a Kind')~=nil,'ordinary public-population backs remain known identities')
s.modifiers={enable_eternals_in_shop=true,enable_perishables_in_shop=true,enable_rentals_in_shop=true}
check(Search.hand_growth_population(s,'Four of a Kind')~=nil,'Gold Stake economic modifiers preserve rank mechanics')
s.hand_limit=3
eq(Search.hand_growth_population(s,'Four of a Kind').frequency,0,'selection limit cannot realize larger rank pattern')
eq(Search.hand_growth_population(s,'Five of a Kind'),nil,'Five of a Kind remains outside this rank-only category qualification')

local x=clone(base_state)
x.hands['Four of a Kind'].played=2;x.playing_cards=nil
local p=Strategy.build_profile(x)
local expected=(0.15+2+2)*((90*10)/(60*7)-1)
near(Search.hand_growth_value(x,'Four of a Kind',p),expected,'missing public population preserves justified historical preference')
local before=clone(base_state)
for i=1,10 do near(value(base_state,'Four of a Kind'),value(before,'Four of a Kind'),'deterministic repeated preference') end
eq(base_state.hands['Four of a Kind'].level,1,'valuation does not mutate owned levels')
eq(base_state.playing_cards[1].rank,7,'valuation does not mutate public population')

-- Same held choices, levels and history; only the full public deck changes.
-- A separate guaranteed High Card clear makes the first-discard development
-- choice reviewable without assuming any favorable replacement draw.
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local function investment(concentrated)
  local s=state({[7]=4,[8]=3,[14]=1})
  s.chips=0;s.hands_left=3;s.hands_played=0;s.discards_left=3;s.discards_used=0;s.current_round={}
  s.dollars=25;s.consumeables={};s.probabilities={normal=1};s.blind.chips=1000
  s.jokers={{key='j_joker',ability={name='Joker',mult=1000}},
    {key='j_burnt',ability={name='Burnt Joker'}}}
  s.hands['Three of a Kind']={level=8,played=10,chips=170,mult=17,l_chips=20,l_mult=2}
  s.hands['Four of a Kind'].played=10
  local counts={};for _,c in ipairs(s.playing_cards) do counts[c.rank]=(counts[c.rank] or 0)+1 end
  local function append(rank)
    local c={id='extra'..(#s.playing_cards+1),rank=rank,suit='Diamonds',enhancement='c_base',ability={}}
    s.deck[#s.deck+1]=c;s.playing_cards[#s.playing_cards+1]=c
  end
  if concentrated then for i=1,20 do append(7) end
  else for rank=2,14 do for i=(counts[rank] or 0)+1,4 do append(rank) end end end
  return s
end
local modules={scoring=Scoring,strategy=Strategy,search=Search}
local selected={}
for _,concentrated in ipairs({false,true}) do
  local s=investment(concentrated)
  local clear=Scoring.score(s,{8});clear.indices={8}
  local original,calls=Scoring.score,0
  Scoring.score=function(...) calls=calls+1;return original(...) end
  local choice,evaluations=Growth.suggest(s,modules,clear,{max_evaluations=12})
  Scoring.score=original
  check(choice and choice.action.kind=='discard','complete safe first-discard growth choice')
  check(calls<=12 and evaluations==calls,'actual/report score work remains inside original12 cap')
  local after=Scoring.after_discard(s,choice.action.indices)
  check(after and Scoring.score(after,choice.play.indices).score>=s.blind.chips,'retained finish clears without any draw assumption')
  eq(s.discards_used,0,'growth comparison preserves original first-discard state')
  eq(s.hands['Three of a Kind'].level,8,'growth comparison preserves input upgrade levels')
  selected[#selected+1]=choice.growth.effects.burnt_hand
end
eq(selected[1],'Three of a Kind','ordinary public population favors established attainable Three of a Kind')
eq(selected[2],'Four of a Kind','same held choices with consolidated population favor Four of a Kind investment')
print('advisor Burnt public population: '..checks..' checks passed')
