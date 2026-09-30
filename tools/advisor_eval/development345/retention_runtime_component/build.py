from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
source=(ROOT/'tools/advisor_eval/development345/retention_component/tests/advisor_gold_retention.lua').read_text()
prefix=source[:source.index('local function run(s,b,cap,modules)')]
prefix=prefix.replace('-- Manufactured post-acquisition retention with actual production dependencies.',
'''-- Manufactured production Decision integration for the fixed-row retention policy.
-- Ordinary advice is focused to an exact declared paid incumbent. Transitions,
-- whole-inventory qualification, four-world scores, phase copying and retries
-- retain their actual initialized production implementations.''')
test=r'''
local function shallow(t) local out={};for k,v in pairs(t)do out[k]=v end;return out end
local original_strategy=A.strategy
A.strategy=shallow(original_strategy)
A.strategy.advise=function()return base()end
A.strategy.shortfall_reroll=nil
A.economy=nil
A.shop_sequences=shallow(A.shop_sequences)
A.shop_sequences.suggest=function()return nil,{complete=true}end
A.shop_sequences.with_continuation=function(value)return value end
local calls,floors=0,0
local raw_score,raw_floor=A.scoring.score,A.scoring.lower_bound
A.scoring.score=function(...)calls=calls+1;return raw_score(...)end
A.scoring.lower_bound=function(...)floors=floors+1;return raw_floor(...)end
local function decide(s,options)
 local result,yields=nil,0
 local worker=coroutine.create(function()
  result=A.decision.run(s,A,function()yields=yields+1;coroutine.yield()end,options)
 end)
 repeat local ok,why=coroutine.resume(worker);check(ok,tostring(why))until coroutine.status(worker)=='dead'
 return result,yields
end
do
 local s=state();local fingerprint=S.fingerprint(s)
 check(A.gold_retention==R or A.gold_retention and A.gold_retention.suggest,'production runtime loads retention')
 local raw_leave={kind='strategy',action={kind='leave_shop'},strategy={action={kind='leave_shop'}},evaluations=0}
 local unguarded=A.phase_copy.apply(s,A,raw_leave)
 check(unguarded.action and unguarded.action.kind=='reorder_jokers','real phase copying would replace an unqualified leave with a Perkeo reorder')
 check(unguarded.phase_copy and unguarded.phase_copy.events_after>unguarded.phase_copy.events_before,'the otherwise suggested reorder really adds Perkeo copy events')
 eq(unguarded.phase_copy_incumbent.action.kind,'leave_shop','the ordinary copy suggestion supersedes leaving')
 local reordered=A.phase_copy.reorder(s,unguarded.action.order)
 check(S.fingerprint(reordered.jokers)~=S.fingerprint(s.jokers),'the unguarded proposal actually changes the assumed fixed physical row')
 local before_calls,before_floors=calls,floors
 local result,yields=decide(s)
 check(result.gold_retention_diagnostics and result.gold_retention_diagnostics.complete,'real Decision performs the full retention comparison')
 check(result.strategy.gold_retention,'a qualified hold receipt is retained on the actual strategy')
 eq(result.action.kind,'leave_shop','the qualified fixed-row hold is delivered without an unproved extra Perkeo reorder')
 eq(result.strategy.action.kind,'leave_shop','strategy and final action agree on the proved hold policy')
 check(not result.phase_copy,'no unrelated copying proof is attached to the fixed-row hold')
 check(not result.phase_copy_incumbent,'the retention result was not silently postprocessed into a different action')
 eq(result.evaluations,calls-before_calls,'the production result charges every actual score pass')
 eq(result.evaluations,floors-before_floors,'all retention scoring is warning-free supported-floor work')
 eq(result.score_cache.score_calls,calls-before_calls,'the real cache receipt retains all work')
 check(result.evaluations>0 and result.evaluations<=50000,'positive complete comparison stays inside the existing shop allowance')
 eq(result.gold_retention_diagnostics.before_missing,0,'the exact paid incumbent would lose the last missing identity')
 eq(result.gold_retention_diagnostics.after_missing,1,'the delivered hold retains it')
 eq(result.gold_retention_diagnostics.held_certificate.copy_events,1,'the receipt credits only the current row copy event')
 eq(S.fingerprint(result.gold_retention_diagnostics.held_certificate.current_order),S.fingerprint(s.jokers),'the proof names the unchanged actual row')
 check(yields>0,'the production scoring worker cooperatively yields')
 eq(S.fingerprint(s),fingerprint,'Decision and unguarded inspection leave manufactured input unchanged')
 local pending=decide(s,{retry={matched=true,pending=true,reloads_used=3}})
 check(pending.gold_retention_diagnostics and pending.gold_retention_diagnostics.complete,'pending retry still retains the diagnostic proof')
 check(pending.action==nil and pending.strategy.action==nil,'pending retry blocks both executable action representations')
 check(pending.retry and pending.retry.review_only and pending.retry.status=='pending','existing persistent retry guard remains authoritative')
 eq(pending.retry.reloads_used,3,'retention cannot reset the persistent retry count')
 local unavailable=decide(s,{retry={unavailable=true,reason='manufactured unavailable metadata'}})
 check(unavailable.action==nil and unavailable.strategy.action==nil,'unavailable retry metadata likewise grants no action')
 eq(unavailable.retry.status,'unavailable','retry uncertainty is preserved')
end
print('advisor_gold_retention_runtime: '..checks..' actual production Decision checks; '..calls..' score passes; '..floors..' supported floors')
'''
dest=OUT/'tests/advisor_gold_retention_runtime.lua'
dest.parent.mkdir(parents=True,exist_ok=True)
dest.write_text(prefix+test,encoding='utf-8',newline='\n')
