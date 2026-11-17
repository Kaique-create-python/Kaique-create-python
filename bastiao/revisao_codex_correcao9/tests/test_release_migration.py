"""Reuse hash-matched stage 2 audio receipts through GET + grant, never Create."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tests"))
from release_fixture import TARGET, write_json
from tooling import assets_upload, release_builder as builder


class ExistingAssetAPI:
    def __init__(self):self.calls = []
    def request(self, method, url, headers, body=None, timeout=30):
        self.calls.append(method)
        if method == "GET":
            asset_id = url.rsplit("/", 1)[1]
            result = {"assetId": asset_id, "assetType": "Audio", "path": "assets/" + asset_id,
                      "creationContext": {"creator": {"userId": TARGET["userId"]}},
                      "moderationResult": {"moderationState": "Approved"}}
        elif method == "PATCH":
            asset_id = json.loads(body)["requests"][0]["assetId"]
            result = {"successAssetIds": [asset_id], "errors": []}
        else:
            raise AssertionError("A known legacy audio asset must not be uploaded again")
        return assets_upload.HttpResponse(200, {}, json.dumps(result).encode())


class AudioReceiptMigrationTests(unittest.TestCase):
    def test_old_hash_matched_upload_is_refreshed_and_granted_without_create(self):
        self.assertTrue(hasattr(builder, "seed_legacy_receipts"), "stage 2 audio receipts must be reused safely")
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        release, old_state = root / "release", root / "old_state"
        (release / "legado/audio").mkdir(parents=True)
        source = (ROOT / "legado/audio/voz_pt.ogg").read_bytes()
        (release / "legado/audio/voz_pt.ogg").write_bytes(source)
        digest = hashlib.sha256(source).hexdigest()
        entry = {"key": "voz_pt", "path": "audio/voz_pt.ogg", "assetType": "Audio", "contentType": "audio/ogg",
                 "sha256": digest, "displayName": "Bastião original"}
        manifest = release / "legado/ASSET_MANIFEST.json"
        write_json(manifest, {"schemaVersion": 1, "target": TARGET, "assets": [entry]})
        write_json(old_state / "midia-recibos.json", {"arquivos": {digest: {"arquivo": "voz_pt",
                    "operationId": "known_operation", "assetId": "12345", "estado": "Approved", "bytes": len(source)}},
                    "liberados": [TARGET["universeId"] + ":12345"]})
        builder.seed_legacy_receipts(manifest, old_state)
        local = release / "legado/.asset_upload_state" / (digest + ".json")
        self.assertEqual(json.loads(local.read_text())["status"], "pending_moderation")
        api = ExistingAssetAPI()
        result = assets_upload.upload_manifest(manifest, "not-a-real-key", transport=api)
        self.assertEqual(result["assets"][0]["assetId"], "12345")
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual(api.calls, ["GET", "PATCH"])
        before = local.read_bytes()
        builder.seed_legacy_receipts(manifest, old_state)
        self.assertEqual(before, local.read_bytes())


if __name__ == "__main__":unittest.main()
