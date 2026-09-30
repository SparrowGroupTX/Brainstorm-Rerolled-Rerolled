-- Independently manufactured five-Joker shop and prescribed four-world receipts.
-- No captured game state or scorer is loaded.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function j(key,name,a,sell)
  a=a or {};a.name=name;a.set='Joker';a.x_mult=a.x_mult or 1
  return {id=key,key=key,name=name,ability=a,sell_cost=sell or 2,cost=4,blueprint_compat=true}
end
local function state()
  return {phase='shop',teacher_profile='perkeo_yorick_win_v1',ante=3,win_ante=8,
    dollars=24,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={j('j_perkeo','Perkeo',{},10),j('j_throwback','Throwback',{x_mult=1.1},3),
      j('j_yorick','Yorick',{x_mult=3,extra={discards=23,xmult=1}},10),
      j('j_joker','Joker',{mult=12},2),j('j_blueprint','Blueprint',{rental=true},1)},
    shop_jokers={j('j_swashbuckler','Swashbuckler',{perishable=true,perish_tally=5},2)},
    shop_vouchers={},shop_booster={},consumeables={},playing_cards={},deck={},hand={},
    hands={Pair={played=5,level=2}},hand_size=8,hand_limit=5,
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    blind={key='bl_big',name='Big Blind'},next_blind={key='bl_big',name='Big Blind',chips=4800},
    interest_cap=25,reroll_cost=5}
end
local function context(options)
  options=options or {}
  local ctx={evaluations=0,calls=0,truncated=false}
  function ctx:readiness()
    return {status='sampled_safe',supported=true,target=4800,opening_mean=6000}
  end
  function ctx:compare(before,after)
    self.calls=self.calls+1;self.evaluations=self.evaluations+4
    local retained={};for _,card in ipairs(after.jokers or {}) do retained[card.key]=true end
    local sold
    for _,card in ipairs(before.jokers or {}) do if not retained[card.key] then sold=card.key end end
    local means={j_perkeo=7200,j_throwback=7600,j_yorick=5000,j_joker=6500,j_blueprint=6200}
    local mean=means[sold] or 6000
    if options.high_copy and sold=='j_blueprint' then mean=8000 end
    if options.weaker_alternative and sold=='j_throwback' then mean=6900 end
    local family=options.different_worlds and sold=='j_throwback' and 'other' or 'manufactured'
    local finish
    if options.finish_regression then
      local progress=sold=='j_throwback' and 0.7 or 0.9
      finish={complete=true,supported=true,known_mechanics=true,samples=4,
        selected={clearing_samples=0,mean_progress=progress,worlds={}}}
      for i=1,4 do finish.selected.worlds[i]={clear=false,progress=progress} end
    end
    local ids=options.mismatched_ids and sold=='j_throwback' and {2,1,3,4} or {1,2,3,4}
    return {samples=4,ratio=mean/6000,adjustment=(sold=='j_perkeo' or sold=='j_throwback' or
      options.high_copy and sold=='j_blueprint') and 35 or 20,
      before_mean=6000,after_mean=mean,before_target=4800,after_target=4800,
      clearing_samples_after=mean>=4800 and 4 or 0,complete_finishing=finish~=nil,
      after_finishing=finish,
      common_worlds={kind='shop_four_common_worlds_v1',family_key=family,
        samples=4,world_ids=ids},
      before_readiness=self:readiness(),after_readiness=self:readiness(),reason='Manufactured paired opening.'}
  end
  return ctx
end

for _,ante in ipairs({3,7,8}) do
local s=state();s.ante=ante;s.next_blind.label='Boss';s.next_blind.ante=ante
local ctx=context();local r=S.advise(s,{shop_scoring=ctx})
print('ante',ante,'title',r.title,'action',Snapshot.fingerprint(r.action),'calls',ctx.calls)
print('diagnostics',Snapshot.fingerprint(ctx.replacement_diagnostics))
end
