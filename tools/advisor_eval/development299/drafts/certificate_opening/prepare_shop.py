"""Create Certificate-specific detached shop draft, separate from Bell merge."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
p=ROOT/'Brainstorm/Advisor/shop_scoring.lua'
s=p.read_text(encoding='utf-8')
def patch(old,new):
    global s
    assert s.count(old)==1,old
    s=s.replace(old,new)
patch('  local root_hands=round_resources(root_snapshot)', '''  local certificate_family=false
  for _,area in ipairs({root_snapshot.jokers or {},root_snapshot.shop_jokers or {},root_snapshot.pack_cards or {}}) do
    for _,card in ipairs(area) do if card.key=='j_certificate' then certificate_family=true end end
  end
  local root_hands=round_resources(root_snapshot)''')
patch('    local row,startup={},false','    local row,startup,first_draw={},false,false')
patch("      if (skip_rows[j.key] or skip_rows[name(j)]) and not supported then return unavailable('Blind-start Joker changes are left to the existing strategy.') end\n      startup=startup or supported",'''      local certificate=Shop.certificate and j.key=='j_certificate'
      if (skip_rows[j.key] or skip_rows[name(j)]) and not supported and not certificate then return unavailable('Blind-start Joker changes are left to the existing strategy.') end
      startup=startup or supported or certificate;first_draw=first_draw or certificate''')
patch("    if #row>12 then return unavailable('Large Joker rows are outside this scoring budget.') end",'''    if #row>12 then return unavailable('Large Joker rows are outside this scoring budget.') end
    if first_draw then
      if not certificate_family then return unavailable('Certificate must be declared in the complete root comparison family.') end
      if upcoming and upcoming.key=='bl_final_bell' then return unavailable('Certificate generation plus Bell forced selection needs a complete joint branch model.') end
      for _,j in ipairs(row) do if Shop.blind_start and Shop.blind_start.supports(j) then
        return unavailable('Combined setting-blind and Certificate first-draw generation is outside this scope.')
      end end
    end''')
patch('      temporal=temporal,shortlisted=shortlisted,has_copies=has_copies,cost=4*#selections*#layouts*#scenarios}',
      '      temporal=temporal,shortlisted=shortlisted,has_copies=has_copies,certificate_first_draw=first_draw,cost=4*#selections*#layouts*#scenarios}')
patch('          local projected,diagnostics=Shop.blind_start.project(setup,{sample_index=sample})', '''          local projected,diagnostics
          if first_draw then
            local drawn=clone(setup);drawn.hand,drawn.deck={},{}
            for i,index in ipairs(plan_draws[sample]) do
              local target=i<=drawn.hand_size and drawn.hand or drawn.deck
              target[#target+1]=drawn.playing_cards[index]
            end
            projected,diagnostics=Shop.certificate.project(drawn,s.certificate_pool,sample)
            if diagnostics and type(diagnostics)=='table' then diagnostics.requires_card_debuff_refresh=true end
          else projected,diagnostics=Shop.blind_start.project(setup,{sample_index=sample}) end''')
patch('          local n=math.floor(projected.hand_size)',
      '          local n=first_draw and #projected.hand or math.floor(projected.hand_size)')
patch('          local permutation,why=paired:sample(projected.playing_cards,sample,encode(projected.playing_cards)==root_key)',
      '          local permutation,why\n          if not first_draw then permutation,why=paired:sample(projected.playing_cards,sample,encode(projected.playing_cards)==root_key) else permutation={} end')
patch('          projected.hand,projected.deck={},{}\n          for i,index in ipairs(permutation) do\n            local target=i<=n and projected.hand or projected.deck;target[#target+1]=projected.playing_cards[index]\n          end',
      '          if not first_draw then\n            projected.hand,projected.deck={},{}\n            for i,index in ipairs(permutation) do\n              local target=i<=n and projected.hand or projected.deck;target[#target+1]=projected.playing_cards[index]\n            end\n          end')
patch('          state=trials[1].state,startup={order=clone(plan.orders[layout]),samples={}}}',
      '          state=trials[1].state,generation_composition_samples=plan.certificate_first_draw,scoring_uncertain=false,\n          startup={order=clone(plan.orders[layout]),samples={}}}')
patch('              value.uncertain=value.uncertain or result.uncertain',
      '              value.uncertain=value.uncertain or result.uncertain\n              value.scoring_uncertain=value.scoring_uncertain or result.uncertain')
patch('    if not upcoming or value.uncertain and not (not value.startup and value.supported_random_choices) then',
      '    if not upcoming or value.uncertain and not (not value.startup and value.supported_random_choices or\n      value.generation_composition_samples and not value.scoring_uncertain) then')
# Locate the exact call before replacing so a future API change fails closed.
old='Shop.blind_finishing.forecast(value.worlds,scorer,charge)'
assert old in s
s=s.replace(old,'Shop.blind_finishing.forecast(value.worlds,scorer,charge,{keep_purple=certificate_family,certificate_samples=certificate_family})')
patch('    if not upcoming or target<=0 or hidden or value.uncertain and not (not value.startup and value.supported_random_choices) then',
      '    if not upcoming or target<=0 or hidden or value.uncertain and not (not value.startup and value.supported_random_choices or\n      value.generation_composition_samples and not value.scoring_uncertain) then')
patch("    if complete_finishing then scope=scope..'; complete paired whole-blind policy progress informs build value' end",'''    if complete_finishing then scope=scope..'; complete paired whole-blind policy progress informs build value' end
    if certificate_family then scope=scope..'; Certificate uses four declared front/seal composition worlds, not all208 outcomes; both policies retain Purple cards on discard, unknown Tarot branches omitted' end''')
patch('      low_sample_delta=low,uncertain=a.uncertain or b.uncertain or temporal~=nil,',
      '      low_sample_delta=low,uncertain=a.uncertain or b.uncertain or temporal~=nil,\n      certificate_composition_family=certificate_family,complete_generation_distribution=false,')
with (HERE/'shop_scoring.lua').open('x',encoding='utf-8',newline='\n') as f:f.write(s)
with (HERE/'shop_base.json').open('x',encoding='utf-8') as f:json.dump({'shop_scoring.lua':hashlib.sha256(p.read_bytes()).hexdigest()},f,indent=2)
