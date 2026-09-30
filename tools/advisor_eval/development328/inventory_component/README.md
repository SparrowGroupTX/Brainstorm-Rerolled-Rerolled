# Replacement inventory integration

Root runtime files were not edited by this component. Candidate `Brainstorm/Advisor/strategy.lua` is detached from the current root version; compose its small patch with the separate complete-replacement comparison fix before installation.

The existing bounded `inventory_value` participates in before/after row utility at the three generic Joker replacement paths: visible shop sale/buy, revealed pack sale/choose, and supported catalog replacement evaluation. It counts all held ordinary and Negative consumables, active physical/copy-chain Perkeo effects and the existing nonlinear Observatory model. It changes no sampling, score limit, affordability, legality, complete comparison or survival dominance gate. These values remain heuristic utilities, not calibrated win rates.

The exported `shop_sequence_api.build_value` remains Joker-only because `shop_sequences.lua` already adds inventory separately. The added `replacement_value` API exposes the combined endpoint valuation for meaningful manufactured checks; its use does not cause extra score calls. Special Egg/Omelette policies are unchanged.

Manufactured evidence: a generic full three-Joker row, known visible Blueprint and insufficient cash can still sell empty Perkeo; the same row holding ordinary plus Negative Mercury now preserves its actual copying source. The pack endpoint behaves similarly. At the manufactured level-4 Pair, unit Planet utility is `8 + 65*(15/55 + 1/5)`. Removing sole Perkeo loses exactly two future copy utilities while leaving both original Planets. With two matching Planets and Observatory it also loses exactly 67.5 prospective held utility; existing held utility stays 30. Mixed inventories and copy-Joker removal are covered. This does not rescore the observed Acorn run or establish that keeping Perkeo would rescue it.

Validation: new fixture 25 checks; eight existing fixtures pass against detached candidate: strategy 238, Perkeo timing 21, Perkeo inventory 110, shop sequences 55, shop order 103, owned Fool shop 92, shop Planet ties 47, catalog replacements 22. Command:

`python tests/run_lua_tests.py tools/advisor_eval/development328/inventory_component/tests/run_replacement_inventory.lua tools/advisor_eval/development328/inventory_component/tests/run_relevant.lua`

The two fixture-authoring errors are preserved separately in JSON receipts. Neither was a source experiment or product regression. Full integrated candidate and exact-installed regression belong to root release evidence.
