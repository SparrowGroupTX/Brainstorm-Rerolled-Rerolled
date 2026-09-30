"""Read a bounded prefix of the explicitly observed log, never saves or game state."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json
HERE=Path(__file__).resolve().parent
source=Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2\session-20260915T202738Z-1-000001.brj')
out=HERE/'captured_log'; out.mkdir(exist_ok=False)
before=source.stat(); limit=min(before.st_size,4*1024*1024)
with source.open('rb') as stream: raw=stream.read(limit)
after=source.stat()
assert len(raw)==limit
target=out/source.name
with target.open('xb') as stream: stream.write(raw)
record={'schema':1,'kind':'read_only_explicit_player_log_prefix','created_utc':datetime.now(timezone.utc).isoformat(),
 'source':str(source),'captured':str(target),'stored_bytes':len(raw),
 'sha256':hashlib.sha256(raw).hexdigest(),'source_size_before':before.st_size,'source_size_after':after.st_size,
 'source_mtime_ns_before':before.st_mtime_ns,'source_mtime_ns_after':after.st_mtime_ns,
 'stable_during_copy':before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns,
 'prefix_only':limit<after.st_size,'complete_frame_status':'pending_strict_read_only_decode',
 'source_modified':False,'game_control':False,'save_or_profile_access':False,'policy_evaluations':0}
with (out/'receipt.json').open('x',encoding='utf-8') as stream: json.dump(record,stream,indent=2);stream.write('\n')
print(json.dumps(record))
