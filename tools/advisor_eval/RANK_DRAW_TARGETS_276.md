# Concentrated-rank redraw coverage — 2.76, 2026-09-13

Search.draw_targets represents upgraded Four/Five of a Kind as well as
Straight/Flush. Held pairs/triples compete using known remaining rank counts,
with exact without-replacement completion probabilities. These are draw-completion
probabilities, never blind/run odds. Advice uses complete matched score comparisons.

At most two existing shortlist slots are reused. First candidate of each redraw
size and incumbent keep-play remain protected. No RNG, score cap, fast-clear,
growth, Glass/population or inventory policy was expanded. Jokers, Observatory
(both forms), concealed/unknown identity and unupgraded hands exclude extension.
Stone has no rank; Serpent draws three; Bell compulsory discard remains legal.
Hidden deck order does not affect selection.

New tests/advisor_rank_draw_targets.lua:21 checks, independent exhaustive draws,
Five versus Four distinction, guards, purity and determinism. Real complete paired
comparison: prior mean9603.3333, new16240,35570 evaluations, same candidate count.
Synthetic component evidence only, no win/rate gain. focus1 omitted normal Draws,
so no redraw completed; focus2 corrects that fixture and completes comparison.

Full selected installed275 plus search: runs/rank_targets276_candidate,109 Lua
fixtures pass in11.391s with unchanged frozen hashes. Pending Fool test/runtime
excluded explicitly; installed pack_scoring baseline retained. Install/backup:
runs/jokerless276_installed/record.json. All51 deployment hashes verify. Repo parity
is intentionally false for ongoing Core/UI/Fool work. Settings/DLLs preserved.
