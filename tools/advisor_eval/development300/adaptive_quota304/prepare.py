"""Prepare detached quota/UI drafts. No native or original-source execution."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def change(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def main():
    names = ('Brainstorm/Advisor/collection_search.lua', 'Brainstorm/Core/auto_run_product.lua',
             'Brainstorm/UI/collection_run.lua', 'tests/advisor_collection_query.lua',
             'tests/advisor_auto_run_product.lua', 'tests/advisor_collection_product.lua')
    original = {}
    for name in names:
        path = ROOT/name
        original[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        text = path.read_text(encoding='utf-8')
        if name.endswith('collection_search.lua'):
            text = change(text, "local M={}\n", """local M={}
local other_legendary={j_caino=true,j_triboulet=true,j_chicot=true}
local opening_legendary={j_yorick=true,j_perkeo=true}
local function unavailable(row,first)
  if not row.direct_supported then return row.reason or 'This prerequisite is outside the modeled fresh-run route.' end
  if other_legendary[row.key] then return 'The two starting Souls are reserved for Yorick and Perkeo; this route has no later Legendary source.' end
  if opening_legendary[row.key] and first>1 then return 'This opening Legendary is produced in Ante 1, before the requested counting window.' end
end
""")
            text = change(text, "  local minimum=option(options,'minimum_distinct',0)", """  local minimum=option(options,'minimum_distinct',0)
  -- Standalone/manual callers retain strict numeric semantics, including zero.
  -- The explicit auto-run facade/UI choose automatic mode separately.
  local mode=option(options,'quota_mode','strict')
  if mode~='auto' and mode~='strict' then return nil,'Choose Automatic or a strict numeric missing-target count.' end""")
            text = change(text, """  local missing,excluded={},{}
  for _,row in ipairs(choices) do
    if row.direct_supported then missing[#missing+1]=row.label else excluded[#excluded+1]=row.key end
  end
  if #choices==0 then return nil,'Every vanilla Joker already has a Gold sticker.' end
  if minimum>#missing then return nil,'Too few supported missing targets remain for that encounter count.' end""", """  local missing,excluded,excluded_reasons={},{},{}
  for _,row in ipairs(choices) do
    local reason=unavailable(row,first)
    if reason then
      excluded[#excluded+1]=row.key
      excluded_reasons[#excluded_reasons+1]={key=row.key,label=row.label,reason=reason}
    else missing[#missing+1]=row.label end
  end
  if #choices==0 then return nil,'Every vanilla Joker already has a Gold sticker.' end
  if mode=='auto' and #missing==0 then
    return nil,'This opening has no reachable missing Jokers in the selected Ante window. The remaining targets need another opening, an earlier window or prerequisite development.'
  end
  local requested=minimum
  if mode=='auto' then minimum=1 end
  if minimum>#missing then return nil,'Only '..#missing..' missing Jokers are reachable on this opening route in that Ante window; the strict count is '..minimum..'.' end""")
            text = change(text, "    minimum_distinct=minimum,first_ante=first,last_ante=last,budget_ms=budget,", """    quota_mode=mode,minimum_distinct=minimum,requested_minimum_distinct=requested,
    first_ante=first,last_ante=last,budget_ms=budget,""")
            text = change(text, "    native_cpu_mode='maximum',supported_missing_count=#missing,excluded_missing_keys=excluded,", """    native_cpu_mode='maximum',supported_missing_count=#missing,excluded_missing_keys=excluded,
    excluded_missing_reasons=excluded_reasons,
    quota_scope='Distinct reachable conditional offers on this fixed opening and Ante window; no acquisition or win credit.',""")
        elif name.endswith('auto_run_product.lua') and name.startswith('Brainstorm'):
            text = change(text, "'minimum_distinct','first_ante','last_ante','budget_ms'", "'minimum_distinct','quota_mode','first_ante','last_ante','budget_ms'")
            needle = '    local timed,now=pcall(clock)'
            text = change(text, needle, """    -- Automatic collection must include progress once the fixed opening is
    -- already complete. Explicit numeric positive or strict zero requests
    -- retain their meaning; absent/legacy zero defaults to the new Auto mode.
    if configured.search_request.quota_mode==nil then
      local count=configured.search_request.minimum_distinct
      configured.search_request.quota_mode=type(count)=='number' and count>0 and 'strict' or 'auto'
    end
"""+needle)
        elif name.endswith('collection_run.lua'):
            text = change(text, '  for key,value in pairs(defaults) do if q[key]==nil then q[key]=value end end', """  for key,value in pairs(defaults) do if q[key]==nil then q[key]=value end end
  -- 302 stored only a count. Preserve positive requests. Its unset/zero
  -- default becomes Auto on this explicit-start page; strict Off is durable.
  if q.quota_mode==nil then q.quota_mode=type(q.minimum_distinct)=='number' and q.minimum_distinct>0 and 'strict' or 'auto' end""")
            text = change(text, "  local q=options();q.minimum_distinct=((tonumber(q.minimum_distinct) or 0)+1)%6;changed()", """  local q=options()
  if q.quota_mode=='auto' then q.quota_mode='strict';q.minimum_distinct=0
  elseif (tonumber(q.minimum_distinct) or 0)>=5 then q.quota_mode='auto';q.minimum_distinct=0
  else q.quota_mode='strict';q.minimum_distinct=(tonumber(q.minimum_distinct) or 0)+1 end
  changed()""")
            text = change(text, "button('Missing: '..(q.minimum_distinct==0 and 'any' or tostring(q.minimum_distinct))", "button('Missing: '..(q.quota_mode=='auto' and 'Auto' or q.minimum_distinct==0 and 'Off' or tostring(q.minimum_distinct))")
            text = change(text, "row('Waiting-time estimate unavailable for this combined query.',nil,.24),", "row('Auto requires one reachable missing Joker; Off adds no missing-target condition.',nil,.22),")
        elif name.endswith('advisor_collection_query.lua'):
            text = text.replace("dofile('Brainstorm/Advisor/collection_search.lua')", "dofile('tools/advisor_eval/development300/adaptive_quota304/Brainstorm/Advisor/collection_search.lua')")
            text = change(text, "request.supported_missing_count==144 and #request.excluded_missing_keys==6", "request.supported_missing_count==141 and #request.excluded_missing_keys==9")
        elif name.endswith('advisor_auto_run_product.lua'):
            text = text.replace("dofile('Brainstorm/Core/auto_run_product.lua')", "dofile('tools/advisor_eval/development300/adaptive_quota304/Brainstorm/Core/auto_run_product.lua')")
        elif name.endswith('advisor_collection_product.lua'):
            text = text.replace("dofile('Brainstorm/Advisor/collection_search.lua')", "dofile('tools/advisor_eval/development300/adaptive_quota304/Brainstorm/Advisor/collection_search.lua')")
        out = HERE/name
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(text)
    with (HERE/'original_hashes.json').open('x', encoding='utf-8') as stream:
        json.dump(original, stream, indent=2); stream.write('\n')
    print('Prepared detached adaptive quota drafts; no runtime staging or experiments.')


if __name__ == '__main__':
    main()
