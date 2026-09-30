# Teacher expired-rental disposal 357

Passive review confirms that teacher mode inadvertently suppressed an existing
economy safeguard. In RH45AD21, observation6277 at18:20:36Z on2026-09-16 shows
Ante6/round14, $92, and The Trio(card:824) with rental=true, perishable=true,
perish_tally=0 and debuff=true. Its public Gold status is complete. The snapshot
has teacher_profile=perkeo_yorick_win_v1 and collection_progress, but no
completionist_goal. The row is Blueprint, Yorick, Greedy Joker, expired Trio,
Perkeo, with one Negative Hermit; the upcoming boss is The Wheel.

The same expired rental remains in24 shop observations. The five leave-shop
attempts are6326,6466,6605,6701,6862 at$76,$111,$154,$203,$242; the associated
advisor_execute request sequences are one higher. The run subsequently loses
Ante7 Big at130932/165000 (terminal6968). Retention is observed; the contribution
of this mistake to the loss and the result of an earlier sale are unmeasured.
The repair is not evidence that this run would have been rescued.

The source gate in Advisor/joker_retirement.lua previously required
completionist_goal. The minimal change reuses collection_progress only when
completionist_goal is absent and the exact explicit win-first teacher profile
is active. It does not enable collection acquisition, retention or speed skips,
and does not mutate the snapshot or restore the objective. Every existing
identity, already-completed status, activity, cash, boss, copy-target,
Temperance/Fool, whole-inventory and unsupported-effect check remains.

New tests/advisor_teacher_retirement357.lua uses manufactured public rows,
not copied recorded states or policy replay. Its39 checks cover the ordinary
Decision/Strategy entry points, preserved input, zero score cost, exact rental
cash and copy/inventory proof, explicit teacher/ledger admission and negative
cases for unknown metadata, malformed active objective, missing sticker,
unsupported/valuable effects, bosses and consumables. The baseline fails the
first teacher-disposal assertion; the repaired code passes. The unchanged
retirement38-check fixture, strategy238-check fixture and runtime781-check
fixture also pass. validation.json and validation.log retain the exact input
hashes, bounded command and output; baseline.* and joker_retirement.before.lua
preserve the prior failure and source.

evidence.json contains original frozen segment/ordinal/raw-record hash anchors,
the selected public fields, all24 shop observation IDs, five leave attempts and
the terminal record. review.py only decodes the already frozen logs and writes
this compact evidence; it does not evaluate a policy or access game/save/profile
files. No experiments, searches, new runs, GPU work or game control occurred.
