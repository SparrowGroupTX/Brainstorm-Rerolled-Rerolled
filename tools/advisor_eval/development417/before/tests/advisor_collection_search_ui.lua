-- Synthetic settings/UI checks: never invokes search, native code or game saves.
package.preload.lovely=function() return {} end
package.preload.nativefs=function() return {} end
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks,writes,searches=0,0,0
local function check(v,why) checks=checks+1;assert(v,why) end
local function eq(a,b,why) check(a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local original={pack={'original'},pack_id=5,voucher_name='v_telescope',voucher_id=8,
  tag_name='tag_charm',tag_id=2,soul_count=2,inst_observatory=true,observatory_deadline=6,
  inst_perkeo=true,no_perishable_jokers=true,copy_money=true,bean=true,burglar=true,retcon=true,
  custom_filter_name='Negative Perkeo',custom_filter_id=3,rank_min=9,rank_min_id=10,
  any_rank_min=8,any_rank_min_id=9,rank_name='Ace',rank_id=14,suit_name='Hearts',suit_id=4,
  joker_targets={'Perkeo','Blueprint','Baron','',''},joker_target_editions={'Negative'},
  joker_target_locations={'soul_pack','by_ante_2'},future_field={keep=41}}
Brainstorm={config={ar_filters=Snapshot.copy(original),ar_prefs={native_cpu_mode='maximum'},
  advisor={enabled=true,retry={persistent_count=5}},challenge_opening={enabled=true,targets={'j_perkeo'}},
  jokerless_opening_search={preset='four_kind'}},ar_active=false,
  writeConfig=function() writes=writes+1 end,autoReroll=function() searches=searches+1 end,
  createAdvisorPage=function() return {} end,createChallengeOpeningPage=function() return {} end}
G={FUNCS={options=function() end},UIT={ROOT='ROOT',R='R',C='C',T='T',O='O'},
  C={CLEAR={},GREEN={},WHITE={},RED={},UI={TRANSPARENT_DARK={}}},
  GAME={challenge='c_medusa_1',seeded=true,used_filter=false,public_marker=17}}
create_tabs=function(args) return args end
UIBox_button=function(args) return {n='BUTTON',config=args} end
create_option_cycle=function(args) return {n='CYCLE',config=args} end
create_toggle=function(args) return {n='TOGGLE',config=args} end
darken=function(value) return value end
local game_before=Snapshot.fingerprint(G.GAME)
local config_before=Snapshot.fingerprint(Brainstorm.config)
dofile('Brainstorm/UI/ui.lua')
eq(writes,0,'loading does not write configuration')
eq(searches,0,'loading does not start search')
local texts,buttons={},{}
local function walk(node)
  if node.config and node.config.text then texts[node.config.text]=true end
  if node.n=='BUTTON' then buttons[node.config.button]=node.config end
  for _,child in ipairs(node.nodes or {}) do walk(child) end
end
for i=1,3 do
  local page=Brainstorm.createCollectionSearchPage();walk(page)
  check(#page.nodes<=14,'collection page keeps a bounded single-page layout')
end
eq(Snapshot.fingerprint(Brainstorm.config),config_before,'rendering preserves all settings')
check(texts['Medusa and other challenges do not record discoveries.'],'collection limitation is explicit')
check(texts['This preset searches for an early Marble Joker.'],'target is Marble rather than a promised Stone Joker')
check(texts['Play Small and Big without skips or shop rerolls.'],'route constraints are displayed')
check(texts['Check the first two shops and their Buffoon packs.'],'early locations are displayed')
check(texts['A Marble offer does not guarantee cash, survival or Stone Joker.'],'offer limitation is explicit')
check(buttons.brainstorm_collection_marble_preset and buttons.brainstorm_collection_restore_filters,'both manual settings actions exist')
G.FUNCS.brainstorm_collection_restore_filters()
eq(writes,0,'missing backup does not write')
Brainstorm.ar_active=true
G.FUNCS.brainstorm_collection_marble_preset()
eq(writes,0,'active search prevents filter replacement')
eq(Snapshot.fingerprint(Brainstorm.config),config_before,'active-search guard preserves exact settings')
Brainstorm.ar_active=false
G.FUNCS.brainstorm_collection_marble_preset()
local selected=Brainstorm.config.ar_filters
eq(writes,1,'one explicit preset click saves once')
eq(Snapshot.fingerprint(Brainstorm.config.collection_previous_filters),Snapshot.fingerprint(original),'original filters are fully backed up')
eq(selected.joker_targets[1],'Marble Joker','native target is the supported prerequisite')
for i=2,5 do eq(selected.joker_targets[i],'','other targets are removed only by the explicit preset') end
for i=1,5 do
  eq(selected.joker_target_locations[i],'ante_1','all target locations are valid early route IDs')
  eq(selected.joker_target_editions[i],'Any Edition','no unnecessary edition constraint')
end
eq(selected.soul_count,0,'no Soul route remains')
eq(selected.tag_name,'','no skip-tag requirement remains')
eq(#selected.pack,0,'no pack requirement remains')
eq(selected.voucher_name,'','no voucher requirement remains')
eq(selected.custom_filter_name,'No Filter','no hidden custom route remains')
for _,key in ipairs({'inst_observatory','inst_perkeo','copy_money','bean','burglar','retcon','no_perishable_jokers'}) do
  eq(selected[key],false,'preset disables unrelated '..key)
end
for _,key in ipairs({'observatory_deadline','rank_min','any_rank_min'}) do eq(selected[key],0,'preset clears '..key) end
eq(selected.future_field.keep,41,'unknown unrelated filter metadata survives')
eq(Brainstorm.config.ar_prefs.native_cpu_mode,'maximum','CPU preference is unchanged')
eq(Brainstorm.config.advisor.retry.persistent_count,5,'retry cap metadata is unchanged')
eq(Brainstorm.config.challenge_opening.targets[1],'j_perkeo','challenge filters are unchanged')
eq(Brainstorm.config.jokerless_opening_search.preset,'four_kind','Jokerless setting is unchanged')
selected.future_field.keep=99
G.FUNCS.brainstorm_collection_marble_preset()
eq(Brainstorm.config.collection_previous_filters.future_field.keep,41,'repeat application cannot overwrite the original backup')
eq(writes,2,'repeat manual preset has one write')
Brainstorm.ar_active=true;G.FUNCS.brainstorm_collection_restore_filters()
eq(writes,2,'restore also respects active search')
Brainstorm.ar_active=false;G.FUNCS.brainstorm_collection_restore_filters()
eq(Snapshot.fingerprint(Brainstorm.config.ar_filters),Snapshot.fingerprint(original),'restore returns exact prior filter content')
eq(Brainstorm.config.collection_previous_filters,nil,'successful explicit restore consumes its backup')
eq(writes,3,'restore saves once')
eq(searches,0,'configuring and restoring never start native search')
eq(Snapshot.fingerprint(G.GAME),game_before,'challenge, seeded flag and progress fields remain untouched')
-- The new page is reachable through the existing page selector, without opening
-- or operating a real overlay. The scheduled object is only this synthetic UI.
G.E_MANAGER={add_event=function(_,event) end};Event=function(event) return event end
Moveable=function() return {} end
local tabs=create_tabs({tab_h=7.05,tabs={}})
local root=tabs.tabs[1].tab_definition_function()
local collection_index,gold_index,gold_search_index
local function find(node)
  if node.n=='CYCLE' and node.config.opt_callback=='change_brainstorm_page' then
    for index,label in ipairs(node.config.options) do
      if label=='Collection' then collection_index=index elseif label=='Completionist++' then gold_index=index
      elseif label=='Gold search' then gold_search_index=index end
    end
  end
  for _,child in ipairs(node.nodes or {}) do find(child) end
end
find(root);check(collection_index~=nil,'Collection is listed in the ordinary Brainstorm page selector')
check(gold_index~=nil and gold_index~=collection_index,'Completionist++ has its own reachable page beside the existing collection helper')
check(gold_search_index~=nil and gold_search_index~=gold_index,'Gold search has a dedicated bounded layout beside the tracker')
print('collection search UI: '..checks..' checks passed')
