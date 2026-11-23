"""Testa o vínculo do pacote real sem rede e sem IDs de produção."""
from pathlib import Path
import json
from shutil import copytree
from tempfile import TemporaryDirectory
import unittest

from media_tools.catalog import make_config, resolved_config, verify_media, ART, OPTIONAL_ART, OPTIONAL_SOUNDS, SOUNDS
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
        self.assertEqual(set(out["sounds"]), set(SOUNDS) | set(OPTIONAL_SOUNDS))
        self.assertEqual(out["art"], {name: lookup[name] for name in ART})
        self.assertEqual(set(out["clips"]), set(self.capri["clips"]))
        for name, clip in out["clips"].items():
            self.assertEqual(clip["fps"], self.capri["clips"][name]["fps"])
            for tile, source in zip(clip["frames"], self.capri["clips"][name]["frames"], strict=True):
                self.assertEqual(tile["id"], lookup[source["assetKey"]])
                self.assertEqual([tile[k] for k in "xywh"], [source[k] for k in "xywh"])
        self.assertEqual(out["video"], 8000)
        self.assertNotIn("background", out)

    def test_city_windows_are_optional_until_approved(self):
        result = self.fixture()
        for row in result["assets"]:
            if row["key"] in OPTIONAL_ART:
                row["moderationState"] = "Reviewing"
        out = resolved_config(ROOT, self.plan, result)
        self.assertFalse(OPTIONAL_ART & set(out["art"]))
        self.assertIn("asphalt", out["art"])
        self.assertTrue(OPTIONAL_ART <= set(ART))

    def test_weapon_sounds_are_optional_until_approved(self):
        result = self.fixture()
        for row in result["assets"]:
            if row["key"] in OPTIONAL_SOUNDS:
                row["status"] = "pending_moderation"
        out = resolved_config(ROOT, self.plan, result)
        self.assertEqual(set(out["sounds"]), set(SOUNDS))

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

    def test_new_package_reuses_shared_approved_media(self):
        with TemporaryDirectory() as directory:
            root = Path(directory) / "new-package"
            state = Path(directory) / "recibos-midia"
            copytree(ROOT / "media", root / "media", ignore=lambda _, names: {"UPLOADED_ASSETS.json"} & set(names))
            state.mkdir()
            for index, row in enumerate(self.fixture()["assets"]):
                saved = dict(row, schemaVersion=1, target=TARGET, operationPath=f"operations/test_{index}")
                (state / f"{row['sha256']}.json").write_text(json.dumps(saved), encoding="utf-8")
            self.assertFalse((root / "media/UPLOADED_ASSETS.json").exists())
            expected = resolved_config(ROOT, self.plan, self.fixture(), video="8000")
            self.assertEqual(make_config(root, state_dir=state, video="8000"), expected)
            missing = self.plan["assets"][0]
            (state / f"{missing['sha256']}.json").unlink()
            with self.assertRaisesRegex(ValueError, missing["key"]):
                make_config(root, state_dir=state)

    def test_default_does_not_submit_paid_video_or_static_city(self):
        self.assertTrue(all(row["assetType"] in ("Image", "Audio") for row in self.plan["assets"]))
        art_paths = {row["path"] for row in self.plan["assets"] if row["path"].startswith("art/")}
        self.assertEqual(art_paths, {f"art/{key}.png" for key in ART})
        self.assertTrue(all(row["path"].startswith(("capri/", "audio/", "art/")) for row in self.plan["assets"]))
        self.assertNotIn("video", resolved_config(ROOT, self.plan, self.fixture()))


if __name__ == "__main__":
    unittest.main()
