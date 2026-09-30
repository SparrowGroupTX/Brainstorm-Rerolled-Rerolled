"""Manufactured BRJ2 wire records; no actual journal, game or policy access."""
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zlib

from tools.advisor_eval import analyze_player_timing as timing
from tools.advisor_eval import inspect_player_log as inspection
from tools.advisor_eval.read_player_log import records


def sha(data):
    return hashlib.sha256(data).hexdigest()


def frame(sequence, segment, previous='-', session='invented405', compressed=False):
    event={'schema':1,'sequence':sequence,'kind':'state_after_actions',
           'monotonic_seconds':sequence,'context':{'snapshot':{'dollars':sequence}},'details':{}}
    original=(json.dumps(event,separators=(',',':'))+'\n').encode()
    wrapper={'schema':2,'session':session,'segment':segment,'previous_frame_sha256':previous,
             'event_json':original.decode()}
    body=json.dumps(wrapper,separators=(',',':')).encode()
    payload=zlib.compress(body) if compressed else body
    header=f"BRJ2\t{'zlib' if compressed else 'raw'}\t{len(payload)}\t{len(body)}\t{sequence}\t{sha(body)}\t{sha(original)}\n".encode()
    wire=header+payload+b'\n'
    return wire,sha(wire)


class SuppliedFragmentIntegrity(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.folder=Path(self.temp.name)

    def files(self,*data):
        paths=[]
        for i,raw in enumerate(data):
            path=self.folder/f'{i}.brj';path.write_bytes(raw);paths.append(path)
        return paths

    def both(self,paths):
        before=[p.read_bytes() for p in paths]
        reports=[]
        for analyze in (timing.analyze,inspection.inspect):
            reports.append(analyze(paths))
            self.assertEqual([p.read_bytes() for p in paths],before)
        return reports

    def test_adjacent_sequence_with_wrong_predecessor_rejected_before_credit(self):
        first,_=frame(11,3,'a'*64)
        second,_=frame(12,4,'b'*64,compressed=True)
        # Independent fragment decode is intentionally valid for both files.
        self.assertEqual(len(list(records(io.BytesIO(second)))),1)
        for report in self.both(self.files(first,second)):
            self.assertEqual(report['status'],'incomplete')
            self.assertEqual(report['events'],1)
            errors=report['errors'].get('rows') if isinstance(report['errors'],dict) else report['errors']
            self.assertIn('predecessor',errors[0]['reason'].lower())
            if 'largest_events' in report:
                self.assertEqual(report['largest_events']['row_count'],1)
                self.assertEqual(report['snapshot_repetition']['observations'],1)

    def test_contiguous_raw_and_compressed_segments_pass(self):
        first,h=frame(11,3,'a'*64)
        second,_=frame(12,4,h,compressed=True)
        for report in self.both(self.files(first,second)):
            self.assertEqual(report['status'],'parsed_supplied_records')
            self.assertEqual(report['events'],2)
            self.assertFalse(report['complete_session_claimed'])
            self.assertEqual(report['archive_integrity']['supplied_frame_links_validated'],1)
            self.assertFalse(report['archive_integrity']['outside_predecessors_verified'])

    def test_standalone_later_fragment_keeps_unknown_predecessor(self):
        one,h=frame(71,9,'b'*64)
        two,_=frame(72,9,h,compressed=True)
        for report in self.both(self.files(one+two)):
            self.assertEqual(report['status'],'parsed_supplied_records')
            self.assertEqual(report['events'],2)
            self.assertFalse(report['complete_session_claimed'])

    def test_cross_file_reused_or_regressed_segment_rejected(self):
        for next_segment in (3,2):
            first,h=frame(11,3,'a'*64)
            second,_=frame(12,next_segment,h)
            for report in self.both(self.files(first,second)):
                self.assertEqual(report['status'],'incomplete')
                self.assertEqual(report['events'],1)

    def test_empty_rotation_segment_gap_is_not_missing_event(self):
        first,h=frame(11,3,'a'*64)
        second,_=frame(12,6,h)
        for report in self.both(self.files(first,second)):
            self.assertEqual(report['status'],'parsed_supplied_records')
            self.assertEqual(report['events'],2)

    def test_interleaved_distinct_sessions_do_not_share_predecessors(self):
        first,h=frame(11,3,'a'*64)
        unrelated,_=frame(1,1,session='independent405')
        second,_=frame(12,4,h)
        for report in self.both(self.files(first,unrelated,second)):
            self.assertEqual(report['status'],'parsed_supplied_records')
            self.assertEqual(report['events'],3)
            self.assertEqual(report['archive_integrity']['supplied_frame_links_validated'],1)

    def test_cli_reports_incomplete_and_preserves_existing_report(self):
        first,_=frame(1,1)
        second,_=frame(2,2,'c'*64)
        paths=self.files(first,second);output=self.folder/'report.json'
        args=['inspect',*[str(p) for p in paths],'--output',str(output)]
        self.assertEqual(inspection.main(args),1)
        original=output.read_bytes()
        self.assertEqual(json.loads(original)['events'],1)
        with patch('sys.stderr',new=io.StringIO()):
            self.assertEqual(inspection.main(args),1)
        self.assertEqual(output.read_bytes(),original)


if __name__=='__main__':unittest.main()
