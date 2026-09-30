-- A detached, bounded comparison of selling one Joker to disable a live boss.
-- Only a verified immediate clear is published; the live sale is a separate
-- explicit action and all subsequent advice must be recalculated.
local M={}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clone(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out
  for k,x in pairs(v) do if type(x)~='function' then out[k]=clone(x,seen) end end
  return out
end
local function list(v) local out={};for i,x in ipairs(v or {}) do out[i]=x end;return out end
local names={j_luchador='Luchador',j_egg='Egg',j_campfire='Campfire',j_invisible='Invisible Joker',j_diet_cola='Diet Cola',
  j_turtle_bean='Turtle Bean',j_troubadour='Troubadour',j_stuntman='Stuntman',j_oops='Oops! All 6s',
  j_credit_card='Credit Card',j_chaos='Chaos the Clown',j_to_the_moon='To the Moon',j_astronomer='Astronomer'}
local function name(c) return (c.ability or {}).name or c.name or names[c.key] or c.key end
local function inactive(c)
  local a=c.ability or {};return a.perma_debuff or a.perishable and num(a.perish_tally,5)<=0
end
local function negative(c) return c.edition=='negative' or type(c.edition)=='table' and c.edition.negative end
local bosses={bl_ox='The Ox',bl_hook='The Hook',bl_mouth='The Mouth',bl_fish='The Fish',bl_club='The Club',
  bl_manacle='The Manacle',bl_tooth='The Tooth',bl_wall='The Wall',bl_house='The House',bl_mark='The Mark',
  bl_final_bell='Cerulean Bell',bl_wheel='The Wheel',bl_arm='The Arm',bl_psychic='The Psychic',bl_goad='The Goad',
  bl_water='The Water',bl_eye='The Eye',bl_plant='The Plant',bl_needle='The Needle',bl_head='The Head',
  bl_final_leaf='Verdant Leaf',bl_final_vessel='Violet Vessel',bl_window='The Window',bl_serpent='The Serpent',
  bl_pillar='The Pillar',bl_flint='The Flint',bl_final_acorn='Amber Acorn',bl_final_heart='Crimson Heart'}
local vanilla={}
for key in ([=[j_joker j_greedy_joker j_lusty_joker j_wrathful_joker j_gluttenous_joker j_jolly j_zany j_mad j_crazy j_droll
j_sly j_wily j_clever j_devious j_crafty j_half j_stencil j_four_fingers j_mime j_credit_card j_ceremonial j_banner
j_mystic_summit j_marble j_loyalty_card j_8_ball j_misprint j_dusk j_raised_fist j_chaos j_fibonacci j_steel_joker
j_scary_face j_abstract j_delayed_grat j_hack j_pareidolia j_gros_michel j_even_steven j_odd_todd j_scholar j_business
j_supernova j_ride_the_bus j_space j_egg j_burglar j_blackboard j_runner j_ice_cream j_dna j_splash j_blue_joker
j_sixth_sense j_constellation j_hiker j_faceless j_green_joker j_superposition j_todo_list j_cavendish j_card_sharp
j_red_card j_madness j_square j_seance j_riff_raff j_vampire j_shortcut j_hologram j_vagabond j_baron j_cloud_9
j_rocket j_obelisk j_midas_mask j_luchador j_photograph j_gift j_turtle_bean j_erosion j_reserved_parking j_mail
j_to_the_moon j_hallucination j_fortune_teller j_juggler j_drunkard j_stone j_golden j_lucky_cat j_baseball j_bull
j_diet_cola j_trading j_flash j_popcorn j_trousers j_ancient j_ramen j_walkie_talkie j_selzer j_castle j_smiley
j_campfire j_ticket j_mr_bones j_acrobat j_sock_and_buskin j_swashbuckler j_troubadour j_certificate j_smeared
j_hanging_chad j_rough_gem j_bloodstone j_arrowhead j_onyx_agate j_glass j_ring_master j_flower_pot
j_blueprint j_wee j_merry_andy j_oops j_idol j_seeing_double j_matador j_hit_the_road j_duo j_trio j_family j_order
j_tribe j_stuntman j_invisible j_brainstorm j_satellite j_shoot_the_moon j_drivers_license j_cartomancer
j_astronomer j_burnt j_bootstraps j_caino j_triboulet j_yorick j_chicot j_perkeo j_throwback]=]):gmatch('%S+') do vanilla[key]=true end
local function boss_name(b)
  if b.key then return bosses[b.key] and (not b.name or b.name==bosses[b.key]) and bosses[b.key] end
  for _,n in pairs(bosses) do if b.name==n then return n end end
end
local function resources(s,c,direction)
  local a=c.ability or {};local extra=type(a.extra)=='table' and a.extra or {};local n=name(c)
  local delta=direction*num(a.h_size)
  if n=='Turtle Bean' or n=='Troubadour' then delta=delta+direction*num(extra.h_size) end
  if n=='Stuntman' then delta=delta-direction*num(extra.h_size,2) end
  if delta>0 and #(s.deck or {})>0 then return nil,'Selling or reactivating this Joker draws and sorts unknown cards.' end
  s.hand_size=num(s.hand_size,8)+delta
  local discards=direction*math.max(0,num(a.d_size))
  s.discards_left=num(s.discards_left)+discards;s.current_round.discards_left=s.discards_left
  s.round_resets.discards=num(s.round_resets.discards,3)+discards
  if n=='Troubadour' then s.round_resets.hands=num(s.round_resets.hands,4)+direction*num(extra.h_plays,-1) end
  if n=='Oops! All 6s' then
    for key,value in pairs(s.probabilities) do s.probabilities[key]=value*(direction==1 and 2 or 0.5) end
  elseif n=='Credit Card' then s.bankrupt_at=num(s.bankrupt_at)-direction*num(a.extra,20)
  elseif n=='Chaos the Clown' then s.current_round.free_rerolls=num(s.current_round.free_rerolls)+direction
  elseif n=='To the Moon' then s.interest_amount=num(s.interest_amount,1)+direction*num(a.extra,1) end
  return true
end

-- Exported for detached regression checks. No live sale or RNG is performed.
function M.project(snapshot,index)
  local b=snapshot.blind or {};local bn=boss_name(b)
  if snapshot.phase~='hand' or b.disabled or not b.boss or not bn then return nil,'No supported active boss is being played.' end
  if not finite(b.chips) or b.chips<=0 then return nil,'The active boss target is unavailable.' end
  if not finite(index) or index%1~=0 or index<1 then return nil,'The Joker index is invalid.' end
  local sold=(snapshot.jokers or {})[index]
  if not sold or (sold.ability or {}).eternal or (snapshot.modifiers or {}).all_eternal then return nil,'This Joker cannot legally be sold.' end
  local luchador=name(sold)=='Luchador' and not sold.debuff and not inactive(sold)
  if not luchador and bn~='Verdant Leaf' then return nil,'This sale does not disable the boss.' end
  if not finite(sold.sell_cost) or sold.sell_cost<0 then return nil,'The Joker sale price is unavailable.' end
  for _,j in ipairs(snapshot.jokers or {}) do
    if not vanilla[j.key] then return nil,'Unknown Joker sale or disable callbacks are not modeled.' end
  end
  if name(sold)=='Invisible Joker' or name(sold)=='Diet Cola' then return nil,'This Joker has an additional sale effect outside the rescue model.' end
  local s=clone(snapshot)
  s.current_round=s.current_round or {};s.round_resets=s.round_resets or {}
  s.hand_size=num(s.hand_size,8)
  s.probabilities=s.probabilities or {normal=1};s.blind.disabled=true;s.blind.block_play=false
  local function set_counter(field,amount)
    s[field]=num(s[field])+amount;s.current_round[field]=s[field]
  end
  if bn=='The Water' then
    if not finite(b.discards_sub) or b.discards_sub<0 then return nil,'The Water discard-restoration count is unavailable.' end
    set_counter('discards_left',b.discards_sub)
  elseif bn=='The Needle' then
    if not finite(b.hands_sub) or b.hands_sub<0 then return nil,'The Needle hand-restoration count is unavailable.' end
    set_counter('hands_left',b.hands_sub)
  elseif bn=='The Wall' then s.blind.chips=b.chips/2
  elseif bn=='Violet Vessel' then s.blind.chips=b.chips/3
  elseif bn=='The Manacle' then
    if #(s.deck or {})>0 then return nil,'Disabling Manacle draws and sorts unknown cards; no exact current-hand rescue is claimed.' end
    s.hand_size=num(s.hand_size,8)+1
  end
  local reveals=bn=='The Wheel' or bn=='The House' or bn=='The Mark' or bn=='The Fish'
  for _,field in ipairs({'hand','deck','playing_cards'}) do for _,c in ipairs(s[field] or {}) do
    c.ability=c.ability or {};c.debuff=not not inactive(c)
    if bn=='Cerulean Bell' then c.ability.forced_selection=nil end
    if reveals then c.ability.wheel_flipped=nil;if field=='hand' then c.face_down=false;c.facing='front' end end
  end end
  -- Luchador disables synchronously in selling_self. Other Leaf sales disable
  -- after the selling_card callback, so a previously debuffed Campfire does
  -- not gain a stack from that delayed Leaf sale.
  for i,j in ipairs(s.jokers) do
    local was_debuffed=j.debuff
    j.debuff=not not inactive(j);j.face_down=false;j.facing='front'
    if i~=index then
      if was_debuffed and not j.debuff then
        local ok,reason=resources(s,j,1);if not ok then return nil,reason end
      end
      local active_for_sale=not inactive(j) and (luchador and not j.debuff or not luchador and not was_debuffed)
      if active_for_sale and name(j)=='Campfire' then
        j.ability.x_mult=num(j.ability.x_mult,1)+num(j.ability.extra,0.25)
      end
    end
  end
  if not sold.debuff and not inactive(sold) then
    local ok,reason=resources(s,sold,-1);if not ok then return nil,reason end
  end
  table.remove(s.jokers,index)
  if negative(sold) then s.joker_limit=num(s.joker_limit,5)-1 end
  -- Card:update refreshes these row-derived caches after a live sale. In
  -- particular Swashbuckler must lose the sold Joker's resale contribution,
  -- and Stencil must use its new space count before the scorer's XMult path.
  local resale,stencils=0,0
  for _,j in ipairs(s.jokers) do
    resale=resale+num(j.sell_cost)
    if j.key=='j_stencil' then stencils=stencils+1 end
  end
  for _,j in ipairs(s.jokers) do
    j.ability=j.ability or {}
    if j.key=='j_swashbuckler' then j.ability.mult=resale-num(j.sell_cost) end
    if j.key=='j_stencil' then j.ability.x_mult=math.max(1,num(s.joker_limit,5)-#s.jokers+stencils) end
  end
  local before=num(s.dollars);s.dollars=before+sold.sell_cost
  local tax=num((s.modifiers or {}).minus_hand_size_per_X_dollar)
  if tax>0 then s.hand_size=num(s.hand_size,8)+math.floor(before/tax)-math.floor(s.dollars/tax) end
  if num(s.hand_size,8)<1 then return nil,'This sale leaves no hand capacity for the continuation.' end
  return s,{sold_name=name(sold),index=index,cash_gain=sold.sell_cost,
    clears_on_sale=num(s.chips)>=num(s.blind.chips),remaining=math.max(0,num(s.blind.chips)-num(s.chips)),
    hands_gain=num(s.hands_left)-num(snapshot.hands_left),discards_gain=num(s.discards_left)-num(snapshot.discards_left),
    hand_size_delta=num(s.hand_size,8)-num(snapshot.hand_size,8)}
end

local function combinations(n,limit,visit)
  local selected={}
  local function walk(start)
    if #selected>0 then visit(selected) end
    if #selected==limit then return end
    for i=start,n do selected[#selected+1]=i;walk(i+1);selected[#selected]=nil end
  end
  walk(1)
end
function M.suggest(snapshot,scorer,result,yield_fn,options)
  local s,base=snapshot or {},result or {};options=options or {}
  local diagnostics={evaluations=0,evaluated_sales=0,partial_comparisons=0,truncated=false,warnings={}}
  local warned={}
  local function warn(reason) if not warned[reason] then warned[reason]=true;diagnostics.warnings[#diagnostics.warnings+1]=reason end end
  local function skip(reason) diagnostics.reason=reason;return nil,diagnostics.evaluations,diagnostics end
  local b=s.blind or {};local bn=boss_name(b)
  if s.phase~='hand' or not b.boss or b.disabled or not bn then return skip('No supported active boss needs disabling.') end
  if not finite(b.chips) or b.chips<=0 then return skip('The active boss target is unavailable.') end
  if not scorer or type(scorer.score)~='function' then return skip('The scoring model is unavailable.') end
  local remaining=math.max(0,num(b.chips)-num(s.chips))
  local protected={base.play,base.ordering and base.ordering.play,base.hand_ordering and base.hand_ordering.play,
    base.consumable and (base.consumable.sequence and base.consumable.sequence.play or base.consumable.play)}
  for _,play in pairs(protected) do
    if play and play.legal~=false and not play.uncertain and num(play.score)>=remaining then
      return skip('An existing play, consumable, or ordering plan already clears; keep the Joker.')
    end
  end
  if base.kind=='discard' and base.discard and num(base.discard.probability)>=0.98 then
    return skip('The high-confidence discard plan preserves the Joker.')
  end
  local n=#(s.hand or {});local limit=math.min(5,num(s.hand_limit,5))
  if n<1 or n>20 or limit<1 then return skip('The held-card count is outside this bounded rescue comparison.') end
  local cost,term=0,1;for i=1,math.min(n,limit) do term=term*(n-i+1)/i;cost=cost+term end
  diagnostics.subsets=cost
  local budget=math.max(0,math.min(10000,math.floor(num(options.max_evaluations,10000))))
  if budget<2*cost then diagnostics.truncated=true;return skip('The budget cannot finish the baseline and one full sale comparison.') end
  local candidates={}
  for index,sold in ipairs(s.jokers or {}) do
    if not (sold.ability or {}).eternal and (bn=='Verdant Leaf' or name(sold)=='Luchador' and not sold.debuff) then
      local projected,meta=M.project(s,index)
      if projected then candidates[#candidates+1]={index=index,sold=sold,state=projected,meta=meta} else warn(meta) end
    end
  end
  if #candidates==0 then return skip('No supported legal sale can disable this boss.') end
  local function priority(c)
    return (negative(c.sold) and 10 or 0)+(inactive(c.sold) and 0 or name(c.sold)=='Luchador' and 0 or name(c.sold)=='Egg' and 1 or 2)
  end
  table.sort(candidates,function(a,c)
    if priority(a)~=priority(c) then return priority(a)<priority(c) end
    return a.index<c.index
  end)
  local function best_play(state)
    local best;local needed=math.max(0,num(state.blind.chips)-num(state.chips))
    combinations(n,limit,function(indices)
      local play=scorer.score(state,indices)
      diagnostics.evaluations=diagnostics.evaluations+1
      if yield_fn and diagnostics.evaluations%32==0 then yield_fn(diagnostics.evaluations) end
      if play and play.legal~=false and finite(play.score) and not play.uncertain then
        if not best or (play.score>=needed and best.score<needed) or
          (play.score>=needed and best.score>=needed and #indices<#best.indices) or
          (play.score<needed and best.score<needed and play.score>best.score) then
          best=clone(play);best.indices=list(indices)
        end
      elseif play and play.uncertain then
        diagnostics.uncertain_scores=(diagnostics.uncertain_scores or 0)+1
      end
    end)
    return best
  end
  local baseline=best_play(s)
  if baseline and baseline.score>=remaining then return skip('A fully rescored current play clears without selling a Joker.') end
  local best
  for _,candidate in ipairs(candidates) do
    if diagnostics.evaluations+cost>budget then diagnostics.truncated=true;break end
    candidate.play=best_play(candidate.state);diagnostics.evaluated_sales=diagnostics.evaluated_sales+1
    if candidate.meta.clears_on_sale or num(candidate.state.hands_left)>0 and candidate.play and candidate.play.score>=candidate.meta.remaining then
      if not best or priority(candidate)<priority(best) or
        (priority(candidate)==priority(best) and candidate.state.hand_size>best.state.hand_size) or
        (priority(candidate)==priority(best) and candidate.state.hand_size==best.state.hand_size and candidate.state.dollars>best.state.dollars) then best=candidate end
    end
  end
  if diagnostics.truncated then warn('Joker sales were shortlisted by the shared budget; every reported hand comparison finished.') end
  if not best then return skip('No completely evaluated sale provides a deterministic immediate clear.') end
  local meta=best.meta
  local lines={'Sell Joker #'..best.index..' ('..meta.sold_name..') to disable '..bn..'.',
    'The comparison removes that Joker, adds $'..tostring(meta.cash_gain)..', and updates the surviving Joker effects.'}
  if meta.clears_on_sale then
    lines[#lines+1]='The lowered target is already covered by the chips scored this blind; no additional play is needed.'
  else
    lines[#lines+1]='After the sale, '..best.play.hand..' estimates '..tostring(best.play.score)..' chips against '..tostring(meta.remaining)..' remaining.'
  end
  if meta.hands_gain>0 or meta.discards_gain>0 then
    lines[#lines+1]='Disabling restores '..meta.hands_gain..' hands and '..meta.discards_gain..' discards.'
  end
  lines[#lines+1]='Recalculate after selling before selecting or playing any cards.'
  local warnings=list(diagnostics.warnings)
  warnings[#warnings+1]='This verifies an immediate boss clear, not later draws or the cost of losing this Joker in future rounds.'
  diagnostics.reason='A legal boss-disable sale produces a verified immediate clear.'
  return {title='Sell '..meta.sold_name..' to disable '..bn,lines=lines,warnings=warnings,
    action={kind='sell',area='jokers',index=best.index},play=best.play,baseline_play=baseline,
    projected_blind=clone(best.state.blind),rescue=meta},diagnostics.evaluations,diagnostics
end

return M
