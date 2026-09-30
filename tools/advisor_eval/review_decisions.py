"""Bounded offline evidence packets and structural alternatives from verified copies.

No policy/scorer execution, simulated worlds, game discovery, or automatic fixes.
Usage: python tools/advisor_eval/review_decisions.py --copy-dir COPY/logs
       --manifest COPY/manifest.json --output NEW_DIRECTORY
"""
from collections import Counter
from itertools import combinations
from math import comb
from pathlib import Path
import argparse
import json
import sys

try:
    from . import flag_suspect_decisions as screen
except ImportError:
    import flag_suspect_decisions as screen

SCHEMA = 'decision_review443.v1'
LIMITS = dict(packets=128, sample=32, flags=256, contradictions=32,
              hand=12, subsets_per_packet=2048, subsets_total=32768,
              output_bytes=67108864, input_decisions=100000, finding_groups=128)
ELIGIBILITY = ('discard', 'clearing play', 'Joker buy/choose', 'voucher buy',
               'Joker sell', 'leave_shop', 'skip_pack', 'reroll')
UNASSESSED = ('non-clearing play', 'consumable use/purchase/choice', 'open pack',
              'ordering', 'other actions without a qualified settlement join')
STAGES = ('observation', 'candidates', 'valuation', 'admission', 'budget',
          'arbitration', 'settlement')


def integer(x):
    return type(x) is int and x >= 0


def key(case):
    a = case['anchors']['request']
    return screen.sha(screen.encoded([case['scope'], a['sequence'], a['event_sha256']]))


def flag_case(flag):
    return dict(scope=flag['scope'], run=flag['run'], version=flag['version'],
                state=flag['decision_context'], advice=flag['recorded_advice'],
                action=flag['action'], anchors=flag['anchors'])


def issues(case):
    """Classify only explicit receipt evidence. No game-value inference."""
    advice, action, state = case['advice'], case['action'], case['state']
    risk = screen.obj(screen.obj(advice.get('yorick_review')).get('risk'))
    finish = screen.obj(advice.get('discard_before_clear'))
    found = []

    def add(code, stage, confidence, severity, evidence, test):
        found.append(dict(code=code, stage=stage, confidence=confidence,
                          severity=severity, evidence=evidence, next_test=test,
                          strategic_regret_established=False))

    for name, receipt in (('risk', risk), ('discard_before_clear', finish)):
        final = receipt.get('final_action_kind')
        if isinstance(final, str) and final != action.get('kind'):
            add('final_action_receipt_mismatch', 'arbitration', 'established_receipt_inconsistency',
                'high', dict(receipt=name, reported=final, settled=action.get('kind')),
                'Trace the final override and receipt stamping; reproduce the contradictory final action.')
    if integer(finish.get('remaining_discards')) and integer(state.get('discards_left')) and finish['remaining_discards'] != state['discards_left']:
        add('discard_resource_receipt_mismatch', 'observation', 'established_receipt_inconsistency',
            'high', dict(recorded=finish['remaining_discards'], observed=state['discards_left']),
            'Check receipt freshness against the linked observation and final stamping.')
    if risk.get('schema') is not None:
        # Current compact risk has no nested schema; unfamiliar extensions are not interpreted.
        return found
    rows = risk.get('by_size')
    rows = rows if isinstance(rows, list) else []
    for row in rows[:5]:
        row = screen.obj(row)
        if integer(row.get('qualified')) and integer(row.get('compared')) and row['qualified'] > row['compared']:
            add('qualified_exceeds_compared', 'admission', 'established_receipt_inconsistency',
                'medium', row, 'Manufacture this candidate-count path and check sample-family accounting.')
    if integer(risk.get('qualified_five_count')) and risk['qualified_five_count'] > 0:
        count = len(screen.arr(action.get('indices'))) if action.get('kind') == 'discard' else 0
        if count < 5:
            add('qualified_five_not_selected', 'arbitration', 'recorded_alternative_signal',
                'high', dict(qualified_five_count=risk['qualified_five_count'], chosen_cards=count,
                             final_action_matches_search=risk.get('final_action_matches_search')),
                'Recover physical candidate IDs, complete common worlds and final override reason. Counts alone do not prove a better action.')
    incomplete = sum(r.get('incomplete', 0) for r in rows if isinstance(r, dict) and integer(r.get('incomplete', 0)))
    if incomplete:
        add('incomplete_discard_comparison', 'budget', 'recorded_coverage_gap', 'medium',
            dict(incomplete_candidates=incomplete),
            'Isolate which candidates exhausted work; compare on invented bounded cases without changing production caps.')
    if finish.get('status') == 'exception':
        add('discard_exception', 'admission', 'recorded_exception', 'medium',
            dict(reason=finish.get('reason'), category=finish.get('category')),
            'Test the stated exception and its nearest safe alternative; the exception may be justified.')
    return found


class Reservoir:
    """Deterministic bottom-k by evidence identity, independent of game outcome."""
    def __init__(self, cap):
        self.cap, self.rows, self.population = cap, {}, 0

    def add(self, case):
        self.population += 1
        identity = key(case)
        if identity in self.rows:
            raise screen.ScreenError('Duplicate settled observer identity')
        self.rows[identity] = case
        if len(self.rows) > self.cap:
            del self.rows[max(self.rows)]


class Collector:
    def __init__(self, sample_size=32, excluded=None):
        self.excluded = excluded
        self.flag_ids, self.rule_counts = set(), Counter()
        self.settled, self.actions = 0, Counter()
        self.sample = Reservoir(sample_size)
        self.contradictions = Reservoir(LIMITS['contradictions'])
        self.finding_counts = Counter()
        self.groups, self.group_omitted = {}, 0

    def flag(self, row):
        self.flag_ids.add(key(flag_case(row)))
        self.rule_counts[row['rule']] += 1

    def observe(self, case):
        self.settled += 1
        screen.require(self.settled <= LIMITS['input_decisions'], 'Decision cap exceeded')
        self.actions[case['action'].get('kind', 'unknown')] += 1
        if self.excluded is not None:
            if key(case) not in self.excluded:
                self.sample.add(case)
            return
        findings = issues(case)
        seen_groups = set()
        for issue in findings:
            self.finding_counts[issue['code']] += 1
            reason = str(issue['evidence'].get('reason', ''))[:256]
            grouping = (issue['code'], issue['stage'], issue['confidence'], reason)
            if grouping not in self.groups:
                if len(self.groups) >= LIMITS['finding_groups']:
                    self.group_omitted += 1
                    continue
                self.groups[grouping] = dict(code=issue['code'], stage=issue['stage'],
                    confidence=issue['confidence'], recorded_reason=reason,
                    occurrences=0, decisions=0, examples=[], next_test=issue['next_test'],
                    common_cause_established=False)
            group = self.groups[grouping]; group['occurrences'] += 1
            if grouping not in seen_groups:
                group['decisions'] += 1; seen_groups.add(grouping)
                if len(group['examples']) < 3:
                    group['examples'].append(dict(packet_id=key(case), request=case['anchors']['request']))
        if any(x['confidence'] == 'established_receipt_inconsistency' for x in findings):
            self.contradictions.add(case)


def discard_alternatives(case, budget):
    """Exhaustive public selection constraints, explicitly NOT a score oracle."""
    s, action = case['state'], case['action']
    out = dict(scope='public_selection_constraints_only', policy_or_scorer_executed=False,
               survival_verified=False, strategic_optimality_proven=False, complete=False,
               candidates=[], next_test='Qualify legality, refill/order, retained scoring and full resource consequences before preferring any candidate.')
    def stop(reason):
        out['reason'] = reason
        return out
    if s.get('phase') != 'hand':
        return stop('not_a_hand_decision')
    if not integer(s.get('discards_left')):
        return stop('discard_count_unknown')
    if s['discards_left'] == 0:
        return stop('no_discards_available')
    hand, selection = screen.arr(s.get('hand')), screen.arr(s.get('hand_selection'))
    n = len(hand)
    if not 1 <= n <= LIMITS['hand']:
        return stop('hand_size_outside_structural_solver_scope')
    if not integer(s.get('hand_limit')) or s['hand_limit'] < 1:
        return stop('selection_limit_unknown')
    ids = [c.get('id') for c in hand]
    if not all(screen.ident(i) for i in ids) or len(set(ids)) != n:
        return stop('physical_identity_missing_or_duplicated')
    if len(selection) != n or any(r.get('id') != ids[i] or type(r.get('forced')) is not bool for i, r in enumerate(selection)):
        return stop('forced_selection_metadata_unknown')
    forced = {i+1 for i, r in enumerate(selection) if r['forced']}
    maximum = min(5, s['hand_limit'], n)
    total = sum(comb(n-len(forced), k-len(forced)) for k in range(max(1, len(forced)), maximum+1))
    out.update(expected_candidates=total, forced_indices=sorted(forced), selection_limit=maximum,
               physical_ids=ids, full_game_legality_verified=False)
    if total > LIMITS['subsets_per_packet'] or total > budget['remaining']:
        return stop('enumeration_budget_insufficient_no_partial_optimum')
    budget['remaining'] -= total
    chosen = action.get('indices') if action.get('kind') == 'play' else None
    anchor = set(chosen) if isinstance(chosen, list) and chosen and all(type(i) is int and 1 <= i <= n for i in chosen) and len(set(chosen)) == len(chosen) else None
    resources = {}
    death = any(c.get('key') == 'c_death' for c in s.get('consumeables', []))
    for i, c in enumerate(hand, 1):
        labels = []
        if c.get('unknown'):
            labels.append('concealed_effects_unknown')
        if c.get('enhancement') not in (None, 'c_base'):
            labels.append('enhancement:' + str(c['enhancement']))
        if c.get('seal'):
            labels.append('seal:' + str(c['seal']))
        if c.get('edition'):
            labels.append('edition_present')
        if death:
            labels.append('held_Death_source_value_unassessed')
        if labels:
            resources[str(i)] = labels
    for size in range(maximum, 0, -1):
        for ix in combinations(range(1, n+1), size):
            if not forced.issubset(ix):
                continue
            out['candidates'].append(dict(indices=list(ix), cards=size,
                retains_chosen_play=not anchor.intersection(ix) if anchor is not None else None,
                annotated_indices=[i for i in ix if str(i) in resources]))
    assert len(out['candidates']) == total
    out['candidates'].sort(key=lambda r: (r['retains_chosen_play'] is not True, -r['cards'], r['indices']))
    retained = [r for r in out['candidates'] if r['retains_chosen_play'] is True]
    out.update(complete=True, reason='enumerated_all_structural_subsets',
               resource_annotations=resources, retained_play_indices=sorted(anchor) if anchor is not None else None,
               maximum_batch_preserving_chosen_play=max((r['cards'] for r in retained), default=0) if anchor is not None else None,
               retained_play_forced_conflict=sorted(anchor & forced) if anchor is not None else [],
               proposal_order='Retain the actual chosen-play cards first, then larger batch, then indices; this is a diagnostic order, not a value ranking.',
               exact_result_scope='Maximum batch retaining the recorded chosen-play indices under explicit selection constraints only; no winning-hand or value certificate.')
    return out


def recorded_alternatives(case):
    """Physical offer-bound receipt rows; merit is never a dominance certificate."""
    p = screen.obj(screen.obj(case['advice'].get('copy_death_review')).get('pack'))
    visible = {c.get('id'): c for c in case['state'].get('pack_cards', []) if screen.ident(c.get('id'))}
    rows = screen.arr(p.get('candidates'))
    matched = []
    for row in rows[:30]:
        r = screen.obj(row); card = visible.get(r.get('offer_id'))
        if card and card.get('key') == r.get('key') and not card.get('unknown'):
            matched.append(r)
    return dict(rows=matched, rows_omitted=max(0, len(rows)-30), unmatched_rows=min(30, len(rows))-len(matched),
                receipt_complete=p.get('complete') is True and not p.get('incomplete') and not p.get('truncated') and not p.get('attempted_truncated'),
                shared_world_identity_present=False, resource_comparison_complete=False,
                strategic_ranking_certified=False,
                next_test='Compare visible offer endpoints, full retained Joker/consumable inventory, financing, survival and horizon on qualified common worlds. Scalar merit alone is insufficient.')


def packet(case, flags, source, budget):
    findings = issues(case)
    alternatives = discard_alternatives(case, budget)
    receipts = recorded_alternatives(case)
    confidence = 'established_receipt_inconsistency' if any(x['confidence'] == 'established_receipt_inconsistency' for x in findings) else 'recorded_alternative_signal' if any(x['confidence'] == 'recorded_alternative_signal' for x in findings) else 'review_hypothesis' if flags or findings else 'unflagged_audit_sample'
    risk = screen.obj(screen.obj(case['advice'].get('yorick_review')).get('risk'))
    candidate_status = 'structural_only' if alternatives['complete'] else 'recorded_only' if receipts['rows'] or risk.get('candidate_count') else 'unknown'
    stages = dict(observation='verified_public_links_projected_state', candidates=candidate_status,
                  valuation='unknown_independent_value', admission='recorded_only' if risk else 'unknown',
                  budget='recorded_incomplete' if any(x['stage'] == 'budget' for x in findings) else 'coverage_not_certified',
                  arbitration='recorded_override' if risk.get('final_action_matches_search') is False else 'not_fully_recorded',
                  settlement='verified_supported_effect')
    # Earliest missing evidence for proving an alternative better, NOT a causal diagnosis.
    legal_receipt = any(r.get('legal') is True and r.get('status') == 'complete'
                        and r.get('admitted') is True for r in receipts['rows'])
    first_gap = 'valuation' if legal_receipt else 'candidates'
    return dict(id=key(case), schema=SCHEMA, source=source, confidence=confidence,
                severity='high' if any(x['severity'] == 'high' for x in findings) or any(f['priority'] >= 80 for f in flags) else 'medium' if flags or findings else 'unassessed',
                run=case['run'], scope=case['scope'], version=case['version'], anchors=case['anchors'],
                chosen_action=case['action'], public_state=case['state'], settled_state=case.get('after'),
                advice=case['advice'], flags=[dict(id=f['id'], rule=f['rule'], evidence=f['evidence'], competing_explanation=f['competing_explanation']) for f in flags],
                findings=findings, stages=stages, first_unresolved_stage=first_gap,
                first_unresolved_stage_is_root_cause=False, strategic_regret_established=False,
                discard_alternatives=alternatives, recorded_pack_alternatives=receipts,
                next_test=findings[0]['next_test'] if findings else alternatives['next_test'] if case['state'].get('phase') == 'hand' else receipts['next_test'],
                execution_authorized=False)


def analyze(copy_dir, manifest, max_packets=96, sample_size=16):
    screen.require(type(max_packets) is int and 1 <= max_packets <= LIMITS['packets'], 'Invalid packet cap')
    screen.require(type(sample_size) is int and 0 <= sample_size <= min(LIMITS['sample'], max_packets), 'Invalid sample cap')
    tool_paths = (Path(__file__), Path(screen.__file__), Path(sys.modules[screen.parsed.__module__].__file__))
    tool_hashes = {p.name:screen.file_sha(p) for p in tool_paths}
    first = Collector(sample_size)
    raw = screen.analyze(copy_dir, manifest, LIMITS['flags'], on_settled=first.observe, on_flag=first.flag)
    # A second verified pass permits exact bottom-k UNFLAGGED sampling even if a
    # watched offer closes later, or its flag was dropped from the ranked report.
    second = Collector(sample_size, excluded=first.flag_ids)
    again = screen.analyze(copy_dir, manifest, 1, on_settled=second.observe)
    screen.require(raw['manifest_sha256'] == again['manifest_sha256'] and raw['inputs'] == again['inputs'] and raw['events'] == again['events'] and first.settled == second.settled, 'Verified analysis passes disagree')
    grouped_flags, flag_order = {}, []
    for flag in raw['flags']:
        identity = key(flag_case(flag))
        if identity not in grouped_flags:
            flag_order.append(identity); grouped_flags[identity] = []
        grouped_flags[identity].append(flag)
    cases, sources = {}, {}
    # Reserve the requested blind-spot sample; keep contradictions ahead of old
    # heuristic priority in the remaining bounded queue.
    for identity, case in sorted(second.sample.rows.items()):
        cases[identity] = case; sources[identity] = 'legacy_unflagged_bottom_k'
    for identity, case in sorted(first.contradictions.rows.items()):
        if identity in cases or len(cases) < max_packets:
            cases[identity] = case; sources[identity] = 'receipt_inconsistency'
    for identity in flag_order:
        if identity not in cases and len(cases) < max_packets:
            cases[identity] = flag_case(grouped_flags[identity][0]); sources[identity] = 'heuristic_flag'
    rank = {'receipt_inconsistency': 0, 'heuristic_flag': 1, 'legacy_unflagged_bottom_k': 2}
    order = sorted(cases, key=lambda k: (rank[sources[k]], -max((f['priority'] for f in grouped_flags.get(k, [])), default=0), k))
    budget = {'remaining': LIMITS['subsets_total']}
    packets = [packet(cases[k], grouped_flags.get(k, []), sources[k], budget) for k in order]
    screen.require(tool_hashes == {p.name:screen.file_sha(p) for p in tool_paths}, 'Tool source changed during analysis')
    coverage = dict(eligible_settled_decisions=first.settled, eligible_by_action=dict(first.actions),
                    eligible_classes=ELIGIBILITY, unsupported_settlement_classes=UNASSESSED,
                    legacy_flagged_decisions=len(first.flag_ids), legacy_unflagged_population=second.sample.population,
                    sample_retained=len(second.sample.rows), sample_rule='Bottom SHA256(scope, request sequence, request event hash) among ALL eligible decisions with NO legacy rule hit, including capped-away hits.',
                    sample_representative_of_all_actions=False, raw_rule_hits=dict(first.rule_counts),
                    all_eligible_finding_counts=dict(first.finding_counts),
                    finding_group_occurrences_omitted=first.group_omitted,
                    contradiction_decisions=first.contradictions.population,
                    contradiction_reservoir_omitted=max(0, first.contradictions.population-LIMITS['contradictions']),
                    packets_retained=len(packets), legacy_flagged_decisions_without_packet=len(first.flag_ids-set(cases)),
                    legacy_flag_rows_omitted=raw['flags_omitted'], old_reader_counts=raw['counts'],
                    old_reader_suppressions=raw['suppressed_or_unmodeled'],
                    unconfirmed_actions_at_tail=raw['unconfirmed_actions_at_tail'],
                    unconfirmed_rule_candidates_at_tail=raw['unconfirmed_rule_candidates_at_tail'],
                    contradictions_without_packet=first.contradictions.population-sum(k in first.contradictions.rows for k in cases))
    return dict(schema=SCHEMA, status='verified_offline_review', limits=LIMITS,
                policy_executed=False, scorer_executed=False, simulated_worlds=0,
                strategic_regret_established=False, win_rate_claimed=False,
                events=raw['events'], manifest_sha256=raw['manifest_sha256'], inputs=raw['inputs'],
                outside_predecessors_verified=raw['outside_predecessors_verified'],
                tool_hashes=tool_hashes,
                coverage=coverage, subset_candidates_enumerated=LIMITS['subsets_total']-budget['remaining'],
                investigation_groups=sorted(first.groups.values(), key=lambda g: (-g['decisions'],g['code'],g['recorded_reason'])),
                context_groups=raw['review_groups'], packets=packets)


def markdown(report):
    c = report['coverage']
    lines = ['# Decision evidence and alternatives', '',
        'Receipt inconsistencies are not proof of strategic regret. Structural alternatives are unscored and never dispatched.', '',
        f"{c['eligible_settled_decisions']} eligible settlements; {c['legacy_flagged_decisions']} legacy-flagged decisions; {c['legacy_unflagged_population']} legacy-unflagged; {c['sample_retained']} sampled.",
        f"{len(report['packets'])} packets; {c['legacy_flagged_decisions_without_packet']} flagged decisions omitted by caps. Eligible classes are restricted; non-clearing plays and consumable actions are not covered.", '',
        'Recorded reason groups across all eligible settlements; shared reasons do not establish shared causes.', '',
        '| Finding | Recorded reason | Decisions | Stage |', '|---|---|---:|---|']
    def cell(x):
        return str(x).replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')
    for g in report['investigation_groups']:
        lines.append('| '+' | '.join(map(cell,(g['code'],g['recorded_reason'],g['decisions'],g['stage'])))+' |')
    lines += ['', '| Packet | Run | Request | Confidence | First evidence gap | Next test |', '|---|---:|---:|---|---|---|']
    for p in report['packets']:
        lines.append('| '+' | '.join(map(cell, (p['id'][:12], p['run'].get('run_number'), p['anchors']['request']['sequence'], p['confidence'], p['first_unresolved_stage'], p['next_test'])))+' |')
    lines += ['', 'See report.json for exact anchors, chosen action, public state, findings, all enumerated subsets, forced-card conflicts, resource annotations and recorded pack candidates.',
              'adjudication.json is an editable review ledger. challenge_queue.json contains test specifications only; it authorizes no policy execution or experiment.']
    return '\n'.join(lines)+'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--copy-dir', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--max-packets', type=int, default=96)
    parser.add_argument('--sample-size', type=int, default=16)
    args = parser.parse_args()
    try:
        args.output.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        print(str(error), file=sys.stderr); return 1
    try:
        report = analyze(args.copy_dir, args.manifest, args.max_packets, args.sample_size)
        ledger = [dict(id=p['id'], status='unreviewed', diagnosis=None, first_failing_stage=None,
                       alternative=None, falsifier=p['next_test'], evidence_paths=[], independent_oracle=None,
                       negative_controls=[], holdout_cases=[], loaded_followup=None) for p in report['packets']]
        queue = [dict(packet_id=p['id'], anchors=p['anchors'], hypothesis=p['next_test'],
                      required_scope='Complete mechanics/resources and public-information constraints; compare actual continuation policies when necessary.',
                      execution_authorized=False, experiment_registered=False,
                      candidate_indices=[r['indices'] for r in p['discard_alternatives']['candidates'][:16]],
                      proposal_preview_only=True, full_candidates_in_report=True) for p in report['packets']]
        outputs = {'report.json': json.dumps(report, indent=2, allow_nan=False)+'\n',
                   'REPORT.md': markdown(report), 'adjudication.json':json.dumps(ledger, indent=2)+'\n',
                   'challenge_queue.json':json.dumps(queue, indent=2)+'\n'}
        screen.require(sum(len(x.encode('utf-8')) for x in outputs.values()) <= LIMITS['output_bytes'], 'Output byte cap exceeded')
        for name, content in outputs.items():
            with (args.output/name).open('x', encoding='utf-8') as f:
                f.write(content)
        with (args.output/'COMPLETE.json').open('x', encoding='utf-8') as f:
            json.dump({'status':report['status'], 'files':{n:screen.file_sha(args.output/n) for n in outputs}}, f, indent=2)
        print(json.dumps(dict(status=report['status'], coverage=report['coverage'], subsets=report['subset_candidates_enumerated'])))
        return 0
    except (OSError, screen.ArchiveError, screen.ScreenError, TypeError, ValueError, KeyError, RecursionError) as error:
        with (args.output/'error.json').open('x', encoding='utf-8') as f:
            json.dump({'status':'failed_no_trusted_report', 'error':str(error)}, f)
        print(str(error), file=sys.stderr); return 1


if __name__ == '__main__':
    raise SystemExit(main())
