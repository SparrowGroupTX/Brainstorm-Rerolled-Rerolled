from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
catalog = json.loads((OUT / 'source_catalog.json').read_text())
header = """-- Manufactured states only. Source names are frozen data, not source execution.
-- Check row catalog agreement separately from paid transition and score support.
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local H=F.Hold
local Goal=dofile('Brainstorm/Advisor/gold_goal.lua')
local Perkeo=dofile('Brainstorm/Advisor/gold_perkeo.lua')
local S=F.Snapshot
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
math.random=function() error('No RNG is allowed in manufactured row support fixtures') end
pseudorandom=math.random;pseudoseed=math.random
local source_names={}
for line in ([=[
"""
header += '\n'.join(f'{k}={v["name"]}' for k,v in sorted(catalog.items()))
header += """
]=]):gmatch('[^\\r\\n]+') do local key,label=line:match('^(j_[%w_]+)=(.+)$');source_names[key]=label end
if row_fixture_scope~='mixed' then
  local admitted=0
  for key,name in pairs(source_names) do
    local s=F.state();local j=F.joker(key,name,'fixture:'..key)
    -- Cartomancer can share the exit-only dependency proof, while its distinct
    -- startup generation still needs the caller's exact capacity qualification.
    local expected=Goal.stable_card(j,Perkeo) or key=='j_cartomancer'
    s.jokers[#s.jokers+1]=j
    local receipt,why=H.certify(s)
    eq(receipt~=nil,not not expected,'exact source-name membership '..key..' / '..tostring(why))
    if expected then
      admitted=admitted+1
      check(receipt.original_inventory_unchanged and not receipt.generation_used_for_score,'wider row grants only unused-inventory equivalence')
      eq(S.fingerprint(receipt.inventory_before),S.fingerprint(s.consumeables),'all original card fields retained')
      local before=S.fingerprint(s)
      s.jokers[#s.jokers].ability.name='Counterfeit '..name
      check(not H.certify(s),'known key with a mismatched source ability rejects '..key)
      s.jokers[#s.jokers].ability.name=name;s.jokers[#s.jokers].name='Counterfeit '..name
      check(not H.certify(s),'known key with a mismatched display identity rejects '..key)
      s.jokers[#s.jokers].name=name
      eq(S.fingerprint(s),before,'qualification checks never mutate the row')
    end
  end
  eq(admitted,110,'current stable/Perkeo identities plus Cartomancer exit-only identity')
  for _,key in ipairs({'j_cartomancer','j_abstract','j_banner','j_mime','j_baron','j_caino'}) do
    local s=F.state();s.jokers={F.joker('j_perkeo','Perkeo','p'),F.joker(key,source_names[key],'target'),F.joker('j_brainstorm','Brainstorm','copy')}
    eq(H.certify(s).copy_events,2,'unrelated '..key..' keeps the physical Perkeo/copy count')
    s.jokers[1],s.jokers[2]=s.jokers[2],s.jokers[1]
    eq(H.certify(s).copy_events,1,'Brainstorm on '..key..' does not create an invented Perkeo event')
    s.jokers[1]=F.joker('j_blueprint','Blueprint','blue')
    eq(H.certify(s).copy_events,3,'Blueprint then Perkeo allows both physical copy chains')
    s.jokers[2].blueprint_compat=false
    eq(H.certify(s).copy_events,1,'target compatibility still gates every copied chain')
  end
  local s=F.state();s.jokers[3]=F.joker('j_unknown','Abstract Joker','unknown')
  check(not H.certify(s),'a known name never admits an unknown key')
  for _,key in ipairs({'j_madness','j_ceremonial','j_riff_raff','j_certificate','j_marble','j_vampire'}) do
    s=F.state();s.jokers[3]=F.joker(key,source_names[key],'excluded')
    check(not H.certify(s),'automatic destruction/population/startup outside this row boundary '..key)
  end
end
"""
fixture = (ROOT / 'tests/advisor_gold_acquisition.lua').read_text()
begin = fixture.index('local prefix=')
end = fixture.index('\ndo\n', fixture.index('math.random=function()', begin))
integration = fixture[begin:end]
# Reuse the existing manufactured constructor/scorer wiring in a lexical block.
integration = integration.replace('local checks=0\n', '')
integration = integration.replace("local function check(v,m) checks=checks+1;assert(v,m) end\n", '')
integration = integration.replace("local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end\n", '')
integration = 'do\n' + integration
integration += """
local variants={
  {key='j_abstract',name='Abstract Joker',ability={extra=3}},
  {key='j_banner',name='Banner',ability={extra=30}},
  {key='j_mime',name='Mime',ability={}},
  {key='j_baron',name='Baron',ability={extra=1.5}},
}
for _,variant in ipairs(variants) do
  local s=state();s.joker_limit=5;s.next_blind.chips=1000
  s.jokers={joker('j_yorick','y','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=13,eternal=true}),
    joker('j_perkeo','p','Perkeo',{eternal=true}),joker('j_brainstorm','b','Brainstorm',{eternal=true}),
    joker('j_scary_face','s','Scary Face',{extra=30}),joker('j_golden','g','Golden Joker',{extra=4})}
  for _,j in ipairs(s.jokers) do s.completionist_goal.by_key[j.key]={status='complete'} end
  s.consumeables=F.state().consumeables;s.consumable_limit=16;s.consumeable_usage_total={tarot=8}
  s.shop_jokers[2]=joker(variant.key,'offer:2',variant.name,copy(variant.ability))
  s.completionist_goal.by_key[variant.key]={status='missing'}
  local configured=module_copy(mods);configured.gold_tarot_hold=H
  local before=Snapshot.fingerprint(s)
  -- An unused prospective Negative from either qualified source class must
  -- leave actual scoring unchanged, including count-based and held-card Jokers.
  local scoring=copy(s);scoring.hand={copy(s.playing_cards[1]),copy(s.playing_cards[2]),copy(s.playing_cards[3]),copy(s.playing_cards[4])}
  scoring.jokers[#scoring.jokers+1]=copy(s.shop_jokers[2])
  local base_score=Score.lower_bound(scoring,{1,2,3,4})
  for _,tarot in ipairs({'c_magician','c_hermit'}) do
    local added=copy(scoring);added.consumeables[#added.consumeables+1]=F.observe(F.raw(tarot,'prospective:'..tarot,true))
    added.consumable_limit=added.consumable_limit+1
    eq(Score.lower_bound(added,{1,2,3,4}).score,base_score.score,'unused Negative '..tarot..' leaves first-hand score unchanged with '..variant.name)
  end
  local advice,work,d=advise(s,nil,configured)
  check(advice and d.complete and d.projection_complete,'the full mixed-offer family completes with '..variant.name..': '..tostring(d.reason))
  eq(#d.endpoints,5,'hold plus two legal completed-original sales for each of two offers')
  local observed={}
  for _,endpoint in ipairs(d.endpoints) do
    if #endpoint.actions>0 then
      local buy=endpoint.actions[#endpoint.actions]
      observed[buy.index]=(observed[buy.index] or 0)+1
      eq(endpoint.hold_certificate.inventory_count_before,14,'every endpoint keeps the whole mixed Tarot inventory')
      eq(endpoint.evidence.common_worlds.family_key,d.endpoints[1].evidence.common_worlds.family_key,'different target offers use exactly the same world family')
    end
  end
  eq(observed[1],2,'the original supported offer is fully compared')
  eq(observed[2],2,'the newly covered offer is fully compared, not dropped after another success')
  eq(Snapshot.fingerprint(s),before,'mixed-offer family leaves input unchanged')
  local sold=assert(Sequences.transition(s,advice.action,configured))
  local buy,_,after=advise(sold,nil,configured)
  check(buy and after.complete and buy.action.kind=='buy','fresh post-sale state buys a visible missing Joker')
end
end
print('advisor_gold_tarot_rows: '..checks..' manufactured source-identity and complete mixed-offer checks passed')
"""
output = OUT / 'tests/advisor_gold_tarot_rows.lua'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(header+integration, encoding='utf-8', newline='\n')
for mode in ('before','candidate'):
    module = 'Brainstorm/Advisor/gold_tarot_hold.lua' if mode=='before' else 'tools/advisor_eval/development345/row_component/Brainstorm/Advisor/gold_tarot_hold.lua'
    runner = "local original=dofile\ndofile=function(path)\n  if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path="+repr(module)+" end\n  return original(path)\nend\ndofile('tools/advisor_eval/development345/row_component/tests/advisor_gold_tarot_rows.lua')\n"
    (OUT / f'run_{mode}.lua').write_text(runner, encoding='utf-8', newline='\n')
