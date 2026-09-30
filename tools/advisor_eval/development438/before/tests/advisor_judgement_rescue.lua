local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Cache=dofile('Brainstorm/Advisor/score_cache.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,label) assert(v,label);checks=checks+1 end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local serial=0
local function card(r,suit)
  serial=serial+1
  return {id='judgement:'..serial,key='c_base',rank=r,suit=suit or 'Spades',
    nominal=r==14 and 11 or math.min(r,10),ability={}}
end
local function joker(name,a) a=a or {};a.name=name;return {name=name,ability=a} end
local function judgement()
  return {key='c_judgement',name='Judgement',ability={name='Judgement',set='Tarot',consumeable={}}}
end
local function state(cards)
  return {phase='hand',hand=cards,playing_cards=cards,deck={},jokers={},joker_limit=5,
    consumeables={judgement()},consumable_limit=2,hands={},blind={chips=10000},chips=0,
    dollars=3,hands_left=1,discards_left=0,hand_limit=5,hand_size=#cards,modifiers={},
    current_round={hands_left=1,discards_left=0},probabilities={normal=1}}
end
local function large()
  local s=state({card(13,'Diamonds'),card(12),card(9,'Diamonds'),card(8),card(7,'Hearts'),
    card(5),card(4,'Hearts'),card(4,'Clubs'),card(4,'Diamonds'),card(2)})
  s.jokers={joker('Ceremonial Dagger',{mult=30}),joker('Juggler',{h_size=1})}
  s.chips=6800;s.blind={key='bl_arm',name='The Arm',chips=10000}
  return s
end
local function suggest(s,options,scorer)
  local base=Search.run(s,S,{max_evaluations=1000})
  return C.suggest(s,scorer or S,base,nil,options)
end

do
  local s=large();local before=Snapshot.fingerprint(s)
  check(S.upper_bound_order_independent(s),'plain-card additive mechanics prove ordered-play equivalence')
  local use,count,diag=suggest(s)
  check(use and use.generator,'owned Judgement can be revealed before a certified losing last play')
  equal(use.generator.set,'Joker','Judgement reveals one Joker')
  equal(use.generator.count,1,'Judgement source generation count is fixed at one')
  equal(use.action.index,1,'only the known owned card is used')
  equal(#use.action.targets,0,'Judgement never selects hand targets')
  equal(count,637,'every unordered subset of the ten-card hand is completely checked')
  equal(use.generator.complete_ordered_plays,36100,'equivalent ordered plays are accounted separately from score passes')
  equal(use.generator.ceiling_evaluations,637,'reported work is the actual number of maximum passes')
  equal(use.generator.immediate_ceiling,1386,'generic recorded mechanics have the exact local maximum')
  check(diag.generator_ceiling.complete and diag.generator_ceiling.supported and
    diag.generator_ceiling.order_equivalence,'only a complete supported equivalence certificate is reported')
  equal(diag.generator_ceiling.enumeration,'all_plain_additive_subsets','diagnostics identify the proved enumeration scope')
  equal(diag.generator_ceiling.legal_plays,36100,'expanded legal ordered plays are accounted correctly')
  equal(diag.generator_ceiling.legal_comparisons,637,'representative legal comparisons are counted separately')
  equal(use.play,nil,'the generated Joker is not assigned an invented score')
  equal(use.generator.probability,nil,'no invented probability of a successful rescue')
  check(use.generator.public_replan,'real revealed identity requires fresh advice')
  equal(C.apply(s,1,{}),nil,'Judgement has no fabricated pure transition')
  equal(Snapshot.fingerprint(s),before,'equivalence and generation admission preserve all input data')
end

do
  -- Exhaust all325 ordered selections of five plain cards, not just the
  -- canonical ordering. Duplicate ranks and unequal debuffs exercise poker
  -- membership/tie behavior. Every order must equal its subset's maximum.
  local s=state({card(14),card(14,'Hearts'),card(9),card(7,'Clubs'),card(5,'Diamonds')})
  s.hand[1].debuff=true
  s.jokers={joker('Misprint',{extra={min=0,max=23}}),joker('Joker'),joker('Ceremonial Dagger',{mult=30})}
  check(S.upper_bound_order_independent(s),'random maximum and debuffed plain cards remain order independent')
  local chosen,used,visits={},{},0
  local function walk()
    if #chosen>0 then
      local sorted={};for i,v in ipairs(chosen) do sorted[i]=v end;table.sort(sorted)
      equal(S.upper_bound(s,chosen).score,S.upper_bound(s,sorted).score,'all plain-card ordered maxima agree with their subset')
      visits=visits+1
    end
    if #chosen==5 then return end
    for i=1,5 do if not used[i] then used[i]=true;chosen[#chosen+1]=i;walk();chosen[#chosen]=nil;used[i]=nil end end
  end
  walk();equal(visits,325,'all ordered selections are covered in the parity fixture')
end

do
  local s=large();local use,count,diag=suggest(s,{max_evaluations=636})
  equal(use,nil,'one missing subset cannot produce a certificate')
  equal(count,0,'insufficient complete-subset budget starts no partial comparison')
  -- The generic consumable admission may reject before the generator-specific
  -- diagnostic because even an ordinary full subset pass cannot fit.
  check(diag.truncated,'the existing hard consumable cap records insufficient work')
  local wrapped,stats=Cache.new(S)
  use,count,diag=suggest(s,nil,wrapped)
  equal(stats().score_calls,637,'prepared scoring counts every compressed maximum pass')
  equal(count,637,'no extra search allowance is allocated for compression')
  equal(use.generator.immediate_ceiling,1386,'raw and prepared compressed maxima agree')
end

do
  local s=state({card(14)});local use=suggest(s)
  check(use and use.generator,'small held hands use the existing exhaustive ordered path')
  check(not use.generator.order_equivalence,'small-hand enumeration behavior is unchanged')
  s.joker_limit=0;equal(suggest(s),nil,'zero Joker capacity cannot use Judgement')
  s.joker_limit=1;s.jokers={joker('Joker')};equal(suggest(s),nil,'a full Joker row never invents space')
  s.jokers[1].edition={negative=true};equal(suggest(s),nil,'Negative row members still occupy actual observed capacity')
  s.joker_limit=2;check(suggest(s),'actual extra Negative capacity permits one revealed Joker')
  s.consumeables[1].edition={negative=true};s.consumable_limit=1
  use=suggest(s);check(use,'Judgement needs a Joker slot, not a freed consumable slot')
  equal(s.consumable_limit,1,'a proposed Negative use does not mutate current capacity')
  s.consumable_limit=0;equal(suggest(s),nil,'malformed Negative capacity remains unsupported')
end

do
  local s=large();s.consumeables[1].key='c_emperor';s.consumeables[1].name='The Emperor'
  s.consumeables[1].ability={name='The Emperor',set='Tarot',consumeable={tarots=2}}
  equal(suggest(s).generator.set,'Tarot','the generic equivalence certificate also extends existing Emperor coverage')
  s=large();s.jokers[#s.jokers+1]=joker('Misprint',{extra={min=0,max=100}})
  s.blind.chips=s.chips+4000
  check(S.upper_bound_order_independent(s),'integer random maxima can enter the additive proof')
  equal(suggest(s),nil,'compressed enumeration still preserves a possible random clear')
  s=large();s.consumeables[1].ability.consumeable={tarots=2}
  equal(suggest(s),nil,'modified Judgement generation configuration is rejected')
  s=large();s.consumeables[1].ability.name='The Emperor'
  equal(suggest(s),nil,'mismatched runtime Judgement name is rejected')
end

do
  local variants={
    function(s) s.hand[1].enhancement='m_mult' end,
    function(s) s.hand[1].seal='Red' end,
    function(s) s.hand[1].edition={foil=true} end,
    function(s) s.hand[1].ability.perma_bonus=5 end,
    function(s) s.hand[1].ability.mult=4 end,
    function(s) s.hand[1].ability.mult='4' end,
    function(s) s.hand[1].nominal=9 end,
    function(s) s.hand[1].face_down=true end,
    function(s) s.jokers={joker('The Duo',{type='Pair',x_mult=2})} end,
    function(s) s.jokers={joker('Hanging Chad',{extra=2})} end,
    function(s) s.jokers={joker('Mime',{extra=1})} end,
    function(s) s.jokers={joker('Scholar',{extra={chips=20,mult=4}})} end,
    function(s) s.jokers={joker('Blueprint'),joker('Joker')} end,
    function(s) s.jokers={joker('Joker',{mult=0.5})} end,
    function(s) s.jokers={joker('Joker',{mult=1048577})} end,
    function(s) s.jokers={joker('Joker')};s.jokers[1].edition={holo=true} end,
    function(s) s.hands.Pair={chips=10.5,mult=2} end,
    function(s) s.dollars=3.5 end,
    function(s) s.first_used_hand_level=1048577 end,
    function(s) s.used_vouchers={v_observatory=true} end,
    function(s) s.modifiers.balance=true end,
    function(s) s.deck=nil end,
    function(s) s.playing_cards=nil end,
    function(s) s.hands.Pair={chips='10',mult=2} end,
    function(s) s.dollars='3' end,
    function(s) s.first_used_hand_level='1' end,
    function(s) s.current_round.hands_left='1' end,
    function(s) s.consumeable_usage_total={tarot='10'} end,
    function(s) s.probabilities.normal='1' end,
    function(s) s.jokers[1].ability.mult='30' end,
    function(s) s.jokers={joker('Stone Joker',{stone_tally='10'})} end,
    function(s) s.jokers={joker('Misprint',{extra={min=0,max='23'}})} end,
    function(s) s.jokers[1].edition={chips='50'} end,
    function(s) s.consumeables[1].edition={chips='50'} end,
    function(s) for i=2,121 do s.consumeables[i]=judgement() end;s.consumable_limit=121 end,
  }
  for i,change in ipairs(variants) do
    local s=large();change(s)
    check(not S.upper_bound_order_independent(s),'unsupported equivalence domain '..i..' is rejected')
    equal(suggest(s),nil,'large-hand generator domain '..i..' abstains without order compression')
  end
  local s=large();s.jokers={joker('Perkeo')}
  equal(suggest(s),nil,'unknown generated inventory never spends a Perkeo engine')
  s=large();s.jokers={joker('Mr. Bones')}
  equal(suggest(s),nil,'Mr. Bones prevents a false terminal-loss premise')
  s=large();local calls=0
  equal(suggest(s,{strategy={preservation_cost=function() calls=calls+1;return 20,'Keep the inventory.',false end}}),nil,
    'whole-inventory preservation still blocks an unknown Judgement reveal')
  equal(calls,1,'Judgement checks complete inventory preservation exactly once')
end

do
  local modules={scoring=S,score_cache=Cache,search=Search,consumables=C,
    strategy=dofile('Brainstorm/Advisor/strategy.lua'),ordering=dofile('Brainstorm/Advisor/ordering.lua'),
    hand_ordering=dofile('Brainstorm/Advisor/hand_ordering.lua'),boss_rescue=dofile('Brainstorm/Advisor/boss_rescue.lua'),
    mixed_rescue=dofile('Brainstorm/Advisor/mixed_rescue.lua')}
  local s=large();local result=Decision.run(s,modules)
  check(result.consumable and result.consumable.generator,'normal decision integrates larger-hand Judgement revelation')
  equal(result.action.kind,'use','the only presented execution is the user-clicked owned use')
  equal(result.action.index,1,'normal integration preserves the actual owned index')
  s.blind.chips=s.chips+1
  result=Decision.run(s,modules)
  check(result.fast_clear and not result.consumable,'existing fast clear bypasses the generator proof')
  check(result.evaluations<=70,'the seventy-score fast-clear allowance is preserved')
end

print('advisor_judgement_rescue: '..checks..' checks passed')
