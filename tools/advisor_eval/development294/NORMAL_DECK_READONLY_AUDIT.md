# Normal-deck dataflow audit for Gold-goal design

This is read-only static navigation, not fresh original-source parity for all15
decks and not an evaluation of player win rates. No game, profile, save, source
component, replay or search was accessed/executed. Normal activation is owned by
slice293; progress display by294; the final-boss goal remains staged for295.

| Deck | Existing detached representation | Concrete limitation |
|---|---|---|
| Red | Actual reset discards flow through snapshot, shop round resources and cash reserves. | No deck-specific scoring blocker found. |
| Blue | Actual reset hands are captured and used by ordinary scoring. | Whole-blind shop forecasts stop above4 hands; the normal five-hand opening can still be compared independently. |
| Yellow | Actual current dollars, purchases, borrowing and interest are captured. | Starting wealth is not imputed later. No deck-specific blocker found. |
| Green | no_interest, money_per_hand and money_per_discard flow to finishing rewards and conditional economy. | Incomplete forecasts must not treat unused-hand/discard income as pre-clear spending. Existing liquidity preserves this boundary. |
| Black | Actual Joker capacity and reset hands are captured; capacity/removal helpers carry changed slots. | Larger rows can exceed later bounded planning budgets; no deck-name override should waive them. |
| Magic | Actual voucher ownership, consumable capacity and held Fools are captured. | Owned-Fool290 planning is deliberately narrow; arbitrary copied effects remain unsupported. |
| Nebula | Actual Telescope ownership and consumable limit are captured. | Whole-inventory protections remain necessary; no automatic Planet use follows from the deck name. |
| Ghost | Actual spectral shop rate and held spectral cards are captured. | Hex/other random destructive uses do not have a general exact tactical model; do not use them to promise retained Gold cargo. |
| Abandoned | Actual physical population and starting deck size drive classification, draw populations and Erosion. | No assumption of missing faces is hardcoded into recommendations. |
| Checkered | Actual suits and physical population drive classification and draw populations. | No forced Flush recommendation is needed. |
| Zodiac | Actual vouchers, shop slot count and Tarot/Planet/Joker/spectral rates are captured. | General next-shop contents remain unknown. |
| Painted | Actual hand size and Joker capacity are captured. | Whole-blind shop forecasts stop above8 cards; its normal10-card hand remains outside that certificate. Ordinary opening scoring allows up to10. |
| Anaglyph | Actual pending Double Tags are captured at blind selection; bounded exact supported skip-tag copies are projected. | Unseen tag rewards, future tag timing and broad tag routes remain outside the current model. |
| Plasma | scoring.lua533 applies balance; snapshot167/190 scales printed blind targets. Score-bound pruning declines nonlinear balance at723. | This audit did not requalify original deck-trigger rounding; no new source parity is claimed. |
| Erratic | The exact observed physical rank/suit population is captured and sorted independently of hidden draw order. | No seed or stock prediction follows from that population. |

Key source navigation: snapshot.capture137–257, shop_scoring.round_resources282,
prepare447–529, compare813–900; scoring.score201/533; finish_rewards.prepare50–81;
conditional_value.interest18, horizon22 and assess211; liquidity.estimate29–67;
blind_routing.project_skip26–62. Exact line numbers can shift with root-owned
integration; function names identify the current boundaries.

Shared blockers matter more than deck labels. blind_finishing.forecast174–176
limits complete forecasts to four hands/eight cards, and finish_resources94
excludes all Joker rows from its detailed end-of-blind resource certificate.
That is a support limitation, not proof ordinary scoring is wrong. Random score
or income, unknown card effects, startup generators and unsupported bosses
remain named failures rather than imputed zero risk.

One concrete existing integration hazard: shop buys/replacements apply
strategy.survival_dominated, while direct Buffoon selections and one-sale pack
replacements do not consistently apply that veto; the replacement path uses
ratio>=0.85. Any future Gold pack slice needs its own complete survival/reference
guard. The staged goal is shop-only and cannot inherit that pack assumption.
