# Architecture navigation after release 377

This is a delta map. Use `ARCHITECTURE_MAP_376.md` and its linked 375/371/370/369
sections for the wider advisor, auto-run, search, speed and release structure.

| Question | Runtime/source anchor | Evidence |
|---|---|---|
| Where is the fixed 26-unit Joker replacement threshold? | `Brainstorm/Advisor/strategy.lua:replacement_sale_plan` | Frozen run 7 replacement receipt; `tests/advisor_funded_copy371.lua` |
| How is a short perishable incumbent considered? | `strategy.lua:perishable_replacement_exception` after complete visible one-sale/one-buy family; win-first shop, net merit 13–26, durable offer, $25 and liquidity reserve | `tests/advisor_perishable_replacement377.lua` (35 manufactured checks); `development377/SCOPE.md` |
| What protects current survival? | `shop_scoring.lua:compare` supplies four common worlds; `blind_finishing.lua:forecast` supplies fixed-policy progress and clears; the new guard rejects unsupported, uncertain, incomplete or regressing endpoints | `WIN_RATE_RESEARCH.md` WR-016; candidate/exact-installed gates |
| How is the sale settled safely? | `strategy.lua:replacement_sale_advice` publishes one sale with a buy follow-up; normal runtime re-observes before acting | Manufactured fresh-advice fixture; existing shop settlement architecture in `ARCHITECTURE_MAP_370.md` |
| Where are new public trajectories? | `win_rate_research/20260924_032258_ten_start/{REPORT.md,capture/manifest.json,actions.json,perishable_opportunities.json}` | Ten-start loaded-label-2.175 cohort, two wins/eight losses |
| How were exact bytes released? | `install_slice.py`, `validate_checkpoint.py`, `development377/release.py` | `SESSION_RESET_377.json`; `runs/perishable377_{candidate,installed,installed_validation,final}/` |

No new scorer work, score-cap increase, auto-run lifecycle change, native DLL,
configuration or save access belongs to this slice. The public cohort predates
2.176 and does not establish benefit. Installation awaits normal user restart
for activation.
