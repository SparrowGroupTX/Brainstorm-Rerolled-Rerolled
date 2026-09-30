"""Temporary manufactured byte files only; no game, capture or source worker."""
from copy import deepcopy
import hashlib
import io
import json
from pathlib import Path
import random
import tempfile
import unittest
from unittest.mock import patch

from tools import repo_artifacts as A


class ArtifactTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.name = "tools/advisor_eval/manufactured/events.sqlite3"
        self.original = A.safe_path(self.root, self.name)
        self.original.parent.mkdir(parents=True)
        self.store = self.root / A.STORE

    def archive(self, data, chunk=8192):
        self.original.write_bytes(data)
        entry = A.pack_file(self.root, self.name, chunk_bytes=chunk)
        catalog = {"version": 1, "compression": "gzip", "chunk_bytes": A.CHUNK_BYTES,
                   "files": {self.name: entry}}
        (self.store / A.CATALOG).write_text(json.dumps(catalog), encoding="utf-8")
        return entry

    def test_split_incompressible_roundtrip_restores_exact_bytes(self):
        data = random.Random(25).randbytes(512 * 1024)
        entry = self.archive(data)
        self.assertGreater(len(entry["parts"]), 1)
        self.assertTrue(all(part["bytes"] <= 8192 for part in entry["parts"]))
        self.assertEqual(self.original.read_bytes(), data)
        self.original.unlink()
        A.restore(self.root, [])
        self.assertEqual(self.original.read_bytes(), data)
        self.assertEqual(A.digest(self.original), (hashlib.sha256(data).hexdigest(), len(data)))

    def test_high_compression_and_empty_files_roundtrip(self):
        for data in (b"", b"public data\x00" * 500000):
            with self.subTest(length=len(data)):
                entry = self.archive(data)
                self.assertEqual(b"".join(A.decoded_blocks(self.store, entry)), data)

    def test_optional_fetch_resumes_completed_pieces_and_restores_exact_bytes(self):
        data = random.Random(46).randbytes(30000)
        entry = self.archive(data)
        (self.store / "downloads.json").write_text(json.dumps({
            "version": 1, "repository": "owner/repo", "tag": "research-data"}))
        payloads = {}
        for part in entry["parts"]:
            path = self.store / part["path"]
            asset = entry["sha256"] + "--" + path.name
            payloads[asset] = path.read_bytes()
            path.unlink()
        calls = []

        def download(url, **kwargs):
            calls.append(url)
            if len(calls) == 2:
                raise OSError("manufactured transfer interruption")
            return io.BytesIO(payloads[url.rsplit("/", 1)[-1]])

        with patch.object(A, "urlopen", side_effect=download):
            with self.assertRaises(OSError):
                A.fetch(self.root, [])
        self.assertTrue((self.store / entry["parts"][0]["path"]).exists())
        self.assertFalse(list(self.store.rglob(".artifact-*")))
        with patch.object(A, "urlopen", side_effect=lambda url, **kwargs:
                          io.BytesIO(payloads[url.rsplit("/", 1)[-1]])) as resumed:
            A.fetch(self.root, [])
            self.assertEqual(resumed.call_count, len(entry["parts"]) - 1)
        self.original.unlink()
        A.restore(self.root, [])
        self.assertEqual(self.original.read_bytes(), data)

    def test_optional_fetch_rejects_bad_download_before_publishing_chunk(self):
        entry = self.archive(b"small optional data")
        (self.store / "downloads.json").write_text(json.dumps({
            "version": 1, "repository": "owner/repo", "tag": "research-data"}))
        target = self.store / entry["parts"][0]["path"]
        target.unlink()
        for bad in (b"corrupt", b"x" * (entry["parts"][0]["bytes"] + 1)):
            with self.subTest(length=len(bad)), patch.object(A, "urlopen", return_value=io.BytesIO(bad)):
                with self.assertRaises(ValueError):
                    A.fetch(self.root, [])
                self.assertFalse(target.exists())
                self.assertFalse(list(self.store.rglob(".artifact-*")))
        (self.store / "downloads.json").write_text(json.dumps({
            "version": 1, "repository": "owner/repo/../escape", "tag": "research-data"}))
        with patch.object(A, "urlopen") as network:
            with self.assertRaises(ValueError):
                A.fetch(self.root, [])
            network.assert_not_called()

    def test_restore_skips_identical_original_and_refuses_overwrite(self):
        self.archive(b"original")
        A.restore(self.root, [self.name])
        self.original.write_bytes(b"user modified file")
        with self.assertRaisesRegex(ValueError, "Refusing to overwrite"):
            A.restore(self.root, [])
        self.assertEqual(self.original.read_bytes(), b"user modified file")

    def test_corrupted_piece_never_publishes_partial_original(self):
        entry = self.archive(b"repeated database content" * 10000)
        self.original.unlink()
        part = self.store / entry["parts"][0]["path"]
        payload = bytearray(part.read_bytes())
        payload[-1] ^= 1
        part.write_bytes(payload)
        with self.assertRaises((ValueError, A.zlib.error)):
            A.restore(self.root, [])
        self.assertFalse(self.original.exists())
        self.assertFalse(list(self.original.parent.glob(".artifact-*")))

    def test_missing_piece_and_wrong_original_hash_fail(self):
        entry = self.archive(b"dataset")
        wrong = deepcopy(entry)
        wrong["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "Original artifact integrity"):
            A.verify_entry(self.store, wrong)
        (self.store / entry["parts"][0]["path"]).unlink()
        with self.assertRaises(FileNotFoundError):
            A.verify_entry(self.store, entry)

    def test_size_cap_truncation_and_trailing_data_rejected(self):
        entry = self.archive(b"a" * 100000)
        short = deepcopy(entry)
        short["bytes"] = 100
        with self.assertRaisesRegex(ValueError, "excess decoded"):
            A.verify_entry(self.store, short)
        part = self.store / entry["parts"][0]["path"]
        raw = part.read_bytes()
        for invalid in (raw[:-2], raw + b"trailing"):
            with self.subTest(length=len(invalid)):
                part.write_bytes(invalid)
                changed = deepcopy(entry)
                changed["parts"][0].update(bytes=len(invalid), sha256=hashlib.sha256(invalid).hexdigest())
                with self.assertRaises(ValueError):
                    A.verify_entry(self.store, changed)

    def test_unsafe_paths_and_duplicate_case_catalog_rejected(self):
        for name in ("../outside", "/absolute", "C:/save", "//server/share", "tools/../secret",
                     "tools\\escape", ".git/config", "tools/file:stream", "tools//doubled"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                A.safe_path(self.root, name)
        entry = self.archive(b"safe")
        catalog = A.load(self.root)
        catalog["files"][self.name.replace("events.sqlite3", "EVENTS.SQLITE3")] = entry
        (self.store / A.CATALOG).write_text(json.dumps(catalog), encoding="utf-8")
        with self.assertRaises(ValueError):
            A.load(self.root)

    def test_symlinked_objects_or_catalog_are_refused_before_writing(self):
        self.original.write_bytes(b"manufactured evidence")
        self.store.mkdir(parents=True)
        outside = self.root / "outside-objects"
        outside.mkdir()
        linked = self.store / "objects"
        try:
            linked.symlink_to(outside, target_is_directory=True)
        except OSError as error:
            if A.os.name != "nt":
                self.skipTest(f"Symlinks unavailable in this test environment: {error}")
            import _winapi
            _winapi.CreateJunction(str(outside), str(linked))
        with self.assertRaises(ValueError):
            A.pack_file(self.root, self.name)
        self.assertFalse(list(outside.iterdir()))
        if getattr(linked, "is_junction", lambda: False)():
            linked.rmdir()
            # Catalog symlinks cannot be made without Windows symlink privilege,
            # but the real directory-junction refusal above was exercised.
            return
        linked.unlink()
        target = outside / "catalog.json"
        target.write_text("{}", encoding="utf-8")
        (self.store / A.CATALOG).symlink_to(target)
        with self.assertRaises(ValueError):
            A.load(self.root)

    def test_unknown_selection_and_exact_ignores_preserve_existing_rules(self):
        entry = self.archive(b"safe")
        catalog = A.load(self.root)
        with self.assertRaisesRegex(ValueError, "Unknown artifact"):
            A.selected(catalog, ["tools/advisor_eval/missing"])
        ignore = self.root / ".gitignore"
        ignore.write_text("# user's rules\n/preserve-me/\n", encoding="utf-8")
        A.ignore_originals(self.root, catalog)
        once = ignore.read_text()
        A.ignore_originals(self.root, catalog)
        self.assertEqual(ignore.read_text(), once)
        self.assertIn("# user's rules\n/preserve-me/\n", once)
        self.assertIn("/" + self.name + "\n", once)
        self.assertNotIn("*.sqlite3", once)


if __name__ == "__main__":
    unittest.main()
