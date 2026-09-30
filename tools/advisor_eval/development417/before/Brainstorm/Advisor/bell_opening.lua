-- Cerulean Bell first-hand evidence: every possible forced physical card is
-- covered using already scored legal subsets. No RNG, future draw or rescoring.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,out={},{};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(v[k]) end
  return '{'..table.concat(out,';')..'}'
end
local function id(c)
  local value=c and c.id
  if type(value)=='string' and value~='' or finite(value) then return type(value)..':'..tostring(value) end
end
local function indices(values,n)
  if type(values)~='table' or #values<1 or #values>5 then return nil end
  local seen={}
  for _,i in ipairs(values) do
    if not finite(i) or i%1~=0 or i<1 or i>n or seen[i] then return nil end
    seen[i]=true
  end
  return seen
end
local function subset_count(n,limit)
  local total,term=0,1
  for k=1,math.min(n,limit) do term=term*(n-k+1)/k;total=total+term end
  return total
end
function M.new(state)
  local hand,population=state.hand or {},state.playing_cards or {}
  if #hand<1 or #hand>10 or #population<1 or #population>128 or not state.blind or
      state.blind.key~='bl_final_bell' or state.blind.disabled or not finite(state.blind.chips) or state.blind.chips<=0 then return nil,'Bell needs an active first-hand target and a bounded nonempty population.' end
  local limit=state.hand_limit or 5
  if not finite(limit) or limit%1~=0 or limit<1 or limit>5 then return nil,'Bell played-card limit must be known and bounded.' end
  local joker_ids={}
  for _,j in ipairs(state.jokers or {}) do
    local key=id(j)
    if not key or joker_ids[key] or j.face_down or j.unknown then return nil,'Bell requires a visible unique physical Joker row.' end
    joker_ids[key]=true
  end
  local known,rows={},{}
  for _,card in ipairs(population) do
    local key=id(card);if not key or known[key] then return nil,'Bell requires unique physical population identities.' end
    known[key]=encode(card);rows[#rows+1]=key..'='..known[key]
  end
  table.sort(rows)
  local ids,seen={},{}
  for _,card in ipairs(hand) do
    local key=id(card)
    if not key or seen[key] or not known[key] or known[key]~=encode(card) or
        card.face_down or card.unknown or not finite(card.rank) or type(card.suit)~='string' or
        (card.ability or {}).forced_selection then return nil,'Every possible forced card must be a distinct visible member of the population.' end
    seen[key]=true;ids[#ids+1]=key
  end
  return {hand_ids=ids,population_key=table.concat(rows,'|'),branches={},scored_subsets=0,seen_subsets={},
    max_cards=limit,expected_subsets=subset_count(#ids,limit),
    target=state.blind.chips,order_identity=encode(state.jokers or {}),failed=false}
end
function M.add(collector,selected,result)
  if not collector or collector.failed then return false end
  local chosen=indices(selected,#collector.hand_ids)
  if not chosen or #selected>collector.max_cards or not result or not finite(result.score) or result.score<0 then
    collector.failed='A scored Bell subset is invalid or nonfinite.';return false
  end
  local sorted=copy(selected);table.sort(sorted);local signature=table.concat(sorted,',')
  if collector.seen_subsets[signature] then collector.failed='Repeated subset cannot replace missing Bell coverage.';return false end
  collector.seen_subsets[signature]=true
  collector.scored_subsets=collector.scored_subsets+1
  if result.legal==false then return true end
  if result.legal~=true then collector.failed='Bell subset legality is unavailable.';return false end
  if result.uncertain then collector.failed='Random scoring cannot supply a deterministic Bell branch.';return false end
  for _,warning in ipairs(result.warnings or {}) do
    if warning:find('Unmodeled',1,true) or warning:find('unknown card',1,true) or
        warning:find('not included',1,true) or warning:find('not modeled',1,true) then
      collector.failed='An unmodeled Bell subset cannot supply complete branch evidence.';return false
    end
  end
  for forced in pairs(chosen) do
    local best=collector.branches[forced]
    if not best or result.score>best.score then
      collector.branches[forced]={forced_index=forced,forced_id=collector.hand_ids[forced],
        score=result.score,indices=copy(selected),hand=result.hand,legal=true,uncertain=false}
    end
  end
  return true
end
function M.finish(collector)
  if not collector or collector.failed then return nil,collector and collector.failed or 'Bell collector unavailable.' end
  if collector.scored_subsets~=collector.expected_subsets then return nil,'The complete Bell subset family has not finished.' end
  local low,high,worst=math.huge,0,nil
  for i=1,#collector.hand_ids do
    local branch=collector.branches[i]
    if not branch then return nil,'A possible forced card has no supported legal play.' end
    if branch.score<low then low,worst=branch.score,branch end
    high=math.max(high,branch.score)
  end
  return {schema=1,complete=true,supported=true,uncertain=false,kind='all_forced_held_cards',
    hand_ids=copy(collector.hand_ids),population_key=collector.population_key,branches=copy(collector.branches),
    minimum=low,maximum=high,scored_subsets=collector.scored_subsets,max_cards=collector.max_cards,
    target=collector.target,order_identity=collector.order_identity},copy(worst)
end
function M.bundle(worlds,ordering)
  if #worlds~=4 or not ordering or type(ordering.identity)~='string' or type(ordering.order)~='table' then return nil end
  for _,world in ipairs(worlds) do if world.order_identity~=ordering.identity then return nil end end
  return {schema=1,complete=true,supported=true,uncertain=false,samples=4,worlds=copy(worlds),
    fixed_order=copy(ordering.order),fixed_order_identity=ordering.identity,
    setup_actions=ordering.action_count,score_kind='forced_card_lower_bound',
    scope='One fixed Joker layout across four common composition worlds; every possible first-hand forced card has a supported legal play. Later forced draws and whole-blind continuations remain unresolved.'}
end
local function validate(bundle,target)
  if type(bundle)~='table' or bundle.schema~=1 or not bundle.complete or not bundle.supported or
      bundle.uncertain~=false or bundle.samples~=4 or type(bundle.worlds)~='table' or #bundle.worlds~=4 or
      bundle.score_kind~='forced_card_lower_bound' or type(bundle.fixed_order_identity)~='string' or
      type(bundle.fixed_order)~='table' or (bundle.setup_actions~=0 and bundle.setup_actions~=1) then return nil end
  local order_seen={}
  for _,i in ipairs(bundle.fixed_order) do
    if not finite(i) or i%1~=0 or i<1 or i>#bundle.fixed_order or order_seen[i] then return nil end;order_seen[i]=true
  end
  local lows={}
  for w,world in ipairs(bundle.worlds) do
    if world.schema~=1 or world.complete~=true or world.supported~=true or world.uncertain~=false or
        world.order_identity~=bundle.fixed_order_identity or
        world.kind~='all_forced_held_cards' or world.target~=target or type(world.population_key)~='string' or
        world.population_key=='' or type(world.hand_ids)~='table' or #world.hand_ids<1 or #world.hand_ids>10 or
        type(world.branches)~='table' or #world.branches~=#world.hand_ids or not finite(world.scored_subsets) or
        not finite(world.max_cards) or world.max_cards%1~=0 or world.max_cards<1 or world.max_cards>5 or
        world.scored_subsets~=subset_count(#world.hand_ids,world.max_cards) then return nil end
    local low,high,seen=math.huge,0,{}
    for i,branch in ipairs(world.branches) do
      local key=world.hand_ids[i];local selected=indices(branch.indices,#world.hand_ids)
      if type(key)~='string' or key=='' or seen[key] or branch.forced_id~=key or branch.forced_index~=i or
          branch.legal~=true or branch.uncertain~=false or not finite(branch.score) or branch.score<0 or
          not selected or not selected[i] or #branch.indices>world.max_cards then return nil end
      seen[key]=true;low=math.min(low,branch.score);high=math.max(high,branch.score)
    end
    if world.minimum~=low or world.maximum~=high then return nil end
    lows[w]=low
  end
  return lows
end
function M.compare(before,after,target)
  if not finite(target) or target<=0 then return nil,'Bell target is unavailable.' end
  local a,b=validate(before,target),validate(after,target)
  if not a or not b then return nil,'Incomplete Bell forced-card evidence.' end
  local low,delta=math.huge,math.huge
  for world=1,4 do
    local left,right=before.worlds[world],after.worlds[world]
    if left.population_key~=right.population_key or encode(left.hand_ids)~=encode(right.hand_ids) then
      return nil,'Bell comparisons require the same physical population and forced-card worlds.'
    end
    for i,branch in ipairs(left.branches) do
      local candidate=right.branches[i]
      low=math.min(low,candidate.score);delta=math.min(delta,candidate.score-branch.score)
    end
  end
  return {minimum_after=low,minimum_delta=delta,before_scores=a,after_scores=b,
    complete=true,scope='Every common forced physical identity, with one fixed layout per endpoint.'}
end
return M
