-- Deterministic work estimate, never the clock speed of the current decision.
-- Reference scorer cost comes from the frozen 2.54 9/10-card component probes.
-- Frequency and action-time conversions are explicit uncalibrated assumptions.
local M={}
local function n(v,f) return type(v)=='number' and v==v and v or (f or 0) end
function M.plays(size,limit)
  local total,choose=0,1
  for k=1,math.min(size,limit or 5) do choose=choose*(size-k+1)/k;total=total+choose end
  return total
end
function M.estimate(s,readiness)
  if not readiness or not readiness.supported or type(readiness.opening_scores)~='table' or
    #readiness.opening_scores~=4 or n(readiness.target)<=0 then return nil end
  local size=math.floor(n(s.hand_size,8));if size<1 or size>20 then return nil end
  local hands=n(readiness.hands,n(s.hands_left,1));local discards=n(readiness.discards,n(s.discards_left))
  local unresolved=0
  for _,score in ipairs(readiness.opening_scores) do
    if type(score)~='number' or score~=score then return nil end
    if score<readiness.target then unresolved=unresolved+1 end
  end
  -- Uncertain opening means cannot earn optimistic time savings.
  if readiness.uncertain then unresolved=4 end
  local work=M.plays(size,math.min(5,n(s.hand_limit,5)))
  local factor=1+(discards>0 and 16*24 or 0)+math.max(0,math.min(3,hands-1))*4*4
  local nonclear=math.min(140000,work*factor)
  local estimated_scores=(nonclear*unresolved+math.min(70,work)*(4-unresolved))/4
  return {seconds=estimated_scores*.000012,score_work=estimated_scores,nonclear_work=nonclear,
    sampled_nonclear_fraction=unresolved/4,hand_size=size,reference_seconds_per_score=.000012,
    calibrated=false,scope='one representative decision per blind; sampled openings, not a survival forecast'}
end
function M.compare(before,after,before_ready,after_ready,scale)
  local left,right=M.estimate(before,before_ready),M.estimate(after,after_ready)
  if not left or not right then return nil end
  local blinds=math.max(1,math.min(3,3*(9-n(before.ante,1))))
  local seconds=(right.seconds-left.seconds)*blinds
  -- Existing visible sequence actions cost2 utility. Convert the declared1.5s
  -- action assumption to the same units, and bound this secondary preference.
  local adjustment=math.max(-8,math.min(8,-seconds*2/1.5))*math.max(0,math.min(2,n(scale,1)))
  return {adjustment=adjustment,extra_seconds=seconds,before=left,after=right,
    representative_blinds=blinds,seconds_per_action=1.5,calibrated=false,
    scope='bounded secondary time preference; strong scoring gains retain priority'}
end
return M
