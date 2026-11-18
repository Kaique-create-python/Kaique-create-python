"""Offline contract tests. No Roblox requests or credentials are used."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
import zlib
from email.parser import BytesParser
from email.policy import default


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
TARGET = {"userId": "10735737143", "universeId": "10776462844", "placeId": "89520940302906"}
API = "https://apis.roblox.com/assets/v1"
GRANT = "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions"


class Simulator:
    def __init__(self, *responses):
        self.responses = list(responses)
        self.calls = []

    def request(self, method, url, headers, body=None, timeout=30):
        self.calls.append((method, url, dict(headers), body))
        if not self.responses:
            raise AssertionError("Unexpected network request: " + method + " " + url)
        response = self.responses.pop(0)
        if callable(response):
            response = response()
        if isinstance(response, BaseException):
            raise response
        return response


def audio_bytes():
    stream = io.BytesIO()
    with wave.open(stream, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(24000)
        audio.writeframes(b"\x00\x00" * 2400)
    return stream.getvalue()


class AssetsUploadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        module_path = ROOT / "tooling/assets_upload.py"
        cls.module_exists = module_path.exists()
        if cls.module_exists:
            spec = importlib.util.spec_from_file_location("assets_upload", module_path)
            cls.uploader = importlib.util.module_from_spec(spec)
            sys.modules["assets_upload"] = cls.uploader
            spec.loader.exec_module(cls.uploader)

    def setUp(self):
        self.assertTrue(self.module_exists, "The Termux uploader has not been implemented")
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.data = audio_bytes()
        (self.folder / "atlas.wav").write_bytes(self.data)
        self.sha = hashlib.sha256(self.data).hexdigest()
        self.manifest = self.folder / "AUDIO_MANIFEST.json"
        self.plan = {
            "schemaVersion": 1, "target": dict(TARGET),
            "assets": [{"key": "voices", "path": "atlas.wav", "assetType": "Audio",
                        "contentType": "audio/wav", "sha256": self.sha,
                        "displayName": "Bastiao voices", "description": "Voices atlas",
                        "durationSeconds": 0.1, "assetId": None}],
        }
        self.write_plan()

    def write_plan(self):
        self.manifest.write_text(json.dumps(self.plan), encoding="utf-8")

    def response(self, status=200, payload=None, headers=None):
        return self.uploader.HttpResponse(status, headers or {}, json.dumps(payload or {}).encode())

    def operation(self, moderation="Approved", creator=None, asset_type="Audio"):
        return {"path": "operations/op-1", "done": True, "response": {
            "path": "assets/1234567890123", "assetId": "1234567890123",
            "assetType": asset_type, "displayName": "Bastiao voices", "description": "Voices atlas",
            "creationContext": {"creator": creator or {"userId": TARGET["userId"]}},
            "moderationResult": {"moderationState": moderation}, "revisionId": "1",
        }}

    def run_upload(self, transport, **options):
        return self.uploader.upload_manifest(self.manifest, "TEST-KEY-NOT-A-REAL-CREDENTIAL", transport,
                                             sleep=lambda _: None, **options)

    def test_upload_encodes_documented_multipart_and_grants_only_this_universe(self):
        transport = Simulator(self.response(payload={"path": "operations/op-1", "done": False}),
                              self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        result = self.run_upload(transport)
        self.assertEqual(result["runtimeMap"], {"voices": "rbxassetid://1234567890123"})
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual([(c[0], c[1]) for c in transport.calls], [
            ("POST", API + "/assets"), ("GET", API + "/operations/op-1"), ("PATCH", GRANT)])
        headers, raw = transport.calls[0][2:]
        message = BytesParser(policy=default).parsebytes(
            ("Content-Type: " + headers["Content-Type"] + "\r\nMIME-Version: 1.0\r\n\r\n").encode() + raw)
        parts = {part.get_param("name", header="content-disposition"): part for part in message.iter_parts()}
        self.assertEqual(set(parts), {"request", "fileContent"})
        request = json.loads(parts["request"].get_payload(decode=True))
        self.assertEqual(request, {"assetType": "Audio", "displayName": "Bastiao voices",
                                  "description": "Voices atlas",
                                  "creationContext": {"creator": {"userId": TARGET["userId"]}, "expectedPrice": 0}})
        self.assertEqual(parts["fileContent"].get_content_type(), "audio/wav")
        self.assertEqual(parts["fileContent"].get_payload(decode=True), self.data)
        self.assertEqual(json.loads(transport.calls[-1][3]), {
            "subjectType": "Universe", "subjectId": TARGET["universeId"], "action": "Use",
            "requests": [{"assetId": 1234567890123, "grantToDependencies": True}]})
        self.assertEqual(json.loads((self.folder / "UPLOADED_ASSETS.json").read_text()), result)
        saved = (self.folder / ".asset_upload_state" / (self.sha + ".json")).read_text()
        self.assertNotIn("TEST-KEY", saved)

    def test_successful_sha_is_reused_across_stable_keys_without_another_post(self):
        transport = Simulator(self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        self.run_upload(transport)
        self.plan["assets"][0]["key"] = "renamed_voices"
        self.write_plan()
        second = Simulator()
        result = self.run_upload(second)
        self.assertEqual(second.calls, [])
        self.assertEqual(result["runtimeMap"], {"renamed_voices": "rbxassetid://1234567890123"})

    def test_changed_file_is_rejected_before_any_network_request(self):
        (self.folder / "atlas.wav").write_bytes(self.data + b"changed")
        transport = Simulator()
        with self.assertRaisesRegex(ValueError, "sha256"):
            self.run_upload(transport)
        self.assertEqual(transport.calls, [])

    def test_owner_or_game_context_cannot_be_changed_by_a_manifest(self):
        for field in ("userId", "universeId", "placeId"):
            with self.subTest(field=field):
                self.plan["target"] = dict(TARGET, **{field: "999"})
                self.write_plan()
                transport = Simulator()
                with self.assertRaisesRegex(ValueError, "target"):
                    self.run_upload(transport)
                self.assertEqual(transport.calls, [])

    def test_mime_mismatch_is_rejected_before_upload(self):
        self.plan["assets"][0]["contentType"] = "image/png"
        self.write_plan()
        transport = Simulator()
        with self.assertRaisesRegex(ValueError, "contentType"):
            self.run_upload(transport)
        self.assertEqual(transport.calls, [])

    def test_manifest_cannot_upload_files_outside_its_directory(self):
        self.plan["assets"][0]["path"] = "../private.wav"
        self.write_plan()
        with self.assertRaisesRegex(ValueError, "path"):
            self.uploader.validate_manifest(self.manifest)

    def test_timeout_records_uncertainty_before_post_and_never_blindly_reposts(self):
        def lost_response():
            receipt = json.loads((self.folder / ".asset_upload_state" / (self.sha + ".json")).read_text())
            self.assertEqual(receipt["status"], "submitting")
            raise TimeoutError("Sensitive response could contain TEST-KEY-NOT-A-REAL-CREDENTIAL")
        first = Simulator(lost_response)
        result = self.run_upload(first)
        self.assertEqual(result["assets"][0]["status"], "uncertain_upload")
        self.assertIsNone(result["assets"][0]["assetId"])
        second = Simulator()
        self.assertEqual(self.run_upload(second)["assets"][0]["status"], "uncertain_upload")
        self.assertEqual(second.calls, [])
        self.assertNotIn("TEST-KEY", json.dumps(result))

    def test_server_error_or_redirect_on_post_is_uncertain_not_retried(self):
        for status in (302, 500, 502, 503):
            with self.subTest(status=status):
                state = self.folder / str(status)
                transport = Simulator(self.response(status, {"message": "TEST-KEY-NOT-A-REAL-CREDENTIAL"},
                                                    {"Location": "https://cdn.example.invalid/steal"}))
                result = self.run_upload(transport, state_dir=state)
                self.assertEqual(result["assets"][0]["status"], "uncertain_upload")
                self.assertEqual(len(transport.calls), 1)
                self.assertNotIn("TEST-KEY", json.dumps(result))

    def test_operation_is_resumed_instead_of_creating_another_asset(self):
        first = Simulator(self.response(payload={"path": "operations/op-1", "done": False}),
                          self.response(payload={"path": "operations/op-1", "done": False}))
        self.assertEqual(self.run_upload(first, max_polls=1)["assets"][0]["status"], "uploading")
        second = Simulator(self.response(payload=self.operation()),
                           self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        result = self.run_upload(second)
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual(second.calls[0][0:2], ("GET", API + "/operations/op-1"))

    def test_returned_operation_survives_an_incomplete_create_response(self):
        transport = Simulator(self.response(payload={"path": "operations/op-1", "done": True}),
                              self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        result = self.run_upload(transport)
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual([call[0] for call in transport.calls], ["POST", "GET", "PATCH"])

    def test_retry_after_http_date_is_respected(self):
        transport = Simulator(self.response(payload={"path": "operations/op-1", "done": False}),
                              self.response(429, headers={"retry-after": "Thu, 01 Jan 1970 00:16:45 GMT"}),
                              self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        waits = []
        result = self.uploader.upload_manifest(self.manifest, "TEST-KEY", transport,
                                              now=lambda: 1000.0, sleep=waits.append)
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual(waits, [5.0])

    def test_poll_budget_stops_an_operation_that_remains_pending(self):
        pending = {"path": "operations/op-1", "done": False}
        transport = Simulator(*(self.response(payload=pending) for _ in range(4)))
        result = self.run_upload(transport, max_polls=3)
        self.assertEqual(result["assets"][0]["status"], "uploading")
        self.assertEqual([call[0] for call in transport.calls], ["POST", "GET", "GET", "GET"])

    def test_grants_can_be_deferred_without_treating_approved_as_ready(self):
        transport = Simulator(self.response(payload=self.operation()))
        result = self.run_upload(transport, grant_permissions=False)
        self.assertEqual(result["assets"][0]["status"], "pending_permission")
        self.assertEqual(result["runtimeMap"], {})
        self.assertEqual(len(transport.calls), 1)

    def test_operation_error_does_not_become_a_success_or_a_fresh_post(self):
        first = Simulator(self.response(payload={"path": "operations/op-1", "done": True,
                                                "error": {"code": 400, "message": "Rejected asset"}}))
        result = self.run_upload(first)
        self.assertEqual(result["assets"][0]["status"], "failed")
        self.assertEqual(result["runtimeMap"], {})
        self.assertEqual(len(first.calls), 1)
        second = Simulator()
        self.run_upload(second)
        self.assertEqual(second.calls, [])

    def test_external_operation_path_never_receives_the_key(self):
        transport = Simulator(self.response(payload={"path": "https://cdn.example.invalid/operations/op-1"}))
        result = self.run_upload(transport)
        self.assertEqual(result["assets"][0]["status"], "uncertain_upload")
        self.assertEqual(len(transport.calls), 1)

    def test_pending_moderation_is_refreshed_without_reuploading(self):
        first = Simulator(self.response(payload=self.operation("MODERATION_STATE_REVIEWING")))
        result = self.run_upload(first)
        self.assertEqual(result["assets"][0]["status"], "pending_moderation")
        self.assertEqual(result["runtimeMap"], {})
        self.assertEqual(result["assets"][0]["assetId"], "1234567890123")
        second = Simulator(self.response(payload=self.operation("MODERATION_STATE_APPROVED")["response"]),
                           self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        self.assertEqual(self.run_upload(second)["assets"][0]["status"], "ready")
        self.assertEqual(second.calls[0][0:2], ("GET", API + "/assets/1234567890123"))

    def test_rejected_or_unknown_moderation_never_enters_runtime_map(self):
        for moderation, status in (("Rejected", "rejected"), ("Unknown", "pending_moderation")):
            with self.subTest(moderation=moderation):
                transport = Simulator(self.response(payload=self.operation(moderation)))
                result = self.run_upload(transport, state_dir=self.folder / moderation)
                self.assertEqual(result["assets"][0]["status"], status)
                self.assertEqual(result["runtimeMap"], {})
                self.assertEqual(len(transport.calls), 1)

    def test_response_creator_and_asset_type_are_verified_before_permission_grant(self):
        for operation in (self.operation(creator={"groupId": TARGET["userId"]}),
                          self.operation(creator={"userId": "123"}),
                          self.operation(asset_type="Model")):
            with self.subTest(operation=operation):
                transport = Simulator(self.response(payload=operation))
                result = self.run_upload(transport, state_dir=self.folder / str(len(str(operation))))
                self.assertEqual(result["assets"][0]["status"], "verification_failed")
                self.assertEqual(result["runtimeMap"], {})
                self.assertEqual(len(transport.calls), 1)

    def test_grant_error_keeps_real_id_but_not_ready_status(self):
        transport = Simulator(self.response(payload=self.operation()), self.response(payload={
            "successAssetIds": [], "errors": [{"assetId": 1234567890123, "code": "CannotManageSubject"}]}))
        result = self.run_upload(transport)
        self.assertEqual(result["assets"][0]["status"], "pending_permission")
        self.assertEqual(result["assets"][0]["permissionStatus"], "error")
        self.assertEqual(result["assets"][0]["assetId"], "1234567890123")
        self.assertEqual(result["runtimeMap"], {})

    def test_success_array_must_explicitly_contain_the_exact_asset_id(self):
        transport = Simulator(self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [123], "errors": []}))
        result = self.run_upload(transport)
        self.assertEqual(result["assets"][0]["status"], "pending_permission")
        self.assertEqual(result["runtimeMap"], {})

    def test_poll_retries_reads_only_and_honors_retry_after(self):
        transport = Simulator(self.response(payload={"path": "operations/op-1", "done": False}),
                              self.response(429, headers={"Retry-After": "3"}),
                              self.response(503, headers={"Retry-After": "2"}),
                              self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        waits = []
        result = self.uploader.upload_manifest(self.manifest, "TEST-KEY", transport, sleep=waits.append)
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual(waits, [3.0, 2.0])
        self.assertEqual([c[0] for c in transport.calls], ["POST", "GET", "GET", "GET", "PATCH"])

    def test_long_retry_after_is_durable_and_bounds_waiting_across_restarts(self):
        first = Simulator(self.response(payload={"path": "operations/op-1", "done": False}),
                          self.response(429, headers={"Retry-After": "600"}))
        result = self.run_upload(first, max_wait_seconds=20, now=lambda: 1000.0)
        self.assertEqual(result["assets"][0]["status"], "uploading")
        second = Simulator()
        self.run_upload(second, now=lambda: 1100.0)
        self.assertEqual(second.calls, [])
        third = Simulator(self.response(payload=self.operation()),
                          self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        self.assertEqual(self.run_upload(third, now=lambda: 1601.0)["assets"][0]["status"], "ready")

    def test_all_entries_validate_before_any_upload_can_happen(self):
        self.plan["assets"].append(dict(self.plan["assets"][0], key="bad", sha256="0" * 64))
        self.write_plan()
        transport = Simulator()
        with self.assertRaisesRegex(ValueError, "sha256"):
            self.run_upload(transport)
        self.assertEqual(transport.calls, [])

    def test_audio_duration_must_match_file_and_stay_below_seven_minutes(self):
        for duration in (421, 0.5):
            with self.subTest(duration=duration):
                self.plan["assets"][0]["durationSeconds"] = duration
                self.write_plan()
                with self.assertRaisesRegex(ValueError, "duration"):
                    self.uploader.validate_manifest(self.manifest)

    def test_image_glb_fbx_and_rbxmx_content_are_validated_offline(self):
        def png_chunk(kind, payload):
            return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
        png = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
        png += png_chunk(b"IDAT", zlib.compress(b"\0\0\0\0\xff")) + png_chunk(b"IEND", b"")
        gltf = json.dumps({"asset": {"version": "2.0"}, "scenes": [{"nodes": []}]}).encode()
        gltf += b" " * (-len(gltf) % 4)
        glb = struct.pack("<4sII", b"glTF", 2, 20 + len(gltf)) + struct.pack("<I4s", len(gltf), b"JSON") + gltf
        fixtures = [
            ("image.png", png, "Image", "image/png"),
            ("model.glb", glb, "Model", "model/gltf-binary"),
            ("model.fbx", b"Kaydara FBX Binary  \x00\x1a\x00" + struct.pack("<I", 7400) + b"\0" * 13, "Model", "model/fbx"),
            ("walk.rbxmx", b'<roblox version="4"><Item class="KeyframeSequence"><Properties/></Item></roblox>',
             "Animation", "model/x-rbxm"),
        ]
        for index, (name, data, kind, mime) in enumerate(fixtures):
            (self.folder / name).write_bytes(data)
            self.plan["assets"].append({"key": "asset" + str(index), "path": name, "assetType": kind,
                                        "contentType": mime, "displayName": name,
                                        "sha256": hashlib.sha256(data).hexdigest()})
        self.write_plan()
        validated = self.uploader.validate_manifest(self.manifest)
        self.assertEqual(len(validated["assets"]), 5)
        (self.folder / "image.png").write_bytes(b"invalid PNG")
        self.plan["assets"][1]["sha256"] = hashlib.sha256(b"invalid PNG").hexdigest()
        self.write_plan()
        with self.assertRaisesRegex(ValueError, "PNG"):
            self.uploader.validate_manifest(self.manifest)

    def test_invalid_key_and_non_roblox_urls_are_rejected_before_network(self):
        transport = Simulator()
        with self.assertRaisesRegex(ValueError, "key"):
            self.uploader.upload_manifest(self.manifest, "bad\r\nheader", transport)
        self.assertEqual(transport.calls, [])
        for url in ("http://apis.roblox.com/assets/v1/assets", "https://apis.roblox.com.evil.invalid/a",
                    "https://key@apis.roblox.com/assets/v1/assets", "https://apis.roblox.com:444/assets/v1/assets"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.uploader.UrllibTransport().request("GET", url, {"x-api-key": "TEST-KEY"})

    def test_known_operation_can_be_attached_to_an_uncertain_receipt_without_a_post(self):
        self.run_upload(Simulator(TimeoutError("Response lost")))
        self.uploader.recover_operation(self.manifest, self.sha, "operations/op-1")
        transport = Simulator(self.response(payload=self.operation()),
                              self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        result = self.run_upload(transport)
        self.assertEqual(result["assets"][0]["status"], "ready")
        self.assertEqual(transport.calls[0][0], "GET")
        self.assertNotIn("POST", [call[0] for call in transport.calls])

    def test_recovery_refuses_external_operation_paths_and_cannot_replace_ready_assets(self):
        self.run_upload(Simulator(TimeoutError("Response lost")))
        with self.assertRaises(ValueError):
            self.uploader.recover_operation(self.manifest, self.sha, "https://cdn.invalid/op")
        self.uploader.recover_operation(self.manifest, self.sha, "operations/op-1")
        self.run_upload(Simulator(self.response(payload=self.operation()),
                                  self.response(payload={"successAssetIds": [1234567890123], "errors": []})))
        with self.assertRaises(ValueError):
            self.uploader.recover_operation(self.manifest, self.sha, "operations/another-op")

    def test_only_a_definitive_create_rejection_can_be_reset_for_retry(self):
        transport = Simulator(self.response(403))
        self.assertEqual(self.run_upload(transport)["assets"][0]["status"], "failed")
        self.uploader.reset_rejected(self.manifest, self.sha)
        second = Simulator(self.response(payload=self.operation()),
                           self.response(payload={"successAssetIds": [1234567890123], "errors": []}))
        self.assertEqual(self.run_upload(second)["assets"][0]["status"], "ready")
        with self.assertRaises(ValueError):
            self.uploader.reset_rejected(self.manifest, self.sha)

    def test_uncertain_create_cannot_be_reset(self):
        self.run_upload(Simulator(self.response(503)))
        with self.assertRaises(ValueError):
            self.uploader.reset_rejected(self.manifest, self.sha)

    def test_create_retry_after_delays_the_first_poll_and_survives_restarts(self):
        first = Simulator(self.response(payload={"path": "operations/op-1", "done": False},
                                        headers={"Retry-After": "120"}))
        result = self.run_upload(first, now=lambda: 1000.0)
        self.assertEqual(result["assets"][0]["status"], "uploading")
        self.assertEqual(len(first.calls), 1)
        second = Simulator()
        self.run_upload(second, now=lambda: 1100.0)
        self.assertEqual(second.calls, [])

    def test_corrupt_ready_receipt_cannot_create_a_runtime_binding(self):
        state = self.folder / ".asset_upload_state"
        state.mkdir()
        (state / (self.sha + ".json")).write_text(json.dumps({
            "schemaVersion": 1, "target": TARGET, "sha256": self.sha, "assetType": "Audio",
            "contentType": "audio/wav", "status": "ready", "assetId": "0"}))
        with self.assertRaisesRegex(ValueError, "Receipt"):
            self.run_upload(Simulator())

    def test_unknown_extension_cannot_pass_when_mime_is_missing(self):
        (self.folder / "atlas.unknown").write_bytes(self.data)
        self.plan["assets"][0]["path"] = "atlas.unknown"
        self.plan["assets"][0].pop("contentType")
        self.write_plan()
        with self.assertRaisesRegex(ValueError, "contentType"):
            self.uploader.validate_manifest(self.manifest)

    def test_cli_check_is_offline_and_upload_refuses_piped_credentials(self):
        script = str(ROOT / "tooling/assets_upload.py")
        checked = subprocess.run([sys.executable, script, "check", str(self.manifest)],
                                 capture_output=True, text=True, check=False)
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertEqual(json.loads(checked.stdout)["assets"], 1)
        refused = subprocess.run([sys.executable, script, "upload", str(self.manifest)],
                                 input="DO-NOT-ECHO-THIS-KEY\n", capture_output=True, text=True, check=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertNotIn("DO-NOT-ECHO", refused.stdout + refused.stderr)
        self.assertFalse((self.folder / ".asset_upload_state").exists())

    def test_oversize_asset_and_symlink_escape_are_rejected(self):
        with (self.folder / "atlas.wav").open("r+b") as handle:
            handle.truncate(20_000_000)
        with self.assertRaisesRegex(ValueError, "size"):
            self.uploader.validate_manifest(self.manifest)
        with tempfile.TemporaryDirectory() as elsewhere:
            outside = Path(elsewhere) / "private.wav"
            outside.write_bytes(self.data)
            (self.folder / "atlas.wav").unlink()
            (self.folder / "atlas.wav").symlink_to(outside)
            with self.assertRaisesRegex(ValueError, "path"):
                self.uploader.validate_manifest(self.manifest)

    def test_compressed_audio_duration_is_read_from_bytes(self):
        stream_info = bytearray(34)
        stream_info[10:18] = ((24000 << 44) | (15 << 36) | 2400).to_bytes(8, "big")
        flac = b"fLaC\x80\x00\x00\x22" + stream_info
        vorbis = b"\x01vorbis" + b"\0" * 4 + b"\x01" + (24000).to_bytes(4, "little") + b"\0" * 14
        ogg = (b"OggS\0\x02" + (2400).to_bytes(8, "little") + (1).to_bytes(4, "little")
               + b"\0" * 8 + b"\x01" + bytes([len(vorbis)]) + vorbis)
        mp3 = (b"\xff\xfb\x90\x64" + b"\0" * 413) * 5
        for extension, data, mime, duration in (("flac", flac, "audio/flac", 0.1),
                                               ("ogg", ogg, "audio/ogg", 0.1),
                                               ("mp3", mp3, "audio/mpeg", 5 * 1152 / 44100)):
            with self.subTest(extension=extension):
                name = "atlas." + extension
                (self.folder / name).write_bytes(data)
                self.plan["assets"][0].update(path=name, sha256=hashlib.sha256(data).hexdigest(),
                                               contentType=mime, durationSeconds=duration)
                self.write_plan()
                self.assertAlmostEqual(self.uploader.validate_manifest(self.manifest)["assets"][0]["durationSeconds"], duration)

    def test_glb_cannot_contain_external_resources_or_truncated_chunks(self):
        for gltf, extra in (({"asset": {"version": "2.0"}, "buffers": [{"uri": "private.bin"}]}, b""),
                            ({"asset": {"version": "2.0"}}, b"BAD!")):
            encoded = json.dumps(gltf).encode()
            encoded += b" " * (-len(encoded) % 4)
            data = struct.pack("<4sII", b"glTF", 2, 20 + len(encoded) + len(extra))
            data += struct.pack("<I4s", len(encoded), b"JSON") + encoded + extra
            (self.folder / "model.glb").write_bytes(data)
            self.plan["assets"] = [{"key": "model", "path": "model.glb", "assetType": "Model",
                                   "contentType": "model/gltf-binary", "displayName": "Monster",
                                   "sha256": hashlib.sha256(data).hexdigest()}]
            self.write_plan()
            with self.subTest(gltf=gltf), self.assertRaises(ValueError):
                self.uploader.validate_manifest(self.manifest)


if __name__ == "__main__":
    unittest.main()
