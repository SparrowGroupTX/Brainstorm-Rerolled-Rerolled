function Game:update_game_over(dt)
  local s="end function"; local other='if end'
  -- end function
  if ready then
    for i=1,3 do
      while active do active=false end
    end
  elseif fallback then
    do local f=function()return "end"end end
  else
    repeat tick() until finished(function()return true end)
  end
end