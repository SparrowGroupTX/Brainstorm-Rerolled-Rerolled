local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function j(key,a) a=a or {};a.set='Joker';if key=='j_chicot' then a.name='Chicot' end;return {key=key,ability=a,cost=2,sell_cost=1} end
local function state(key)
    local s={phase='shop',ante=4,dollars=30,joker_limit=5,hand_size=8,hand_limit=5,jokers={},
        playing_cards={},hands={Pair={level=1,played=10}},round_resets={hands=4,discards=3},current_round={},
        next_blind={key=key,boss=true,chips=1000},probabilities={normal=1},modifiers={}}
    for i=1,8 do s.playing_cards[i]={id='p'..i,rank=10+i%4,suit=({'Hearts','Clubs','Spades','Diamonds'})[i%4+1],ability={}} end
    return s
end
local function compare(s,incoming,inspect)
    local after=Snap.copy(s);after.jokers[#after.jokers+1]=incoming
    local seen=false
    local scorer={score=function(t,selected)
        if inspect and not seen then seen=true;inspect(t) end
        return Scorer.score(t,selected)
    end}
    return Shop.new(s,scorer):compare(s,after)
end
do
    local s=state('bl_plant');local original=Snap.fingerprint(s)
    local e=compare(s,j('j_photograph',{extra=2}),function(t)
        for _,c in ipairs(t.hand) do check(c.debuff==(c.rank>=11 and c.rank<=13),'Plant marks face cards before scoring') end
    end)
    check(e and e.ratio==1 and e.blind=='bl_plant','Plant purchase evidence removes Photograph activation')
    check(e.after_target==1000 and e.reason:find('upcoming The Plant',1,true),'evidence identifies actual boss and target')
    check(Snap.fingerprint(s)==original,'boss comparison preserves original snapshot')
    local neutral=Snap.copy(s);neutral.next_blind=nil
    check(compare(neutral,j('j_photograph',{extra=2})).ratio>1,'same purchase receives functional value under neutral conditions')
    s.jokers={j('j_joker',{mult=4})};s.shop_jokers={j('j_photograph',{extra=2}),j('j_joker',{mult=4})}
    local r=Strategy.advise(s,{shop_scoring=Shop.new(s,Scorer)})
    check(r.action.kind=='buy' and r.action.index==2,'actual Plant evidence produces executable useful purchase')
end
do
    local s=state('bl_head');s.jokers={j('j_smeared')}
    s.playing_cards[1].enhancement='m_wild';s.playing_cards[2].enhancement='m_stone'
    s.playing_cards[3].ability.perma_debuff=true
    check(compare(s,j('j_joker',{mult=4}),function(t)
        for _,c in ipairs(t.hand) do
            local expected=c.id=='p1' or c.id=='p3' or c.id~='p2' and (c.suit=='Hearts' or c.suit=='Diamonds')
            check(c.debuff==expected,'suit boss includes Wild/Smeared, excludes Stone, and preserves permanent loss')
        end
    end)~=nil,'suit projection scores')
    s=state('bl_plant');s.jokers={j('j_pareidolia')};s.playing_cards[1].enhancement='m_stone'
    compare(s,j('j_joker',{mult=4}),function(t)
        for _,c in ipairs(t.hand) do check(c.debuff,'Pareidolia makes even Stone face for Plant') end
    end)
end
do
    for _,key in ipairs({'bl_psychic','bl_manacle','bl_water','bl_needle'}) do
        local s=state(key)
        local e=compare(s,j('j_joker',{mult=4}),function(t)
            check(#t.hand==(key=='bl_manacle' and 7 or 8),'Manacle changes sample hand size exactly once')
            check(t.discards_left==(key=='bl_water' and 0 or 3),'Water removes fresh discards')
            check(t.hands_left==(key=='bl_needle' and 1 or 4),'Needle has exactly one fresh hand')
            if key=='bl_psychic' then check(t.blind.debuff.h_size_ge==5,'Psychic requires five-card candidate') end
        end)
        check(e and e.blind==key,'supported restriction supplies actual-blind evidence')
    end
end
do
    local s=state('bl_eye');s.blind={key='bl_eye',hands={Pair=true},only_hand='Flush'}
    local e=compare(s,j('j_card_sharp',{extra={Xmult=3}}),function(t)
        check(not t.blind.hands.Pair and not t.blind.only_hand,'Eye opening clears completed-blind history')
    end)
    check(e and e.ratio==1,'Card Sharp gains no impossible repeated hand under Eye')
    s=state('bl_mouth');s.hands.Pair.played_this_round=4
    check(compare(s,j('j_card_sharp',{extra={Xmult=3}})).ratio>1,'Mouth permits its locked repeated hand in conditional capacity')
    s=state('bl_needle')
    check(compare(s,j('j_card_sharp',{extra={Xmult=3}})).ratio==1,'Needle grants no speculative second hand Card Sharp effect')
end
do
    local s=state('bl_wall');s.next_blind.chips=2000
    local e=compare(s,j('j_chicot'))
    check(e and e.ratio==1 and e.capacity_ratio==2 and e.after_target==1000,'Chicot lowers Wall target without inventing raw score')
    s=state('bl_plant');s.jokers={j('j_photograph',{extra=2})}
    check(compare(s,j('j_chicot')).ratio>1,'Chicot restores face-card scoring after Plant projection')
    s=state('bl_pillar');s.playing_cards[1].ability.played_this_ante=true
    compare(s,j('j_joker',{mult=4}),function(t)
        for _,c in ipairs(t.hand) do check(c.debuff==(c.id=='p1'),'Pillar uses current ante play history') end
    end)
    s=state('bl_final_heart');e=compare(s,j('j_joker',{mult=4}))
    check(e and not e.blind and e.boss_fallback and e.reason:find('neutral blind',1,true),'random boss uses explicit neutral fallback')
    s=state('bl_modded');e=compare(s,j('j_joker',{mult=4}))
    check(e and e.boss_fallback,'unknown boss never inherits vanilla guarantees')
    s=state('bl_plant');local after=Snap.copy(s);after.jokers={j('j_joker',{mult=4})}
    local ctx=Shop.new(s,Scorer,nil,{max_evaluations=1})
    check(not ctx:compare(s,after) and ctx.truncated,'boss scoring obeys whole-pair budget cutoff')
end
print('advisor_shop_boss: '..checks..' checks passed')
