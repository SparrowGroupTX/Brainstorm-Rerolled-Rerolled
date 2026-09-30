"""Manufactured public journal files only; no player files, game or source runs."""
import copy
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zlib

from tools.advisor_eval import inspect_player_log as I


def raw(event):
    return (json.dumps(event, separators=(',', ':'), ensure_ascii=False) + '\n').encode()


def event(seq=1, kind='state_after_actions', snapshot=None, stamp=None):
    return {'schema': 1, 'sequence': seq, 'kind': kind,
            'monotonic_seconds': seq if stamp is None else stamp,
            'context': {'snapshot': {'hand': [{'id': 'card1', 'rank': 13}]} if snapshot is None else snapshot},
            'details': {}}


def frame(e, previous='-', snapshot=None):
    original = raw(e)
    body = {'schema': 2, 'session': 'manufactured', 'segment': 1,
            'previous_frame_sha256': previous, 'event_json': original.decode()}
    if snapshot is not None:
        text = raw(snapshot).rstrip(b'\n')
        offset = original.index(text)
        body.pop('event_json')
        body.update(prefix=original[:offset].decode(), suffix=original[offset+len(text):].decode(),
                    snapshot_id=I.digest(text))
        if previous == '-':
            body['snapshot_json'] = text.decode()
    body = raw(body)
    payload = zlib.compress(body)
    header = '\t'.join(['BRJ2', 'zlib', str(len(payload)), str(len(body)),
                        str(e['sequence']), I.digest(body), I.digest(original)]) + '\n'
    wire = header.encode() + payload + b'\n'
    return wire, I.digest(wire)


def window(seq=1):
    e = event(seq, 'performance_window', stamp=seq*5)
    e['context'] = {}
    e['details'] = {'schema': 1, 'window_id': seq, 'clock_scope': 'process_monotonic', 'units': 'seconds',
                    'start_seconds': (seq-1)*5, 'end_seconds': seq*5,
                    'bucket_upper_seconds': I.timing.BUCKETS,
                    'metrics': {'update_total': {'count': 2, 'total_seconds': .201, 'max_seconds': .2,
                                                'histogram': [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]}},
                    'slow_frames': [{'at_seconds': seq*5, 'update_seconds': .2, 'flags': {}}],
                    'slow_frames_dropped': 3, 'decisions_dropped': 0, 'decisions': {}, 'flags': {}}
    return e


class Inspection(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def file(self, events, name='input.jsonl'):
        path = self.folder / name
        path.write_bytes(events if isinstance(events, bytes) else b''.join(raw(e) for e in events))
        return path

    def inspect(self, events, options=None):
        return I.inspect([self.file(events)], options)

    def test_counts_sizes_and_exact_locators_do_not_dump_snapshot(self):
        e = event()
        e['context']['snapshot']['private_display_text'] = 'not for compact context' * 500
        p = self.file([e])
        before = p.read_bytes()
        r = I.inspect([p])
        self.assertEqual(r['events'], 1)
        self.assertEqual(r['decoded_bytes'], len(before))
        loc = r['largest_events']['rows'][0]['locator']
        self.assertEqual(loc, {'file_index': 1, 'ordinal': 1, 'sequence': 1, 'stored_start': 0,
                               'stored_end': len(before), 'event_sha256': I.digest(before)})
        self.assertEqual(r['inputs']['rows'][0]['sha256'], I.digest(before))
        self.assertNotIn(b'not for compact context', I.render(r))
        self.assertEqual(p.read_bytes(), before)

    def test_report_is_strictly_bounded_and_omissions_explicit(self):
        events = []
        for seq in range(1, 100):
            e = event(seq, 'error_' + str(seq))
            e['details']['reason'] = 'very detailed reason ' * 100
            e['context']['snapshot'].update({str(i): 'large value' for i in range(20)})
            events.append(e)
        r = self.inspect(events, {'max_examples': 64})
        rendered = I.render(r)
        self.assertLessEqual(len(rendered), 16384)
        result = json.loads(rendered)
        self.assertGreater(result['output_budget']['rows_omitted_for_output'], 0)
        self.assertEqual(result['events'], 99)
        self.assertEqual(result['anomaly_examples']['row_count'], 99)
        self.assertEqual(len(result['anomaly_examples']['rows']) + result['anomaly_examples']['rows_omitted'], 99)
        self.assertFalse(result['output_budget']['summary_is_lossless_replacement'])

    def test_counter_labels_and_long_values_are_bounded(self):
        counter = I.Counts()
        for i in range(500):
            counter.add('label_' + str(i))
        result = counter.report()
        self.assertEqual(result['row_count'], 256)
        self.assertEqual(result['untracked_label_occurrences'], 244)
        value = 'x' * 10000
        self.assertIn(I.digest(value.encode()), I.label(value))
        self.assertLess(len(I.label(value)), 100)

    def test_snapshot_repetition_canonical_scope_and_overlap_are_explicit(self):
        first = event()
        second = event(2, snapshot={'hand': [{'rank': 13, 'id': 'card1'}]})
        third = event(3, snapshot={'hand': [{'id': 'card2', 'rank': 13}]})
        r = self.inspect([first, second, third])
        s = r['snapshot_repetition']
        self.assertEqual(s['observations'], 3)
        self.assertEqual(s['unique_canonical_snapshots'], 2)
        self.assertEqual(s['repeated_observations'], 1)
        self.assertEqual(s['consecutive_snapshot_observation_repeats'], 1)
        fields = {row['label']: row['count'] for row in r['canonical_field_value_bytes_overlapping']['rows']}
        self.assertEqual(fields['/context/snapshot'], s['canonical_bytes'])
        self.assertIn('overlap', ' '.join(r['interpretation']))

    def test_inter_event_gap_is_not_a_freeze_or_cross_file_clock(self):
        a = self.file([event(1, stamp=1), event(2, stamp=20)], 'a.jsonl')
        b = self.file([event(1, stamp=100)], 'b.jsonl')
        r = I.inspect([a, b])
        gaps = r['timing']['largest_inter_event_gaps_not_stall_proof']
        self.assertEqual(gaps['row_count'], 1)
        self.assertEqual(gaps['rows'][0]['seconds'], 19)
        self.assertFalse(r['complete_session_claimed'])
        self.assertNotIn('cpu_percent', json.dumps(r))

    def test_reported_loss_and_incidental_won_flag_never_become_win(self):
        e = event(kind='auto_run')
        e['context'].update(game_over=True, won_field=True)
        e['details'].update(event='run_finished', outcome='loss')
        r = self.inspect([e])
        outcomes = r['reported_terminal_labels_not_verified_outcomes']['rows']
        self.assertEqual(outcomes, [{'label': 'loss', 'count': 1}])
        self.assertEqual(r['anomaly_signals_not_diagnoses']['rows'][0]['label'], 'game_over_with_incidental_won_field')
        self.assertNotIn('verified_wins', r)

    def test_callback_failure_gets_locator_without_completion_claim(self):
        e = event(kind='action_callback_result')
        e['details'] = {'callback_returned': False, 'reason': 'failed'}
        r = self.inspect([e])
        example = r['anomaly_examples']['rows'][0]
        self.assertIn('callback_returned_false_not_completed_action', example['flags'])
        self.assertEqual(example['locator']['ordinal'], 1)

    def test_existing_timing_validation_and_measurements_are_reused(self):
        r = self.inspect([window()])
        t = r['timing']
        self.assertEqual(t['performance_windows'], 1)
        self.assertEqual(t['metrics']['rows'][0]['total_seconds'], .201)
        self.assertEqual(t['metrics']['rows'][0]['p95_bucket_bounds']['upper_seconds'], .25)
        self.assertEqual(t['slow_frames']['source_dropped'], 3)
        self.assertEqual(t['largest_slow_frames']['rows'][0]['locator']['ordinal'], 1)
        bad = window(2)
        bad['details']['metrics']['update_total']['count'] = 3
        r = self.inspect([window(), bad])
        self.assertEqual(r['status'], 'incomplete')
        self.assertEqual(r['events'], 1)
        self.assertEqual(r['timing']['performance_windows'], 1)

    def test_brj3_metadata_shares_clock_window_and_state_scope_across_segments(self):
        inspector = I.Inspection()
        for seq, source in ((1, 'first.brj'), (2, 'second.brj')):
            e = window(seq)
            data = raw(e)
            meta = {'format': 3, 'session': 'manufactured-brj3', 'segment': seq, 'sequence': seq}
            locator = {'file_index': seq, 'ordinal': 1, 'sequence': seq, 'stored_start': 0,
                       'stored_end': len(data), 'event_sha256': I.digest(data)}
            inspector.consume(data, meta, source, locator)
        r = inspector.report()
        self.assertEqual(r['timing']['performance_windows'], 2)
        scopes = r['timing']['scopes']['rows']
        self.assertEqual(len(scopes), 1)
        self.assertEqual(scopes[0]['scope'], 'archive:manufactured-brj3')
        self.assertEqual(r['timing']['largest_inter_event_gaps_not_stall_proof']['row_count'], 1)
        anchors = r['timing']['largest_slow_frames']['rows']
        self.assertTrue(all(row['locator'] is not None for row in anchors))
        self.assertEqual({row['locator']['file_index'] for row in anchors}, {1, 2})

    def test_brj3_cross_segment_duplicate_clock_regression_and_sequence_gap_decline(self):
        for mutation in ('duplicate_window', 'clock_regression', 'sequence_gap'):
            summary = I.timing.Summary()
            e = window()
            meta = {'format': 3, 'session': 'manufactured-brj3', 'segment': 1, 'sequence': 1}
            summary.consume(raw(e), meta, 'first.brj')
            second = window(2)
            if mutation == 'duplicate_window':
                second['details']['window_id'] = 1
            elif mutation == 'clock_regression':
                second['monotonic_seconds'] = 4
            else:
                second['sequence'] = 3
            with self.assertRaises(I.timing.TimingError):
                summary.consume(raw(second), {**meta, 'segment': 2, 'sequence': second['sequence']}, 'second.brj')
            self.assertEqual(summary.events, 1)
            self.assertEqual(summary.windows, 1)

    def test_archive_snapshot_references_extract_exact_original_text(self):
        first, last = event(), event(2)
        one, h = frame(first, snapshot=first['context']['snapshot'])
        two, _ = frame(last, previous=h, snapshot=last['context']['snapshot'])
        p = self.file(one+two, 'input.brj')
        r = I.inspect([p])
        self.assertEqual(r['status'], 'parsed_supplied_records')
        largest = {row['locator']['ordinal']: row['locator'] for row in r['largest_events']['rows']}
        self.assertEqual(largest[2]['stored_start'], len(one))
        self.assertEqual(largest[2]['stored_end'], len(one+two))
        out = self.folder/'exact.jsonl'
        receipt = I.extract(p, [2], I.digest(one+two), out)
        self.assertEqual(out.read_bytes(), raw(last))
        self.assertEqual(receipt['events']['rows'][0]['event_sha256'], I.digest(raw(last)))
        self.assertEqual(p.read_bytes(), one+two)

    def test_extraction_preserves_whitespace_unicode_and_source_order(self):
        one = json.dumps(event(), ensure_ascii=False, indent=1).replace('\n', ' ').encode()+b'\n'
        e = event(2)
        e['details']['text'] = 'caf\u00e9 \u2665'
        two = raw(e)
        p = self.file(one+two)
        out = self.folder/'out.jsonl'
        I.extract(p, [2, 1], I.digest(one+two), out)
        self.assertEqual(out.read_bytes(), one+two)

    def test_extraction_rejects_changed_hash_missing_selection_and_overwrite(self):
        p = self.file([event()])
        out = self.folder/'out.jsonl'
        for ordinals, checksum in (([1], '0'*64), ([2], I.digest(p.read_bytes())), ([1, 1], I.digest(p.read_bytes()))):
            with self.assertRaises(I.timing.TimingError):
                I.extract(p, ordinals, checksum, out)
            self.assertFalse(out.exists())
        out.write_bytes(b'preserve prior output')
        with self.assertRaises(FileExistsError):
            I.extract(p, [1], I.digest(p.read_bytes()), out)
        self.assertEqual(out.read_bytes(), b'preserve prior output')
        with self.assertRaises(I.timing.TimingError):
            I.extract(p, [1], I.digest(p.read_bytes()), p)

    def test_diagnostic_extraction_can_retrieve_invalid_timing_semantics(self):
        e = window()
        e['details']['metrics']['update_total']['count'] = 99
        p = self.file([e])
        self.assertEqual(I.inspect([p])['status'], 'incomplete')
        out = self.folder/'diagnostic.jsonl'
        I.extract(p, [1], I.digest(p.read_bytes()), out)
        self.assertEqual(out.read_bytes(), raw(e))

    def test_incomplete_or_corrupt_tail_is_explicit_and_not_extracted(self):
        p = self.file(raw(event())+b'{"schema":1')
        r = I.inspect([p])
        self.assertEqual(r['status'], 'incomplete')
        self.assertEqual(r['events'], 1)
        self.assertIn('prefix_sha256', r['inputs']['rows'][0])
        out = self.folder/'out.jsonl'
        with self.assertRaises(I.ArchiveError):
            I.extract(p, [1], I.digest(p.read_bytes()), out)
        self.assertFalse(out.exists())

    def test_input_file_event_decoded_and_extract_caps(self):
        p = self.file([event(), event(2)])
        for option in ({'max_events': 1}, {'max_decoded_bytes': 1}, {'max_file_bytes': 1}):
            r = I.inspect([p], option)
            self.assertEqual(r['status'], 'incomplete')
            with self.assertRaises(I.timing.TimingError):
                I.extract(p, [1], I.digest(p.read_bytes()), self.folder/'out.jsonl', option)
        with self.assertRaises(I.timing.TimingError):
            I.extract(p, list(range(1, 18)), I.digest(p.read_bytes()), self.folder/'out.jsonl')
        with patch.object(I, 'MAX_EXTRACT_BYTES', 1):
            with self.assertRaises(I.timing.TimingError):
                I.extract(p, [1], I.digest(p.read_bytes()), self.folder/'out.jsonl')

    def test_duplicate_paths_directories_and_bad_limits_decline(self):
        p = self.file([event()])
        self.assertEqual(I.inspect([p, p])['events'], 0)
        self.assertEqual(I.inspect([self.folder])['events'], 0)
        with self.assertRaises(I.timing.TimingError):
            I.inspect([p], {'max_events': I.timing.HARD['max_events']+1})
        with self.assertRaises(I.timing.TimingError):
            I.render(I.inspect([p]), 100)

    def test_cli_summary_exclusive_output_and_extraction_receipt_only(self):
        p = self.file([event()])
        out = self.folder/'report.json'
        self.assertEqual(I.main(['inspect', str(p), '--output', str(out)]), 0)
        saved = out.read_bytes()
        with patch('sys.stderr', new=io.StringIO()):
            self.assertEqual(I.main(['inspect', str(p), '--output', str(out)]), 1)
        self.assertEqual(out.read_bytes(), saved)
        exact = self.folder/'exact.jsonl'
        with patch('sys.stdout', new=io.StringIO()) as stdout:
            self.assertEqual(I.main(['extract', str(p), '--input-sha256', I.digest(p.read_bytes()),
                                     '--ordinal', '1', '--output', str(exact)]), 0)
            receipt = json.loads(stdout.getvalue())
            self.assertNotIn('snapshot', stdout.getvalue())
            self.assertEqual(receipt['status'], 'exact_selected_events_written')
        self.assertEqual(exact.read_bytes(), p.read_bytes())

    def test_invalid_cli_output_budget_cannot_create_extraction_artifact(self):
        p = self.file([event()])
        out = self.folder/'out.jsonl'
        with patch('sys.stderr', new=io.StringIO()):
            result = I.main(['extract', str(p), '--input-sha256', I.digest(p.read_bytes()),
                             '--ordinal', '1', '--output', str(out), '--max-output-bytes', '1'])
        self.assertEqual(result, 1)
        self.assertFalse(out.exists())


if __name__ == '__main__':
    unittest.main()
