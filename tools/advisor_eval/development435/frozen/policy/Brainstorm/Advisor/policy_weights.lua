-- Versioned, bounded strategic coefficients. These defaults preserve the
-- existing policy. Development screens edit only the frozen VALUES block;
-- live settings, saves and installed defaults are never tuned implicitly.
local M={schema=2,version='2.0'}
local bounds={growth_action_cost={0,12},growth_utility_scale={0.5,1.5},discard_action_penalty={0,0.2},
  shop_scoring_gain_weight={0.5,1.5},reroll_min_target_gain={0.01,0.1},computation_cost_scale={0,2}}
-- POLICY_WEIGHTS_BEGIN
local VALUES={
  growth_action_cost=4,
  growth_utility_scale=1,
  discard_action_penalty=0.06,
  shop_scoring_gain_weight=1,
  reroll_min_target_gain=0.02,
  computation_cost_scale=1,
}
-- POLICY_WEIGHTS_END
for key,range in pairs(bounds) do
  local value=VALUES[key]
  assert(type(value)=='number' and value==value and value>=range[1] and value<=range[2],
    'Invalid policy coefficient: '..key)
end
for key in pairs(VALUES) do assert(bounds[key],'Unknown policy coefficient: '..tostring(key)) end
function M.get(key)
  assert(bounds[key],'Unknown policy coefficient: '..tostring(key))
  return VALUES[key]
end
function M.values()
  local result={};for key,value in pairs(VALUES) do result[key]=value end;return result
end
function M.spec()
  local result={};for key,range in pairs(bounds) do result[key]={minimum=range[1],maximum=range[2],value=VALUES[key]} end;return result
end
return M
