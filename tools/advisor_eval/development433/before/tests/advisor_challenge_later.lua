local O=dofile('Brainstorm/Core/challenge_opening.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function eq(a,b,label)check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function game(id)
 local p=O.profiles[id or 'c_city_1'] or {0,0,0}
 local g={STAGES={RUN=1},STAGE=1,STATES={BLIND_SELECT=2},STATE=2,STATE_COMPLETE=true,
  jokers={cards={},config={card_limit=p[1]}},consumeables={cards={}},FUNCS={},P_CENTERS={},P_JOKER_RARITY_POOLS={[3]={}}}
 g.GAME={challenge=id or 'c_city_1',challenge_tab={id=id or 'c_city_1'},round=0,stake=1,skips=0,
  blind_on_deck='Small',round_resets={ante=1,blind_states={Small='Select'}},banned_keys={},used_jokers={},modifiers={},shop={joker_max=2},tags={},
  joker_rate=20,tarot_rate=4,planet_rate=id=='c_blast_off_1' and 32 or 4,playing_card_rate=0,spectral_rate=0,edition_rate=1}
 for i,expected in ipairs(O.starting_rows[id or 'c_city_1'] or {})do
  g.jokers.cards[i]={config={center={key=expected[1]}},ability={eternal=expected[2]},
    edition=expected[3] and {negative=true,type='negative'} or nil,pinned=expected[4]}
  g.GAME.used_jokers[expected[1]]=true
 end
 for i,key in ipairs(O.rare_keys)do
  local center={key=key,set='Joker',rarity=3,unlocked=true};g.P_CENTERS[key]=center;g.P_JOKER_RARITY_POOLS[3][i]=center
 end
 return g
end
local cfg=O.defaults({});eq(cfg.later_enabled,false);eq(cfg.later_target,'j_blueprint');eq(cfg.later_ante,2)
local config={enabled=true,targets={'j_yorick','j_perkeo'},later_enabled=true,later_target='j_blueprint',later_ante=2}
local g=game();local valid,csv,later=O.validate(g,config)
check(valid);eq(csv,'j_yorick,j_perkeo');eq(later.target_key,'j_blueprint');eq(later.deadline,2);eq(later.rare_pool_mask,string.rep('1',20))
for _,key in ipairs(O.rare_keys)do local q=copy(config);q.later_target=key;check(O.validate(g,q),'supports '..key)end
for ante=2,8 do local q=copy(config);q.later_ante=ante;check(O.validate(g,q),'deadline '..ante)end
local q=copy(config);q.later_target='j_perkeo';check(not O.validate(g,q),'later target cannot replace a Legendary')
q.later_target='j_joker';check(not O.validate(g,q),'unknown common eligibility not advertised as supported')
q=copy(config);for _,value in ipairs({1,9,2.5,'2'})do q.later_ante=value;check(not O.validate(g,q))end
q=copy(config);q.later_enabled='yes';check(not O.validate(g,q))
q=copy(config);q.later_enabled=false;q.later_target='unknown';q.later_ante=99
check(O.validate(game('c_bram_poker_1'),q),'disabled option preserves original Bram opening')
check(not O.validate(game('c_bram_poker_1'),config),'Bram has no shop Joker later route')
check(not O.validate(game('c_jokerless_1'),config),'Jokerless remains excluded')
for field,value in pairs({joker_rate=21,tarot_rate=8,planet_rate=8,playing_card_rate=1,spectral_rate=1,edition_rate=2})do
 local changed=game();changed.GAME[field]=value;check(not O.validate(changed,config),'reject changed '..field)
 changed.GAME[field]=nil;check(not O.validate(changed,config),'reject missing '..field)
end
local changed=game();changed.GAME.shop.joker_max=3;check(not O.validate(changed,config),'expanded shop slots')
changed=game();changed.GAME.tags={{key='tag_rare'}};check(not O.validate(changed,config),'pending tags change shop generation')
check(O.validate(game('c_blast_off_1'),config),'Blast Off has the declared Planet Tycoon rate')
local locked=game();locked.P_CENTERS.j_blueprint.unlocked=false;check(not O.validate(locked,config),'locked target')
locked=game();locked.GAME.banned_keys.j_blueprint=true;check(not O.validate(locked,config),'banned target')
locked=game();locked.GAME.used_jokers.j_blueprint=true;check(not O.validate(locked,config),'owned target')
locked=game();locked.P_CENTERS.j_dna.unlocked=false;local req=assert(O.later_request(locked,config));eq(req.rare_pool_mask:sub(1,1),'0')
locked=game();locked.P_CENTERS.j_dna.unlocked=nil;check(not O.validate(locked,config),'unknown unlock profile')
locked=game();locked.P_CENTERS.j_dna.yes_pool_flag='unknown_gate';check(not O.validate(locked,config),'unknown Rare gameplay gate')
locked=game();locked.P_JOKER_RARITY_POOLS[3][1],locked.P_JOKER_RARITY_POOLS[3][2]=locked.P_JOKER_RARITY_POOLS[3][2],locked.P_JOKER_RARITY_POOLS[3][1]
check(not O.validate(locked,config),'changed source pool order')
locked=game('c_monolith_1');locked.GAME.used_jokers.j_obelisk=nil;check(not O.validate(locked,config),'inconsistent physical ownership flags')
locked.GAME.used_jokers.j_obelisk=true;check(O.validate(locked,config),'consistent original starting Rare is excluded without hiding other targets')
for _,field in ipairs({'eternal','perishable','rental'})do
 local altered=game();altered.jokers.cards[1].ability[field]=field~='eternal';check(not O.validate(altered,config),'changed starting '..field)
end
local altered=game();altered.jokers.cards[1].edition={negative=true,type='negative'};check(not O.validate(altered,config),'extra starting Negative cannot fabricate room')
altered=game('c_knife_1');altered.jokers.cards[1].pinned=false;check(not O.validate(altered,config),'original Knife pin required')
altered=game();altered.SETTINGS={tutorial_progress={forced_shop={'j_blueprint'}}};check(not O.validate(altered,config),'forced tutorial shop')
altered=game();altered.load_shop_jokers={};check(not O.validate(altered,config),'saved shop regeneration is not the conditional schedule')
altered=game();altered.GAME.used_jokers=nil;check(not O.validate(altered,config),'unknown ownership profile')
for _,field in ipairs({'all_eternal','no_shop_jokers'})do
 local altered=game();altered.GAME.modifiers[field]=true;check(not O.validate(altered,config),'changed '..field..' rule')
end
local permanent=game('c_non_perishable_1');permanent.GAME.modifiers.all_eternal=true;permanent.GAME.banned_keys.j_invisible=true
check(O.validate(permanent,config),'original all-Eternal challenge remains supported')
permanent.GAME.modifiers.all_eternal=false;check(not O.validate(permanent,config),'missing original all-Eternal rule')
local base={status='found',challenge_id='c_city_1',first_tag='tag_charm',multi_soul_exception=true,required_sales=0,
 starting_joker_count=2,starting_joker_limit=5,search_limit=1,seed='I1L21111',soul_count=2,legendary_jokers={'j_yorick','j_perkeo'},
 api_version=2,later_target='j_blueprint',later_deadline=2,later_pool_mask=string.rep('1',20),later_source='shop_initial',
 later_schedule='first_charm_then_play_all_fixed_rare_pool',later_offer_status='conditional',later_retention='not_verified',
 later_found_ante=2,later_shop=3,later_slot=2,later_edition='negative',later_eternal=false}
local function json(value)
 if type(value)=='string'then return '"'..value..'"'end
 if type(value)~='table'then return tostring(value)end
 if #value>0 then local out={};for _,x in ipairs(value)do out[#out+1]=json(x)end;return '['..table.concat(out,',')..']'end
 local keys,out={},{};for key in pairs(value)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do out[#out+1]=json(key)..':'..json(value[key])end;return '{'..table.concat(out,',')..'}'
end
local raw=json(base);local parsed=assert(O.result(raw,'c_city_1',csv,later));local plan=assert(O.later_plan(parsed))
eq(plan.target_key,'j_blueprint');eq(plan.found_ante,2);eq(plan.shop,3);eq(plan.slot,2);eq(#plan.rare_pool_keys,20)
eq(plan.acquisition_verified,false);eq(plan.retention_verified,false);eq(plan.shop_slots,2);eq(plan.shop_rates.planet_rate,4)
plan.shop_rates.joker_rate=999;eq(O.later_plan(parsed).shop_rates.joker_rate,20,'shop profile metadata is detached')
plan.rare_pool_keys[1]='edited';eq(O.later_plan(parsed).rare_pool_keys[1],'j_dna','plan arrays are detached')
for field,value in pairs({api_version=1,later_target='j_dna',later_deadline=3,later_pool_mask='00000000000000000000',
 later_source='pack',later_schedule='any_play',later_offer_status='owned',later_retention='verified',later_found_ante=3,
 later_shop=4,later_slot=3,later_edition='unknown',later_eternal='false'})do
 local bad=copy(base);bad[field]=value;check(not O.result(json(bad),'c_city_1',csv,later),'reject mismatched '..field)
end
local bad=copy(base);bad.later_found_ante=1;bad.later_shop=2;check(not O.result(json(bad),'c_city_1',csv,later),'Ante 1 has only the post-Big shop')
local miss=copy(base);miss.status='not_found';miss.seed=nil;miss.soul_count=nil;miss.legendary_jokers=nil;miss.next_seed='A'
for _,field in ipairs({'later_found_ante','later_shop','later_slot','later_edition','later_eternal'})do miss[field]=nil end
check(O.result(json(miss),'c_city_1',csv,later),'v2 bounded miss retains conditional request provenance')
local typecast=copy(base);typecast.challenge_id='c_typecast_1';typecast.starting_joker_count=0;typecast.later_deadline=8;typecast.later_found_ante=5
local requested=copy(later);requested.deadline=8
check(not O.result(json(typecast),'c_typecast_1',csv,requested),'Typecast cannot fabricate offers after its supported slot boundary')
local legacy=copy(base);for key in pairs(legacy)do if key:find('later_',1,true)==1 or key=='api_version'then legacy[key]=nil end end
check(not O.result(json(legacy),'c_city_1',csv,later),'v1 cannot silently satisfy enabled later target')
-- A successful enabled request forwards only the explicit request table and
-- preserves the challenge definition plus unverified conditional metadata.
G=game();local starts,deletes,alerts=0,0,0;local def=G.GAME.challenge_tab
G.delete_run=function()deletes=deletes+1 end
G.start_run=function(self,args)starts=starts+1;eq(args.challenge,def);self.GAME={challenge=args.challenge.id}end
local B={config={challenge_opening=copy(config)}}
O.attach(B,{alert=function()alerts=alerts+1 end,search=function(seed,id,targets,request)
 eq(seed,'ABC');eq(id,'c_city_1');eq(targets,csv);eq(request.rare_pool_mask,later.rare_pool_mask);return raw
end})
check(B.startChallengeOpeningSearch());eq(B.challengeOpeningSearch('ABC'),'I1L21111');eq(starts,1);eq(deletes,1);eq(alerts,0)
eq(G.GAME.filter_info.native_api_version,'challenge_opening_v2');eq(G.GAME.filter_info.later.target_key,'j_blueprint')
eq(G.GAME.filter_info.later.retention_verified,false);eq(G.GAME.filter_info.legendary_jokers[2],'j_perkeo')
for _,change in ipairs({'deadline','mask','disable','rates'})do
 G=game();G.delete_run=function()error('stale result must not replace run')end;G.start_run=G.delete_run
 local alert=0;B={config={challenge_opening=copy(config)}}
 O.attach(B,{alert=function()alert=alert+1 end,search=function()
  if change=='deadline'then B.config.challenge_opening.later_ante=3
  elseif change=='mask'then G.P_CENTERS.j_dna.unlocked=false
  elseif change=='rates'then G.GAME.joker_rate=21
  else B.config.challenge_opening.later_enabled=false end
  return raw
 end})
 check(B.startChallengeOpeningSearch());eq(B.challengeOpeningSearch('ABC'),nil);eq(alert,1);check(not B.ar_active)
end
-- Disabled mode forwards exactly the original three arguments, even when stale
-- later preferences remain in the settings file.
G=game();B={config={challenge_opening=copy(config)}};B.config.challenge_opening.later_enabled=false
O.attach(B,{alert=function()end,search=function(...)
 eq(select('#',...),3,'disabled v1 callback unchanged');return json(miss):gsub('"api_version":2,','')
end})
check(B.startChallengeOpeningSearch());B.challengeOpeningSearch('ABC');check(B.ar_active)
-- Search costs accumulate across bounded miss batches and include native
-- failures. The declared batch limit is never reported as seeds evaluated.
local times={10,11.25,20,20.5,30,32};local tick,calls=0,{}
G=game();G.delete_run=function()end;G.start_run=function(self,args)self.GAME={challenge=args.challenge.id}end
B={config={challenge_opening=copy(config)}}
O.attach(B,{alert=function()error('unexpected cost fixture alert')end,now=function()tick=tick+1;return times[tick]end,
 search=function(seed)
  calls[#calls+1]=seed
  if #calls<3 then local m=copy(miss);m.next_seed=#calls==1 and 'A' or 'B';m.search_limit=1000000;return json(m)end
  local hit=copy(base);hit.search_limit=1000000;return json(hit)
 end})
check(B.startChallengeOpeningSearch());eq(O.last_search.batches,0)
eq(B.challengeOpeningSearch('ABC'),nil);eq(B.challengeOpeningSearch('IGNORED'),nil);eq(B.challengeOpeningSearch('IGNORED'),'I1L21111')
local ledger=G.GAME.filter_info.search
eq(ledger.batches,3);eq(ledger.misses,2);eq(ledger.timed_batches,3);eq(ledger.native_seconds,3.75)
eq(ledger.native_seconds_known,true);eq(ledger.start_cursor,'ABC');eq(ledger.end_cursor,'I1L21111')
eq(ledger.status,'found');eq(table.concat(calls,','),'ABC,A,B');eq(ledger.evaluated_seeds,nil)
ledger.batches=999;eq(O.last_search.batches,3,'stored run search ledger is detached')
for _,mode in ipairs({'stop','error','untimed'})do
 G=game();B={config={challenge_opening=copy(config)}};local clock=0;local alerts=0
 local deps={alert=function()alerts=alerts+1 end,search=function()
  if mode~='stop'then error('bounded native failure')end;return json(miss)
 end}
 if mode~='untimed'then deps.now=function()clock=clock+.25;return clock end end
 O.attach(B,deps);check(B.startChallengeOpeningSearch());B.challengeOpeningSearch('XYZ')
 if mode=='stop'then B.stopChallengeOpeningSearch()end
 eq(O.last_search.batches,1);eq(O.last_search.status,mode=='stop' and 'stopped' or 'error')
 eq(O.last_search.start_cursor,'XYZ');eq(O.last_search.misses,mode=='stop' and 1 or 0)
 eq(O.last_search.native_seconds_known,mode~='untimed')
 if mode=='untimed' then eq(O.last_search.native_seconds,nil) else eq(O.last_search.native_seconds,.25) end
 eq(alerts,mode=='stop' and 0 or 1);check(not B.ar_active)
end
print('advisor_challenge_later: '..checks..' checks passed')
