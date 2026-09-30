"""Publish optional lossless archive pieces as a GitHub data release.

Default command is read-only. Credentials stay in memory and are never recorded.
Uploads preserve existing assets and verify GitHub's SHA-256 receipt.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import subprocess
import threading
import time
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

from tools import repo_artifacts as A

ROOT = A.ROOT
API = "https://api.github.com"


def pieces(root: Path) -> dict:
    result = {}
    for entry in A.load(root)["files"].values():
        for part in entry["parts"]:
            name = entry["sha256"] + "--" + Path(part["path"]).name
            if name in result and result[name] != part:
                raise ValueError("Conflicting archive asset metadata")
            result[name] = part
    return result


def publish(root: Path) -> dict:
    metadata = json.loads(A.safe_path(root, A.STORE + "/downloads.json").read_text())
    repo, tag = metadata["repository"], metadata["tag"]
    # Limit credential use to the repository configured in this publication.
    remote = A.git(root, "remote", "get-url", "origin").decode().strip()
    if remote.removesuffix(".git") != "https://github.com/" + repo:
        raise ValueError("Archive repository does not match the configured HTTPS origin")
    if A.git(root, "status", "--porcelain", "--untracked-files=normal").strip():
        raise ValueError("Commit the archive tools and metadata before publication")
    target = A.git(root, "rev-parse", "HEAD").decode().strip()
    heads = A.git(root, "ls-remote", "--heads", "origin").splitlines()
    if target.encode() not in {row.split()[0] for row in heads}:
        raise ValueError("Publish the lightweight code commit before its optional data release")
    raw = subprocess.check_output(["git", "-C", str(root), "credential", "fill"],
                                  input=b"protocol=https\nhost=github.com\n\n")
    credentials = dict(row.split(b"=", 1) for row in raw.splitlines() if b"=" in row)
    secret = credentials.get(b"password")
    if not secret:
        raise ValueError("Git credential manager has no authenticated GitHub credential")
    headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2026-03-10",
               "User-Agent": "Brainstorm-optional-research-assets"}

    def api(path, data=None, method=None):
        body = json.dumps(data).encode() if data is not None else None
        request = Request(API + path, data=body, headers=headers, method=method)
        request.add_unredirected_header("Authorization", "Bearer " + secret.decode())
        if body is not None:
            request.add_header("Content-Type", "application/json")
        with urlopen(request, timeout=60) as response:
            return json.load(response)

    catalog_sha, _ = A.digest(A.safe_path(root, A.STORE + "/catalog.json"))
    body = ("Optional historical research captures and analysis. Not required to install the mod.\n\n"
            f"Catalog SHA-256: `{catalog_sha}`\n\n"
            "From a clone: `python -B tools/repo_artifacts.py fetch`, then "
            "`python -B tools/repo_artifacts.py restore`. Each piece is at most48MiB; "
            "the downloader verifies exact sizes and SHA-256 and resumes completed pieces.\n\n"
            "This data release does not qualify simulator fidelity or authorize game/training execution.")
    base = "/repos/" + repo
    try:
        release = api(base + "/releases/tags/" + quote(tag))
    except HTTPError as error:
        if error.code != 404:
            raise
        release = api(base + "/releases", {
            "tag_name": tag, "target_commitish": target,
            "name": "Optional historical research data — 2026-09-30", "body": body,
            "draft": True, "prerelease": True, "make_latest": "false"})
    if catalog_sha not in (release.get("body") or ""):
        raise ValueError("Existing data release belongs to a different frozen catalog")
    payloads = pieces(root)
    existing = {}
    for page in range(1, 20):
        rows = api(base + f"/releases/{release['id']}/assets?per_page=100&page={page}")
        existing.update({row["name"]: row for row in rows})
        if len(rows) < 100:
            break
    lock, next_start = threading.Lock(), [0.0]

    def verify(asset, part):
        if (asset.get("state") != "uploaded" or asset.get("size") != part["bytes"]
                or asset.get("digest") != "sha256:" + part["sha256"]):
            raise ValueError("GitHub asset integrity receipt disagrees: " + asset["name"])

    def upload(name, part):
        if name in existing:
            verify(existing[name], part)
            return existing[name]
        path = A.safe_path(root, A.STORE + "/" + part["path"])
        if A.digest(path) != (part["sha256"], part["bytes"]):
            raise ValueError("Local archive piece changed: " + name)
        with lock:
            delay = max(0.0, next_start[0] - time.monotonic())
            if delay:
                time.sleep(delay)
            next_start[0] = time.monotonic() + 1.0
        url = f"https://uploads.github.com/repos/{repo}/releases/{release['id']}/assets?name={quote(name)}"
        with path.open("rb") as stream:
            request = Request(url, data=stream, headers={**headers,
                              "Content-Type": "application/octet-stream",
                              "Content-Length": str(part["bytes"])}, method="POST")
            request.add_unredirected_header("Authorization", "Bearer " + secret.decode())
            with urlopen(request, timeout=60) as response:
                asset = json.load(response)
        verify(asset, part)
        return asset

    assets, byte_count = [], 0
    print(f"Data release {tag}: {len(payloads)} optional pieces, four upload connections", flush=True)
    with ThreadPoolExecutor(max_workers=4) as workers:
        tasks = {workers.submit(upload, name, part): part for name, part in payloads.items()}
        try:
            for task in as_completed(tasks):
                asset = task.result()
                assets.append({"name": asset["name"], "bytes": asset["size"], "digest": asset["digest"]})
                byte_count += asset["size"]
                print(f"Verified {len(assets)}/{len(payloads)} assets; {byte_count / 1048576:.1f}MiB available", flush=True)
        except BaseException:
            for task in tasks:
                task.cancel()
            print("Upload stopped; verified assets and the draft release remain for recovery", flush=True)
            raise
    release = api(base + f"/releases/{release['id']}", {"draft": False, "make_latest": "false"}, "PATCH")
    receipt = {"repository": repo, "tag": tag, "release_url": release["html_url"],
               "catalog_sha256": catalog_sha, "code_commit": target,
               "assets": sorted(assets, key=lambda a: a["name"]), "verified_asset_bytes": byte_count,
               "published": not release["draft"], "archive_pieces": len(assets)}
    A.atomic_text(root / ".git/optional-research-release-receipt.json", json.dumps(receipt, indent=2) + "\n")
    print("Published optional data: " + release["html_url"], flush=True)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "push"), nargs="?", default="plan")
    args = parser.parse_args()
    if args.command == "plan":
        payloads = pieces(ROOT)
        print(f"Read-only: {len(payloads)} optional pieces, {sum(p['bytes'] for p in payloads.values()) / 1048576:.1f}MiB")
        return 0
    try:
        publish(ROOT)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("Optional data publication stopped: " + str(error))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
