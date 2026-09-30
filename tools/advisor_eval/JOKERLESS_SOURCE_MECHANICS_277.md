# Original-source mechanics for rank and Flush routes — 2026-09-13

Read-only inspection of Lua members in the installed executable ZIP. The
executable was not launched and no source worker, game control or save access
was used. The bounded source experiments bind rules digest
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.

| Mechanic | Exact source behavior | ZIP member and lines |
| --- | --- | --- |
| Mars | Four of a Kind starts at 60 Chips × 7 Mult; each level adds 30 Chips and 3 Mult. | `game.lua:560`, `game.lua:2006` |
| Jupiter | Flush starts at 35 Chips × 4 Mult; each level adds 15 Chips and 2 Mult. | `game.lua:561`, `game.lua:2008` |
| Planet X | Five of a Kind starts at 120 Chips × 12 Mult; each level adds 35 Chips and 3 Mult. Its Planet is softlocked until that hand has actually been played. It is unavailable in the untouched starting Planet pool even with unlock/discovery flags enabled. | `game.lua:566`, `game.lua:2004`, `functions/common_events.lua:2008–2010` |
| Blue seal | An undeBuffed held Blue seal only schedules a Planet if actual consumables plus pending buffer are below capacity. It creates the Planet corresponding to `GAME.last_hand_played`, and reserves capacity through `consumeable_buffer`. Multiple seals do not bypass full slots. | `card.lua:1033–1063` |
| Cerulean Bell | Whenever cards are drawn, an existing forced card is retained. If none remains, it unhighlights the hand and deterministically selects one current card using the source `cerulean_bell` pseudoseed, marks `forced_selection`, then highlights it. | `blind.lua:572–586` |
| Jokerless final bosses | Amber Acorn, Crimson Heart and Verdant Leaf are explicitly banned. Cerulean Bell and Violet Vessel are not in that ban list. | `challenges.lua:690–736` |
| Ouija | All currently held cards receive one shared randomly chosen rank; suit and other card identity features remain through `set_base`. The hand-size cost is an actual permanent `G.hand:change_size(-1)`, not a discarded card or temporary draw penalty. | `card.lua:1246–1256` |

These facts support ordinary initial Mars/Jupiter targets and later actual
Five-of-a-Kind development. They do not establish any route as optimal, a
specific run as won, or a measured player win rate. Public card identities,
finite population, forced-card inclusion and actual inventory room remain
necessary in tactical comparisons.
