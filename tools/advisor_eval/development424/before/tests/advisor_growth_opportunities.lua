local V=dofile('Brainstorm/Advisor/conditional_value.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(a,label) checks=checks+1;assert(a,label) end
local names={j_credit_card='Credit Card',j_devious='Devious Joker',j_trousers='Spare Trousers',j_square='Square Joker',j_runner='Runner',j_green_joker='Green Joker'}
local function joker(key,cost,a) a=a or {};a.set='Joker';a.name=names[key];return {key=key,cost=cost or 0,ability=a,sell_cost=2} end
local row={j_trousers=joker('j_trousers',6,{mult=0,extra=2}),
  j_square=joker('j_square',4,{extra={chips=0,chip_mod=4}}),
  j_runner=joker('j_runner',5,{extra={chips=0,chip_mod=15}}),
  j_green_joker=joker('j_green_joker',4,{mult=0,extra={hand_add=1,discard_sub=1}})}
local r={supported=true,status='unresolved',hands=1,discards=5,samples=4,target=600,clearing_samples=1,
  opening_scores={90,680,40,90},opening_hands={'Two Pair','Straight','Pair','Two Pair'},opening_sizes={5,5,5,5}}
local state={phase='shop',ante=2,dollars=14,jokers={},consumeables={},next_blind={key='bl_big'}}
local function value(key,ready) return V.assess(state,row[key],{base_value=58,readiness=ready or r}) end
local trousers=value('j_trousers')
eq(trousers.opening_trigger_samples,2,'weak Two Pair samples are real triggers')
eq(trousers.clearing_trigger_samples,0,'weak samples do not become timely clearing opportunities')
eq(trousers.clearing_trigger_conflicts,1,'the observed clear cannot trigger Trousers')
eq(trousers.adjustment,-30,'existing bounded unscaled-growth discount')
check(trousers.reason:find('alternative draws or plays remain unresolved',1,true),'conflict is not proof no alternative finish exists')
eq(value('j_square').adjustment,-30,'five-card clearing play cannot trigger Square')
eq(value('j_runner').adjustment,0,'matching Runner investment remains')
eq(value('j_runner').timely_opportunities,1,'Runner matches observed clearing play')
eq(value('j_green_joker').adjustment,0,'Green grows before any clearing play')
local mixed=Snapshot.copy(r);mixed.opening_scores[1]=650;mixed.clearing_samples=2
eq(value('j_trousers',mixed).adjustment,-15,'mixed clearing routes discount only known conflicts')
eq(value('j_runner',mixed).adjustment,-15,'symmetric trigger weighting across hand types')
local four=Snapshot.copy(r);four.opening_sizes[2]=4
eq(value('j_square',four).adjustment,0,'a real four-card clearing Straight can grow Square')
local safe=Snapshot.copy(r);safe.status='sampled_safe'
eq(value('j_square',safe).adjustment,0,'safe investment is preserved')
local margin=Snapshot.copy(r);margin.opening_scores={650,680,650,650};margin.clearing_samples=4
eq(value('j_square',margin).adjustment,0,'all sampled openings clear despite unresolved margin')
local multi=Snapshot.copy(r);multi.hands=2
eq(value('j_square',multi).adjustment,0,'no imaginary multi-hand survival conflict')
local missing=Snapshot.copy(r);missing.opening_scores=nil
eq(value('j_square',missing).adjustment,0,'legacy aggregate metadata cannot identify the clearing play')
local mismatch=Snapshot.copy(r);mismatch.clearing_samples=2
eq(value('j_square',mismatch).adjustment,0,'inconsistent sample metadata fails closed')
local unknown=Snapshot.copy(r);unknown.supported=false
eq(value('j_square',unknown).adjustment,0,'unsupported mechanics do not create a conflict')
local flush=Snapshot.copy(r);flush.opening_hands[2]='Flush'
eq(value('j_trousers',flush).adjustment,0,'Flush may contain Two Pair; dominant label is insufficient')
eq(value('j_trousers',flush).clearing_trigger_unknown,1,'embedded-hand ambiguity stays explicit')
row.j_trousers.ability.mult=8
eq(value('j_trousers').adjustment,0,'mature Mult survives a mismatched growth trigger')
row.j_trousers.ability.mult=0
for _,key in ipairs({'j_perkeo','j_yorick','j_burnt'}) do
  eq(V.assess(state,joker(key),{base_value=58,readiness=r}),nil,key..' established development is untouched')
end

-- End-to-end shop policy regression on a plain known deck and one-hand budget.
-- No challenge name, source seed, future cards, or fabricated scoring context.
local s={phase='shop',ante=1,dollars=13,bankrupt_at=-20,joker_limit=5,consumable_limit=2,
  jokers={joker('j_credit_card',0,{extra=20}),joker('j_devious',0,{t_chips=100,type='Straight'})},
  consumeables={},playing_cards={},hand={},deck={},shop_booster={},shop_vouchers={},
  shop_jokers={Snapshot.copy(row.j_square),Snapshot.copy(row.j_trousers)},
  round_resets={hands=1,discards=6},current_round={},hand_size=8,hand_limit=5,
  hands={Straight={level=1,played=2}},modifiers={},probabilities={normal=1},reroll_cost=5,
  next_blind={key='bl_head',name='The Head',boss=true,chips=600,debuff={suit='Hearts'}}}
-- Vanilla front-key order: 2..9, A, J, K, Q, T.
for _,suit in ipairs({'Clubs','Diamonds','Hearts','Spades'}) do for _,rank in ipairs({2,3,4,5,6,7,8,9,14,11,13,12,10}) do
  local i=#s.playing_cards+1
  s.playing_cards[i]={id='playing:'..i,rank=rank,suit=suit,ability={}}
end end
local modules={strategy=S,scoring=Scoring,shop_scoring=Shop}
local before=Snapshot.fingerprint(s)
S.conditional_value=nil
local old=D.run(s,modules)
S.conditional_value=V
local actual=D.run(s,modules)
eq(old.action.kind,'buy','unweighted growth policy buys')
eq(old.action.index,2,'unweighted policy prefers Trousers')
eq(actual.strategy.readiness.status,'unresolved','real paired profile has unresolved survival')
eq(actual.strategy.readiness.clearing_samples,1,'one actual sampled opening clear')
eq(actual.action.kind,'leave_shop','growth conflict policy preserves money for timely scoring')
check(actual.evaluations>0 and not actual.shop_diagnostics.truncated,'full scoring comparisons complete')
eq(actual.evaluations,old.evaluations,'opportunity metadata does not enlarge scoring budget')
eq(Snapshot.fingerprint(s),before,'full policy leaves input unchanged')
eq(Snapshot.fingerprint(D.run(s,modules)),Snapshot.fingerprint(actual),'full policy is deterministic')
s.shop_jokers={Snapshot.copy(row.j_runner)}
local aligned=D.run(s,modules)
check(aligned.strategy.readiness.opening_scores[2]>=600,'paired score identifies the clearing sample')
eq(V.assess(s,s.shop_jokers[1],{base_value=58,readiness=aligned.strategy.readiness}).adjustment,0,
  'actual straight clearing plan preserves aligned Runner utility')
print('advisor growth opportunities: '..checks..' checks passed')
