-- Manufactured fixed-row cost/accounting checks only, with a synthetic scorer.
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,msg)checks=checks+1;assert(v,msg)end
local function eq(a,b,msg)check(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(x)return Snapshot.copy(x)end
local function state(size)
  local s={phase='shop',playing_cards={},jokers={},dollars=25,hand_size=size or 8,hand_limit=5,
    joker_limit=5,hands={},modifiers={},probabilities={normal=1},consumeables={},used_vouchers={},
    current_round={},round_resets={hands=4,discards=3},next_blind={key='bl_small',name='Small Blind',chips=50}}
  for i=1,12 do s.playing_cards[i]={id='manufactured:'..i,rank=2+(i-1)%13,
    nominal=math.min(2+(i-1)%13,10),suit=({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],ability={}}end
  return s
end
local function joker(id)
  return {id=id,key='j_joker',name='Joker',ability={name='Joker',set='Joker',mult=4},sell_cost=2,blueprint_compat=true}
end
local function setup(s,cap,fixed,fail)
  local calls,yields=0,0
  local scorer={score=function()
    calls=calls+1;if fail then return nil end
    return {score=100,legal=true,uncertain=false,hand='High Card',warnings={}}
  end}
  return Shop.new(s,scorer,function()yields=yields+1 end,
    {max_evaluations=cap,current_order_opening_only=fixed~=false}),function()return calls,yields end
end
math.random=function()error('Preflight must not use RNG')end
math.randomseed=function()error('Preflight must not reseed RNG')end

do
  local s=state();local p=copy(s);p.jokers={joker('owned:1')}
  local ctx,count=setup(s,1744);local before=Snapshot.fingerprint({s,p})
  local r=ctx:preflight_family({s,p,s,copy(p)})
  check(r.complete and r.supported and r.fits,'all unique complete fixed-row endpoints fit exactly')
  eq(r.required_evaluations,1744,'two eight-card profiles cost 2*4*218')
  eq(r.available_evaluations,1744,'full remaining allowance')
  eq(r.unique_profiles,2,'duplicate prepared keys coalesce')
  eq(r.cached_profiles,0,'no completed profile yet');eq(r.uncached_profiles,2,'two unscored profiles')
  local calls,yields=count();eq(calls,0,'preflight calls no scorer');eq(yields,0,'preflight never yields')
  eq(ctx.evaluations,0,'preflight charges no scores');eq(ctx.truncated,false,'preflight does not truncate')
  eq(Snapshot.fingerprint({s,p}),before,'preflight preserves all supplied states')
  check(ctx:compare(s,s),'baseline completes normally')
  eq(ctx.evaluations,872,'hold profile scored once')
  r=ctx:preflight_family({s,p,copy(s)})
  eq(r.unique_profiles,2,'family retains cached and uncached identities')
  eq(r.cached_profiles,1,'completed baseline reused');eq(r.required_evaluations,872,'only new endpoint charged prospectively')
  eq(r.available_evaluations,872,'actual prior work subtracted');check(r.fits,'remaining profile fits exactly')
  check(ctx:compare(s,p),'paid endpoint completes');eq(ctx.evaluations,1744,'predicted work equals actual calls')
  r=ctx:preflight_family({s,p});check(r.fits,'fully cached family fits with zero budget remaining')
  eq(r.required_evaluations,0,'fully cached profiles require no calls');eq(r.available_evaluations,0,'no budget silently renewed')
  eq(r.cached_profiles,2,'both profiles reused');eq(count(),1744,'all actual work counted')
end
do
  local s=state();local p=copy(s);p.jokers={joker('owned:1')}
  local ctx,count=setup(s,1743)
  local r=ctx:preflight_family({s,p})
  check(r.complete and r.supported and not r.fits,'complete expensive family is declined before scoring')
  eq(r.required_evaluations,1744,'one-call shortage is exact');eq(count(),0,'failed budget preflight spends nothing')
  eq(ctx.truncated,false,'caller can select a complete smaller family')
  local fallback=ctx:preflight_family({s,s})
  check(fallback.fits,'smaller fixed family fits without renewing budget')
  check(ctx:compare(s,s),'existing fallback comparison remains usable')
  eq(count(),872,'fallback only actual calls');eq(ctx.truncated,false,'failed preflight did not poison context')
  r=ctx:preflight_family({s,p})
  eq(r.required_evaluations,872,'cached hold excluded after fallback');eq(r.available_evaluations,871,'prior work still charged')
  check(not r.fits,'no budget renewal after fallback')
end
do
  local s=state();local ctx,count=setup(s,50000,false)
  local r=ctx:preflight_family({s})
  check(not r.complete and not r.supported and not r.fits,'ordinary/finishing contexts explicitly outside method scope')
  eq(count(),0,'wrong mode never scores');eq(ctx.truncated,false,'wrong mode leaves existing context usable')
end
do
  local s=state();local ctx,count=setup(s,50000)
  for _,bad in ipairs({{},false,{[2]=s},{s,label=true},{setmetatable({}, {})},{false},{{jokers=false}}})do
    local r=ctx:preflight_family(bad)
    check(not r.complete and not r.supported and not r.fits,'malformed declared family stays explicit')
    eq(count(),0,'malformed family never scores');eq(ctx.truncated,false,'malformed family does not exhaust budget')
  end
  local p=copy(s);p.jokers={{key='j_unknown'}}
  local r=ctx:preflight_family({s,p})
  check(not r.complete and not r.supported and not r.fits,'unsupported later endpoint invalidates entire preflight')
  check(type(r.reason)=='string' and #r.reason>0,'unsupported endpoint has a reason')
  eq(count(),0,'no early prefix is scored');eq(ctx.evaluations,0,'unsupported prefix is uncharged')
  check(ctx:preflight_family({s}).fits,'supported family remains available after unsupported state')
end
do
  local s=state();local ctx,count=setup(s,50000,true,true)
  check(not ctx:compare(s,s),'synthetic scorer failure is preserved')
  eq(count(),1,'one failed score remains spent');eq(ctx.truncated,false,'unsupported score is not budget truncation')
  local r=ctx:preflight_family({s,copy(s)})
  check(not r.complete and not r.supported and not r.fits,'cached failure is never treated as a free supported profile')
  check(r.reason:find('cached unsupported',1,true),'cached failure explicitly distinguished')
  eq(count(),1,'preflight never retries failed score');eq(ctx.evaluations,1,'failed work remains charged')
end
do
  local s=state();s.jokers={joker('a'),joker('b')}
  local p=copy(s);p.jokers={p.jokers[2],p.jokers[1]}
  local ctx,count=setup(s,50000)
  local r=ctx:preflight_family({s,p})
  eq(r.unique_profiles,2,'fixed-row permutations retain distinct physical keys')
  eq(r.required_evaluations,1744,'equal movable multisets do not erase fixed-row work')
  check(ctx:compare(s,p),'both physical orders complete')
  p.dollars=p.dollars+1
  r=ctx:preflight_family({s,p})
  eq(r.required_evaluations,872,'mutation of the same table invalidates exact preparation key')
  eq(r.cached_profiles,1,'no pointer-only stale preparation cache')
  eq(count(),1744,'preflight of changed endpoint itself adds no calls')
end
for _,v in ipairs({{8,872},{9,1524},{10,2548}})do
  local s=state(v[1]);local ctx,count=setup(s,50000)
  local r=ctx:preflight_family({s})
  check(r.fits,'each bounded hand size fits individually');eq(r.required_evaluations,v[2],'exact hand-size subset cost')
  eq(count(),0,'arithmetic cost uses no scorer')
end
do
  local s=state();s.hand_limit=3;local ctx=setup(s,50000)
  eq(ctx:preflight_family({s}).required_evaluations,368,'three-card legal limit reduces complete subset cost exactly')
  s=state();ctx=setup(s,1);check(not ctx:compare(s,s) and ctx.truncated,'existing compare budget behavior remains unchanged')
  local r=ctx:preflight_family({s});check(not r.complete and not r.supported and not r.fits,'already-truncated context cannot be renewed')
end
do
  local s=state();local ctx,count=setup(s,50000);local states={}
  for i=1,128 do states[i]=s end
  local r=ctx:preflight_family(states)
  check(r.complete and r.supported and r.fits,'declared maximum 128 states is supported')
  eq(r.unique_profiles,1,'all maximum-size aliases deduplicate exactly')
  eq(r.required_evaluations,872,'maximum aliases never multiply identical score work')
  states[129]=s;r=ctx:preflight_family(states)
  check(not r.complete and not r.supported and not r.fits,'oversized family rejected before preparation or scoring')
  eq(count(),0,'family size limit spends no score work');eq(ctx.truncated,false,'oversized family does not poison existing cap')
end
print('shop family preflight: '..checks..' checks passed')
