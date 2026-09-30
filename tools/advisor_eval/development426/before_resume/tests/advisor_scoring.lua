local scoring = dofile('Brainstorm/Advisor/scoring.lua')
local checks = 0
local function eq(actual, expected, label)
    checks=checks+1
    assert(actual==expected,(label or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function card(r,s,e,a)
    return {rank=r,suit=s or 'Spades',nominal=r==14 and 11 or math.min(r,10),enhancement=e or 'c_base',ability=a or {}}
end
local function joker(n,a,ed)
    a=a or {}; a.name=n
    return {name=n,ability=a,edition=ed,blueprint_compat=true}
end
local function snap(cards,jokers)
    return {hand=cards,jokers=jokers or {},deck={},hands={},dollars=100,hands_left=4,discards_left=3,blind={},modifiers={},probabilities={normal=1}}
end
local function all(s) local t={};for i=1,#s.hand do t[i]=i end;return t end
local function score(s,sel) return scoring.score(s,sel or all(s)) end

eq(score(snap({card(14)})).score,16,'bare Ace')
local pair=snap({card(10),card(10,'Hearts'),card(14)})
eq(score(pair).score,60,'pair excludes kicker')
eq(#score(pair).scoring_indices,2,'pair scoring count')
local fh=snap({card(7),card(7,'Hearts'),card(7),card(2),card(2)})
eq(score(fh).hand,'Full House','full house')
eq(score(fh).score,260,'full house chips')
local _,_,contains=scoring.classify(fh,all(fh))
eq(contains['Two Pair'],true,'full house includes two pair')
eq(contains.Pair,true,'full house includes pair')
eq(score(snap({card(2),card(3),card(4),card(5),card(14)})).hand,'Straight Flush','wheel straight')
eq(score(snap({card(14),card(2),card(3),card(12),card(13)})).hand,'Flush','no wrapping straight')
eq(score(snap({card(7),card(7),card(7),card(7),card(7)})).hand,'Flush Five','flush five')
local fourfingers=snap({card(2),card(3),card(4),card(5,'Hearts'),card(10)},{joker('Four Fingers')})
eq(score(fourfingers).hand,'Straight Flush','four fingers independent flush and straight')
eq(#score(fourfingers).scoring_indices,5,'straight flush union')
local shortcut=snap({card(2),card(4,'Hearts'),card(6),card(8),card(10)},{joker('Shortcut')})
eq(score(shortcut).hand,'Straight','shortcut gaps')
local stone=snap({card(10),card(10,'Hearts'),card(14,'Spades','m_stone')})
eq(score(stone).score,160,'stone always scores with pair')
eq(score(snap({card(14,'Spades','m_stone'),card(14,'Spades','m_stone')})).hand,'High Card','stones never pair')
local wild=snap({card(2),card(5),card(8),card(11),card(14,'Hearts','m_wild')})
eq(score(wild).hand,'Flush','wild joins flush')
wild.hand[5].debuff=true
eq(score(wild).hand,'High Card','debuff wild loses extra suits')
local debuffed=snap({card(10),card(10,'Hearts')}); debuffed.hand[1].debuff=true
eq(score(debuffed).score,40,'debuff card still forms pair')

local order=snap({card(10,'Spades','m_glass'),card(10,'Hearts','m_mult')})
eq(score(order,{1,2}).score,240,'glass then mult')
eq(score(order,{2,1}).score,360,'mult then glass')
local steel=snap({card(14),card(13,'Hearts','m_steel')},{joker('Mime')})
eq(score(steel,{1}).score,36,'Mime retriggers held steel')
steel.hand[2].seal='Red'
eq(score(steel,{1}).score,54,'red seal plus Mime')
local heldorder=snap({card(14),card(12),card(13,'Spades','m_steel')},{joker('Shoot the Moon')})
eq(score(heldorder,{1}).score,336,'held queen before steel')
local photo=snap({card(11)},{joker('Photograph'),joker('Hanging Chad',{extra=2})})
eq(score(photo).score,280,'Photograph and Chad retrigger all card effects')
local hiker=snap({card(2)},{joker('Hiker',{extra=5}),joker('Hanging Chad',{extra=2})})
eq(score(hiker).score,26,'Hiker growth affects later retriggers')
eq(hiker.hand[1].ability.perma_bonus,nil,'Hiker leaves snapshot untouched')
local weej=snap({card(2)},{joker('Wee Joker',{extra={chips=0,chip_mod=8}}),joker('Hanging Chad',{extra=2})})
eq(score(weej).score,35,'Wee grows per scored trigger')
eq(weej.jokers[1].ability.extra.chips,0,'Wee leaves snapshot untouched')

local bus=snap({card(14)},{joker('Ride the Bus',{mult=4,extra=1})})
eq(score(bus).score,96,'bus grows before scoring')
bus.hand={card(11)}
eq(score(bus).score,15,'bus resets on face')
eq(bus.jokers[1].ability.mult,4,'bus leaves snapshot untouched')
local trou=snap(fh.hand,{joker('Spare Trousers',{mult=2,extra=2})})
eq(score(trou).score,520,'trousers before hand')
local sharp=snap({card(14)},{joker('Card Sharp',{extra={Xmult=3}})})
sharp.hands['High Card']={chips=5,mult=1,played_this_round=1}
eq(score(sharp).score,48,'Card Sharp includes current play counter')
local obelisk=snap({card(14)},{joker('Obelisk',{x_mult=2,extra=0.2})})
obelisk.hands={['High Card']={chips=5,mult=1,played=1,visible=true},Pair={played=2,visible=true}}
eq(score(obelisk).mult,2.2,'obelisk safe when catching previous most played')
obelisk.hands.Pair.played=1
eq(score(obelisk).mult,1,'obelisk resets playing most used')
local vamp=snap({card(10,'Spades','m_glass')},{joker('Vampire',{x_mult=1,extra=0.1})})
eq(score(vamp).score,16,'Vampire removes glass before scoring')
eq(vamp.hand[1].enhancement,'m_glass','Vampire leaves enhancement untouched')
local midas=snap({card(13,'Spades','m_glass')},{joker('Midas Mask'),joker('Vampire',{x_mult=1,extra=0.1})})
eq(score(midas).mult,1.1,'Midas then Vampire ordering')

local blueprint=snap({card(14)},{joker('Blueprint'),joker('Joker',{mult=4})})
eq(score(blueprint).score,144,'Blueprint copies Joker')
blueprint.jokers[2].debuff=true
eq(score(blueprint).score,16,'Blueprint cannot copy debuffed Joker')
local cycle=snap({card(14)},{joker('Blueprint'),joker('Brainstorm')})
eq(score(cycle).score,16,'copy cycles terminate')
local editionorder=snap({card(14)},{joker('Joker',{mult=4},{holo=true}),joker('Cavendish',{extra={Xmult=3}},{polychrome=true})})
eq(score(editionorder).score,1080,'Joker editions resolve around main effect')

local boss=snap({card(14)});boss.blind.name='The Psychic'
eq(score(boss).legal,false,'Psychic blocks short hands')
boss.blind={name='The Eye',hands={['High Card']=true}}
eq(score(boss).legal,false,'Eye repeated category')
boss.blind={name='The Mouth',only_hand='Pair'}
eq(score(boss).legal,false,'Mouth required category')
boss.blind.disabled=true
eq(score(boss).legal,true,'disabled boss')
boss.blind={name='The Flint'}
eq(score(boss).score,14,'Flint rounds base chips and mult')
boss.blind={name='The Arm'};boss.hands['High Card']={chips=15,mult=2,level=2,l_chips=10,l_mult=1}
eq(score(boss).score,16,'Arm loses one level')
local bell=snap({card(14),card(2)});bell.hand[2].ability.forced_selection=true
eq(score(bell,{1}).legal,false,'Bell requires forced card')
local cap=snap({card(14)},{joker('Joker',{mult=4})});cap.dollars=8;cap.modifiers.chips_dollar_cap=true
eq(score(cap).score,40,'Luxury Tax chips cap')
cap.blind={name='The Ox'};cap.current_round={most_played_poker_hand='High Card'}
eq(score(cap).score,0,'Ox resets dollars before chip cap')
eq(score(snap({card(14)},{joker('Misprint',{extra={min=0,max=23}})})).uncertain,true,'random effect marked uncertain')
eq(#score(snap({card(14)},{joker('Unmodeled modded Joker')})).warnings,1,'unknown Joker warned')
eq(score(snap({card(14)}),{1,1}).legal,false,'duplicate selection rejected')
local omelette=snap({card(14)},{joker('Egg',{}, {foil=true})})
eq(score(omelette).score,66,'Omelette foil Egg still gives chips')
local baseball=snap({card(14)},{joker('Baseball Card',{extra=1.5}),joker('Banner',{extra=30})})
baseball.jokers[2].rarity=2;baseball.jokers[2].debuff=true
eq(score(baseball).score,24,'Baseball triggers on debuffed uncommon')
local observatory=snap({card(14)});observatory.used_vouchers={v_observatory=true}
observatory.consumeables={{ability={set='Planet',consumeable={hand_type='High Card'}}},{ability={set='Planet',consumeable={hand_type='Pair'}}}}
eq(score(observatory).score,24,'Observatory boosts only matching held planets')
local goldcap=snap({card(14)});goldcap.dollars=8;goldcap.modifiers.chips_dollar_cap=true;goldcap.hand[1].seal='Gold';goldcap.hand[1].edition={foil=true}
eq(score(goldcap).score,8,'queued Gold earnings do not raise cap during evaluation')
eq(score(goldcap).expected_dollars,3,'Gold seal earnings counted')
local smeared=snap({card(2),card(5,'Clubs'),card(8),card(11,'Clubs'),card(14)},{joker('Smeared Joker')})
eq(score(smeared).hand,'Flush','Smeared suits combine for flush')
local last=snap({card(14)},{joker('Dusk',{extra=1}),joker('Acrobat',{extra=3})});last.hands_left=1
eq(score(last).score,81,'Dusk and Acrobat check hands remaining after play')
local duplicate_straight=snap({card(2),card(3),card(3,'Hearts'),card(4),card(5,'Hearts')},{joker('Four Fingers')})
eq(score(duplicate_straight).hand,'Straight','Four Fingers includes duplicate rank straight')
eq(#score(duplicate_straight).scoring_indices,5,'duplicate rank straight all contribute')
local stripped_lucky=snap({card(13,'Spades','m_lucky',{p_dollars=20,mult=20})},{joker('Vampire',{x_mult=1,extra=0.1}),joker('Bull',{extra=2})})
eq(score(stripped_lucky).expected_dollars,0,'Vampire removes Lucky dollars')
eq(score(stripped_lucky).score,236,'Bull ignores removed Lucky dollars')
stripped_lucky.jokers[1]=joker('Midas Mask')
eq(score(stripped_lucky).expected_dollars,0,'Midas removes Lucky dollars')
print('advisor scoring: '..checks..' checks passed')
