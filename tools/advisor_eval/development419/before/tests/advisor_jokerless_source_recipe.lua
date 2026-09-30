local M=dofile('Brainstorm/Core/jokerless_opening.lua')
local source=dofile('tests/jokerless_source_recipe_fixture.lua')
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local function copy(v)if type(v)~='table' then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function chooses_blue(s)
 local result=M.advice(s)
 check(result and result.action and result.action.kind=='choose' and result.action.index==4,'whole source pack chooses actual Blue seal')
 check(s.pack_cards[result.action.index].seal=='Blue','chosen source identity is Blue')
end
chooses_blue(source)
for kind,value in pairs({foil={foil=true,type='foil',chips=50},holo={holo=true,type='holo',mult=10},polychrome={polychrome=true,type='polychrome',x_mult=1.5}})do
 local s=copy(source);s.pack_cards[5].edition=value;s.filter_info.jokerless_opening.packs[1].cards[5].edition=kind
 chooses_blue(s)
end
for _,edition in ipairs({{foil=true,chips=51},{foil=true,mult=10},{foil=true,type='holo'},{foil=true,holo=true},{negative=true},{foil=true,custom=1},'foil'})do
 local s=copy(source);s.pack_cards[5].edition=edition;local result=M.advice(s)
 check(result and not result.action and #result.warnings>0,'changed or unsupported edition metadata pauses full pack')
end
check(source.pack_cards[5].edition.chips==50,'original source fixture remains unchanged')
print('advisor_jokerless_source_recipe: '..checks..' checks passed')
