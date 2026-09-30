-- Complete, finite immediate play/order comparison over a public slot belief.
-- This first component handles a final ordinary-card hand, with no consumables.
local M={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function list(x) local r={};for i,v in ipairs(x or {}) do r[i]=v end;return r end
function M.suggest(s,b,scorer,belief,options)
  options=options or {};local diag={evaluations=0,complete=false,worlds=b and b.worlds and #b.worlds or 0,
    terminal_evidence=false,scope='All fixed slot permutations and public legal subsets over every consistent inventory world; immediate final-hand clear only.'}
  local function no(reason) diag.reason=reason;return nil,diag.evaluations,diag end
  if not belief or not belief.validate(b) or b.state_valid~=true then return no('Current public inventory abilities are not qualified.') end
  if s.phase~='hand' or s.hands_left~=1 or s.discards_left~=0 or #(s.consumeables or {})>0 or
    #(s.hand or {})<1 or #s.hand>8 or s.jokers_shuffling or s.ordering_safe==false then
    return no('The first belief comparison requires a settled final visible hand without remaining discards or consumables.') end
  if not scorer or not scorer.score or not finite(s.chips) or not finite((s.blind or {}).chips) then return no('Exact scoring and target resources are required.') end
  local target=s.blind.chips-s.chips;if target<=0 then return no('The round is already cleared.') end
  for _,c in ipairs(s.hand) do
    if c.face_down or c.unknown or c.concealed or c.facing=='back' or c.enhancement and c.enhancement~='c_base' or c.edition or c.seal then
      return no('Only ordinary fully visible cards enter this immediate comparison.') end
  end
  -- Ignore the raw live Joker array even if a caller supplied concealed payloads.
  local root={};for k,v in pairs(s) do if k~='jokers' and k~='public_joker_belief' then root[k]=belief.copy(v) end end
  local selected,subsets={},{};local maximum=math.min(5,s.hand_limit or 5)
  local function walk(start)
    if #selected>0 then
      local ok=true;for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection then
        local found=false;for _,index in ipairs(selected) do if i==index then found=true end end;ok=ok and found
      end end
      if ok then subsets[#subsets+1]=list(selected) end
    end
    if #selected>=maximum then return end
    for i=start,#s.hand do selected[#selected+1]=i;walk(i+1);selected[#selected]=nil end
  end
  walk(1)
  local orders=belief.permutations(#b.inventory,720)
  local budget=math.min(30000,math.max(0,math.floor(options.max_evaluations or 30000)))
  local needed=#orders*#subsets*#b.worlds
  diag.orders=#orders;diag.subsets=#subsets;diag.required_evaluations=needed;diag.max_evaluations=budget
  if needed==0 or needed>budget then return no('The entire common-world/order/play family does not fit the existing allowance.') end
  local profiles={}
  for oi,order in ipairs(orders) do
    profiles[oi]={}
    for pi,indices in ipairs(subsets) do
      local profile={order=list(order),indices=list(indices),scores={},minimum=math.huge,legal=true}
      for wi,world in ipairs(b.worlds) do
        local state=belief.copy(root);state.jokers={}
        for position,oldslot in ipairs(order) do
          local ordinal=world[oldslot];local j=belief.copy(b.inventory[ordinal]);j.id='public-belief:'..ordinal;j.face_down=false
          state.jokers[position]=j
        end
        local result=scorer.score(state,indices);diag.evaluations=diag.evaluations+1
        if not result or result.uncertain or type(result.warnings)=='table' and #result.warnings>0 or
          result.legal~=false and not finite(result.score) then return no('An admitted world lacks a supported exact score; no partial comparison is published.') end
        if result.legal==false then profile.legal=false;profile.minimum=-math.huge;profile.scores[wi]=false
        else profile.scores[wi]=result.score;profile.minimum=math.min(profile.minimum,result.score) end
      end
      profiles[oi][pi]=profile
    end
  end
  diag.complete=true;diag.profiles=profiles
  for _,profile in ipairs(profiles[1]) do if profile.legal and profile.minimum>=target then
    return {kind='play',action={kind='play',area='hand',indices=profile.indices},minimum_score=profile.minimum,
      lines={'This fixed play reaches the modeled target in every consistent public Joker order.'}},diag.evaluations,diag
  end end
  for oi=2,#orders do for _,profile in ipairs(profiles[oi]) do if profile.legal and profile.minimum>=target then
    return {kind='reorder_jokers',action={kind='reorder_jokers',order=profile.order},projected_play={indices=profile.indices,score=profile.minimum},
      minimum_score=profile.minimum,belief_epoch=b.epoch,belief_revision=b.revision,
      lines={'Move the current visible slots into this order, then refresh advice.',
        'The same proposed hand reaches the modeled target in every remaining public identity world.'}},diag.evaluations,diag
  end end end
  return no('No fixed immediate clear exists in the completed family; this is not terminal validation.')
end
return M
