local S=dofile('Brainstorm/Advisor/search.lua')
local C=dofile('Brainstorm/Advisor/scoring.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local function card(i,r) return {id=i,rank=r,suit='Spades',ability={},enhancement='c_base'} end
local s={phase='hand',hand={card(1,13),card(2,2),card(3,3)},deck={},jokers={{key='j_baron',ability={name='Baron',extra=1.5}}},
  hands={},hand_limit=5,hand_size=3,hands_left=3,discards_left=0,blind={chips=10},chips=0,modifiers={debuff_played_cards=true},ante=2}
s.playing_cards=s.hand
local before=Snap.fingerprint(s);local p=S.population_profile(s)
local a,u,l=S.population_cost(s,{scoring_indices={1}},p)
local b=S.population_cost(s,{scoring_indices={2}},p)
check(a>b and u==2 and l==1,'preserve Kings engine with usable-population accounting')
local overlap,_,lost=S.population_cost(s,{scoring_indices={1},glass_exposure={{index=1,probability=1}}},p)
check(overlap==a and lost==1,'Glass plus permanent debuff is one lost resource')
local result=S.run(s,C)
check(result.fast_clear and result.play.indices[1]~=1,'bounded clear conserves useful King even when it overkills')
check(result.play.population_loss==1,'chosen loss is visible')
check(Snap.fingerprint(s)==before,'population accounting does not mutate snapshot')
s.hand[1].ability.perma_debuff=true;p=S.population_profile(s)
check(p.usable==2 and S.population_cost(s,{scoring_indices={1}},p)==0,'previously lost cards have no new loss')
check(S.population_cost(s,{scoring_indices={2},indices={1,2,3}},p)==S.population_cost(s,{scoring_indices={2}},p),'unscored cycling cards do not become permanent-debuff losses')
s.hand[1].ability.perma_debuff=nil;s.hand[1].debuff=true;p=S.population_profile(s)
check(p.usable==3,'temporary boss debuff is not permanent resource loss')
s.modifiers={};s.hand[1].debuff=nil
local risk=S.population_cost(s,{scoring_indices={1},glass_exposure={{index=1,probability=0.25}}},p)
check(risk>0 and risk<a,'fractional Glass risk remains fractional, never certain destruction')
s.ante=8;s.blind.boss=true
check(S.population_cost(s,{scoring_indices={1},glass_exposure={{index=1,probability=1}}},p)==0,'no future population charge after final boss win')
print('advisor_population_conservation: '..n..' checks passed')
