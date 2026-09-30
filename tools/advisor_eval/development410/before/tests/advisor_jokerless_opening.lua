local M=dofile('Brainstorm/Core/jokerless_opening.lua')
local checks=0
local function check(v,label) assert(v,label);checks=checks+1 end
for i=0,200 do
  local seed=(i+0.125)/201
  math.randomseed(seed)
  check(M.random(seed)==math.random(),'private LuaJIT random parity '..i)
end
local original=math.randomseed
math.randomseed=function()error('global RNG must not be touched')end
check(type(M.stream('J2710002')('Tag1'))=='number','keyed stream has no global RNG call')
math.randomseed=original
check(M.seed_at(0)=='11111111' and M.seed_at(35)=='12111111','stable bounded seed enumeration')
local F=dofile('tests/jokerless_opening_fixture.lua')
local function copy(v) if type(v)~='table' then return v end;local x={};for k,a in pairs(v) do x[k]=copy(a) end;return x end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
for _,e in ipairs(F.examples) do
 local p=M.predict(e.seed,F.catalog)
 for _,key in ipairs({'small_tag','big_tag','voucher','shop','packs'}) do check(equal(p[key],e[key]),'complete original-source parity '..e.seed..' '..key) end
 check(M.validate_result(p)==not not (not e.seed:find('0')),'only UI seed alphabet admitted')
end
local recipe=M.predict(F.examples[2].seed,F.catalog)
check(M.match(copy(recipe),{min_blue=2,require_saturn=true,require_telescope=true}),'two selectable Blue seals plus Saturn and Telescope')
check(not M.match(copy(recipe),{min_blue=2,min_steel=1}),'do not invent Blue Steel')
local capped=copy(recipe);capped.packs[1].choose=1;capped.packs[2].cards={}
for _,c in ipairs(capped.packs[1].cards) do c.seal='Blue';c.key='m_steel' end
check(not M.match(capped,{min_blue=2,min_quality=2,min_steel=2}),'all predicate counts honor actual pack choice cap')
check(not M.search(F.catalog,{limit=1000001}),'one million search bound')
check(not M.search(F.catalog,{limit=1,max_matches=17}),'result count bounded')
check(not M.search(F.catalog,{limit=1,min_blue=0/0}),'malformed predicate rejected')
local function snapshot()
 return {phase='blind',challenge='c_jokerless_1',ante=1,round=0,blind_on_deck='Small',skip_tags={Small='tag_coupon'},
  filter_info={jokerless_opening=copy(recipe),jokerless_catalog_signature=recipe.catalog_signature},blind_states={},
  shop_jokers={},shop_booster={},shop_vouchers={},consumeables={},consumable_limit=2,dollars=10,bankrupt_at=0}
end
local function action(s,kind,index)
 local before=copy(s);local r=M.advice(s);check(equal(before,s),'advice does not mutate snapshot or recipe')
 check(r and r.action and r.action.kind==kind and (not index or r.action.index==index),'expected recipe action '..kind)
end
local function review(s,label) local r=M.advice(s);check(r and not r.action and #r.warnings>0,label) end
local s=snapshot();action(s,'skip_blind')
s.skip_tags.Small='tag_charm';review(s,'tag mismatch pauses')
s=snapshot();s.blind_on_deck='Big';s.blind_states.Small='Skipped';action(s,'select_blind')
s.phase='hand';check(M.advice(s)==nil,'ordinary hand solver retains control')
s=snapshot();s.filter_info.jokerless_catalog_signature='mismatch';review(s,'catalog mismatch pauses')
s=snapshot();s.filter_info.jokerless_opening.packs[1].cards[1].front=nil;review(s,'malformed card pauses without exception')
s=snapshot();s.round=1;s.phase='shop';s.blind_states.Small='Skipped'
s.shop_jokers={{key='c_pluto',cost=0},{key='c_saturn',cost=0}}
s.shop_booster={{key=recipe.packs[1].key,cost=0},{key=recipe.packs[2].key,cost=0}}
s.shop_vouchers={{key='v_telescope',cost=10}}
action(s,'buy',2)
s.consumeables={{key='c_saturn'}};action(s,'use',1)
s.consumeables={};s.shop_jokers={{key='c_pluto',cost=0}};action(s,'buy',1)
s.dollars=9;action(s,'open',1)
s.dollars=10;s.bankrupt_at=-5;action(s,'buy',1)
s.dollars=10;s.bankrupt_at=0;s.shop_vouchers={};action(s,'open',1)
s.shop_booster[1].cost=6;review(s,'Coupon affordability must be visible free price')
s.shop_booster[1].cost=0;s.shop_jokers={{key='c_death',cost=0}};review(s,'rerolled shop mismatches recipe')
s.shop_jokers={{key='c_saturn',cost=0}};s.consumeables={{key='c_fool'},{key='c_chariot'}};review(s,'full inventory pauses safely')
local suit={C='Clubs',D='Diamonds',H='Hearts',S='Spades'};local rank={T=10,J=11,Q=12,K=13,A=14}
local function visible(c)
 local r=c.front:sub(3);return {key=c.key,enhancement=c.key~='c_base' and c.key or nil,rank=rank[r] or tonumber(r),suit=suit[c.front:sub(1,1)],
   seal=c.seal~='none' and c.seal or nil,edition=c.edition~='base' and {[c.edition]=true} or nil}
end
s=snapshot();s.round=1;s.phase='pack';s.pack_type='STANDARD_PACK';s.blind_states.Small='Skipped';s.pack_cards={};s.pack_choices=1
for _,c in ipairs(recipe.packs[1].cards) do s.pack_cards[#s.pack_cards+1]=visible(c) end
action(s,'choose',4)
for _,kind in ipairs({'TAROT_PACK','PLANET_PACK','SPECTRAL_PACK','BUFFOON_PACK'}) do
 s.pack_type=kind;check(M.advice(s)==nil,'unrelated '..kind..' leaves ordinary advisor in control')
end;s.pack_type='STANDARD_PACK'
s.pack_cards[1].rank=2;review(s,'entire visible pack compared, not only Blue target')
s.pack_cards[1]=visible(recipe.packs[1].cards[1]);s.pack_cards[4].face_down=true;review(s,'concealed target rejected')
s.pack_cards[4].face_down=nil;s.pack_cards[4].edition={negative=true};review(s,'unsupported edition rejected')
s.pack_cards[4]=visible(recipe.packs[1].cards[4]);table.remove(s.pack_cards,4)
check(M.advice(s)==nil,'after Blue pick normal remaining choice may proceed')
s.opened_booster_key='p_arcana_normal_1';check(M.advice(s)==nil,'public later nonstandard pack left to normal advisor')
local g={STAGE=1,STAGES={RUN=1},STATE=2,STATES={BLIND_SELECT=2},GAME={challenge='c_jokerless_1',challenge_tab={id='c_jokerless_1'},stake=1,round=0,round_resets={ante=1,blind_states={Small='Select'}},hands_played=0,blind_on_deck='Small',skips=0,
 used_vouchers={},modifiers={},tags={},joker_rate=0,tarot_rate=4,planet_rate=4,playing_card_rate=0,edition_rate=1,shop={joker_max=2},
 banned_keys=copy(F.banned),used_jokers={c_base=true}},jokers={cards={},config={card_limit=0}},consumeables={cards={}},P_CENTERS={},P_CENTER_POOLS={},P_CARDS={},playing_cards={}}
for set,keys in pairs(F.prototype_keys) do g.P_CENTER_POOLS[set]={};for i,key in ipairs(keys) do
 local c={key=key,set=set,unlocked=true,config={}};g.P_CENTER_POOLS[set][i]=c;g.P_CENTERS[key]=c
 local source=({Tag='tags',Voucher='vouchers',Planet='planets',Tarot='tarots',Enhanced='enhancements'})[set]
 if source and F.catalog[source][i]=='UNAVAILABLE' and not F.banned[key] then
  if set=='Tag' then c.min_ante=2 elseif set=='Voucher' then c.requires={'earlier_voucher'} elseif set=='Planet' then c.config.softlock=true else c.unlocked=false end
 end
 if set=='Booster' then for _,p in ipairs(F.catalog.boosters) do if p.key==key then c.kind=p.kind;c.weight=p.weight;c.cost=p.cost;c.config={extra=p.extra,choose=p.choose} end end end
end end
for _,c in ipairs(F.catalog.fronts) do g.P_CARDS[c.key]={suit=c.suit};g.playing_cards[#g.playing_cards+1]={config={card_key=c.key,center={key='c_base'}}} end
local before=copy(g);local catalog=assert(M.catalog(g));check(equal(before,g),'live catalog does not mutate game')
for _,key in ipairs({'tags','vouchers','tarots','planets','boosters','fronts','edition_rate'}) do check(equal(catalog[key],F.catalog[key]),'live public catalog parity '..key) end
g.STAGE=0;check(not M.catalog(g),'menu stage is not a fresh run');g.STAGE=1
g.STATE=3;check(not M.catalog(g),'non-blind selection state rejected');g.STATE=2
g.GAME.blind_on_deck='Big';check(not M.catalog(g),'skipped Small Blind cannot be replaced');g.GAME.blind_on_deck='Small'
g.GAME.round_resets.blind_states.Small='Skipped';check(not M.catalog(g),'selected Small Blind required');g.GAME.round_resets.blind_states.Small='Select'
g.GAME.skips=1;check(not M.catalog(g),'prior skip rejected');g.GAME.skips=0
g.GAME.round=1;check(not M.catalog(g),'fresh-run gate');g.GAME.round=0
g.GAME.planet_rate=5;check(not M.catalog(g),'rate drift rejected');g.GAME.planet_rate=4
g.GAME.banned_keys.tag_coupon=true;check(not M.catalog(g),'ban drift rejected');g.GAME.banned_keys.tag_coupon=nil
g.playing_cards[1].seal='Blue';check(not M.catalog(g),'non-original deck rejected');g.playing_cards[1].seal=nil
g.P_CENTER_POOLS.Tag[1].key='tag_custom';check(not M.catalog(g),'custom pool rejected')
print('advisor_jokerless_opening: '..checks..' checks passed')
