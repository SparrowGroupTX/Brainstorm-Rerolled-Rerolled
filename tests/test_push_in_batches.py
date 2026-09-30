"""Manufactured temporary repositories and a local bare remote only."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import push_in_batches as P


class BatchedPushTests(unittest.TestCase):
    def test_bitmap_prevents_real_git_pack_resending_preloaded_blobs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            P.git(root, "init", "-q")
            P.git(root, "config", "user.name", "Manufactured pack check")
            P.git(root, "config", "user.email", "check@example.invalid")
            (root / "base.txt").write_bytes(b"base")
            P.git(root, "add", ".")
            P.git(root, "commit", "-qm", "base")
            base = P.git(root, "rev-parse", "HEAD").decode().strip()
            (root / "original.bin").write_bytes(os.urandom(256 * 1024))
            P.git(root, "add", ".")
            P.git(root, "commit", "-qm", "target")
            target = P.git(root, "rev-parse", "HEAD").decode().strip()
            blob = P.git(root, "rev-parse", "HEAD:original.bin").decode().strip()
            tree = P.payload_tree(root, [(blob, 256 * 1024)])
            payload = P.git(root, "commit-tree", tree, "-p", base, data=b"payload\n").decode().strip()
            P.git(root, "update-ref", "refs/heads/preload", payload)
            revisions = f"{target}\n^{payload}\n".encode()
            before = P.git(root, "pack-objects", "--revs", "--stdout", "--thin",
                           "--no-use-bitmap-index", data=revisions)
            P.git(root, "repack", "-a", "-b")
            after = P.git(root, "pack-objects", "--revs", "--stdout", "--thin",
                          "--use-bitmap-index", data=revisions)
            self.assertGreater(len(before), 256 * 1024)
            self.assertLess(len(after), 1024)
            self.assertTrue(list((root / ".git/objects/pack").glob("*.bitmap")))
            self.assertEqual(P.git(root, "rev-parse", "HEAD").decode().strip(), target)

    def test_dirty_repository_stops_before_fetch_or_ref_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", str(root)], check=True, capture_output=True)
            (root / "uncommitted.txt").write_bytes(b"preserve me")
            with self.assertRaisesRegex(ValueError, "Commit the remaining"):
                P.publish(root, "not-a-remote", "main")
            self.assertEqual((root / "uncommitted.txt").read_bytes(), b"preserve me")
            self.assertEqual(P.git(root, "for-each-ref").strip(), b"")

    def test_partition_caps_each_batch_and_rejects_unfittable_blob(self):
        result = P.batches([("b", 7), ("a", 5), ("c", 4)], 10)
        self.assertEqual(result, [[("a", 5)], [("b", 7)], [("c", 4)]])
        self.assertTrue(all(sum(size for _, size in group) <= 10 for group in result))
        with self.assertRaises(ValueError):
            P.batches([("large", 11)], 10)
        with self.assertRaises(ValueError):
            P.batches([], 0)

    def test_cli_batch_size_reaches_publisher_and_rejects_invalid_limits(self):
        with patch.object(P, "configuration", return_value=("origin", "main")), \
                patch.object(P, "publish") as publish, \
                patch.object(P.sys, "argv", ["push_in_batches.py", "push", "--batch-mib", "64"]):
            self.assertEqual(P.main(), 0)
            publish.assert_called_once_with(P.ROOT, "origin", "main", limit=64 * 1048576)
        with patch.object(P, "configuration") as configuration, \
                patch.object(P.sys, "argv", ["push_in_batches.py", "push", "--batch-mib", "513"]):
            self.assertEqual(P.main(), 1)
            configuration.assert_not_called()

    def test_actual_local_remote_multi_batch_preserves_history_and_cleans_refs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            remote, local = root / "remote.git", root / "local"
            subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
            subprocess.run(["git", "init", "-b", "main", str(local)], check=True, capture_output=True)
            P.git(local, "config", "user.name", "Manufactured test")
            P.git(local, "config", "user.email", "test@example.invalid")
            P.git(local, "config", "core.autocrlf", "false")
            P.git(local, "remote", "add", "origin", str(remote))
            (local / "base.txt").write_bytes(b"base")
            P.git(local, "add", "base.txt")
            P.git(local, "commit", "-m", "base")
            P.git(local, "push", "-u", "origin", "main")
            base = P.git(local, "rev-parse", "HEAD").strip()
            for i in range(4):
                (local / f"data{i}.bin").write_bytes(bytes([i]) * 800)
            P.git(local, "add", ".")
            P.git(local, "commit", "-m", "large manufactured update")
            target = P.git(local, "rev-parse", "HEAD").strip()
            P.publish(local, "origin", "main", limit=1000)
            self.assertEqual(P.git(local, "rev-parse", "HEAD").strip(), target)
            self.assertEqual(P.git(remote, "rev-parse", "refs/heads/main").strip(), target)
            self.assertEqual(P.git(local, "rev-parse", "HEAD^").strip(), base)
            self.assertEqual(P.git(remote, "for-each-ref", "refs/heads/codex/upload-").strip(), b"")
            self.assertEqual(P.git(local, "for-each-ref", "refs/heads/codex/upload-").strip(), b"")
            self.assertEqual(P.git(local, "status", "--porcelain").strip(), b"")

    def test_partial_transfer_resumes_only_missing_blobs_under_new_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            remote, local = root / "remote.git", root / "local"
            subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
            subprocess.run(["git", "init", "-b", "main", str(local)], check=True, capture_output=True)
            P.git(local, "config", "user.name", "Manufactured resume test")
            P.git(local, "config", "user.email", "test@example.invalid")
            P.git(local, "config", "core.autocrlf", "false")
            P.git(local, "remote", "add", "origin", str(remote))
            (local / "base.txt").write_bytes(b"base")
            P.git(local, "add", ".")
            P.git(local, "commit", "-m", "base")
            P.git(local, "push", "-u", "origin", "main")
            base = P.git(local, "rev-parse", "HEAD").strip()
            for i in range(5):
                (local / f"data{i}.bin").write_bytes(bytes([i]) * 800)
            P.git(local, "add", ".")
            P.git(local, "commit", "-m", "five payloads")
            target = P.git(local, "rev-parse", "HEAD").strip()
            P.git(local, "update-ref", "refs/remotes/origin/stale", target.decode())
            real_run, attempts = P.subprocess.run, []

            def fail_third(args, **kwargs):
                if "push" in args and any(":refs/heads/codex/upload-" in arg for arg in args):
                    attempts.append(args)
                    if len(attempts) == 3:
                        raise subprocess.CalledProcessError(1, args)
                return real_run(args, **kwargs)

            with patch.object(P.subprocess, "run", side_effect=fail_third):
                with self.assertRaises(subprocess.CalledProcessError):
                    P.publish(local, "origin", "main", limit=1000)
            self.assertEqual(P.git(remote, "rev-parse", "main").strip(), base)
            P.git(local, "fetch", "--no-auto-maintenance", "--no-tags", "origin")
            # Remote payloads rename blobs to their hash. rev-list negative
            # traversal alone incorrectly rediscovered all five target paths.
            self.assertEqual(len(P.missing_blobs(local, target.decode(), "origin",
                                              P.advertised_cached_heads(local, "origin"))), 3)
            P.publish(local, "origin", "main", limit=1000)
            self.assertEqual(P.git(remote, "rev-parse", "main").strip(), target)
            self.assertEqual(P.git(local, "rev-parse", "HEAD").strip(), target)
            self.assertEqual(P.git(local, "status", "--porcelain").strip(), b"")
            for i in range(5):
                self.assertEqual(P.git(remote, "show", f"main:data{i}.bin"), bytes([i]) * 800)

            # A failed next upload leaves the primary branch and user's local
            # history intact and retains only a recovery payload ref.
            (local / "next.bin").write_bytes(b"next data")
            P.git(local, "add", "next.bin")
            P.git(local, "commit", "-m", "next")
            next_target = P.git(local, "rev-parse", "HEAD").strip()
            real_run = P.subprocess.run

            def fail_payload(args, **kwargs):
                if "push" in args and any(":refs/heads/codex/upload-" in arg for arg in args):
                    raise subprocess.CalledProcessError(1, args)
                return real_run(args, **kwargs)

            with patch.object(P.subprocess, "run", side_effect=fail_payload):
                with self.assertRaises(subprocess.CalledProcessError):
                    P.publish(local, "origin", "main", limit=1000)
            self.assertEqual(P.git(local, "rev-parse", "HEAD").strip(), next_target)
            self.assertEqual(P.git(remote, "rev-parse", "main").strip(), target)
            self.assertIn(b"refs/heads/codex/upload-", P.git(local, "for-each-ref"))
            self.assertEqual(P.git(local, "status", "--porcelain").strip(), b"")


if __name__ == "__main__":
    unittest.main()
