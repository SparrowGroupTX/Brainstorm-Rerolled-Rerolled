local scoring=dofile('Brainstorm/Advisor/scoring.lua')
local copy=dofile('Brainstorm/Advisor/snapshot.lua').copy
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(rank,e,suit) return {rank=rank or 14,suit=suit or 'Spades',enhancement=e or 'c_base',ability={}} end
local function joker(n,a) a=a or {};a.name=n;return {name=n,ability=a,blueprint_compat=true} end
local function snap(cards,jokers,prob) return {hand=cards or {card()},jokers=jokers or {},hands={},hands_left=3,hands_played=1,dollars=4,probabilities={normal=prob or 1},current_round={}} end
Event=function(e) return e end
localize=function() return 'test' end
local function source_score(s,pattern)
  G={C={BLUE={},RED={},CHIPS={},MULT={}},GAME={probabilities=copy(s.probabilities),current_round={},dollars=s.dollars,dollar_buffer=0},
    hand={cards={}},play={cards={}},jokers={cards=copy(s.jokers)},consumeables={cards={}},E_MANAGER={add_event=function() end}}
  local calls=0
  pseudorandom=function(_,minimum,maximum)
    local high=math.floor(pattern/2^calls)%2==1;calls=calls+1
    assert(calls<=6,'outcome enumeration bound exceeded')
    if minimum then return high and maximum or minimum end
    return high and 0.999999 or 0
  end
  for i,c in ipairs(copy(s.hand)) do
    c.base={id=c.rank,suit=c.suit,nominal=c.rank==14 and 11 or math.min(c.rank,10)}
    c.ability.set=c.enhancement=='c_base' and 'Default' or 'Enhanced'
    c.ability.effect=c.enhancement=='m_lucky' and 'Lucky Card' or 'Default Base'
    c.ability.mult=c.ability.mult or (c.enhancement=='m_lucky' and 20 or 0)
    c.ability.p_dollars=c.ability.p_dollars or (c.enhancement=='m_lucky' and 20 or 0)
    c.ability.name=c.ability.effect
    setmetatable(c,{__index=Card})
    local area=i==1 and G.play or G.hand;area.cards[#area.cards+1]=c
  end
  for _,j in ipairs(G.jokers.cards) do
    j.ability.set='Joker';j.ability.x_mult=j.ability.x_mult or 1;j.ability.t_mult=0;j.ability.t_chips=0;j.ability.type=''
    setmetatable(j,{__index=Card})
  end
  local chips,mult=5,1
  local function apply(effect)
    if not effect then return end
    chips=chips+(effect.chips or effect.chip_mod or 0)
    mult=(mult+(effect.mult or effect.mult_mod or 0))*(effect.x_mult or effect.Xmult_mod or 1)
  end
  for _,j in ipairs(G.jokers.cards) do
    local e=j:calculate_joker({before=true,cardarea=G.jokers,full_hand=G.play.cards,scoring_hand=G.play.cards,scoring_name='High Card',poker_hands={}})
    if e and e.level_up then chips=chips+10;mult=mult+1 end
  end
  local c=G.play.cards[1]
  chips=chips+c.base.nominal;mult=mult+c:get_chip_mult();c:get_p_dollars()
  for _,j in ipairs(G.jokers.cards) do apply(j:calculate_joker({individual=true,cardarea=G.play,other_card=c,scoring_hand=G.play.cards,full_hand=G.play.cards})) end
  for _,held in ipairs(G.hand.cards) do
    for _,j in ipairs(G.jokers.cards) do apply(j:calculate_joker({individual=true,cardarea=G.hand,other_card=held,scoring_hand=G.play.cards,full_hand=G.play.cards})) end
  end
  for _,j in ipairs(G.jokers.cards) do apply(j:calculate_joker({joker_main=true,cardarea=G.jokers,scoring_name='High Card',scoring_hand=G.play.cards,full_hand=G.play.cards,poker_hands={}})) end
  return math.max(0,math.floor(chips*mult))
end
local function parity(s,label)
  cases=cases+1
  local r=scoring.lower_bound(s,{1});eq(r.reliable_bound,true,label..' supported')
  local minimum=math.huge
  for pattern=0,63 do
    local actual=source_score(s,pattern)
    checks=checks+1;assert(r.score<=actual,label..' bound exceeds source outcome '..pattern)
    minimum=math.min(minimum,actual)
  end
  eq(r.score,minimum,label..' reaches source minimum')
end
parity(snap(),'plain High Card')
parity(snap({card(14,'m_lucky')}),'Lucky optional')
parity(snap({card(14,'m_lucky')},nil,5),'Lucky mult guaranteed')
parity(snap({card(14,'m_lucky')},nil,15),'Lucky both guaranteed')
parity(snap(nil,{joker('Space Joker',{extra=4})}),'Space optional')
parity(snap(nil,{joker('Blueprint'),joker('Space Joker',{extra=4})},4),'Space copied guaranteed')
parity(snap({card(14,'m_lucky')},{joker('Blueprint'),joker('Lucky Cat',{x_mult=2,extra=0.25})}),'Lucky Cat copied optional')
parity(snap({card(14,'m_lucky')},{joker('Blueprint'),joker('Lucky Cat',{x_mult=2,extra=0.25})},5),'Lucky Cat copied guaranteed')
parity(snap(nil,{joker('Misprint',{extra={min=2,max=8}})}),'Misprint range')
parity(snap({card(14,nil,'Hearts')},{joker('Bloodstone',{extra={odds=2,Xmult=1.5}})}),'Bloodstone optional')
parity(snap({card(14,nil,'Hearts')},{joker('Bloodstone',{extra={odds=2,Xmult=1.5}})},2),'Bloodstone guaranteed')
parity(snap({card(13)},{joker('Business Card',{extra=2}),joker('Bull',{extra=2}),joker('Bootstraps',{extra={mult=2,dollars=5}})}),'Business dollar threshold')
parity(snap({card(14),card(13)},{joker('Reserved Parking',{extra={odds=2,dollars=1}}),joker('Bull',{extra=2}),joker('Bootstraps',{extra={mult=2,dollars=5}})},2),'Parking guaranteed threshold')
parity(snap({card(14,'m_lucky','Hearts')},{joker('Space Joker',{extra=4}),joker('Bloodstone',{extra={odds=2,Xmult=1.5}}),joker('Lucky Cat',{x_mult=2,extra=0.25}),joker('Misprint',{extra={min=2,max=8}})}),'combined random effects')
print('score-bound source parity: '..cases..' cases, '..checks..' checks passed (source method extrema; not full-run parity)')
