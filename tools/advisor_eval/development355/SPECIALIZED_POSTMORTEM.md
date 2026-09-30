# T02 / V02 specialized policy postmortem

Read-only analysis of completed job action, episode, configuration, and summary receipts. No new episode, replay, policy/source execution, training, or game control was performed; no runtime code was changed. Calculated counts and input SHA-256 identities are retained in `SPECIALIZED_POSTMORTEM_DATA.json`; opening sequences, discard counts, and paired comparisons are in `SPECIALIZED_POSTMORTEM_OPENING.json`.

The clearest failures are behavioral: the final learned policy liquidates both starting engine Jokers before its first blind, underuses discards in early losses, and enters long reorder sequences during deterministic evaluation. The logs support those findings directly. They do not establish that any single repair would yield a win, that a particular model feature caused the behavior, or that the external simulator is qualified.

## Completed evidence

| Cohort | Attempts | Actual losses | Unsupported | Censored | Wins / new simulated Gold | Mean observed clears |
|---|---:|---:|---:|---:|---:|---:|
| T02 changing learned policy | 6,986 | 6,859 | 119 | 8 | 0 / 0 | 0.997 |
| V02 fixed learned policy | 32 | 28 | 2 | 2 | 0 / 0 | 1.500 |
| V02 public heuristic | 32 | 23 | 9 | 0 | 0 / 0 | 3.156 |

The T02 and V02 episode files contain **zero missing or null `blinds_cleared` fields**, and zero missing `steps`, including unsupported records. These specific means therefore do not result from zero-imputing absent progress. They are observed prefix means, including censored attempts, not completed-run strength or player win rates. No error outcomes appear in these two files.

V02 pairs both policies on the same 32 development seed strings. The learned policy has fewer observed clears on 21 pairs, equal clears on 11, and more on none. Different trajectories and fidelity censoring preclude interpreting this as a counterfactual full-run comparison. This is the isolated weak tensor heuristic, **not the installed advisor**.

T02 used the 530/67/163 specialized schema, warm-started learned weights, weight-0.1 play-only imitation, undiscounted gamma 1, and the frozen public 59-complete / 91-missing goal map. It recorded 127,744 decisions and 499 updates in 882.062 seconds. There is no terminal success or positive sticker reward in those trajectories. Verified-clear shaping provides intermediate feedback, but the declared shaping cancels over a complete zero-award episode. The data therefore supply no successful example of earning the target terminal reward.

## 1. The intended engine is sold before it can develop

Every learned V02 episode begins with **two Joker sales**, targeting catalog IDs 223 and 170, then the first blind selection. Because the configured starting inventory contains only Yorick and Perkeo, those actions dispose of both anchors before any play or discard. All 32 heuristic attempts retain both at that point.

This is not a small-sample anomaly in the training log: among the last 986 T02 episode indices, 941 have two sales before their first blind selection. Across the whole T02 job, 6,359 attempts select at least one Joker sale. The initial public scaffold is therefore not the operating engine for most of the trained agent's later trajectories.

Example V02 episode 3 (`DBCFA5E4`) records two sales at steps 1–2, select blind at step 3, then four plays and a zero-clear loss at step 7. No discard occurs. Episode 1 follows the same liquidation, then makes three one-card discards across the blind and loses with zero clears.

Selling the anchors removes Yorick's future growth and Perkeo's future duplication opportunities. It also provides sale cash; the logs do not prove that keeping both forever is optimal. Both anchors are already Gold under the goal mask, but attributing liquidation specifically to that feature would be speculative. The logs do not contain logits, alternative values, gradients, or teacher eligibility decisions.

The learned V02 policy redeems 37 vouchers across 48 recorded cash-outs, versus zero for the heuristic. Thirty-six of those voucher offers cost $10 and one cost $7. It makes 41 card buys versus the heuristic's 81. This documents an economic preference after liquidation; it does not by itself establish that a particular voucher was a bad purchase. Full shop alternatives and future marginal values were not recorded.

## 2. Resource use and growth are not learned reliably

The learned V02 policy makes no discard during its first blind on 23/32 attempts; the heuristic does so on 10/32. Six of the learned policy's ten first-blind losses contain no discard at all. Both heuristic first-blind losses use three discards.

Across V02, learned discards select one card 33 times, two cards four times, three cards three times, and four cards eight times; there are no five-card discards. The heuristic makes 283 discards, all of size three to five. Large discards are not universally correct, and retaining a particular draw cannot be assessed without the public hand alternatives. However, the combination of early unused discard resources and immediate Yorick sales shows that the specialized growth strategy was not acquired.

Across T02, 3,163 actual losses have zero clears; 1,746 of those record zero discards before the loss. Near-one-blind training progress is therefore primarily an early survival failure, not just a late-game fidelity boundary. The first 1,000 episode indices average 1.390 clears; later 1,000-episode bands range from 0.715 to 1.139, with the final partial band at 1.030. These changing-policy cohorts are descriptive, not an independent regression experiment.

## 3. Free reordering consumes evaluation episodes

The learned V02 policy performs **1,564 Joker reorder actions out of 2,177 total decisions** (71.8%). The heuristic performs none. Two learned attempts hit the 800-step cap:

- Episode 11 (`D6D34C83`) reaches three clears, then records 774 reorder actions in total. Its final rows alternate left/right candidates 5 and 8 with a constant candidate count of 14.
- Episode 59 (`D00202AA`) reaches two clears, then records 778 left-reorder actions. Its final rows repeat candidate 4 with a constant candidate count of 10.

These are direct repeated-action traces, not proof of byte-identical complete states: the log does not preserve observation hashes or full ordered inventories. The second trace could include a no-op, swaps between indistinguishable copies, or a repeated public configuration; the records alone cannot distinguish them. Neither episode should be called a loss or a rescued run.

The current representation includes public position and action direction but no explicit repeated-state memory. Global step fraction changes while these sequences run; it does not by itself identify which ordering has already been tried. These receipts establish a missing control safeguard, not a demonstrated need for a larger network.

## 4. Fidelity and logging still constrain diagnosis

T02 unsupported reasons: 105 perishable expiry boundaries, 13 candidate-capacity overflows, and one Mime round-end repetition boundary. All 11 V02 unsupported attempts are perishable expiry: nine heuristic and two learned. Most early actual losses happen before these boundaries. Censoring must remain explicit rather than being removed to manufacture longer trajectories.

The enhanced logs identify selected target catalog IDs, costs, stickers, selected slots, and ordinary base-score feature. They still omit before/after public hands, actual scored chips, remaining hands/discards, complete shop alternatives, Joker growth values, teacher-selected actions, and policy probabilities. Consequently the audit cannot prove a specific inferior hand selection, a precise score mismatch, or which retained draw would have improved an outcome. Ordinary base-score features must not be treated as exact engine scores.

The known public encoder and weak teacher omit or approximate conditional Joker/scoring interactions, and the teacher does not supply a source-qualified full-run strategy. Their limitations remain plausible contributors. These logs alone do not establish an encoding bug, hidden-information leak, or causal effect of the expanded goal channels.

## Narrow correction and prerequisite

The most directly justified implementation correction is a **public reorder-cycle safeguard**: do not offer reorder actions that leave the visible ordered inventory unchanged, and track visited public orderings within a decision phase so immediate reversals or repeats cannot consume hundreds of steps. Reset that history after a substantive state-changing action. Preserve useful distinct ordering choices, derive the guard only from public information, and represent its history/action availability consistently to the policy. Manufactured cases should cover identical copies, inverse swaps, concealed identity, and a useful new ordering. This would prevent the observed control failure; it does not claim to improve terminal awards.

A separate, explicitly restricted opening curriculum could defer selling the two untouched starting anchors until the first shop, or supply a narrow public opening teacher selecting the next blind. That would allow the intended engine to appear in training. It must be labelled a scaffold/action restriction rather than a universally optimal no-sale rule; later retirement/replacement decisions remain essential to new-sticker collection. Do not silently install it or present a resulting score as unrestricted policy performance.

More repetitions of the unchanged training setup are not well supported by these receipts. All terminal target rewards are zero, and the comparison heuristic also produces no wins. Long-horizon award learning needs stronger verified behavior supervision or a separately specified successful prerequisite curriculum, with source fidelity checks retained. Merely restoring broad imitation of the existing weak heuristic would reproduce its known shop/consumable/discard limitations. The installed advisor is a different system; this audit did not run it, score it, or use it as a teacher.

Before any further registered pilot, the minimal diagnostic logging addition is the public ordered-state fingerprint around reorders, opening-sale eligibility/reason, actual blind chips/target and hands/discards around plays, and teacher action/coverage when imitation applies. Such evidence would separate an execution no-op from a policy cycle and an incorrect hand estimate from resource misuse without requiring replay. No additional pilot is authorized by this report.
