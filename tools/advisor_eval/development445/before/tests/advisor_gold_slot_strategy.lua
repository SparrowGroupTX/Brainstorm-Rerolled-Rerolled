-- Manufactured acquisition routing, never a player-state replay.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Slot=dofile('Brainstorm/Advisor/gold_slot.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
Strategy.gold_slot=Slot
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function joker(key,id,eternal)
  local names={j_droll='Droll Joker',j_devious='Devious Joker',j_cartomancer='Cartomancer',j_joker='Joker',j_egg='Egg'}
  return {key=key,id=id,name=names[key],cost=2,sell_cost=1,rarity=1,blueprint_compat=true,
    ability={set='Joker',name=names[key],eternal=eternal,mult=key=='j_droll' and 10 or 4,
      t_chips=100,type=key=='j_devious' and 'Straight' or 'Flush'}}
end
local function state(phase,key)
  local s={phase=phase,ante=1,dollars=20,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={},consumeables={},playing_cards={},shop_jokers={},shop_vouchers={},shop_booster={},
    pack_cards={},hand={},deck={},modifiers={},hands={Flush={level=1,played=0}},reroll_cost=5,
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={status='eligible',eligible=true},by_key={j_droll={status='complete'},j_devious={status='complete'},
        j_cartomancer={status='complete'},j_joker={status='missing'},j_egg={status='complete'}}}}
  s[phase=='pack' and 'pack_cards' or 'shop_jokers']={joker(key,'offer',true)}
  return s
end
for _,phase in ipairs({'shop','pack'}) do
  for _,key in ipairs({'j_droll','j_devious','j_cartomancer'}) do
    local s=state(phase,key);local before=Snapshot.fingerprint(s)
    local a=Strategy.advise(s)
    check(a.action.kind~='buy' and a.action.kind~='choose' and a.action.kind~='sell',phase..' rejects heuristic-only completed Eternal '..key)
    check(a.gold_slot_diagnostics.protected_offers==1,'protection is visible without storing projected snapshots')
    check(Snapshot.fingerprint(s)==before,'input remains unchanged')
    s[phase=='pack' and 'pack_cards' or 'shop_jokers'][2]=joker('j_joker','missing',false)
    a=Strategy.advise(s)
    check(a.action.index==2 and a.action.area==(phase=='pack' and 'pack_cards' or 'shop_jokers'),'rank a useful alternative instead of vetoing the final action')
    s[phase=='pack' and 'pack_cards' or 'shop_jokers'][2]=nil
    s.completionist_goal.by_key[key].status='missing'
    a=Strategy.advise(s)
    check(a.action.index==1,'missing Eternal remains a collection opportunity')
  end
end
-- Permanent acquisitions cannot re-enter through whole-row sale/replacement.
for _,phase in ipairs({'shop','pack'}) do
  local s=state(phase,'j_devious');s.joker_limit=1
  s.jokers={joker('j_egg','owned',false)};s.jokers[1].ability.extra=3
  local a=Strategy.advise(s)
  check(a.action.kind~='sell' and a.action.kind~='buy' and a.action.kind~='choose','full-row replacement respects collection slots')
end
-- Partial scoring and the ratings-only fallback have the identical admission rule.
local s=state('pack','j_droll')
local context={truncated=true,unavailable_reason='manufactured incomplete family',
  compare=function()return nil end,readiness=function()return {status='unavailable',reason='Unavailable'}end}
local a=Strategy.advise(s,{shop_scoring=context})
check(a.action.kind=='skip_pack','partial family does not override the guard')
a=Strategy.advise(s)
check(a.action.kind=='skip_pack','fallback still protects the slot')
print('advisor_gold_slot_strategy: '..checks..' checks passed')
