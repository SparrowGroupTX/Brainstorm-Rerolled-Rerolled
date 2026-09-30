-- A narrow free-pack survival priority, using completed common-world evidence.
-- This is not a Pareto claim over future runs or a calibrated win probability.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function ordinary(card)
  local a=card and card.ability
  return card and type(a)=='table' and a.set=='Joker' and not card.unknown and not card.face_down
    and not a.eternal and not a.rental and not a.perishable and not card.pinned
    and not (card.edition and card.edition.negative)
end
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,out={},{};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(v[k]) end
  return '{'..table.concat(out,';')..'}'
end
local fields={'score','shortfall','progress','hands_used','discards_used','setup_actions','action_count',
  'dollars_after','population_loss','finish_reward'}
local function outcome(row,target)
  if type(row)~='table' or type(row.clear)~='boolean' or type(row.actions)~='table' then return false end
  for _,key in ipairs(fields) do if not finite(row[key]) then return false end end
  if row.score<0 or row.shortfall~=math.max(0,target-row.score) or
      row.clear~=(row.score>=target) or row.progress~=math.min(1,row.score/target) or
      row.action_count~=#row.actions or row.population_loss<0 then return false end
  for _,key in ipairs({'hands_used','discards_used','setup_actions','action_count'}) do
    if row[key]<0 or row[key]%1~=0 then return false end
  end
  return true
end
local function finishing(f,target)
  if type(f)~='table' or f.complete~=true or f.supported~=true or f.known_mechanics~=true or
      type(f.policies)~='table' or #f.policies~=2 or type(f.selected)~='table' then return nil end
  local names,selected={},nil
  for _,p in ipairs(f.policies) do
    if (p.name~='play_only' and p.name~='one_targeted_discard') or names[p.name] or
        type(p.worlds)~='table' or #p.worlds~=4 then return nil end
    names[p.name]=true;local clears=0
    for _,world in ipairs(p.worlds) do
      if not outcome(world,target) then return nil end
      clears=clears+(world.clear and 1 or 0)
    end
    if p.clearing_samples~=clears then return nil end
    if p.name==f.selected.name then
      if encode(p)~=encode(f.selected) then return nil end
      selected=p
    end
  end
  return selected
end
function M.choose(snapshot,candidates,incumbent,diagnostics)
  local d={complete=false,scope='One free ordinary Joker choice: completed paired blind policies before heuristic ratings; no forecast of later-run value.'}
  local function no(reason) d.reason=reason;return nil,d end
  local ctx=snapshot and snapshot._shop_scoring
  if not snapshot or snapshot.phase~='pack' or snapshot.pack_type~='BUFFOON_PACK' or snapshot.pack_choices~=1 or
      not ctx or ctx.truncated or not diagnostics or diagnostics.incomplete then return no('Complete direct free-pack evidence is required.') end
  local offers=snapshot.pack_cards or {}
  if #offers<2 or #offers>4 or #candidates~=#offers or not incumbent or not finite(snapshot.joker_limit) or
      #(snapshot.jokers or {})>=snapshot.joker_limit then return no('This rule admits every direct offer in a single-choice pack with a free ordinary slot.') end
  if type(snapshot.consumeables)~='table' or (snapshot.consumeable_buffer or 0)~=0 then return no('A settled whole consumable inventory is required.') end
  for _,j in ipairs(snapshot.jokers or {}) do
    if j.key=='j_perkeo' and next(snapshot.consumeables) then return no('Nonempty Perkeo exit copying requires complete inventory projection.') end
  end
  local target=(snapshot.next_blind or {}).chips
  if not finite(target) or target<=0 or not finite(snapshot.dollars) or not finite(snapshot.bankrupt_at) then return no('Known blind pressure and cash are required.') end
  local rows,seen,reference,prior={},{}
  for _,c in ipairs(candidates) do
    if not ordinary(c.card) or offers[c.index]~=c.card or seen[c.index] or not finite(c.score) or c.score<=0 or
        c.hand_order or c.planet_dominated_by then return no('An offer has unbounded commitment, unknown identity or no direct supported choice.') end
    seen[c.index]=true
    local e=c.scoring_evidence
    if not e or e.incomplete or e.complete_finishing~=true or e.samples~=4 or e.temporal or
        e.before_target~=target or e.after_target~=target then return no('Every offer needs the same complete whole-blind scope.') end
    local before,after=finishing(e.before_finishing,target),finishing(e.after_finishing,target)
    if not before or not after then return no('A completed policy trajectory or resource receipt is unavailable.') end
    -- A shared context is necessary but not sufficient: verify its actual
    -- baseline trajectories match too, including actions, rewards and cash.
    local key=encode(e.before_finishing)
    if reference and key~=reference then return no('The offers were evaluated against different baseline worlds.') end
    reference=key;rows[#rows+1]={candidate=c,policy=after}
    if c==incumbent then prior=after end
  end
  if not prior then return no('The actual heuristic incumbent is absent from the full family.') end
  d.complete=true;d.incumbent_index=incumbent.index;d.before_clearing_samples=prior.clearing_samples
  if prior.clearing_samples==4 then return no('The incumbent already clears every sampled world; keep its development preference.') end
  local best
  for _,row in ipairs(rows) do
    local p=row.policy;local acceptable=p.clearing_samples==4
    for world=1,4 do
      local a,b=p.worlds[world],prior.worlds[world]
      -- Do not buy a sampled survival advantage by using more resources or
      -- losing a known finishing reward in any common world.
      acceptable=acceptable and a.progress>=b.progress and a.hands_used<=b.hands_used and
        a.discards_used<=b.discards_used and a.action_count<=b.action_count and
        a.dollars_after>=b.dollars_after and a.dollars_after>=snapshot.bankrupt_at and
        a.population_loss<=b.population_loss and a.finish_reward>=b.finish_reward
    end
    if acceptable and (not best or row.candidate.score>best.candidate.score or
        row.candidate.score==best.candidate.score and row.candidate.index<best.candidate.index) then best=row end
  end
  if not best then return no('No all-clearing candidate preserves the recorded resources and actions in every common world.') end
  d.selected_index=best.candidate.index;d.after_clearing_samples=4
  d.reason='Prefer the free choice clearing every paired world with no worse recorded cash, hands, discards, actions, population loss or finishing reward. Later deck-development value is not proven equal.'
  return best.candidate,d
end
return M
