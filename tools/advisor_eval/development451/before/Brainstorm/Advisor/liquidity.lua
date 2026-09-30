-- One cash allowance for detached shop decisions. Rental charges occur after
-- play, before interest; reserved discard dollars remain possible spending,
-- never a claim that the next blind is winnable or needs every discard.
local M={}
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function num(v,d) return finite(v) and v or (d or 0) end
local function integer(v) return finite(v) and v>=0 and v==math.floor(v) end

function M.observation_key(state)
  if not M.snapshot or not M.snapshot.fingerprint then return nil end
  local seen={}
  local function observed(value)
    if type(value)~='table' then
      if type(value)=='number' and not finite(value) then error('Non-finite observation') end
      if type(value)=='function' or type(value)=='userdata' or type(value)=='thread' then error('Non-data observation') end
      return value
    end
    if seen[value] then error('Cyclic observation') end
    seen[value]=true;local out={}
    for key,item in pairs(value) do
      if key~='_readiness' and key~='_shop_scoring' then out[key]=observed(item) end
    end
    seen[value]=nil;return out
  end
  local ok,key=pcall(function() return M.snapshot.fingerprint(observed(state)) end)
  return ok and key or nil
end

function M.estimate(state,readiness,options)
  options=options or {};readiness=readiness or state._readiness or {}
  local meta=state.shop_forecast or {};local mods=state.modifiers or {}
  local bonus=state.round_bonus or meta.round_bonus or {};local resets=state.round_resets or {}
  local supported=readiness.supported and integer(readiness.discards)
  local discards=supported and readiness.discards or math.max(0,num(resets.discards,3)+num(bonus.discards))
  local rentals=0;local rental_rate=math.max(0,num(state.rental_rate,num(meta.rental_rate,3)))
  for _,j in ipairs(state.jokers or {}) do
    -- Rental still charges for a debuffed or expired retained card.
    if (j.ability or {}).rental then rentals=rentals+rental_rate end
  end
  local count=discards;local scope='conservative_all_available_discards'
  local reason='Reserve all available paid discards; a complete finishing plan has not established a smaller cost.'
  local plan=options.resource_plan or readiness.resource_plan
  -- Compute the binding again from the actual endpoint. A supplied matching
  -- string cannot make a stale plan valid after purchases, uses or reorderings.
  -- Derived readiness/context tables are excluded on both sides of the binding.
  local observation_key=plan and M.observation_key(state)
  if supported and plan and plan.complete and plan.supported and plan.all_worlds_clear and plan.known_mechanics and
      plan.cost_model=='actual_actions' and type(observation_key)=='string' and observation_key~='' and
      (not options.observation_key or options.observation_key==observation_key) and
      plan.observation_key==observation_key and plan.target==readiness.target and
      integer(plan.samples) and plan.samples>=4 and plan.discards_available==discards and
      integer(plan.max_discards_used) and plan.max_discards_used<=discards then
    count=plan.max_discards_used;scope='complete_sampled_finish_resources'
    reason='Reserve the largest actual discard cost in the complete supported sampled finish; unseen draws remain uncertain.'
  end
  local discard_cost=math.max(0,num(mods.discard_cost))
  local reserve=rentals+discard_cost*count
  local debt=math.min(0,num(state.bankrupt_at))
  local cash=num(state.dollars);local floor=debt+reserve
  return {reserve=reserve,rental_cost=rentals,rental_timing='after_play_before_interest',
    discard_cost=discard_cost,discards_reserved=count,discards_available=discards,
    debt_limit=debt,purchase_floor=floor,cash_after_payment=cash,shortfall=math.max(0,floor-cash),
    remaining_allowance=math.max(0,cash-floor),cash_after_reserved_costs=cash-reserve,
    resource_basis=supported and 'supported_next_blind_resources' or 'unresolved_reset_resources',
    scope=scope,conservative=scope=='conservative_all_available_discards',
    finishing_guarantee=false,reason=reason}
end

function M.incremental(before,after,before_readiness,after_readiness)
  local left=M.estimate(before,before_readiness);local right=M.estimate(after,after_readiness)
  -- Spending is not prohibited: a timely scoring purchase can still justify
  -- emergency cash use. Existing resource gaps are not charged again per item.
  return math.min(30,5*math.max(0,right.shortfall-left.shortfall)),left,right
end
return M
