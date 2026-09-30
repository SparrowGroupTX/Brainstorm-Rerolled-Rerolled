local F=dofile('tests/fixtures/retained418.lua');local P='Brainstorm/Advisor/'
local B=dofile('tools/advisor_eval/runs/repair420_candidate4/policy/'..P..'strategy.lua');B.conditional_value=dofile('tools/advisor_eval/runs/repair420_candidate4/policy/'..P..'conditional_value.lua')
local S=dofile(P..'strategy.lua');S.joker_plan=dofile(P..'joker_plan.lua');S.conditional_value=dofile(P..'conditional_value.lua')
local function state(h,kings)local s=F.state();s.phase='pack';s.hands={[h]={played=12,level=4}};s.round_resets={hands=4,discards=3};s.next_blind={key='bl_big',ante=3};s.jokers={F.j('j_yorick'),F.j('j_perkeo')};if kings then s.playing_cards={};for i=1,24 do s.playing_cards[i]=F.card('catalog:'..i,13,({'Clubs','Spades','Diamonds','Hearts'})[i%4+1])end end;return s end
for _,c in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do
 local before,_,known=B.owned_joker_value(state('Pair'),c);local vals={}
 for _,h in ipairs({'High Card','Pair','Full House','Straight','Flush'})do vals[#vals+1]=string.format('%.4f',(S.owned_joker_value(state(h),c)))end
 vals[#vals+1]=string.format('%.4f',(S.owned_joker_value(state('Pair',true),c)))
 print('AUDIT\t'..c.key..'\t'..c.name..'\t'..tostring(known)..'\t'..string.format('%.4f',before)..'\t'..table.concat(vals,'\t'))
end
io.stdout:flush()
