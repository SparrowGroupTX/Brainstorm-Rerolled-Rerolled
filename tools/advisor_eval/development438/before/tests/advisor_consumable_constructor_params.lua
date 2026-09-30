-- Source-shaped manufactured Card/create_card/copy_card metadata only.
-- No original source function, player snapshot, game object or RNG is executed.
local H=dofile('Brainstorm/Advisor/gold_tarot_hold.lua')
local P=dofile('Brainstorm/Advisor/perkeo_inventory.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
S.gold_tarot_hold=H;S.perkeo_inventory=P
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function params(area,back)
  -- create_card's boolean/nil area conditions, including its actual back field.
  return {bypass_discovery_center=area=='shop' or area=='pack' or area=='owned',
    bypass_discovery_ui=(area=='shop' or area=='pack') or nil,
    discover=area=='owned',bypass_back=back}
end
local function raw(kind,id,area,back)
  local planet=kind=='Planet'
  local center={key=planet and 'c_mercury' or 'c_hermit',name=planet and 'Mercury' or 'The Hermit',
    set=kind,effect=planet and 'Hand Upgrade' or 'Dollar Doubler',order=planet and 2 or 10,cost=3,consumeable=true,
    config=planet and {hand_type='Pair'} or {extra=20}}
  local a={name=center.name,set=kind,effect=center.effect,order=center.order,type='',x_mult=1,
    extra=not planet and 20 or nil,extra_value=0,hands_played_at_create=7,consumeable=S.copy(center.config)}
  for _,key in ipairs({'mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips','h_size','d_size','bonus','perma_bonus'})do a[key]=0 end
  return {sort_id=id,config={center=center,card={}},params=params(area,back),
    base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0},ability=a,
    facing='front',sprite_facing='front',debuff=false,base_cost=3,cost=3,sell_cost=1}
end
local function copied(original,id)
  local c=S.copy(original);c.sort_id=id;c.params=original.params
  -- copy_card transfers the parameter table and absent playing identity.
  c.params.playing_card=nil;c.pinned=original.pinned
  -- Perkeo overwrites edition, then source pricing for the zero-discount case.
  c.edition={negative=true,type='negative'};c.cost=8;c.sell_cost=4
  return c
end
local function observe(c)
  G={P_CENTERS={[c.config.center.key]=c.config.center}}
  return S.card(c)
end
local function proof(c)
  local o=observe(c);return c.ability.set=='Tarot' and o.tarot_hold_source or o.copy_source,o
end
local function joker(key,id,name)
  return {key=key,id=id,name=name,ability={set='Joker',name=name},cost=5,sell_cost=2,
    debuff=false,pinned=false,face_down=false,blueprint_compat=true}
end
math.random=function()error('No RNG in constructor shape qualification')end;pseudorandom=math.random;pseudoseed=math.random
for _,kind in ipairs({'Tarot','Planet'})do
  for _,area in ipairs({'shop','pack','owned'})do
    for _,back in ipairs({{x=0,y=0},{x=4,y=1},false})do
      local position=back~=false and back or nil
      local c=raw(kind,1,area,position);local before=S.fingerprint(c);local p,o=proof(c)
      check(p and p.supported,'create_card shape with public back qualifies '..kind..'/'..area)
      eq(S.fingerprint(c),before,'capture preserves raw defaults and parameter table')
      eq(S.fingerprint(p.params),S.fingerprint(c.params),'complete original parameters are retained')
      eq(c.pinned,nil,'normal source Card:init pin stays absent')
      local new=copied(c,2);local q,n=proof(new)
      check(q and q.supported,'copied Negative shares the same qualified back parameters')
      eq(S.fingerprint(c),before,'copy capture does not mutate original shared parameters')
      eq(n.edition.type,'negative','Perkeo edition remains explicit')
      if kind=='Planet'then check(P.source_key(o) and P.source_key(n),'source validation accepts ordinary and copied Planet back params')end
    end
  end
end
do
  local s={phase='shop',jokers={joker('j_perkeo','p','Perkeo'),joker('j_brainstorm','b','Brainstorm')},
    consumeables={},consumeable_buffer=0,consumable_limit=16,dollars=170,ordering_safe=true,jokers_shuffling=false,playing_cards={},used_vouchers={}}
  local original=raw('Tarot',1,'shop',{x=4,y=1})
  for i=1,14 do s.consumeables[i]=observe(copied(original,i))end
  local before=S.fingerprint(s);local r,why=H.certify(s)
  check(r,why or 'full source-shaped Negative pool qualifies')
  eq(r.copy_events,2,'complete physical Perkeo/Brainstorm chain')
  eq(r.inventory_count_before,14,'all originals counted');eq(r.inventory_count_after,16,'future copies counted without choosing identities')
  eq(r.capacity_after,18,'Negative capacity conserved');eq(S.fingerprint(s),before,'whole current pool remains unchanged')
  s.consumeables={observe(raw('Planet',15,'owned',{x=1,y=2}))};s.consumable_limit=2
  s.shop_forecast={inflation=0,discount_percent=0}
  before=S.fingerprint(s);local after,receipt=P.project(s)
  check(after and receipt.supported,'homogeneous Planet projection accepts the same real create_card params')
  eq(#after.consumeables,3,'Planet path generates two exact symbolic Negative copies')
  eq(after.consumable_limit,4,'Planet path preserves Negative capacity')
  eq(S.fingerprint(s),before,'Planet source pool remains unchanged')
  for i=2,3 do eq(S.fingerprint(after.consumeables[i].copy_source.params.bypass_back),S.fingerprint({x=1,y=2}),'copied proof preserves cosmetic coordinates')end
end
for _,kind in ipairs({'Tarot','Planet'})do
  local invalid={false,true,0,'back',{},{x=0},{x=0,y=-1},{x=0.5,y=1},{x=0,y=1,z=0},
    {x=math.huge,y=0},setmetatable({x=0,y=0},{}),{x=0,y=function()end}}
  for i,back in ipairs(invalid)do
    local c=raw(kind,1,'owned',back);local p=proof(c)
    check(p and not p.supported,'malformed back metadata rejects '..kind..'/'..i)
    if kind=='Tarot'then eq(p.reason_code,'copy_parameters','parameter rejection is actionable without serializing raw params')end
  end
  local c=raw(kind,1,'owned',{x=0,y=0});c.params.playing_card=1
  check(not proof(c).supported,'physical playing identity remains rejected')
  c=raw(kind,1,'owned',{x=0,y=0});c.params.unmodeled=true
  check(not proof(c).supported,'unknown source parameter remains rejected')
  c=raw(kind,1,'owned',{x=0,y=0});c.params.viewed_back=true;c.params.bypass_lock=false
  check(proof(c).supported,'known Boolean Card:init display/lock parameters qualify')
  c.params.viewed_back='true';check(not proof(c).supported,'malformed known Boolean remains rejected')
end
do
  local cases={
    {'front_shape',function(c)c.config.card.id=2 end},
    {'base_shape',function(c)c.base.times_played=1 end},
    {'ability_shape',function(c)c.ability.h_size=1 end},
    {'physical_state',function(c)c.pinned=true end},
    {'price_shape',function(c)c.base_cost=4 end},
    {'edition_shape',function(c)c.edition={foil=true,type='foil',chips=50}end},
    {'center_shape',function(c)c.config.center.cost=4 end},
  }
  for _,case in ipairs(cases)do
    local c=raw('Tarot',1,'owned',{x=0,y=0});case[2](c);local p=proof(c)
    check(not p.supported,'invalid source shape remains unsupported');eq(p.reason_code,case[1],'stable diagnostic category')
  end
  local poison=setmetatable({},{__index=function()error('Hidden metadata accessed')end})
  local hidden={facing='back',config=poison,params=poison,ability=poison}
  local p=H.capture(hidden,poison);check(not p.supported and p.reason_code=='visibility','concealment still precedes all identity/parameter reads')
end
print('PASS source-shaped consumable parameters '..checks..' checks')
