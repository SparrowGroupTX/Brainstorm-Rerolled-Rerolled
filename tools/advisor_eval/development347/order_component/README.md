# Pure bounded current-shop copy-target order family

This component uses manufactured public fixtures and already available product
code. It performs no captured-state policy replay, source execution, seed search,
complete attempt, live-game control, or save/profile access.

`gold_order.family(snapshot, modules)` enumerates every legal physical permutation
of a settled, visible shop row of one through six supported Jokers (at most 720
permutations). Pins remain at their original positions. It exposes the original
row plus one canonical row maximizing compatible active copy effects for each
active physical non-copy target, with no more than six distinct output rows.
Targets are physical cards, so two copies of the same Joker remain distinct.
Ties use stable physical-ID order, independently of the current movable order.
There are no scores, random draws, yields, or source callbacks in enumeration.

This is a complete **copy-count target family**, not a complete scoring-order
search. The canonical row may sacrifice a different positional effect. Every
prospective order still needs complete actual scoring against the other admitted
endpoints. The helper does not value extra Perkeo inventory or future actions.

`gold_order.apply(snapshot, row)` validates the original physical-ID mapping,
public activity/copy/pin metadata, a complete legal permutation, and consistency
of the action receipt. It returns a detached reordered snapshot. Each changed
candidate has one explicit `reorder_jokers` action; the current row has none.
Receipts bind physical order metadata, not the entire shop observation. Callers
must regenerate from the current snapshot and revalidate the resulting endpoint
and original inventory; receipts are not persistent policy certificates.

The shared 50,000-score shop cap does not increase. Enumerating at most six rows
does not guarantee that every paid endpoint fits that cap. The integrated
acquisition code preflights the whole declared family before scoring and can
choose a complete current-row family first if the expanded family cannot fit.
It never publishes the best scored prefix of an incomplete family.

The pure fixture covers 164 checks, including all 720 permutations, pins,
compatibility edges, copy cycles, current-order-independent canonical rows,
duplicate physical targets, hidden metadata, stale receipts, and zero score/RNG
work. Its first failed receipt is retained: an initially incorrect test assumed
one incompatible Blueprint prevented all three copy effects, overlooking a
valid compatible chain that places that Blueprint first.

The separate production-wired acquisition fixture uses a manufactured five-slot
shop row: Eternal Perkeo, Eternal Yorick at x2, Eternal Caino at x10, removable
Scary Face, and Eternal Brainstorm; fourteen native-shaped Negative Tarots;
sixteen public playing cards; and a visible missing Crazy Joker. The identical
fixed-row control lacks the required opening margin. The expanded comparison
selects an actual reorder to copy Caino, then fresh advice sells the correctly
reindexed Scary Face and buys Crazy. All four common worlds, every score call,
cash, inventory, and public-card conservation are checked. A smaller score
allowance uses the complete fixed-row fallback before any expanded scoring, and
one fewer score than that complete family requires declines at zero work.

The first three acquisition failures are retained as harness-development
evidence: the first two forbade the legitimate internal `Score.score` call made
by `lower_bound`; the third used physical IDs that accidentally preserved the
old sale index. Neither was a captured evaluation or terminal attempt. This
component demonstrates a bounded local decision path, not new Gold stickers,
a run rescue, measured success probability, or completion of the achievement.

## Exact validation receipts

- `validation4.json` / `validation4.log`: 164 pure-helper checks passed. Earlier
  passing receipts `validation2.json` (160) and `validation3.json` (162) remain.
  `validation1.json` / `.log` retain the failed compatible-chain test assumption.
- `acquisition_validation5.json` / `.log`: 2,668 production-wired checks passed.
  The identical fixed-row control uses 120 actual score-floor calls; the expanded
  family uses 360. Its selected endpoint has a 216,000 minimum opening score over
  all four composition worlds versus a 90,000 Small Blind and the unchanged 1.25
  acceptance margin. The fresh sale index is 2; exact cash is 80, then 82 after
  sale, then 78 after purchase. Both inventory and playing-card population remain
  unchanged. A 120-score allowance falls back to the complete fixed-row family;
  a 119-score allowance declines before spending any calls.
- `acquisition_validation1.json` and `acquisition_validation2.json` preserve the
  internal-score harness mistake; `acquisition_validation3.json` preserves the
  inadequate reindexing setup. `acquisition_validation4.json` was the first full
  pass; receipt 5 adds the explicit score-work/cash summary to its output.
- `component_report.json` records the initial component seal. The Lua helper and
  both fixtures are unchanged from that seal; this README was subsequently
  expanded with these exact receipts.

These are actual manufactured-fixture score-work counts, not production frame
time, runtime speedup, or end-to-end throughput measurements. The expanded
comparison spends more scores in this fixture because it evaluates additional
complete physical rows. No measured runtime timing improvement is claimed.
