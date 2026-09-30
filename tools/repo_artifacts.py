"""Lossless, bounded Git storage for large offline research artifacts.

Standard library only. Never runs a game, source probe, analyzer or training job.
Originals stay at their existing paths; restore recreates their exact bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile
from urllib.parse import quote
from urllib.request import urlopen
import zlib

ROOT = Path(__file__).resolve().parents[1]
STORE = "tools/repository_artifacts"
CATALOG = "catalog.json"
CHUNK_BYTES = 48 * 1024 * 1024
IO_BYTES = 1024 * 1024
GITHUB_BYTES = 100 * 1024 * 1024
BEGIN = "# BEGIN lossless research artifact originals (tools/repo_artifacts.py)"
END = "# END lossless research artifact originals"
HEX = re.compile(r"[0-9a-f]{64}\Z")


def git(root: Path, *args: str, stdin: bytes | None = None) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], input=stdin)


def safe_path(root: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    if (not relative or path.is_absolute() or "\\" in relative or ":" in relative
            or any(part in {".", "..", ".git"} for part in path.parts)
            or path.as_posix() != relative):
        raise ValueError(f"Unsafe artifact path: {relative!r}")
    result = root.joinpath(*path.parts)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Artifact path escapes root: {relative}")
    # Do not follow even an internal symlink when preserving/restoring bytes.
    if any(parent.is_symlink() or getattr(parent, "is_junction", lambda: False)()
           for parent in [result, *result.parents]
           if parent.is_relative_to(root)):
        raise ValueError(f"Artifact path contains a symlink: {relative}")
    return result


def digest(path: Path) -> tuple[str, int]:
    sha, size = hashlib.sha256(), 0
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(IO_BYTES), b""):
            sha.update(block)
            size += len(block)
    return sha.hexdigest(), size


def load(root: Path) -> dict:
    store = safe_path(root, STORE)
    path = safe_path(store, CATALOG)
    if not path.exists():
        return {"version": 1, "compression": "gzip", "chunk_bytes": CHUNK_BYTES,
                "files": {}}
    catalog = json.loads(path.read_text(encoding="utf-8"))
    if (catalog.get("version") != 1 or catalog.get("compression") != "gzip"
            or catalog.get("chunk_bytes") != CHUNK_BYTES
            or not isinstance(catalog.get("files"), dict)):
        raise ValueError("Unsupported artifact catalog")
    folded = set()
    for name, entry in catalog["files"].items():
        safe_path(root, name)
        if not name.startswith("tools/advisor_eval/") or name.casefold() in folded:
            raise ValueError(f"Invalid or duplicate original path: {name}")
        folded.add(name.casefold())
        if (not HEX.fullmatch(entry["sha256"]) or type(entry["bytes"]) is not int
                or entry["bytes"] < 0 or not entry["parts"]):
            raise ValueError(f"Invalid original metadata: {name}")
        for index, part in enumerate(entry["parts"]):
            wanted = f"objects/{entry['sha256']}/{index:05d}.gzpart"
            if (part["path"] != wanted or not HEX.fullmatch(part["sha256"])
                    or type(part["bytes"]) is not int
                    or not 0 < part["bytes"] <= CHUNK_BYTES):
                raise ValueError(f"Invalid chunk metadata: {name}")
            safe_path(store, part["path"])
    return catalog


def decoded_blocks(store: Path, entry: dict):
    """Validate both the compressed pieces and the bounded decoded stream."""
    decoder = zlib.decompressobj(wbits=31)
    original_sha, size = hashlib.sha256(), 0
    for part in entry["parts"]:
        path = safe_path(store, part["path"])
        piece_sha, piece_size = hashlib.sha256(), 0
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(IO_BYTES), b""):
                piece_sha.update(block)
                piece_size += len(block)
                if piece_size > part["bytes"]:
                    raise ValueError(f"Oversized chunk: {path}")
                pending = block
                while pending:
                    output = decoder.decompress(pending, IO_BYTES)
                    pending = decoder.unconsumed_tail
                    size += len(output)
                    if size > entry["bytes"] or decoder.unused_data:
                        raise ValueError("Archive has excess decoded bytes or trailing data")
                    original_sha.update(output)
                    if output:
                        yield output
        if (piece_size, piece_sha.hexdigest()) != (part["bytes"], part["sha256"]):
            raise ValueError(f"Chunk integrity failed: {path}")
    if not decoder.eof or (size, original_sha.hexdigest()) != (entry["bytes"], entry["sha256"]):
        raise ValueError("Original artifact integrity failed or gzip stream incomplete")


def verify_entry(store: Path, entry: dict) -> None:
    for _ in decoded_blocks(store, entry):
        pass


def atomic_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".artifact-", delete=False) as out:
        temporary = Path(out.name)
        out.write(text.encode("utf-8"))
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def ignore_originals(root: Path, catalog: dict) -> None:
    path = root / ".gitignore"
    old = path.read_text(encoding="utf-8") if path.exists() else ""
    if (BEGIN in old) != (END in old):
        raise ValueError("Incomplete managed .gitignore section")
    # Escape Git wildcards so this ignores only the archived physical paths.
    escape = lambda s: "".join("\\" + c if c in "\\*?[]#! " else c for c in s)
    section = BEGIN + "\n" + "\n".join("/" + escape(n) for n in sorted(catalog["files"]))
    section += "\n" + END
    if BEGIN in old:
        left, remainder = old.split(BEGIN, 1)
        _, right = remainder.split(END, 1)
        new = left + section + right
    else:
        new = old.rstrip() + "\n\n" + section + "\n"
    atomic_text(path, new)


def pack_file(root: Path, name: str, *, chunk_bytes: int = CHUNK_BYTES) -> dict:
    source = safe_path(root, name)
    original_sha, original_bytes = digest(source)
    store = safe_path(root, STORE)
    store.mkdir(parents=True, exist_ok=True)
    destination = safe_path(store, "objects/" + original_sha)
    if destination.exists():
        raise ValueError(f"Uncatalogued or incomplete object already exists: {destination}")
    staging = Path(tempfile.mkdtemp(dir=store, prefix=".tmp-"))
    parts, stream = [], None
    piece_sha, piece_size = hashlib.sha256(), 0

    def finish_piece():
        nonlocal stream, piece_sha, piece_size
        if stream is not None:
            stream.close()
            parts.append({"path": f"objects/{original_sha}/{len(parts):05d}.gzpart",
                          "sha256": piece_sha.hexdigest(), "bytes": piece_size})
            stream = None
            piece_sha, piece_size = hashlib.sha256(), 0

    def write(data: bytes):
        nonlocal stream, piece_size
        while data:
            if stream is None:
                stream = (staging / f"{len(parts):05d}.gzpart").open("xb")
            count = min(len(data), chunk_bytes - piece_size)
            stream.write(data[:count])
            piece_sha.update(data[:count])
            piece_size += count
            data = data[count:]
            if piece_size == chunk_bytes:
                finish_piece()

    try:
        compressor = zlib.compressobj(level=6, wbits=31)
        seen_sha, seen_bytes = hashlib.sha256(), 0
        with source.open("rb") as incoming:
            for block in iter(lambda: incoming.read(IO_BYTES), b""):
                seen_sha.update(block)
                seen_bytes += len(block)
                write(compressor.compress(block))
        write(compressor.flush())
        finish_piece()
        if (seen_sha.hexdigest(), seen_bytes) != (original_sha, original_bytes):
            raise ValueError(f"Source changed while archiving: {name}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Known, freshly created staging path and destination stay inside store.
        staging.rename(destination)
        entry = {"sha256": original_sha, "bytes": original_bytes, "parts": parts}
        verify_entry(store, entry)
        return entry
    finally:
        if stream is not None:
            stream.close()
        if staging.exists():
            # Only our own freshly created, flat temporary directory is removed.
            for child in staging.iterdir():
                child.unlink()
            staging.rmdir()


def lfs_paths(root: Path, names: list[str]) -> set[str]:
    if not names:
        return set()
    data = git(root, "check-attr", "-z", "filter", "--stdin",
               stdin=b"\0".join(n.encode("utf-8") for n in names) + b"\0").split(b"\0")
    return {data[i].decode("utf-8") for i in range(0, len(data) - 1, 3) if data[i + 2] == b"lfs"}


def candidates(root: Path) -> list[str]:
    data = git(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z")
    return sorted(set(n.decode("utf-8") for n in data.split(b"\0") if n))


def candidate_sizes(root: Path) -> list[tuple[str, int]]:
    # Git supplies normalized repository-relative names. This metadata-only scan
    # does not follow symlinks; full path checks happen on selected byte reads/writes.
    result = []
    for name in candidates(root):
        try:
            info = (root / name).lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISREG(info.st_mode):
            result.append((name, info.st_size))
    return result


def pack(root: Path, minimum: int) -> None:
    catalog = load(root)
    names = [n for n, size in candidate_sizes(root)
             if n.startswith("tools/advisor_eval/") and size >= minimum]
    tracked = set(n.decode("utf-8") for n in git(root, "ls-files", "-z").split(b"\0") if n)
    names = [n for n in names if n not in lfs_paths(root, names)]
    if set(names) & tracked:
        raise ValueError("An oversized original is already tracked; history needs separate handling")
    by_sha = {entry["sha256"]: entry for entry in catalog["files"].values()}
    for name in names:
        sha, size = digest(safe_path(root, name))
        if name in catalog["files"] and catalog["files"][name]["sha256"] != sha:
            raise ValueError(f"Archived original changed; preserve its existing receipt: {name}")
        if sha in by_sha:
            entry = by_sha[sha]
            verify_entry(safe_path(root, STORE), entry)
        else:
            entry = pack_file(root, name)
            by_sha[sha] = entry
        catalog["files"][name] = entry
        atomic_text(safe_path(safe_path(root, STORE), CATALOG),
                    json.dumps(catalog, indent=2, sort_keys=True) + "\n")
        ignore_originals(root, catalog)
        compressed = sum(p["bytes"] for p in entry["parts"])
        print(f"Archived {name}: {size / 1048576:.1f} -> {compressed / 1048576:.1f} MiB", flush=True)
    print(f"Catalog contains {len(catalog['files'])} originals. Original files were not changed.")


def selected(catalog: dict, names: list[str]) -> list[tuple[str, dict]]:
    unknown = set(names) - catalog["files"].keys()
    if unknown:
        raise ValueError("Unknown artifact paths: " + ", ".join(sorted(unknown)))
    return [(n, catalog["files"][n]) for n in sorted(names or catalog["files"])]


def restore(root: Path, names: list[str]) -> None:
    for name, entry in selected(load(root), names):
        target = safe_path(root, name)
        if target.exists():
            if digest(target) != (entry["sha256"], entry["bytes"]):
                raise ValueError(f"Refusing to overwrite different existing bytes: {name}")
            print(f"Already present and verified: {name}", flush=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".artifact-", delete=False) as out:
            temporary = Path(out.name)
            try:
                for block in decoded_blocks(safe_path(root, STORE), entry):
                    out.write(block)
            except BaseException:
                out.close()
                temporary.unlink(missing_ok=True)
                raise
        try:
            # Exclusive creation: a concurrent producer's original must survive.
            if os.name == "nt":
                # Windows rename fails if the destination exists, including on
                # FAT/exFAT, which do not support hard links.
                os.rename(temporary, target)
            else:
                os.link(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)
        print(f"Restored exact bytes: {name}", flush=True)


def fetch(root: Path, names: list[str]) -> None:
    """Download selected optional archive pieces; retain verified completed files."""
    store = safe_path(root, STORE)
    metadata = json.loads(safe_path(store, "downloads.json").read_text(encoding="utf-8"))
    repo, tag = metadata.get("repository", ""), metadata.get("tag", "")
    if (metadata.get("version") != 1 or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo)
            or not re.fullmatch(r"[A-Za-z0-9_.-]+", tag)):
        raise ValueError("Invalid optional archive download metadata")
    parts = {part["path"]: part for _, entry in selected(load(root), names)
             for part in entry["parts"]}
    for relative, part in sorted(parts.items()):
        target = safe_path(store, relative)
        if target.exists():
            if digest(target) != (part["sha256"], part["bytes"]):
                raise ValueError(f"Existing archive chunk has different bytes: {relative}")
            print(f"Already downloaded and verified: {relative}", flush=True)
            continue
        original_sha, filename = PurePosixPath(relative).parts[1:]
        asset = original_sha + "--" + filename
        url = f"https://github.com/{repo}/releases/download/{quote(tag)}/{quote(asset)}"
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".artifact-", delete=False) as out:
            temporary = Path(out.name)
            try:
                sha, count = hashlib.sha256(), 0
                with urlopen(url, timeout=60) as response:
                    for block in iter(lambda: response.read(IO_BYTES), b""):
                        count += len(block)
                        if count > part["bytes"]:
                            raise ValueError("Downloaded archive chunk exceeds its frozen size")
                        sha.update(block)
                        out.write(block)
                if (sha.hexdigest(), count) != (part["sha256"], part["bytes"]):
                    raise ValueError("Downloaded archive chunk failed integrity verification")
            except BaseException:
                out.close()
                temporary.unlink(missing_ok=True)
                raise
        try:
            safe_path(store, relative)
            if os.name == "nt":
                os.rename(temporary, target)
            else:
                os.link(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)
        print(f"Downloaded and verified: {relative}", flush=True)
    print(f"{len(parts)} optional archive pieces available; run restore to recreate originals.")


def check(root: Path, *, staged: bool = False) -> int:
    """Report ordinary Git blockers, accounting for existing LFS filters."""
    if staged:
        records = git(root, "ls-files", "--stage", "-z").split(b"\0")
        objects, names, hashes = [], [], []
        for record in records:
            if record:
                metadata, name = record.split(b"\t", 1)
                hashes.append(metadata.split()[1])
                names.append(name.decode("utf-8"))
        sizes = git(root, "cat-file", "--batch-check=%(objectsize)",
                    stdin=b"\n".join(hashes) + b"\n").splitlines() if hashes else []
        for name, raw_size in zip(names, sizes, strict=True):
            size = int(raw_size)
            if size > GITHUB_BYTES:
                objects.append((name, size))
        blockers = objects
    else:
        large = [(n, size) for n, size in candidate_sizes(root) if size > GITHUB_BYTES]
        lfs = lfs_paths(root, [n for n, _ in large])
        blockers = [(n, s) for n, s in large if n not in lfs]
        if lfs:
            print(f"{len(lfs)} large working files use existing Git LFS filters.")
    for name, size in blockers:
        print(f"BLOCKED {size / 1048576:.1f} MiB: {name}")
    print(f"{len(blockers)} ordinary Git files exceed 100 MiB.")
    return int(bool(blockers))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    packing = sub.add_parser("pack", help="Archive untracked offline evidence; keep original bytes")
    packing.add_argument("--minimum-mib", type=int, default=50)
    for command in ("restore", "verify", "fetch"):
        cmd = sub.add_parser(command)
        cmd.add_argument("paths", nargs="*", help="Exact catalog paths, or all if omitted")
        if command == "verify":
            cmd.add_argument("--originals", action="store_true", help="Also require matching local originals")
    sub.add_parser("list")
    checking = sub.add_parser("check", help="Check potential GitHub file-size blockers")
    checking.add_argument("--staged", action="store_true", help="Inspect actual index blobs, including LFS pointers")
    args = parser.parse_args()
    try:
        if args.command == "pack":
            if args.minimum_mib < 1:
                raise ValueError("Minimum must be at least 1 MiB")
            pack(ROOT, args.minimum_mib * 1048576)
        elif args.command == "restore":
            restore(ROOT, args.paths)
        elif args.command == "fetch":
            fetch(ROOT, args.paths)
        elif args.command == "verify":
            entries = selected(load(ROOT), args.paths)
            for name, entry in entries:
                verify_entry(safe_path(ROOT, STORE), entry)
                if args.originals and digest(safe_path(ROOT, name)) != (entry["sha256"], entry["bytes"]):
                    raise ValueError(f"Original integrity failed: {name}")
                print(f"Verified: {name}", flush=True)
            print(f"Verified {len(entries)} lossless artifacts.")
        elif args.command == "list":
            for name, entry in selected(load(ROOT), []):
                print(f"{entry['bytes'] / 1048576:8.1f} MiB  {name}")
        elif args.command == "check":
            return check(ROOT, staged=args.staged)
    except (OSError, ValueError, KeyError, zlib.error, subprocess.CalledProcessError) as error:
        print(f"Artifact operation stopped: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
