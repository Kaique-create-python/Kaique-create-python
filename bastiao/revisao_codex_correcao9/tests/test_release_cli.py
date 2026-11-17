"""Local commands stay offline; paid/network commands enforce preparation first."""
from __future__ import annotations

import contextlib
import importlib.util
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
from release_fixture import make_release, write_json
from tooling import release_builder as builder

ENTRY = ROOT / "instalar.py"
if ENTRY.is_file():
    spec = importlib.util.spec_from_file_location("release_entrypoint", ENTRY)
    entrypoint = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(entrypoint)
else:
    entrypoint = None


class ReleaseCommandTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(entrypoint, "portable Termux release entrypoint is missing")
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / "release"
        self.root.mkdir()
        make_release(self.root)
        self.home = Path(temp.name) / "home"
        self.home.mkdir()

    def test_verificar_needs_no_key_network_or_state_writes(self):
        (self.root / "audio/AUDIO_MANIFEST.json").unlink()
        before = sorted((p.relative_to(self.root).as_posix(), p.read_bytes()) for p in self.root.rglob("*") if p.is_file())
        output = io.StringIO()
        with mock.patch("pathlib.Path.home", return_value=self.home), mock.patch("getpass.getpass", side_effect=AssertionError("Key prompt forbidden")), mock.patch("socket.socket", side_effect=AssertionError("Network forbidden")), contextlib.redirect_stdout(output):
            entrypoint.main(["verificar"], root=self.root)
        report = json.loads(output.getvalue())
        self.assertEqual(report["stage"], 3)
        self.assertFalse(report["readyToBuild"])
        self.assertTrue(report["pending"])
        after = sorted((p.relative_to(self.root).as_posix(), p.read_bytes()) for p in self.root.rglob("*") if p.is_file())
        self.assertEqual(before, after)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_cloud_test_is_blocked_before_key_prompt_when_asset_is_pending(self):
        path = self.root / "audio/UPLOADED_ASSETS.json"
        data = json.loads(path.read_text())
        data["assets"][0]["status"] = "pending_moderation"
        write_json(path, data)
        with mock.patch("getpass.getpass", side_effect=AssertionError("Must not prompt before readiness")):
            with self.assertRaises(builder.BuildError):entrypoint.main(["testar-nuvem"], root=self.root)
        self.assertFalse((self.root / "payload/manifest.json").exists())

    def test_assets_validate_real_files_before_requesting_a_key(self):
        # Fixture bytes have matching hashes but are intentionally not valid OGGs.
        with mock.patch("getpass.getpass", side_effect=AssertionError("Must validate content before key")):
            with self.assertRaises(ValueError):entrypoint.main(["assets"], root=self.root)
        self.assertFalse((self.root / "legado/.asset_upload_state").exists())

    def test_frozen_resume_payload_is_integrity_checked_and_independent_of_changed_plan(self):
        self.assertTrue(hasattr(builder, "persist_payload"), "resume requires an immutable tested payload cache")
        files, _ = builder.build_files(self.root)
        builder.persist_payload(self.root, files)
        (self.root / "audio/AUDIO_MANIFEST.json").unlink()
        self.assertEqual(builder.load_payload(self.root), files)
        (self.root / "payload/sources.json").write_text("foreign edit")
        from instalador.codec import Failure
        with self.assertRaises(Failure):builder.load_payload(self.root)


if __name__ == "__main__":
    unittest.main()
