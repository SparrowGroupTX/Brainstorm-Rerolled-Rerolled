local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
S.consumables=dofile('Brainstorm/Advisor/consumables.lua')
S.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function joker(key,a,cost)
  a=a or {};a.set='Joker'
  return {key=key,ability=a,cost=cost or 3,sell_cost=1}
end
local function state()
  local s={phase='shop',ante=2,dollars=3,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    hand_size=8,hand_limit=5,jokers={},consumeables={},hands={Flush={level=1,played=5}},
    round_resets={hands=1,discards=3},current_round={},playing_cards={},
    next_blind={key='bl_small',chips=500},next_blind_chips=500,
    probabilities={normal=1},modifiers={},shop_jokers={},shop_booster={},shop_vouchers={}}
  for i,r in ipairs({2,4,6,8,10,11,12,14}) do
    s.playing_cards[i]={id='r'..i,rank=r,suit='Hearts',ability={}}
  end
  return s
end
local modules={strategy=S,scoring=Scorer,shop_scoring=Shop,consumables=S.consumables}
do
  local s=state();local fingerprint=Snap.fingerprint(s)
  local ctx=Shop.new(s,Scorer);local r=ctx:readiness(s)
  check(r.status=='sampled_deficit' and r.hands==1 and r.discards==3,'one-hand scoring pressure uses real resources')
  check(r.opening_max<500 and r.reason:find('not a global score bound',1,true),'sample capacity is explicitly not an upper bound')
  local count=ctx.evaluations;local e=ctx:compare(s,s)
  check(ctx.evaluations==count and e.before_readiness.status==r.status,'readiness and paired baseline share complete profiles')
  check(ctx.metrics.profile_cache_hits>=2,'reused scoring work is counted')
  check(Snap.fingerprint(s)==fingerprint,'readiness leaves source snapshot intact')
  s.round_resets.hands=4
  r=Shop.new(s,Scorer):readiness(s)
  check(r.status=='unresolved','multiplying an opening score across hands does not manufacture a safe finish')
  s.next_blind={key='bl_needle',boss=true,chips=500}
  r=Shop.new(s,Scorer):readiness(s)
  check(r.status=='sampled_deficit' and r.hands==1,'Needle removes extra hands before readiness')
  s.next_blind={key='bl_water',boss=true,chips=500}
  r=Shop.new(s,Scorer):readiness(s)
  check(r.discards==0,'Water cannot promise discard opportunities')
end
do
  local s=state()
  s.shop_jokers={joker('j_hologram',{x_mult=1,extra=0.25}),
    {key='c_jupiter',cost=3,ability={set='Planet',name='Jupiter',consumeable={hand_type='Flush'}}}}
  local old=Snap.fingerprint(s);local result=D.run(s,modules)
  check(result.action.kind=='buy' and result.action.index==2,'limited cash prioritizes a useful immediate Planet over unscaled growth')
  check(result.strategy.scoring_evidence.planet_use and result.strategy.scoring_evidence.timely_scoring,
    'Planet evidence includes actual level use and current scoring benefit')
  check(result.strategy.scoring_evidence.after_mean>=500,'the purchased Planet supplies the sampled missing score')
  check(Snap.fingerprint(s)==old,'shop advice preserves cash, levels, offers and inventory')
  local repeat_result=D.run(s,modules)
  check(Snap.fingerprint(result)==Snap.fingerprint(repeat_result),'the entire readiness decision is deterministic')
  s.dollars=2;result=D.run(s,modules)
  check(result.action.kind~='buy','a credible improvement does not authorize unaffordable buying')
end
do
  local s=state();s.jokers={joker('j_joker',{mult=40},0)}
  s.shop_jokers={joker('j_golden',{extra=4})}
  local r=D.run(s,modules)
  check(r.strategy.readiness.status=='sampled_safe','strong opening builds retain a sampled margin')
  check(r.action.kind=='buy','a safe build can still buy a worthwhile income investment')
  s.shop_jokers={};r=D.run(s,modules)
  check(r.action.kind=='leave_shop','safe builds can save instead of chasing unnecessary purchases')
end
do
  for _,key in ipairs({'bl_house','bl_mark','bl_wheel','bl_hook'}) do
    local s=state();s.next_blind={key=key,boss=true,chips=1};s.jokers={joker('j_joker',{mult=100})}
    check(Shop.new(s,Scorer):readiness(s).status=='unsupported','concealed or unsupported boss '..key..' cannot promise safety')
  end
  local s=state();s.jokers={joker('j_unknown',{mult=100})}
  check(Shop.new(s,Scorer):readiness(s).status=='unsupported','unknown effects remain explicit')
  s=state();s.playing_cards={s.playing_cards[1]};s.round_resets.hands=4
  local r=Shop.new(s,Scorer):readiness(s)
  check(r.hands==1 and r.status=='sampled_deficit','depleted populations cannot invent four playable hands')
  local old=S.advise(s);local result=D.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
  check(result.shop_diagnostics.truncated and result.action.kind==old.action.kind,'incomplete readiness falls back with the whole comparison')
end
print('advisor_readiness: '..checks..' checks passed')
