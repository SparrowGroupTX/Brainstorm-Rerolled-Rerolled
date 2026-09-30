-- Review regressions: recurring rental costs cannot create positive income value.
local Value=dofile('Brainstorm/Advisor/conditional_value.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
S.conditional_value=Value
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local function state()
  local s={phase='pack',ante=2,dollars=18,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    hand_size=8,hand_limit=5,jokers={},consumeables={},hands={Flush={level=1,played=5}},
    round_resets={hands=1,discards=3},current_round={},playing_cards={},rental_rate=3,
    next_blind={key='bl_small',name='Small Blind',chips=500},next_blind_chips=500,
    probabilities={normal=1},modifiers={},pack_cards={}}
  for i,r in ipairs({2,4,6,8,10,11,12,14}) do
    s.playing_cards[i]={id='income'..i,rank=r,suit='Hearts',ability={}}
  end
  return s
end
local moon={key='j_to_the_moon',cost=99,sell_cost=2,ability={set='Joker',name='To the Moon',extra=1,rental=true}}
local safe={supported=true,status='sampled_safe',samples=4,hands=1,discards=3}
do
  local s=state()
  local v=Value.assess(s,moon,{base_value=55,readiness=safe})
  check(v.net_cash==0 and v.payback_rounds==nil and v.rating==0,
    'a rental exactly consuming its income has no positive pure-income rating')
  s.dollars=13;v=Value.assess(s,moon,{base_value=55,readiness=safe})
  check(v.net_cash==-1 and v.rating==0,'negative rental return has no positive pure-income rating')
  s.dollars=23;v=Value.assess(s,moon,{base_value=55,readiness=safe})
  check(v.net_cash==1 and v.rating>0,'positive supported net income remains investable')
end
do
  local s=state();s.dollars=15
  local ordinary_moon=Snap.copy(moon);ordinary_moon.ability.rental=nil
  s.jokers={{key='j_joker',ability={set='Joker',name='Joker',rental=true,perishable=true,perish_tally=0},debuff=true}}
  local v=Value.assess(s,ordinary_moon,{base_value=55,readiness=safe})
  check(v.cash_end_round==2,'existing expired and debuffed rental still lowers the Moon interest threshold')
  s.jokers[2]=moon
  v=Value.assess(s,moon,{base_value=55,readiness=safe})
  check(v.purchase_cost==0 and v.cash_end_round==1,
    'owned Moon rental is counted exactly once alongside the existing rental')
end
do
  local s=state();s.pack_cards={moon}
  s.jokers={{key='j_joker',ability={set='Joker',name='Joker',mult=40}}}
  local modules={strategy=S,scoring=Scorer,shop_scoring=Shop}
  local result=D.run(s,modules)
  check(result.strategy.readiness.status=='sampled_safe' and result.action.kind=='skip_pack',
    'safe build skips free but nonproductive rental income')
  s.jokers={};s.pack_cards={Snap.copy(moon)};s.pack_cards[1].edition={holo=true}
  local before=Snap.fingerprint(s)
  result=D.run(s,modules)
  check(result.action.kind=='choose' and result.strategy.scoring_evidence.timely_scoring,
    'the scoring edition can still justify the same rental when it supplies the missing immediate Mult')
  check(result.strategy.scoring_evidence.after_mean>=500,'scoring edition rescue uses actual paired score evidence')
  check(Snap.fingerprint(s)==before,'income and scoring evaluation preserve the detached snapshot')
end
print('advisor_income_pack_regression: '..checks..' checks passed')
