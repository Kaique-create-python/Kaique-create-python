"""Run the reviewed publication state machine with an in-memory API boundary."""
from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tests"))
from release_fixture import make_release
from tooling import release_builder as builder
from instalador import cli
from instalador.codec import Failure
from instalador.runtime import Runtime, TARGET, read


class PlaceAPI:
    """Only the transport is simulated; files, receipts and Runtime stay real."""
    def __init__(self, raw):
        self.key = "not-a-real-key"
        self.latest = 1
        self.versions = {1: {"raw": raw, "published": True}}
        self.posts = []
        self.lose_response = None
        self.pass_task = True

    def validate_destination(self):pass
    def team_empty(self):pass
    def history(self):
        return self.latest, [{"version": number, "isPublished": item["published"]} for number, item in self.versions.items()]
    def download(self, version, path):
        raw = self.versions[version]["raw"]
        path.write_bytes(raw)
        return raw
    def task(self, version, source):
        return {"package": "BASTIAO-ETAPA-3", "passed": self.pass_task,
                "errors": [] if self.pass_task else ["native scenario failed"]}
    def request(self, path, *, raw, mime, method):
        if method != "POST" or "/versions?versionType=" not in path:
            raise AssertionError("Unapproved transport operation")
        mode = path.rsplit("=", 1)[1]
        self.posts.append(mode)
        if mode == "Saved":self.latest += 1
        self.versions[self.latest] = {"raw": raw, "published": mode == "Published"}
        if self.lose_response == mode:
            raise Failure("simulated response loss")
        return {"versionNumber": self.latest}


class ReviewedProtocolTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        def patch(raw):
            if raw == b"original place":return b"prepared place", True
            if raw == b"prepared place":return raw, False
            raise Failure("foreign place")
        self.runtime = Runtime(self.root / "state", 3, "a" * 64, patch, lambda version, verify: ["native tester"])
        self.api = PlaceAPI(b"original place")

    def test_failed_native_report_blocks_publication_and_keeps_saved_unpublished(self):
        self.api.pass_task = False
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(Failure):self.runtime.test(self.api)
        self.assertEqual(self.api.posts, ["Saved"])
        self.assertFalse(self.api.versions[2]["published"])
        self.assertTrue(self.api.versions[1]["published"])
        with self.assertRaises(Failure):self.runtime.publish(self.api)
        self.assertEqual(self.api.posts, ["Saved"])

    def test_publication_requires_written_confirmation_after_passing_saved_test(self):
        with contextlib.redirect_stdout(io.StringIO()):self.runtime.test(self.api)
        with mock.patch("builtins.input", return_value="wrong"):
            with self.assertRaises(Failure):self.runtime.publish(self.api)
        self.assertEqual(self.api.posts, ["Saved"])
        with mock.patch("builtins.input", return_value="PUBLICAR ETAPA3"), contextlib.redirect_stdout(io.StringIO()):
            self.runtime.publish(self.api)
        self.assertEqual(self.api.posts, ["Saved", "Published"])
        self.assertEqual(read(self.runtime.state / "last-published.json")["status"], "VERIFIED")
        self.assertFalse(self.runtime.active.exists())

    def test_response_loss_preserves_receipt_and_resume_never_repeats_post(self):
        with contextlib.redirect_stdout(io.StringIO()):self.runtime.test(self.api)
        self.api.lose_response = "Published"
        with mock.patch("builtins.input", return_value="PUBLICAR ETAPA3"), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(Failure):self.runtime.publish(self.api)
        self.assertEqual(read(self.runtime.active)["status"], "UNCERTAIN")
        with self.assertRaises(Failure):self.runtime.publish(self.api)
        self.assertEqual(self.api.posts, ["Saved", "Published"])
        with contextlib.redirect_stdout(io.StringIO()):self.runtime.resume(self.api)
        self.assertEqual(self.api.posts, ["Saved", "Published"])
        self.assertFalse(self.runtime.active.exists())

    def test_changed_latest_place_after_test_blocks_publish(self):
        with contextlib.redirect_stdout(io.StringIO()):self.runtime.test(self.api)
        self.api.latest = 3
        self.api.versions[3] = {"raw": b"foreign place", "published": False}
        with self.assertRaises(Failure):self.runtime.publish(self.api)
        self.assertEqual(self.api.posts, ["Saved"])


class BoundAssetCLIIntegration(unittest.TestCase):
    def test_saved_test_uses_bound_ids_without_optional_upload_path(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        release = root / "release"
        release.mkdir()
        make_release(release)
        files, _ = builder.build_files(release)
        # The external asset uploader must not run after the release was bound.
        with mock.patch("pathlib.Path.home", return_value=root), mock.patch.object(cli, "hidden_key", return_value="unused"), mock.patch.object(cli.sons.Midia, "preparar", side_effect=AssertionError("approved assets re-entered optional uploader")), mock.patch.object(cli.transport, "Cloud", side_effect=lambda key, target: api), contextlib.redirect_stdout(io.StringIO()):
            from instalador.package import Package
            package = Package(files)
            api = PlaceAPI(b"original place")
            # Full source patching is covered separately; retain the real Runtime here.
            def patch(raw):
                return (b"prepared place", raw != b"prepared place")
            with mock.patch.object(Package, "patch", side_effect=patch):
                cli.main(files, ["testar-nuvem"])
        proof = read(root / ".bastiao_instalador/state-etapa3/test.json")
        self.assertEqual(proof["base"], 2)
        self.assertEqual(proof["reports"][0]["passed"], True)
        self.assertEqual(api.posts, ["Saved"])


if __name__ == "__main__":
    unittest.main()
