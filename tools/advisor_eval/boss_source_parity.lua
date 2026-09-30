-- Appended to unmodified installed source by boss_source_parity.py.
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local definitions={
    {key='bl_club',name='The Club',debuff={suit='Clubs'}},
    {key='bl_goad',name='The Goad',debuff={suit='Spades'}},
    {key='bl_window',name='The Window',debuff={suit='Diamonds'}},
    {key='bl_head',name='The Head',debuff={suit='Hearts'}},
    {key='bl_plant',name='The Plant',debuff={is_face='face'}},
    {key='bl_pillar',name='The Pillar',debuff={}},
    {key='bl_final_leaf',name='Verdant Leaf',debuff={}},
    {key='bl_psychic',name='The Psychic',debuff={h_size_ge=5}},
    {key='bl_wall',name='The Wall',debuff={}},
}
for _,definition in ipairs(definitions) do for combination=0,3 do
    local snapshot={phase='shop',hand_size=8,hand_limit=5,joker_limit=5,dollars=20,hands={},current_round={},
        playing_cards={},jokers={},round_resets={hands=4,discards=3},next_blind=Snapshot.copy(definition)}
    if combination%2==1 then snapshot.jokers[#snapshot.jokers+1]={key='j_smeared',ability={name='Smeared Joker',set='Joker'}} end
    if combination>=2 then snapshot.jokers[#snapshot.jokers+1]={key='j_pareidolia',ability={name='Pareidolia',set='Joker'}} end
    for i=1,8 do
        local rank=9+i%5
        local enhancement=i==1 and 'm_stone' or i==2 and 'm_wild' or nil
        snapshot.playing_cards[i]={id='p'..i,rank=rank,suit=({'Hearts','Diamonds','Spades','Clubs'})[i%4+1],
            enhancement=enhancement,ability={played_this_ante=i==3},debuff=i==4}
    end
    G={jokers={cards=Snapshot.copy(snapshot.jokers)},consumeables={cards={}}}
    local original=Snapshot.copy(snapshot.playing_cards)
    local source_blind=Snapshot.copy(definition);setmetatable(source_blind,{__index=Blind})
    for _,c in ipairs(original) do
        local effect=c.enhancement=='m_stone' and 'Stone Card' or c.enhancement=='m_wild' and 'Wild Card' or 'Default Base'
        c.base={id=c.rank,suit=c.suit};c.ability.name=effect;c.ability.effect=effect
        c.area={};c.config={center={}};setmetatable(c,{__index=Card})
        source_blind:debuff_card(c)
    end
    local expected={};for _,c in ipairs(original) do expected[c.id]=not not c.debuff end
    local inspected=false
    local scorer={score=function(s)
        if not inspected then
            inspected=true
            for _,c in ipairs(s.playing_cards) do eq(not not c.debuff,expected[c.id],definition.key..' combination '..combination..' '..c.id) end
        end
        return {score=100,legal=true}
    end}
    local result=Shop.new(snapshot,scorer):compare(snapshot,Snapshot.copy(snapshot))
    eq(not not result,true,'source projection comparison completed')
    cases=cases+1
end end
print('boss source parity: '..cases..' cases / '..checks..' comparisons passed')
