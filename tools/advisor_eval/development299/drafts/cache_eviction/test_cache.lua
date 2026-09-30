local C=dofile('Brainstorm/Advisor/scoring.lua')
local Cache=dofile('tools/advisor_eval/development299/drafts/cache_eviction/score_cache.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function eq(a,b,label) assert(Snap.fingerprint(a)==Snap.fingerprint(b),label);checks=checks+1 end
local function card(i,r,s,e) return {id=i,rank=r,suit=s,enhancement=e,ability={}} end
local s={hand={},deck={},jokers={},hands={},blind={chips=999999},dollars=10,hand_size=8,
  hands_left=1,discards_left=1,chips=0,modifiers={},probabilities={normal=1}}
local sets={'Spades','Hearts','Clubs','Diamonds'}
local cached,stats=Cache.new(C,{max_entries=256})
local rows={{},{ {key='j_four_fingers'} },{{key='j_shortcut'}},{{key='j_splash'}},{{key='j_smeared'}},
  {{key='j_four_fingers'},{key='j_shortcut'},{key='j_smeared'},{key='j_splash'}},
  {{key='j_mime'},{key='j_baron',ability={name='Baron',extra=1.5}}},
  {{key='j_smeared',debuff=true},{key='j_joker',ability={name='Joker',mult=4}}}}
for variant=1,8 do
  s.jokers=rows[variant]
  for i=1,8 do s.hand[i]=card(i,2+(i*3+variant)%13,sets[(i+variant)%4+1],i==3 and 'm_stone' or i==4 and 'm_wild' or i==5 and 'm_steel' or 'c_base') end
  s.hand[4].debuff=variant%2==0
  s.playing_cards=s.hand
  Search.combinations(8,5,function(indices)
    eq(cached.score(s,indices),C.score(s,indices),'cached score equals full scorer including uncertainty/cash/exposure')
    eq(cached.score(s,indices),C.score(s,indices),'repeat cached score equals full scorer')
  end)
end
assert(stats().hits>0 and stats().stored<=256,'bounded cache actually reuses classifications');checks=checks+1
-- Physical indices and hand positions can change while classification is equal.
s.jokers={};s.hand={card(1,13,'Spades'),card(2,13,'Hearts'),card(3,2,'Clubs')}
local a=cached.score(s,{1,2});a.scoring_indices[1]=99
local changed=Snap.copy(s);changed.hand={s.hand[3],s.hand[1],s.hand[2]}
eq(cached.score(changed,{2,3}),C.score(changed,{2,3}),'cached relative positions remap without sharing mutable outputs')
local fresh,initial=Cache.new(C)
eq(initial().hits,0,'new decision starts with fresh cache')
s.hand[1].ability.forced_selection=true
eq(fresh.score(s,{2}),C.score(s,{2}),'forced legality is still scored independently')
s.hand[1].face_down=true
eq(fresh.score(s,{1,2}),C.score(s,{1,2}),'hidden card warning cannot disappear in classification cache')
local small=Cache.new(C,{max_entries=0})
eq(small.score(s,{1}),C.score(s,{1}),'zero cache budget retains exact reference')
-- One frozen-decision scope shares cache across different sampled draw states.
s={phase='hand',hand={},deck={},jokers={},consumeables={},hands={},blind={chips=300},dollars=4,
  hand_size=8,hand_limit=5,hands_left=1,discards_left=3,chips=0,modifiers={},probabilities={normal=1}}
for i=1,8 do s.hand[i]=card(i,2+(i*3)%13,sets[i%4+1]) end
for i=9,40 do s.deck[#s.deck+1]=card(i,2+(i*3)%13,sets[i%4+1]) end
s.playing_cards={};for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end;for _,c in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=c end
cached,stats=Cache.new(C)
local before=Snap.fingerprint(s)
local options={samples=4,candidates=5,resource_samples=0,max_evaluations=10000}
local clock=os.clock();local reference=Search.run(s,C,options);local plain_time=os.clock()-clock
clock=os.clock();local reused=Search.run(s,cached,options);local cached_time=os.clock()-clock
eq(reference,reused,'full sampled decision is exactly equivalent')
eq(Snap.fingerprint(s),before,'input untouched across cache evaluation')
print('score cache: '..checks..' checks; hits '..stats().hits..'/'..stats().classify_calls..'; seconds '..plain_time..' -> '..cached_time)
local D=dofile('Brainstorm/Advisor/decision.lua')
local modules={search=Search,scoring=C,score_cache=Cache}
local normal=D.run(s,modules,nil,{search=options,prepared_scoring=false})
local prepared=D.run(s,modules,nil,{search=options})
assert(prepared.score_cache and prepared.score_cache.hits>0,'shared decision activates cache')
prepared.score_cache=nil
eq(prepared,normal,'whole decision unchanged by prepared scoring')
eq(modules.scoring,C,'decision wrapper does not mutate shared scorer module')
-- Packed keys preserve ordered ties, cardinality, rule flags and wildcard/stone
-- distinctions. Compare complete classifications against raw code in one cache.
local key_cache=Cache.new(C)
local function classified(s,indices,scorer)
  local category,indices,contains=scorer.classify(s,indices)
  return {category=category,indices=indices,contains=contains}
end
for _,jokers in ipairs(rows) do
  local state={jokers=jokers,hand={card(1,14,'Spades'),card(2,14,'Hearts'),
    card(3,2,'Spades','m_wild'),card(4,0,'Clubs','m_stone'),card(5,14,'Clubs'),card(6,3,'Diamonds')}}
  state.hand[3].debuff=true
  for _,indices in ipairs({{1},{1,2},{2,1},{1,2,5},{5,2,1},{4},{1,4},{1,2,3,4,5},{1,2,3,4,5,6}}) do
    eq(classified(state,indices,key_cache),classified(state,indices,C),'packed key preserves full ordered classification')
  end
end
for _,rank in ipairs({-1,1.5,15,1000000}) do
  local state={jokers={},hand={card(1,rank,'Spades'),card(2,14,'Hearts')}}
  eq(classified(state,{1,2},key_cache),classified(state,{1,2},C),'unpacked rank falls back without aliasing')
end
print('score cache packed-key coverage: '..checks..' total checks')

-- Capacity stays fixed and exact keys still remap relative positions after
-- saturation. A working set arriving late can now acquire cache entries.
local wrapped,measure=Cache.new(C,{max_entries=2})
local smallstates={}
for rank=2,6 do smallstates[#smallstates+1]={hand={card(rank,rank,'Spades')},jokers={}} end
for _,state in ipairs(smallstates) do eq(classified(state,{1},wrapped),classified(state,{1},C),'eviction parity') end
local hits=measure().hits
for _,state in ipairs({smallstates[4],smallstates[5]}) do eq(classified(state,{1},wrapped),classified(state,{1},C),'late working set parity') end
assert(measure().stored==2 and measure().evictions==3 and measure().hits==hits+2)
print('FIFO eviction: exact bounded late-working-set reuse passed')
