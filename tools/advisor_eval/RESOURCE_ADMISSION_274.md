# Resource override admission and public deck backs — 2.74

A captured original-source decision in the selected TO run used a16-point High
Card cycle while a complete24-world discard estimate averaged547.5833. An8-world
fixed-policy continuation preferred playing by6/8 versus5/8 clears, while omitting
all subsequent discard decisions. Its actual273 episode later lost to Pillar;
the fixed-policy estimate never established that either action was a sure win.

For no owned Jokers and no Observatory, when the incumbent is discard and another
discard would remain, a play-now override now requires complete, non-regressing
paired utility/clear outcomes. Crossed/incomplete worlds retain the incumbent.
The aggregate winner is separately recorded; resource_comparison.best reflects
the retained policy so downstream finishing/consumable planners do not consume
rejected evidence. Every existing sample and scorer budget remains unchanged.
This is a conservative admission rule, not a claim of full optimal continuation.

Source compatibility also exposed that ordinary remaining-deck cards have
face_down=true in the original game. Their public composition remains known.
Upgraded Straight/Flush targets now admit these normal backs; unknown/concealed
identities and held face-down cards still abstain. Hidden order remains unused.

Root component lease2: runs/jokerless271_push_20260912_214242/
root_component02_step19_resource/report.json. One15s worker completed in2.822s,
frozen policies/input/source evidence and unchanged-default fullDecision.run.
Baseline exactly reproduces sourceplay[1,5,6,7,8]; candidate chooses
discard[1,2,3,4]. Both105196evaluations, no truncation or mutation. No episode was
replayed by that component test and no source rescue is imputed from it.

Tests: advisor_resource_guard.lua45checks covers complete dominance, crossed
worlds, nonfinite/incomplete inputs and protected/one-discard controls, including
actual finite-population play-first behavior. Existing resource199, sampled435,
finishing264, owned93, draw-target37 and fast-clear24 checks pass. Full274candidate:
107Lua fixtures /249Python tests, unchanged bytes. Installed13:20:37CDT with
51verifieddeploymentfiles; settings and both nativeDLLs preserved.

The new separately registered dependent full attempt uses fresh original
initialization, a changed hand policy, prior trace/registration and the component
repair receipt. It consumes a new shared one-use lease; the prior loss stays
unchanged. Its result belongs in JOKERLESS_PUSH_271.md, not inferred here.
