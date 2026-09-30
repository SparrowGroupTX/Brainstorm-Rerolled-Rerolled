-- Controlled routine fixtures only: no seed discovery or throughput benchmark.
local M=dofile('Brainstorm/Core/jokerless_opening.lua')
local F=dofile('tests/jokerless_opening_fixture.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function equal(a,b)
  if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function position(pool,key)
  for i,v in ipairs(pool) do if v==key then return (i-.5)/#pool end end;error('Missing catalog entry '..key)
end
local function pack_position(catalog,key)
  local sum,total=0,0;for _,p in ipairs(catalog.boosters) do total=total+p.weight end
  for _,p in ipairs(catalog.boosters) do if p.key==key then return (sum+p.weight/2)/total end;sum=sum+p.weight end
  error('Missing booster '..key)
end
local normal={require_planet='c_mars',target_hand='Four of a Kind',min_blue=2,min_steel=1,require_telescope=true,limit=1}
local real_stream,real_signature=M.stream,M.catalog_signature
local random,randomseed=math.random,math.randomseed
math.random=function() error('Search gates touched global RNG') end
math.randomseed=function() error('Search gates reseeded global RNG') end
local function controlled(rows,catalog)
  catalog=catalog or F.catalog;local counts,created,order={},{},{}
  M.stream=function(seed)
    local row=rows[seed] or rows.default or {};local seen={};created[#created+1]=seed
    return function(key)
      counts[key]=(counts[key] or 0)+1;seen[key]=(seen[key] or 0)+1;order[#order+1]=seed..'|'..key
      if row.override then local v=row.override(key,seen[key],catalog);if v~=nil then return v end end
      if key=='Tag1' then return position(catalog.tags,seen[key]==1 and (row.small or 'tag_coupon') or 'tag_double') end
      if key=='Voucher1' then return position(catalog.vouchers,row.voucher or 'v_telescope') end
      if key=='cdt1' then return 1 end
      if key=='Planetsho1' then return position(catalog.planets,(row.planets or {'c_mars','c_jupiter'})[seen[key]]) end
      if key=='shop_pack1' then return pack_position(catalog,(row.packs or {'p_standard_mega_1','p_standard_mega_1'})[seen[key]]) end
      if key=='stdset1' then return .9 end
      if key=='Enhancedsta1' then return position(catalog.enhancements,'m_steel') end
      if key=='frontsta1' then return .1 end
      if key=='standard_edition1' then return 0 end
      if key=='stdseal1' then return .9 end
      if key=='stdsealtype1' then return .6 end
      error('Unexpected controlled draw '..key)
    end
  end
  return counts,created,order
end
local function baseline(catalog,options)
  local target=options.require_planet or ({['Four of a Kind']='c_mars',Flush='c_jupiter'})[options.target_hand]
  local p,why=M.predict(M.seed_at(options.start or 0),catalog,{require_coupon=true,require_planet=target,
    target_hand=target and ({c_mars='Four of a Kind',c_jupiter='Flush'})[target]})
  if p then M.match(p,options) end
  return p,why
end

do
  local row={packs={'p_standard_normal_1','p_standard_mega_1'},override=function(key,n,catalog)
    if key=='stdset1' then return n%2==1 and .9 or .1 end
    if key=='Enhancedsta1' then return position(catalog.enhancements,n%2==1 and 'm_steel' or 'm_bonus') end
    if key=='frontsta1' then return n/60 end
    if key=='standard_edition1' then return n%3==0 and .99 or .2 end
    if key=='stdseal1' then return n==3 and .1 or .9 end
  end}
  local counts,_,order=controlled({default=row});local full=assert(baseline(F.catalog,normal));local before=copy(order)
  counts,_,order=controlled({default=row});local found=M.search(F.catalog,normal)
  eq(found.status,'found','mixed Standard cards remain a potential match')
  check(equal(found.matches[1],full),'different pack sizes and mixed cards preserve every recipe field')
  check(equal(order,before),'shared Standard keyed streams retain exact call order across both packs')
  eq(#found.matches[1].packs[1].cards,3);eq(#found.matches[1].packs[2].cards,5)
end

do
  for _,options in ipairs({normal,{require_planet='c_jupiter',target_hand='Flush',min_blue=2,min_steel=1,require_telescope=true,limit=1},
    {target_hand='Four of a Kind',min_blue=2,min_steel=1,limit=1},
    {require_saturn=true,min_blue=2,require_telescope=true,limit=1},
    {require_saturn=true,min_blue=2,min_steel=1,require_telescope=true,limit=1},
    {require_saturn=true,min_blue=3,min_steel=3,require_telescope=true,limit=1},
    {min_blue=0,min_quality=0,min_steel=0,limit=1}}) do
    local row=options.require_saturn and {planets={'c_saturn','c_mars'}} or {}
    local counts=controlled({default=row});local full=assert(baseline(F.catalog,options));local full_counts=copy(counts)
    counts=controlled({default=row});local found=assert(M.search(F.catalog,options))
    eq(found.status,'found');eq(found.tested,1);eq(found.next_index,1)
    check(equal(found.matches[1],full),'potential match preserves every full predictor recipe field')
    check(equal(counts,full_counts),'potential match preserves every keyed draw count')
    check(M.validate_result(found.matches[1]),'optimized full recipe remains structurally valid')
    if options.require_saturn then eq(found.matches[1].target_planet,nil,'legacy Saturn stays unbound') end
  end
end

do
  local stages={
    {row={small='tag_double'},last='Tag1',absent='Voucher1',label='Coupon'},
    {row={voucher='v_grabber'},last='Voucher1',absent='cdt1',label='Telescope'},
    {row={planets={'c_mercury','c_jupiter'}},last='Planetsho1',absent='shop_pack1',label='target Planet'},
    {row={packs={'p_standard_normal_1','p_arcana_normal_1'}},last='shop_pack1',absent='stdset1',label='selectable Blue capacity'},
  }
  for _,stage in ipairs(stages) do
    local counts=controlled({default=stage.row});local full=assert(baseline(F.catalog,normal));local before=copy(counts)
    check(not M.match(full,normal),'full predictor also rejects '..stage.label)
    counts=controlled({default=stage.row});local found=M.search(F.catalog,normal)
    eq(found.status,'not_found',stage.label);eq(found.tested,1);eq(found.next_index,1);eq(#found.matches,0)
    check(counts[stage.last] and not counts[stage.absent],'required gate finishes before unused generation for '..stage.label)
    if stage.label~='Coupon' then check(before[stage.absent]~=nil,'ordinary predictor still generates after '..stage.label) end
    if stage.label=='Telescope' then
      local old_total,new_total=0,0;for _,n in pairs(before) do old_total=old_total+n end;for _,n in pairs(counts) do new_total=new_total+n end
      print('controlled Telescope nonmatch: '..old_total..' full draws / '..new_total..' gated draws; not a speed benchmark')
      eq(counts.Tag1,2,'both tags still precede the voucher')
    elseif stage.label=='target Planet' then eq(counts.Planetsho1,2,'both ordinary shop slots precede the target gate') end
  end
  controlled({default={voucher='v_grabber'}})
  local no_telescope=copy(normal);no_telescope.require_telescope=false
  eq(M.search(F.catalog,no_telescope).status,'found','disabled Telescope requirement is not silently added')
  controlled({default={packs={'p_standard_mega_1','p_arcana_normal_1'}}})
  local quality=copy(normal);quality.min_blue=0;quality.min_quality=3;quality.min_steel=0
  eq(M.search(F.catalog,quality).status,'not_found','quality requirement uses selectable capacity, not five revealed cards')
  controlled({default={packs={'p_standard_mega_1','p_arcana_normal_1'}}})
  quality.min_quality=0;quality.min_steel=3
  eq(M.search(F.catalog,quality).status,'not_found','Steel requirement uses selectable capacity')
  controlled({default={packs={'p_arcana_normal_1','p_arcana_normal_1'}}})
  local zero={limit=1,min_blue=0,min_quality=0,min_steel=0}
  eq(M.search(F.catalog,zero).status,'found','zero requirements preserve no-Standard valid matches')
  local legacy={limit=1,require_saturn=true,min_blue=2}
  local counts=controlled({default={}})
  eq(M.search(F.catalog,legacy).status,'not_found','legacy Saturn rejects both non-Saturn shop offers')
  eq(counts.Planetsho1,2);eq(counts.shop_pack1,nil,'legacy target gate runs after both slots')
end

do
  local row={override=function(key,n,catalog)
    if key=='Tag1' and n==1 or key=='Voucher1' then return position(key=='Tag1' and catalog.tags or catalog.vouchers,'UNAVAILABLE') end
    if key=='Tag1_resample2' then return position(catalog.tags,'tag_coupon') end
    if key=='Voucher1_resample2' then return position(catalog.vouchers,'v_telescope') end
    if key=='Planetsho1' then return position(catalog.planets,'c_mars') end
    if key=='Planetsho1_resample2' then return position(catalog.planets,'c_jupiter') end
  end}
  local opts=copy(normal);opts.require_planet='c_jupiter';opts.target_hand='Flush'
  local counts=controlled({default=row});local full=assert(baseline(F.catalog,opts));local before=copy(counts)
  counts=controlled({default=row});local found=M.search(F.catalog,opts)
  check(found.status=='found' and equal(found.matches[1],full),'resampling and second-slot target preserve recipe')
  check(equal(counts,before),'resample key progression exactly preserved on a match')
  eq(found.matches[1].shop[1].key,'c_mars');eq(found.matches[1].shop[2].key,'c_jupiter')
  eq(counts.Planetsho1_resample2,1,'used first-slot identity is unavailable to the second slot')
end

do
  for _,stage in ipairs({'small','big','voucher','shop'}) do
    local row={override=function(key,n,catalog)
      if stage=='small' and (key=='Tag1' or key:match('^Tag1_resample')) or
        stage=='big' and (key=='Tag1' and n==2 or key:match('^Tag1_resample')) then return position(catalog.tags,'UNAVAILABLE') end
      if stage=='voucher' and (key=='Voucher1' or key:match('^Voucher1_resample')) then return position(catalog.vouchers,'UNAVAILABLE') end
      if stage=='shop' and (key=='Planetsho1' or key:match('^Planetsho1_resample')) then return position(catalog.planets,'UNAVAILABLE') end
    end}
    controlled({default=row});local full,why=baseline(F.catalog,normal)
    eq(full,nil,'full required '..stage..' resample failure')
    controlled({default=row});local found=M.search(F.catalog,normal)
    eq(found.status,'unsupported',stage..' remains required');eq(found.reason,why);eq(found.tested,0);eq(found.next_index,nil)
  end
  local rejected={voucher='v_grabber',override=function(key,n,catalog)
    if key=='Planetsho1' or key:match('^Planetsho1_resample') then return position(catalog.planets,'UNAVAILABLE') end
  end}
  controlled({default=rejected});eq(baseline(F.catalog,normal),nil,'public predictor retains hypothetical downstream failure')
  local counts=controlled({default=rejected});local found=M.search(F.catalog,normal)
  eq(found.status,'not_found','proved wrong voucher does not require hypothetical downstream unsupported generation')
  eq(found.tested,1);eq(found.next_index,1);eq(counts.Planetsho1,nil,'irrelevant branch is not executed or imputed')
  local malformed=copy(F.catalog);malformed.boosters={}
  counts=controlled({default={voucher='v_grabber',override=function(key) if key=='shop_pack1' then return 0 end end}},malformed)
  found=M.search(malformed,normal)
  eq(found.status,'unsupported','malformed catalog cannot enter optimized rejection path')
  eq(found.reason,'No supported pack.');check(counts.Planetsho1~=nil,'malformed fallback retains full required generation')
  local sparse=copy(F.catalog);sparse.boosters={[1]=sparse.boosters[1],[3]=sparse.boosters[3]}
  counts=controlled({default={voucher='v_grabber',override=function(key) if key=='shop_pack1' then return 0 end end}},sparse)
  eq(M.search(sparse,normal).status,'not_found');check(counts.Planetsho1~=nil,'sparse booster arrays retain full-generation fallback')
  local noncanonical=copy(F.catalog);noncanonical.edition_rate=2
  counts=controlled({default={voucher='v_grabber'}},noncanonical)
  eq(M.search(noncanonical,normal).status,'not_found');check(counts.stdset1~=nil,'unrecognized catalog retains full-generation fallback')
end

do
  local rows={default={voucher='v_grabber'},[M.seed_at(2)]={},[M.seed_at(4)]={}}
  local counts,created=controlled(rows);local options=copy(normal);options.limit=6;options.max_matches=2
  local found=M.search(F.catalog,options)
  eq(found.status,'found');eq(found.tested,5);eq(found.next_index,5);eq(#found.matches,2)
  for i=1,5 do eq(created[i],M.seed_at(i-1),'contiguous seed index order') end
  counts,created=controlled(rows);options.max_matches=3
  local partial=M.search(F.catalog,options)
  eq(partial.status,'not_found');eq(partial.tested,6);eq(partial.next_index,6);eq(#partial.matches,2,'not_found retains completed matches')
  for i=1,6 do eq(created[i],M.seed_at(i-1),'no index skipped by gate') end
  controlled(rows);options.start=3;options.limit=2;options.max_matches=1
  found=M.search(F.catalog,options);eq(found.tested,2);eq(found.start,3);eq(found.next_index,5)
end

do
  local catalog=copy(F.catalog);local before=copy(catalog);local signatures=0
  M.catalog_signature=function(c) signatures=signatures+1;return real_signature(c) end
  controlled({default={voucher='v_grabber'}},catalog)
  local options=copy(normal);options.limit=3
  M.search(catalog,options)
  eq(signatures,1,'canonical signature prepared once for a bounded nonmatch call')
  check(equal(catalog,before),'catalog preparation never mutates caller input')
  local callbacks=0;signatures=0
  local rows={default={voucher='v_grabber'},[M.seed_at(64)]={}}
  controlled(rows,catalog);options.limit=65
  local found=M.search(catalog,options,function()
    callbacks=callbacks+1;catalog.boosters[1].weight=catalog.boosters[1].weight+1
  end)
  eq(callbacks,1,'yield cadence stays every64tested indices');eq(found.tested,65);eq(found.status,'found')
  eq(signatures,2,'caller catalog mutation is re-prepared after yield')
  eq(found.matches[1].catalog_signature,real_signature(catalog),'recipe binds catalog actually used after callback')
  controlled({default={}},catalog);options.limit=1;options.start=0
  found=M.search(catalog,options)
  eq(found.matches[1].catalog_signature,real_signature(catalog),'new call cannot reuse stale global catalog cache')
  M.catalog_signature=real_signature
end

M.stream=real_stream;M.catalog_signature=real_signature
math.random,math.randomseed=random,randomseed
print('advisor_jokerless_search_gates: '..checks..' checks passed; controlled operations, no throughput claim')
