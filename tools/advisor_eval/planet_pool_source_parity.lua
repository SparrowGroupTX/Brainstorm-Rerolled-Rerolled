-- Synthetic public catalogs; original source pool/price methods precede this file.
local Snapshot=dofile(PROBE_POLICY..'/Brainstorm/Advisor/snapshot.lua')
local Reroll=dofile(PROBE_POLICY..'/Brainstorm/Advisor/paid_reroll.lua')
function EMPTY(t) for k in pairs(t or {}) do t[k]=nil end;return t or {} end
local checks=0
local function eq(left,right,message)
  checks=checks+1;assert(left==right,message..': '..tostring(left)..' ~= '..tostring(right))
end
local function planet(key,hand,extra)
  local c={key=key,name=key,set='Planet',cost=3,unlocked=true,config={hand_type=hand},order=1}
  for k,v in pairs(extra or {}) do c[k]=v end;return c
end
local function card(c,id)
  return {config={center=c},ability={name=c.name,set=c.set},base={},base_cost=c.cost,sort_id=id,facing='front'}
end
local function joker(key,name,debuff)
  local c=card({key=key,name=name,set='Joker',cost=5},100);c.debuff=debuff;return c
end
local function state()
  local pool={planet('c_mercury','Pair'),planet('c_jupiter','Flush'),
    planet('c_soft','Flush Five',{config={hand_type='Flush Five',softlock=true}}),
    planet('c_flag','High Card',{yes_pool_flag='enabled'}),
    planet('c_block','High Card',{no_pool_flag='blocked'}),
    planet('c_locked','High Card',{unlocked=false}),
    planet('c_black','High Card',{name='Black Hole'})}
  return {STAGES={RUN=1},STAGE=1,STATES={SHOP=2},STATE=2,ARGS={TEMP_POOL={}},SETTINGS={},
    P_JOKER_RARITY_POOLS={{},{},{}},P_CENTER_POOLS={Planet=pool,Tarot={}},playing_cards={},
    jokers={cards={},config={card_limit=5}},consumeables={cards={},config={card_limit=5}},
    shop_jokers={cards={}},
    GAME={shop={joker_max=2},joker_rate=0,tarot_rate=4,planet_rate=4,playing_card_rate=0,spectral_rate=0,
      dollars=100,discount_percent=0,inflation=0,rental_rate=3,edition_rate=1,modifiers={},
      banned_keys={},pool_flags={},used_jokers={},tags={},current_round={reroll_cost=1},round_resets={ante=2},
      hands={Pair={played=1},Flush={played=1},['High Card']={played=1},['Flush Five']={played=0}}}}
end
local cases={
  {'ordinary',function() end},
  {'softlock_played',function(g) g.GAME.hands['Flush Five'].played=1 end},
  {'flags_bans_locked',function(g) g.GAME.pool_flags.enabled=true;g.GAME.pool_flags.blocked=true;g.GAME.banned_keys.c_mercury=true end},
  {'removed_offer_owned',function(g)
    g.shop_jokers.cards={card(g.P_CENTER_POOLS.Planet[1],1),card(g.P_CENTER_POOLS.Planet[2],2)}
    g.consumeables.cards={card(g.P_CENTER_POOLS.Planet[1],3)}
    g.GAME.used_jokers={c_mercury=true,c_jupiter=true}
  end},
  {'active_showman',function(g) g.jokers.cards={joker('j_ring_master','Showman')};g.GAME.used_jokers.c_mercury=true end},
  {'debuffed_showman',function(g) g.jokers.cards={joker('j_ring_master','Showman',true)};g.GAME.used_jokers.c_mercury=true end},
  {'discount_inflation',function(g) g.GAME.inflation=2;g.GAME.discount_percent=25 end},
  {'astronomer',function(g) g.jokers.cards={joker('j_astronomer','Astronomer')};g.GAME.inflation=2;g.GAME.discount_percent=25 end},
  {'debuffed_astronomer',function(g) g.jokers.cards={joker('j_astronomer','Astronomer',true)};g.GAME.inflation=2;g.GAME.discount_percent=25 end},
  {'empty_fallback',function(g) for _,c in ipairs(g.P_CENTER_POOLS.Planet) do g.GAME.banned_keys[c.key]=true end end},
}
local function evidence(score)
  return {before_readiness={supported=true,status='sampled_deficit',target=100,opening_scores={20,20,20,20},opening_mean=20},
    after_readiness={supported=true,target=100,opening_scores={score,score,score,score}}}
end
local function run(spec)
  G=state();spec[2](G)
  local s=Snapshot.capture(G);local before=Snapshot.fingerprint(s)
  local prices={}
  local advice=Reroll.planet_suggest(s,function(entry,price) prices[entry.key]=price;return 1 end,evidence(20),
    {compare=function() return evidence(100) end,compare_miss=function() return evidence(20) end})
  eq(Snapshot.fingerprint(s),before,spec[1]..' input conservation')
  -- Explicit source first-slot setup: old shop cards are removed and held cards remain used.
  for _,c in ipairs(G.shop_jokers.cards) do G.GAME.used_jokers[c.config.center.key]=nil end
  for _,c in ipairs(G.consumeables.cards) do G.GAME.used_jokers[c.config.center.key]=true end
  G.shop_jokers.cards={}
  local pool=get_current_pool('Planet');local expected={}
  for _,key in ipairs(pool) do if key~='UNAVAILABLE' then expected[#expected+1]=key end end
  table.sort(expected)
  local actual={};for key in pairs(prices) do actual[#actual+1]=key end;table.sort(actual)
  if spec[1]=='empty_fallback' then
    eq(table.concat(expected,','),'c_pluto','source empty fallback')
    eq(#actual,0,'fallback earns no assessed mass');eq(advice,nil,'fallback remains unknown')
  else
    eq(table.concat(actual,','),table.concat(expected,','),spec[1]..' eligible pool')
    for _,key in ipairs(expected) do
      local center;for _,c in ipairs(G.P_CENTER_POOLS.Planet) do if c.key==key then center=c end end
      local c=card(center,200);Card.set_cost(c)
      eq(prices[key],c.cost,spec[1]..' original price '..key)
    end
    eq(type(advice),'table',spec[1]..' bounded catalog advice')
    eq(advice.reroll_forecast.credited_slots,1,spec[1]..' only first slot')
    eq(advice.reroll_forecast.covered_pool_mass,0.5,spec[1]..' actual type mass')
  end
end
local function quoted(text)
  return '"'..tostring(text):gsub('[%z\1-\31\\"]',function(c)
    local escapes={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return escapes[c] or string.format('\\u%04x',string.byte(c)) end)..'"'
end
local passed=0
for _,spec in ipairs(cases) do
  local before=checks;local ok,reason=pcall(run,spec)
  if ok then passed=passed+1 end
  print('planet case_result {"case":'..quoted(spec[1])..',"status":'..quoted(ok and 'passed' or 'error')..
    ',"comparison_assertions_attempted":'..(checks-before)..',"reason":'..(ok and 'null' or quoted(reason))..'}')
end
print('planet source parity: '..passed..' cases, '..checks..' comparisons')
assert(passed==#cases,'One or more registered cases failed; independent results retained')
