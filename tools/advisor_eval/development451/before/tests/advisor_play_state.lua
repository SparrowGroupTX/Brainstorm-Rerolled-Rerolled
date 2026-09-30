local Scoring = dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function eq(actual,expected,label)
    checks=checks+1
    assert(actual==expected,label..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function card(id,r,s,e,a)
    return {id=id,rank=r,nominal=r==14 and 11 or math.min(r,10),suit=s or 'Spades',enhancement=e or 'c_base',ability=a or {},base={times_played=2}}
end
local function joker(n,a)
    a=a or {}; a.name=n
    return {name=n,ability=a,blueprint_compat=true,sell_cost=2}
end
local function snap(cards,jokers)
    return {hand=cards,jokers=jokers or {},deck={card('deck1',8),card('deck2',9)},
        playing_cards=Snapshot.copy(cards),hands={},dollars=10,chips=20,
        hands_left=4,hands_played=1,hands_played_total=7,discards_left=2,discards_used=1,
        current_round={hands_left=4,hands_played=1,discards_left=2,discards_used=1},
        blind={},modifiers={},hand_size=8,probabilities={normal=1}}
end
local function after(s,sel)
    local original=Snapshot.fingerprint(s)
    local next_state,reason=Scoring.after_play(s,sel)
    eq(Snapshot.fingerprint(s),original,'input snapshot is unchanged')
    assert(next_state,reason)
    return next_state
end

-- The transition must stay detached and must never use callbacks or random state.
G={GAME={}}
pseudorandom=function() error('must not consume live RNG') end
math.random=function() error('must not consume global RNG') end
local base=snap({card('a',14),card('b',2),card('c',3),card('d',4),card('e',5)})
base.hand[1].ability.forced_selection=true
base.deck[1].ability.forced_selection=true
base.jokers={joker('Green Joker',{mult=4,extra={hand_add=1,discard_sub=1,nested={value=5}}})}
local next_state=after(base,{1,2,3,4})
eq(#next_state.hand,1,'played extras leave the hand')
eq(next_state.hand[1].id,'e','held cards retain their order')
eq(#next_state.deck,#base.deck,'transition does not draw cards')
eq(next_state.deck[1].id,base.deck[1].id,'remaining deck order stays intact')
eq(next_state.hands_left,3,'one hand consumed')
eq(next_state.hands_played,2,'round play counter advances')
eq(next_state.hands_played_total,8,'total play counter advances')
eq(next_state.current_round.hands_left,3,'nested hands remaining advances')
eq(next_state.current_round.hands_played,2,'nested played counter advances')
eq(next_state.discards_left,2,'play does not consume a discard')
eq(next_state.current_round.discards_left,2,'nested discards unchanged')
eq(next_state.discards_used,1,'discard count unchanged')
eq(next_state.chips,20+Scoring.score(base,{1,2,3,4}).score,'round score advances')
eq(next_state.hands['High Card'].played,1,'category play count advances')
eq(next_state.hands['High Card'].played_this_round,1,'category round count advances')
eq(next_state.hands['High Card'].visible,true,'played category is visible')
eq(next_state.playing_cards[1].ability.forced_selection,nil,'old Bell selection cleared from full deck')
eq(next_state.deck[1].ability.forced_selection,nil,'old Bell selection cleared from remaining deck')
eq(next_state.playing_cards[1].ability.played_this_ante,true,'played card marked for ante')
eq(next_state.playing_cards[1].base.times_played,3,'played-card counter advances')
next_state.deck[1].ability.changed=true
next_state.hand[1].base.times_played=99
next_state.jokers[1].ability.extra.nested.value=99
eq(base.deck[1].ability.changed,nil,'remaining deck abilities are detached')
eq(base.hand[5].base.times_played,2,'held base state is detached')
eq(base.jokers[1].ability.extra.nested.value,5,'deep Joker state is detached')

local growing=snap({card('a',14),card('b',2),card('c',3),card('d',4)}, {
    joker('Green Joker',{mult=4,extra={hand_add=1}}),
    joker('Ride the Bus',{mult=3,extra=1}),
    joker('Square Joker',{extra={chips=8,chip_mod=4}}),
    joker('Blueprint'),joker('Square Joker',{extra={chips=12,chip_mod=4}})})
next_state=after(growing,{1,2,3,4})
eq(next_state.jokers[1].ability.mult,5,'Green growth persists')
eq(next_state.jokers[2].ability.mult,4,'Bus growth persists')
eq(next_state.jokers[3].ability.extra.chips,12,'Square counts full played size')
eq(next_state.jokers[5].ability.extra.chips,16,'Blueprint does not double persistent growth')
growing.hand[1]=card('face',13)
next_state=after(growing,{1})
eq(next_state.jokers[2].ability.mult,0,'scored face resets Bus')
eq(next_state.jokers[3].ability.extra.chips,8,'single-card play does not grow Square')

local history=snap({card('a',14)}, {joker('Card Sharp',{extra={Xmult=3}}),joker('Supernova')})
next_state=after(history,{1})
next_state.hand={card('next',14)}
eq(Scoring.score(next_state,{1}).score,80,'next play sees Card Sharp and Supernova history')
local arm=snap({card('a',14)})
arm.blind={name='The Arm'}
arm.hands['High Card']={chips=25,mult=3,level=3,l_chips=10,l_mult=1,played=2,played_this_round=1}
next_state=after(arm,{1})
eq(next_state.hands['High Card'].level,2,'Arm lowered level persists')
eq(next_state.hands['High Card'].chips,15,'Arm base chips persist')
eq(next_state.hands['High Card'].mult,2,'Arm base mult persists')
next_state.hand={card('next',14)}
eq(Scoring.score(next_state,{1}).score,16,'next Arm hand loses another level')
arm.blind={name='The Flint'}
next_state=after(arm,{1})
eq(next_state.hands['High Card'].chips,25,'Flint does not persist temporary chip halving')
eq(next_state.hands['High Card'].mult,3,'Flint does not persist temporary mult halving')
arm.blind={}; arm.first_used_hand_level=2
arm.jokers={joker('Space Joker',{extra=4}),joker('Blueprint'),joker('Space Joker',{extra=4})}
next_state=after(arm,{1})
eq(next_state.hands['High Card'].level,5.75,'first-use and expected copied Space upgrades persist')
eq(next_state.hands['High Card'].chips,52.5,'expected Space base chips persist')
eq(next_state.first_used_hand_level,nil,'first-use upgrade consumed')

local constraints=snap({card('a',14),card('b',2)})
constraints.blind={name='The Mouth'}
next_state=after(constraints,{1})
eq(next_state.blind.only_hand,'High Card','Mouth locks played category')
constraints.blind={key='bl_eye',hands={}}
next_state=after(constraints,{1})
eq(next_state.blind.hands['High Card'],true,'Eye remembers played category')
eq(Scoring.score(next_state,{1}).legal,false,'Eye forbids category next hand')
constraints.blind={name='The Mouth',disabled=true}
next_state=after(constraints,{1})
eq(next_state.blind.only_hand,nil,'disabled Mouth does not lock')
constraints.blind={name='The Serpent'}
next_state=after(constraints,{1})
eq(#next_state.hand,1,'Serpent leaves draw behavior to the sampler')

local income=snap({card('a',14)},{joker('To Do List',{to_do_poker_hand='High Card',extra={dollars=4}})})
income.hand[1].seal='Gold'
next_state=after(income,{1})
eq(next_state.dollars,17,'queued hand income persists')
income.blind={name='The Ox'}; income.current_round.most_played_poker_hand='High Card'
next_state=after(income,{1})
eq(next_state.dollars,7,'Ox reset and later income persist in order')
income.blind={name='The Tooth'}
next_state=after(income,{1})
eq(next_state.dollars,16,'Tooth cost persists')
income.blind={};income.modifiers={minus_hand_size_per_X_dollar=5}
next_state=after(income,{1})
eq(next_state.hand_size,7,'Luxury Tax contracts hand at dollar threshold')
income.blind={name='The Ox'}
next_state=after(income,{1})
eq(next_state.hand_size,9,'Luxury Tax expands hand when Ox removes money')

local decay=snap({card('a',14)}, {joker('Ice Cream',{extra={chips=10,chip_mod=5}}),joker('Seltzer',{extra=2}),joker('Swashbuckler',{mult=4})})
next_state=after(decay,{1})
eq(next_state.jokers[1].ability.extra.chips,5,'Ice Cream decays after scoring')
eq(next_state.jokers[2].ability.extra,1,'Seltzer decays after scoring')
next_state.hand={card('next',14)}
next_state.jokers[2].edition={negative=true}; next_state.joker_limit=6
next_state=after(next_state,{1})
eq(#next_state.jokers,1,'exhausted consumable Jokers disappear')
eq(next_state.jokers[1].name,'Swashbuckler','remaining Joker order preserved')
eq(next_state.jokers[1].ability.mult,0,'Swashbuckler loses dissolved Joker sell values')
eq(next_state.joker_limit,5,'exhausted negative Joker removes extra slot')

local persistent=snap({card('a',2)}, {joker('Hiker',{extra=5}),joker('Hanging Chad',{extra=2}),joker('Wee Joker',{extra={chips=0,chip_mod=8}})})
persistent.modifiers.debuff_played_cards=true
next_state=after(persistent,{1})
eq(next_state.playing_cards[1].ability.perma_bonus,15,'Hiker card improvements persist')
eq(next_state.jokers[3].ability.extra.chips,24,'Wee growth from retriggers persists')
eq(next_state.playing_cards[1].ability.perma_debuff,true,'Double or Nothing marks scored card')
local vampire=snap({card('a',13,'Spades','m_steel')}, {
    joker('Vampire',{x_mult=1,extra=0.1}),joker('Steel Joker',{steel_tally=1,extra=0.2}),joker("Driver's License",{driver_tally=16,extra=3})})
next_state=after(vampire,{1})
eq(next_state.playing_cards[1].enhancement,'c_base','Vampire strips persistent enhancement')
eq(next_state.playing_cards[1].vampired,nil,'temporary Vampire marker cleared')
eq(next_state.jokers[1].ability.x_mult,1.1,'Vampire growth persists')
eq(next_state.jokers[2].ability.steel_tally,0,'Steel Joker tally tracks removed enhancement')
eq(next_state.jokers[3].ability.driver_tally,15,'License tally tracks removed enhancement')
vampire.hand[1].enhancement='m_glass'
next_state=after(vampire,{1})
eq(next_state.playing_cards[1].enhancement,'c_base','stripped Glass is safe to transition')

local function rejects(s,sel,pattern,label)
    local original=Snapshot.fingerprint(s)
    local state,reason=Scoring.after_play(s,sel)
    eq(state,nil,label)
    eq(not not (reason and reason:match(pattern)),true,label..' explains limit')
    eq(Snapshot.fingerprint(s),original,label..' leaves input unchanged')
end
local unsupported=snap({card('a',14)})
unsupported.blind={name='The Hook'}
unsupported.hand[2]=card('hook-held',2)
rejects(unsupported,{1},'Hook','Hook is not faked')
unsupported.hand[2]=nil
unsupported.blind={key='bl_final_heart'}
rejects(unsupported,{1},'Crimson','random Joker replacement is not faked')
unsupported.blind={};unsupported.hands_played=0;unsupported.jokers={joker('DNA')}
local dna_population=unsupported.playing_cards;unsupported.playing_cards={}
rejects(unsupported,{1},'DNA','DNA duplication requires full population')
unsupported.playing_cards=dna_population
unsupported.hand[1].rank=6;unsupported.jokers={joker('Sixth Sense')}
rejects(unsupported,{1},'Sixth Sense','Sixth Sense destruction is not faked')
unsupported.jokers={};unsupported.hand[1].enhancement='m_glass'
rejects(unsupported,{1},'Glass','Glass destruction is not faked')
unsupported.hand[1].enhancement='c_base';unsupported.jokers={joker('Unknown mod Joker')};unsupported.suppress_warnings=true
rejects(unsupported,{1},'Unmodeled','unknown effects still rejected with suppressed warnings')
unsupported.jokers={};unsupported.hand[1].enhancement='m_custom'
rejects(unsupported,{1},'Unmodeled','unknown enhancements are not faked')
unsupported.hand[1].enhancement='m_lucky';unsupported.modifiers.minus_hand_size_per_X_dollar=5
rejects(unsupported,{1},'Uncertain earnings','random Luxury Tax hand-size thresholds are not averaged')
rejects(base,{1,1},'duplicate','invalid selection has no transition')
print('advisor play state: '..checks..' checks passed')
