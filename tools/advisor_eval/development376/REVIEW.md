# WR-015 Fool/Jupiter hand-cycle read-only review — 2026-09-23

One independent reviewer inspected the narrow policy path and its
manufactured fixtures, then made one focused recheck after fixes. The
reviewer made no edits, ran no captured-state policy/scorer, and did not
repeat the full release gates.

The initial review found two release blockers. First, an optional stock
proposal could replace a selected specialist play. `decision.lua` now
admits it only after an ordinary selected play, and a fixture preserves
specialist priority. Second, the first manufactured score example used an
invalid play. The test now constructs a legal five-card Flush and calls the
ordinary scorer before and after the projected Jupiter use. The focused
recheck accepted these resolutions. Projection now also records per-key
Jupiter use, validates the freshly observed Jupiter strictly, and tests
last-source Perkeo pool loss.

Static installed Balatro 1.0.1o source inspection supports the local
transition: `card.lua:1553-1555` permits Fool use at full stock;
`button_callbacks.lua:2209,2218,2258-2260` removes/generates in the
relevant order; `card.lua:1373-1383,687-695` covers generated card and
Negative slot handling; `common_events.lua:2109-2111,2126-2152` covers
forced key/editionless Planet generation; and
`functions/misc_functions.lua:1212-1219` updates last-used Tarot/Planet.
These source files were read, not executed. `runtime.lua:142-147` attaches
the selected win-first teacher profile to the actual decision snapshot.

Review acceptance is bounded to public Jupiter, supported main Flush,
known safe Joker row and one refreshed step. It does not establish the
profitability of a captured run-9 alternative, subsequent draws, wider
shop/Observatory/other-card behavior, activation or full-run benefit.
The full candidate and exact-installed validation results are in
`runs/fool376_{candidate,installed_validation}/`; exact hashes and
preservation checks are in `SESSION_RESET_376.json` and
`runs/fool376_final/final_verification.json`.
