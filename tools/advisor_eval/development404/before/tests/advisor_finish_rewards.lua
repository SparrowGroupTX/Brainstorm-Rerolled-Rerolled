local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(v,label) checks=checks+1;assert(v,label) end
local function card(rank,seal,gold) return {rank=rank,suit='Spades',seal=seal,enhancement=gold and 'm_gold' or 'c_base',ability={}} end
local function joker(name,extra) return {name=name,ability={name=name,extra=extra,set='Joker'}} end
local function state()
  return {hand={card(14),card(13,nil,true),card(2,'Blue')},deck={},jokers={},
    consumeables={},consumable_limit=2,dollars=4,ante=1,blind={},hands_left=3,
    discards_left=2,modifiers={},hands={['High Card']={level=1,chips=5,mult=1,played=0},
    Pair={level=1,chips=10,mult=2,played=5}}}
end
local function value(s,selected,hand,dollars,strategy)
  return Rewards.value(s,{indices=selected or {1},hand=hand or 'High Card',expected_dollars=dollars or 0},Rewards.prepare(s,strategy))
end
local s=state();local n,d=value(s)
eq(d.held_dollars,3,'Gold enhancement earns held dollars')
eq(d.blue_planets,1,'Blue seal generates final hand Planet')
eq(d.hand_dollars,2,'current clearing play consumes exactly one hand')
eq(d.marginal_interest,1,'held income crosses interest threshold')
local _,playedgold=value(s,{2})
eq(playedgold.held_dollars,0,'played Gold gets no endround payout')
check(n>value(s,{2}),'free clear keeps Gold')
check(n>value(s,{3}),'free clear keeps Blue')
local _,scored=value(s,{1},'Pair',7)
eq(scored.play_dollars,7,'scorer income is consumed once')
eq(scored.dollars,14,'score, Gold, hands, incremental interest only')
s.hand[2].seal='Red';s.jokers={joker('Mime',1),joker('Blueprint'),joker('Mime',2)}
_,d=value(s)
eq(d.held_dollars,21,'Red plus physical and copied Mime repetitions add')
eq(d.blue_planets,2,'Blue retriggers stop at inventory capacity')
s.consumable_limit=5
_,d=value(s);eq(d.blue_planets,5,'Mime repetitions produce exact Blue count')
s.consumeable_buffer=2
_,d=value(s);eq(d.blue_planets,3,'pending consumable reservations consume capacity')
s.consumeables={{edition={negative=true}},{}};s.consumable_limit=3;s.consumeable_buffer=nil
_,d=value(s);eq(d.blue_planets,1,'Negative capacity already included in live limit')
s.consumeables[3]={}
_,d=value(s);eq(d.blue_planets,0,'full inventory cannot gain Blue reward')
s=state();s.jokers={joker('Mime',1),joker('Brainstorm')}
_,d=value(s);eq(d.held_dollars,9,'Brainstorm copies left Mime')
s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=1
_,d=value(s);eq(d.held_dollars,3,'expiring Mime disabled before held-card payout')
s.jokers[1].ability.perish_tally=2;s.jokers[2].ability.perishable=true;s.jokers[2].ability.perish_tally=1
_,d=value(s);eq(d.held_dollars,6,'expiring copying Joker does not retrigger')
s.jokers[1].debuff=true
_,d=value(s);eq(d.held_dollars,3,'debuffed Mime and copied target give no retrigger')
s.jokers={joker('Blueprint'),joker('Brainstorm')}
_,d=value(s);eq(d.held_dollars,3,'copying cycle terminates without phantom Mime')
s.hand[2].debuff=true;s.hand[3].debuff=true
_,d=value(s);eq(d.held_dollars,0,'debuffed Gold produces no payout');eq(d.blue_planets,0,'debuffed Blue produces no Planet')
s=state();s.hand[2].ability.h_dollars=11
_,d=value(s);eq(d.held_dollars,11,'live h_dollars overrides Gold default')
s.hand[2].ability.h_dollars=0
_,d=value(s);eq(d.held_dollars,0,'explicit zero held dollars stays zero')
s=state();s.modifiers={no_extra_hand_money=true,no_interest=true,money_per_discard=2}
_,d=value(s);eq(d.hand_dollars,0,'no extra hand money');eq(d.marginal_interest,0,'no interest');eq(d.discard_dollars,4,'custom discard reward')
s.modifiers={money_per_hand=3};s.hands_left=1
_,d=value(s);eq(d.hand_dollars,0,'last hand leaves no hand payout')
s.hands_left=3
_,d=value(s);eq(d.hand_dollars,6,'live money per hand')
s=state();s.dollars=4;s.hand[2].ability.h_dollars=0
_,d=value(s);eq(d.marginal_interest,0,'cashout hand reward cannot earn same-round interest')
s=state();s.dollars=6;s.jokers={joker('Joker')};s.jokers[1].ability.rental=true
_,d=value(s);eq(d.marginal_interest,1,'rental payment happens before interest and Gold')
s.rental_rate=5
_,d=value(s);eq(d.marginal_interest,0,'live rental rate honored')
s=state();s.dollars=25
_,d=value(s,{1},nil,20);eq(d.marginal_interest,0,'interest stops at cap')
s=state();s.blind={key='bl_hook'}
_,d=value(s);eq(d.held_dollars,0,'Hook held survivors unknown');eq(d.blue_planets,0,'Hook cannot promise held Blue')
s.blind.disabled=true
_,d=value(s);eq(d.held_dollars,3,'disabled Hook restores exact held reward')
s=state();s.jokers={joker('Vagabond')}
_,d=value(s);eq(d.blue_planets,0,'unprojected on-play generation reserves unknown inventory');eq(d.held_dollars,3,'generation uncertainty leaves Gold reward exact')
s.jokers[1].debuff=true
_,d=value(s);eq(d.blue_planets,1,'debuffed generator cannot interfere')
s=state();s.ante=8;s.blind.boss=true
n,d=value(s);eq(n,0,'final challenge blind has no future reward preference');check(d.final_blind,'final blind diagnostic')
s.win_ante=10
n,d=value(s);check(n>0,'live win ante allows intervening boss development')
s=state();s.hand[3].seal=nil
local prepared=Rewards.prepare(s,Strategy)
eq(next(prepared.planet_values),nil,'no Blue skips inventory utility preparation')
s.hand[3].seal='Blue';s.deck={card(7),card(7),card(7),card(7)}
local high=value(s,{1},'High Card',0,Strategy)
local pair=value(s,{1},'Pair',0,Strategy)
check(pair>high,'Blue seal seeks useful build hand Planet among equal clears')
s.consumeables={{key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}}
s.jokers={joker('Perkeo')};s.used_vouchers={v_observatory=true}
local a,ad=value(s,{1},'High Card',0,Strategy)
local b,bd=value(s,{1},'Pair',0,Strategy)
check(bd.planet_utility>ad.planet_utility,'whole inventory utility values Observatory and Perkeo dilution')
eq(#s.consumeables,1,'reward preparation does not add generated cards to input')
eq(#s.hand,3,'reward evaluation does not remove selected cards')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
s=state();s.phase='hand';s.blind={chips=10};s.chips=0;s.hand_size=3;s.hand_limit=5;s.deck={};s.playing_cards=s.hand
s.hand[1].enhancement='m_gold';s.hand[2].enhancement='c_base'
local before=Snapshot.fingerprint(s)
local answer=Search.run(s,Scoring,{finish_rewards=Rewards,strategy=Strategy})
check(answer.fast_clear and answer.play.indices[1]==2,'whole clearing search retains Gold and Blue instead of Ace overkill')
eq(answer.play.finish_rewards.held_dollars,3,'clear publishes concrete held reward')
check(answer.evaluations<=48,'reward-aware clear adds no scoring beyond existing conservation budget')
eq(Snapshot.fingerprint(s),before,'whole reward decision remains detached')
s=state();s.hands_played=0;s.playing_cards=s.hand;s.jokers={joker('DNA'),joker('Mime',1)}
for i,c in ipairs(s.hand) do c.id=i end
local scored=Scoring.score(s,{2});scored.indices={2}
local _,dna=Rewards.value(s,scored,Rewards.prepare(s,Strategy))
eq(#scored.created_cards,1,'shared scorer exposes physical DNA copy')
eq(dna.held_dollars,6,'copied selected Gold pays with surviving Mime')
scored=Scoring.score(s,{3});scored.indices={3}
_,dna=Rewards.value(s,scored,Rewards.prepare(s,Strategy))
eq(dna.blue_planets,2,'selected Blue copy produces bounded planets with Mime')
check(dna.planet_utility>0,'copied Blue has prepared inventory utility')
s.jokers={joker('DNA'),{ability={name='Vampire',x_mult=1,extra=0.1}}}
s.hand[2].ability.h_dollars=3
scored=Scoring.score(s,{2});scored.indices={2}
_,dna=Rewards.value(s,scored,Rewards.prepare(s,Strategy));eq(dna.held_dollars,3,'DNA before Vampire retains copied Gold')
s.jokers={s.jokers[2],s.jokers[1]}
scored=Scoring.score(s,{2});scored.indices={2}
_,dna=Rewards.value(s,scored,Rewards.prepare(s,Strategy));eq(dna.held_dollars,0,'Vampire before DNA strips copied Gold')
s.hand[2].enhancement='c_base';s.hand[2].ability.h_dollars=0
s.jokers={joker('Midas Mask'),joker('DNA')}
scored=Scoring.score(s,{2});scored.indices={2}
_,dna=Rewards.value(s,scored,Rewards.prepare(s,Strategy));eq(dna.held_dollars,3,'Midas before DNA replaces explicit zero with Gold payout')
print('Finish rewards: '..checks..' checks passed (source quantities; heuristic utility, no win-rate evidence)')
