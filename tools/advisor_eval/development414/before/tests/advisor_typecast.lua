local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function j(key,a,cost)
    a=a or {};a.set='Joker';return {key=key,ability=a,cost=cost or 0,sell_cost=2}
end
local function state()
    return {phase='shop',challenge='c_typecast_1',ante=4,win_ante=8,dollars=30,joker_limit=3,
        bankrupt_at=0,jokers={j('j_joker',{mult=4}),j('j_blue_joker',{t_chips=80})},
        shop_jokers={},shop_booster={},shop_vouchers={},consumeables={},modifiers={},
        hands={Pair={played=10,level=2}},playing_cards={},hand_size=8}
end
do
    local s=state();s.shop_jokers={j('j_popcorn',{mult=20},4),j('j_joker',{mult=4},4)}
    local before=Snap.fingerprint(s);local r=S.advise(s)
    check(r.action.kind=='buy' and r.action.index==2,'prefer a durable visible scorer near lock over decaying Popcorn')
    check(Snap.fingerprint(s)==before,'Typecast advice does not mutate state')
    s.ante=1;r=S.advise(s)
    check(r.action.kind=='buy' and r.action.index==1,'early survival still permits short-lived strength before commitment horizon')
    s.ante=4;s.challenge=nil;s.modifiers={set_joker_slots_ante=4}
    check(S.advise(s).action.index==2,'rule-driven lock policy generalizes beyond challenge name')
end
do
    local s=state();s.jokers[3]=j('j_popcorn',{mult=4});s.shop_jokers={j('j_card_sharp',{extra={Xmult=3}},2)}
    local r=S.advise(s)
    check(r.action.kind=='sell' and r.action.index==3 and r.action.followup.index==1,'replace expiring filler using an actual available lasting scorer')
    local after=Snap.copy(s);table.remove(after.jokers,3);after.dollars=after.dollars+2
    check(S.advise(after).action.kind=='buy','replacement follow-up remains legal after the promised sale')
    s.shop_jokers={};s.shop_booster={{key='p_buffoon_normal_1',cost=1}}
    check(S.advise(s).action.kind~='sell','unrevealed pack is never promised as final-row replacement')
    s.shop_booster={};s.jokers[3]=j('j_green_joker',{mult=90});s.shop_jokers={j('j_card_sharp',{extra={Xmult=3}},2)}
    r=S.advise(s)
    check(r.action.kind~='sell' or r.action.index~=3,'mature Mult core remains valuable at commitment')
end
do
    local s=state();s.phase='blind';s.blind_on_deck='Boss';s.jokers[3]=j('j_egg',{rental=true})
    local r=S.advise(s)
    check(r.action.kind=='sell' and r.action.index==3,'remove useless rental resale engine before it becomes unsellable')
    s.jokers[3].ability.rental=nil
    check(S.advise(s).action.kind=='select_blind','ordinary filler is retained without a concrete replacement')
    s.jokers[3].ability.rental=true;s.consumeables={{key='c_temperance'}}
    check(S.advise(s).action.kind=='select_blind','preserve useful Temperance resale source')
    s.consumeables={};s.jokers[1]=j('j_swashbuckler',{})
    check(S.advise(s).action.kind=='select_blind','preserve Egg contribution to Swashbuckler')
    s=state();s.phase='blind';s.blind_on_deck='Boss';s.jokers[3]=j('j_credit_card',{rental=true,extra=20});s.dollars=-1
    check(S.advise(s).action.kind=='select_blind','keep required borrowing allowance when in debt')
    s.dollars=0;s.jokers[3].edition={holo=true}
    check(S.advise(s).action.kind=='select_blind','retain scoring edition on otherwise empty rental')
    s.jokers[3].edition=nil;s.jokers[3].ability.eternal=true
    check(S.advise(s).action.kind=='select_blind','never sell an already eternal Joker')
    s.jokers[3].ability.eternal=nil;s.ante=5;s.joker_limit=0
    check(S.advise(s).action.kind=='select_blind','do not invent a postlock preparation window')
end
print('advisor_typecast: '..checks..' checks passed')
