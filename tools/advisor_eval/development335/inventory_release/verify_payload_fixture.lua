-- Verify prepared production fixture paths without any production mutation.
local payload='tools/advisor_eval/development335/inventory_release/payload/'
local original_dofile,original_open=dofile,io.open
local function redirect(path)
  if path=='Brainstorm/Advisor/strategy.lua' or path=='Brainstorm/Advisor/consumables.lua' or
    path:find('tests/fixtures/inventory337/',1,true)==1 then return payload..path end
  return path
end
function dofile(path) return original_dofile(redirect(path)) end
function io.open(path,mode) return original_open(redirect(path),mode) end
original_dofile(payload..'tests/advisor_inventory_reuse.lua')
