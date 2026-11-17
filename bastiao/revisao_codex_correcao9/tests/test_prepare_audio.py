"""Offline tests: the HTTP boundary is fake; DSP uses tiny test tones only."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "tooling" / "prepare_audio.py"
if MODULE.exists():
    spec = importlib.util.spec_from_file_location("prepare_audio", MODULE)
    audio = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[spec.name] = audio
    spec.loader.exec_module(audio)
else:
    audio = None


class FakeAPI:
    """Exercise real request construction, persistence, decoding, and atlas code."""
    def __init__(self, mp3, *, mode="ok", voices=None, loop_mp3=None):
        self.mp3, self.mode, self.calls = mp3, mode, []
        self.loop_mp3 = loop_mp3
        self.voices = voices or [
            {"voice_id": "male_br", "name": "Homem BR", "category": "premade",
             "labels": {"gender": "male", "language": "pt", "accent": "Brazilian", "age": "middle_aged", "description": "deep"},
             "available_for_tiers": ["free"], "high_quality_base_model_ids": ["eleven_v3"]},
            {"voice_id": "male_other", "name": "Outro homem", "category": "premade",
             "labels": {"gender": "male", "language": "en", "age": "middle_aged"},
             "available_for_tiers": ["free"], "high_quality_base_model_ids": ["eleven_v3"]},
        ]

    def __call__(self, method, url, headers, body):
        path = url.split("api.elevenlabs.io", 1)[-1]
        payload = json.loads(body) if body else None
        self.calls.append((method, path, payload))
        def response(data, status=200, mime="application/json", **more):
            return audio.HTTPResponse(status, {"content-type": mime, **more},
                                      json.dumps(data).encode() if mime == "application/json" else data)
        if path == "/v1/voices":
            return response({"voices": self.voices})
        if path == "/v1/models":
            return response([{"model_id": "eleven_v3", "can_do_text_to_speech": True,
                              "serves_pro_voices": True, "languages": [{"language_id": "pt", "name": "Portuguese"}]}])
        if path == "/v1/user/subscription":
            return response({"tier": "free", "character_count": 10, "character_limit": 10000})
        if path == "/v1/history/h_good":
            return response({"history_item_id": "h_good", "voice_id": "male_br", "model_id": "eleven_v3",
                             "text": "[curious] Fala intacta.", "request_id": "r_old", "content_type": "audio/mpeg"})
        if path == "/v1/history/h_good/audio":
            return response(self.mp3, mime="audio/mpeg")
        if method == "POST":
            if self.mode == "timeout":
                raise TimeoutError("secret-token-must-never-be-written")
            if self.mode == "json":
                return response({"detail": "secret-token-must-never-be-written"}, mime="application/json")
            if self.mode == "bad_audio":
                return response(b"ID3invalid audio", mime="audio/mpeg", **{"request-id": "r_bad"})
            data = self.loop_mp3 if payload.get("loop") and self.loop_mp3 is not None else self.mp3
            return response(data, mime="audio/mpeg", **{"request-id": "r_ok", "history-item-id": "h_good", "x-character-count": "30"})
        raise AssertionError((method, path))


class AudioProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = tempfile.TemporaryDirectory()
        cls.mp3path = Path(cls.fixtures.name) / "test_tone.mp3"
        if shutil.which("ffmpeg"):
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
                            "sine=frequency=640:sample_rate=44100:duration=0.22", "-c:a", "libmp3lame", "-b:a", "128k",
                            str(cls.mp3path)], check=True)
            cls.mp3 = cls.mp3path.read_bytes()
            loop_path = Path(cls.fixtures.name) / "periodic_loop.mp3"
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
                            "sine=frequency=640:sample_rate=44100:duration=4", "-c:a", "libmp3lame", "-b:a", "128k",
                            str(loop_path)], check=True)
            cls.loop_mp3 = loop_path.read_bytes()
        else:
            cls.mp3 = b""

    @classmethod
    def tearDownClass(cls):
        cls.fixtures.cleanup()

    def setUp(self):
        self.assertIsNotNone(audio, "The deferred media production implementation is missing")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.plan_path = self.root / "AUDIO_PLAN.json"
        self.plan = {
            "schemaVersion": 1,
            "target": {"userId": "10735737143", "universeId": "10776462844", "placeId": "89520940302906"},
            "voices": {
                "PAVEL": {"voiceId": "not_in_account", "name": "Selected actor", "gender": "male", "mature": True},
                "ORLOV_RADIO": {"voiceId": "also_missing", "name": "Another selected actor", "gender": "male", "mature": True},
            },
            "clips": [
                {"key": "line1", "kind": "tts", "role": "PAVEL", "text": "Fala intacta.", "tags": ["curious"],
                 "profile": "radio", "category": "Voice", "volume": 0.8, "spatial": False, "radio": True, "loop": False},
            ],
            "atlas": {"sampleRate": 44100, "paddingSeconds": 0.24},
        }
        self.write_plan()

    def write_plan(self):
        self.plan_path.write_text(json.dumps(self.plan), encoding="utf-8")

    def api(self, **kw):
        return FakeAPI(self.mp3, loop_mp3=self.loop_mp3, **kw)

    def receipt(self, key="line1"):
        return json.loads((self.root / "receipts" / f"{key}.json").read_text())

    def test_inspect_is_offline_and_does_not_claim_missing_media(self):
        status = audio.inspect_plan(self.plan_path)
        self.assertFalse(status["complete"])
        self.assertEqual(status["clips"]["line1"]["status"], "missing")
        self.assertFalse((self.root / "AUDIO_MANIFEST.json").exists())

    def test_completed_sources_skip_charged_posts_and_build_without_key(self):
        api = self.api()
        manifest = audio.prepare(self.plan_path, "secret-token-must-never-be-written", transport=api)
        self.assertEqual(len([c for c in api.calls if c[0] == "POST"]), 1)
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["target"]["userId"], "10735737143")
        receipt = self.receipt()
        self.assertEqual(receipt["status"], "completed")
        self.assertEqual(receipt["voice"]["voiceId"], "male_br")
        self.assertTrue(receipt["voice"]["fallbackReason"])
        self.assertEqual(receipt["sha256"], hashlib.sha256(self.mp3).hexdigest())
        first_post = [c for c in api.calls if c[0] == "POST"][0]
        self.assertEqual(first_post[1], "/v1/text-to-speech/male_br?output_format=mp3_44100_128")
        self.assertEqual(first_post[2]["text"], "[curious] Fala intacta.")
        self.assertEqual(first_post[2]["voice_settings"]["speed"], 1.0)
        self.assertEqual(first_post[2]["model_id"], "eleven_v3")
        def no_http(*args):
            self.fail("Complete sources must not contact the provider")
        second = audio.prepare(self.plan_path, transport=no_http)
        self.assertEqual(second["segments"], manifest["segments"])
        self.assertTrue(audio.inspect_plan(self.plan_path)["complete"])
        serialized = "\n".join(p.read_text(errors="replace") for p in self.root.rglob("*.json"))
        self.assertNotIn("secret-token-must-never-be-written", serialized)

    def test_different_male_characters_get_distinct_real_available_voices(self):
        self.plan["clips"].append({**self.plan["clips"][0], "key": "line2", "role": "ORLOV_RADIO", "text": "Outra fala."})
        self.write_plan()
        audio.prepare(self.plan_path, "test-key", transport=self.api())
        self.assertEqual(self.receipt("line1")["voice"]["voiceId"], "male_br")
        self.assertEqual(self.receipt("line2")["voice"]["voiceId"], "male_other")

    def test_timeout_is_persisted_and_never_posts_again_automatically(self):
        api = self.api(mode="timeout")
        with self.assertRaises(audio.AudioProductionError) as caught:
            audio.prepare(self.plan_path, "secret-token-must-never-be-written", transport=api)
        self.assertNotIn("secret-token", str(caught.exception))
        self.assertEqual(self.receipt()["status"], "uncertain")
        with self.assertRaises(audio.AudioProductionError):
            audio.prepare(self.plan_path, "test-key", transport=api)
        self.assertEqual(len([c for c in api.calls if c[0] == "POST"]), 1)
        self.assertFalse((self.root / "AUDIO_MANIFEST.json").exists())

    def test_json_or_invalid_audio_response_blocks_automatic_regeneration(self):
        for mode in ("json", "bad_audio"):
            with self.subTest(mode=mode):
                root = self.root / mode
                root.mkdir()
                p = root / "AUDIO_PLAN.json"
                p.write_text(json.dumps(self.plan))
                api = self.api(mode=mode)
                with self.assertRaises(audio.AudioProductionError):
                    audio.prepare(p, "secret-token-must-never-be-written", transport=api)
                with self.assertRaises(audio.AudioProductionError):
                    audio.prepare(p, "test-key", transport=api)
                self.assertEqual(len([c for c in api.calls if c[0] == "POST"]), 1)
                self.assertFalse((root / "AUDIO_MANIFEST.json").exists())
                self.assertFalse(any(b"secret-token" in f.read_bytes() for f in root.rglob("*") if f.is_file()))

    def test_corrupted_completed_source_is_not_silently_billed_again(self):
        api = self.api()
        audio.prepare(self.plan_path, "test-key", transport=api)
        (self.root / self.receipt()["rawPath"]).write_bytes(b"corrupted")
        with self.assertRaises(audio.AudioProductionError):
            audio.prepare(self.plan_path, "test-key", transport=api)
        self.assertEqual(len([c for c in api.calls if c[0] == "POST"]), 1)
        self.assertFalse(audio.inspect_plan(self.plan_path)["complete"])

    def test_history_recovery_uses_only_get_and_checks_text_voice(self):
        api = self.api(mode="timeout")
        with self.assertRaises(audio.AudioProductionError):
            audio.prepare(self.plan_path, "test-key", transport=api)
        recovered = audio.recover_history(self.plan_path, "line1", "h_good", "test-key", transport=api)
        self.assertEqual(recovered["status"], "completed")
        self.assertEqual(len([c for c in api.calls if c[0] == "POST"]), 1)
        self.assertEqual(self.receipt()["historyItemId"], "h_good")
        audio.build_atlases(self.plan_path)

    def test_unknown_professional_permissions_stop_before_any_post(self):
        voices = [{"voice_id": "restricted", "name": "Professional without plan proof", "category": "professional",
                   "labels": {"gender": "male", "language": "pt"}, "high_quality_base_model_ids": ["eleven_v3"]}]
        api = self.api(voices=voices)
        with self.assertRaises(audio.AudioProductionError):
            audio.prepare(self.plan_path, "test-key", transport=api)
        self.assertFalse(any(c[0] == "POST" for c in api.calls))

    def test_sfx_limits_are_checked_before_network(self):
        self.plan["clips"] = [{"key": "bad", "kind": "sfx", "text": "Metal", "durationSeconds": float("nan"),
                              "promptInfluence": 0.5, "category": "Foley", "profile": "foley", "volume": 0.8}]
        self.write_plan()
        with self.assertRaises(audio.AudioProductionError):
            audio.prepare(self.plan_path, "test-key", transport=self.api())

    def test_atlas_segments_stop_before_padding_and_ambient_is_separate(self):
        self.plan["clips"].extend([
            {"key": "step", "kind": "sfx", "text": "One concrete boot step, no voices, no music.", "durationSeconds": 0.6,
             "promptInfluence": 0.7, "profile": "foley", "category": "Foley", "volume": 0.7, "spatial": True, "loop": False},
            {"key": "ui_denied", "kind": "sfx", "text": "One brief relay denial click, no voices, no music.", "durationSeconds": 0.5,
             "promptInfluence": 0.8, "profile": "ui", "category": "UI", "volume": 0.5, "spatial": False, "loop": False},
            {"key": "bunker_air", "kind": "sfx", "text": "Seamless quiet ventilation, no voices, no music.", "durationSeconds": 4,
             "promptInfluence": 0.5, "profile": "ambience", "category": "Ambience", "volume": 0.25, "spatial": False, "loop": True},
        ])
        self.write_plan()
        api = self.api()
        manifest = audio.prepare(self.plan_path, "test-key", transport=api)
        audio.validate_manifest(manifest, self.root)
        self.assertEqual({a["key"] for a in manifest["assets"]}, {"voices_atlas", "foley_atlas", "bunker_air"})
        s1, s2 = manifest["segments"]["step"], manifest["segments"]["ui_denied"]
        self.assertAlmostEqual(s2["start"] - s1["finish"], 0.24, places=4)
        self.assertAlmostEqual(s1["duration"], s1["finish"] - s1["start"], places=4)
        self.assertEqual(s1["fileKey"], "foley_atlas")
        self.assertTrue(manifest["segments"]["line1"]["radio"])
        self.assertTrue(manifest["segments"]["bunker_air"]["loop"])
        self.assertEqual(manifest["clips"]["step"]["status"], "ready")
        self.assertTrue((self.root / manifest["clips"]["step"]["processedPath"]).exists())
        asset = next(a for a in manifest["assets"] if a["key"] == "foley_atlas")
        self.assertLessEqual(s2["finish"], asset["durationSeconds"] + 1 / 44100)
        broken = json.loads(json.dumps(manifest))
        broken["segments"]["step"]["finish"] = asset["durationSeconds"] + 1
        with self.assertRaises(audio.AudioProductionError):
            audio.validate_manifest(broken, self.root)
        sfx_post = next(c for c in api.calls if c[0] == "POST" and c[1].startswith("/v1/sound-generation"))
        self.assertEqual(sfx_post[2]["model_id"], "eleven_text_to_sound_v2")
        self.assertEqual(sfx_post[2]["duration_seconds"], 0.6)

    def test_clear_pending_requires_explicit_no_charge_verification(self):
        api = self.api(mode="timeout")
        with self.assertRaises(audio.AudioProductionError):
            audio.prepare(self.plan_path, "test-key", transport=api)
        with self.assertRaises(audio.AudioProductionError):
            audio.clear_pending(self.plan_path, "line1")
        audio.clear_pending(self.plan_path, "line1", no_charge_confirmed=True)
        self.assertEqual(audio.inspect_plan(self.plan_path)["clips"]["line1"]["status"], "missing")


class ShippedPlanTests(unittest.TestCase):
    def test_all_textos_lines_and_sound_keys_are_real_planned_sources(self):
        self.assertIsNotNone(audio, "The production implementation is missing")
        plan = audio.load_plan(ROOT / "audio" / "AUDIO_PLAN.json")
        import re
        rows = json.loads((ROOT / "BASE_CLAUDE_ETAPA2.json").read_text())
        source = next(r['source'] for r in rows if r['path'][-1] == 'Textos')
        portuguese = source.split('L.pt = {', 1)[1].split('L.en = {', 1)[0]
        original = re.search(r'\n\tfalas = \{(.*?)\n\t\}', portuguese, re.S).group(1)
        roles = dict(re.findall(r'(\w+) = "([^"]+)"', re.search(r'Textos.FALANTE = \{(.*?)\n\}', source, re.S).group(1)))
        lines = [(key, roles[key], text) for key,text in re.findall(r'(\w+) = "([^"]+)"', original)]
        planned = {c["key"]: c for c in plan["clips"]}
        self.assertEqual(len(lines), 20)
        self.assertEqual(len([c for c in planned.values() if c["kind"] == "tts"]), 3)
        self.assertEqual(len([c for c in planned.values() if c["kind"] == "reuse" and c["category"] == "Voice"]), 17)
        for key, role, text in lines:
            self.assertEqual(planned[key]["text"], text)
            self.assertEqual(planned[key]["role"], role)
        sounds = re.search(r'\n\tsons = \{(.*?)\n\t\}', portuguese, re.S).group(1)
        for key in re.findall(r'(\w+) = "', sounds):
            self.assertIn(planned[key]["kind"], {"sfx", "reuse"})
        required = {"ui_click", "ui_confirm", "ui_denied", "monster_step_01", "monster_step_02", "monster_breath", "bunker_air", "monster_roar"}
        required.update(f"soldier_step_concrete_{i:02d}" for i in range(1, 5))
        required.update(f"soldier_step_metal_{i:02d}" for i in range(1, 3))
        self.assertTrue(required <= planned.keys())
        roar = planned["monster_roar"]
        self.assertEqual(hashlib.sha256((ROOT / "audio" / roar["sourcePath"]).read_bytes()).hexdigest(), roar["sha256"])
        self.assertFalse((ROOT / "audio" / "AUDIO_MANIFEST.json").exists())


if __name__ == "__main__":
    unittest.main()
