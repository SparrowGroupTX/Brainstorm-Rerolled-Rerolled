-- A small nested redraw policy for the final playable hand. The next discard
-- may depend on the first observed draw, never on the still-unknown second draw.
local M={}
local min,max,floor=math.min,math.max,math.floor
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function list(t) local r={};for i,v in ipairs(t or {}) do r[i]=v end;return r end
local function key(t) return table.concat(t or {},',') end
local function reliable(p,target)
  return p and p.legal~=false and not p.uncertain and type(p.score)=='number' and p.score==p.score and p.score<math.huge and p.score>=target
end
local function hidden(s)
  for _,c in ipairs(s.hand or {}) do if c.face_down then return true end end
  return false
end
local function merit(s,indices)
  local removed,ranks,suits,values={},{},{},{}
  for _,i in ipairs(indices) do removed[i]=true end
  local score=0
  for i,c in ipairs(s.hand) do if not removed[i] then
    local r=c.rank or 0;ranks[r]=(ranks[r] or 0)+1
    suits[c.suit or '?']=(suits[c.suit or '?'] or 0)+1;values[r]=true
    if c.enhancement=='m_steel' then score=score+4 end
  end end
  local largest=0;for _,n in pairs(ranks) do largest=max(largest,n) end
  score=score+largest*largest*5
  largest=0;for _,n in pairs(suits) do largest=max(largest,n) end
  if largest>=3 then score=score+largest*largest*2 end
  local run=0;for start=1,10 do local n=0;for r=start,start+4 do if values[r==1 and 14 or r] then n=n+1 end end;run=max(run,n) end
  if run>=3 then score=score+run*3 end
  return score+#indices*0.25
end

function M.discard_candidates(s,preferred,limit,options)
  options=options or {}
  limit=min(3,max(1,num(limit,3)))
  local candidates,out,seen={}, {},{}
  local maximum=min(5,num(s.hand_limit,5),#s.hand)
  local forced={};for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection then forced[i]=true end end
  local function valid(indices)
    if not indices or #indices==0 or #indices>maximum then return false end
    local used={};for _,i in ipairs(indices) do if not s.hand[i] or used[i] or
      options.keep_purple and s.hand[i].seal=='Purple' then return false end;used[i]=true end
    for i in pairs(forced) do if not used[i] then return false end end
    return true
  end
  local function add(indices)
    if not valid(indices) or #out>=limit then return end
    indices=list(indices);table.sort(indices);local k=key(indices)
    if not seen[k] then seen[k]=true;out[#out+1]={indices=indices,key=k,merit=merit(s,indices)} end
  end
  add(preferred)
  local chosen={}
  local function walk(start)
    if valid(chosen) then candidates[#candidates+1]={indices=list(chosen),merit=merit(s,chosen)} end
    if #chosen==maximum then return end
    for i=start,#s.hand do chosen[#chosen+1]=i;walk(i+1);chosen[#chosen]=nil end
  end
  walk(1)
  table.sort(candidates,function(a,b)
    if a.merit~=b.merit then return a.merit>b.merit end
    return key(a.indices)<key(b.indices)
  end)
  if candidates[1] then add(candidates[1].indices) end
  -- Include a different redraw size when possible, instead of spending all
  -- three positions on equivalent one-card or five-card variants.
  local represented={};for _,c in ipairs(out) do represented[#c.indices]=true end
  for _,c in ipairs(candidates) do if not represented[#c.indices] then add(c.indices);represented[#c.indices]=true;if #out>=limit then break end end end
  for _,c in ipairs(candidates) do add(c.indices);if #out>=limit then break end end
  return out
end

local function permutation(deck,seed,outcomes,turn)
  local ranked={}
  for i,c in ipairs(deck or {}) do
    ranked[#ranked+1]={card=c,id=tostring(c.id or i)}
  end
  table.sort(ranked,function(a,b) return a.id<b.id end)
  local ordered={};for i,item in ipairs(ranked) do ordered[i]=item.card end
  seed=(seed+turn*104729)%4294967296
  for i=#ordered,2,-1 do
    seed=(seed*1664525+1013904223)%4294967296
    local j=seed%i+1;ordered[i],ordered[j]=ordered[j],ordered[i]
  end
  return ordered
end

function M.suggest(s,modules,result,yield_fn,options)
  options=options or {};result=result or {};modules=modules or {}
  local diag={evaluations=0,max_evaluations=min(12000,max(0,floor(num(options.max_evaluations,12000)))),
    outer_samples=4,inner_samples=4,first_limit=3,second_limit=3,complete=false,
    scope='nested 4 outer x 4 conditional inner samples; not 16 independent episodes',heuristic=true}
  local function no(reason) diag.reason=reason;return nil,diag.evaluations,diag end
  local target=max(1,num((s.blind or {}).chips)-num(s.chips))
  if num(s.hands_left,(s.current_round or {}).hands_left)~=1 or num(s.discards_left)<2 or #(s.deck or {})==0 then return no('Two-discard horizon requires one playable hand and at least two discards.') end
  if #(s.hand or {})>10 or #(s.hand or {})<1 or #s.deck>120 or hidden(s) then return no('Hand visibility or state size is outside the bounded horizon.') end
  local identities={}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    if c.id==nil or identities[c.id] then return no('Distinct physical card identities are required for common composition draws.') end
    identities[c.id]=true
  end end
  if reliable(result.play,target) then return no('A reliable current finish already exists.') end
  for _,field in ipairs({'consumable','ordering','hand_ordering','boss_rescue','mixed_rescue','growth'}) do
    if result[field] then return no('An existing tactical or investment action takes priority.') end
  end
  local scorer,search,draws,outcomes=modules.scoring,modules.search,modules.draws,modules.sampled_outcomes
  if not scorer or not scorer.after_discard or not search or not search.obvious_candidates or not draws or not outcomes then return no('Exact discard and sampled draw dependencies unavailable.') end
  local play_limit=min(24,max(1,floor(num(options.play_candidates,24))))
  diag.play_candidates=play_limit
  local aborted
  local function best_play(state)
    if hidden(state) or #state.hand>10 then aborted='A sampled hand is concealed or exceeds the bounded hand size.';return nil end
    local candidates=search.obvious_candidates(state,min(5,num(state.hand_limit,5)))
    local best
    for i=1,min(play_limit,#candidates) do
      if diag.evaluations>=diag.max_evaluations then aborted='The score budget cannot complete every paired sample.';return nil end
      diag.evaluations=diag.evaluations+1
      if yield_fn and diag.evaluations%64==0 then yield_fn() end
      local p=scorer.score(state,candidates[i])
      if p and p.legal~=false then
        if type(p.score)~='number' or p.score~=p.score or p.score<0 or p.score==math.huge then
          aborted='A sampled score was not finite and nonnegative.';return nil
        end
        if p.uncertain then aborted='Random or unsupported score estimates cannot establish this discard comparison.';return nil end
        if not best or num(p.score)>num(best.score) then best=p end
        if reliable(p,target) then return {probability=1,utility=1} end
      end
    end
    return {probability=0,utility=min(1,max(0,best and num(best.score)/target or 0))}
  end
  local function draw(after,seed,turn)
    local order=permutation(after.deck,seed,outcomes,turn)
    local bell=floor(outcomes.roll(seed,turn,'nested-bell',0)*1000000)
    return outcomes.fill(after,order,scorer,draws,seed,turn,bell)
  end
  local candidates=M.discard_candidates(s,result.discard and result.discard.indices,3)
  local prepared={}
  for _,candidate in ipairs(candidates) do
    local after,reason=scorer.after_discard(s,candidate.indices)
    if after then candidate.after=after;candidate.probability=0;candidate.utility=0;candidate.one_step=0;candidate.second_actions=0;prepared[#prepared+1]=candidate
    elseif result.discard and key(candidate.indices)==key(result.discard.indices) then return no('The incumbent discard transition is unsupported: '..tostring(reason)) end
  end
  if #prepared<2 then return no('Fewer than two supported first discards can be compared.') end
  local incumbent=prepared[1]
  if result.discard and incumbent.key~=key(result.discard.indices) then return no('The incumbent discard must be present in every paired set.') end
  local seeds={2718281,3141593,1618033,1414213}
  for outer,seed in ipairs(seeds) do
    local observations={}
    for ci,candidate in ipairs(prepared) do
      local observed,why=draw(candidate.after,seed,1)
      if not observed then return no(why) end
      local immediate=best_play(observed);if not immediate then return no(aborted) end
      local chosen={probability=immediate.probability,utility=immediate.utility,second=false}
      if immediate.probability==0 and num(observed.discards_left)>0 and #observed.deck>0 then
        local second=M.discard_candidates(observed,nil,3)
        for _,option in ipairs(second) do
          local after=scorer.after_discard(observed,option.indices)
          if after then
            local score,wins=0,0
            for inner=1,4 do
              -- The second action is fixed before inspecting any inner draw.
              -- Each option shares these independent conditional seed keys.
              local next_state,reason=draw(after,seed+inner*104729,2)
              if not next_state then return no(reason) end
              local outcome=best_play(next_state);if not outcome then return no(aborted) end
              wins=wins+outcome.probability;score=score+outcome.utility
            end
            local p,u=wins/4,score/4
            if p>chosen.probability or p==chosen.probability and u>chosen.utility+0.02 then
              chosen={probability=p,utility=u,second=true,indices=option.indices}
            end
          end
        end
      end
      observations[ci]={probability=chosen.probability,utility=chosen.utility,one_step=immediate.probability,second=chosen.second}
    end
    -- Commit an outer observation only after every first candidate and every
    -- considered second option has completed its full paired inner set.
    for ci,c in ipairs(prepared) do local v=observations[ci]
      c.probability=c.probability+v.probability/4;c.utility=c.utility+v.utility/4
      c.one_step=c.one_step+v.one_step/4;c.second_actions=c.second_actions+(v.second and 0.25 or 0)
    end
    diag.completed_outer=outer
  end
  diag.complete=true;diag.candidates={}
  local best=incumbent
  for _,c in ipairs(prepared) do
    diag.candidates[#diag.candidates+1]={indices=list(c.indices),probability=c.probability,utility=c.utility,
      one_step=c.one_step,expected_second_actions=c.second_actions}
    if c.probability>best.probability or c.probability==best.probability and c.utility>best.utility+0.02 then best=c end
  end
  diag.baseline_probability=incumbent.probability;diag.baseline_one_step=incumbent.one_step
  diag.estimated_probability=best.probability;diag.uplift=best.probability-incumbent.probability
  if best==incumbent then return no('The incumbent first discard remains best under the nested comparison.') end
  if diag.uplift<max(0.125,num(options.minimum_uplift,0.125)) then return no('The paired nested survival uplift is too small to change the first discard.') end
  -- Equal-depth paths have the same first discard charge; extra second uses
  -- still need worthwhile survival benefit when a challenge charges cash.
  local extra_cost=num((s.modifiers or {}).discard_cost)*max(0,best.second_actions-incumbent.second_actions)
  if diag.uplift<0.125+min(0.25,extra_cost*0.025) then return no('Additional paid discards require a larger estimated survival gain.') end
  local suggestion={action={kind='discard',area='hand',indices=list(best.indices)},indices=list(best.indices),
    probability=best.probability,baseline_probability=incumbent.probability,
    reason=string.format('Plan across two discards: the bounded nested estimate improves from %.0f%% to %.0f%%. Execute this discard, then refresh after the actual draw; no later cards are assumed known.',incumbent.probability*100,best.probability*100),
    scope=diag.scope,heuristic=true}
  return suggestion,diag.evaluations,diag
end

return M
