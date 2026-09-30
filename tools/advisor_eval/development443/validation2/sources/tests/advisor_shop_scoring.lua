local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(condition,message) checks=checks+1; assert(condition,message) end
local function copy(x) return Snapshot.copy(x) end
local function card(rank,suit,index,enhancement)
  return {id='playing:'..index,rank=rank,suit=suit or 'Spades',nominal=math.min(rank,10),
    enhancement=enhancement or 'c_base',ability={}}
end
local function joker(key,label,a,more)
  local j={key=key,name=label,ability=a or {},sell_cost=2,blueprint_compat=true}
  j.ability.name=label
  for k,v in pairs(more or {}) do j[k]=v end
  return j
end
local function state()
  local s={phase='shop',playing_cards={},jokers={},hand={},deck={},dollars=25,hand_size=8,hand_limit=5,
    joker_limit=5,hands={},modifiers={},probabilities={normal=1},consumeables={},used_vouchers={},
    current_round={hands_left=1,discards_left=0,hands_played=3},round_resets={hands=4,discards=3},
    hands_left=1,discards_left=0,hands_played=3,blind={key='bl_flint',name='The Flint'}}
  for i,r in ipairs({2,4,6,8,10,11,12,14}) do s.playing_cards[i]=card(r,({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],i) end
  return s
end
local function add(s,j,cost)
  local a=copy(s); a.jokers[#a.jokers+1]=j; a.dollars=a.dollars-(cost or 0); return a
end
local old_random,old_seed=math.random,math.randomseed
math.random=function() error('Shop scoring advanced game RNG') end
math.randomseed=function() error('Shop scoring reseeded game RNG') end
local s=state()
local flat=add(s,joker('j_joker','Joker',{mult=4}),2)
local inactive=add(s,joker('j_trio','The Trio',{x_mult=3,type='Three of a Kind'}),2)
local yields=0
local ctx=Shop.new(s,Scorer,function() yields=yields+1 end)
local flat_e=ctx:compare(s,flat)
local inactive_e=ctx:compare(s,inactive)
check(flat_e and inactive_e and flat_e.ratio>inactive_e.ratio and flat_e.adjustment>inactive_e.adjustment,
  'real opening scores prefer usable flat Mult over an impossible three-of-a-kind XMult condition')
check(inactive_e.ratio==1 and inactive_e.adjustment<0,'nonfunctional tactical Joker receives no fabricated XMult gain')
check(flat_e.samples==4 and flat_e.after_mean>flat_e.before_mean,'four complete paired draws report an actual mean improvement')
check(flat_e.reason:find('estimate',1,true) and flat_e.reason:find('neutral blind',1,true),'evidence states its estimate and neutral-blind scope')
check(yields>0 and ctx.evaluations<=50000,'bounded scorer cooperatively yields without exceeding its shared budget')
local count=ctx.evaluations
check(ctx:compare(s,flat).ratio==flat_e.ratio and ctx.evaluations==count,'repeated equivalent comparison reuses cached rows')
local stale=copy(s); stale.hands_left=0; stale.current_round.hands_left=0; stale.current_round.hands_played=99
stale.hands_played=99; stale.shop_jokers={{key='unrelated'}}; stale._shop_scoring={context=ctx}
check(ctx:compare(stale,flat).ratio==flat_e.ratio and ctx.evaluations==count,
  'cache ignores shop metadata/private context and counters that fresh-round preparation resets')
local again=Shop.new(s,Scorer):compare(s,flat)
check(Snapshot.fingerprint(again)==Snapshot.fingerprint(flat_e),'independent contexts are deterministic')
local reversed=copy(s); reversed.deck=copy(reversed.playing_cards)
local reordered={}; for i=#reversed.playing_cards,1,-1 do reordered[#reordered+1]=reversed.playing_cards[i] end
reversed.playing_cards=reordered
local shuffled_e=Shop.new(reversed,Scorer):compare(reversed,add(reversed,joker('j_joker','Joker',{mult=4}),2))
check(shuffled_e.ratio==flat_e.ratio,'results depend on owned composition, not deck or input array order')

local mult_build=add(s,joker('j_joker','Joker',{mult=40}))
local chips=add(mult_build,joker('j_stuntman','Stuntman',{extra={chip_mod=250,h_size=2}})); chips.hand_size=6
local more_mult=add(mult_build,joker('j_joker','Joker',{mult=4}))
ctx=Shop.new(mult_build,Scorer)
check(ctx:compare(mult_build,chips).ratio>ctx:compare(mult_build,more_mult).ratio,
  'a Mult-heavy build values real complementary Chips despite Stuntman hand-size loss')
local cash=copy(mult_build); cash.modifiers={chips_dollar_cap=true}; cash.dollars=40
local bankrupt=add(cash,joker('j_joker','Joker',{mult=4}),40)
local loss=Shop.new(cash,Scorer):compare(cash,bankrupt)
check(loss and loss.after_mean==0 and loss.ratio==0 and loss.adjustment==-35,
  'Rich Get Richer scores the actual cash after buying and detects a destroyed chip cap')

local raw=copy(s); raw.current_round.ancient_card={suit='Hearts'}; raw.current_round.idol_card={id=12,suit='Diamonds'}
raw.hands.Pair={chips=10,mult=2,level=1,played=9,played_this_round=3}
raw.playing_cards[1].debuff=true; raw.playing_cards[1].ability.forced_selection=true
raw.playing_cards[2].debuff=true; raw.playing_cards[2].ability.perma_debuff=true
local inspected=0
local wrapped={score=function(snapshot,indices)
  inspected=inspected+1
  check(snapshot.hands_left==4 and snapshot.discards_left==3 and snapshot.hands_played==0,'shop counters reset to actual fresh-round resources')
  check(snapshot.hands.Pair.played==9 and snapshot.hands.Pair.played_this_round==0,'hand levels and lifetime usage survive per-round reset')
  check(snapshot.current_round.ancient_card.suit=='Hearts' and snapshot.current_round.idol_card.id==12,'known next-round suit/rank conditions remain authoritative')
  check(snapshot.blind.disabled and #snapshot.hand==8 and #snapshot.deck==0,'finished blind restrictions are removed and remaining deck excludes drawn cards')
  for _,c in ipairs(snapshot.hand) do
    if c.id=='playing:1' then check(not c.debuff and not c.ability.forced_selection,'temporary card restrictions are cleared') end
    if c.id=='playing:2' then check(c.debuff,'permanent challenge debuffs remain') end
  end
  return Scorer.score(snapshot,indices)
end}
-- Inspect one actual score then use the ordinary scorer for the remaining calls.
local inspect_once={score=function(snapshot,indices)
  if inspected==0 then return wrapped.score(snapshot,indices) end
  return Scorer.score(snapshot,indices)
end}
local original=Snapshot.fingerprint(raw)
check(Shop.new(raw,inspect_once):compare(raw,add(raw,joker('j_joker','Joker',{mult=4})))~=nil,'fresh-round normalization produces legal scoring evidence')
check(Snapshot.fingerprint(raw)==original,'sampling and normalization never mutate the original snapshot')

local ordinary=state()
local unknown=add(ordinary,joker('j_custom_modded','Unmodeled Custom',{x_mult=999}))
ctx=Shop.new(ordinary,Scorer)
check(ctx:compare(ordinary,unknown)==nil and ctx.evaluations==0 and not ctx.truncated,
  'unknown effects fall back even if their generic XMult field appears strong')
local no_target=Shop.new(ordinary,Scorer):compare(ordinary,add(ordinary,joker('j_blueprint','Blueprint',{})))
check(no_target and no_target.ratio==1,
  'a Blueprint without any target receives no fabricated copying gain')
for _,entry in ipairs({{'j_ceremonial','Ceremonial Dagger'},{'j_madness','Madness'},{'j_burglar','Burglar'},
  {'j_hit_the_road','Hit the Road'}}) do
  check(Shop.new(ordinary,Scorer):compare(ordinary,add(ordinary,joker(entry[1],entry[2],{})))==nil,
    'unsupported temporal/start-blind changes retain old strategy: '..entry[2])
end
local oversized=copy(ordinary); oversized.hand_size=11
check(Shop.new(ordinary,Scorer):compare(ordinary,oversized)==nil,'large hand sizes fall back rather than silently clipping cards')
local empty=copy(ordinary); empty.playing_cards={}
check(Shop.new(empty,Scorer):compare(empty,add(empty,joker('j_joker','Joker',{mult=4})))==nil,'missing deck data is not replaced with a fabricated standard deck')

local limited=Shop.new(ordinary,Scorer,nil,{max_evaluations=1})
check(limited:compare(ordinary,add(ordinary,joker('j_joker','Joker',{mult=4})))==nil and limited.truncated and limited.evaluations==0,
  'insufficient budget publishes no partial paired estimate')
limited=Shop.new(ordinary,Scorer,nil,{max_evaluations=2000})
check(limited:compare(ordinary,add(ordinary,joker('j_joker','Joker',{mult=4})))~=nil,'first complete pair fits bounded shared budget')
local used=limited.evaluations
check(limited:compare(ordinary,add(ordinary,joker('j_joker','Joker',{mult=8})))==nil and limited.truncated and limited.evaluations==used,
  'later comparisons share the same budget and trigger whole-decision fallback without partial work')

local swash=state(); swash.joker_limit=2
swash.jokers={joker('j_swashbuckler','Swashbuckler',{mult=60}),joker('j_egg','Egg',{}, {sell_cost=60})}
local sold=copy(swash); sold.jokers[2]=joker('j_joker','Joker',{mult=4}); sold.dollars=85
local e=Shop.new(swash,Scorer):compare(swash,sold)
check(e and e.ratio<0.3,'selling an Egg removes its cached Swashbuckler Mult in the projected whole row')
local stencil=state(); stencil.joker_limit=3; stencil.jokers={joker('j_stencil','Joker Stencil',{x_mult=3})}
local stuffed=add(stencil,joker('j_egg','Egg',{}))
e=Shop.new(stencil,Scorer):compare(stencil,stuffed)
check(e and math.abs(e.ratio-2/3)<0.000001,'filling a Stencil slot recomputes its stale XMult from final capacity')

local steel=state()
for _,c in ipairs(steel.playing_cards) do c.enhancement='m_steel' end
e=Shop.new(steel,Scorer):compare(steel,add(steel,joker('j_steel_joker','Steel Joker',{steel_tally=0,extra=0.2})))
check(e and e.ratio>2,'a new Steel Joker uses the actual deck tally rather than a stale zero cache')
local ordered=state(); ordered.jokers={joker('j_ramen','Ramen',{x_mult=2}),joker('j_joker','Joker',{mult=4})}
local normalized=copy(ordered); normalized.jokers={normalized.jokers[2],normalized.jokers[1]}
e=Shop.new(ordered,Scorer):compare(ordered,normalized)
check(e and e.ratio==1,'baseline and candidate both get the same sensible-order freedom')
ordered.jokers[1].pinned=true
e=Shop.new(ordered,Scorer):compare(ordered,add(ordered,joker('j_joker','Joker',{mult=4})))
check(e~=nil,'pinned positions remain usable under the constrained order comparison')
local full=state(); full.playing_cards={}
for _,suit in ipairs({'Hearts','Clubs','Spades','Diamonds'}) do
  for rank=2,14 do full.playing_cards[#full.playing_cards+1]=card(rank,suit,#full.playing_cards+1) end
end
local bigger=add(full,joker('j_juggler','Juggler',{})); bigger.hand_size=10
local observed={}
local full_scorer={score=function(snapshot,selected)
  local n=#snapshot.hand
  check(n==8 or n==10,'given hand size determines each actual sample')
  check(#snapshot.deck==52-n,'Blue Joker receives the true remaining-deck count after this sampled draw')
  local ids={}; for _,c in ipairs(snapshot.hand) do ids[#ids+1]=c.id end
  observed[n]=observed[n] or {}; observed[n][table.concat(ids,',')]=true
  return Scorer.score(snapshot,selected)
end}
-- Observe each hand/size pair once, avoiding thousands of duplicate assertions.
local seen={}
local count_once={score=function(snapshot,selected)
  local ids={}; for _,c in ipairs(snapshot.hand) do ids[#ids+1]=c.id end
  local key=table.concat(ids,',')
  if not seen[key] then seen[key]=true; return full_scorer.score(snapshot,selected) end
  return Scorer.score(snapshot,selected)
end}
e=Shop.new(full,count_once):compare(full,bigger)
check(e and e.samples==4,'ten-card hands are completely scored within the supported bound')
local n8,n10=0,0; for _ in pairs(observed[8]) do n8=n8+1 end; for _ in pairs(observed[10]) do n10=n10+1 end
check(n8==4 and n10==4,'four distinct representative draws are paired at both hand sizes')
for first in pairs(observed[8]) do
  local paired=false
  for second in pairs(observed[10]) do if second:sub(1,#first+1)==first..',' then paired=true end end
  check(paired,'larger hands use prefixes of the same paired permutation, not fresh lucky samples')
end
local zero=state(); zero.modifiers={chips_dollar_cap=true}; zero.dollars=0
ctx=Shop.new(zero,Scorer)
check(ctx:compare(zero,add(zero,joker('j_joker','Joker',{mult=4})))==nil and not ctx.truncated,
  'a zero-score baseline falls back without inventing an infinite scoring ratio')
local mystery=state(); mystery.playing_cards[1].enhancement='m_custom_unknown'
check(Shop.new(mystery,Scorer):compare(mystery,add(mystery,joker('j_joker','Joker',{mult=4})))==nil,
  'unmodeled playing-card effects disable the whole paired estimate')
local probabilistic=state()
for _,c in ipairs(probabilistic.playing_cards) do c.suit='Hearts' end
probabilistic.jokers={joker('j_bloodstone','Bloodstone',{extra={odds=2,Xmult=1.5}})}
local luckier=add(probabilistic,joker('j_oops','Oops! All 6s',{})); luckier.probabilities.normal=2
e=Shop.new(probabilistic,Scorer):compare(probabilistic,luckier)
check(e and e.ratio>1 and e.uncertain,'explicit changed probabilities affect random scoring without being called guaranteed outcomes')
math.random,math.randomseed=old_random,old_seed
print('advisor_shop_scoring: '..checks..' checks passed')
