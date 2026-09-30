-- Cooperative metadata for product-owned wrappers. No debug/upvalue inspection
-- or third-party callback replacement is performed. Weak keys and values release retired
-- wrappers while an active wrapper keeps its own original callback reachable.
local M={MAX_CHAIN=128}
function M.new()
  local parents=setmetatable({},{__mode='kv'})
  local R={}
  function R:contains(current,target)
    if type(current)~='function' or type(target)~='function' then return false end
    for _=1,M.MAX_CHAIN do
      if current==target then return true end
      current=parents[current]
      if not current then return false end
    end
    return false
  end
  function R:record(wrapper,original)
    assert(type(wrapper)=='function' and type(original)=='function' and wrapper~=original,'Invalid callback wrapper metadata.')
    assert(parents[wrapper]==nil,'Callback wrapper metadata is immutable.')
    assert(not self:contains(original,wrapper),'Cyclic callback wrapper metadata.')
    parents[wrapper]=original
    return wrapper
  end
  return R
end
return M
