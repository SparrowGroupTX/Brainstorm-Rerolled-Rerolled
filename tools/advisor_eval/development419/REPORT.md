# Repair419: discard volume and shop alignment

2.203.0-alpha candidate3 is frozen and passes287 Lua fixtures/458 Python tests.
Exact digest: `c9426a51c8f358e3c8f8bb83331278682928d7ce2be084becae0034d7d228ef3`.
Candidate status is separate from deployment; consult SESSION_RESET_419 if present.
The change has no loaded-game outcome evidence. It is not a universal discard fix.

## Discards lead the decision

The teacher's exhaust-discard comparison now checks smaller, already-scored safe
winning hands even when the incumbent is safe. Previously the safe incumbent
short-circuited that selection and could reserve five cards unnecessarily. The
largest safe discard wins before optional Burnt/Death heuristic utility. Candidate
and final-shortlist ordering both prioritize card count, so the12-call proof budget
does not expire on smaller batches before a second five-card variant is checked.
The list remains bounded; this is not an exhaustive proof of every legal discard.

Canonical Hiker and Joker Stencil rows now qualify for the existing additive
retained-card order proof. Complete first-scoring-card rotations still cover Chad.
Cash, Glass, Arm/population, hidden-card and score-floor safeguards remain. Held
Blue seals and Gold cards stay protected. Ordinary140000/shop50000/consumable25000,
fast70/growth12/concealed8000 allowances are unchanged. No new rollout or cap.

Manufactured evidence: independent120-permutation minima, three actual decision /
discard / draw refreshes before a zero-discard winning play, smaller pair anchors,
five-card priority against very high tiny-Burnt merit, protected resources, modified
ability negatives, and a two-King/Chad/held-Steel case where only the second five-card
variant is safe.275 new growth checks pass. These states are invented, not captures.

## Shop decisions support that policy

Shared teacher admission rejects optional Trading Card, Banner and Ramen purchases
or pack choices; only a complete immediate paired survival rescue can waive this.
Trading gets no assumed single-card income when offered. Already-owned Trading
keeps its existing rating to avoid an unproved destructive fallback sale.

Ordinary paid/rental Joker acquisitions through ante3 preserve$25 plus unavoidable
near-term rental/paid-discard costs. Yorick, Perkeo, Blueprint, Brainstorm and Burnt
remain exempt; pack exploration is not blocked by this early spending floor. Core,
destructive-effect and last-engine safeguards retain precedence.

A visible saleable Tarot/Planet activates a once-per-pool strategic60 option for
Perkeo across its useful pre-final horizon, not only early antes. It is never
spendable cash or credit for a consumed Planet. Useful source differences remain
additive; duplicates do not repeat activation. Known positive generator count can
retain activation without inventing generated identities or their utility. Direct
and graph acquisitions preserve actual rental/discard reserves. An otherwise
positive initial-stock purchase clears the generic acquisition hurdle; a fresh
observation holds the source rather than immediately consuming it.

Before the final boss, admitted same-offer Blueprint/Brainstorm alternatives that
retain active Perkeo are preferred over selling it when the complete existing
paired comparison supports the alternative. Pack comparisons collect every
admitted endpoint, even if a direct Negative choice currently ranks higher; the
fresh vacancy must still choose the intended copy Joker. An only-safe Perkeo
exchange remains permitted, consistent with the user's earlier instruction.

From ante7 through the winning ante, an ordinary leave decision spends surplus
above$25 plus unavoidable costs on a useful visible pack or one paid shop refresh.
Every next action uses a fresh observation. This implements the stated excess-cash
interpretation: an indivisible price cannot cross that buffer. It is a preference,
not proof that unseen offers improve the run. Advice journals retain its cash,
price and reserve disposition and the initial Perkeo-stock receipt.

## Public chain and limits

Current loaded label was2.202.0-alpha, exact installed418. Preserved session
`session-20260927T045909Z-1` is in captures/001,002,003; none was replayed through
policy or scoring. The final003 copy has18475 verified events,25 segments,
44,832,110 bytes, ten recorded starts,3 wins/6 losses/1 abandoned_stall and no
unended identity. This descriptive cohort is not a candidate win-rate estimate.

Key chains are anchored by segment, ordinal and body hash in captures/002/
settled_actions.json and captures/001/shop_trace.json. Use the later physical
observations in settled_actions: callback acceptance or the first queued
observation alone does not establish a paid purchase.

- Neptune: observation9390 (ante2,$6,cost3,empty consumables), advice9393,
  request9396, then observation9400 leaves with$6 and no source.11606 calls,
  not truncated. The existing empty bonus already applied here; weak utility,
  price/interest/reserve and the generic hurdle suppressed it. The old later-ante
  cutoff was a separate defect, not the cause of this ante2 example.
- Trading: observation10302, advice10306, request10309; observation10314 shows
  the new card but payment is pending,10317 confirms$12->$11.40266 calls,
  not truncated. The unsupported one-card income conflicted with discard volume.
- Perkeo: observation11042, request11048, observation11052 removes Perkeo;
  request11058 and observation11060 add Brainstorm.26224 calls, not truncated.
  Copy priority selected merit-124.4/ratio2 over admitted Banner/Blue victims
  with merit87.44/95.83 and ratio1.209/1.227. Public compact records do not expose
  every alternative world, so the exact counterfactual safety is not claimed.
- Hiker/Stencil: clearing request10277 left three discards after automatic-order
  refusal. The canonical missing contract is reproduced by independent fixtures.

Prefix002 contained23 physical clears with discards. Final003 contains28 clears
among80 settled plays that had discards. Remaining rows include Banner/Ramen,
unqualified mixed mechanics, Mark/House concealment, Bell and broader ordering
coverage. Avoiding new conflict Jokers helps future acquisition; it does not prove
all these already-owned rows could safely exhaust discards. No below1% exception,
all-fixed, causal win gain or50% win-rate claim is warranted.

## Validation and preservation

109 runtime dependencies,335 test files, six changed runtime paths. Two new fixture
files contain379 checks. Exact418 fails the newly manufactured initial-stock and
Hiker/Stencil controls. Targeted logs, baseline controls and three frozen candidates
remain. Candidate1 failed seven fixture classes; candidate2 failed four. Repairs
restored owned-card valuation and guard precedence, generator continuity and useful
stock marginal value. Final candidate3 passes the full unchanged validation tools.

Six existing fixture inputs were adjusted where the explicit new policy conflicted
with their old setup:381 early buffer isolation; runtime408 ante4 continuation;
371 legacy catalog-only isolation;411/404 neutral perishable scorer instead of
newly blocked Ramen;400 seven-card selected-fishing receipts plus an explicit
volume-supersedes-fishing control. Their engine, endpoint, receipt and safety
assertions remain; the new419 fixture tests final late-spending integration.

One primary implementer and the same read-only reviewer completed one substantive
review and one focused recheck. No remaining blocker; allocation exhausted.447
prework inputs and1656 unique historical files are hashed. All prior tracked and
untracked work, both failed candidates, settings and seven DLLs are preserved.
No game control, saves/profiles, original-game execution, captured replay, search
experiment or heartbeat restart. Release requires confirmed normal current exit,
passive absence, matching preserved public logs, explicit backed install_slice
deployment and a full exact-installed gate.
