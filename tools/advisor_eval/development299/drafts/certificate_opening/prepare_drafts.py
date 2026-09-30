"""Create detached integration drafts; actual runtime remains parent-owned."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
bases={}
def load(name):
    p=ROOT/'Brainstorm/Advisor'/name
    bases[name]=hashlib.sha256(p.read_bytes()).hexdigest()
    return p.read_text(encoding='utf-8')
def patch(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new)
def save(name,text):
    with (HERE/name).open('x',encoding='utf-8',newline='\n') as f:f.write(text)

s=load('snapshot.lua')
s=patch(s,'    normal_opening = M.normal_opening and M.normal_opening.capture(g) or nil,',
    '    normal_opening = M.normal_opening and M.normal_opening.capture(g) or nil,\n    certificate_pool = M.certificate and M.certificate.capture(g) or nil,')
save('snapshot.lua',s)

s=load('multi_discard.lua')
s=patch(s,'function M.discard_candidates(s,preferred,limit)',
    'function M.discard_candidates(s,preferred,limit,options)\n  options=options or {}')
s=patch(s,'local used={};for _,i in ipairs(indices) do if not s.hand[i] or used[i] then return false end;used[i]=true end',
    "local used={};for _,i in ipairs(indices) do if not s.hand[i] or used[i] or\n      options.keep_purple and s.hand[i].seal=='Purple' then return false end;used[i]=true end")
save('multi_discard.lua',s)

s=load('blind_finishing.lua')
s=patch(s,'  if #state.hand<1 or #state.hand>8 or #state.deck>120 or num(state.hand_size)>8 then return false end',
    '''  local generation=state.certificate_generation
  local maximum=8
  if type(generation)=='table' and generation.schema==1 and generation.kind=='certificate_four_composition_worlds_v1' and
      generation.extra_held==1 and generation.hand_capacity==state.hand_size and generation.population_after==#(state.playing_cards or {}) then
    local found=0
    for _,card in ipairs(state.playing_cards or {}) do if card.id==generation.generated_id and
        card.advisor_generated=='certificate_composition_sample' then found=found+1 end end
    if found==1 then maximum=9 end
  end
  if #state.hand<1 or #state.hand>maximum or #state.deck>120 or num(state.hand_size)>8 then return false end''')
s=patch(s,'function M.forecast(worlds,scorer,charge)',
    'function M.forecast(worlds,scorer,charge,options)\n  options=options or {}')
s=patch(s,"    cost_model='actual_actions',known_mechanics=false,finishing_guarantee=false}",
    "    cost_model='actual_actions',known_mechanics=false,finishing_guarantee=false}\n  if options.certificate_samples then\n    diagnostic.policy_scope='Four common deck/front/seal composition worlds; play-only or one targeted observed discard retaining Purple cards; up to four hands, one certified extra initial card, and32 future-play candidates. Other generation outcomes and Tarot branches are omitted.'\n  end")
s=patch(s,"local candidate=M.multi_discard.discard_candidates(state,nil,1)[1]",
    "local candidate=M.multi_discard.discard_candidates(state,nil,1,{keep_purple=options.keep_purple==true})[1]")
s=patch(s,"diagnostic.complete=true;diagnostic.supported=true;diagnostic.known_mechanics=true",
    "diagnostic.complete=true;diagnostic.supported=true;diagnostic.known_mechanics=true\n  diagnostic.keep_purple=options.keep_purple==true\n  diagnostic.generation_composition_samples=options.certificate_samples==true")
save('blind_finishing.lua',s)

with (HERE/'base.json').open('x',encoding='utf-8') as f:json.dump(bases,f,indent=2)
