"""Manufactured local archive and API responses; no real GitHub writes."""
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from tools import publish_research_assets as P
from tools import repo_artifacts as A


class ResearchAssetTests(unittest.TestCase):
    def fixture(self, root):
        name = "tools/advisor_eval/manufactured/events.json"
        original = root / name
        original.parent.mkdir(parents=True)
        original.write_bytes(b"preserved evidence" * 100)
        entry = A.pack_file(root, name)
        store = root / A.STORE
        (store / A.CATALOG).write_text(json.dumps({"version": 1, "compression": "gzip",
            "chunk_bytes": A.CHUNK_BYTES, "files": {name: entry}}))
        (store / "downloads.json").write_text(json.dumps({"version": 1,
            "repository": "owner/repo", "tag": "data-test"}))
        return entry

    def check_publication(self, bad_digest=False, resume=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry = self.fixture(root)
            target, calls, releases = "a" * 40, [], []
            if resume:
                releases.append({"id": 7, "tag_name": "data-test", "draft": True,
                    "body": A.digest(root / A.STORE / A.CATALOG)[0],
                    "html_url": "https://github.com/owner/repo/releases/tag/data-test"})

            def git(_root, *args, **kwargs):
                if args[:2] == ("remote", "get-url"):
                    return b"https://github.com/owner/repo.git\n"
                if args[0] == "status":
                    return b""
                if args[0] == "rev-parse":
                    return target.encode()
                if args[0] == "ls-remote":
                    return (target + "\trefs/heads/main\n").encode()
                raise AssertionError(args)

            def response(value):
                return io.BytesIO(json.dumps(value).encode())

            def request(req, **kwargs):
                calls.append((req.get_method(), req.full_url))
                if "/releases/tags/" in req.full_url:
                    raise HTTPError(req.full_url, 404, "manufactured missing release", {}, None)
                if "/releases?per_page=" in req.full_url:
                    return response(releases)
                if req.get_method() == "POST" and req.full_url.endswith("/releases"):
                    self.assertFalse(resume, "Do not recreate an existing draft")
                    value = json.loads(req.data)
                    value.update(id=7, html_url="https://github.com/owner/repo/releases/tag/data-test")
                    releases.append(value)
                    return response(value)
                if "/assets?per_page=" in req.full_url:
                    if resume:
                        part = entry["parts"][0]
                        return response([{"name": entry["sha256"] + "--00000.gzpart",
                            "state": "uploaded", "size": part["bytes"],
                            "digest": "sha256:" + part["sha256"]}])
                    return response([])
                if req.full_url.startswith("https://uploads.github.com/"):
                    self.assertFalse(resume, "Do not resend a verified completed asset")
                    data = req.data.read()
                    self.assertEqual(int(req.get_header("Content-length")), len(data))
                    digest = hashlib.sha256(data).hexdigest()
                    return response({"name": entry["sha256"] + "--00000.gzpart",
                        "state": "uploaded", "size": len(data),
                        "digest": "sha256:" + ("0" * 64 if bad_digest else digest)})
                if req.get_method() == "PATCH":
                    releases[0].update(json.loads(req.data))
                    return response(releases[0])
                raise AssertionError(req.full_url)

            with patch.object(A, "git", side_effect=git), \
                    patch.object(P.subprocess, "check_output", return_value=b"password=manufactured-token\n"), \
                    patch.object(P, "urlopen", side_effect=request):
                if bad_digest:
                    with self.assertRaisesRegex(ValueError, "integrity receipt"):
                        P.publish(root)
                    self.assertFalse(any(method == "PATCH" for method, _ in calls))
                    self.assertTrue(releases[0]["draft"])
                else:
                    result = P.publish(root)
                    self.assertTrue(result["published"])
                    self.assertEqual(result["archive_pieces"], 1)
                    self.assertFalse(releases[0]["draft"])
                    self.assertNotIn("manufactured-token", (root / ".git/optional-research-release-receipt.json").read_text())

    def test_publishes_only_after_uploaded_bytes_verify(self):
        self.check_publication()

    def test_bad_remote_digest_keeps_data_release_unpublished(self):
        self.check_publication(bad_digest=True)

    def test_resume_reuses_draft_and_assets_when_tag_lookup_returns404(self):
        self.check_publication(resume=True)

    def test_ambiguous_draft_lookup_refuses_to_create_another_release(self):
        def api(path):
            if "/tags/" in path:
                raise HTTPError(path, 404, "no published tag", {}, None)
            return [{"tag_name": "same-tag", "id": 1}, {"tag_name": "same-tag", "id": 2}]
        with self.assertRaisesRegex(ValueError, "Multiple releases"):
            P.find_release(api, "/repos/owner/repo", "same-tag")


if __name__ == "__main__":
    unittest.main()
