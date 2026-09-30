-- Independent manufactured shop and fixed-policy finishing evidence only.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity
local checks=0
local function check(ok,why) checks=checks+1;assert(ok,why) end
local function joker(key,a,cost,sell)
  a=a or {};a.set='Joker'
  return {key=key,id='manufactured:'..key,name=key,ability=a,cost=cost or 0,
    sell_cost=sell or 2,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=3,win_ante=8,teacher_profile='perkeo_yorick_win_v1',
    dollars=70,bankrupt_at=0,joker_limit=5,consumable_limit=2,consumeables={},
    jokers={joker('j_yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=11}),
      joker('j_perkeo'),joker('j_jolly',{mult=8}),joker('j_smiley',{extra=4}),
      joker('j_ice_cream',{perishable=true,perish_tally=2,extra={chips=20,chip_mod=20}},0,3)},
    shop_jokers={joker('j_bull',{extra=2},6)},shop_vouchers={},shop_booster={},
    hand={},deck={},playing_cards={},hands={Pair={level=3,played=6,chips=50,mult=6}},
    hand_size=8,hand_limit=5,round_resets={hands=4,discards=3},current_round={},
    modifiers={},probabilities={normal=1},blind={key='bl_small',chips=0},
    next_blind={key='bl_big',chips=1000},interest_cap=25,reroll_cost=5}
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
  return {adjustment=0,ratio=1.1,samples=4,uncertain=false,
    before_target=1000,after_target=1000,complete_finishing=true,
    common_worlds={kind='shop_four_common_worlds_v1',samples=4,
      family_key='manufactured:paired:1',world_ids={1,2,3,4}},
    before_finishing=finishing(0.5,false),after_finishing=finishing(0.6,false),
    after_readiness={supported=false},reason='Manufactured four-world comparison.'}
end
local baseline=state();local sold=baseline.jokers[5];local offered=baseline.shop_jokers[1]
local after=Snapshot.copy(baseline);after.dollars=67
check(Strategy.perishable_replacement_exception(baseline,sold,offered,after,evidence(),17),
  'a funded durable offer with four supported non-regressing worlds qualifies')
local function reject(label,modify)
  local s=state();local e=evidence();local a=Snapshot.copy(s);a.dollars=67
  modify(s,s.jokers[5],s.shop_jokers[1],a,e)
  local accepted=Strategy.perishable_replacement_exception(s,s.jokers[5],s.shop_jokers[1],a,e,17)
  check(not accepted,label)
end
reject('collection profile is unchanged',function(s) s.teacher_profile=nil end)
reject('only a shop endpoint',function(s) s.phase='pack' end)
reject('later replacement has no horizon',function(s) s.ante=7 end)
reject('four rounds left is outside exception',function(s,sold) sold.ability.perish_tally=4 end)
reject('expired incumbent stays on ordinary path',function(s,sold) sold.ability.perish_tally=0 end)
reject('pinned incumbent is protected',function(s,sold) sold.pinned=true end)
reject('a new rental is not durable',function(s,sold,card) card.ability.rental=true end)
reject('a new perishable is not durable',function(s,sold,card) card.ability.perishable=true end)
reject('cash buffer is protected',function(s,sold,card,a) a.dollars=24 end)
reject('discard cash reserve is protected',function(s,sold,card,a) a.modifiers.discard_cost=25 end)
reject('uncertain score cannot certify exception',function(s,sold,card,a,e) e.uncertain=true end)
reject('missing whole-blind finish cannot certify exception',function(s,sold,card,a,e) e.complete_finishing=false end)
reject('unknown mechanics cannot certify exception',function(s,sold,card,a,e) e.after_finishing.known_mechanics=false end)
reject('an incomplete comparison cannot certify exception',function(s,sold,card,a,e) e.incomplete=true end)
reject('mismatched targets cannot certify exception',function(s,sold,card,a,e) e.after_target=2000 end)
reject('changed world identity cannot certify exception',function(s,sold,card,a,e) e.common_worlds.world_ids[2]=9 end)
reject('incomplete world list cannot certify exception',function(s,sold,card,a,e) e.after_finishing.selected.worlds[4]=nil end)
reject('existing clear must survive',function(s,sold,card,a,e)
  e.before_finishing=finishing(1,true);e.after_finishing=finishing(1,true)
  e.after_finishing.selected.worlds[2].clear=false
end)
reject('each common world must retain progress',function(s,sold,card,a,e)
  e.after_finishing.selected.worlds[3].progress=0.4
end)
reject('opening mean must improve',function(s,sold,card,a,e) e.ratio=1 end)
check(not Strategy.perishable_replacement_exception(baseline,sold,offered,after,evidence(),12.99),
  'lower whole-build merit retains the ordinary threshold')
check(not Strategy.perishable_replacement_exception(baseline,sold,offered,after,nil,17),
  'missing scoring evidence never qualifies')
for _,key in ipairs({'j_yorick','j_perkeo','j_blueprint','j_brainstorm'}) do
  local protected=Snapshot.copy(sold);protected.key=key
  check(not Strategy.perishable_replacement_exception(baseline,protected,offered,after,evidence(),17),
    'critical '..key..' retains its ordinary replacement threshold')
end

-- This context supplies independently manufactured comparison *results* so
-- the real shop arbitration can be tested without a captured state or scorer.
local adjustment=-12
local function advise(s)
  local ctx={evaluations=0,max_evaluations=50000,truncated=false}
  function ctx:readiness() return {supported=false,status='unsupported'} end
  function ctx:compare(before,after)
    self.evaluations=self.evaluations+4
    local e=evidence();e.adjustment=adjustment
    local has_ice=false
    for _,j in ipairs(after.jokers or {}) do if j.key=='j_ice_cream' then has_ice=true end end
    if has_ice then e.ratio=0.8 end
    return e
  end
  return Strategy.advise(s,{shop_scoring=ctx}),ctx
end
local original=state();local fingerprint=Snapshot.fingerprint(original)
local advice,ctx=advise(original)
local receipt=ctx.replacement_diagnostics
check(receipt and receipt.complete and ctx.evaluations<=50000,
  'real shop arbitration completes the whole visible victim family within cap')
local chosen
for _,c in ipairs(receipt.candidates) do if c.sale_index==5 then chosen=c end end
check(chosen and chosen.compared and chosen.admitted and type(chosen.merit)=='number',
  'the manufactured perishable endpoint has a scored, admitted receipt')
check(chosen.merit>=13 and chosen.merit<26 and
  chosen.perishable_exception and chosen.perishable_exception_reason=='supported_perishable_replacement' and
  advice.action.kind=='sell' and advice.action.index==5 and
  advice.action.followup.kind=='buy' and advice.action.followup.index==1,
  'a sub-26 positive endpoint selects only the supported perishable sale')
check(Snapshot.fingerprint(original)==fingerprint,'the full-row comparison leaves its public snapshot unchanged')
local settled=state();table.remove(settled.jokers,5);settled.dollars=73
local fresh=advise(settled)
check(fresh.action.kind=='buy' and fresh.action.area=='shop_jokers' and fresh.action.index==1,
  'fresh advice buys only the still-visible funded offer after sale')
adjustment=-30
local rejected,rejected_ctx=advise(state())
local low
for _,c in ipairs(rejected_ctx.replacement_diagnostics.candidates) do if c.sale_index==5 then low=c end end
check(low and low.merit<13 and rejected.action.kind~='sell',
  'low net merit cannot use the exception through the final shop arbitration')
check(rejected_ctx.evaluations<=50000,'negative case preserves the shop score cap')
adjustment=-12
local collection=state();collection.teacher_profile=nil
local ordinary=advise(collection)
check(ordinary.action.kind~='sell',
  'the same manufactured sub-26 endpoint does not change collection mode')
print('advisor_perishable_replacement377: '..checks..' checks passed')
