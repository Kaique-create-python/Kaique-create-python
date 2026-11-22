"""Testa o vínculo do pacote real sem rede e sem IDs de produção."""
from pathlib import Path
import unittest

from media_tools.catalog import resolved_config, verify_media, SOUNDS
from media_tools.upload import TARGET

ROOT = Path(__file__).resolve().parents[1]


class MediaBindingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan, cls.capri = verify_media(ROOT)

    def fixture(self):
        return {"target": TARGET.copy(), "assets": [
            {**row, "assetId": str(1000 + i), "status": "ready",
             "moderationState": "Approved", "permissionStatus": "granted"}
            for i, row in enumerate(self.plan["assets"])]}

    def test_resolved_real_frames_and_sounds(self):
        result = self.fixture()
        lookup = {r["key"]: int(r["assetId"]) for r in result["assets"]}
        out = resolved_config(ROOT, self.plan, result, video="8000")
        self.assertEqual(set(out["sounds"]), set(SOUNDS))
        self.assertEqual(set(out["clips"]), set(self.capri["clips"]))
        for name, clip in out["clips"].items():
            self.assertEqual(clip["fps"], self.capri["clips"][name]["fps"])
            for tile, source in zip(clip["frames"], self.capri["clips"][name]["frames"], strict=True):
                self.assertEqual(tile["id"], lookup[source["assetKey"]])
                self.assertEqual([tile[k] for k in "xywh"], [source[k] for k in "xywh"])
        self.assertEqual(out["video"], 8000)
        self.assertNotIn("background", out)

    def test_assets_needing_approval_do_not_bind(self):
        result = self.fixture()
        result["assets"][0]["moderationState"] = "Reviewing"
        with self.assertRaisesRegex(ValueError, "aguardando"):
            resolved_config(ROOT, self.plan, result)

    def test_receipt_is_bound_to_same_file_and_universe(self):
        result = self.fixture()
        result["assets"][0]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            resolved_config(ROOT, self.plan, result)
        result = self.fixture()
        result["target"]["universeId"] = "1400"
        with self.assertRaises(ValueError):
            resolved_config(ROOT, self.plan, result)

    def test_default_does_not_submit_paid_video_or_static_city(self):
        self.assertTrue(all(row["assetType"] in ("Image", "Audio") for row in self.plan["assets"]))
        self.assertTrue(all(row["path"].startswith(("capri/", "audio/")) for row in self.plan["assets"]))
        self.assertNotIn("video", resolved_config(ROOT, self.plan, self.fixture()))


if __name__ == "__main__":
    unittest.main()
