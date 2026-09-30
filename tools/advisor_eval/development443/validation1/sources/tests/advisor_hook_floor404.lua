-- Independent manufactured Hook outcomes; no recorded state or game execution.
local P='Brainstorm/Advisor/'
local S=dofile(P..'scoring.lua');local Q=dofile(P..'search.lua')
local Snap=dofile(P..'snapshot.lua');local Cache=dofile(P..'score_cache.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function card(i,r,s,e,seal)
 return {id='hook404:'..i,rank=r,nominal=math.min(r,10),suit=s,enhancement=e or 'c_base',seal=seal,
  ability=e=='m_lucky' and {mult=20,p_dollars=20} or {}}
end
local function state()
 local s={phase='hand',hand={card(1,13,'Spades','m_lucky'),card(2,9,'Clubs'),card(3,9,'Diamonds'),
  card(4,4,'Hearts'),card(5,2,'Spades')},deck={},playing_cards={},hands={},jokers={},consumeables={},
  hands_left=1,discards_left=0,discards_used=2,hand_limit=5,hand_size=5,chips=0,dollars=0,
  blind={key='bl_hook',chips=50},probabilities={normal=1},modifiers={},current_round={}}
 for i,c in ipairs(s.hand) do s.playing_cards[i]=c end;return s
end
math.random=function()error('No live RNG')end
local s=state();local original=Snap.fingerprint(s)
local wrapped,stats=Cache.new(S)
local pair,work=wrapped.hook_lower_bound(s,{2,3},3)
check(pair and pair.reliable_bound and pair.score==56,'all three Hook pairs preserve independent (10+9+9)*2')
check(work==3 and stats().score_calls==3 and pair.hook_outcomes==3,'all outcome scores explicitly charged through cache')
check(pair.scoring_indices[1]==2 and pair.scoring_indices[2]==3,'returned coordinates are original hand indices')
local lucky,n=S.hook_lower_bound(s,{1},6)
check(lucky and lucky.score==15 and n==6,'six Lucky outcomes retain no-trigger floor15')
local partial,used=S.hook_lower_bound(s,{2,3},2)
check(not partial and used==0,'insufficient complete-family allowance cannot certify a prefix')
local result=Q.run(s,wrapped,{max_evaluations=1000,fast_clear=false},function()end)
check(result.play.reliable_bound and result.play.score==56 and result.play.hand=='Pair','search chooses certified Pair over higher Lucky mean')
check(result.evaluations<=1000,'ordinary work remains bounded')
check(Snap.fingerprint(s)==original,'input purity')
s=state();s.hand[4].enhancement='m_steel';s.hand[4].seal='Red'
local steel=S.hook_lower_bound(s,{2,3},3)
check(steel and steel.score==56,'worst outcome removes Red-Seal Steel; no held boost is guaranteed')
s=state();s.hand[4].seal='Purple';s.consumable_limit=2
local purple,pu=S.hook_lower_bound(s,{2,3},3)
check(not purple and pu<=3,'unmodeled generated Tarot prevents certification')
s.consumeables={{key='c_star'},{key='c_sun'}}
check(S.hook_lower_bound(s,{2,3},3).score==56,'full inventory suppresses Purple generation consistently')
s=state();s.jokers={{key='j_yorick',ability={name='Yorick',x_mult=2,yorick_discards=1,extra={discards=5,xmult=1}}}}
check(S.hook_lower_bound(s,{2,3},3).score==168,'exact two unpaid discards cross Yorick threshold once:56*3')
s.jokers[1].ability.yorick_discards=3
check(S.hook_lower_bound(s,{2,3},3).score==112,'no threshold crossing:56*2')
s.jokers={{key='j_unknown404',ability={name='Unsupported404'}}}
check(not S.hook_lower_bound(s,{2,3},3),'unknown scoring remains unsupported')
s=state();s.hand[4].enhancement='m_glass'
local glass=S.hook_lower_bound(s,{2,3,4},1)
check(glass and glass.scoring_indices[1]==2,'one Hook outcome and non-scoring Glass retain original coordinates')
local tiny=Q.run(state(),S,{max_evaluations=5,fast_clear=false},function()end)
check(tiny.evaluations<=5,'small caller cap is not bypassed by Hook floor work')
print('advisor_hook_floor404: '..checks..' checks passed')

s=state();s.hand[2].enhancement='m_glass'
local exposure=S.hook_lower_bound(s,{2,3},3)
check(exposure.score==112 and exposure.glass_exposure[1].index==2 and exposure.glass_exposure[1].probability==.25,'played Glass exposure remaps to original physical index')
check(not S.hook_lower_bound(s,{2,3},0/0),'nonfinite allowance cannot admit an unbudgeted family')
print('advisor_hook_floor_total404: '..checks..' checks passed')

local charged=0;local scoped=setmetatable({}, {__index=S})
scoped.score=function(...)charged=charged+1;return S.score(...)end
scoped.lower_bound=function(...)charged=charged+1;return S.lower_bound(...)end
local scoped_result=Q.run(state(),scoped,{max_evaluations=1000,fast_clear=false},function()end)
check(scoped_result.evaluations==charged,'Hook invokes caller floor wrapper so outer aggregate budget sees every score')
print('advisor_hook_scoped_total404: '..checks..' checks passed')

-- Manufactured scorer isolates proof-work accounting from hand strength.
-- Actual Hook transition still enumerates every possible two-card discard.
do
 local big=state();big.hand={};big.playing_cards={};big.hand_size=12
 for i=1,12 do big.hand[i]=card(i,i+1,'Clubs');big.playing_cards[i]=big.hand[i] end
 for _,immediate in ipairs({false,true}) do
  local charged,floors=0,0
  local stub={hook_lower_bound=S.hook_lower_bound}
  function stub.score(_,indices)
   charged=charged+1
   return {score=100,legal=true,uncertain=not (immediate and #indices==1),hand='High Card',warnings={}}
  end
  function stub.lower_bound(_,indices)
   charged=charged+1;floors=floors+1
   return {score=#indices>=5 and 100 or 10,legal=true,uncertain=false,reliable_bound=true,hand='High Card',warnings={}}
  end
  local r=Q.run(big,stub,{max_evaluations=1000},function()end)
  check(r.fast_clear and r.play.score>=50 and not r.play.uncertain,'large-hand complete proof or initial deterministic clear')
  check(r.evaluations==charged and charged<=48,'shortlist and conservation respect shared32+16 score ceiling')
  check(r.fast_clear.clear_found_at<=32 and r.fast_clear.conservation_evaluations<=16,'both phase-local ceilings enforced')
  check(immediate and floors==0 or not immediate and floors==21,'indivisible55-call singletons deferred; only complete21-call family admitted')
 end
end
print('advisor_hook_phase_limits404: '..checks..' checks passed')
