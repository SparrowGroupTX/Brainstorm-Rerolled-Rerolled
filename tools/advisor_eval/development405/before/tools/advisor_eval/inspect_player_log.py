"""Bounded public-log index and exact targeted extraction; originals remain untouched.

Use ``inspect explicit.brj --output new-report.json`` for a context-sized index.
Use ``extract explicit.brj --input-sha256 HASH --ordinal 123 --output new.jsonl``
to retrieve exact original bytes. A summary is an index, not a lossless replacement.
No directory discovery, game/source execution, save access, or outcome inference.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import sys

try:
    import analyze_player_timing as timing
    from read_player_log import ArchiveError, parsed, records
except ModuleNotFoundError:
    from tools.advisor_eval import analyze_player_timing as timing
    from tools.advisor_eval.read_player_log import ArchiveError, parsed, records

DEFAULT_OUTPUT_BYTES = 16384
MAX_OUTPUT_BYTES = 65536
MAX_EXTRACT_EVENTS = 16
MAX_EXTRACT_BYTES = 4194304
MAX_LABELS = 256
MAX_STATE_HASHES = 100000
ERRORS = (OSError, ArchiveError, timing.TimingError, RecursionError, OverflowError)


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8', errors='backslashreplace')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def label(value):
    """Display bounded labels, with a digest instead of lossy ambiguous clipping."""
    if not isinstance(value, (str, bool, int, float)) or value is None:
        return '<absent-or-nonscalar>'
    result = str(value)
    return result if len(result) <= 96 else '<long-label-sha256:' + digest(result.encode('utf-8', errors='backslashreplace')) + '>'


def table(rows, total=None):
    rows = list(rows)
    total = len(rows) if total is None else total
    return {'rows': rows, 'row_count': total, 'rows_omitted': total - len(rows)}


class Counts:
    def __init__(self):
        self.counts = Counter()
        self.overflow = 0

    def add(self, key, amount=1):
        key = label(key)
        if key in self.counts or len(self.counts) < MAX_LABELS:
            self.counts[key] += amount
        else:
            self.overflow += amount

    def report(self):
        return {**table({'label': key, 'count': count} for key, count in self.counts.most_common()),
                'untracked_label_occurrences': self.overflow}


class Inspection:
    def __init__(self, options=None):
        self.timing = timing.Summary(options)
        self.kinds, self.actions, self.outcomes = Counts(), Counts(), Counts()
        self.anomalies, self.field_bytes = Counts(), Counts()
        self.top_events = []
        self.examples = []
        self.example_count = 0
        self.snapshots = {}
        self.snapshot_count = self.snapshot_bytes = 0
        self.repeat_count = self.repeat_bytes = self.consecutive_repeats = 0
        self.previous_snapshot = {}
        self.last_anchor = {}
        self.gaps = []
        self.gap_count = 0
        self.locators = {}

    def consume(self, raw, metadata, source, locator):
        # The existing analyzer validates all sequences, clocks and compact timing
        # receipts before any aggregate below receives credit for this record.
        self.timing.consume(raw, metadata, source)
        event = parsed(raw)
        context = event.get('context') if isinstance(event.get('context'), dict) else {}
        details = event.get('details') if isinstance(event.get('details'), dict) else {}
        kind = event.get('kind')
        scope = 'archive:' + metadata['session'] if metadata.get('format') == 2 else 'jsonl:' + source
        self.kinds.add(kind)
        if kind == 'action_requested':
            self.actions.add(details.get('action'))
        if kind == 'auto_run' and details.get('event') == 'run_finished':
            self.outcomes.add(details.get('outcome'))
        flags = []
        if context.get('game_over') is True and context.get('won_field') is True:
            flags.append('game_over_with_incidental_won_field')
        if kind == 'action_callback_result' and details.get('callback_returned') is False:
            flags.append('callback_returned_false_not_completed_action')
        if kind == 'auto_run' and details.get('event') == 'session_stopped':
            flags.append('auto_run_session_stopped')
        if 'error' in str(kind).lower() or details.get('error') not in (None, False, ''):
            flags.append('explicit_error_field_or_event_name')
        if flags:
            for flag in flags:
                self.anomalies.add(flag)
            self.example_count += 1
            if len(self.examples) < self.timing.limits['max_examples']:
                self.examples.append({'flags': flags, 'kind': label(kind),
                                      'reason': label(details.get('reason')), 'locator': locator})
        row = {'decoded_bytes': len(raw), 'kind': label(kind), 'locator': locator}
        self.top_events.append(row)
        self.top_events.sort(key=lambda entry: entry['decoded_bytes'], reverse=True)
        del self.top_events[self.timing.limits['max_examples']:]
        # Values are re-serialized canonically. These sizes are diagnostic JSON
        # value sizes, not original byte spans; nested entries overlap parents.
        for key, value in event.items():
            self.field_bytes.add('/' + str(key), len(encoded(value)))
        for prefix, container in (('/context/', context), ('/details/', details)):
            for key, value in container.items():
                self.field_bytes.add(prefix + str(key), len(encoded(value)))
        snapshot = context.get('snapshot')
        if isinstance(snapshot, (dict, list)):
            state = encoded(snapshot)
            state_hash = digest(state)
            self.snapshot_count += 1
            self.snapshot_bytes += len(state)
            if state_hash in self.snapshots:
                self.repeat_count += 1
                self.repeat_bytes += len(state)
            else:
                timing.require(len(self.snapshots) < MAX_STATE_HASHES, 'Unique snapshot index cap reached')
                self.snapshots[state_hash] = locator
            if self.previous_snapshot.get(scope) == state_hash:
                self.consecutive_repeats += 1
            self.previous_snapshot[scope] = state_hash
            if isinstance(snapshot, dict):
                for key, value in snapshot.items():
                    self.field_bytes.add('/context/snapshot/' + str(key), len(encoded(value)))
        stamp = event.get('monotonic_seconds')
        if timing.number(stamp):
            previous = self.last_anchor.get(scope)
            if previous is not None:
                self.gap_count += 1
                self.gaps.append({'seconds': stamp - previous[0], 'before': previous[1],
                                  'after': locator, 'after_kind': label(kind)})
                self.gaps.sort(key=lambda entry: entry['seconds'], reverse=True)
                del self.gaps[self.timing.limits['max_examples']:]
            self.last_anchor[scope] = stamp, locator
        if kind == 'performance_window':
            self.locators[(scope, details['window_id'])] = locator

    def report(self):
        full = self.timing.report()
        decision = full['decisions']
        slow = full['slow_frames']

        def anchored(rows):
            return [{**row, 'locator': self.locators.get((row['scope'], row['window_id']))} for row in rows]

        metrics = []
        for name, value in full['metrics'].items():
            metrics.append({'metric': name, 'count': value['count'], 'total_seconds': value['total_seconds'],
                            'mean_seconds': value['mean_seconds'], 'max_seconds': value['max_seconds'],
                            'p95_bucket_bounds': value['histogram_quantile_bounds']['p95']})
        metrics.sort(key=lambda row: row['total_seconds'], reverse=True)
        return {
            'schema': 1, 'status': full['status'], 'complete_session_claimed': False,
            'purpose': 'Bounded inspection index. Original logs retain all information; exact extraction uses input SHA256 and event ordinal.',
            'inputs': table(full['inputs']), 'errors': table(full['errors']),
            'limits': full['limits'], 'events': full['events'], 'decoded_bytes': full['decoded_bytes'],
            'event_kinds': self.kinds.report(), 'requested_actions': self.actions.report(),
            'reported_terminal_labels_not_verified_outcomes': self.outcomes.report(),
            'anomaly_signals_not_diagnoses': self.anomalies.report(),
            'anomaly_examples': table(self.examples, self.example_count),
            'largest_events': table(self.top_events, full['events']),
            'canonical_field_value_bytes_overlapping': self.field_bytes.report(),
            'snapshot_repetition': {
                'canonicalization': 'Sorted compact UTF-8 JSON values; semantic repeats, not an exact original-byte equality claim.',
                'observations': self.snapshot_count, 'unique_canonical_snapshots': len(self.snapshots),
                'canonical_bytes': self.snapshot_bytes, 'repeated_observations': self.repeat_count,
                'repeated_canonical_bytes': self.repeat_bytes,
                'consecutive_snapshot_observation_repeats': self.consecutive_repeats,
                'scope': 'Global unique count; consecutive repeats only within each validated clock scope.',
            },
            'timing': {
                'performance_windows': full['performance_windows'], 'event_anchors': full['event_anchors'],
                'metrics': table(metrics), 'metric_groups': full['metric_groups'],
                'decisions': {key: value for key, value in decision.items() if key not in ('largest_elapsed_examples', 'examples_omitted')},
                'slow_frames': {key: value for key, value in slow.items() if key not in ('largest_reported_gap_or_update_examples', 'examples_omitted')},
                'largest_decisions': table(anchored(decision['largest_elapsed_examples']), decision['recorded']),
                'largest_slow_frames': table(anchored(slow['largest_reported_gap_or_update_examples']), slow['recorded']),
                'largest_inter_event_gaps_not_stall_proof': table(self.gaps, self.gap_count),
                'clock_failures_in_windows': full['clock_failures_in_windows'],
                'scopes': table({'scope': key, **value} for key, value in full['scopes'].items()),
            },
            'interpretation': [
                'Reported terminal labels are not audited wins; GAME.won alone is never used to classify a win.',
                'Canonical nested field sizes overlap and must not be added to original decoded bytes.',
                'Identical public snapshots do not establish identical hidden RNG or redundant advisor work.',
                'Inter-event gaps can include user waits, animation, unlogged work or idle time; they do not establish freezes or CPU usage.',
                'Timing metrics overlap parents; elapsed wall measurements are not CPU utilization. p95 values are histogram bounds.',
                'Missing, dropped, incomplete and unflushed timing records remain unknown, never zero.',
                'Locators name supplied-file index, one-based event ordinal, sequence, stored byte interval and exact decoded-event hash. BRJ2 extraction replays the validated prefix.',
            ],
        }


def inspect(inputs, options=None):
    inspection = Inspection(options)
    summary = inspection.timing
    paths = [Path(path) for path in inputs]
    total = 0
    seen = set()
    try:
        timing.require(0 < len(paths) <= summary.limits['max_files'], 'Explicit file count exceeds cap')
        for path in paths:
            resolved = path.resolve()
            timing.require(resolved not in seen, 'Duplicate input path')
            seen.add(resolved)
            timing.require(path.is_file(), 'Input must be an explicit regular file')
            size = path.stat().st_size
            timing.require(size <= summary.limits['max_file_bytes'], 'Input file byte cap exceeded')
            total += size
            timing.require(total <= summary.limits['max_total_bytes'], 'Total input byte cap exceeded')
        total = 0
        for file_index, path in enumerate(paths, 1):
            entry = {'file_index': file_index, 'path': str(path), 'status': 'reading'}
            summary.inputs.append(entry)
            reader = None
            try:
                with path.open('rb') as stream:
                    before = os.fstat(stream.fileno())
                    timing.require(before.st_size <= summary.limits['max_file_bytes'], 'Input grew beyond file cap')
                    total += before.st_size
                    timing.require(total <= summary.limits['max_total_bytes'], 'Inputs grew beyond total cap')
                    reader = timing.LimitedReader(stream, before.st_size)
                    iterator = records(reader)
                    ordinal = 0
                    while reader.remaining:
                        timing.require(summary.events < summary.limits['max_events'], 'Event cap reached; suffix not decoded')
                        start = reader.bytes
                        try:
                            raw, meta = next(iterator)
                        except StopIteration:
                            raise timing.TimingError('Input truncated while reading') from None
                        ordinal += 1
                        locator = {'file_index': file_index, 'ordinal': ordinal, 'sequence': meta['sequence'],
                                   'stored_start': start, 'stored_end': reader.bytes, 'event_sha256': digest(raw)}
                        inspection.consume(raw, meta, str(path.resolve()), locator)
                    after = os.fstat(stream.fileno())
                    timing.require(before.st_size == after.st_size and before.st_mtime_ns == after.st_mtime_ns,
                                   'Input changed while reading; use a stable explicit copy')
                    entry.update(status='parsed',stored_bytes=reader.bytes, sha256=reader.hash.hexdigest())
            except ERRORS:
                entry['status'] = 'incomplete'
                if reader:
                    entry.update(stored_bytes_read=reader.bytes, prefix_sha256=reader.hash.hexdigest())
                raise
    except ERRORS as error:
        summary.errors.append({'reason': str(error)[:512], 'complete_prefix_events': summary.events,
                               'remaining_inputs_not_read': True})
    return inspection.report()


def render(report, max_bytes=DEFAULT_OUTPUT_BYTES):
    """Fit valid JSON to a strict byte budget; every trimmed table counts omissions."""
    timing.require(type(max_bytes) is int and 4096 <= max_bytes <= MAX_OUTPUT_BYTES, 'Output budget must be 4096..65536 bytes')
    result = copy.deepcopy(report)
    result['output_budget'] = {'maximum_bytes': max_bytes, 'rows_omitted_for_output': 0,
                               'summary_is_lossless_replacement': False}

    def tables(value):
        if isinstance(value, dict):
            if isinstance(value.get('rows'), list) and value['rows']:
                yield value
            for child in value.values():
                yield from tables(child)
        elif isinstance(value, list):
            for child in value:
                yield from tables(child)

    while True:
        raw = encoded(result) + b'\n'
        if len(raw) <= max_bytes:
            return raw
        available = list(tables(result))
        timing.require(available, 'Non-tabular report metadata exceeds output budget')
        target = max(available, key=lambda value: len(encoded(value['rows'])))
        target['rows'].pop()
        target['rows_omitted'] += 1
        result['output_budget']['rows_omitted_for_output'] += 1


def extract(path, ordinals, expected_sha256, output, options=None):
    """Write selected original records exactly, after validating the full input hash.

    Selection is bounded in memory, and output is created only after all input
    records validate. Any decoder error leaves the requested output absent.
    """
    caps = timing.limits(options)
    timing.require(isinstance(expected_sha256, str) and re.fullmatch('[0-9a-f]{64}', expected_sha256), 'Expected input SHA256 is required')
    wanted = list(ordinals)
    timing.require(0 < len(wanted) <= MAX_EXTRACT_EVENTS and len(set(wanted)) == len(wanted)
                   and all(type(item) is int and 1 <= item <= caps['max_events'] for item in wanted),
                   'Choose 1..16 distinct positive event ordinals within the event cap')
    path, output = Path(path), Path(output)
    timing.require(path.resolve() != output.resolve(), 'Extraction output cannot be an input')
    timing.require(path.is_file(), 'Input must be an explicit regular file')
    found = []
    selected_bytes = 0
    decoded_bytes = 0
    with path.open('rb') as stream:
        before = os.fstat(stream.fileno())
        timing.require(before.st_size <= min(caps['max_file_bytes'], caps['max_total_bytes']), 'Input file byte cap exceeded')
        reader = timing.LimitedReader(stream, before.st_size)
        iterator = records(reader)
        ordinal = 0
        while reader.remaining:
            timing.require(ordinal < caps['max_events'], 'Event cap reached; extraction declined')
            try:
                raw, meta = next(iterator)
            except StopIteration:
                raise timing.TimingError('Input truncated while reading') from None
            ordinal += 1
            decoded_bytes += len(raw)
            timing.require(decoded_bytes <= caps['max_decoded_bytes'], 'Decoded-byte cap reached; extraction declined')
            if ordinal in wanted:
                selected_bytes += len(raw)
                timing.require(selected_bytes <= MAX_EXTRACT_BYTES, 'Exact extraction byte cap exceeded')
                found.append((ordinal, meta['sequence'], raw))
        after = os.fstat(stream.fileno())
        timing.require(before.st_size == after.st_size and before.st_mtime_ns == after.st_mtime_ns, 'Input changed while reading')
        timing.require(reader.hash.hexdigest() == expected_sha256, 'Expected input SHA256 does not match')
    timing.require(len(found) == len(wanted), 'Requested event ordinal is absent')
    data = b''.join(raw for _, _, raw in found)
    with output.open('xb') as stream:
        stream.write(data)
    output_path = str(output)
    return {'schema': 1, 'status': 'exact_selected_events_written', 'input_sha256': expected_sha256,
            'output': output_path if len(output_path) <= 512 else '<long-path-sha256:' + digest(output_path.encode('utf-8', errors='backslashreplace')) + '>',
            'output_path_hashed': len(output_path) > 512,
            'output_bytes': len(data), 'output_sha256': digest(data),
            'events': table({'ordinal': ordinal, 'sequence': sequence, 'event_sha256': digest(raw)}
                            for ordinal, sequence, raw in found),
            'validation': 'Original JSON/archive integrity; timing semantics are not required for diagnostic extraction.',
            'ordering': 'Original input order; exact original JSONL bytes, no re-serialization.'}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    read = sub.add_parser('inspect', help='Emit a bounded summary index')
    read.add_argument('inputs', nargs='+', type=Path)
    read.add_argument('--output', type=Path, help='Create a new summary file; existing files are never overwritten')
    fetch = sub.add_parser('extract', help='Write exact chosen events to a new file, never stdout')
    fetch.add_argument('input', type=Path)
    fetch.add_argument('--ordinal', type=int, action='append', required=True)
    fetch.add_argument('--input-sha256', required=True)
    fetch.add_argument('--output', type=Path, required=True)
    for command in (read, fetch):
        command.add_argument('--max-output-bytes', type=int, default=DEFAULT_OUTPUT_BYTES)
        for key, value in timing.DEFAULT.items():
            command.add_argument('--' + key.replace('_', '-'), type=int, default=value)
    args = parser.parse_args(argv)
    options = {key: getattr(args, key) for key in timing.DEFAULT}
    try:
        timing.require(4096 <= args.max_output_bytes <= MAX_OUTPUT_BYTES, 'Output budget must be 4096..65536 bytes')
        if args.command == 'inspect':
            report = inspect(args.inputs, options)
            raw = render(report, args.max_output_bytes)
            if args.output:
                with args.output.open('xb') as stream:
                    stream.write(raw)
            else:
                sys.stdout.write(raw.decode('utf-8'))
            return int(report['status'] == 'incomplete')
        receipt = extract(args.input, args.ordinal, args.input_sha256, args.output, options)
        sys.stdout.write(render(receipt, args.max_output_bytes).decode('utf-8'))
        return 0
    except ERRORS as error:
        print('Inspection/extraction declined; existing files preserved: ' + str(error)[:512], file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
