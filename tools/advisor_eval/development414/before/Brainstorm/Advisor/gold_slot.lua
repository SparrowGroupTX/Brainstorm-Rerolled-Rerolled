-- Preserve replaceable collection slots. A permanently retained completed
-- Joker needs existing exact opening evidence, never a heuristic/core exemption.
-- This module performs no scoring, mutation, I/O, or future action projection.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v>=0 and v%1==0 end
local function plain(v)return type(v)=='table'and getmetatable(v)==nil end
local function dense(v,cap)
 if not plain(v)or #v>cap then return false end
 local n=0;for k in pairs(v)do if not integer(k)or k<1 or k>#v then return false end;n=n+1 end
 return n==#v
end
local function same(a,b)
 local budget,active_a,active_b=20000,{},{}
 local function visit(x,y,depth)
  budget=budget-1
  if budget<0 or depth>32 or type(x)~=type(y)then return false end
  if type(x)~='table'then
   return x==y and (x==nil or type(x)=='boolean'or type(x)=='string'and #x<=262144 or finite(x))
  end
  if not plain(x)or not plain(y)or active_a[x]or active_b[y]then return false end
  active_a[x],active_b[y]=true,true
  for k,v in pairs(x)do
   if not (type(k)=='string'or finite(k))or not visit(v,y[k],depth+1)then return false end
  end
  for k in pairs(y)do if x[k]==nil then return false end end
  active_a[x],active_b[y]=nil,nil;return true
 end
 return visit(a,b,0)
end
local function physical_id(v)return type(v)=='string'and v~=''or finite(v)end
local function visible(c)
 return plain(c)and not(c.unknown or c.face_down or c.identity_redacted or c.concealed or
  c.getting_sliced or c.facing=='back'or c.sprite_facing=='back')
end
local function receipt(applies,allowed,reason)
 return {schema=1,kind='completed_eternal_slot_guard_v1',applies=applies,allowed=allowed,
  reason=reason,additional_score_calls=0,terminal_evidence=false}
end
function M.protected(before,incoming)
 local g=plain(before)and before.completionist_goal
 if not plain(g)or g.schema~=1 or g.goal~='gold_stickers'or not plain(g.eligibility)or g.eligibility.eligible~=true then
  return false,receipt(false,true,'The eligible Completionist++ objective is not active.')
 end
 if g.metadata_status~='complete'or g.catalog_status~='complete'or g.held_status~='complete'or not plain(g.by_key)then
  local d=receipt(false,true,'Collection metadata is unknown or incomplete; it is not relabelled as completed.');d.metadata_unknown=true;return false,d
 end
 if not visible(incoming)or not plain(incoming.ability)or incoming.ability.set~='Joker'or type(incoming.key)~='string'then
  return false,receipt(false,true,'The incoming card is not a known visible Joker.')
 end
 local status=plain(g.by_key[incoming.key])and g.by_key[incoming.key].status
 if status~='complete'then
  local d=receipt(false,true,status=='missing'and 'A missing Gold Joker is outside this completed-slot rule.'or
   'This Joker has unknown Gold status; no completed status is inferred.');d.metadata_unknown=status~='missing';return false,d
 end
 local a=incoming.ability;local mods=before.modifiers or {}
 if not plain(mods)then
  local d=receipt(false,true,'The modifier metadata is unknown; permanent-slot status is not inferred.');d.metadata_unknown=true;return false,d
 end
 if a.eternal~=true and mods.all_eternal~=true then return false,receipt(false,true,'This completed Joker remains replaceable.')end
 local e=incoming.edition
 if e=='negative'or plain(e)and (e.negative==true or e.type=='negative')then
  return false,receipt(false,true,'A Negative Joker does not consume an ordinary collection slot.')
 end
 if e~=nil and type(e)~='string'and not plain(e)then
  local d=receipt(false,true,'The edition metadata is unknown; ordinary-slot status is not inferred.');d.metadata_unknown=true;return false,d
 end
 return true,receipt(true,false,'Keep this ordinary slot replaceable; the already-Gold Eternal needs supported next-blind evidence.')
end
local function exact_append(before,card,after)
 if not plain(after)or (before.phase~='shop'and before.phase~='pack')or after.phase~=before.phase or
  not dense(before.jokers,12)or not dense(after.jokers,12)or #after.jokers~=#before.jokers+1 or
  not integer(before.joker_limit)or after.joker_limit~=before.joker_limit or #after.jokers>after.joker_limit or
  not physical_id(card.id)then return nil,'Only one legal direct acquisition with unchanged original slots is qualified.'end
 local seen={}
 for i,j in ipairs(before.jokers)do
  if not visible(j)or not physical_id(j.id)or seen[tostring(j.id)]or j.id==card.id or not same(j,after.jokers[i])then
   return nil,'Original physical Jokers must be unchanged; a sale or unrelated row change needs a separate complete policy.'
  end
  seen[tostring(j.id)]=true
 end
 if not same(card,after.jokers[#after.jokers])then return nil,'The actual appended physical offer must match the compared card.'end
 for _,field in ipairs({'consumeables','playing_cards','hands','hand_size','hand_limit','probabilities','round_resets',
  'modifiers','next_blind','used_vouchers','vouchers','interest_amount','interest_cap','bankrupt_at','consumeable_usage_total'})do
  if not same(before[field],after[field])then return nil,'The direct comparison changed protected inventory, population, development or resources.'end
 end
 if not dense(before.consumeables,128)or not dense(before.playing_cards,520)or
  not integer(before.consumable_limit)or before.consumable_limit<#before.consumeables or
  after.consumable_limit~=before.consumable_limit or before.consumeable_buffer~=0 or after.consumeable_buffer~=0 then
  return nil,'Exact whole inventory, capacity, buffer and population are required.'
 end
 if not finite(before.dollars)or not finite(after.dollars)or not finite(before.bankrupt_at)or before.bankrupt_at>0 or
  not finite(card.cost)or card.cost<0 then return nil,'Exact affordable cash metadata is required.'end
 local cost=before.phase=='shop'and card.cost or 0
 if after.dollars~=before.dollars-cost or cost>0 and cost>before.dollars-before.bankrupt_at then
  return nil,'The paid or free acquisition cash transition is not exact.'
 end
 return true
end
local function inventory(state)
 local perkeo=false;local gold=M.gold_goal
 if not gold or type(gold.stable_card)~='function'then return nil,'The qualified stable-row classifier is unavailable.'end
 for _,j in ipairs(state.jokers)do
  if not visible(j)or not gold.stable_card(j,M.gold_perkeo,state)then return nil,'An unknown startup or retained-row effect prevents the exception.'end
  perkeo=perkeo or j.key=='j_perkeo'
 end
 if not perkeo or #state.consumeables==0 then return true end
 if state.phase~='shop'or not M.gold_tarot_hold or not M.gold_tarot_hold.certify then
  return nil,'The nonempty Perkeo pool has no qualified fixed-hold shop-exit certificate.'
 end
 local c,why=M.gold_tarot_hold.certify(state)
 if not c or c.schema~=1 or c.supported~=true or c.scope~='fixed_hold_tarot_copy_score_equivalence_v1'or
  c.original_inventory_unchanged~=true or c.first_hand_consumable_actions~=0 or c.generation_used_for_score~=false or
  c.inventory_count_before~=#state.consumeables or c.capacity_before~=state.consumable_limit or
  c.cash_before~=state.dollars or c.cash_after~=state.dollars or not same(c.inventory_before,state.consumeables)then
  return nil,why or 'The whole Perkeo inventory hold proof is unavailable.'
 end
 return true
end
local function current_order(r,count)
 local o=plain(r)and r.ordering
 if not plain(o)or o.action_count~=0 or not dense(o.order,12)or #o.order~=count then return false end
 for i,index in ipairs(o.order)do if index~=i then return false end end
 return true
end
function M.admit(before,incoming,after,evidence)
 local applies,d=M.protected(before,incoming);if not applies then return true,d end
 local function no(why)d.reason=why;return false,d end
 local exact,why=exact_append(before,incoming,after);if not exact then return no(why)end
 for _,s in ipairs({before,after})do local ok,reason=inventory(s);if not ok then return no(reason)end end
 local ctx=before._shop_scoring
 if ctx and ctx.truncated then return no('The shared scoring family is incomplete; no Eternal exception is available.')end
 local b=before.next_blind;local e=evidence;local gold=M.gold_goal
 if not plain(b)or type(b.key)~='string'or not finite(b.chips)or b.chips<=0 or not plain(e)or
  e.uncertain~=false or e.incomplete or e.blind~=b.key or e.boss_fallback or
  not plain(e.common_worlds)or type(e.common_worlds.family_key)~='string'or e.common_worlds.family_key==''or
  not current_order(e.before_readiness,#before.jokers)or not current_order(e.after_readiness,#after.jokers)then
  return no('A complete deterministic common-world comparison of the actual current rows is required.')
 end
 if not gold or type(gold.validate_inventory_opening)~='function'then return no('The complete opening receipt validator is unavailable.')end
 local ok,low,delta=pcall(gold.validate_inventory_opening,e,b.chips,b.key,M.bell_opening)
 if not ok or not finite(low)or not finite(delta)then return no('Uncertain, partial, temporal or startup opening evidence cannot justify a permanent slot.')end
 local before_scores=e.before_readiness.opening_scores
 local after_scores=e.after_readiness.opening_scores
 if not dense(before_scores,4)or not dense(after_scores,4)or #before_scores~=4 or #after_scores~=4 then
  return no('All four exact paired opening scores are required.')
 end
 local short,min_before=0,math.huge
 for i=1,4 do
  if not finite(before_scores[i])or not finite(after_scores[i])then return no('Every opening score must be exact and finite.')end
  min_before=math.min(min_before,before_scores[i])
  if before_scores[i]<b.chips then short=short+1 end
  if after_scores[i]<1.25*b.chips then return no('The candidate does not retain 25% opening margin in every common world.')end
 end
 if short==0 then return no('Holding already clears every sampled opening; greater overkill does not justify an Eternal slot.')end
 local finish=e.before_finishing
 if finish~=nil and not plain(finish)then return no('The existing holding continuation receipt is malformed.')end
 if finish and finish.complete then
  if not plain(finish)or finish.supported~=true or finish.known_mechanics~=true or finish.samples~=4 or
   not plain(finish.selected)or not integer(finish.selected.clearing_samples)or finish.selected.clearing_samples>4 then
   return no('The existing holding continuation receipt is not qualified.')
  end
  if finish.selected.clearing_samples==4 then return no('Holding already has a complete four-world clear; an extra Eternal is not needed for this check.')end
 end
 d.allowed=true;d.reason='This direct acquisition repairs a sampled opening shortfall with at least 25% margin in all four exact common worlds.'
 d.evidence_kind='exact_deterministic_opening_margin';d.samples=4;d.target=b.chips;d.before_min=min_before;d.after_min=low
 d.minimum_delta=delta;d.baseline_short_worlds=short;d.required_margin=1.25;d.family_key_bytes=#e.common_worlds.family_key
 return true,d
end
function M.endpoint(before,after,evidence,actions)
 if not plain(before)or not plain(after)or not dense(before.jokers,12)or not dense(after.jokers,12)then
  local d=receipt(false,true,'The endpoint physical Joker inventory is unknown; this objective guard does not replace legality checks.')
  d.metadata_unknown=true;return true,d
 end
 local owned={};for _,j in ipairs(before.jokers)do
  if not plain(j)then local d=receipt(false,true,'The original physical row is unknown.');d.metadata_unknown=true;return true,d end
  if physical_id(j.id)then owned[tostring(j.id)]=true end
 end
 local protected={}
 for _,j in ipairs(after.jokers)do
  if not plain(j)then local d=receipt(false,true,'The resulting physical row is unknown.');d.metadata_unknown=true;return true,d end
  if not owned[tostring(j.id)]then
  local guarded=M.protected(before,j);if guarded then protected[#protected+1]=j end
 end end
 if #protected==0 then return true,receipt(false,true,'This endpoint adds no protected already-Gold Eternal.')end
 if #protected~=1 or not dense(actions,1)or #actions~=1 then
  return false,receipt(true,false,'A protected Eternal cannot borrow survival credit from an unrelated multi-action sequence.')
 end
 local a=actions[1];local card=plain(a)and a.kind=='buy'and a.area=='shop_jokers'and
  integer(a.index)and a.index>=1 and (before.shop_jokers or {})[a.index]
 if not card or card.id~=protected[1].id or not same(card,protected[1])then
  return false,receipt(true,false,'Only the exact single visible Joker purchase can claim this slot exception.')
 end
 return M.admit(before,card,after,evidence)
end
return M
