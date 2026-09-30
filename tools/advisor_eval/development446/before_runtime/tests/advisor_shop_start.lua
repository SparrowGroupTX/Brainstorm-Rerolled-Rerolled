local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
Shop.blind_start=dofile('Brainstorm/Advisor/blind_start.lua')
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
Shop.blind_prep=dofile('Brainstorm/Advisor/blind_prep.lua')
Shop.strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(x,s) checks=checks+1;assert(x,s) end
local function joker(id,key,a,sell)
  return {id=id,key=key,ability=a or {},sell_cost=sell or 2,blueprint_compat=true}
end
local function state()
  local s={phase='shop',jokers={},playing_cards={},hand_size=8,hand_limit=5,joker_limit=5,
    dollars=20,modifiers={},probabilities={normal=1},hands={},consumeables={},
    current_round={},round_resets={hands=4,discards=3},next_blind={key='bl_small',chips=300}}
  for i,r in ipairs({2,4,6,8,10,11,12,14}) do
    s.playing_cards[i]={id='p:'..i,rank=r,suit='Spades',nominal=math.min(r,10),ability={}}
  end
  return s
end
local s=state()
s.jokers={joker('dagger','j_ceremonial',{name='Ceremonial Dagger',mult=0,eternal=true}),
  joker('basic','j_joker',{name='Joker',mult=4}),joker('canio','j_caino',{name='Caino',caino_xmult=100,extra=1},10)}
s.jokers[1].pinned=true
local before=Snapshot.fingerprint(s)
local ctx=Shop.new(s,Scorer)
local e=ctx:compare(s,s)
check(e and e.ratio==1,'Pinned Dagger rows receive complete scoring evidence')
check(e.before_startup and #e.before_startup.samples==4,'All four projected starts are reviewable')
for _,sample in ipairs(e.before_startup.samples) do
  check(sample.removed[1]=='basic' and #sample.removed==1,'The same cheap victim is chosen before every draw, retaining mature Canio')
end
check(Snapshot.fingerprint(s)==before,'Projection does not mutate owned inventory')
check(e.reason:find('fixed pre-blind setup',1,true),'Evidence states pre-draw setup limitation')
local perkeo=Snapshot.copy(s)
perkeo.jokers[3]=joker('copying','j_perkeo',{name='Perkeo'},50);perkeo.jokers[3].rarity=4
local guarded=Shop.new(perkeo,Scorer):compare(perkeo,perkeo)
check(guarded~=nil,'Protected copying inventory row remains supported')
for _,sample in ipairs(guarded.before_startup.samples) do
  check(sample.removed[1]=='basic','Forecast cannot consume a new protected Perkeo victim for short-term Mult')
end
local after=Snapshot.copy(s);after.jokers[4]=joker('chips','j_sly',{name='Sly Joker',t_chips=50,type='Pair'})
check(ctx:compare(s,after)~=nil,'Actual new offers are compared after Dagger effects')
local reversed=Snapshot.copy(s);reversed.jokers[2],reversed.jokers[3]=reversed.jokers[3],reversed.jokers[2]
check(Shop.new(s,Scorer):compare(s,reversed).ratio==1,'Both rows get the same legal setup freedom')
local marble=state();marble.jokers={joker('marble','j_marble',{name='Marble Joker',eternal=true}),
  joker('holo','j_hologram',{name='Hologram',x_mult=2,extra=0.25})}
local counted=0
local inspect={score=function(t,indices)
  if counted==0 then
    check(#t.playing_cards==9 and #t.hand==8 and #t.deck==1,'Marble creates one real extra population member before drawing')
    local found=false;for _,j in ipairs(t.jokers) do if j.key=='j_hologram' then found=j.ability.x_mult==2.25 end end
    check(found,'Actual addition triggers Hologram growth before scoring')
    counted=1
  end
  return Scorer.score(t,indices)
end}
e=Shop.new(marble,inspect):compare(marble,marble)
check(e and e.uncertain and #e.before_startup.samples[1].generated==1,'Marble is sampled composition evidence, not a known future draw')
check(e.before_readiness.status=='unsupported','Sampled generation cannot establish a safe readiness claim')
local burglar=state();burglar.round_resets.hands=1
burglar.jokers={joker('burglar','j_burglar',{name='Burglar',extra=3})}
e=Shop.new(burglar,Scorer):compare(burglar,burglar)
check(e and e.before_readiness.hands==4 and e.before_readiness.discards==0,'Readiness uses post-Burglar hands and discards')
burglar.jokers[2]=joker('copy','j_blueprint',{name='Blueprint'})
e=Shop.new(burglar,Scorer):compare(burglar,burglar)
check(e and e.before_readiness.hands==4,'Unpublished Blueprint move cannot invent copied Burglar hands')
check(e.before_startup.order[1]==1 and e.before_startup.order[2]==2,'Non-Dagger startup uses the actual observed order')
Shop.blind_prep.blind_start=Shop.blind_start
e=Shop.new(burglar,Scorer):compare(burglar,burglar)
check(e and e.before_readiness.hands==7 and e.before_readiness.discards==0,'Wired executable setup adds the actual copied Burglar hands')
check(e.before_startup.order[1]==2 and e.before_startup.order[2]==1,'Shop forecasts the fixed reorder the product can actually publish')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local blind_state=Snapshot.copy(burglar);blind_state.phase='blind'
local action=Decision.run(blind_state,{blind_prep=Shop.blind_prep,strategy=Shop.strategy})
check(action.action.kind=='reorder_jokers' and table.concat(action.action.order,',')==table.concat(e.before_startup.order,','),
  'Actual preblind advice and projected scoring use the identical copy setup')
local fixed=Snapshot.copy(blind_state);fixed.jokers={blind_state.jokers[2],blind_state.jokers[1]}
check(not Shop.blind_prep.suggest(fixed,Shop.strategy),'Fresh advice never repeats the already completed setup')
burglar.jokers[2]=nil
burglar.next_blind={key='bl_needle',name='The Needle',chips=300,boss=true}
burglar.round_resets.hands=4;burglar.round_bonus={next_hands=2}
e=Shop.new(burglar,Scorer):compare(burglar,burglar)
check(e and e.before_readiness.hands==6,'Needle preserves bonus hands before Burglar adds its actual hands')
local unsupported=Snapshot.copy(s);unsupported.jokers[4]=joker('madness','j_madness',{name='Madness',x_mult=2})
check(not Shop.new(s,Scorer):compare(s,unsupported),'Unknown random blind-start effects still fail closed')
local limited=Shop.new(s,Scorer,nil,{max_evaluations=1})
check(not limited:compare(s,after) and limited.truncated and limited.evaluations==0,'Whole projected comparison is budgeted before any partial score')
local transformed=state();transformed.playing_cards[1].rank=13;transformed.playing_cards[1].nominal=10
e=Shop.new(state(),Scorer):compare(state(),transformed)
check(e~=nil,'An exact rank transformation can use paired population samples')
print('advisor_shop_start: '..checks..' checks passed')
