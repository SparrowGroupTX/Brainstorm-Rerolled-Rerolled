"""Write isolated wrappers for existing manufactured regression fixtures."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
fixtures=('advisor_shop_replacement_baseline','advisor_replacement_inventory','advisor_pack_comparison',
          'advisor_shop_sequences','advisor_catalog_replacements','advisor_gold_goal','advisor_shop_order')
for index,name in enumerate(fixtures,1):
    code="""local original=dofile
function dofile(path)
 if path=='Brainstorm/Advisor/strategy.lua' then
  return original('tools/advisor_eval/development328/replacement_evidence_component/strategy.lua')
 end
 return original(path)
end
original('tests/%s.lua')
"""%name
    with (HERE/('regression_%02d.lua'%index)).open('x',encoding='utf-8') as stream:stream.write(code)
print('prepared seven isolated existing-fixture wrappers')
