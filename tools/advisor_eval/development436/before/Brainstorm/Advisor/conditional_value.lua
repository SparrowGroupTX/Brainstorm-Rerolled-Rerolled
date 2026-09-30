-- Trigger and cash timing for detached shop/pack valuations. These are bounded
-- strategic utilities, never survival probabilities or a simulation of future
-- shops. Immediate scoring, legal purchases, and stickers remain the caller's
-- responsibility. Unknown opportunities are named instead of invented.
local M={}
local min,max,floor=math.min,math.max,math.floor
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function ability(c) return type(c.ability)=='table' and c.ability or {} end
local function active(c) local a=ability(c);return not c.debuff and not a.perma_debuff and not (a.perishable and num(a.perish_tally,5)<=0) end
local function has(s,key)
  for _,c in ipairs(s.jokers or {}) do if c.key==key and active(c) then return true end end
  return false
end
local function owned(s,card)
  for _,c in ipairs(s.jokers or {}) do if c==card or card.id and c.id==card.id then return true end end
  return false
end
local function interest(s,cash,no_interest)
  if no_interest or (s.modifiers or {}).no_interest or cash<5 then return 0 end
  return num(s.interest_amount,1)*min(floor(cash/5),num(s.interest_cap,25)/5)
end
local function horizon(s)
  local next_blind=s.next_blind or {}
  local ante=num(next_blind.ante,num(s.ante,1))
  -- Cash received after the final boss cannot finance another challenge blind.
  local left=(num(s.win_ante,8)-ante)*3
  if next_blind.key=='bl_small' then left=left+2
  elseif next_blind.key=='bl_big' then left=left+1
  elseif not next_blind.boss and not next_blind.key then left=left+1 end
  return max(0,min(3,left))
end
local income={j_golden=true,j_rocket=true,j_cloud_9=true,j_satellite=true,
  j_delayed_grat=true,j_to_the_moon=true}
local resale={j_egg=true,j_gift=true}
local growth={j_trousers=true,j_runner=true,j_square=true,j_green_joker=true,
  j_constellation=true,j_hologram=true,j_red_card=true}
local conditional_income={
  j_business='Face cards must actually score; random successful payouts are not projected.',
  j_faceless='A legal discard must contain enough face cards; changing the scoring plan for that discard is not free.',
  j_todo_list='The required hand must actually be played; the next round can change that target.',
  j_reserved_parking='Face cards must remain held during scoring; random payouts and future holdings are not projected.',
  j_mail='The next-round mail rank and legal matching discards are not established by the previous round target.',
  j_rough_gem='Diamonds must actually score; deck membership alone is not a payout.',
  j_ticket='Gold cards must actually score; owning them alone is not a payout.',
  j_trading='The first discard must legally destroy exactly one card; discard cost and the retained finish need their own comparison.',
}
local growth_hands={j_trousers={['Two Pair']=true,['Full House']=true,['Flush House']=true},
  j_runner={Straight=true,['Straight Flush']=true}}
local known_hands={['High Card']=true,Pair=true,['Two Pair']=true,['Three of a Kind']=true,
  Straight=true,Flush=true,['Full House']=true,['Four of a Kind']=true,['Straight Flush']=true,
  ['Five of a Kind']=true,['Flush House']=true,['Flush Five']=true}
local function opening_trigger(key,label,size)
  if type(size)~='number' or size<1 or size>5 then return nil end
  if key=='j_square' then return size==4 end
  if key=='j_green_joker' then return true end
  if not growth_hands[key] or not known_hands[label] then return nil end
  if growth_hands[key][label] then return true end
  -- A Flush can contain Two Pair in a modified deck. The winning label alone
  -- cannot settle that embedded hand, so do not invent a trigger conflict.
  if key=='j_trousers' and label=='Flush' and size>=4 then return nil end
  return false
end

local function clearing_growth_opportunities(key,r,out)
  local n=num(r.samples)
  if not r.supported or r.status~='unresolved' or r.hands~=1 or n<1 or n~=floor(n) or
      type(r.opening_scores)~='table' or #r.opening_scores~=n or
      type(r.opening_hands)~='table' or #r.opening_hands~=n or
      type(r.opening_sizes)~='table' or #r.opening_sizes~=n or num(r.target)<=0 then return end
  local clears,matches,conflicts,unknown=0,0,0,0
  for i=1,n do
    local score=r.opening_scores[i]
    if type(score)~='number' then return end
    if score>=r.target then
      clears=clears+1
      local trigger=opening_trigger(key,r.opening_hands[i],r.opening_sizes[i])
      if trigger==true then matches=matches+1
      elseif trigger==false then conflicts=conflicts+1
      else unknown=unknown+1 end
    end
  end
  if clears~=r.clearing_samples or clears==0 or clears==n then return end
  out.clearing_trigger_samples=matches;out.clearing_trigger_conflicts=conflicts
  out.clearing_trigger_unknown=unknown;out.clearing_samples=clears
  out.one_hand_trigger_conflict=conflicts>0
  out.timely_opportunities=matches/clears
  -- Only the observed clearing plays matter to this conflict. Matching a weak
  -- nonclearing sample does not establish a spare safe turn to farm growth.
  return conflicts/clears
end

local function resources(s,r)
  local resets=s.round_resets or {};local bonus=(s.shop_forecast or {}).round_bonus or {}
  local hands=num(r.hands,num(resets.hands,4)+num(bonus.next_hands))
  local discards=num(r.discards,num(resets.discards,3)+num(bonus.discards))
  local blind=s.next_blind or {};local chicot=has(s,'j_chicot')
  if blind.key=='bl_water' and not chicot or has(s,'j_burglar') then discards=0 end
  if blind.key=='bl_needle' and not chicot then hands=1 end
  return max(0,hands),max(0,discards)
end

local function payout(s,card,r,out)
  local key,a=card.key,ability(card);local e=type(a.extra)=='table' and a.extra or {}
  if key=='j_golden' then out.opportunities=1;return num(a.extra,4)
  elseif key=='j_rocket' then
    out.opportunities=1
    return num(e.dollars,1)+((s.next_blind or {}).boss and num(e.increase,2) or 0)
  elseif key=='j_cloud_9' then
    local cards=s.playing_cards
    if type(cards)~='table' then out.supported=false;out.unknown='Complete owned deck unavailable for Cloud 9.';return 0 end
    local nines=0
    for _,c in ipairs(cards) do
      -- Card:get_id returns no rank for Stone, even if its original base is 9.
      local a=ability(c);local stone=c.enhancement=='m_stone' or c.enhancement=='Stone Card' or a.effect=='Stone Card'
      if not stone and num(c.rank,num((c.base or {}).id))==9 then nines=nines+1 end
    end
    out.opportunities=nines;return nines*num(a.extra,1)
  elseif key=='j_satellite' then
    if type(s.consumeable_usage)~='table' then
      out.supported=false;out.unknown='Distinct used Planet metadata unavailable for Satellite.';return 0
    end
    local planets=0
    for _,v in pairs(s.consumeable_usage) do if type(v)=='table' and v.set=='Planet' then planets=planets+1 end end
    out.opportunities=planets;return planets*num(a.extra,1)
  elseif key=='j_to_the_moon' then
    out.timing='interest_after_clear'
    if out.no_interest then out.opportunities=0;return 0 end
    local other_rent=0
    for _,j in ipairs(s.jokers or {}) do
      if j~=card and not (card.id and j.id==card.id) and ability(j).rental then
        other_rent=other_rent+num(s.rental_rate,3)
      end
    end
    out.other_rental_before_interest=other_rent
    local cash=max(0,num(s.dollars)-out.purchase_cost-out.rental-other_rent)
    if out.liquidity then
      cash=max(0,out.liquidity.cash_after_reserved_costs)
      out.interest_cash_basis='after_conservative_reserved_costs'
      out.trigger_note='Interest uses cash after the shared rental and paid-discard reserve; this conservative budget is not a predicted discard count.'
    end
    out.opportunities=min(floor(cash/5),num(s.interest_cap,25)/5)
    -- Do not credit same-round cashout income toward the interest threshold.
    return out.opportunities*num(a.extra,1)
  elseif key=='j_delayed_grat' then
    local _,discards=resources(s,r);out.opportunities=discards
    out.trigger='No discards used and at least one discard retained at cashout.'
    if s.teacher_profile=='perkeo_yorick_win_v1' then
      out.trigger_weight=0;out.discard_conflict=true
      out.trigger_note='This strategy spends discards to develop the run; a safe opening score does not establish a no-discard payout.'
    elseif discards<=0 then out.trigger_weight=0;out.trigger_note='The next blind supplies no retained-discard payout.'
    elseif r.status=='sampled_safe' and r.supported then
      out.trigger_weight=1
      out.trigger_note='All supported opening samples clear with margin; retaining discards is a credible plan.'
    elseif r.status=='sampled_deficit' and r.supported then
      out.trigger_weight=0;out.discard_conflict=true
      out.trigger_note='The sampled scoring deficit gives no credible no-discard clear; no payout is budgeted. This does not prove a discard is necessary.'
    else
      out.trigger_weight=0.25
      out.trigger_note='No verified no-discard route is available; a conservative quarter of the conditional payout is used only as heuristic utility.'
    end
    return discards*num(a.extra,2)
  end
end

local function growth_value(s,card,r,out,base)
  local key,a=card.key,ability(card);local e=type(a.extra)=='table' and a.extra or {}
  out.kind='scoring_growth';out.timing='trigger_dependent';out.opportunities=0
  out.cash_end_round=0;out.net_cash=0;out.adjustment=0
  local maturity=0
  if key=='j_square' or key=='j_runner' then maturity=num(e.chips)/60
  elseif key=='j_hologram' or key=='j_constellation' then maturity=(num(a.x_mult,1)-1)/0.5
  else maturity=num(a.mult)/8 end
  out.current_maturity=max(0,min(1,maturity))
  if key=='j_constellation' then
    for _,c in ipairs(s.consumeables or {}) do
      if ability(c).set=='Planet' or type(ability(c).consumeable)=='table' and ability(c).consumeable.hand_type then
        out.opportunities=out.opportunities+1
      end
    end
    out.trigger='Using an already owned Planet can grow it before the blind; using that inventory still needs its own legal comparison.'
  elseif key=='j_hologram' then
    out.opportunities=(has(s,'j_marble') and 1 or 0)+(has(s,'j_certificate') and 1 or 0)
    out.trigger='Owned start-of-blind card generators are opportunities; DNA needs a legal first one-card play.'
    out.dna_opportunity=has(s,'j_dna')
  elseif key=='j_red_card' then
    out.trigger='A later paid pack skip is required; unseen future packs are not credited.'
  else
    local matches,unknown=0,0
    for i,label in ipairs(r.opening_hands or {}) do
      local trigger=opening_trigger(key,label,(r.opening_sizes or {})[i])
      if trigger==true then matches=matches+1 elseif trigger==nil then unknown=unknown+1 end
    end
    out.opening_trigger_samples=matches;out.opening_trigger_unknown_samples=unknown
    out.opportunities=matches/max(1,num(r.samples,4))
    out.trigger=key=='j_square' and 'Grows only when exactly four cards are played.' or
      key=='j_green_joker' and 'Grows before each play; spending discards removes Mult.' or
      'Only matching played hands grow it; future matching plays are not assumed.'
  end
  -- Existing tactical scoring already includes the first supported before-score
  -- trigger. Do not promise several additional plays to rescue an unscaled row.
  if r.supported and r.status=='sampled_deficit' then
    out.adjustment=-min(30,max(0,base)*0.55)*(1-out.current_maturity)
    if out.opportunities>0 and (key=='j_constellation' or key=='j_hologram') then
      out.adjustment=out.adjustment*0.5
    end
    out.reason=out.trigger..' The next-blind sampled deficit discounts growth that has not yet produced scoring.'
  else
    local conflict=clearing_growth_opportunities(key,r,out)
    if conflict and conflict>0 then
      out.adjustment=-min(30,max(0,base)*0.55)*(1-out.current_maturity)*conflict
      out.reason=out.trigger..' With one playable hand, '..out.clearing_trigger_conflicts..' of '..out.clearing_samples..
        ' sampled clearing plays do not trigger this growth. Unscaled investment is discounted; alternative draws or plays remain unresolved.'
    else
    out.reason=out.trigger..' Existing growth value is retained while no supported urgent scoring deficit is established.'
    end
  end
  out.rating=base+out.adjustment
  return out
end

function M.assess(s,card,options)
  options=options or {};local key=card.key
  if not income[key] and not resale[key] and not growth[key] and not conditional_income[key] then return nil end
  local r=options.readiness or {};local a=ability(card)
  local base=num(options.base_value);local is_owned=owned(s,card)
  local cost=num(options.purchase_cost,s.phase=='shop' and not is_owned and num(card.cost) or 0)
  local rental=a.rental and num(s.rental_rate,3) or 0
  local out={kind='income',supported=true,heuristic=true,timing='cashout_after_clear',
    purchase_cost=max(0,cost),cash_before_blind=0,cash_during_blind=0,rental=rental,
    horizon=horizon(s),trigger_weight=1,readiness=r.status or 'unavailable',
    no_interest=not not (options.no_interest or (s.modifiers or {}).no_interest),
    scope='Current trigger opportunities and at most three useful cashouts; conditional on survival, not a forecast of future shops.'}
  if M.liquidity then
    local after={};for k,v in pairs(s) do after[k]=v end
    after.dollars=num(s.dollars)-out.purchase_cost
    if not is_owned then
      after.jokers={};for i,j in ipairs(s.jokers or {}) do after.jokers[i]=j end
      after.jokers[#after.jokers+1]=card
    end
    out.liquidity=M.liquidity.estimate(after,r)
    out.spendable_before_clear=out.liquidity.remaining_allowance
    -- Delayed trigger income remains zero in this allowance, including when
    -- the quoted future payout would exceed today's reserve shortfall.
  end
  if conditional_income[key] then
    out.supported=false;out.timing='unverified_play_or_discard_trigger'
    -- No guessed event frequency, next mail rank, held face population, or
    -- successful random activation may appear as projected spendable dollars.
    out.cash_during_blind=nil;out.cash_end_round=nil;out.net_cash=nil;out.opportunities=nil
    out.rating=base
    if r.supported and r.status=='sampled_deficit' then out.rating=min(base,18) end
    if not active(card) then out.rating=0 end
    out.adjustment=out.rating-base
    out.reason=conditional_income[key]..' Conditional income opportunity is unverified; no cash forecast is supplied.'
    if out.adjustment<0 then out.reason=out.reason..' An unresolved scoring deficit limits speculative income value.' end
    return out
  end
  if growth[key] then return growth_value(s,card,r,out,base) end
  if resale[key] then
    out.kind='resale_growth';out.timing='resale_after_round';out.cash_end_round=0;out.net_cash=-rental
    out.opportunities=key=='j_egg' and 1 or #(s.jokers or {})+#(s.consumeables or {})+(is_owned and 0 or 1)
    out.resale_growth=active(card) and out.opportunities*num(a.extra,key=='j_egg' and 3 or 1) or 0
    out.adjustment=r.supported and r.status=='sampled_deficit' and -min(24,max(0,base-12)) or 0
    out.rating=base+out.adjustment
    out.reason='Resale grows only after the round and is not spendable until a legal sale or Temperance use. Existing scoring and copy-pool synergies remain separate.'
    if out.adjustment<0 then out.reason=out.reason..' The sampled scoring deficit lowers the value of waiting for that growth.' end
    return out
  end
  local gross=payout(s,card,r,out)
  local payouts=out.horizon
  -- The perishable callback precedes cashout. A tally of one cannot receive
  -- Golden/Rocket/Cloud9/Satellite/Delayed cash even though it was active in play.
  if a.perishable then payouts=min(payouts,max(0,num(a.perish_tally,5)-1)) end
  if not active(card) then payouts=0 end
  out.payout_rounds=payouts
  out.conditional_cash_end_round=payouts>0 and gross or 0
  out.cash_end_round=out.conditional_cash_end_round*out.trigger_weight
  out.net_cash=out.cash_end_round-rental
  local cash=num(s.dollars);local lost_interest=max(0,interest(s,cash,out.no_interest)-interest(s,cash-out.purchase_cost,out.no_interest))
  out.purchase_interest_loss=lost_interest
  -- Quoted payback freezes today's payout and omits subsequent purchases,
  -- income compounding, future boss Rocket increases, and survival assumptions.
  if out.net_cash>0 then out.payback_rounds=math.ceil((out.purchase_cost+lost_interest)/out.net_cash) end
  local rating=out.net_cash>0 and min(76,20+6*out.cash_end_round+min(12,2*out.net_cash*payouts)) or 0
  if out.payback_rounds and out.payback_rounds>payouts then rating=rating*0.6 end
  if r.supported and r.status=='sampled_deficit' then rating=min(rating,8) end
  if not out.supported then rating=0 end
  out.rating=rating;out.adjustment=rating-base
  out.reason=out.unknown or string.format('Conditional next-round payout $%.1f, net $%.1f after rental; available only after clearing.',out.cash_end_round,out.net_cash)
  if out.trigger_note then out.reason=out.reason..' '..out.trigger_note end
  if out.payback_rounds then out.reason=out.reason..string.format(' Purchase payback is %d round(s) at this payout; %d useful cashouts are considered.',out.payback_rounds,payouts)
  else out.reason=out.reason..' No positive cash payback is established.' end
  if r.supported and r.status=='sampled_deficit' then out.reason=out.reason..' Later income cannot repair the current sampled scoring deficit.' end
  if a.perishable then out.reason=out.reason..' Perishable expiration is applied before cashout.' end
  return out
end

return M
