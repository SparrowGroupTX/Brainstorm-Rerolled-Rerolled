-- Owned cash consumables before an actual shop purchase/sale. No live callbacks.
local E={}
local function num(x,default) return type(x)=='number' and x or (default or 0) end
local function spend(s,advice)
  local a=advice and advice.action
  if not a then return end
  if a.kind=='buy' or a.kind=='open' then
    local c=(s[a.area] or {})[a.index]
    if c then return num(c.cost),c end
  elseif a.kind=='reroll' then return num(s.reroll_cost) end
end
function E.suggest(s,strategy,consumables,base)
  if s.phase~='shop' or not consumables or not consumables.apply then return end
  if base.action and base.action.kind=='use' then return end
  local retained={}
  local function candidate(state,index,advice)
    local c=state.consumeables[index]
    if not c or c.key~='c_hermit' and c.key~='c_temperance' then return end
    local after=consumables.apply(state,index,{})
    if not after then return end
    local gain=num(after.dollars)-num(state.dollars)
    if gain<=0 then return end
    local next_advice=strategy.advise(after)
    local cost,purchase=spend(after,next_advice)
    local old_cost,old_purchase=spend(state,advice)
    local sale=advice.action and advice.action.kind=='sell' and advice.action.area=='jokers'
    local cap=num((c.ability or {}).extra,c.key=='c_hermit' and 20 or 50)
    -- Enabling a paid reroll alone is not a known purchase opportunity.
    local unlock=purchase and cost>0 and (not old_purchase or old_cost<=0 or
      cost>math.max(0,num(state.dollars)-num(state.bankrupt_at)))
    local protects=c.key=='c_hermit' and old_cost and old_cost>0 and cost and cost>0
    local cashout=c.key=='c_temperance' and sale
    local at_cap=gain>=cap
    -- Extra cash can shrink Luxury Tax's hand or turn off a working Vagabond.
    -- Require the concrete next spend to restore the current useful threshold.
    local tax=num((state.modifiers or {}).minus_hand_size_per_X_dollar)
    local before_spending=num(state.dollars)-num(old_cost)
    local safe=tax<=0 or cost and cost>0 and
      math.floor((after.dollars-cost)/tax)<=math.floor(before_spending/tax)
    for _,j in ipairs(state.jokers or {}) do
      if j.key=='j_vagabond' and not j.debuff and before_spending<=num((j.ability or {}).extra,4) then
        safe=safe and num(after.dollars)-num(cost)<=num((j.ability or {}).extra,4)
      end
    end
    if not safe then return end
    if strategy.preservation_cost then
      local loss,reason,last=strategy.preservation_cost(state,after,index)
      -- Cash is already included in the concrete purchase preview. Future
      -- source value is separate; recompute it after each sequence step.
      if last or loss>gain*2 then
        if reason then retained[reason]=true end
        return
      end
    end
    -- Shop buys store Wraith in inventory; its cash reset occurs on USE. An
    -- existing use action is kept by the guard above, not confused with a buy.
    return {index=index,card=c,after=after,gain=gain,next_advice=next_advice,
      immediate=not not (unlock or protects or cashout or at_cap),
      priority=(cashout and 100 or 0)+(unlock and 60 or 0)+(protects and 30 or 0)+(at_cap and 20 or 0),
      reason=cashout and 'Collect the payout before selling a Joker, while its sell value still counts.' or
        protects and 'Use it before spending so the purchase does not reduce the doubled cash.' or
        unlock and 'The extra cash enables the next recommended purchase.' or
        'Its payout has reached the current cap; holding it cannot increase this payout.'}
  end
  local possible,candidates={},{}
  for index,c in ipairs(s.consumeables or {}) do
    if c.key=='c_hermit' or c.key=='c_temperance' then
      local item=candidate(s,index,base)
      if item then possible[#possible+1]=item end
    end
  end
  -- Compare only useful two-step payouts. An uncapped Temperance may be worth
  -- using first because it increases the Hermit we already need before spending.
  for _,a in ipairs(possible) do
    a.combined=a.gain
    for _,b in ipairs(possible) do if a~=b then
      local i=b.index-(b.index>a.index and 1 or 0)
      local second=candidate(a.after,i,a.next_advice)
      if second and second.immediate then
        local combined=num(second.after.dollars)-num(s.dollars)
        if not a.immediate and a.card.key=='c_temperance' and b.immediate and
          b.card.key=='c_hermit' and second.gain>b.gain then
          a.immediate=true
          a.reason='Use Temperance first to increase the held Hermit payout before the planned spending.'
        end
        if combined>a.combined then a.combined=combined; a.next_cash=second end
      end
    end end
    if a.immediate then candidates[#candidates+1]=a end
  end
  table.sort(candidates,function(a,b)
    if a.combined~=b.combined then return a.combined>b.combined end
    if a.priority~=b.priority then return a.priority>b.priority end
    if a.gain~=b.gain then return a.gain>b.gain end
    return a.index<b.index
  end)
  local best=candidates[1]; if not best then
    local reasons={};for reason in pairs(retained) do reasons[#reasons+1]=reason end
    table.sort(reasons)
    base.lines=base.lines or {}
    for _,reason in ipairs(reasons) do base.lines[#base.lines+1]=reason end
    return
  end
  local name=best.card.key=='c_hermit' and 'The Hermit' or 'Temperance'
  local next_title=best.next_advice.title
  if best.next_cash then
    next_title='use '..(best.next_cash.card.key=='c_hermit' and 'The Hermit' or 'Temperance')..
      ' (+$'..tostring(best.next_cash.gain)..')'
  end
  return {title='Use '..name..' (+$'..tostring(best.gain)..')',
    lines={best.reason,'Then reassess: '..next_title..'.'},warnings={},
    action={kind='use',area='consumeables',index=best.index,targets={}}}
end
return E
