local Rescue=dofile('Brainstorm/Advisor/boss_rescue.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function equal(a,b,m) check(a==b,(m or 'Mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local next_id=0
local function card(rank,suit,enhancement)
  next_id=next_id+1
  return {id='card'..next_id,rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(10,rank),
    enhancement=enhancement or 'c_base',ability={}}
end
local function joker(key,name,extra,sell)
  return {key=key,name=name,ability={name=name,extra=extra,h_size=0,d_size=0},sell_cost=sell or 2,blueprint_compat=true}
end
local function luchador(sell) return joker('j_luchador','Luchador',nil,sell) end
local function egg(sell) return joker('j_egg','Egg',3,sell) end
local function plus(mult) local j=joker('j_joker','Joker');j.ability.mult=mult or 4;return j end
local function state(key,name,target,hand,jokers)
  return {phase='hand',blind={key=key,name=name,boss=true,chips=target},hand=hand or {card(14)},
    jokers=jokers or {luchador()},deck={},playing_cards={},consumeables={},hands={},chips=0,dollars=10,
    hand_limit=5,hand_size=8,joker_limit=5,hands_left=3,discards_left=0,hands_played=0,
    current_round={hands_left=3,discards_left=0},round_resets={hands=4,discards=3},probabilities={normal=1},modifiers={}}
end
local function result(s,indices)
  local p=Scoring.score(s,indices or {1});p.indices=indices or {1};return {kind='play',play=p}
end
local function suggest(s,base,opts) return Rescue.suggest(s,Scoring,base or result(s),nil,opts) end
local function no_rescue(s,base)
  local use,work,diag=suggest(s,base);equal(use,nil,'No unsupported or wasteful rescue');return work,diag
end
local old_random,old_seed,old_pseudo,old_pseudoseed=math.random,math.randomseed,pseudorandom,pseudoseed
math.random=function() error('Boss rescue used global RNG') end
math.randomseed=function() error('Boss rescue seeded global RNG') end
pseudorandom=function() error('Boss rescue used game RNG') end
pseudoseed=function() error('Boss rescue used game seed') end

do
  local king=card(13);king.debuff=true
  local s=state('bl_plant','The Plant',100,{king},{luchador(),plus(10)})
  s.playing_cards=s.hand
  local base=result(s);equal(base.play.score,55)
  local before=Snapshot.fingerprint(s);local before_result=Snapshot.fingerprint(base)
  local use,work,diag=suggest(s,base)
  check(use,'Selling Luchador restores Plant face-card scoring')
  equal(use.action.kind,'sell');equal(use.action.area,'jokers');equal(use.action.index,1)
  equal(use.play.score,165);equal(use.baseline_play.score,55);equal(use.projected_blind.disabled,true)
  equal(use.rescue.cash_gain,2);equal(use.rescue.remaining,100);equal(work,2);equal(diag.evaluated_sales,1)
  equal(Snapshot.fingerprint(s),before,'Live snapshot is untouched')
  equal(Snapshot.fingerprint(base),before_result,'Published recommendation is untouched')
  equal(Snapshot.fingerprint(use),Snapshot.fingerprint(suggest(s,base)),'Unchanged state has identical advice')
  check(table.concat(use.lines,' '):find('Recalculate after selling',1,true),'Sale requests a fresh decision')
  local after=Rescue.project(s,1)
  equal(after.playing_cards[1],after.hand[1],'Clone preserves aliases without mutating originals')
  equal(after.hand[1].debuff,false);equal(#after.jokers,1);equal(after.dollars,12)
  equal(Scoring.score(after,use.play.indices).score,use.play.score)
  no_rescue(after)
  king.ability.perma_debuff=true;no_rescue(s)
  equal(Rescue.project(s,1).hand[1].debuff,true,'Permanent challenge debuff survives disabling')
  king.ability.perma_debuff=nil;king.ability.perishable=true;king.ability.perish_tally=0
  equal(Rescue.project(s,1).hand[1].debuff,true,'Expired perishable debuff survives disabling')
end

do
  local ace=card(14);ace.debuff=true
  local s=state('bl_final_leaf','Verdant Leaf',70,{ace},{plus(),egg(3)})
  local use=suggest(s)
  check(use,'Leaf permits selling a non-Luchador Joker');equal(use.action.index,2)
  equal(use.play.score,80);equal(use.baseline_play.score,25)
  equal(Rescue.project(s,1).jokers[1].key,'j_egg','The actual chosen row index is removed')
  s.jokers[2].ability.eternal=true;no_rescue(s)
  s.jokers[2].ability.eternal=nil;s.modifiers.all_eternal=true;no_rescue(s)
  s.modifiers.all_eternal=nil;s.jokers[2].key='mod_egg';local projected,why=Rescue.project(s,1)
  equal(projected,nil);check(why:find('Unknown Joker',1,true),'Unknown sale callback is not invented')
  for _,j in ipairs({joker('j_invisible','Invisible Joker'),joker('j_diet_cola','Diet Cola')}) do
    s.jokers={j};projected,why=Rescue.project(s,1);equal(projected,nil)
    check(why:find('additional sale effect',1,true),'Extra sale effects are explicit blockers')
  end
end

do
  local s=state('bl_wall','The Wall',100);s.chips=40
  local use=suggest(s);check(use,'Wall reduction lets a current hand clear')
  equal(use.projected_blind.chips,50);equal(use.rescue.remaining,10);equal(use.play.score,16)
  equal(use.rescue.clears_on_sale,false)
  s.chips=55;use=suggest(s);check(use);equal(use.rescue.clears_on_sale,true)
  s.hands_left=0;s.current_round.hands_left=0;check(suggest(s),'Already sufficient chips require no additional hand')
  s.chips=40;no_rescue(s)
  s=state('bl_final_vessel','Violet Vessel',300);s.chips=105
  use=suggest(s);check(use);equal(use.projected_blind.chips,100,'Vessel target is divided by three')
  equal(use.rescue.clears_on_sale,true)
  s=state('bl_wall','The Wall',100);s.chips=90
  equal(no_rescue(s),0,'Keep Luchador when the ordinary play already clears')
end

do
  local s=state('bl_water','The Water',80,nil,{luchador(),joker('j_banner','Banner',30)})
  s.blind.discards_sub=3
  local use=suggest(s);check(use,'Restored Water discards reactivate Banner')
  equal(use.baseline_play.score,16);equal(use.play.score,106);equal(use.rescue.discards_gain,3)
  local after=Rescue.project(s,1);equal(after.discards_left,3);equal(after.current_round.discards_left,3)
  equal(after.round_resets.discards,3,'Restored current discards do not increase reset capacity')
  s.blind.discards_sub=nil;local work,diag=no_rescue(s);equal(work,0)
  check(table.concat(diag.warnings,' '):find('restoration count',1,true),'Missing source count is visible')

  s=state('bl_needle','The Needle',70,nil,{luchador(20),joker('j_bull','Bull',2)})
  s.hands_left=1;s.current_round.hands_left=1;s.blind.hands_sub=3
  use=suggest(s);check(use,'Sale cash improves Bull enough while Needle restores hands')
  equal(use.baseline_play.score,36);equal(use.play.score,76);equal(use.rescue.hands_gain,3)
  after=Rescue.project(s,1);equal(after.hands_left,4);equal(after.current_round.hands_left,4)
  s.jokers={luchador(),joker('j_dusk','Dusk')};s.blind.chips=30
  equal(result(s).play.score,27);after=Rescue.project(s,1);equal(Scoring.score(after,{1}).score,16)
  no_rescue(s)
  s.blind.hands_sub=nil;equal(Rescue.project(s,1),nil)
end

do
  local s=state('bl_manacle','The Manacle',70,nil,{luchador(20),joker('j_bull','Bull',2)})
  s.hand_size=7
  local use=suggest(s);check(use,'Manacle with an empty deck has an exact sale projection')
  equal(use.rescue.hand_size_delta,1);equal(use.play.score,76)
  s.deck={card(2)};local work,diag=no_rescue(s);equal(work,0)
  check(table.concat(diag.warnings,' '):find('draws and sorts unknown cards',1,true),'Unknown Manacle draws are not called a rescue')
end

do
  local camp=joker('j_campfire','Campfire',0.25);camp.ability.x_mult=1;camp.debuff=true
  local s=state('bl_final_heart','Crimson Heart',90,nil,{luchador(),plus(),camp})
  local use=suggest(s);check(use,'Luchador synchronously enables Campfire before selling_card')
  equal(use.baseline_play.score,80);equal(use.play.score,100)
  local after=Rescue.project(s,1);equal(after.jokers[2].ability.x_mult,1.25);equal(after.jokers[2].debuff,false)
  camp.ability.perishable=true;camp.ability.perish_tally=0
  after=Rescue.project(s,1);equal(after.jokers[2].ability.x_mult,1);equal(after.jokers[2].debuff,true);no_rescue(s)
  camp.ability.perishable=nil;camp.ability.perish_tally=nil
  s=state('bl_final_leaf','Verdant Leaf',90,nil,{egg(),camp,plus()})
  after=Rescue.project(s,1);equal(after.jokers[1].ability.x_mult,1,'Delayed Leaf disable happens after sale growth callback')
  equal(after.jokers[1].debuff,false)
  s=state('bl_plant','The Plant',30,{card(13)},{luchador(),joker('j_hanging_chad','Hanging Chad',2)})
  s.hand[1].debuff=true
  use=suggest(s);check(use,'Vanilla Chad is supported during boss-disable sales');equal(use.play.score,35)
end

do
  local steel=card(2,'Clubs','m_steel');steel.ability.forced_selection=true
  local s=state('bl_final_bell','Cerulean Bell',20,{card(14),steel},{luchador()})
  s.playing_cards=s.hand
  local use=suggest(s,result(s,{1,2}));check(use,'Bell release can retain forced Steel in hand')
  equal(use.play.score,24);equal(table.concat(use.play.indices,','),'1')
  equal(Rescue.project(s,1).hand[2].ability.forced_selection,nil)
  equal(steel.ability.forced_selection,true,'Source forced selection is preserved')
  local king=card(13);king.face_down=true;king.facing='back';king.ability.wheel_flipped=true
  s=state('bl_mark','The Mark',30,{king},{luchador(10),joker('j_bull','Bull',2)});s.dollars=0
  local after=Rescue.project(s,1)
  equal(after.hand[1].face_down,false);equal(after.hand[1].facing,'front');equal(after.hand[1].ability.wheel_flipped,nil)
  use=suggest(s);check(use,'Mark disable reveals the currently hidden scoring card')
  equal(use.play.score,35);equal(use.play.uncertain,false)
  s.blind={key='bl_plant',name='The Plant',boss=true,chips=30}
  equal(Rescue.project(s,1).hand[1].face_down,true,'Other bosses do not reveal held card identity')
end

do
  local s=state('bl_final_leaf','Verdant Leaf',100,nil,{egg(10),joker('j_swashbuckler','Swashbuckler',nil,2)})
  s.jokers[2].ability.mult=10
  local after=Rescue.project(s,1);equal(after.jokers[1].ability.mult,0,'Swashbuckler loses sold Egg resale value')
  equal(Scoring.score(after,{1}).score,16,'No stale Swashbuckler clear')
  local stencil=joker('j_stencil','Joker Stencil');stencil.ability.x_mult=4
  s.jokers={egg(),stencil};s.joker_limit=5
  after=Rescue.project(s,1);equal(after.jokers[1].ability.x_mult,5);equal(Scoring.score(after,{1}).score,80)
  s.jokers[1].edition={negative=true}
  after=Rescue.project(s,1);equal(after.joker_limit,4);equal(after.jokers[1].ability.x_mult,4)
  s.jokers={egg(),joker('j_abstract','Abstract Joker',3)}
  after=Rescue.project(s,1);equal(Scoring.score(after,{1}).score,64,'Abstract counts the surviving row')

  s.jokers={egg(10)};s.dollars=9;s.hand_size=7;s.modifiers.minus_hand_size_per_X_dollar=5
  after=Rescue.project(s,1);equal(after.hand_size,5,'Luxury Tax includes cash crossing multiple thresholds')
  local andy=joker('j_merry_andy','Merry Andy');andy.ability.h_size=-1;andy.ability.d_size=3
  s.modifiers={};s.jokers={andy};s.hand_size=7;s.discards_left=4;s.current_round.discards_left=4;s.round_resets.discards=6
  after=Rescue.project(s,1);equal(after.hand_size,8);equal(after.discards_left,1)
  equal(after.current_round.discards_left,1);equal(after.round_resets.discards,3)
  s.deck={card(2)};equal(Rescue.project(s,1),nil,'Hand growth with unknown draw/sort is skipped')
  s.deck={};s.jokers={joker('j_troubadour','Troubadour',{h_size=2,h_plays=-1})};s.hand_size=10;s.round_resets.hands=3
  after=Rescue.project(s,1);equal(after.hand_size,8);equal(after.round_resets.hands,4);equal(after.hands_left,3)
  s.jokers={joker('j_oops','Oops! All 6s')};s.probabilities={normal=2,extra=4}
  after=Rescue.project(s,1);equal(after.probabilities.normal,1);equal(after.probabilities.extra,2)
  s.jokers={joker('j_credit_card','Credit Card',20)};s.bankrupt_at=-20
  equal(Rescue.project(s,1).bankrupt_at,0)
end

do
  local s=state('bl_plant','The Plant',100,{card(13)},{luchador(),plus(10)});s.hand[1].debuff=true
  local base=result(s)
  for _,field in ipairs({'ordering','hand_ordering','consumable'}) do
    local protected=Snapshot.copy(base);protected[field]={play={legal=true,score=100,uncertain=false}}
    equal(no_rescue(s,protected),0,'Do not sell when '..field..' already clears')
  end
  local protected=Snapshot.copy(base);protected.consumable={play={score=55},sequence={play={score=165,legal=true}}}
  equal(no_rescue(s,protected),0,'The complete consumable sequence clear is protected')
  protected=Snapshot.copy(base);protected.kind='discard';protected.discard={probability=1}
  equal(no_rescue(s,protected),0,'A high-confidence resource-preserving discard is protected')
  for _,index in ipairs({0,-1,1.5,math.huge}) do equal(Rescue.project(s,index),nil,'Invalid index is rejected') end
  s.blind.chips=nil;equal(Rescue.project(s,1),nil);equal(no_rescue(s),0)
  s.blind.chips=100;s.blind.key='bl_unknown';equal(Rescue.project(s,1),nil);no_rescue(s)
  s.blind.key='bl_plant';s.blind.name='The Wall';equal(Rescue.project(s,1),nil,'Mismatched modded boss identity is rejected')
end

do
  local hand={};for i=1,8 do hand[i]=card(2) end
  local s=state('bl_final_leaf','Verdant Leaf',10000,hand,{egg(),egg(),egg(),egg()})
  local use,work,diag=suggest(s,{}, {max_evaluations=435})
  equal(use,nil);equal(work,0);equal(diag.subsets,218);equal(diag.truncated,true)
  hand={};for i=1,13 do hand[i]=card(2);hand[i].debuff=true end
  s.hand=hand
  local calls,yields=0,0
  local wrapped={score=function(projected,indices) calls=calls+1;return Scoring.score(projected,indices) end}
  use,work,diag=Rescue.suggest(s,wrapped,{},function() yields=yields+1 end)
  equal(use,nil);equal(diag.subsets,2379);equal(work,9516,'Four complete subset sets fit within the shared cap')
  equal(calls,work);equal(diag.evaluated_sales,3);equal(diag.truncated,true);equal(diag.partial_comparisons,0)
  equal(yields,math.floor(work/32));check(work<=10000,'Hard evaluation cap includes baseline')
  local before=Snapshot.fingerprint(s)
  local _,repeat_work,repeat_diag=suggest(s,{})
  equal(repeat_work,work);equal(Snapshot.fingerprint(repeat_diag),Snapshot.fingerprint(diag))
  equal(Snapshot.fingerprint(s),before,'Large comparison remains detached')
  for i=14,21 do hand[i]=card(2) end
  use,work,diag=suggest(s,{})
  equal(use,nil);equal(work,0);check(diag.reason:find('held-card count',1,true) or diag.reason:find('held',1,true))
end

math.random,math.randomseed,pseudorandom,pseudoseed=old_random,old_seed,old_pseudo,old_pseudoseed
print('advisor_boss_rescue: '..checks..' checks passed')
