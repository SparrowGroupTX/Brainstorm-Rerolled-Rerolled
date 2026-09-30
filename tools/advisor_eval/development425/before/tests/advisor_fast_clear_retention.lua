-- Synthetic public states isolate the two observed candidate-coverage gaps.
-- No source attempt, hidden draw, save or external game process is executed.
local Search=dofile('Brainstorm/Advisor/search.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Growth=dofile('Brainstorm/Advisor/growth.lua')
Strategy.consumables=Consumables
local modules={search=Search,scoring=Scoring,strategy=Strategy,finish_rewards=Rewards,consumables=Consumables,growth=Growth}
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local function card(i,rank,suit)
 return {id='retention-'..i,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit or 'Spades',enhancement='c_base',ability={}}
end
local function contains(indices,selected)for _,i in ipairs(indices)do if i==selected then return true end end;return false end
local function base()
 return {phase='hand',ante=3,win_ante=8,hand={},deck={},playing_cards={},jokers={},consumeables={},consumable_limit=2,
  hands={},hand_limit=5,hand_size=9,hands_left=3,hands_played=1,discards_left=2,dollars=10,chips=0,
  blind={key='bl_big',chips=705},current_round={},modifiers={},used_vouchers={},probabilities={normal=1}}
end
local function straight()
 local s=base();s.hand={card(1,13),card(2,8),card(3,2,'Hearts'),card(4,7,'Clubs'),card(5,6),
  card(6,5,'Hearts'),card(7,5,'Diamonds'),card(8,4,'Clubs'),card(9,10,'Diamonds')}
 s.hand[6].seal='Blue';s.hand[6].enhancement='m_steel';s.hand[6].edition={holo=true,type='holo',mult=10}
 s.hands.Straight={level=4,chips=120,mult=13,l_chips=30,l_mult=3,played=8}
 s.playing_cards=s.hand;return s
end
local function flush()
 local s=base();s.blind.chips=255
 s.hand={card(1,13,'Hearts'),card(2,11,'Diamonds'),card(3,10,'Diamonds'),card(4,7,'Spades'),card(5,5,'Clubs'),
  card(6,8,'Diamonds'),card(7,6,'Diamonds'),card(8,4,'Diamonds'),card(9,2,'Diamonds')}
 s.hand[2].seal='Blue';s.hand[2].enhancement='m_steel'
 s.hands.Flush={level=1,chips=35,mult=4,l_chips=15,l_mult=2,played=8}
 s.playing_cards=s.hand;return s
end
local function run(s,label)
 local before=Snapshot.fingerprint(s);local result=Decision.run(s,modules)
 check(result.fast_clear and result.action.kind=='play' and Search.reliable_clear(result.play,s.blind.chips-s.chips),label..' retains a concrete legal clearing action')
 check(result.evaluations<=70 and result.fast_clear.conservation_evaluations<=16,label..' stays within the existing whole-decision and conservation caps')
 check(not result.play_complete and result.fast_clear.specialists_skipped,label..' does not claim exhaustive search or defer to costly specialists')
 check(Snapshot.fingerprint(s)==before,label..' preserves the public state and inventory')
 return result
end
do
 local s=straight();local original={2,4,5,6,8};local replacement={2,4,5,7,8}
 check(Search.reliable_clear(Scoring.score(s,original),705) and Search.reliable_clear(Scoring.score(s,replacement),705),
  'both original and plain duplicate Straight clear under the real scorer')
 local result=run(s,'duplicate Straight')
 check(result.play.hand=='Straight' and not contains(result.play.indices,6) and contains(result.play.indices,7),
  'complete decision replaces the scored Blue Steel Five with its ordinary duplicate')
 check(result.play.finish_rewards.blue_planets==1 and result.play.finish_rewards.planet_hand=='Straight',
  'retained Blue seal receives the exact final-hand Planet reward')
 check(Snapshot.fingerprint(result)==Snapshot.fingerprint(Decision.run(s,modules)),'retention decision is deterministic')
end
do
 local s=flush();check(Search.reliable_clear(Scoring.score(s,{2,3,6,7,8}),255) and Search.reliable_clear(Scoring.score(s,{3,6,7,8,9}),255),
  'both five-Diamond selections clear with exact held Steel scoring')
 local result=run(s,'six-card Flush')
 check(result.play.hand=='Flush' and not contains(result.play.indices,2) and contains(result.play.indices,9),
  'complete decision uses the sixth suit card to retain Blue Steel')
 check(result.play.finish_rewards.blue_planets==1,'same-suit replacement earns a real Blue generation slot')
end
for _,n in ipairs({4,5})do
 local s=base();s.hand_size=n+2;s.blind.chips=n==4 and 1000 or 1500
 for i=1,n+1 do s.hand[i]=card(i,9,({'Spades','Hearts','Clubs','Diamonds'})[(i-1)%4+1]) end
 s.hand[n+2]=card(n+2,2,'Hearts');s.hand[1].seal='Blue';s.hand[1].enhancement='m_steel'
 local family=n==4 and 'Four of a Kind' or 'Five of a Kind'
 s.hands[family]={level=4,chips=200,mult=15,l_chips=30,l_mult=3,played=8};s.playing_cards=s.hand
 if n==4 then s.hands['Five of a Kind']={level=1,chips=120,mult=1,l_chips=35,l_mult=3,played=0} end
 local result=run(s,family..' duplicate')
 check(result.play.hand==family and not contains(result.play.indices,1) and result.play.finish_rewards.blue_planets==1,
  family..' exact duplicate preserves a Blue seal without sacrificing the clear')
end
do
 local s=straight();s.hand[6].ability.forced_selection=true
 local result=run(s,'forced Blue card')
 check(contains(result.play.indices,6) and result.play.finish_rewards.blue_planets==0,'forced selection never becomes an illegal retained Blue reward')
end
do
 local s=straight();s.hand[6].debuff=true
 local result=run(s,'debuffed Blue card')
 check(result.play.finish_rewards.blue_planets==0,'a debuffed retained Blue seal never produces a Planet')
end
for _,kind in ipairs({'full inventory','final boss'})do
 local s=straight()
 if kind=='full inventory' then
  s.consumeables={{key='c_fool',ability={name='The Fool',set='Tarot'}},{key='c_wheel_of_fortune',ability={name='The Wheel of Fortune',set='Tarot'}}}
 else s.ante=8;s.blind.boss=true end
 local result=run(s,kind)
 check(contains(result.play.indices,6),kind..' does not replace higher-scoring play for a nonexistent future Planet')
 check(result.play.finish_rewards.blue_planets==0 and result.play.finish_rewards.planet_utility==0,kind..' reports no Planet benefit')
end
do
 local s=straight();s.jokers={{key='j_perkeo',ability={name='Perkeo',set='Joker'}}};s.used_vouchers.v_observatory=true
 s.consumeables={{key='c_mercury',edition={negative=true},ability={name='Mercury',set='Planet',consumeable={hand_type='Pair'}}}}
 s.consumable_limit=3;s.hands.Pair={level=1,chips=10,mult=2,l_chips=15,l_mult=1,played=80}
 local result=run(s,'Perkeo Observatory inventory')
 local value,details=Rewards.value(s,result.play,Rewards.prepare(s,Strategy))
 check(result.play.finish_reward==value and result.play.finish_rewards.planet_utility==details.planet_utility,
  'whole-inventory Perkeo dilution and Observatory valuation remain the actual comparator')
 check(#s.consumeables==1 and s.consumeables[1].edition.negative,'Negative inventory and its expanded capacity remain intact')
end
do
 local s=straight();s.hand[7].enhancement='m_glass';s.hand[7].ability.extra=4
 local result=run(s,'Glass replacement')
 check(not contains(result.play.indices,7) and (result.play.glass_loss or 0)==0,
  'Blue reward cannot displace a safe clear with avoidable Glass population loss')
end
for _,target in ipairs({18,100})do
 local s=base();s.hand_size=8;s.blind={key='bl_psychic',name='The Psychic',chips=target,debuff={h_size_ge=5}}
 local suits={'Spades','Hearts','Diamonds','Clubs'}
 for i,rank in ipairs({12,11,11,10,6,6,5,3})do s.hand[i]=card(i,rank,suits[(i-1)%4+1]) end
 s.hand[3].seal='Blue';s.playing_cards=s.hand
 local first=Scoring.score(s,{1,2,3,5,6});local alternate=Scoring.score(s,{1,2,4,5,6})
 check(Search.reliable_clear(first,target) and first.hand=='Two Pair','Psychic original two-pair clear is exact')
 check(alternate.hand=='Pair' and alternate.score==44 and not Scoring.score(s,{5,6}).legal,
  'Psychic alternate uses five legal cards even though only its pair scores')
 local result=run(s,'Psychic cross-category substitution at '..target)
 check(#result.action.indices==5,'Psychic action preserves the five-card requirement')
 if target==18 then
  check(not contains(result.action.indices,3) and result.play.finish_rewards.blue_planets==1,
   'arbitrary same-cap replacement retains Blue when the lower-scoring poker category still clears')
 else
  check(contains(result.action.indices,3) and result.play.finish_rewards.blue_planets==0,
   'a protected-card replacement cannot sacrifice the only sufficient clearing hand')
 end
end
print('advisor_fast_clear_retention: '..checks..' checks passed (synthetic exact-score coverage, no run outcome claim)')
