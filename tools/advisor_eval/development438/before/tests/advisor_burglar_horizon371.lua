-- Manufactured pack choices for the future-discard opportunity cost.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local function j(key,name,a)
  a=a or {};a.set='Joker';a.name=name
  return {id='manufactured:'..key,key=key,ability=a,cost=0,sell_cost=2}
end
local burglar=j('j_burglar','Burglar',{extra=3})
local mail=j('j_mail','Mail-in Rebate',{extra=5})
local function state()
  return {phase='pack',ante=1,win_ante=8,dollars=5,bankrupt_at=0,joker_limit=5,
    jokers={},consumeables={},hand={},playing_cards={},pack_cards={burglar,mail},
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},
    hands={Pair={level=1,played=4}},interest_cap=25}
end
local plain=state();local base=Strategy.shop_sequence_api.card_value(plain,burglar)
check(base==72,'Burglar has its established immediate extra-hands rating without growth targets')
local growth=state();growth.jokers={j('j_yorick','Yorick',{x_mult=1,extra={discards=23,xmult=1},yorick_discards=23})}
local fingerprint=Snapshot.fingerprint(growth)
local with_yorick,reason=Strategy.shop_sequence_api.card_value(growth,burglar)
check(with_yorick<base and reason:find('future Yorick/Burnt',1,true),
  'a visible early Yorick makes lost future discard investment material')
check(Strategy.advise(growth).action.index==2,'the low-pressure early pack retains Yorick discards over Burglar')
local urgent=Strategy.advise(growth,{shop_scoring={compare=function(_,before,after)
  local incoming=after.jokers[#after.jokers]
  return {adjustment=incoming.key=='j_burglar' and 35 or 0,ratio=incoming.key=='j_burglar' and 3 or 1,
    reason='Complete paired immediate-survival fixture.'}
end}})
check(urgent.action.index==1,'a supported strong immediate survival gain can still justify Burglar')
check(Snapshot.fingerprint(growth)==fingerprint,'horizon rating does not mutate physical Yorick counters')
local late=state();late.ante=9;late.jokers=growth.jokers
check(Strategy.shop_sequence_api.card_value(late,burglar)==base,
  'the win ante has passed, so no future growth is invented')
local final=state();final.ante=8;final.next_blind={label='Small'}
final.jokers={j('j_yorick','Yorick',{x_mult=2,extra={discards=23,xmult=1},yorick_discards=1})}
check(Strategy.shop_sequence_api.card_value(final,burglar)<base,
  'an imminent Yorick threshold still matters before the final ante is over')
local zero=state();zero.jokers=growth.jokers;zero.round_resets.discards=0
check(Strategy.shop_sequence_api.card_value(zero,burglar)==base,
  'already-absent discards are not charged twice')
local burnt=state();burnt.jokers={j('j_burnt','Burnt Joker',{})}
check(Strategy.shop_sequence_api.card_value(burnt,burglar)<base,
  'first-discard Burnt loses development when Burglar removes discards')
local existing=state();existing.jokers={j('j_burglar','Burglar',{extra=3}),growth.jokers[1]}
check(Strategy.shop_sequence_api.card_value(existing,burglar)==base,
  'a second Burglar is not charged for already-lost future discards')
print('advisor_burglar_horizon371: '..checks..' checks passed')
