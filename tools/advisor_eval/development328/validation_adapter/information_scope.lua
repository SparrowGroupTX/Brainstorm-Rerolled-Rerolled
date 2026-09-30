-- Validation boundary, not a product strategy. Never reads hidden identities.
local M={mode='stop_before_concealed_joker_decision_v1'}
function M.check(snapshot)
  local hidden=0
  for _,card in ipairs(snapshot.jokers or {}) do
    if card.face_down or card.facing=='back' or card.identity_redacted or card.unknown or card.concealed then hidden=hidden+1 end
  end
  if hidden>0 then return false,{mode=M.mode,reason='concealed_joker_order_not_publicly_supported',
    hidden_joker_count=hidden,phase=snapshot.phase,ante=snapshot.ante,round=snapshot.round,
    blind_key=(snapshot.blind or {}).key,policy_evaluated=false} end
  return true
end
return M
