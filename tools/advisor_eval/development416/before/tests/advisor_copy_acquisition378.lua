-- Independently manufactured shop endpoints; no captured game or seed replay.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity
local checks=0
local function check(ok,why) checks=checks+1;assert(ok,why) end
local function joker(key,name,a,cost,sell)
  a=a or {};a.set='Joker';a.name=name
  return {key=key,id='manufactured:'..key,name=name,ability=a,cost=cost or 0,
    sell_cost=sell or 2,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=3,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=24,bankrupt_at=0,joker_limit=5,consumable_limit=2,consumeables={},
    jokers={joker('j_yorick','Yorick',{x_mult=3,extra={discards=23,xmult=1},yorick_discards=12}),
      joker('j_perkeo','Perkeo'),joker('j_jolly','Jolly Joker',{mult=8}),
      joker('j_sly','Sly Joker',{t_chips=50}),joker('j_smiley','Smiley Face',{extra=4})},
    shop_jokers={joker('j_brainstorm','Brainstorm',{rental=true},1)},
    shop_vouchers={},shop_booster={},hand={},deck={},playing_cards={},
    hands={Pair={level=3,played=6,chips=50,mult=6}},hand_size=8,hand_limit=5,
    round_resets={hands=4,discards=3},current_round={},modifiers={},
    probabilities={normal=1},blind={key='bl_small',chips=0},
    next_blind={key='bl_big',chips=1000},interest_cap=25,reroll_cost=5,
    shop_forecast={rental_rate=3}}
  for i=1,12 do s.playing_cards[i]={id='manufactured:card:'..i,rank=i+1,
    nominal=math.min(10,i+1),suit='Hearts',ability={}} end
  return s
end
local function finishing(progress,clear)
  local worlds={}
  for i=1,4 do worlds[i]={clear=clear,score=progress*1000,progress=progress} end
  return {complete=true,supported=true,known_mechanics=true,samples=4,
    selected={worlds=worlds,clearing_samples=clear and 4 or 0}}
end
local function evidence()
  return {adjustment=0,ratio=1.4,samples=4,uncertain=false,
    before_target=1000,after_target=1000,complete_finishing=true,
    common_worlds={kind='shop_four_common_worlds_v1',samples=4,
      family_key='manufactured:copy-family',world_ids={1,2,3,4}},
    before_finishing=finishing(1,true),after_finishing=finishing(1,true),
    after_readiness={supported=false},reason='Manufactured fixed-policy family.'}
end
local baseline=state();local after=Snapshot.copy(baseline);after.dollars=23
table.remove(after.jokers,5);after.jokers[#after.jokers+1]=baseline.shop_jokers[1]
check(Strategy.copy_replacement_exception(baseline,baseline.jokers[5],
  baseline.shop_jokers[1],after,evidence(),17),'funded developed copy can qualify')
local function reject(label,change)
  local s=state();local a=Snapshot.copy(s);a.dollars=23;local e=evidence()
  table.remove(a.jokers,5);a.jokers[#a.jokers+1]=s.shop_jokers[1]
  change(s,a,e)
  check(not Strategy.copy_replacement_exception(s,s.jokers[5],s.shop_jokers[1],a,e,17),label)
end
reject('collection objective stays unchanged',function(s) s.teacher_profile=nil end)
reject('only a visible shop endpoint',function(s) s.phase='pack' end)
reject('short horizon does not invest',function(s) s.ante=6 end)
reject('undeveloped Yorick is not a copy target',function(s) s.jokers[1].ability.x_mult=1 end)
reject('incompatible Yorick is not a target',function(s) s.jokers[1].blueprint_compat=false end)
reject('already-owned copy is outside this exception',function(s)
  s.jokers[4]=joker('j_blueprint','Blueprint') end)
reject('opening Jokers remain protected',function(s) s.jokers[5].key='j_perkeo' end)
reject('Eternal incumbent remains protected',function(s) s.jokers[5].ability.eternal=true end)
reject('Negative slot cannot be presumed free',function(s) s.jokers[5].edition='negative' end)
reject('little cash is not enough',function(s,a) a.dollars=4 end)
reject('rental reserve must remain',function(s,a) a.modifiers.discard_cost=6 end)
reject('Credit Card debt cannot substitute for actual reserved cash',function(s,a)
  s.shop_jokers[1].ability.rental=nil;a.jokers[5].ability.rental=nil
  a.bankrupt_at=-20;a.modifiers.discard_cost=10
end)
reject('uncertain comparison cannot certify investment',function(s,a,e) e.uncertain=true end)
reject('incomplete finishing cannot certify investment',function(s,a,e) e.complete_finishing=false end)
reject('unknown mechanics cannot certify investment',function(s,a,e) e.after_finishing.known_mechanics=false end)
reject('unpaired worlds cannot certify investment',function(s,a,e) e.common_worlds.world_ids[3]=9 end)
reject('target mismatch cannot certify investment',function(s,a,e) e.after_target=2000 end)
reject('after worlds must all clear',function(s,a,e)
  e.after_finishing.selected.clearing_samples=3;e.after_finishing.selected.worlds[2].clear=false end)
reject('progress cannot regress in one world',function(s,a,e)
  e.after_finishing.selected.worlds[4].progress=0.9 end)
reject('opening ratio must be material',function(s,a,e) e.ratio=1.2 end)
check(not Strategy.copy_replacement_exception(baseline,baseline.jokers[5],
  baseline.shop_jokers[1],after,evidence(),12.99),'low merit retains ordinary threshold')

local adjustment=-27
local function advise(s)
  local ctx={evaluations=0,max_evaluations=50000,truncated=false}
  function ctx:readiness() return {supported=false,status='unsupported'} end
  function ctx:compare(before,following)
    self.evaluations=self.evaluations+4
    local e=evidence();e.adjustment=adjustment
    return e
  end
  return Strategy.advise(s,{shop_scoring=ctx}),ctx
end
local original=state();local key=Snapshot.fingerprint(original)
local advice,ctx=advise(original)
local receipt=ctx.replacement_diagnostics
check(receipt and receipt.complete and ctx.evaluations<=50000,
  'full visible victim family respects existing shop cap')
local chosen
for _,c in ipairs(receipt.candidates) do if c.copy_exception then chosen=c end end
check(chosen and chosen.merit>=13 and chosen.merit<26 and
  chosen.copy_exception_reason=='supported_copy_replacement' and
  chosen.finishing_complete and chosen.finishing_supported and chosen.finishing_all_clear,
  'a sub-26 copy endpoint has auditable complete finishing evidence')
check(advice.action.kind=='sell' and advice.action.area=='jokers' and
  advice.action.followup.kind=='buy' and advice.action.followup.index==1,
  'only a qualified sale is published before fresh advice')
check(Snapshot.fingerprint(original)==key,'the candidate does not mutate the observation')
local compact=Journal.compact_replacement_review({shop_diagnostics={replacements=receipt}})
check(compact and compact.candidates[chosen and 1 or 1] and
  not compact.secret,'public replacement receipt exists without arbitrary payload')
local seen=false
for _,c in ipairs(compact.candidates) do
  if c.copy_exception then seen=c.copy_exception_reason=='supported_copy_replacement' end
  check(c.worlds==nil,'public receipt excludes world assignments')
end
check(seen,'copy admission reason survives the public scalar projection')
local wide_shop=state()
for i=2,4 do wide_shop.shop_jokers[i]=joker('j_joker_'..i,'Extra',{},200) end
local wide_advice,wide_context=advise(wide_shop)
check(wide_context.replacement_diagnostics and not wide_context.replacement_diagnostics.complete and
  wide_context.replacement_diagnostics.reason=='replacement_receipt_scope_bound' and
  wide_advice.action.kind~='sell','four offers cannot bypass the complete visible family')
local wide_row=state();wide_row.joker_limit=7
wide_row.jokers[6]=joker('j_even_steven','Even Steven',{mult=8})
wide_row.jokers[7]=joker('j_odd_todd','Odd Todd',{t_chips=31})
local row_advice,row_context=advise(wide_row)
check(row_context.replacement_diagnostics and not row_context.replacement_diagnostics.complete and
  row_context.replacement_diagnostics.reason=='replacement_receipt_scope_bound' and
  row_advice.action.kind~='sell','seven owned Jokers cannot bypass the bounded family')
local settled=state();table.remove(settled.jokers,advice.action.index)
settled.dollars=original.dollars+original.jokers[advice.action.index].sell_cost
local fresh=advise(settled)
check(fresh.action.kind=='buy' and fresh.action.area=='shop_jokers' and
  fresh.action.index==1,'fresh observation confirms the funded purchase')
adjustment=-70
local rejected,rejected_ctx=advise(state())
local low=false
for _,c in ipairs(rejected_ctx.replacement_diagnostics.candidates) do
  if c.merit and c.merit<13 then low=true end
end
check(low and rejected.action.kind=='sell' and rejected.copy_acquisition_review and
  rejected.copy_acquisition_review.reason=='supported_copy_priority',
  '400: complete supported copy priority can outweigh a negative additive rating; legacy exception guard remains separate')
print('advisor_copy_acquisition378: '..checks..' checks passed')
