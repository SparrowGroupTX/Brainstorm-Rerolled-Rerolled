# 385 — surplus cash after a truncated shop comparison

Observed problem: in the live user-started 2.182 win-first public journal,
shops with $103–$178 recommended leaving. Three receipts admitted a bounded
surplus Joker reroll, but the shop score context then truncated and the
whole-decision fallback discarded the independently qualified reroll. Freeze
and verify a completed public-log prefix before reporting exact counts.

Acceptance: after a truncated shop comparison, the complete strategic fallback
is selected first. If it leaves the shop, independently recheck the existing
bounded surplus-catalog admission using only the current public snapshot; a
qualifying reroll may replace that leave. Do not restore a partially scored
buy, sale, sequence or tactical reroll. A fallback purchase/use/other action
retains priority. Clear abandoned reroll receipts so the journal describes the
final decision. Preserve the current source-catalog, cash/interest/purchase,
cash-scaling, replacement-slot, special-shop, fee and profile exclusions and
all score caps. Newly revealed offers are assessed afresh.

Validation: manufacture truncated-context and complete-context contrasts,
including positive cash, non-leave fallback, excluded cash-scaling and
unsupported catalog cases. Run focused Lua fixtures, then freeze exact
candidate bytes and run the full candidate gate. Release only after a normal
game exit, explicit-file backed installation and exact-installed validation.
No captured state is submitted to a policy or scorer.

**Release completed 2026-09-25:** `REPORT.md`, `SESSION_RESET_385.md`/`.json`
and `runs/cash385_final/final_verification.json` hold exact installation and
candidate/installed validation evidence. Activation and real-game benefit
remain unconfirmed.
