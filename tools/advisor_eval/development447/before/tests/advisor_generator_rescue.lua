local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Cache=dofile('Brainstorm/Advisor/score_cache.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,label) assert(v,label);checks=checks+1 end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r
end
local serial=0
local function card(rank,suit,enhancement)
  serial=serial+1
  return {id='generator-test-'..serial,rank=rank,suit=suit or 'Spades',
    nominal=rank==14 and 11 or math.min(rank,10),enhancement=enhancement or 'c_base',ability={}}
end
local function joker(name,a) a=a or {};a.name=name;return {name=name,ability=a,blueprint_compat=true} end
local function owned(key,config)
  local name=key=='c_emperor' and 'The Emperor' or key=='c_high_priestess' and 'The High Priestess' or 'Mercury'
  return {key=key,name=name,ability={name=name,set=key=='c_mercury' and 'Planet' or 'Tarot',
    consumeable=config or (key=='c_emperor' and {tarots=2} or key=='c_high_priestess' and {planets=2} or {hand_type='Pair'})}}
end
local function state(cards,inventory,jokers)
  return {phase='hand',hand=cards,playing_cards=cards,deck={},jokers=jokers or {},
    consumeables=inventory or {owned('c_emperor')},consumable_limit=2,hands={},
    blind={chips=1000},chips=0,dollars=10,hands_left=1,hands_played=0,hand_limit=5,
    hand_size=#cards,discards_left=0,modifiers={},probabilities={normal=1},ante=3,
    current_round={hands_left=1,hands_played=0,discards_left=0},
    consumeable_usage_total={tarot=0,planet=0,spectral=0,all=0,tarot_planet=0}}
end
local function suggest(s,options,scorer)
  local base=Search.run(s,Scoring,{max_evaluations=1000})
  return Consumables.suggest(s,scorer or Scoring,base,nil,options)
end

do
  local s=state({card(14),card(8,'Hearts'),card(5,'Clubs')})
  local use,count,diag=suggest(s)
  check(use and use.generator,'an otherwise losing hand considers its owned generator')
  equal(use.action.kind,'use','public action is a consumable use')
  equal(use.action.index,1,'use the owned card')
  equal(#use.action.targets,0,'generator has no hand targets')
  equal(use.generator.count,2,'removal leaves capacity for two generated cards')
  equal(count,15,'all ordered nonempty plays are counted')
  check(diag.generator_ceiling.complete and diag.generator_ceiling.supported,'the certificate is complete and supported')
  equal(use.play,nil,'no invented post-reveal scored play')
  equal(use.generator.probability,nil,'no invented rescue probability')
  check(use.generator.public_replan,'public reveal requires replanning')
  equal(Consumables.apply(s,1,{}),nil,'pure transitions do not invent generated identities')
  equal(#s.consumeables,1,'the input inventory stays unchanged')
  equal(s.consumeables[1].key,'c_emperor','input owned identity is preserved')
end

do
  -- The development loss pattern is a mechanics fixture, not a seed-specific
  -- policy or a replayed rescued attempt. The complete maximum is 15,080.
  local cards={card(14,'Spades','m_mult'),card(14,'Diamonds','m_mult'),card(6),card(3,'Hearts'),card(3,'Diamonds')}
  local row={joker('Misprint',{extra={min=0,max=23}}),joker('Joker'),joker('Abstract Joker',{extra=3}),
    joker('The Duo',{type='Pair',x_mult=2}),joker('Banner',{extra=30}),
    joker('Card Sharp',{extra={Xmult=3}}),joker('Blue Joker',{extra=2})}
  local s=state(cards,nil,row);s.blind.chips=20000
  for i=1,41 do s.deck[i]=card(2) end
  local use,count,diag=suggest(s)
  check(use and use.generator,'the demonstrated supported generator omission is repaired')
  equal(use.generator.immediate_ceiling,15080,'all random and Joker-order maxima remain below the target')
  equal(count,325,'all ordered plays of the five-card hand are covered')
  equal(diag.generator_ceiling.legal_plays,325,'all unconstrained ordered plays are legal')
end

do
  local s=state({card(14)},nil,{joker('Misprint',{extra={min=0,max=23}})})
  s.blind.chips=300
  check(Scoring.score(s,{1}).score<300,'Misprint mean loses this counterexample')
  equal(Scoring.upper_bound(s,{1}).score,384,'Misprint maximum includes its positive upside')
  equal(suggest(s),nil,'a losing mean cannot certify a losing play')
  s=state({card(14,'Hearts','m_lucky')});s.blind.chips=200
  check(Scoring.score(s,{1}).score<200,'Lucky mean loses this counterexample')
  equal(Scoring.upper_bound(s,{1}).score,336,'Lucky maximum includes all possible Mult triggers')
  equal(suggest(s),nil,'Lucky upside retains the immediate play')
  s=state({card(14,'Hearts')},nil,{joker('Bloodstone',{extra={odds=2,Xmult=3}})})
  s.blind.chips=40
  equal(Scoring.upper_bound(s,{1}).score,48,'Bloodstone maximum includes its trigger')
  equal(suggest(s),nil,'Bloodstone upside is never treated as a certain loss')
  s=state({card(14)},nil,{joker('Space Joker',{extra=4})});s.blind.chips=40
  equal(Scoring.upper_bound(s,{1}).score,52,'Space Joker maximum includes an immediate level')
  equal(suggest(s),nil,'Space Joker upside prevents false impossibility')
end

do
  local s=state({card(14),card(14,'Hearts')},nil,{joker('The Duo',{type='Pair',x_mult=2}),joker('Joker')})
  s.blind.chips=300
  equal(Scoring.score(s,{1,2}).score,256,'the current row order loses')
  equal(Scoring.upper_bound(s,{1,2}).score,384,'independent additive-before-multiplier order is bounded')
  equal(suggest(s),nil,'a possible Joker reorder prevents a false loss certificate')
  equal(s.jokers[1].name,'The Duo','upper-bound sorting does not reorder the source row')
end

do
  -- Exhaust a small independent row's orders and selected-card orders. This
  -- checks an actual ordering counterfactual, not only the implementation's
  -- canonical order. Card editions and enhancement Mult may be interleaved.
  local first,second=card(14,'Spades','m_mult'),card(14,'Hearts')
  second.edition={polychrome=true}
  local s=state({first,second},nil,{joker('The Duo',{type='Pair',x_mult=2}),
    joker('Joker'),joker('Scholar',{extra={chips=20,mult=4}})})
  local max_bound=math.max(Scoring.upper_bound(s,{1,2}).score,Scoring.upper_bound(s,{2,1}).score)
  local original=clone(s.jokers)
  for a=1,3 do for b=1,3 do if b~=a then
    local c=6-a-b;s.jokers={original[a],original[b],original[c]}
    check(Scoring.score(s,{1,2}).score<=max_bound,'maximum bounds each Joker order, first card order')
    check(Scoring.score(s,{2,1}).score<=max_bound,'maximum bounds each Joker order, reversed card order')
  end end end
end

do
  local s=state({card(14),card(14,'Hearts')},{owned('c_emperor'),owned('c_mercury')})
  s.blind.chips=120
  local use=suggest(s)
  equal(use.action.index,2,'a deterministic owned Planet rescue takes priority over a generator')
  equal(use.generator,nil,'a known rescue is retained')
  s.blind.chips=90;s.used_vouchers={v_observatory=true}
  check(Scoring.upper_bound(s,{1,2}).score>=90,'the maximum includes the held Observatory Planet')
  use=suggest(s,{strategy=Strategy})
  check(not use or not use.generator,'held Observatory scoring prevents a false generator-rescue certificate')
end

do
  local s=state({card(14)},{owned('c_high_priestess')})
  local use=suggest(s)
  equal(use.generator.set,'Planet','High Priestess reveals Planets but remains an owned Tarot')
  equal(use.generator.count,2,'High Priestess source count is respected')
  s.consumeables={owned('c_emperor'),owned('c_emperor')}
  equal(suggest(s).generator.count,1,'a full ordinary inventory frees one slot before generation')
  s.consumeables[1].edition={negative=true};s.consumeables[2].debuff=true
  equal(suggest(s),nil,'a Negative card removing its own slot cannot create a new slot')
  s.consumeables={owned('c_emperor')};s.consumeables[1].edition={negative=true};s.consumable_limit=3
  equal(suggest(s).generator.count,2,'Negative slot removal preserves other available capacity')
end

do
  local s=state({card(14)},nil,{joker('Perkeo')})
  equal(suggest(s),nil,'without inventory valuation an active copying engine is protected')
  equal(suggest(s,{strategy=Strategy}),nil,'whole-inventory future copying value protects the last generator source')
  equal(suggest(s,{strategy={preservation_cost=function() return 0,nil,false end}}),nil,
    'removal-only value cannot certify an unknown generated Perkeo copying pool')
  local called=false
  local strategy={preservation_cost=function(before,after,index)
    called=true;equal(#before.consumeables,1,'valuation receives the complete original inventory')
    equal(#after.consumeables,0,'valuation sees the actual removal');equal(index,1,'valuation receives the owned index')
    return 10,'Retain the inventory engine.',false
  end}
  equal(suggest(state({card(14)}),{strategy=strategy}),nil,'positive retained-inventory value is not spent on an unknown rescue')
  check(called,'whole-inventory preservation valuation is called')
end

do
  local variants={
    function(s) s.hands_left=2 end,
    function(s) s.discards_left=1 end,
    function(s) s.hand[1].face_down=true end,
    function(s) s.jokers={joker('Unknown Joker')} end,
    function(s) s.jokers={joker('Mr. Bones')} end,
    function(s) s.jokers={joker('Blueprint'),joker('Joker')} end,
    function(s) s.jokers={joker('Midas Mask')} end,
    function(s) s.jokers={joker('Joker',{mult=-4})} end,
    function(s) s.jokers={joker('Joker')};s.jokers[1].key='j_custom' end,
    function(s) s.blind.key='bl_custom' end,
    function(s) s.hand[1].ability.h_mult=4 end,
    function(s) s.consumeables[1].ability.consumeable.tarots=0 end,
    function(s) s.consumeables[1].ability.consumeable.mod_conv='m_glass' end,
    function(s) s.consumable_limit=nil end,
    function(s) s.probabilities.normal=0/0 end,
    function(s) s.hand[1].rank=15 end,
    function(s) s.jokers={joker('Cavendish',{extra={Xmult=0.5}}),joker('Joker')} end,
    function(s) s.jokers={joker('Acrobat',{extra=0.5}),joker('Joker')} end,
    function(s) s.jokers={joker('Bloodstone',{extra={odds=2,Xmult=0.5}})} end,
    function(s) s.hand_limit=1.5 end,
    function(s) s.jokers={joker('Dusk',{extra=100})} end,
    function(s) for i=1,99 do s.jokers[i]=joker('Mime',{extra=1}) end end,
  }
  for i,change in ipairs(variants) do
    local s=state({card(14)});change(s)
    equal(suggest(s),nil,'unsupported or nonfinal generator case '..i..' abstains')
  end
end

do
  local modules={scoring=Scoring,score_cache=Cache,search=Search,consumables=Consumables,
    strategy=Strategy,ordering=dofile('Brainstorm/Advisor/ordering.lua'),
    hand_ordering=dofile('Brainstorm/Advisor/hand_ordering.lua'),
    boss_rescue=dofile('Brainstorm/Advisor/boss_rescue.lua'),
    mixed_rescue=dofile('Brainstorm/Advisor/mixed_rescue.lua')}
  local s=state({card(14),card(7,'Hearts')})
  local result=Decision.run(s,modules)
  check(result.consumable and result.consumable.generator,'normal Jokerless decision reaches generator admission')
  equal(result.action.kind,'use','the normal decision presents only the user-clicked first use')
  s.jokers={joker('Ceremonial Dagger',{mult=12})};s.blind.chips=3000
  result=Decision.run(s,modules)
  check(result.consumable and result.consumable.generator,'a developed Dagger row also admits the generic last-hand reveal')
  equal(result.action.kind,'use','other specialists do not replace the reveal with a losing Dagger play')
  s.blind.chips=1
  result=Decision.run(s,modules)
  check(result.fast_clear and not result.consumable,'fast clears never enter generator ceiling search')
  check(result.evaluations<=70,'the existing fast-clear scoring allowance is preserved')
end

do
  local s=state({card(14),card(8),card(5)})
  local use,count,diag=suggest(s,{max_evaluations=14})
  equal(use,nil,'an incomplete ordered-play budget abstains')
  equal(count,0,'no partial ceiling comparison is started')
  check(not diag.generator_ceiling.complete,'insufficient-budget certificate stays incomplete')
  local wrapped,stats=Cache.new(Scoring)
  use,count,diag=suggest(s,nil,wrapped)
  equal(stats().score_calls,count,'ceiling passes are counted by the prepared scorer')
  equal(use.generator.immediate_ceiling,Scoring.upper_bound(s,{1}).score,'prepared and raw maxima agree')
  s.hand[1].ability.forced_selection=true
  use,count,diag=suggest(s)
  check(use and diag.generator_ceiling.legal_plays<count,'forced-card legality is checked for every ordered play')
end

print('advisor_generator_rescue: '..checks..' checks passed')
