local F=dofile('tools/advisor_eval/development344/tarot_hold_component/fixture_support.lua')
local H,S=F.Hold,F.Snapshot
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function eq(a,b,why) check(a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local function rejected(s,why) local result=H.certify(s);check(result==nil,why) end
math.random=function() error('No RNG is allowed in Tarot hold qualification') end
pseudorandom=math.random;pseudoseed=math.random
local function poison() return setmetatable({},{__index=function() error('Hidden metadata was inspected') end}) end

do
  local s=F.state();local before=S.fingerprint(s);local receipt,why=H.certify(s)
  check(receipt,why or '14 mixed Negative Tarots qualify without identity enumeration')
  eq(receipt.copy_events,2,'Perkeo and Brainstorm each copy')
  eq(receipt.inventory_count_before,14,'full original inventory counted')
  eq(receipt.inventory_count_after,16,'new copies counted symbolically')
  eq(receipt.capacity_after,18,'each Negative adds a slot')
  eq(receipt.free_slots_before,2,'original free capacity')
  eq(receipt.free_slots_after,2,'free capacity is conserved')
  eq(receipt.cash_after,170,'no prospective payout is credited')
  eq(receipt.generated_identity,'unresolved','no copied identity invented')
  eq(receipt.generated_prices,'unresolved','no copied price invented')
  eq(receipt.generated_resale_credit,0,'no future resale credited')
  eq(receipt.generated_future_utility_credit,0,'no future strategic value credited')
  check(receipt.original_inventory_unchanged and not receipt.generation_used_for_score,'dependency-only certificate explicit')
  eq(receipt.first_hand_consumable_actions,0,'every original and generated card is held')
  eq(S.fingerprint(receipt.inventory_before),S.fingerprint(s.consumeables),'all original fields retained')
  eq(S.fingerprint(s),before,'certificate does not mutate input')
  receipt.inventory_before[1].ability.extra_value=100
  eq(s.consumeables[1].ability.extra_value,0,'receipt inventory detached')
end

do
  for _,key in ipairs({'c_magician','c_hermit'}) do for _,negative in ipairs({false,true}) do
    local raw=F.raw(key,1,negative);local before=S.fingerprint(raw);local c=F.observe(raw)
    check(c.tarot_hold_source.supported,'ordinary/Negative qualified Tarot constructor')
    eq(S.fingerprint(raw),before,'public capture leaves source-shaped card untouched')
  end end
  local raw=F.raw('c_magician',1,true)
  raw.flipping='b2f';raw.pinch={x=false}
  check(F.observe(raw).tarot_hold_source.supported,'completed public reveal remains admissible')
  raw.pinch.x=0.01;check(not F.observe(raw).tarot_hold_source.supported,'active reveal rejected')
  raw=F.raw('c_magician',1,true);raw.states={drag={is=true}}
  check(not F.observe(raw).tarot_hold_source.supported,'public active card drag prevents capture')
  local hidden={facing='back',config=poison(),ability=poison()}
  check(not H.capture(hidden,poison()).supported,'hidden capture rejects before identity reads')
  raw=F.raw('c_magician',1,true);raw.config.center.config.mod_num=3
  check(not F.observe(raw).tarot_hold_source.supported,'modified center rejected')
  raw=F.raw('c_magician',1,true);raw.config.center.calculate=function() error('never call') end
  check(not F.observe(raw).tarot_hold_source.supported,'callback-bearing modified center rejected')
  raw=F.raw('c_magician',1,true);raw.ability.h_size=1
  check(not F.observe(raw).tarot_hold_source.supported,'copied hand-size side effect rejected')
  raw=F.raw('c_magician',1,true);raw.ability.d_size=1
  check(not F.observe(raw).tarot_hold_source.supported,'copied discard side effect rejected')
  raw=F.raw('c_magician',1,true);raw.params.playing_card=44
  check(not F.observe(raw).tarot_hold_source.supported,'physical playing-card constructor rejected')
  raw=F.raw('c_magician',1,true);raw.edition.chips=50
  check(not F.observe(raw).tarot_hold_source.supported,'off-spec Negative scoring edition rejected')
  raw=F.raw('c_magician',1,true);raw.edition={foil=true,type='foil',chips=50}
  check(not F.observe(raw).tarot_hold_source.supported,'original foil outside narrow hold family')
  raw=F.raw('c_magician',1,true);raw.ability.extra_value=8
  check(F.observe(raw).tarot_hold_source.supported,'known original extra resale value can be retained without future credit')
  raw=F.raw('c_magician',1,true)
  check(not H.capture(raw,{c_magician=S.copy(raw.config.center)}).supported,'loaded registry identity required')
end

do
  local changes={
    function(s) s.consumeable_buffer=1 end,
    function(s) s.consumable_limit=13 end,
    function(s) s.consumeables[2].id=s.consumeables[1].id end,
    function(s) s.consumeables[1].tarot_hold_source=nil end,
    function(s) s.consumeables[1].tarot_hold_source.ability.extra_value=3 end,
    function(s) s.consumeables[1].ability.h_size=1;s.consumeables[1].tarot_hold_source.ability.h_size=1 end,
    function(s) s.consumeables[1].key='c_mercury' end,
    function(s) s.consumeables[1].edition={holo=true,type='holo',mult=10} end,
    function(s) s.ordering_safe=false end,
    function(s) s.dragging=true end,
    function(s) s.jokers[1].states={drag={is=true}} end,
    function(s) s.jokers_shuffling=true end,
    function(s) s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=nil end,
    function(s) s.jokers[1].key='j_modded' end,
    function(s) s.jokers[1].ability.name='Unexpected Callback' end,
    function(s) s.jokers[1].blueprint_compat=nil end,
    function(s) s.jokers[1].id=s.consumeables[1].id end,
  }
  for i,change in ipairs(changes) do local s=F.state();change(s);rejected(s,'invalid boundary '..i) end
  local s=F.state();s.consumeables[1]={face_down=true,key=poison(),ability=poison()};rejected(s,'hidden Tarot rejected before source reads')
  s=F.state();s.jokers[1]={face_down=true,key=poison(),ability=poison()};rejected(s,'hidden Joker rejected before identity reads')
  s=F.state();s.used_vouchers.v_observatory=true
  check(H.certify(s),'Observatory cannot multiply generated Tarot identities')
  s.consumeables[1].ability.set='Planet';s.consumeables[1].ability.consumeable={hand_type='Pair'}
  rejected(s,'Observatory Planet is not interchangeable with a Tarot copy')
  s=F.state();for i=15,65 do s.consumeables[i]=F.observe(F.raw('c_magician',i,true)) end;s.consumable_limit=67
  rejected(s,'inventory bound enforced without partial admission')
  s=F.state();s.ordering_safe=nil;s.jokers_shuffling=nil
  check(H.certify(s),'ordinary Snapshot shape with absent optional ordering flags uses established scheduler guards')
end

do
  local s=F.state();s.jokers={F.joker('j_blueprint','Blueprint','bp'),F.joker('j_perkeo','Perkeo','p'),F.joker('j_brainstorm','Brainstorm','bs')}
  eq(H.certify(s).copy_events,3,'Blueprint and Brainstorm chain resolves to Perkeo')
  s.jokers[2].blueprint_compat=false
  eq(H.certify(s).copy_events,1,'incompatible target prevents both copied paths')
  s=F.state();s.jokers[1].debuff=true
  eq(H.certify(s).copy_events,0,'debuffed Perkeo supplies no copy effect')
  s=F.state();s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=0
  eq(H.certify(s).copy_events,0,'expired Perkeo supplies no copy effect')
  s=F.state();s.jokers={F.joker('j_brainstorm','Brainstorm','a'),F.joker('j_brainstorm','Brainstorm','b')}
  eq(H.certify(s).copy_events,0,'copy cycle gives no invented event')
end

do
  -- Manufactured scorer dependency checks only: enumerate the two possible
  -- admitted generated classes, not a player state or original-source replay.
  local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
  local s=F.state();s.jokers={F.joker('j_joker','Joker')};s.jokers[1].ability.mult=4
  s.hand={{id='a',rank=2,nominal=2,suit='Hearts',ability={}},{id='b',rank=2,nominal=2,suit='Clubs',ability={}}}
  s.playing_cards=S.copy(s.hand);s.deck={};s.hands={Pair={level=1,chips=10,mult=2,l_chips=15,l_mult=1,played=0}}
  s.hand_limit=5;s.hand_size=2;s.hands_left=4;s.discards_left=3;s.current_round={};s.probabilities={normal=1}
  s.used_vouchers.v_observatory=true
  local original=Scoring.score(s,{1,2})
  for _,key in ipairs({'c_magician','c_hermit'}) do
    local after=S.copy(s);after.consumeables[#after.consumeables+1]=F.observe(F.raw(key,100,true));after.consumable_limit=after.consumable_limit+1
    local result=Scoring.score(after,{1,2})
    eq(result.score,original.score,'unused generated '..key..' has zero score contribution')
  end
  local after=S.copy(s);local c=F.observe(F.raw('c_magician',100,true));c.key='c_mercury';c.ability.set='Planet';c.ability.consumeable={hand_type='Pair'}
  after.consumeables[#after.consumeables+1]=c
  check(Scoring.score(after,{1,2}).score>original.score,'held Planet Observatory counterexample changes score')
  rejected(after,'counterexample cannot receive Tarot equivalence proof')
end
print('PASS Tarot fixed-hold equivalence '..checks..' checks')
