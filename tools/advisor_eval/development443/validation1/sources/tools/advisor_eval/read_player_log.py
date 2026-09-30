"""Decode v1 JSONL or v2 archives to exact ordinary JSONL; never modify inputs."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import re
import sys
import zlib

MAX_EVENT = 1048577
MAX_FRAME = 3145728
HASH = re.compile(r'^[0-9a-f]{64}$')


class ArchiveError(ValueError):
    pass


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(value, message):
    if not value:
        raise ArchiveError(message)


def parsed(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'Duplicate JSON key')
            result[key] = value
        return result
    def number(text):
        value = float(text)
        require(math.isfinite(value), 'Nonfinite JSON number')
        return value
    def constant(text):
        raise ArchiveError('Nonfinite JSON token ' + text)
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_float=number, parse_constant=constant)
    except (ValueError, UnicodeError, RecursionError) as error:
        raise ArchiveError('Invalid bounded JSON: ' + str(error)) from error


def text(value):
    if isinstance(value, list):
        require(0 < len(value) <= 5 and all(isinstance(x, str) and len(x.encode('utf-8')) <= 262144 for x in value),
                'Invalid text chunks')
        value = ''.join(value)
    require(isinstance(value, str), 'Missing exact JSON text')
    raw = value.encode('utf-8')
    require(len(raw) <= MAX_EVENT, 'Text exceeds original-event bound')
    return raw


def records(stream):
    """Yield (original_jsonl_bytes, metadata), preserving any failure as an error."""
    last_snapshot = None
    previous = None
    last_sequence = None
    identity = None
    format_seen = None
    while True:
        head = stream.readline(MAX_EVENT + 1)
        if not head:
            return
        if head.startswith(b'BRJ2\t'):
            require(format_seen in (None, 2), 'Mixed archive formats in one file')
            format_seen = 2
            require(len(head) <= 256 and head.endswith(b'\n'), 'Invalid frame header length')
            fields = head[:-1].split(b'\t')
            require(len(fields) == 7, 'Invalid frame header fields')
            try:
                _, codec, stored_text, decoded_text, sequence_text, bodyhash, eventhash = fields
                stored, decoded, sequence = int(stored_text), int(decoded_text), int(sequence_text)
                require(stored_text == str(stored).encode() and decoded_text == str(decoded).encode() and
                        sequence_text == str(sequence).encode(), 'Noncanonical header number')
                require(0 < stored <= MAX_FRAME and 0 < decoded <= MAX_FRAME and sequence > 0, 'Frame length/sequence out of bounds')
                require(HASH.fullmatch(bodyhash.decode()) and HASH.fullmatch(eventhash.decode()), 'Invalid frame hashes')
            except (ValueError, UnicodeError) as error:
                raise ArchiveError('Malformed frame header') from error
            payload = stream.read(stored)
            require(len(payload) == stored and stream.read(1) == b'\n', 'Truncated archive tail')
            if codec == b'raw':
                raw = payload
            elif codec == b'zlib':
                try:
                    inflater = zlib.decompressobj()
                    raw = inflater.decompress(payload, MAX_FRAME + 1)
                    require(inflater.eof and not inflater.unconsumed_tail and not inflater.unused_data, 'Invalid or oversized zlib frame')
                except zlib.error as error:
                    raise ArchiveError('Invalid compressed frame') from error
            else:
                raise ArchiveError('Unsupported frame codec')
            require(len(raw) == decoded and sha(raw) == bodyhash.decode(), 'Decoded frame checksum/length mismatch')
            body = parsed(raw)
            require(isinstance(body, dict) and body.get('schema') == 2, 'Invalid frame schema')
            current_identity = body.get('session'), body.get('segment')
            require(isinstance(current_identity[0], str) and 0 < len(current_identity[0]) <= 128 and
                    type(current_identity[1]) is int and current_identity[1] > 0, 'Invalid segment identity')
            require(identity is None or identity == current_identity, 'Segment identity changed within file')
            identity = current_identity
            claimed_previous = body.get('previous_frame_sha256')
            require(claimed_previous == '-' or isinstance(claimed_previous, str) and HASH.fullmatch(claimed_previous), 'Invalid predecessor hash')
            require(previous is None or claimed_previous == previous, 'Frame chain mismatch')
            if 'event_json' in body:
                require(set(body) == {'schema', 'session', 'segment', 'previous_frame_sha256', 'event_json'}, 'Unexpected direct-event fields')
                original = text(body['event_json'])
            else:
                require(set(body) in ({'schema', 'session', 'segment', 'previous_frame_sha256', 'prefix', 'suffix', 'snapshot_id'},
                                     {'schema', 'session', 'segment', 'previous_frame_sha256', 'prefix', 'suffix', 'snapshot_id', 'snapshot_json'}),
                        'Unexpected snapshot-event fields')
                snapshot_id = body.get('snapshot_id')
                require(isinstance(snapshot_id, str) and HASH.fullmatch(snapshot_id), 'Invalid snapshot reference')
                if 'snapshot_json' in body:
                    snapshot = text(body['snapshot_json'])
                    require(sha(snapshot) == snapshot_id and isinstance(parsed(snapshot), (dict, list)), 'Invalid full snapshot payload')
                    last_snapshot = snapshot_id, snapshot
                require(last_snapshot is not None and last_snapshot[0] == snapshot_id, 'Missing same-segment prior snapshot')
                original = text(body['prefix']) + last_snapshot[1] + text(body['suffix'])
            require(len(original) <= MAX_EVENT and original.endswith(b'\n') and sha(original) == eventhash.decode(),
                    'Original event checksum/length mismatch')
            event = parsed(original)
            require(isinstance(event, dict) and event.get('schema') == 1 and type(event.get('sequence')) is int and
                    event['sequence'] == sequence, 'Original event identity differs from frame')
            require(last_sequence is None or sequence == last_sequence + 1, 'Event sequence discontinuity')
            last_sequence = sequence
            wirehash = sha(head + payload + b'\n')
            metadata = dict(format=2, session=identity[0], segment=identity[1], sequence=sequence,
                            previous_frame_sha256=claimed_previous, frame_sha256=wirehash)
            previous = wirehash
            yield original, metadata
        else:
            require(format_seen in (None, 1), 'Mixed archive formats in one file')
            format_seen = 1
            require(len(head) <= MAX_EVENT and head.endswith(b'\n'), 'Oversized or incomplete v1 JSONL record')
            event = parsed(head)
            require(isinstance(event, dict) and event.get('schema') == 1 and type(event.get('sequence')) is int and event['sequence'] > 0,
                    'Invalid v1 journal event')
            yield head, dict(format=1, sequence=event['sequence'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, help='New JSONL file; existing output is never overwritten')
    args = parser.parse_args()
    output = args.output.open('xb') if args.output else sys.stdout.buffer
    count = 0
    try:
        for path in args.inputs:
            with path.open('rb') as stream:
                for raw, _ in records(stream):
                    output.write(raw)
                    count += 1
        return 0
    except (OSError, ArchiveError) as error:
        print(f'Decoding stopped after {count} complete records; inputs and partial output preserved: {error}', file=sys.stderr)
        return 1
    finally:
        if args.output:
            output.close()


if __name__ == '__main__':
    raise SystemExit(main())
