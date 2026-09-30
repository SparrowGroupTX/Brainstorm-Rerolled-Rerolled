-- Controlled unit draws through the original public catalog. These cases are
-- not source attempts, discovered seeds, or evidence of later survival.
local M=dofile('Brainstorm/Core/jokerless_opening.lua')
local F=dofile('tests/jokerless_opening_fixture.lua')
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local function copy(v)if type(v)~='table' then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k]) then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function position(pool,key)
 for i,v in ipairs(pool)do if v==key then return (i-.5)/#pool end end;error('Missing public catalog entry: '..key)
end
local controlled={Tag1=position(F.catalog.tags,'tag_coupon'),Voucher1=position(F.catalog.vouchers,'v_telescope'),
 cdt1=1,stdset1=.9,Enhancedsta1=position(F.catalog.enhancements,'m_steel'),frontsta1=.1,
 standard_edition1=0,stdseal1=.9,stdsealtype1=.6}
local sum,total=0,0;for _,p in ipairs(F.catalog.boosters)do total=total+p.weight end
for _,p in ipairs(F.catalog.boosters)do
 if p.key=='p_standard_mega_1' then controlled.shop_pack1=(sum+p.weight/2)/total;break end;sum=sum+p.weight
end
check(controlled.shop_pack1~=nil,'source catalog contains the selectable Standard booster')
local real_stream=M.stream
M.stream=function()
 local planets=0
 return function(key)
  if key=='Planetsho1' then planets=planets+1;return position(F.catalog.planets,planets==1 and 'c_mars' or 'c_jupiter') end
  return assert(controlled[key],'unexpected draw key '..key)
 end
end
local recipes={}
for _,target in ipairs({{key='c_mars',hand='Four of a Kind',name='Mars'},{key='c_jupiter',hand='Flush',name='Jupiter'}})do
 local options={require_planet=target.key,target_hand=target.hand,min_blue=2,min_steel=1,require_telescope=true,limit=1}
 local result=assert(M.search(F.catalog,options));local recipe=result.matches[1];recipes[target.key]=recipe
 check(result.status=='found' and result.tested==1 and result.next_index==1 and #result.matches==1,'one controlled complete candidate uses unchanged cursor accounting')
 check(recipe.shop[1].key=='c_mars' and recipe.shop[1].set=='Planet' and recipe.shop[2].key=='c_jupiter' and recipe.shop[2].set=='Planet','Mars and Jupiter come from actual original public Planet slots')
 check(recipe.target_planet==target.key and recipe.target_hand==target.hand and M.validate_result(recipe),'recipe binds selected target')
 check(M.match(copy(recipe),options) and recipe.blue_choices==4 and recipe.blue_steel==4,'required target and selectable Blue Steel cards matched')
 local p=assert(M.predict(recipe.seed,F.catalog,options));M.match(p,options)
 check(equal(recipe,p),'explicit predictor plus predicate reproduces complete search recipe')
 local derived=assert(M.predict(recipe.seed,F.catalog,{target_hand=target.hand}))
 check(derived.target_planet==target.key and derived.target_hand==target.hand,'hand-only predicate resolves its exact Planet')
 local s={phase='shop',challenge='c_jokerless_1',ante=1,round=1,blind_states={Small='Skipped'},
  filter_info={jokerless_opening=copy(recipe),jokerless_catalog_signature=recipe.catalog_signature},
  shop_jokers={{key='c_mars',cost=0},{key='c_jupiter',cost=0}},shop_vouchers={{key='v_telescope',cost=10}},
  shop_booster={{key=recipe.packs[1].key,cost=0},{key=recipe.packs[2].key,cost=0}},consumeables={},consumable_limit=2,dollars=10}
 local before=copy(s);local advice=M.advice(s);local index=target.key=='c_mars' and 1 or 2
 check(advice.action.kind=='buy' and advice.action.index==index and advice.title=='Buy the free '..target.name,'opening buys selected Planet rather than the other free Planet')
 check(equal(s,before),'targeted advice does not mutate the public snapshot or recipe')
 s.consumeables={{key='c_saturn'},{key=target.key}};advice=M.advice(s)
 check(advice.action.kind=='use' and advice.action.index==2 and advice.title:find(target.hand,1,true),'opening uses only its selected Planet and hand')
 s.consumeables={{key='c_saturn'},{key='c_fool'}};advice=M.advice(s)
 check(not advice.action and #advice.warnings>0,'full inventory retains explicit safe-space review')
 s.consumeables={};s.shop_jokers[index].cost=3;advice=M.advice(s)
 check(not advice.action and #advice.warnings>0,'selected Planet still requires actual Coupon free price')
 s.phase='hand';s.shop_jokers[index].cost=0
 check(M.advice(s)==nil,'bound target does not take over normal tactical hand search')
end
M.stream=real_stream
-- Binding adds no calls to the real private stream and no changes to source-
-- checked tags, cards, shops, boosters or legacy unbound recipe fields.
for _,e in ipairs(F.examples)do
 local legacy=assert(M.predict(e.seed,F.catalog))
 for _,target in ipairs({'c_mars','c_jupiter','c_saturn'})do
  local bound=assert(M.predict(e.seed,F.catalog,{require_planet=target}))
  check(bound.target_planet==target and type(bound.target_hand)=='string','explicit target metadata is canonical')
  bound.target_planet=nil;bound.target_hand=nil
  check(equal(bound,legacy),'binding preserves all original-source prediction fields and RNG outcomes')
 end
 check(legacy.target_planet==nil and legacy.target_hand==nil,'absent options retain legacy recipe bytes')
end
for _,bad in ipairs({{require_planet='c_planet_x'},{target_hand='Five of a Kind'},{require_planet='c_ceres'},
 {require_planet='c_eris'},{require_planet='c_mars',target_hand='Flush'},{require_planet='c_jupiter',require_saturn=true},
 {require_planet=false},{target_hand=5}})do
 bad.limit=1
 check(not M.search(F.catalog,bad),'unsupported or conflicting target rejected before search')
 check(not M.predict(F.examples[2].seed,F.catalog,bad),'unsupported or conflicting prediction target rejected')
 check(not M.match(copy(recipes.c_mars),bad),'unsupported or conflicting target cannot match a valid recipe')
end
for _,bad in ipairs({{target_planet='c_mars'},{target_hand='Four of a Kind'},
 {target_planet='c_planet_x',target_hand='Five of a Kind'},{target_planet='c_mars',target_hand='Flush'}})do
 local recipe=copy(recipes.c_mars);recipe.target_planet=bad.target_planet;recipe.target_hand=bad.target_hand
 check(not M.validate_result(recipe),'malformed target binding rejected structurally')
 check(not M.match(recipe,{min_blue=2}),'malformed target binding never matches implicitly')
end
check(not M.match(copy(recipes.c_mars),{require_planet='c_jupiter'}),'different target cannot reinterpret an already bound recipe')
check(not M.match(copy(recipes.c_mars),{require_saturn=true}),'legacy Saturn predicate cannot reinterpret a Mars recipe')
local absent=copy(recipes.c_mars);absent.shop[1]={key='c_saturn',set='Planet'}
check(not M.match(absent,{}),'bound recipe still requires its actual Planet even without explicit options')
local unavailable=copy(F.catalog)
for i,key in ipairs(unavailable.planets)do if key=='c_mars' then unavailable.planets[i]='UNAVAILABLE' end end
check(not M.search(unavailable,{limit=1,require_planet='c_mars'}),'unavailable target fails before spending a seed range')
local legacy=assert(M.predict(F.examples[2].seed,F.catalog))
check(M.match(copy(legacy),{min_blue=2,require_saturn=true,require_telescope=true}),'recorded source Saturn recipe keeps legacy predicate behavior')
print('advisor_jokerless_planet_targets: '..checks..' checks passed')
