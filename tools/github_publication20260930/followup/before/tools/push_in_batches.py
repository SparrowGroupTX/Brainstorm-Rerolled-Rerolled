"""Publish a large committed update using small fast-forward pushes.

Keep existing commit history. Preload missing blobs through a temporary branch,
then publish the original branch and remove only the uploader's temporary refs.
No real upload occurs with the default 'plan' command.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
MAX_BLOB = 100 * 1024 * 1024
BATCH_BYTES = 128 * 1024 * 1024


def git(root: Path, *args: str, data: bytes | None = None) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], input=data)


def batches(blobs: list[tuple[str, int]], limit: int) -> list[list[tuple[str, int]]]:
    if limit < 1:
        raise ValueError("Batch limit must be positive")
    result, batch, size = [], [], 0
    for sha, count in sorted(blobs):
        if count > limit:
            raise ValueError(f"Blob {sha} does not fit the batch limit")
        if batch and size + count > limit:
            result.append(batch)
            batch, size = [], 0
        batch.append((sha, count))
        size += count
    if batch:
        result.append(batch)
    return result


def missing_blobs(root: Path, target: str, remote: str) -> list[tuple[str, int]]:
    objects = git(root, "rev-list", "--objects", target, "--not", "--remotes=" + remote)
    if not objects.strip():
        return []
    rows = git(root, "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)",
               data=b"\n".join(row.split(b" ", 1)[0] for row in objects.splitlines()) + b"\n")
    blobs = []
    for row in rows.splitlines():
        sha, kind, raw_size = row.decode("ascii").split()
        size = int(raw_size)
        if kind == "blob":
            if size > MAX_BLOB:
                raise ValueError(f"History still contains an ordinary blob above100MiB: {sha}")
            blobs.append((sha, size))
    return blobs


def payload_tree(root: Path, blobs: list[tuple[str, int]]) -> str:
    shards = defaultdict(list)
    for sha, _ in blobs:
        shards[sha[:2]].append(f"100644 blob {sha}\t{sha}\n")
    folders = []
    for prefix, rows in sorted(shards.items()):
        tree = git(root, "mktree", data="".join(sorted(rows)).encode("ascii")).decode().strip()
        folders.append(f"040000 tree {tree}\t{prefix}\n")
    payload = git(root, "mktree", data="".join(folders).encode("ascii")).decode().strip()
    return git(root, "mktree", data=f"040000 tree {payload}\tpayload\n".encode()).decode().strip()


def configuration(root: Path, remote: str | None, branch: str | None) -> tuple[str, str]:
    local = git(root, "symbolic-ref", "--short", "HEAD").decode().strip()
    remote = remote or git(root, "config", "--get", f"branch.{local}.remote").decode().strip()
    configured = git(root, "config", "--get", f"branch.{local}.merge").decode().strip()
    branch = branch or configured.removeprefix("refs/heads/")
    if not remote or remote == "." or remote.startswith("-"):
        raise ValueError("Select a named publication remote")
    git(root, "check-ref-format", "refs/heads/" + branch)
    return remote, branch


def publish(root: Path, remote: str, branch: str, limit: int = BATCH_BYTES) -> None:
    if git(root, "status", "--porcelain", "--untracked-files=normal").strip():
        raise ValueError("Commit the remaining changes first; this tool only uploads committed snapshots")
    target = git(root, "rev-parse", "HEAD").decode().strip()
    print(f"Publishing frozen commit {target} to {remote}/{branch}", flush=True)
    # Refresh advertised remote refs, without pruning or altering the user's branch.
    subprocess.run(["git", "-C", str(root), "fetch", "--no-tags", remote], check=True)
    base = git(root, "rev-parse", f"refs/remotes/{remote}/{branch}").decode().strip()
    git(root, "merge-base", "--is-ancestor", base, target)
    grouped = batches(missing_blobs(root, target, remote), limit)
    name = "codex/upload-" + target[:12] + "-" + uuid.uuid4().hex[:10]
    ref = "refs/heads/" + name
    previous, uploaded = base, []
    created = False
    try:
        for number, batch in enumerate(grouped, 1):
            uploaded.extend(batch)
            tree = payload_tree(root, uploaded)
            message = f"Preload upload data {number}/{len(grouped)} for {target}\n"
            commit = git(root, "commit-tree", tree, "-p", previous,
                         data=message.encode("utf-8")).decode().strip()
            old = previous if created else "0" * len(commit)
            git(root, "update-ref", ref, commit, old)
            created = True
            print(f"Batch {number}/{len(grouped)}: at most {sum(n for _, n in batch) / 1048576:.1f} MiB of new blob data", flush=True)
            subprocess.run(["git", "-C", str(root), "-c", "core.compression=9",
                            "-c", "pack.compression=9", "push", "--progress", remote,
                            commit + ":" + ref], check=True)
            previous = commit
        print("Publishing the original branch; commit history stays unchanged", flush=True)
        subprocess.run(["git", "-C", str(root), "-c", "core.compression=9",
                        "-c", "pack.compression=9", "push", "--progress", remote,
                        target + ":refs/heads/" + branch], check=True)
        advertised = git(root, "ls-remote", "--heads", remote, "refs/heads/" + branch)
        if advertised.split()[0].decode() != target:
            raise ValueError("Published branch verification failed; temporary upload refs retained")
    except BaseException:
        if created:
            print(f"Upload stopped; temporary ref retained for recovery: {remote}/{name}", file=sys.stderr)
        raise
    if created:
        cleanup = subprocess.run(["git", "-C", str(root), "push", remote, "--delete", name])
        if cleanup.returncode:
            print(f"Branch published, but temporary remote branch remains: {remote}/{name}", file=sys.stderr)
        else:
            git(root, "update-ref", "-d", ref, previous)
    print(f"Published {target}; no history rewrite or force push", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "push"), nargs="?", default="plan")
    parser.add_argument("--remote")
    parser.add_argument("--branch")
    parser.add_argument("--batch-mib", type=int, default=BATCH_BYTES // 1048576,
                        help="Maximum new uncompressed blob MiB per push (default:128)")
    args = parser.parse_args()
    try:
        if not 1 <= args.batch_mib <= 512:
            raise ValueError("Select a batch size between1 and512MiB")
        limit = args.batch_mib * 1048576
        remote, branch = configuration(ROOT, args.remote, args.branch)
        if args.command == "push":
            publish(ROOT, remote, branch, limit=limit)
        else:
            target = git(ROOT, "rev-parse", "HEAD").decode().strip()
            grouped = batches(missing_blobs(ROOT, target, remote), limit)
            print(f"Read-only plan for {remote}/{branch}: {len(grouped)} payload batches, then one final branch push.")
            print(f"Each batch has at most{args.batch_mib}MiB of new uncompressed blob data plus small Git metadata.")
            print("Plan uses current local remote refs; push refreshes them before uploading.")
            print("Commit all remaining changes, then run: python -B tools/push_in_batches.py push")
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Batched upload stopped: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
