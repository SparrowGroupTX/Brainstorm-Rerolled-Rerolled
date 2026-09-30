local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function equal(a,b,message) check(a==b,(message or 'Mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(rank,suit,id)
  return {id=id or tostring(rank)..tostring(suit),rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(10,rank),enhancement='c_base',ability={}}
end
local function owned(key,name,set,config)
  return {key=key,name=name,ability={name=name,set=set or 'Tarot',consumeable=config or {}}}
end
local function pluto() return owned('c_pluto','Pluto','Planet',{hand_type='High Card'}) end
local function empress() return owned('c_empress','The Empress','Tarot',{max_highlighted=2}) end
local function state(cards,inventory)
  return {phase='hand',hand=cards,playing_cards=cards,deck={},jokers={},consumeables=inventory,
    hands={},blind={chips=100},chips=0,dollars=10,hands_left=1,hands_played=0,hand_limit=5,
    hand_size=#cards,discards_left=0,discards_used=0,modifiers={},probabilities={normal=1},
    current_round={hands_left=1,hands_played=0,discards_left=0},consumeable_usage_total={all=0,planet=0,tarot=0}}
end
local function base(s) return Search.run(s,Scoring,{max_evaluations=3000,samples=0}) end
local function suggest(s,options,prior,scorer,yield_fn)
  return Consumables.suggest(s,scorer or Scoring,prior or base(s),yield_fn,options)
end

local old_random,old_randomseed,old_pseudorandom,old_pseudoseed=math.random,math.randomseed,pseudorandom,pseudoseed
math.random=function() error('Sequence search used global RNG') end
math.randomseed=function() error('Sequence search reseeded global RNG') end
pseudorandom=function() error('Sequence search used game RNG') end
pseudoseed=function() error('Sequence search used game seed') end

for _,reversed in ipairs({false,true}) do
  local inventory=reversed and {pluto(),empress()} or {empress(),pluto()}
  local s=state({card(14)},inventory)
  local before=Snapshot.fingerprint(s)
  equal(base(s).play.score,16,'Unassisted hand loses')
  equal(suggest(s,{sequences=false}),nil,'Neither single consumable can clear the last hand')
  local use,evaluations,diagnostics=suggest(s)
  check(use and use.sequence,'Two consumables jointly rescue the blind')
  equal(use.action.kind,'use');equal(use.action.index,reversed and 1 or 2,'Execute only the Planet first')
  equal(#use.action.targets,0,'The first use has no hand targets')
  equal(use.play.score,52,'Displayed after-use score belongs to the first transition only')
  equal(use.sequence.play.score,156,'Separate combined score includes both consumables')
  equal(use.sequence.second_name,'The Empress');equal(use.sequence.second_index,1,'Projected inventory shift is accurate')
  equal(use.sequence.targets[1],1);equal(use.sequence.action,nil,'No second executable action is queued')
  equal(evaluations,3,'Two complete singles plus one complete pair')
  equal(diagnostics.evaluated_candidates,2);equal(diagnostics.evaluated_sequences,1)
  check(table.concat(use.lines,' '):find('recalculate',1,true),'The follow-up explicitly asks for recomputation')
  equal(Snapshot.fingerprint(s),before,'Sequence planning does not mutate cards, inventory, or levels')
  equal(Snapshot.fingerprint(use),Snapshot.fingerprint(suggest(s)),'Repeated advice is identical')
  local after=assert(Consumables.apply(s,use.action.index,use.action.targets))
  local next_use=suggest(after)
  check(next_use and not next_use.sequence,'Recomputed follow-up is a single concrete use')
  equal(Snapshot.fingerprint(next_use),Snapshot.fingerprint(suggest(after)),'The follow-up is stable on an unchanged snapshot')
  equal(next_use.action.index,1,'The second use refers to its new current inventory index')
  equal(next_use.action.targets[1],1);equal(next_use.play.score,156,'Follow-up agrees with the projected clear')
  after=assert(Consumables.apply(after,next_use.action.index,next_use.action.targets))
  equal(#after.consumeables,0);equal(base(after).play.score,156,'The final real scorer confirms the play')
  equal(suggest(after),nil,'No contradictory extra consumable step after completion')
end

do
  local s=state({card(13,'Hearts'),card(12,'Hearts'),card(11,'Hearts'),card(9,'Hearts'),card(14,'Clubs')},
    {owned('c_jupiter','Jupiter','Planet',{hand_type='Flush'}),owned('c_sun','The Sun','Tarot',{suit_conv='Hearts',max_highlighted=3})})
  s.blind.chips=500
  equal(suggest(s,{sequences=false}),nil,'A Flush Planet alone has no hand and a suit Tarot alone is too weak')
  local use,evaluations,diagnostics=suggest(s)
  check(use and use.sequence,'The shortlist recognizes hand-type synergy, not only raw chip gains')
  equal(use.action.index,1);equal(use.sequence.play.hand,'Flush');equal(use.sequence.play.score,600)
  equal(table.concat(use.sequence.targets,','),'5','Only the off-suit card needs conversion')
  equal(use.play.hand,'High Card','First-use state does not pretend the suit changed already')
  check(evaluations<=25000 and evaluations%31==0,'All five-card-hand comparisons are complete and bounded')
  check(diagnostics.evaluated_sequences<=8,'Pair beam has a fixed maximum size')
  local after=assert(Consumables.apply(s,1,{}));local next_use=suggest(after)
  equal(next_use.action.index,1);equal(next_use.play.score,600);equal(next_use.action.targets[1],5)
  equal(Snapshot.fingerprint(next_use),Snapshot.fingerprint(suggest(after)),'Sun follow-up repeats deterministically')
  s.blind.only_hand='Flush';s.blind.name='The Mouth';s.blind.key='bl_mouth'
  use=suggest(s)
  check(use and use.sequence,'A two-card sequence can create the only legal Mouth hand')
  equal(use.play,nil,'There is no misleading immediate legal play before the second use')
  equal(use.sequence.play.hand,'Flush')
end

do
  local s=state({card(14)}, {empress(),pluto()})
  local use,evaluations,diagnostics=suggest(s,{max_evaluations=2})
  equal(use,nil,'No sequence published without its complete final comparison')
  equal(evaluations,2);equal(diagnostics.evaluated_sequences,0)
  check(diagnostics.sequence_truncated,'Insufficient sequence budget is disclosed')
  use,evaluations,diagnostics=suggest(s,{max_evaluations=3})
  check(use and use.sequence,'The exact three-pass budget is sufficient')
  equal(evaluations,3);equal(diagnostics.evaluated_sequences,1)
  s.blind.chips=70
  use,evaluations,diagnostics=suggest(s)
  check(use and not use.sequence,'Spend one card when one alone clears')
  equal(use.action.index,1,'The single Empress is the concrete clearing action')
  equal(diagnostics.evaluated_sequences,0,'No sequence work after a one-card clear')
  s.blind.chips=15
  use,evaluations,diagnostics=suggest(s)
  check(not use or not use.sequence,'An existing clear never spends a second consumable')
  equal(diagnostics.evaluated_sequences,0)
  s.blind.chips=100
  local prior=base(s);prior.kind='discard';prior.discard={probability=1,mean=150}
  use,evaluations,diagnostics=suggest(s,nil,prior)
  equal(use,nil,'A near-certain discard clear preserves both consumables');equal(diagnostics.evaluated_sequences,0)
  prior=base(s);prior.resource_comparison={samples=8,best={probability=1}}
  use,evaluations,diagnostics=suggest(s,nil,prior)
  equal(use,nil,'A strong sampled remaining-hand continuation preserves both consumables');equal(diagnostics.evaluated_sequences,0)
end

do
  local s=state({card(14)}, {owned('c_magician','The Magician'),pluto()})
  local use,_,diagnostics=suggest(s)
  equal(use,nil,'An expected Lucky clear does not justify spending both cards')
  check(diagnostics.evaluated_sequences>0,'The uncertain combination was actually checked')
  s.consumeables={empress(),pluto()};s.blind.name='The Arm';s.blind.key='bl_arm'
  equal(suggest(s),nil,'Do not spend a Planet that The Arm cancels before the combined play')
  s.blind={chips=100};s.hand={card(14),card(13,'Hearts')};s.playing_cards=s.hand
  s.hand[2].ability.forced_selection=true;s.consumeables[1].ability.consumeable.max_highlighted=1
  equal(Consumables.apply(s,1,{1}),nil,'A targeted consumable cannot omit the forced Bell card')
  local use=suggest(s)
  check(use and use.sequence,'The legal forced target can still form a winning combination')
  equal(table.concat(use.sequence.targets,','),'2','The projected second action obeys forced selection')
  local after=assert(Consumables.apply(s,use.action.index,use.action.targets))
  local next_use=suggest(after)
  equal(table.concat(next_use.action.targets,','),'2','The recomputed live target stays legal')
end

do
  local cards={};for i=1,12 do cards[i]=card(2,'Spades','low'..i) end;cards[13]=card(14,'Hearts','ace13')
  local s=state(cards,{empress(),pluto()});s.blind={chips=100,name='The Mouth',key='bl_mouth',only_hand='High Card'}
  local calls,yields=0,0
  local scorer={score=function(projected,indices) calls=calls+1;return Scoring.score(projected,indices) end}
  local before=Snapshot.fingerprint(s)
  local use,evaluations,diagnostics=suggest(s,{max_evaluations=50000},nil,scorer,function() yields=yields+1 end)
  check(use and use.sequence,'Expanded hands retain a bounded two-card rescue')
  equal(use.sequence.targets[1],13,'Target index 13 remains in original hand coordinates')
  equal(use.sequence.play.score,156);equal(evaluations,calls,'Every score call is charged to the shared budget')
  check(evaluations<=25000 and evaluations%2379==0,'13-card work uses complete common subset sets within 25k')
  equal(yields,math.floor(evaluations/32),'Pair work yields with the same cadence as singles')
  check(diagnostics.truncated and diagnostics.sequence_truncated,'Both bounded shortlists are explicit')
  equal(Snapshot.fingerprint(s),before,'Expanded-hand planning stays detached')
end

math.random,math.randomseed,pseudorandom,pseudoseed=old_random,old_randomseed,old_pseudorandom,old_pseudoseed
print('advisor_consumable_sequences: '..checks..' checks passed')
