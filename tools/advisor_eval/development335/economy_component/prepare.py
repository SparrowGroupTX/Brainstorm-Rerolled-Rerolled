"""Prepare a cash-copy candidate from preserved runtime bytes; no game execution."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
def save(path, text):
    with path.open('x', encoding='utf-8') as f: f.write(text)
base = ROOT/'Brainstorm/Advisor'
text = (base/'economy.lua').read_text(encoding='utf-8')
save(HERE/'before_economy.lua', text)
old = """  local possible,candidates={},{}
  for index,c in ipairs(s.consumeables or {}) do
    if c.key=='c_hermit' or c.key=='c_temperance' then
      local item=candidate(s,index,base)
      if item then possible[#possible+1]=item end
    end
  end"""
new = """  local possible,candidates={},{}
  -- Equal adjacent cash copies have the same payout and leave the same ordered
  -- metadata after one use. Keep the full inventory and multiplicity: two uses
  -- from one group remain a distinct, explicitly evaluated sequence.
  local groups,previous={},nil
  for index,c in ipairs(s.consumeables or {}) do
    if c.key=='c_hermit' or c.key=='c_temperance' then
      if previous and consumables.equivalent_owned and consumables.equivalent_owned(c,previous.card) then
        previous.count=previous.count+1
      else
        previous={index=index,card=c,count=1};groups[#groups+1]=previous
      end
    else previous=nil end
  end
  for _,group in ipairs(groups) do
    local item=candidate(s,group.index,base)
    if item then item.copy_count=group.count;possible[#possible+1]=item end
  end"""
assert text.count(old)==1
text=text.replace(old,new)
old="""    for _,b in ipairs(possible) do if a~=b then
      local i=b.index-(b.index>a.index and 1 or 0)"""
new="""    for _,b in ipairs(possible) do if a~=b or a.copy_count>1 then
      local original=b.index+(a==b and 1 or 0)
      local i=original-(original>a.index and 1 or 0)"""
assert text.count(old)==1
text=text.replace(old,new)
save(HERE/'economy.lua',text)
text=(base/'consumables.lua').read_text(encoding='utf-8')
save(HERE/'before_consumables.lua',text)
old='local function joker_name(j)'
assert text.count(old)==1
text=text.replace(old,'-- Shared by the shop cash planner; no grouping mutates the actual inventory.\nM.equivalent_owned=equivalent_owned\n'+old)
save(HERE/'consumables.lua',text)
