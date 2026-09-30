-- Synthetic loaded tables only. No profile/save/game/source worker is opened.
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,why) checks=checks+1;assert(value,why) end
local function eq(a,b,why) check(a==b,(why or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(t) return Snapshot.copy(t) end
local function row(wins) return {count=1,order=1,wins=wins or {},losses={}} end
local function held(key) return {config={center_key=key},ability={set='Joker'}} end
local function state()
  local g={STAGE=2,STAGES={RUN=2},SETTINGS={profile=1},PROFILES={[1]={joker_usage={}}},P_CENTERS={},P_STAKES={},P_CENTER_POOLS={Stake={}},
    GAME={stake=8,seeded=false,won=false,win_ante=8,round_resets={ante=1}},jokers={cards={}},sticker_map={}}
  for _,key in ipairs(Gold.target_keys()) do
    g.P_CENTERS[key]={key=key,set='Joker',name='private-name:'..key,discovered=false,unlocked=false}
  end
  for level,name in ipairs({'white','red','green','black','blue','purple','orange','gold'}) do
    local stake={key='stake_'..name,set='Stake',order=level,stake_level=level}
    g.P_STAKES[stake.key]=stake;g.P_CENTER_POOLS.Stake[level]=stake;g.sticker_map[level]=name
  end
  return g
end
local function capture(g) return Gold.capture(g,{enabled=true}) end
local old_random,old_seed=math.random,math.randomseed
math.random=function()error('Progress must not draw RNG')end
math.randomseed=function()error('Progress must not reseed RNG')end
do
  local poison=setmetatable({},{__index=function()error('Disabled capture touched game data')end})
  eq(Gold.capture(poison),nil,'no opt-in gives no profile context')
  eq(Gold.capture(poison,{enabled=false}),nil,'explicit disabled evaluation remains clean')
  local keys=Gold.target_keys();eq(#keys,150,'all150 vanilla Jokers are targets')
  local seen={};for i,key in ipairs(keys) do
    check(not seen[key] and (i==1 or keys[i-1]<key),'target keys are unique and sorted');seen[key]=true
  end
  check(seen.j_perkeo and seen.j_ticket and seen.j_selzer and seen.j_stone,'locked, Legendary and original source-spelled keys remain included')
  keys[1]='mutated';check(Gold.target_keys()[1]~='mutated','callers cannot mutate the allowlist')
end
do
  local g=state();local original=Snapshot.fingerprint(g);local p=capture(g)
  eq(p.profile_id,1,'active public profile identity accompanies progress')
  eq(p.metadata_status,'complete','the full already-loaded table establishes known absence')
  eq(p.counts.missing,150,'empty complete history means150 missing stickers')
  eq(p.counts.complete,0,'empty history does not create wins')
  eq(p.counts.unknown,0,'empty loaded history is distinguished from unavailable history')
  eq(p.eligibility.eligible,true,'normal Gold run with verified loaded metadata is eligible')
  eq(p.held_target_count,0,'empty owned area has no carried target')
  eq(p.by_key.j_perkeo.status,'missing','locked undiscovered Joker is still a target')
  check(p.by_key.j_perkeo.name==nil and p.by_key.j_perkeo.discovered==nil and p.by_key.j_perkeo.unlocked==nil,
    'progress exposes no hidden catalog name, discovery or unlock metadata')
  eq(Snapshot.fingerprint(g),original,'capture does not mutate profile, catalog or game')
  p.by_key.j_perkeo.status='complete';eq(capture(g).by_key.j_perkeo.status,'missing','outputs cannot change later completion')
  g.PROFILES[1].joker_usage.j_joker=row({[1]=3,[7]=1})
  g.PROFILES[1].joker_usage.j_perkeo=row({[8]=1})
  g.PROFILES[1].joker_usage.j_blueprint=row({[1]=2,[8]=4})
  g.PROFILES[1].joker_usage.j_egg=false
  g.PROFILES[1].joker_usage.j_modded=row({[8]=1})
  p=capture(g)
  eq(p.counts.complete,2,'positive numeric Gold wins credit each vanilla Joker once')
  eq(p.counts.unknown,1,'a false/malformed row is not a known absence')
  eq(p.counts.missing,147,'lower stakes and modded Joker wins do not complete Gold targets')
  eq(p.by_key.j_joker.status,'missing','Orange and White wins are insufficient for Gold')
  eq(p.by_key.j_perkeo.status,'complete','collection flags do not suppress a recorded Gold win')
  g.jokers.cards={held('j_joker'),held('j_joker'),held('j_perkeo'),held('j_egg'),held('j_modded')}
  g.jokers.cards[1].debuff=true;g.jokers.cards[2].edition={negative=true}
  p=capture(g)
  eq(p.held_target_count,1,'duplicate/Negative/debuffed copies count one carried missing Joker key')
  eq(table.concat(p.held_target_keys,','),'j_joker','only known missing held vanilla keys are targets')
  eq(table.concat(p.held_unknown_keys,','),'j_egg','malformed held progress remains explicitly unknown')
  eq(#p.held_keys,3,'complete, missing and unknown vanilla held identities are unique')
  eq(p.held_status,'unsupported','an extra modded key is not claimed as known vanilla cargo')
  check(p.eligibility.eligible~=true,'unknown nonvanilla held effects cannot enable the objective')
end
for _,change in ipairs({
  function(g)g.PROFILES=nil end,function(g)g.PROFILES[1]=nil end,function(g)g.PROFILES[1].joker_usage=nil end,
  function(g)g.PROFILES[1].joker_usage=false end,function(g)g.PROFILES[1].joker_usage[2]=row()end,
  function(g)g.SETTINGS.profile=false end,function(g)g.SETTINGS.profile=0 end,
  function(g)g.PROFILES[1].joker_usage=setmetatable({},{__index=function()error('No profile callbacks')end})end
})do
  local g=state();change(g);local p=capture(g)
  eq(p.counts.unknown,150,'unavailable or malformed complete table cannot impute150 missing stickers')
  check(p.eligibility.eligible~=true,'unavailable profile disables the objective')
end
for _,entry in ipairs({false,1,'bad',{}, {count=1,order=1,wins=false},row({['8']=1}),row({[8]=0}),
  row({[8]=-1}),row({[8]=0/0}),row({[8]=1.5}),row({[9]=1}),row({[1.5]=1}),
  {count=0,order=1,wins={}}, {count=1,order=0,wins={}}, {count=1,order=1,wins={},losses=false}
})do
  local g=state();g.PROFILES[1].joker_usage.j_joker=entry;local p=capture(g)
  eq(p.by_key.j_joker.status,'unknown','malformed per-Joker records never become a win or missing target')
  eq(p.counts.missing,149,'a single malformed record does not corrupt other confirmed absences')
  eq(p.counts.complete+p.counts.missing+p.counts.unknown,150,'all statuses conserve the vanilla population')
end
do
  local g=state();g.PROFILES[2]={joker_usage={j_joker=row({[8]=1})}}
  local before=capture(g);g.SETTINGS.profile=2;local after=capture(g)
  eq(before.profile_id,1,'first profile identity is retained in its detached result')
  eq(after.profile_id,2,'switching profiles changes the context identity immediately')
  eq(before.counts.complete,0,'old detached progress does not mutate after profile switch')
  eq(after.counts.complete,1,'new active profile supplies its own completion')
  g.SETTINGS.profile=3;eq(capture(g).counts.unknown,150,'unloaded profile never borrows another profile history')
end
for _,case in ipairs({
  {'challenge_run',function(g)g.GAME.challenge='c_jokerless_1'end},
  {'seeded_run',function(g)g.GAME.seeded=true end},
  {'not_gold_stake',function(g)g.GAME.stake=7 end},
  {'run_already_won',function(g)g.GAME.won=true end},
  {'past_winning_ante',function(g)g.GAME.round_resets.ante=9 end}
})do
  local g=state();case[2](g);local p=capture(g)
  eq(p.eligibility.status,'ineligible','known exclusion has an explicit status')
  eq(p.eligibility.eligible,false,'known exclusion preserves false rather than ambiguous nil')
  check(table.concat(p.eligibility.reasons,','):find(case[1],1,true),'eligibility explains the actual exclusion')
  eq(p.counts.missing,150,'run eligibility never rewrites collection history')
end
do
  local g=state();g.GAME.round_resets.ante=8;eq(capture(g).eligibility.eligible,true,'pre-win final Ante remains eligible')
  g.GAME=nil;eq(capture(g).eligibility.status,'unknown','missing active run is explicit')
  g=state();g.GAME.round_resets.ante=0/0;check(not capture(g).eligibility.eligible,'malformed progress disables the objective')
  g=state();g.GAME.won=0;eq(capture(g).eligibility.status,'unknown','a malformed win flag is not an observed completed run')
  g=state();g.GAME.seeded={};eq(capture(g).eligibility.status,'unknown','a malformed seed flag cannot establish ordinary eligibility')
  g=state();g.STAGE=1;eq(capture(g).eligibility.status,'ineligible','stale menu game fields do not establish an active run')
  eq(capture(g).counts.missing,150,'public collection progress remains readable outside a run')
  g=state();g.STAGES=nil;eq(capture(g).eligibility.status,'unknown','unavailable run-stage metadata remains unknown')
  g=state();g.STAGE=nil;eq(capture(g).eligibility.status,'unknown','a missing current stage cannot enable the objective')
end
for _,change in ipairs({
  function(g)g.P_STAKES=nil end,function(g)g.P_STAKES.stake_gold=nil end,
  function(g)g.P_STAKES.stake_gold.stake_level=7 end,function(g)g.P_STAKES.stake_gold.order=9 end,
  function(g)g.P_STAKES.stake_gold.mod={}end,
  function(g)g.P_STAKES.stake_extra={set='Stake',order=9,stake_level=9}end,
  function(g)g.P_CENTER_POOLS.Stake[8]={set='Stake',order=8,stake_level=8,key='stake_fake'}end,
  function(g)g.P_CENTER_POOLS.Stake[8]=nil end,function(g)g.sticker_map[8]='purple'end
})do
  local g=state();g.PROFILES[1].joker_usage.j_joker=row({[8]=1});change(g);local p=capture(g)
  eq(p.counts.unknown,150,'unverified or modified stake mapping cannot invent a Gold label')
  check(p.eligibility.eligible~=true,'unsupported stakes cannot enable the objective')
end
do
  local g=state();g.P_CENTER_POOLS=nil;g.sticker_map=nil
  eq(capture(g).stake_status,'complete','exact primary stake catalog suffices when optional mirrors are absent')
  g=state();g.P_CENTERS.j_joker=nil;local p=capture(g)
  eq(p.by_key.j_joker.status,'unknown','missing vanilla catalog center stays unknown')
  check(p.eligibility.eligible~=true,'incomplete vanilla catalog cannot enable strategy')
  g=state();g.P_CENTERS.j_joker.mod={};p=capture(g)
  eq(p.catalog_status,'unsupported','replaced vanilla center is labeled unsupported')
  eq(p.eligibility.status,'unsupported','modified vanilla targets cannot enable the objective')
  g=state();g.jokers.cards={[2]=held('j_joker')};eq(capture(g).held_status,'malformed','sparse held arrays do not claim complete cargo')
  eq(capture(g).eligibility.status,'unknown','malformed cargo cannot label the objective eligible')
  g=state();g.jokers=nil;eq(capture(g).held_status,'unavailable','missing owned area is not an observed empty area')
  eq(capture(g).eligibility.status,'unknown','missing owned area prevents complete objective eligibility')
end
do
  local g=state();local calls=0
  local function forbidden()calls=calls+1;error('A loaded-table reader must not invoke game/profile/save callbacks')end
  g.load_profile=forbidden;g.save_settings=forbidden;g.PROFILES[1].save=forbidden
  g.GAME.pseudorandom=setmetatable({},{__index=forbidden});g.GAME.hidden_seed='DO_NOT_EXPORT'
  g.jokers.cards[1]=setmetatable(held('j_joker'),{__index=forbidden})
  local before=Snapshot.fingerprint(g);local p=capture(g)
  eq(calls,0,'callbacks, hidden RNG and seed data are untouched')
  eq(p.held_target_count,1,'raw fields on ordinary card instances are supported')
  eq(Snapshot.fingerprint(g),before,'callback-bearing live tables remain unchanged')
  check(not Snapshot.fingerprint(p):find('DO_NOT_EXPORT',1,true),'public progress does not export hidden seed data')
  check(not Snapshot.fingerprint(p):find('private-name:',1,true),'public progress does not export undiscovered catalog metadata')
end
math.random,math.randomseed=old_random,old_seed
print('advisor_gold_stickers294: '..checks..' synthetic loaded-metadata checks passed')
