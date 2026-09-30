local F=dofile('tests/fixtures/retained418.lua');local P='Brainstorm/Advisor/';local S=dofile(P..'strategy.lua');S.joker_plan=dofile(P..'joker_plan.lua');S.conditional_value=dofile(P..'conditional_value.lua')
local s=F.state();s.phase='pack';s.hands={Pair={played=10,level=4}};s.round_resets={hands=4,discards=3};s.next_blind={key='bl_big',ante=3};s.jokers={F.j('j_yorick'),F.j('j_perkeo')}
for _,c in ipairs(dofile('tests/fixtures/joker_centers421.lua')) do local v,r,k=S.owned_joker_value(s,c);if not k then print(c.key..' UNKNOWN '..v)end end
