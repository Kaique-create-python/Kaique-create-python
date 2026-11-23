"""Uma chave recusada (401/403) não pode marcar a mídia como falha definitiva."""
import hashlib
import io
import json
import shutil
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from media_tools import catalog, upload

ROOT = Path(__file__).resolve().parents[1]


class Refuse:
    def __init__(self, status=401):
        self.status, self.calls = status, []

    def request(self, method, url, headers, body=None, timeout=30):
        assert headers["x-api-key"] == "chave-teste"
        self.calls.append((method, url))
        body = json.dumps({"code": "UNAUTHENTICATED", "message": "Invalid API Key"}).encode()
        return upload.HttpResponse(self.status, {}, body)


class AuthTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)
        source = ROOT / "media/art/poca_1.png"
        (self.dir / "art").mkdir()
        shutil.copy(source, self.dir / "art/poca_1.png")
        self.sha = hashlib.sha256(source.read_bytes()).hexdigest()
        self.manifest = self.dir / "ASSET_PLAN.json"
        self.manifest.write_text(json.dumps({"schemaVersion": 1, "target": dict(upload.TARGET), "assets": [
            {"key": "poca_1", "path": "art/poca_1.png", "assetType": "Image", "contentType": "image/png",
             "sha256": self.sha, "displayName": "CyberOutlaw poca_1", "description": "Poça desenhada por código."}]}))
        self.state = self.dir / "estado"

    def run_upload(self, transport):
        return upload.upload_manifest(self.manifest, "chave-teste", state_dir=self.state, transport=transport,
                                      max_polls=1, max_wait_seconds=0, sleep=lambda _: None)

    def test_refused_key_stops_and_leaves_no_failed_receipt(self):
        transport = Refuse(401)
        with self.assertRaises(upload.AuthRejected) as caught:
            self.run_upload(transport)
        self.assertEqual(caught.exception.status, 401)
        self.assertIn("Invalid API Key", caught.exception.detail)
        self.assertFalse((self.state / (self.sha + ".json")).exists())
        self.assertEqual(len(list((self.state / "rejected").glob("*.json"))), 1)

    def test_old_auth_failure_is_retried_with_the_new_key(self):
        self.state.mkdir()
        old = {"schemaVersion": 1, "target": dict(upload.TARGET), "sha256": self.sha, "assetType": "Image",
               "contentType": "image/png", "assetId": None, "status": "failed", "permissionStatus": "pending",
               "lastErrorCode": "create_http_401"}
        (self.state / (self.sha + ".json")).write_text(json.dumps(old))
        transport = Refuse(403)
        with self.assertRaises(upload.AuthRejected):
            self.run_upload(transport)
        self.assertEqual(transport.calls, [("POST", upload.ASSETS_URL + "/assets")])

    def test_key_check_reads_one_approved_asset_and_explains(self):
        self.state.mkdir()
        (self.state / "pronto.json").write_text(json.dumps({"status": "ready", "assetId": "123456"}))
        transport = Refuse(401)
        out = io.StringIO()
        with redirect_stdout(out):
            code = catalog.test_key(self.state, transport=transport, key="chave-teste")
        self.assertEqual(code, 1)
        self.assertEqual(transport.calls, [("GET", upload.ASSETS_URL + "/assets/123456")])
        self.assertIn("HTTP 401", out.getvalue())
        self.assertIn("0.0.0.0/0", out.getvalue())
        self.assertNotIn("chave-teste", out.getvalue())


if __name__ == "__main__":
    unittest.main()
