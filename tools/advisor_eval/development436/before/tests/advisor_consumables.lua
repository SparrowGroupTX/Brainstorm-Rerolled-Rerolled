local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,label) assert(v,label); checks=checks+1 end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local next_id=0
local function card(rank,suit,enhancement)
  next_id=next_id+1
  return {id='c'..next_id,rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(rank,10),
    enhancement=enhancement or 'c_base',ability={}}
end
local function joker(name,ability)
  ability=ability or {}; ability.name=name
  return {name=name,ability=ability,blueprint_compat=true}
end
local function owned(key,name,set,config)
  return {key=key,name=name,ability={name=name,set=set or 'Tarot',consumeable=config or {}}}
end
local function state(cards,inventory,jokers)
  return {phase='hand',hand=cards,playing_cards=cards,deck={},jokers=jokers or {},consumeables=inventory,
    hands={},blind={chips=1000},chips=0,dollars=10,hands_left=1,hands_played=0,
    hand_limit=5,hand_size=#cards,discards_left=0,discards_used=0,modifiers={},
    probabilities={normal=1},current_round={hands_left=1,hands_played=0,discards_left=0},
    consumeable_usage_total={tarot=0,planet=0,spectral=0,all=0,tarot_planet=0}}
end
local function baseline(s) return Search.run(s,Scoring,{max_evaluations=3000}) end
local function suggest(s,result,options) return Consumables.suggest(s,Scoring,result or baseline(s),nil,options) end
local function has(t,value) for _,v in ipairs(t or {}) do if v==value then return true end end; return false end

do
  local s=state({card(13,'Hearts'),card(12,'Hearts'),card(11,'Hearts'),card(9,'Hearts'),card(14,'Clubs')},
    {owned('c_sun','The Sun','Tarot',{suit_conv='Hearts',max_highlighted=3})})
  s.blind.chips=300
  local base=baseline(s); equal(base.play.hand,'High Card','initial hand cannot flush')
  local use=suggest(s,base)
  check(use~=nil,'held suit Tarot is considered before a losing play')
  equal(use.action.kind,'use','consumable action is explicit')
  equal(use.action.index,1,'action references the held inventory card')
  equal(table.concat(use.action.targets,','),'5','convert only the off-suit Ace')
  equal(use.play.hand,'Flush','suit conversion changes the poker hand')
  check(use.play.score>=300,'the transformed flush secures the modeled clear')
end

do
  local s=state({card(13)}, {owned('c_strength','Strength','Tarot',{mod_conv='up_rank',max_highlighted=2})},
    {joker('Scholar',{extra={chips=20,mult=4}})})
  s.blind.chips=100
  local use=suggest(s)
  check(use~=nil,'Strength recognizes Scholar activation at Ace')
  equal(use.play.score,180,'Scholar chips and Mult use the transformed Ace')
  local after=Consumables.apply(s,1,use.action.targets)
  equal(after.hand[1].rank,14,'Strength turns King into Ace')
  s.hand[1]=card(14); s.playing_cards=s.hand
  after=Consumables.apply(s,1,{1})
  equal(after.hand[1].rank,2,'Strength wraps Ace to two')
  equal(s.hand[1].rank,14,'Strength does not mutate the source Ace')
end

do
  local s=state({card(14,'Hearts')},{owned('c_world','The World','Tarot',{suit_conv='Spades',max_highlighted=3})},
    {joker('Arrowhead',{extra=50})})
  s.blind.chips=60
  local use=suggest(s)
  check(use~=nil,'suit Tarot recognizes a suit-conditional Joker')
  equal(use.play.score,66,'Arrowhead scores the converted Spade')
end

do
  local s=state({card(14),card(13,'Hearts')},{owned('c_strength','Strength')},
    {joker('The Duo',{type='Pair',x_mult=2})})
  s.blind.chips=100
  local use=suggest(s)
  equal(use.play.hand,'Pair','a rank transformation activates a hand-type Joker')
  equal(use.play.score,128,'The Duo applies after Strength creates the pair')
  s=state({card(14)},{owned('c_heirophant','The Hierophant','Tarot',{mod_conv='m_bonus',max_highlighted=2})})
  s.blind.chips=40
  equal(suggest(s).play.score,46,'the actual vanilla c_heirophant key is supported')
end

do
  local left,right=card(2),card(14,'Hearts'); right.edition={foil=true}; right.seal='Red'
  local s=state({left,right},{owned('c_death','Death','Tarot',{mod_conv='card',min_highlighted=2,max_highlighted=2})})
  s.blind.chips=200
  local use=suggest(s)
  check(use~=nil,'Death copies a valuable right-hand card to secure a clear')
  equal(table.concat(use.action.targets,','),'1,2','Death targets preserve hand order')
  local after=Consumables.apply(s,1,{1,2})
  equal(after.hand[1].rank,14,'Death copies right onto left')
  equal(after.hand[1].id,left.id,'Death preserves destination physical identity')
  equal(after.hand[1].seal,'Red','Death copies seals')
  check(after.hand[1].edition.foil,'Death copies editions')
  equal(after.hand[2].id,right.id,'Death preserves source identity')
  s.hand={right,left}; s.playing_cards=s.hand
  equal(suggest(s),nil,'Death does not silently reverse direction to copy a left-hand Ace')
  equal(Consumables.apply(s,1,{2,1}),nil,'reversed Death target indices are rejected')
end

do
  local c=card(14,'Spades','m_bonus'); c.ability={bonus=30,perma_bonus=7}
  local s=state({c},{owned('c_empress','The Empress','Tarot',{mod_conv='m_mult',max_highlighted=2})})
  s.blind.chips=100
  local use=suggest(s)
  equal(use.play.score,115,'enhancement replacement removes old bonus but keeps Hiker chips')
  local after=Consumables.apply(s,1,{1})
  equal(after.hand[1].ability.bonus,0,'old enhancement bonus is cleared')
  equal(after.hand[1].ability.perma_bonus,7,'permanent chips survive enhancement conversion')
  equal(after.hand[1].enhancement,'m_mult','the replacement enhancement is recorded')
end

do
  local s=state({card(14)},{owned('c_tower','The Tower','Tarot',{mod_conv='m_stone',max_highlighted=1})},
    {joker('Stone Joker',{extra=25,stone_tally=0})})
  s.blind.chips=70
  local use=suggest(s)
  equal(use.play.score,80,'Stone conversion updates both card chips and Stone Joker tally')
  local after=Consumables.apply(s,1,{1})
  equal(after.jokers[1].ability.stone_tally,1,'the full deck has one Stone card')
  equal(s.jokers[1].ability.stone_tally,0,'source Stone tally is untouched')
end

do
  local s=state({card(14)},{owned('c_empress','The Empress','Tarot',{mod_conv='m_mult',max_highlighted=2})},
    {joker("Driver's License",{driver_tally=15})})
  s.playing_cards={s.hand[1]}
  for i=1,15 do s.playing_cards[#s.playing_cards+1]=card(2,'Hearts','m_bonus') end
  s.blind.chips=200
  local use=suggest(s)
  equal(use.play.score,240,'the sixteenth enhancement activates Driver\'s License')
  local after=Consumables.apply(s,1,{1})
  equal(after.jokers[1].ability.driver_tally,16,'full playing-card inventory is recounted')
end

do
  local s=state({card(14),card(2,'Hearts')},{owned('c_chariot','The Chariot','Tarot',{mod_conv='m_steel',max_highlighted=1})},
    {joker('Steel Joker',{steel_tally=0,extra=0.2})})
  s.blind.chips=25
  local use=suggest(s)
  equal(table.concat(use.action.targets,','),'2','Steel can be placed on a held non-scoring card')
  equal(use.play.score,28,'held Steel and updated Steel Joker multiply together')
end

do
  local s=state({card(14)},{owned('c_pluto','Pluto','Planet',{hand_type='High Card'})},
    {joker('Constellation',{x_mult=2,extra=0.1})})
  s.blind.chips=100
  local use=suggest(s)
  equal(use.play.score,109,'Planet levels and Constellation growth are both applied')
  local after=Consumables.apply(s,1,{})
  equal(after.jokers[1].ability.x_mult,2.1,'Constellation grows once per physical Joker')
  equal(after.consumeable_usage_total.planet,1,'Planet usage is updated')
  equal(#after.consumeables,0,'the used Planet no longer remains held')
end

do
  local s=state({card(14),card(14,'Hearts')},{owned('c_mercury','Mercury','Planet',{hand_type='Pair'})})
  s.used_vouchers={v_observatory=true}
  s.hands.Pair={level=10,chips=145,mult=11,s_chips=10,s_mult=2,l_chips=15,l_mult=1}
  s.blind.chips=3000
  equal(suggest(s),nil,'high-level Observatory Planet is held when consumption lowers the score')
  s.hands.Pair=nil; s.blind.chips=130
  local use=suggest(s)
  equal(use.play.score,141,'a low-level upgrade can outweigh the lost Observatory multiplier')
end

do
  local s=state({card(14)},{owned('c_black_hole','Black Hole','Spectral')})
  s.blind.chips=50
  local use=suggest(s)
  equal(use.play.score,52,'Black Hole improves the playable hand')
  local after=Consumables.apply(s,1,{})
  equal(after.hands['Flush Five'].level,2,'Black Hole also upgrades hidden hand types')
  equal(after.consumeable_usage_total.spectral,1,'Black Hole is Spectral, not a Planet use')
end

do
  local s=state({card(14)},{owned('c_hermit','The Hermit')},{joker('Fortune Teller')})
  s.dollars=0; s.blind.chips=30
  local use=suggest(s)
  equal(use.play.score,32,'Tarot use can activate Fortune Teller despite zero Hermit payout')
  local after=Consumables.apply(s,1,{})
  equal(after.dollars,0,'Hermit never creates dollars from a zero balance')
  equal(after.consumeable_usage_total.tarot,1,'Tarot usage advances exactly once')
end

do
  local s=state({card(14)},{owned('c_hermit','The Hermit')},{joker('Bull',{extra=2})})
  s.blind.chips=50
  local use=suggest(s)
  equal(use.play.score,56,'Hermit earnings improve Bull before the play')
  local after=Consumables.apply(s,1,{})
  equal(after.dollars,20,'Hermit doubles ten dollars')
  s.consumeables={owned('c_temperance','Temperance')}; s.jokers[1].sell_cost=20
  use=suggest(s)
  equal(use.play.score,76,'Temperance uses Joker sale value before scoring Bull')
end

do
  local s=state({card(14)},{owned('c_empress','The Empress')})
  s.blind.chips=15
  equal(suggest(s),nil,'an already clearing play saves a targeted Tarot')
  s.consumeables={owned('c_pluto','Pluto','Planet',{hand_type='High Card'})}
  check(suggest(s)~=nil,'a safe permanent Planet upgrade can precede an already clearing play')
  s.consumeables={owned('c_mars','Mars','Planet',{hand_type='Four of a Kind'})}
  equal(suggest(s),nil,'an unrelated Planet with no current benefit stays held')
  s.blind.chips=70; s.consumeables={owned('c_empress','The Empress')}
  local base=baseline(s); base.kind='discard'; base.discard={mean=100,probability=1}
  equal(suggest(s,base),nil,'a guaranteed modeled discard clear saves the targeted Tarot')
end

do
  local s=state({card(14),card(13,'Hearts')},{owned('c_strength','Strength')})
  s.blind={name='The Mouth',key='bl_mouth',only_hand='Pair',chips=40}
  local base=baseline(s); equal(base.play,nil,'there is currently no legal Mouth play')
  local use=suggest(s,base)
  check(use~=nil,'a transformation can create a legal hand when the baseline has no play')
  equal(use.play.hand,'Pair','Strength creates the required pair of Aces')
end

do
  local s=state({card(14),card(14,'Hearts')},{owned('c_mercury','Mercury','Planet',{hand_type='Pair'})})
  s.blind={name='The Arm',key='bl_arm',chips=40}
  local base=baseline(s)
  local use=Consumables.suggest(s,Scoring,base,nil,{arm_cost=Search.arm_cost})
  equal(use,nil,'do not consume a Planet that The Arm immediately cancels on an existing clear')
  s.consumeables={owned('c_pluto','Pluto','Planet',{hand_type='High Card'})}
  s.jokers={joker('Constellation',{x_mult=3,extra=0.1})}
  s.hands.Pair={level=2,chips=25,mult=3,l_chips=15,l_mult=1,s_chips=10,s_mult=2,played=10}
  s.blind.chips=195
  local saw_projected=false
  use=Consumables.suggest(s,Scoring,baseline(s),nil,{arm_cost=function(projected,hand)
    if projected.hands['High Card'].level==2 then saw_projected=true end
    return Search.arm_cost(projected,hand)
  end})
  check(saw_projected,'Arm future costs are evaluated against the transformed hand levels')
  equal(use.play.hand,'Pair','an Arm downgrade remains acceptable when needed to survive')
  check(use.play.score>=195,'Constellation growth can make the necessary Arm play clear')
end

do
  local s=state({card(14,'Hearts')},{owned('c_world','The World')})
  s.hand[1].debuff=true; s.blind={name='The Head',key='bl_head',chips=12,debuff={suit='Hearts'}}
  local use=suggest(s)
  equal(use.play.score,16,'suit conversion recomputes the blind debuff')
  s.hand[1].ability.perma_debuff=true
  equal(suggest(s),nil,'suit conversion does not remove a permanent challenge debuff')
end

do
  local s=state({card(14)},{owned('c_wheel_of_fortune','The Wheel of Fortune')})
  local use,evaluations,diagnostics=suggest(s)
  equal(use,nil,'unsupported random transformations fail closed')
  equal(evaluations,0,'unsupported actions do not consume the scoring budget')
  check(#diagnostics.warnings>0,'unsupported held actions are disclosed')
  s.consumeables={owned('c_modded_empress','The Empress')}
  equal(suggest(s),nil,'a custom consumable cannot masquerade as a vanilla action by name')
end

do
  local s=state({card(14),card(13,'Hearts'),card(11,'Clubs'),card(9,'Diamonds'),card(7),card(5,'Hearts'),card(3,'Clubs'),card(2,'Diamonds')},
    {owned('c_empress','The Empress')})
  s.blind.chips=70
  local base=baseline(s); local before=Snapshot.fingerprint(s)
  local old_random,old_randomseed=math.random,math.randomseed
  local old_pseudorandom,old_pseudoseed=pseudorandom,pseudoseed
  math.random=function() error('consumables used global RNG') end
  math.randomseed=function() error('consumables seeded global RNG') end
  pseudorandom=function() error('consumables used game RNG') end
  pseudoseed=function() error('consumables used game seed') end
  local yields=0
  local first,evaluations,diagnostics=Consumables.suggest(s,Scoring,base,function() yields=yields+1 end,{max_evaluations=450})
  local second=Consumables.suggest(s,Scoring,base,nil,{max_evaluations=450})
  math.random,math.randomseed=old_random,old_randomseed
  pseudorandom,pseudoseed=old_pseudorandom,old_pseudoseed
  check(first~=nil,'a fully scored candidate can be reported under a small bounded budget')
  equal(evaluations,436,'only complete 218-play comparisons consume the budget')
  equal(diagnostics.evaluated_candidates,2,'two target choices are evaluated completely')
  equal(diagnostics.truncated,true,'target shortlisting is disclosed')
  equal(yields,math.floor(evaluations/32),'long scoring work yields consistently')
  equal(Snapshot.fingerprint(first),Snapshot.fingerprint(second),'unchanged states produce identical consumable advice')
  equal(Snapshot.fingerprint(s),before,'no source cards, abilities, or inventory are mutated')
  local none,cost,diag=Consumables.suggest(s,Scoring,base,nil,{max_evaluations=200})
  equal(none,nil,'a partial legal-play enumeration is never published')
  equal(cost,0,'insufficient budget does not start a partial comparison')
  equal(diag.truncated,true,'insufficient budget is disclosed')
end

print('advisor_consumables: '..checks..' checks passed')
