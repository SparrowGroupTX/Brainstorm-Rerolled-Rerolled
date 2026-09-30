local O=dofile('Brainstorm/Core/challenge_opening.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local count=0
local function check(v,msg) count=count+1;assert(v,msg) end
local function game(id)
  local p=O.profiles[id] or {0,0,0}
  local g={STAGES={RUN=1},STAGE=1,STATES={BLIND_SELECT=2},STATE=2,STATE_COMPLETE=true,
    jokers={cards={},config={card_limit=p[1]}},consumeables={cards={}},FUNCS={}}
  g.GAME={challenge=id,challenge_tab={id=id,deck={type='Challenge Deck'}},round=0,stake=1,skips=0,
    blind_on_deck='Small',round_resets={ante=1,blind_states={Small='Select'}},banned_keys={},modifiers={}}
  for i=1,p[2] do g.jokers.cards[i]={config={center={key=id=='c_omelette_1' and 'j_egg' or 'j_joker'}},ability={}} end
  return g
end
local config={enabled=true,targets={'',''}}
for id in pairs(O.profiles) do check(O.validate(game(id),config),id..' opening allowed') end
check(not O.validate(game('c_jokerless_1'),config),'Jokerless excluded')
check(not O.validate(game('mod_challenge'),config),'unknown excluded')
for _,field in ipairs({'round','skips'}) do local g=game('c_city_1');g.GAME[field]=1;check(not O.validate(g,config),'no progressed '..field) end
local g=game('c_city_1');g.GAME.blind_on_deck='Big';check(not O.validate(g,config),'only first small')
g=game('c_city_1');g.GAME.banned_keys.c_soul=true;check(not O.validate(g,config),'Soul ban')
g=game('c_city_1');g.GAME.banned_keys.tag_charm=true;check(not O.validate(g,config),'Charm ban')
g=game('c_city_1');g.GAME.banned_keys.tag_rare=true;check(not O.validate(g,config),'changed tag pool')
g=game('c_city_1');g.GAME.banned_keys.j_perkeo=true;check(not O.validate(g,config),'changed Legendary pool')
g=game('c_omelette_1');for _,j in ipairs(g.jokers.cards) do j.ability.eternal=true end;check(not O.validate(g,config),'cannot sell eternal Eggs')
g=game('c_bram_poker_1');g.consumeables.cards={{config={center={key='c_empress'}}},{config={center={key='c_emperor'}}}}
check(O.validate(g,config),'Bram original consumables permitted')
g.consumeables.cards[1].config.center.key='c_soul';check(not O.validate(g,config),'starting Soul unsupported')
check(O.targets({targets={'j_yorick','j_perkeo'}})=='j_yorick,j_perkeo','CSV targets')
check(not O.targets({targets={'j_yorick','j_yorick'}}),'duplicate target')
check(not O.targets({targets={'j_joker',''}}),'nonlegendary target')
local raw='{"status":"found","challenge_id":"c_city_1","first_tag":"tag_charm","multi_soul_exception":true,"required_sales":0,"starting_joker_count":2,"starting_joker_limit":5,"search_limit":1,"seed":"I1L21111","soul_count":2,"legendary_jokers":["j_yorick","j_perkeo"]}'
check(O.result(raw,'c_city_1','j_perkeo,j_yorick'),'valid result')
check(O.result(raw:gsub('I1L21111','A'),'c_city_1',''),'short native seed allowed')
check(not O.result(raw,'c_city_1','j_chicot'),'missing requested target')
check(not O.result(raw,'c_omelette_1',''),'wrong challenge')
check(not O.result(raw:gsub('j_perkeo','j_yorick'),'c_city_1',''),'duplicate result')
check(not O.result(raw:gsub('I1L21111','BAD0SEED'),'c_city_1',''),'invalid seed')
check(not O.decode('{"status":"found","status":"not_found"}'),'duplicate JSON key')
check(not O.decode(raw..'junk'),'trailing JSON')
check(not O.decode('{"a":function() end}'),'never eval input')
check(not O.decode('{"a":"escaped\\n"}'),'unsupported escapes rejected')
local no_match='{"status":"not_found","challenge_id":"c_city_1","first_tag":"tag_charm","multi_soul_exception":true,"required_sales":0,"starting_joker_count":2,"starting_joker_limit":5,"search_limit":1,"next_seed":"A"}'
check(O.result(no_match,'c_city_1',''),'bounded miss valid')
check(O.result(no_match:gsub('"A"','""'),'c_city_1',''),'wrapped cursor valid')

-- Search may restart only its own unchanged, valid fresh challenge, once.
G=game('c_city_1');local starts,deleted,alerts,calls=0,0,0,{}
local definition=G.GAME.challenge_tab
G.delete_run=function() deleted=deleted+1 end
G.start_run=function(self,args) starts=starts+1;check(args.challenge==definition,'preserves definition identity');self.GAME={challenge=args.challenge.id} end
local B={config={}}
O.attach(B,{alert=function() alerts=alerts+1 end,search=function(seed,id,targets) calls[#calls+1]=seed;return #calls==1 and no_match or raw end})
check(B.startChallengeOpeningSearch(),'explicit start')
check(B.challengeOpeningSearch('12345678')==nil and deleted==0 and B.ar_active,'miss keeps run')
check(B.challengeOpeningSearch('IGNORED')=='I1L21111','next batch found')
check(calls[2]=='A','native cursor used')
check(starts==1 and deleted==1 and not B.ar_active,'one restart then stop')
check(G.GAME.filter_info.challenge_opening and not G.GAME.seeded,'route metadata saved')
check(B.challengeOpeningSearch('12345678')==nil and starts==1,'progressed/invalid state never restart')
G=game('c_city_1');B={config={}};alerts=0
O.attach(B,{alert=function() alerts=alerts+1 end,search=function() error('missing DLL export') end})
B.startChallengeOpeningSearch();B.challengeOpeningSearch('12345678')
check(not B.ar_active and alerts==1,'native failure stops and alerts once')

local f={challenge_opening=true,challenge_id='c_omelette_1',multi_soul_pack_consumed=false}
local s={challenge='c_omelette_1',filter_info=f,phase='blind',round=0,ante=1,blind_on_deck='Small',skip_tags={Small='tag_charm'}}
check(O.advice(s).action.kind=='skip_blind','advisor skips searched tag')
s.round=1;check(not O.advice(s),'route expires after opening');s.round=0
s.phase='pack';s.opening_pack=true;f.multi_soul_pack_consumed=true;s.pack_cards={{key='c_soul'}};s.joker_limit=5;s.jokers={}
for i=1,5 do s.jokers[i]={key='j_egg',ability={}} end
check(O.advice(s).action.kind=='sell','full Omelette row sells one Egg')
table.remove(s.jokers);check(O.advice(s).action.kind=='choose','choose visible Soul once space exists')
s.opening_pack=false;check(not O.advice(s),'do not hijack unrelated pack')
g=game('c_city_1');g.GAME.filter_info={challenge_opening=true,challenge_id='c_city_1'}
check(not O.matching_pack(g.GAME,{}),'no exception before skip')
g.GAME.round_resets.blind_states.Small='Skipped';g.GAME.blind_on_deck='Big'
check(O.matching_pack(g.GAME,{}),'first skipped Small pack only')
g.GAME.round=1;check(not O.matching_pack(g.GAME,{}),'no exception later')
check(O.matching_pack({filter_info={required_soul_count=2}},{}),'normal filtered route preserved')
g=game('c_city_1');g.STATES.SHOP=4;g.STATE=4;g.consumeables.config={card_limit=2}
g.P_BLINDS={bl_small={mult=1},bl_big={mult=1.5},bl_wall={mult=4}}
g.GAME.round_resets.blind_ante=1
g.GAME.round_resets.blind_states={Small='Defeated',Big='Select'}
check(S.capture(g).next_blind_chips==450,'next Big blind printed requirement')
g.GAME.round_resets.blind_choices={Boss='bl_wall'};g.GAME.round_resets.blind_states.Big='Defeated'
check(S.capture(g).next_blind_chips==1200,'next boss printed multiplier')
g.GAME.round_resets.blind_states.Boss='Defeated';g.GAME.round_resets.ante=2
check(S.capture(g).next_blind_chips==800,'post-boss shop uses next ante')
g.GAME.blind={boss=true,hands_sub=3,discards_sub=2}
local captured=S.capture(g)
check(captured.blind.boss and captured.blind.hands_sub==3 and captured.blind.discards_sub==2,'boss removal resources captured')

-- Source-level integration guard: the only dispatch is inside autoReroll and
-- precedes normal query construction and native calls.
local file=assert(io.open('Brainstorm/Core/Brainstorm.lua','rb'));local core=file:read('*a');file:close()
local auto=assert(core:find('function Brainstorm.autoReroll()',1,true))
local call=assert(core:find('if G.GAME.challenge then return Brainstorm.challengeOpeningSearch(seed_found) end',1,true))
check(call>auto and call<core:find('local search_query',auto,true),'challenge dispatch isolated before normal query')
check(not core:find('Brainstorm.challengeOpeningSearch(seed_found)',call+90,true),'only one dispatch')
print('advisor_challenge_opening: '..count..' checks passed')
