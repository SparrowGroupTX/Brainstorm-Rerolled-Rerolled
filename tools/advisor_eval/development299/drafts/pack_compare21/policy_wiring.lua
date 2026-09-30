-- Source-adapter graph contract only. No game, source, profile or file access.
local M={}
local required={
  'snapshot','scoring','search','strategy','decision','consumables','deck_development','spectral_development',
  'ordering','economy','shop_scoring','shop_sequences','pack_scoring','hand_ordering','boss_rescue','mixed_rescue',
  'growth','phase_copy','gold_stickers','gold_perkeo','perkeo_inventory','gold_planet_policy','gold_search','normal_opening','bell_opening','certificate',
  'pack_survival','finish_rewards','score_cache','blind_routing','draws','sampled_outcomes','multi_discard',
  'two_hand_finish','resource_finish','concealed_belief','policy_weights','work_cost','blind_prep','liquidity','blind_finishing'}
local edges={
  {'snapshot.normal_opening','normal_opening'}, {'snapshot.certificate','certificate'},
  {'snapshot.perkeo_inventory','perkeo_inventory'},
  {'normal_opening.gold_stickers','gold_stickers'}, {'normal_opening.gold_search','gold_search'},
  {'strategy.consumables','consumables'}, {'strategy.deck_development','deck_development'},
  {'strategy.pack_scoring','pack_scoring'}, {'strategy.pack_survival','pack_survival'},
  {'strategy.liquidity','liquidity'}, {'deck_development.spectral','spectral_development'},
  {'consumables.deck_development','deck_development'}, {'shop_scoring.strategy','strategy'},
  {'shop_scoring.blind_prep','blind_prep'}, {'shop_scoring.bell_opening','bell_opening'},
  {'shop_scoring.certificate','certificate'}, {'shop_scoring.work_cost','work_cost'},
  {'shop_scoring.policy_weights','policy_weights'}, {'shop_scoring.liquidity','liquidity'},
  {'shop_scoring.blind_finishing','blind_finishing'}, {'blind_prep.blind_start','shop_scoring.blind_start'},
  {'search.policy_weights','policy_weights'}, {'growth.policy_weights','policy_weights'},
  {'strategy.paid_reroll.policy_weights','policy_weights'}, {'strategy.paid_reroll.liquidity','liquidity'},
  {'strategy.conditional_value.liquidity','liquidity'}, {'liquidity.snapshot','snapshot'},
  {'blind_finishing.search','search'}, {'blind_finishing.draws','draws'},
  {'blind_finishing.sampled_outcomes','sampled_outcomes'}, {'blind_finishing.multi_discard','multi_discard'},
  {'blind_finishing.finish_rewards','finish_rewards'}, {'blind_finishing.strategy','strategy'},
  {'blind_finishing.pack_survival','pack_survival'}}
local secondary={'strategy.synergies','strategy.conditional_value','strategy.paid_reroll',
  'strategy.paid_reroll.catalog','shop_scoring.paired_deck','shop_scoring.blind_start'}
local excluded={'retry_memory','retry_policy','retry_journal','retry_store','player_journal','player_log_archive',
  'execution','auto_run','auto_terminal','auto_product'}
local function at(root,path)
  local value=root
  for key in path:gmatch('[^.]+') do value=type(value)=='table' and value[key] or nil end
  return value
end
function M.verify(modules,objective)
  assert(type(modules)=='table','HEADLESS_BOUNDARY policy wiring table missing')
  local enabled=type(objective)=='table' and objective.enabled==true
  local names={}
  for _,name in ipairs(required) do
    assert(type(at(modules,name))=='table','HEADLESS_BOUNDARY required policy missing: '..name)
    names[#names+1]=name
  end
  for _,path in ipairs(secondary) do
    assert(type(at(modules,path))=='table','HEADLESS_BOUNDARY required policy dependency missing: '..path)
    names[#names+1]=path
  end
  if enabled then
    assert(type(modules.gold_goal)=='table' and type(modules.gold_goal.suggest)=='function',
      'HEADLESS_BOUNDARY enabled Gold objective policy missing')
    names[#names+1]='gold_goal'
  else
    assert(modules.gold_goal==nil,'HEADLESS_BOUNDARY Gold policy must stay disabled when objective mode is off')
  end
  local connections={}
  for _,edge in ipairs(edges) do
    local actual,expected=at(modules,edge[1]),at(modules,edge[2])
    assert(expected~=nil and actual==expected,'HEADLESS_BOUNDARY policy edge mismatch: '..edge[1]..' -> '..edge[2])
    connections[#connections+1]={from=edge[1],to=edge[2]}
  end
  for _,name in ipairs(excluded) do
    assert(modules[name]==nil,'HEADLESS_BOUNDARY excluded live/retry integration present: '..name)
  end
  table.sort(names)
  return {schema=1,kind='complete_source_policy_wiring_310_v1',modules=names,connections=connections,
    gold_objective_enabled=enabled,retry_enabled=false,checkpoint_restore_enabled=false,
    runtime_ui_execution=false,qualification=false,
    scope='Detached product decision graph; original source action callbacks; no runtime/UI, player journals or retry context'}
end
return M
