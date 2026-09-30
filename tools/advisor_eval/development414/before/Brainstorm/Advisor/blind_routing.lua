-- Bounded blind-route advice. Fixed composition samples establish a capacity
-- margin, not a calibrated probability. Unknown route transitions fail closed.
local M={}
local min,max,floor=math.min,math.max,math.floor
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function copy(x)
  if type(x)~='table' then return x end
  local y={};for k,v in pairs(x) do if type(v)~='function' and k~='_shop_scoring' then y[k]=copy(v) end end;return y
end
local function name(j) return (j.ability or {}).name or j.name or j.key end
local function active(j) local a=j.ability or {};return not a.perma_debuff and not (a.perishable and num(a.perish_tally)<=0) end
local names={tag_economy='Economy Tag',tag_handy='Handy Tag',tag_garbage='Garbage Tag',tag_skip='Skip Tag',
  tag_investment='Investment Tag',tag_double='Double Tag'}
local types={tag_economy='immediate',tag_handy='immediate',tag_garbage='immediate',tag_skip='immediate',
  tag_investment='eval',tag_double='tag_add'}
local startup={['Ceremonial Dagger']=true,Madness=true,Burglar=true,['Riff-raff']=true,Cartomancer=true,
  Certificate=true,['Marble Joker']=true,['Ancient Joker']=true,['The Idol']=true,['To Do List']=true,
  ['Gros Michel']=true,Cavendish=true,Popcorn=true,['Turtle Bean']=true}
for _,key in ipairs({'j_ceremonial','j_madness','j_burglar','j_riff_raff','j_cartomancer','j_certificate','j_marble',
  'j_ancient','j_idol','j_todo_list','j_gros_michel','j_cavendish','j_popcorn','j_turtle_bean'}) do startup[key]=true end
local hidden={bl_house=true,bl_wheel=true,bl_mark=true,bl_fish=true,bl_hook=true,bl_final_heart=true,bl_final_bell=true}
local function integer(v,low)
  return type(v)=='number' and v==v and v<math.huge and v%1==0 and v>=(low or 0)
end
-- A faster finish must still deliver a known missing Joker when this objective
-- is enabled. Reconcile the loaded public metadata with the physical held row;
-- an empty or stale cargo list does not justify giving up the final shop.
local function gold_cargo(s)
  local goal=s.completionist_goal
  if goal==nil then return true end
  if type(goal)~='table' or goal.schema~=1 or goal.goal~='gold_stickers' or
      goal.metadata_status~='complete' or goal.catalog_status~='complete' or goal.held_status~='complete' or
      type(goal.eligibility)~='table' or goal.eligibility.eligible~=true or type(goal.by_key)~='table' then
    return nil,'Keep the shop opportunity: complete eligible Gold-sticker metadata is required for a final-ante skip.'
  end
  local counts=type(goal.counts)=='table' and goal.counts or {}
  if counts.total~=150 or counts.unknown~=0 or not integer(counts.complete) or not integer(counts.missing) or
      counts.complete+counts.missing~=150 then return nil,'The Gold-sticker counts are incomplete.' end
  local missing,count={},0
  for _,j in ipairs(s.jokers or {}) do
    local row=goal.by_key[j.key]
    local status=type(row)=='table' and row.status
    if status~='missing' and status~='complete' then return nil,'A held Joker has unknown Gold-sticker status.' end
    if status=='missing' and not missing[j.key] then missing[j.key]=true;count=count+1 end
  end
  if count==0 then return nil,'Keep the shop opportunity: no known missing Gold-sticker Joker is held.' end
  if goal.held_target_count~=count or counts.missing<count or type(goal.held_target_keys)~='table' then
    return nil,'The Gold-sticker cargo metadata does not match the held row.'
  end
  local seen,total={},0
  for index,key in pairs(goal.held_target_keys) do
    if not integer(index,1) or index>count or not missing[key] or seen[key] then
      return nil,'The Gold-sticker cargo metadata does not match the held row.'
    end
    seen[key]=true;total=total+1
  end
  if total~=count then return nil,'The Gold-sticker cargo metadata does not match the held row.' end
  return count
end

-- Exact supported tag amounts, including source timing: skips increments
-- before Skip Tag pays, and copied Economy Tags compound sequentially.
function M.project_skip(s)
  local label=s.blind_on_deck
  local tag=(s.route_tags or {})[label]
  if not tag or not names[tag.key] or tag.name and tag.name~=names[tag.key] then return nil,'Skip tag changes are not supported.' end
  local config=tag.config or {};local repeats=1
  if config.type and config.type~=types[tag.key] then return nil,'The tag has nonstandard activation timing.' end
  for _,old in ipairs(s.active_tags or {}) do if not old.triggered then
    if (old.config or {}).type and old.config.type~=types[old.key] then return nil,'A pending tag has nonstandard activation timing.' end
    if old.key=='tag_double' and tag.key~='tag_double' then repeats=repeats+1
    elseif old.key~='tag_investment' and old.key~='tag_double' then return nil,'Pending tag changes are not projected.' end
  end end
  if repeats>20 then return nil,'Too many pending Double Tags for this bounded comparison.' end
  local out=copy(s);out.skips=num(s.skips)+1
  local meta={cash=0,deferred_cash=0,tag=tag.key,tag_copies=repeats,throwback_growth=0}
  for _=1,repeats do
    local cash=0
    if tag.key=='tag_economy' then cash=min(num(config.max,40),max(0,num(out.dollars)))
    elseif tag.key=='tag_handy' then cash=num(s.hands_played_total)*num(config.dollars_per_hand,1)
    elseif tag.key=='tag_garbage' then cash=num(s.unused_discards)*num(config.dollars_per_discard,1)
    elseif tag.key=='tag_skip' then cash=out.skips*num(config.skip_bonus,5)
    elseif tag.key=='tag_investment' then meta.deferred_cash=meta.deferred_cash+num(config.dollars,25) end
    meta.cash=meta.cash+cash;out.dollars=num(out.dollars)+cash
  end
  local tax=num((s.modifiers or {}).minus_hand_size_per_X_dollar)
  if tax>0 then return nil,'Skip cash can change the hand size; this route is not projected.' end
  for _,j in ipairs(out.jokers or {}) do if active(j) and (j.key=='j_throwback' or name(j)=='Throwback') then
    local a=j.ability or {};j.ability=a
    local previous=1+num(s.skips)*num(a.extra,0.25)
    a.x_mult=1+out.skips*num(a.extra,0.25)
    meta.throwback_growth=meta.throwback_growth+a.x_mult-previous
  end end
  out.blind_on_deck=label=='Small' and 'Big' or 'Boss'
  out.blind_states=out.blind_states or {};out.blind_states[label]='Skipped';out.blind_states[out.blind_on_deck]='Select'
  return out,meta
end

local function ordered_population(s)
  local cards=copy(s.playing_cards or {})
  table.sort(cards,function(a,b) return tostring(a.id or '')<tostring(b.id or '') end)
  return cards
end
local function fresh(s,definition,seed,shop,bell)
  local state=copy(s);state.phase='hand';state.chips=0
  state.hands_played=0;state.discards_used=0
  local rr,bonus=s.round_resets or {},s.round_bonus or {}
  state.hands_left=max(1,num(rr.hands,4)+num(bonus.next_hands))
  state.discards_left=max(0,num(rr.discards,3)+num(bonus.discards))
  state.current_round=copy(s.current_round or {})
  state.current_round.hands_left=state.hands_left;state.current_round.discards_left=state.discards_left
  state.current_round.hands_played=0;state.current_round.discards_used=0
  state.hand_size=num(s.hand_size,8);state.hand_limit=min(5,num(s.hand_limit,5))
  for _,h in pairs(state.hands or {}) do h.played_this_round=0 end
  state.playing_cards=ordered_population(s)
  for _,c in ipairs(state.playing_cards) do
    c.ability=c.ability or {};c.debuff=not not c.ability.perma_debuff;c.face_down=false
    c.ability.forced_selection=nil;c.ability.wheel_flipped=nil
  end
  for _,j in ipairs(state.jokers or {}) do
    j.debuff=not active(j)
    if name(j)=='Hit the Road' then j.ability.x_mult=1 end
  end
  state.next_blind=definition
  local supported,why=shop.next_blind(state)
  if not supported or hidden[definition.key] and not (definition.key=='bl_final_bell' and bell) then
    return nil,why or 'Upcoming concealed or random draw mechanics are unsupported.'
  end
  shop.apply_blind(state,supported)
  if state.hand_size<1 or state.hand_size>10 or #state.playing_cards<state.hand_size then return nil,'Not enough usable population for a complete bounded opening draw.' end
  local order={};for i=1,#state.playing_cards do order[i]=i end
  for i=#order,2,-1 do seed=(seed*1664525+1013904223)%4294967296;local j=seed%i+1;order[i],order[j]=order[j],order[i] end
  state.hand={};state.deck={}
  for i,index in ipairs(order) do
    local area=i<=state.hand_size and state.hand or state.deck;area[#area+1]=state.playing_cards[index]
  end
  return state
end

function M.suggest(s,modules,options)
  options=options or {};modules=modules or {}
  local diag={evaluations=0,max_evaluations=min(5000,max(0,floor(num(options.max_evaluations,5000)))),
    samples=4,outcome_branches=0,scope='fixed composition openings; no purchase assumed; no win probability',heuristic=true}
  local function no(reason) diag.reason=reason;return nil,diag end
  local label=s.blind_on_deck
  if s.phase~='blind' or (label~='Small' and label~='Big') or (s.blind_states or {})[label]~='Select' then return no('No current skippable blind.') end
  local scoring,shop=modules.scoring,modules.shop_scoring
  if not scoring or not scoring.after_play or not shop or not shop.apply_blind or not shop.next_blind or not shop.known_joker
    or not modules.finish_rewards then return no('Route scoring dependencies unavailable.') end
  local routes=s.route_blinds or {};local labels=label=='Small' and {'Big','Boss'} or {'Boss'}
  if not routes[label] or num(routes[label].chips)<=0 then return no('Current blind definition or target unavailable.') end
  for _,l in ipairs(labels) do if not routes[l] or num(routes[l].chips)<=0 then return no('Actual '..l..' route definition or target unavailable.') end end
  if #(s.playing_cards or {})<8 or #s.playing_cards>120 or #(s.jokers or {})>12 then return no('Population or Joker row is outside bounded route limits.') end
  local bell
  if routes.Boss.key=='bl_final_bell' then
    bell=modules.bell_opening
    if not bell or not bell.new or not bell.add or not bell.finish then return no('Complete Bell forced-card scoring is unavailable.') end
    if not integer(s.win_ante,1) or s.ante~=s.win_ante then return no('Bell routing requires the known winning ante.') end
    diag.bell_worlds={}
  end
  -- Every winning-ante shortcut gives up a remaining shop, regardless of the
  -- final boss's scoring mechanics. A completed engine alone is no collection
  -- progress; retain those opportunities until known missing cargo is held.
  if integer(s.win_ante,1) and s.ante==s.win_ante then
    local cargo,reason=gold_cargo(s);if not cargo then return no(reason) end
    diag.gold_cargo=type(cargo)=='number' and cargo or nil
  end
  for _,j in ipairs(s.jokers or {}) do if active(j) then
    local a=j.ability or {}
    if not shop.known_joker(j.key) then return no('Unknown Joker identity is outside route projection.') end
    if startup[name(j)] or startup[j.key] then return no(name(j)..' changes a blind boundary outside this route model.') end
    if a.perishable and num(a.perish_tally)<=#labels then return no('A route Joker can expire before the checked boss.') end
    if name(j)=='Seltzer' then return no('Seltzer expiry can change the route.') end
  end end
  local skipped,reward=M.project_skip(s);if not skipped then return no(reward) end
  diag.reward=reward
  local safety=max(bell and 2 or 1.5,num(options.margin,2))
  local function find(state)
    local chosen,best={},nil
    local collector
    if (state.blind or {}).key=='bl_final_bell' then
      local reason;collector,reason=bell.new(state)
      if not collector then return nil,reason end
    end
    local function walk(start,remaining)
      if remaining==0 then
        if diag.evaluations>=diag.max_evaluations then return false end
        diag.evaluations=diag.evaluations+1
        if options.yield_fn and diag.evaluations%64==0 then options.yield_fn() end
        local p=scoring.score(state,chosen)
        if collector then return bell.add(collector,chosen,p) end
        if p and p.legal~=false and not p.uncertain and num(p.score)>=num(state.blind.chips)*safety then
          p.indices={};for i,v in ipairs(chosen) do p.indices[i]=v end;best=p;return false
        end
        return true
      end
      for i=start,#state.hand-remaining+1 do chosen[#chosen+1]=i
        local continue=walk(i+1,remaining-1);chosen[#chosen]=nil
        if not continue then return false end
      end
      return true
    end
    for n=1,min(5,state.hand_limit,#state.hand) do if not walk(1,n) then break end end
    if collector then
      local receipt,worst=bell.finish(collector)
      if not receipt then return nil,worst end
      if receipt.minimum<num(state.blind.chips)*safety then return nil,'At least one forced Bell card lacks the required capacity margin.' end
      diag.bell_worlds[#diag.bell_worlds+1]=receipt
      return worst
    end
    return best
  end
  diag.minimum_capacity=math.huge;diag.checked_blinds={};diag.current_income=0;diag.glass_saved=0;diag.population_saved=0
  for _,seed in ipairs({977,1999,3253,4751}) do
    local current,why=fresh(s,routes[label],seed,shop,bell);if not current then return no(why) end
    local clear=find(current);if not clear then return no('Current blind lacks the required sampled capacity margin.') end
    local income=num(routes[label].dollars)
    local reward_state=modules.finish_rewards.prepare(current,modules.strategy)
    local _,r=modules.finish_rewards.value(current,clear,reward_state)
    local cash=num(current.dollars)-reward_state.rental
    local base_interest=not reward_state.no_interest and cash>=5 and
      reward_state.interest_amount*min(floor(cash/5),reward_state.interest_cap/5) or 0
    income=income+r.dollars+base_interest
    diag.current_income=diag.current_income+income/4
    local damaged={}
    if (s.modifiers or {}).debuff_played_cards then
      for _,i in ipairs(clear.scoring_indices or {}) do if not current.hand[i].debuff then damaged[i]=1 end end
    end
    for _,x in ipairs(clear.glass_exposure or {}) do
      diag.glass_saved=diag.glass_saved+x.probability/4;damaged[x.index]=max(damaged[x.index] or 0,x.probability)
    end
    for _,loss in pairs(damaged) do diag.population_saved=diag.population_saved+loss/4 end
    local branches={skipped}
    for step,l in ipairs(labels) do
      diag.checked_blinds[l]=true;local next_branches={}
      for _,branch in ipairs(branches) do
        local state,reason=fresh(branch,routes[l],seed+step*113,shop,bell);if not state then return no(reason) end
        local play,reason=find(state);if not play then return no(reason or 'The '..l..' route fails the required sampled capacity margin.') end
        diag.minimum_capacity=min(diag.minimum_capacity,play.score/state.blind.chips)
        if step<#labels then
          local random=0
          for _,x in ipairs(play.glass_exposure or {}) do if x.probability>0 and x.probability<1 then random=random+1 end end
          if random>1 then return no('Multiple stochastic Glass cards need a wider route outcome tree.') end
          for outcome=1,random>0 and 2 or 1 do
            if diag.evaluations>=diag.max_evaluations then return no('Route score budget exhausted.') end
            diag.evaluations=diag.evaluations+1 -- after_play performs one score internally
            local outcomes={};for _,x in ipairs(play.glass_exposure or {}) do outcomes[x.index]=outcome==2 or x.probability>=1 end
            local after,reason=scoring.after_play(state,play.indices,{glass_outcomes=outcomes})
            if not after then return no(reason) end
            diag.outcome_branches=diag.outcome_branches+1
            -- No extra cash, Joker growth from discards, or shop acquisition is
            -- required to pass the next sample. Playing-card effects/depletion
            -- and supported scored Joker growth come from the exact transition.
            after.hand_size=branch.hand_size;after.round_bonus={}
            for _,j in ipairs(after.jokers or {}) do
              if (j.ability or {}).perishable then j.ability.perish_tally=num(j.ability.perish_tally)-1 end
              if (j.ability or {}).rental then after.dollars=num(after.dollars)-num(s.rental_rate,3) end
            end
            next_branches[#next_branches+1]=after
          end
        end
      end
      branches=next_branches
    end
  end
  -- Explicit, uncalibrated opportunity costs. Cash/shops matter less near the
  -- final boss; no future engine value is needed after completing the challenge.
  local horizon=max(1,(num(s.win_ante,8)-num(s.ante,1))*3+#labels)
  local cash_weight=min(1,horizon/6)
  local growth,joker_income=0,0
  for _,j in ipairs(s.jokers or {}) do
    if (j.ability or {}).rental then joker_income=joker_income-num(s.rental_rate,3) end
    if active(j) then
    local n,a=name(j),j.ability or {};local ex=type(a.extra)=='table' and a.extra or {}
    if n=='Egg' then growth=growth+num(a.extra,3)
    elseif n=='Gift Card' then growth=growth+num(a.extra,1)*(#s.jokers+#(s.consumeables or {}))
    elseif n=='Burnt Joker' or n=='Yorick' then growth=growth+4
    elseif n=='Invisible Joker' then growth=growth+3 end
    if n=='Golden Joker' then joker_income=joker_income+num(a.extra,4)
    elseif n=='Rocket' then joker_income=joker_income+num(ex.dollars,1)
    elseif n=='Cloud 9' then joker_income=joker_income+num(a.extra,1)*num(a.nine_tally)
    elseif n=='Satellite' then
      if type(s.consumeable_usage)~='table' then return no('Satellite cashout needs captured distinct Planet usage.') end
      local used=0;for _,usage in pairs(s.consumeable_usage) do if usage.set=='Planet' then used=used+1 end end
      joker_income=joker_income+used*num(a.extra,1)
    elseif n=='Delayed Gratification' then joker_income=joker_income+num(a.extra,2)*num((s.round_resets or {}).discards,3) end
  end end
  if modules.strategy and modules.strategy.inventory_value then
    local _,inv=modules.strategy.inventory_value(s)
    if inv.effects>0 then growth=growth+max(0,inv.future/max(1,inv.events))/12 end
  end
  local shop_cost=6+max(0,3-#(s.jokers or {}))*2
  local usable=0;for _,c in ipairs(s.playing_cards) do if not (c.ability or {}).perma_debuff then usable=usable+1 end end
  local scarcity=min(8,52/max(8,usable))
  local attrition=diag.population_saved*scarcity*2
  local foregone=diag.current_income+joker_income+growth+shop_cost
  local received=reward.cash+reward.deferred_cash*0.65
  local saved_seconds=max(0,num(options.saved_seconds,30))
  local seconds_per_dollar=max(0,num(options.seconds_per_dollar,3))
  diag.foregone_income=diag.current_income+joker_income;diag.growth_cost=growth;diag.shop_cost=shop_cost
  diag.attrition_value=attrition;diag.saved_seconds=saved_seconds;diag.cash_weight=cash_weight
  diag.net_seconds=saved_seconds+seconds_per_dollar*(cash_weight*(received-foregone)+attrition)
  if diag.net_seconds<max(5,num(options.minimum_seconds,8)) then return no('Income, growth and shop opportunity outweigh this skip under the time heuristic.') end
  local result={title='Skip the '..label..' Blind',action={kind='skip_blind',blind=label},warnings={},
    lines={string.format('Four fixed deck samples clear every checked remaining blind with at least %.1fx score capacity; no intervening purchase is assumed.',diag.minimum_capacity),
      string.format('Skipping avoids a played round and shop, estimated at %.0f seconds. Forgone income $%.1f, shop opportunity and growth are included.',saved_seconds,diag.foregone_income),
      string.format('Tag value: $%.0f now%s. This is a bounded route heuristic, not a win-probability estimate.',reward.cash,
        reward.deferred_cash>0 and string.format(' and $%.0f after the boss',reward.deferred_cash) or '')},routing=diag}
  if bell then
    result.lines[#result.lines+1]='Every possible first-hand Bell forced card is covered in each checked composition world, using the current Joker order. These are sampled openings, not every possible draw.'
    if diag.gold_cargo then result.lines[#result.lines+1]='The held missing Gold-sticker Jokers are retained; the skipped shop opportunity and Perkeo copying cost remain included.' end
  end
  return result,diag
end

return M
