local W=dofile('Brainstorm/Advisor/policy_weights.lua')
local checks=0
local function eq(a,b) checks=checks+1;assert(a==b,tostring(a)..' ~= '..tostring(b)) end
eq(W.schema,2);eq(W.version,'2.0')
eq(W.get('growth_action_cost'),4);eq(W.get('growth_utility_scale'),1);eq(W.get('discard_action_penalty'),0.06)
eq(W.get('shop_scoring_gain_weight'),1);eq(W.get('reroll_min_target_gain'),0.02);eq(W.get('computation_cost_scale'),1)
local values=W.values();values.growth_action_cost=100;eq(W.get('growth_action_cost'),4)
local spec=W.spec();eq(spec.growth_action_cost.maximum,12);eq(spec.discard_action_penalty.minimum,0)
spec.growth_action_cost.maximum=100;eq(W.spec().growth_action_cost.maximum,12)
eq(pcall(W.get,'missing'),false)
print('policy weights: '..checks..' checks passed')
