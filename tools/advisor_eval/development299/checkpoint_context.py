"""Snapshot this active cycle without renewing any one-use slot.

Bind full immutable audits by path/hash; retain only explicit outcome fields in
the navigation summary instead of duplicating hundreds of megabytes of traces.
Earlier full snapshots and every original audit remain untouched.
"""
from cycle import ROOT,BASE,CAPS,create,read,sha
from datetime import datetime,timezone
from pathlib import Path
import sys

label=sys.argv[1]
assert label.isalnum()
folder=BASE/label;folder.mkdir(exist_ok=False)
jobs=[]
for path in sorted(BASE.glob('*/record.json')):
    record=read(path)
    if 'job' not in record:continue
    audits={}
    for audit_path in sorted(path.parent.glob('audit*.json')):
        value=read(audit_path)
        summary={k:value[k] for k in ('status','disposition','observed_wins','censored_timeouts',
            'qualification','passed','complete','issues') if k in value}
        audits[audit_path.name]={'path':str(audit_path.relative_to(ROOT)),
            'sha256':sha(audit_path),'value_is_summary':True,'value':summary}
    job={'record':record,'record_sha256':sha(path),'audits':audits}
    selection_path=path.parent/'selected_audit.json'
    if selection_path.exists():
        selection=read(selection_path);name=selection['filename']
        assert name in audits and Path(name).name==name and selection['sha256']==audits[name]['sha256'], 'Audit selection must bind a preserved receipt'
        job['selected_audit']=name
        job['audit_selection']={'path':str(selection_path.relative_to(ROOT)),
            'sha256':sha(selection_path),'value':selection}
    jobs.append(job)
captured={j['record']['job'] for j in jobs if j['record']['job'] in ('M09','M10','M19','M20','M21','M22')}
captured_evaluations=sum(len(list((BASE/name).glob('*_result.json'))) for name in captured)
counts={'source_components':sum(j['record']['job'].startswith('M') and j['record']['job'] not in captured for j in jobs),
 'captured_pair_jobs':len(captured),'captured_policy_evaluations':captured_evaluations,
 'search_workers':sum(j['record']['job'].startswith('S') for j in jobs),
 'complete_attempts':sum(j['record']['job'].startswith('C') for j in jobs)}
outcomes=dict(win=0,loss=0,error=0,timeout=0,unsupported=0,censored=0,running=0,not_started=24-counts['complete_attempts'])
for job in jobs:
    if not job['record']['job'].startswith('C'):continue
    audit=job['audits'].get(job.get('selected_audit','audit.json'),{}).get('value',{})
    disposition=audit.get('disposition')
    if audit.get('status')=='audited_selected_synthetic_original_source_win' and audit.get('observed_wins')==1:
        disposition='win'
    elif audit.get('status')=='audited_selected_synthetic_timeout_censored' and audit.get('censored_timeouts')==1:
        disposition='timeout'
    assert disposition in outcomes and disposition!='not_started','Explicit terminal audit required: '+job['record']['job']
    outcomes[disposition]+=1
spent=sum(CAPS[j['record']['job']] for j in jobs);elapsed=sum(j['record']['elapsed_seconds'] for j in jobs)
budget={'reserved_total_seconds':sum(CAPS.values()),'spent_reserved_seconds':spent,'actual_worker_seconds':elapsed,
 'remaining_slots':[k for k in CAPS if not (BASE/(k+'_reservation.json')).exists()],
 'expires_at_utc':read(BASE/'authority.json')['expires_at_utc'],'replacements':0}
create(folder/'outcomes.json',{'jobs':jobs,'counts':counts,'complete_attempt_outcomes':outcomes})
create(folder/'budget.json',budget)
create(folder/'limits.json',{'selected_development_only':True,'profile':'synthetic_all_unlocked_discovered_v1',
 'old_authorities':'closed','game_control':False,'actual_save_access':False,
 'native_empty_response':'No match found in observed responses; traversal and invalid-vs-notfound unqualified.',
 'coordinator_sha256':sha(ROOT/'tools/advisor_eval/development299/cycle.py'),
 'navigation_generator_sha256':sha(Path(__file__))})
refs={'authority':BASE/'authority.json',**{role:folder/(role+'.json') for role in ('outcomes','budget','limits')}}
later_notes=[]
if (BASE/'M10/audit.json').exists():
    later_notes.append('M10 completed four captured decisions: frozen302 preserved the full-blind55104 mean across the Perkeo shop-exit reorder and chose leave instead of frozen300 selling Perkeo; all eight continuation trajectories matched apart from charged setup actions. The job remains ERROR because a final physical-order identity assertion was too strong; no terminal improvement is inferred.')
if (BASE/'M12/audit.json').exists():
    later_notes.append('M12 verified frozen302 product startup through original Back and Game delete/start callbacks using the already observed S05 receipt, zero advisor actions and zero new searches. It is a startup component, not a complete attempt or automatic player win.')
if (BASE/'C03/audit.json').exists():
    later_notes.append('C03 frozen302 selected S7PXV521 lost Ante1Pillar592/600 after22 legal resolved actions and6 exact plays in13.5s;590632 scorecalls, no observed cap violations. No prior-state counterfactual is credited as a win.')
if (BASE/'C04/audit.json').exists():
    later_notes.append('C04 frozen303 M4BVSY11 with explicit naturally fresh all150-missing Gold context timed out at180.03100000007544s after198 legal resolved actions,24 exact plays,2 Death effect receipts and17 cleared blinds. Decision199 was unfinished atAnte7Small0/110000. Completed advisor time147.25781750003776s and8888708scorecalls; completed caps complied. No terminal result or Gold award is imputed.')
if (BASE/'M13/record.json').exists():
    later_notes.append('M13 bounded source inspection completed without Lua/game execution. It diagnosed both user-reported Start-button blockers: persistent G.LOADING boot font cache was treated as active loading, and main-menu STATE_COMPLETE stays false. Release303 did not include the separate subsequent readiness repair; current installation records establish its status.')
if (BASE/'M14/audit.json').exists():
    later_notes.append('M14 verified the304 repair through original Back/Game startup using the observed S05 receipt: source-shaped cached font blocks frozen302 but304 starts S7PXV521 and preserves actual Small Charm. The font is an explicitly inert injected stand-in; zero advisor actions and zero new searches,0.4220000000204891s. This is no terminal outcome or full live auto-run result.')
if (BASE/'M15/audit.json').exists():
    later_notes.append('M15 inspected three original ZIP members without Lua execution in0.2029999999795109s. Exact Certificate first-hand generation and seal branch were captured; five complete methods and24115 excerpt bytes were audited. The original first-hand dispatch and generation-dispatcher definition were not established, and two broad neighborhoods were truncated. No policy action or terminal result follows from this inspection.')
if (BASE/'M16/audit.json').exists():
    later_notes.append('M16 inspected four ZIP members without Lua execution in0.39000000001396984s. All nine named methods were complete, with40005 excerpt bytes. It established original first-hand dispatch, generated-card callback dispatch, Perkeo copy/edition/cost/capacity and main-menu initialization; one broad Perkeo neighborhood tail was truncated while the exact ending-shop branch was complete. It is mechanics text, not a policy or terminal result.')
if (BASE/'M17/audit.json').exists():
    later_notes.append('M17 is a spent adapter ERROR in0.34299999999348074s: malformed generated preload indexing failed Lua parsing before source initialization, callbacks, searches or launches. Its original files and failure remain intact; ten later compile-only checks verified the separate serializer repair.')
if (BASE/'M18/audit.json').exists():
    later_notes.append('M18 verified both actual manual/auto product UI button paths under frozen308 in0.7179999999934807s, using original main-menu/options/exit/controller/update-menu/Back/start callbacks and the observed S05 receipt. Each respected frame locks and started RedGold S7PXV521 with actual Small Charm; two fresh Lua cases, one launch each, zero new native searches, advisor actions or scores. Full Game:update, boot cache, presentation/input and logging use declared stand-ins. This is startup component evidence, not live activation, autonomous survival or a terminal result.')
if (BASE/'M19/audit.json').exists():
    later_notes.append('M19 completed four frozen309/FIFO-cache comparisons on preserved C04steps85/185 in15.797000000020489s,559992 score calls under560000. Complete results matched apart from cache diagnostics. FIFO reduced classification misses but slowed both pairs:1.943535999977 to6.8102767999517s and2.0005020999815 to4.0012928999495s. It is not installed. These selected dependent local timings are not a controlled general speed estimate or terminal result.')
if (BASE/'M20/audit.json').exists():
    later_notes.append('M20 completed four frozen309/dense-two-way-cache comparisons on the same C04steps85/185 in9.46799999999348s with559992 calls. Full semantics matched apart from cache diagnostics. Step85 slowed1.9482618001057 to2.2205037999665s; step185 changed2.1306756000267 to2.0636867999565s. Aggregate candidate timing was slower. It remains uninstalled, and no further cache workers will run in this cycle. These two local dependent pairs establish no general speed or terminal result.')
if (BASE/'C05/audit.json').exists():
    later_notes.append('C05 frozen312 S7PXV521 with explicit naturally fresh synthetic all150-missing Gold context lost Ante1Pillar592/600 after22 legal resolved actions and6 exact plays in25.46799999999348s.633045 score calls and17.066945300088232s completed advisor time; no audited score gaps, mismatches or budget violations. Certificate was again chosen atstep12. Its pack priority rejected complete-root equality even though read-only JSON comparison found identical common_worlds and before_finishing: full forecast65091 nodes and selected policy21737 exceeded the20000-node serializer bound, while each world was below5500. This is a local integration diagnosis, not a rescued run. C03 Gold was off and C05 Gold on, so policy and objective changes are confounded. No Gold awards or unfinished decisions were recorded.')
if (BASE/'M21/audit.json').exists():
    later_notes.append('M21 completed two unchanged C05step12 captured decisions under exact installed312/314 in5.5s,8356calls total4178each. The complete pack family now qualifies, but Certificate remains selected because no fixed all-clearing alternative preserves the admitted owned assets and separate successful-world rewards. Full results differ only in eight duplicated diagnostic fields. Inputs,48modules/34edges,policy/runtime hashes and caps verified. No action dispatched or terminal improvement demonstrated.')
if (BASE/'S06/audit.json').exists():
    later_notes.append('S06 found alternate Canio+Perkeo ITKSGS21 in0.418769 native seconds,0.515999999945052 outer seconds:376745984screened,2220exact,32threads. Actual installed313 query/fallback recipes used explicit synthetic149complete/onlyCanio missing; native accepted strictBurnt/copyOR byAnte5/noPerishable/MissingAuto1. One9s allocation, no relaxed second call. Python serial timing/cursor is not LOVE threading or live startup qualification; no acquisition, survival or Gold award is inferred.')
if (BASE/'M23/audit.json').exists():
    later_notes.append('M23 completed read-only inspection of four original ZIP members and twelve complete methods in0.17199999990407377s,20305 source bytes. Initial mouse-press cancellation precedes the later Start callback; ordinary movement/release handlers do not enter those cancellation hooks. The permitted modloader dump declared2.115 and matched frozen315 hooks byte-for-byte. No source/game/native execution occurred. Separately, the opt-in public startup log at19:50:43UTC declared2.115 and recorded search_start_failed because LOVE tried to open the native absolute worker path as a virtual filename. The installed worker existed. This is a startup diagnosis, not a simulation or survival result; M18 used a search stand-in and did not exercise this default factory.')
if (BASE/'M22/audit.json').exists():
    later_notes.append('M22 completed four unchanged captured C04steps31/96 decisions under exact installed314/315 in4.108999999938533s,167562calls total. Both chose the same physical reorder;315 adds explicitarea=jokers. Actualcalls26378to654 and139876to654; localwholedecisionseconds0.3676946000196to0.32466379995458 and1.7593111998867to0.68179110006895. Both315 proofs completed218pairedplays;step96 also218paireddiscards. Input identity,210frozenfiles,49/50modulegraphs and runtime hashes matched. No post-reorder fresh decision, actualplay, sourcequalification or terminal outcome. These two selected dependent measurements establish no general speedup or odds.')
if (BASE/'C06/audit.json').exists():
    later_notes.append('C06 exact315 M4BVSY11/S04 RedGold with naturallyfresh synthetic150missing timed out180.03200000000652s after163legalresolvedactions and20exactplays. Decision164 remained unfinished inAnte6round15shop,$82. All127frozenfiles/source/runtime/full315graph matched;6241824completedscorecalls and131.9038161advice seconds,completedcaps complied. No mismatch,randomgap,terminal orGoldaward observed. Sixcopy-preflight reorders completed. ActualheldYorick/Perkeo/Brainstorm/Droll/Supernova;noBurnt acquisition orJokersale;ten exitsgenerated2NegativeEmpress each. Threeof28discardsselected5cards;that frequencyalone provesnomistake. C04/C06 differacrossmorethan315 so noisolatedwhole-runimprovementclaim.')
if (BASE/'M24/audit.json').exists():
    later_notes.append('M24 inspected6completeoriginalmethods/6159sourcebytes in3ZIPmembers,0.125s,108frozeninputs,0Lua/policy/native/gameexecution. UIBox config.major/currentG.round_eval andG.I.UIBOXregistry explain the detachedCashOutbutton;sourcecallbackasynchronouslyentersshop. All24mechanicalslots nowspent. Separatelyuserconfirmed2.116 searches;opt-inpubliclogsdeclare2.116 andshowcash_outlookuprejectionthenmanualcash_outsuccess5slater. SourceattemptadaptersbypassedthatproductionUIlookup, sonoactualUIqualificationwasinferredfromthem. Thisisadocumentedproductintegrationdefect,notapolicywin/loss.')
if (BASE/'C07/audit.json').exists():
    later_notes.append('C07 exact320 M4BVSY11 RedGold timed out at180.03099999995902s:164 legal completed actions,20 exact scores,6290261 score calls and132.65666820004137 advisor seconds; no audited score gaps, mismatches or completed phase-budget violations. Step165 remained unfinished in Ante6 round15 shop,$82,population51; Perkeo/Supernova/Brainstorm/Droll/Yorick and two Negative Empress remained. Fifteen cash-outs and twenty generated Negative Empress copies were observed, without any terminal or Gold award. All163 shared completed C06/C07 public snapshots and actions match exactly; both used growth only at36-38.320 removed sorting rejection at six recorded steps but still admitted no candidate there, demonstrating no added growth action or terminal benefit. Step164 was an additional reorder before timeout, not a demonstrated throughput gain. The only ordinary Buffoon choice was Eternal Brainstorm; this route did not demonstrate the new three-policy pack replacement. Full frozen/source/profile/runtime/graph provenance and clean synthetic150-missing context passed the separate read-only audit. See C07/AUDIT.md and the preserved exact comparison.')
if (BASE/'C08/selected_audit.json').exists():
    later_notes.append('C08 exact320 S7PXV521 RedGold lost Ante1 Pillar592/600 after22 legal actions and6 exact plays in23.09299999999348s. All22 recorded full public inputs and selected actions equal C05; pack12 remained Certificate, with4708 rather than4178 score calls. Total633575 completed calls,15.228758299956066 advisor seconds,0.0112345995148644 snapshot seconds and2.718569800257671 source-effect seconds; completed reported caps passed, absent consumable counters are not imputed. Card Sharp ordinary targeted policy clears all four forecast worlds but fails preserved Yorick progress/cash/cashout protection in world2 and Yorick/played-hand/leader protection in world3. Those hand histories belong to projected successful endpoints, not extra actual progression. Its new five-card policy clears only two worlds. Actual six discards used17 cards; Yorick endedX1/countdown6, no growth action, no Perkeo copies, final$2 and zero Gold. No changed action or terminal improvement was demonstrated. The hash-bound selected_audit.json chooses audit_verified.json with no issues; two earlier audit-tool adaptation errors remain preserved separately and did not consume new source evaluations. This is dependent synthetic development data, not a holdout or UI/animation qualification. See C08/AUDIT.md and development300/audit_c08/development_analysis.json.')
later_notes.append('Later C04 supersedes the old C01 ScaryFace bottleneck: C04 bought Supernova atstep22 with15375calls. No new runtime defect is established by the historical Eternal choice; read development299/eternal_slots_readonly/SUPERSESSION.md.')
value={'schema':1,'kind':'checkpoint_experiment_context','status':'ACTIVE',
 'created_at_utc':datetime.now(timezone.utc).isoformat(),
 'summary':'The user-authorized RedGold/Completionist++ cycle remains active. Verified releases and ongoing implementation use only the existing fresh one-use authority; no historical allowance is renewed.',
 'outcome_summary':'C01 frozen300 won selected synthetic normal Red Deck Gold Stake M4BVSY11:225 actions,172.14000000001397s, final Ante8 Cerulean Bell705600/400000, original deck/Joker Gold callbacks, noGAME_OVER. Final Yorick, Brainstorm, Droll, ScaryFace and FlowerPot received synthetic Gold. All225 actions and28 exact plays audited. Thirteen decisions exceeded ordinary140000,max169367. C02 frozen301 on the same development seed timed out at180.01600000000326s after197 resolved actions/21 exact plays/18 cleared blinds; decision198 unfinished at Ante7Big0/165000,4hands/2discards,$112, Perkeo retained. No terminal outcome is imputed. Completed ordinary/shop caps complied; two fast_clear-labelled decisions173/117calls are explicit exceptions to a literal70-total label interpretation, also present inC01. On120 matched states scorecalls fell4215255 to4048640, but measured advisor time increased72.328 to77.508s; no measured speedup is claimed. Burnt was affordable but early Eternal fillers blocked a free slot. M09 failed before decisions because exact CRLF module embedding exceeded Lua parser depth; its lease stays spent. M11 read bounded original result-UI source, with no source execution. M05/M08 terminal fixtures are not full attempts. M04 nativeAPI/v9 and M07 active cancellation passed. M02/M03 errors remain. S01/S02 traversal unqualified; S03 nohit; S04 foundM4BVSY11 in0.667459s. S05 OR-copy search foundS7PXV521 in0.247699s (156557312screened/912exact); no acquisition/survival inferred. Screened chunks are not a contiguous coverage watermark. No verified complete Jokerless win.',
 'limits_summary':'C01 is one selected synthetic all_unlocked_discovered_v1 development attempt, not a player achievement, representative win-rate cohort, unseen validation or proof of general adapter qualification. Its observed outcome belongs to frozen300 only; later policies do not inherit it. Numerical win odds, human superiority and Completionist++ time improvement remain unknown. Source retry context remains disabled and clean. Tools have not controlled the game or accessed player saves.',
 'budget_summary':f'Fresh cycle maximum12 searches x30s,24 mechanical x30s,24 attempts x180s/500actions:5400s reserved. At this immutable snapshot {len(jobs)} jobs spent,{spent}s of their full caps reserved,{elapsed!r}s actual. Remaining jobs expire2026-09-14T22:40UTC. No replacements or carry-forward from closed historical budgets.',
 'counts':counts,'complete_attempt_outcomes':outcomes,
 'verified_complete_win':outcomes['win']>0,'unused_capacity':'retained_under_existing_authority',
 'evidence':{role:{'path':str(path.relative_to(ROOT)),'sha256':sha(path)} for role,path in refs.items()}}
value['outcome_summary']+=' '+' '.join(later_notes)
create(folder/'context.json',value)
print(folder/'context.json')
