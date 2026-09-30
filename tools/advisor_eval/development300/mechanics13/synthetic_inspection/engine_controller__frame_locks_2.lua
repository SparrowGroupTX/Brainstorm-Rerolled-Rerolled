function Controller:init()
 self.locks={}
 self.locked=false
end
function Controller:update(dt)
 self.locks.frame_set=nil
 self.locks.frame=false
end
