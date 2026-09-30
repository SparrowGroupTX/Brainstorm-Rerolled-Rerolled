"""Build detached Bell integration drafts; no shared runtime/test edits."""
from pathlib import Path
import hashlib
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
base = {}
def read(name):
    path = ROOT / 'Brainstorm/Advisor' / name
    base[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return path.read_text()
def change(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)
def create(name, value):
    with (HERE / name).open('x', encoding='utf-8', newline='\n') as stream: stream.write(value)

s = read('shop_scoring.lua')
s = change(s, "bl_final_leaf='Verdant Leaf',", "bl_final_leaf='Verdant Leaf',bl_final_bell='Cerulean Bell',")
s = change(s, "  local function prepare(s,temporal)\n", "  local bell=upcoming and upcoming.key=='bl_final_bell'\n  local function prepare(s,temporal)\n    if bell and not Shop.bell_opening then return unavailable('Complete Bell forced-card comparisons are unavailable.') end\n")
s = change(s, "    if #row>12 then return unavailable('Large Joker rows are outside this scoring budget.') end", "    if #row>12 then return unavailable('Large Joker rows are outside this scoring budget.') end\n    if bell and startup then return unavailable('Bell first-hand branches do not include blind-start creation, destruction or disabling.') end")
s = change(s, '    if Shop.blind_finishing then for index,order in ipairs(plan.orders) do',
               '    if Shop.blind_finishing or bell then for index,order in ipairs(plan.orders) do')
s = change(s, '        order=clone(order),identity=encode(row),changed=changed}',
               '        order=clone(order),identity=encode(row),changed=changed,bell_worlds=bell and {} or nil}')
s = change(s, '        local opening_play,order_best,order_hand,order_size\n', '''        local opening_play,order_best,order_hand,order_size
        local forced
        if bell then
          local why;forced,why=Shop.bell_opening.new(trial)
          if not forced then cache[plan.key]=false;return unavailable(why) end
        end
''')
s = change(s, '          uncertain=uncertain or result.uncertain\n', '''          if forced and not Shop.bell_opening.add(forced,selected,result) then
            cache[plan.key]=false;return unavailable(forced.failed)
          end
          uncertain=uncertain or result.uncertain
''')
s = change(s, '        if Shop.blind_finishing then\n          local candidate=fixed[order_index]', '''        if forced then
          local branches,worst=Shop.bell_opening.finish(forced)
          if not branches then cache[plan.key]=false;return unavailable(worst) end
          fixed[order_index].bell_worlds[draw]=branches
          order_best,order_hand,order_size=branches.minimum,worst.hand,#worst.indices
          opening_play={score=branches.minimum,hand=worst.hand,indices=clone(worst.indices),legal=true,uncertain=false}
        end
        if Shop.blind_finishing or bell then
          local candidate=fixed[order_index]''')
s = change(s, '''    if Shop.blind_finishing then
      -- One fixed arrangement is chosen once across ALL four common worlds,''', '''    if Shop.blind_finishing or bell then
      -- One fixed arrangement is chosen once across ALL four common worlds,''')
s = change(s, '''        scope='Legal projected first-hand reorder, then one fixed observed continuation; future actions require fresh advice.'}
    end
    context.metrics.completed_profiles''', '''        scope='Legal projected first-hand reorder, then one fixed observed continuation; future actions require fresh advice.'}
      if bell then
        value.ordering.selection='one_fixed_layout_by_complete_forced_card_floor_mean'
        value.bell_opening=Shop.bell_opening.bundle(best.bell_worlds,value.ordering)
        if not value.bell_opening then cache[plan.key]=false;return unavailable('Bell fixed-order evidence is incomplete.') end
      end
    end
    context.metrics.completed_profiles''')
s = change(s, '  local function temporal_for(before,after)\n', "  local function temporal_for(before,after)\n    if bell then return nil end -- first-hand branches never invent later Card Sharp/discard conditions\n")
s = change(s, '  local function finishing(plan,value)\n', '''  local function finishing(plan,value)
    if bell then return {complete=false,supported=false,reason='Bell evidence covers every possible first forced card only; later forced selections remain unresolved.'} end
''')
s = change(s, '''    if Shop.blind_finishing then
      status=complete and''', '''    if Shop.blind_finishing and not bell then
      status=complete and''')
s = change(s, '      ordering=clone(value.ordering),\n', '      ordering=clone(value.ordering),bell_opening=clone(value.bell_opening),\n')
s = change(s, '''    if Shop.blind_finishing then
      result.finishing=clone(finish)''', '''    if Shop.blind_finishing and not bell then
      result.finishing=clone(finish)''')
s = change(s, '''    return result
  end
  function context:readiness''', '''    if bell then
      result.finishing=clone(finish);result.finishing_basis='first_hand_forced_branches_only'
      result.score_kind='forced_card_lower_bound'
      result.reason='All possible first-hand forced cards are compared within each composition world and one fixed Joker layout. Reported scores are lower bounds over those choices; later draws and forced selections remain unresolved.'
    end
    return result
  end
  function context:readiness''')
s = change(s, '''    local low=math.huge
    for i=1,4 do low=math.min(low,b.scores[i]-a.scores[i]) end''', '''    local low=math.huge
    for i=1,4 do low=math.min(low,b.scores[i]-a.scores[i]) end
    local forced_comparison
    if bell then
      local why;forced_comparison,why=Shop.bell_opening.compare(a.bell_opening,b.bell_opening,left_target)
      if not forced_comparison or left_target~=right_target then return unavailable(why or 'Bell targets differ.') end
      low=math.min(low,forced_comparison.minimum_delta)
    end''')
s = change(s, "    local scope='Opening-hand scoring estimate'", "    local scope=bell and 'First-hand lower bound over all possible forced cards' or 'Opening-hand scoring estimate'")
s = change(s, '      before_readiness=before_readiness,after_readiness=after_readiness,work_cost=work_cost,',
               "      before_readiness=before_readiness,after_readiness=after_readiness,work_cost=work_cost,\n      forced_comparison=clone(forced_comparison),score_kind=bell and 'forced_card_lower_bound' or nil,")
create('shop_scoring.lua', s)

g=read('gold_goal.lua')
g=change(g,'local function opening(e,target)', 'local function opening(e,target,boss,bell)')
g=change(g,'  return after_low,math.min(delta,e.low_sample_delta)\n', '''  if boss=='bl_final_bell' then
    if not bell or not bell.compare or e.score_kind~='forced_card_lower_bound' then return nil end
    local forced=bell.compare(e.before_readiness.bell_opening,e.after_readiness.bell_opening,target)
    if not forced then return nil end
    for i=1,4 do
      if forced.before_scores[i]~=e.before_readiness.opening_scores[i] or
          forced.after_scores[i]~=e.after_readiness.opening_scores[i] then return nil end
    end
    after_low=math.min(after_low,forced.minimum_after);delta=math.min(delta,forced.minimum_delta)
  end
  return after_low,math.min(delta,e.low_sample_delta)
''')
g=change(g,"not ({bl_final_vessel=true,bl_final_leaf=true})[b.key]", "not ({bl_final_vessel=true,bl_final_leaf=true,bl_final_bell=true})[b.key]")
g=change(g,"  local strategy=modules.strategy;local api=strategy and strategy.shop_sequence_api", "  if b.key=='bl_final_bell' and not modules.bell_opening then return no('Complete Bell forced-card dependencies are required.') end\n  local strategy=modules.strategy;local api=strategy and strategy.shop_sequence_api")
g=change(g,'local low,delta=opening(e,b.chips)', 'local low,delta=opening(e,b.chips,b.key,modules.bell_opening)')
g=change(g,"      'All four supported sampled openings clear the final boss with at least 25% margin and no lower sampled chips than keeping the current row or taking the current recommendation.',", "      b.key=='bl_final_bell' and 'Every possible forced card in all four sampled first hands clears with at least 25% margin and no lower chips for the same forced identity. One fixed Joker layout is used per endpoint; later forced draws remain unresolved.' or\n      'All four supported sampled openings clear the final boss with at least 25% margin and no lower sampled chips than keeping the current row or taking the current recommendation.',")
create('gold_goal.lua',g)
create('integration_base_sha256.json',json.dumps(base,indent=2)+'\n')
print('Created detached Bell draft; runtime/tests unchanged.')
