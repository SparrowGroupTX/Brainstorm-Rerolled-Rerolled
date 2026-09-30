-- Exact narrow disposal of a completed, expired rental. No hypothetical buy,
-- reroll outcome or draw is used; the removed card contributes no active effect.
local M={}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function plain(v)return type(v)=='table' and not getmetatable(v)end
local function dense(v,cap)
 if not plain(v) or #v>cap then return false end
 local n=0;for k in pairs(v)do if not finite(k) or k%1~=0 or k<1 or k>#v then return false end;n=n+1 end
 return n==#v
end
local function equal(a,b)
 local left=24000
 local function visit(x,y,depth)
  left=left-1
  if left<0 or depth>32 or type(x)~=type(y)then return false end
  if type(x)~='table'then return x==y end
  if not plain(x) or not plain(y)then return false end
  for k,v in pairs(x)do if not visit(v,y[k],depth+1)then return false end end
  for k in pairs(y)do if x[k]==nil then return false end end
  return true
 end
 return visit(a,b,0)
end
-- These effects depend on the played/held cards or their own counters. They
-- have no response to selling another Joker, its rarity, count or sell value.
-- Unknown/global-row, destruction, startup and sale-trigger effects decline.
local independent={}
for k in ([=[j_joker j_greedy_joker j_lusty_joker j_wrathful_joker j_gluttenous_joker
j_jolly j_zany j_mad j_crazy j_droll j_sly j_wily j_clever j_devious j_crafty
j_half j_four_fingers j_mime j_banner j_mystic_summit j_loyalty_card j_dusk
j_raised_fist j_fibonacci j_scary_face j_hack j_even_steven j_odd_todd j_scholar
j_supernova j_ride_the_bus j_blackboard j_runner j_splash j_blue_joker j_hiker
j_green_joker j_card_sharp j_red_card j_square j_shortcut j_hologram j_baron
j_obelisk j_photograph j_lucky_cat j_flash j_trousers j_walkie_talkie j_castle
j_smiley j_sock_and_buskin j_hanging_chad j_rough_gem j_arrowhead j_onyx_agate
j_glass j_flower_pot j_wee j_seeing_double j_duo j_trio j_family j_order j_tribe
j_drivers_license j_shoot_the_moon j_caino j_triboulet j_yorick
j_blueprint j_brainstorm j_perkeo j_burnt j_constellation j_steel_joker j_smeared]=]):gmatch('%S+')do independent[k]=true end
local function expired(c)
 local a=c.ability
 return a.perishable==true and finite(a.perish_tally) and a.perish_tally%1==0 and a.perish_tally<=0 and c.debuff==true
end
local function active(c)return not c.debuff and not c.ability.perma_debuff and not expired(c)end
local function edition_known(e)
 if e==nil then return true end
 if not plain(e)then return false end
 local selected,count=nil,0
 for _,k in ipairs({'foil','holo','polychrome','negative'})do if e[k]then selected=k;count=count+1 end end
 if count~=1 then return false end
 for k,v in pairs(e)do
  if ({foil=true,holo=true,polychrome=true,negative=true})[k]then if type(v)~='boolean'then return false end
  elseif k=='type'then if v~=selected then return false end
  elseif k=='chips' and selected=='foil' or k=='mult' and selected=='holo' or k=='x_mult' and selected=='polychrome'then
   if not finite(v) or v<0 then return false end
  else return false end
 end
 return true
end
local function row(s)
 if not dense(s.jokers,8) or s.ordering_safe==false or s.jokers_shuffling or (s.blind or {}).shuffle_pending then return nil end
 local ids={}
 for _,c in ipairs(s.jokers)do
  if not plain(c) or not plain(c.ability) or c.ability.set~='Joker' or not independent[c.key] or
   c.unknown or c.face_down or c.facing=='back' or c.identity_redacted or c.concealed or c.getting_sliced or
   not (type(c.id)=='string' and c.id~='' or finite(c.id)) or ids[tostring(c.id)] or
   type(c.debuff)~='boolean' or type(c.blueprint_compat)~='boolean' or
   not finite(c.sell_cost) or c.sell_cost<0 or not edition_known(c.edition) or c.debuff and not expired(c)then return nil end
  for _,k in ipairs({'eternal','rental','perishable','perma_debuff'})do
   if c.ability[k]~=nil and type(c.ability[k])~='boolean'then return nil end
  end
  if c.ability.perishable and (not finite(c.ability.perish_tally) or c.ability.perish_tally%1~=0)then return nil end
  ids[tostring(c.id)]=true
 end
 local function resolve(i,seen)
  local c=s.jokers[i];if not c or not active(c) or seen[i]then return false end
  seen[i]=true
  local next_i=c.key=='j_blueprint' and i+1 or c.key=='j_brainstorm' and 1
  if next_i then
   local target=s.jokers[next_i];if not target or not target.blueprint_compat then return false end
   return resolve(next_i,seen)
  end
  return c.id
 end
 local effects={}
 for i,c in ipairs(s.jokers)do if active(c)then effects[#effects+1]={source=c.id,target=resolve(i,{})}end end
 return effects
end
local tarot={c_magician=true,c_empress=true,c_heirophant=true,c_lovers=true,c_chariot=true,c_justice=true,
 c_hermit=true,c_strength=true,c_hanged_man=true,c_death=true,c_devil=true,c_tower=true,c_star=true,
 c_moon=true,c_sun=true,c_world=true,c_temperance=true,c_fool=true}
local planets={c_pluto=true,c_mercury=true,c_venus=true,c_earth=true,c_mars=true,c_jupiter=true,
 c_saturn=true,c_uranus=true,c_neptune=true,c_planet_x=true,c_ceres=true,c_eris=true,c_black_hole=true}
local function inventory(s,after)
 if not dense(s.consumeables,128) or not finite(s.consumable_limit) or s.consumeable_buffer~=0 or
  not equal(s.consumeables,after.consumeables)then return false end
 local temperance=false
 for _,c in ipairs(s.consumeables)do
  if not plain(c) or not plain(c.ability) or c.unknown or c.face_down or c.facing=='back' or
   not (tarot[c.key] and c.ability.set=='Tarot' or planets[c.key] and (c.ability.set=='Planet' or c.key=='c_black_hole' and c.ability.set=='Spectral'))then return false end
  -- Fool can create the last used card, whose sale-sensitive value is also
  -- retained. Unknown previous identities keep the whole-inventory safeguard.
  if c.key=='c_fool' and (not s.last_tarot_planet or not tarot[s.last_tarot_planet] and not planets[s.last_tarot_planet])then return false end
  if c.key=='c_fool' and s.last_tarot_planet=='c_temperance'then return false end -- no copied-cap receipt here
  if c.key=='c_temperance' and (c.ability.extra~=50 or not plain(c.ability.consumeable) or c.ability.consumeable.extra~=50)then return false end
  temperance=temperance or c.key=='c_temperance'
 end
 if temperance then
  local a,b=0,0;for _,c in ipairs(s.jokers)do a=a+c.sell_cost end;for _,c in ipairs(after.jokers)do b=b+c.sell_cost end
  if math.min(50,b)<math.min(50,a)then return false end
 end
 return true
end
function M.suggest(s,strategy)
 local d={schema=1,complete=false,evaluations=0,scope='Exact expired completed rental removal; supported independent active row and unchanged copy targets/inventory.'}
 local function no(reason)d.reason=reason;return nil,d end
 local g=s.completionist_goal;local api=strategy and strategy.shop_sequence_api
 if s.phase~='shop' or not api or type(api.after_joker_sale)~='function' or not plain(g) or g.schema~=1 or
  g.goal~='gold_stickers' or g.metadata_status~='complete' or g.held_status~='complete' or
  g.catalog_status~='complete' or not plain(g.eligibility) or g.eligibility.eligible~=true or not plain(g.by_key)then
  return no('Verified eligible collection metadata and a shop sale transition are required.')end
 if (s.modifiers or {}).all_eternal or not finite(s.rental_rate) or s.rental_rate<=0 or
  not finite(s.dollars) or not finite(s.bankrupt_at)then return no('Exact rental and cash metadata are required.')end
 local next_blind=s.next_blind or {}
 local boss=(s.blind_choices or {}).Boss or ((s.round_resets or {}).blind_choices or {}).Boss
 if type(boss)=='table'then boss=boss.key end
 local protected={bl_final_leaf=true,bl_final_acorn=true,bl_final_heart=true}
 if protected[next_blind.key] or protected[boss]then
  return no('Preserve the sacrifice or random Joker-selection row for this upcoming boss.')end
 local before_effects=row(s)
 if not before_effects then return no('The full public row contains unsupported, concealed or unsettled effects.')end
 for i,c in ipairs(s.jokers)do
  local status=g.by_key[c.key];local a=c.ability
  if expired(c) and a.rental==true and not a.eternal and not c.pinned and not a.pinned and
   not c.edition and plain(status) and status.status=='complete' then
   local after=api.after_joker_sale(s,i)
   local valid=after and after.dollars==s.dollars+c.sell_cost and after.dollars>=s.bankrupt_at and
    equal(before_effects,row(after)) and inventory(s,after)
   for _,field in ipairs({'playing_cards','hands','hand_size','hand_limit','round_resets','consumeable_buffer',
    'consumable_limit','joker_limit','bankrupt_at','probabilities','modifiers','used_vouchers','interest_cap','interest_amount'})do
    valid=valid and equal(s[field],after and after[field])
   end
   if valid then
    d.complete=true;d.sold_id=c.id;d.sold_key=c.key;d.rental_saved=s.rental_rate;d.sale_proceeds=c.sell_cost
    d.copy_targets_unchanged=true;d.inventory_unchanged=true;d.additional_score_calls=0
    d.reason='This already-Gold rental has expired permanently; removing it preserves all supported active effects and copy targets.'
    return {title='Sell expired '..(c.name or a.name or c.key)..' ($'..c.sell_cost..')',
     action={kind='sell',area='jokers',index=i},warnings={},retirement=d,
     lines={d.reason,'Free its ordinary slot and stop the $'..s.rental_rate..' per-round rent; then reassess the shop. No replacement is assumed.'}},d
   end
  end
 end
 return no('No standalone expired completed rental sale preserves the supported full row and inventory.')
end
return M
