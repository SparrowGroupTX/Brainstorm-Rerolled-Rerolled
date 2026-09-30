  else
    repeat tick() until finished(function()return true end)
  end
end
function after()error("must not capture")end

self:update_game_over(dt)
