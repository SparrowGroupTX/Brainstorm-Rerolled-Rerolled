local Draw=dofile('Brainstorm/Advisor/draws.lua')
local checks=0;local function eq(a,b) checks=checks+1;assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local roll=.2;function pseudoseed(x)return x end;function pseudorandom()return roll end
local pareidolia=false;function find_joker()return pareidolia and {true} or {} end
local names={bl_small='Small Blind',bl_wheel='The Wheel',bl_house='The House',bl_mark='The Mark',bl_fish='The Fish'}
for key,name in pairs(names) do for _,front in ipairs({false,true}) do for _,rank in ipairs({2,13}) do
  for _,first in ipairs({false,true}) do for _,disabled in ipairs({false,true}) do
    local source={rank=rank,face_down=not front,enhancement='c_base',ability={}}
    local s={blind={key=key,name=name,prepped=true,disabled=disabled},hands_played=first and 0 or 1,discards_used=0,probabilities={normal=2}}
    G={GAME={current_round={hands_played=s.hands_played,discards_used=0},probabilities=s.probabilities},hand={config={type='hand',card_limit=8},cards={}},deck={}}
    local area=G.hand;area.set_ranks=function()end;area.align_cards=function()end
    local c={facing=front and 'front' or 'back',ability={},get_id=function()return rank end,is_face=Card.is_face,
      flip=function(self)self.facing='front'end,set_card_area=function()end}
    local hidden=Blind.stay_flipped(s.blind,G.hand,c)
    CardArea.emplace(area,c,nil,hidden)
    local result=assert(Draw.card(s,source,roll))
    eq(result.face_down,c.facing=='back');eq(not not result.ability.wheel_flipped,not not c.ability.wheel_flipped)
  end end end end end
pareidolia=true
local c=assert(Draw.card({blind={key='bl_mark'},jokers={{key='j_pareidolia'}}},{rank=2,face_down=true,enhancement='m_stone'}))
eq(c.face_down,true)
print('draw source parity: 80 scenarios / '..checks..' comparisons passed')
