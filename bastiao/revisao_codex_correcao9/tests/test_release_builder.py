"""Exercise real source assembly, binding, integrity and refusal behavior."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tests"))
from release_fixture import make_release, ready, write_json
try:
    from tooling import release_builder as builder
except ImportError:
    builder = None


class ReleaseBuilderTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(builder, "stage 3 release builder must assemble approved assets")
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.baseline = make_release(self.root)

    def read(self, path):
        return json.loads((self.root / path).read_text())

    def test_binds_new_sources_and_preserves_all_unmodified_claude_modules(self):
        rows, report = builder.assemble_sources(self.root)
        got = {tuple(row["path"]): row for row in rows}
        for original in self.baseline:
            key = tuple(original["path"])
            if key[-1] in {"Idioma", "Telas", "Preferencias", "Textos", "Prompts", "Cenario"}:
                self.assertEqual(got[key]["source"], original["source"])
        server = got[("ServerScriptService", "BastiaoServidor")]
        self.assertIn("replacement fixture BastiaoServidor", server["source"])
        previous = next(r for r in self.baseline if r["path"] == server["path"])
        self.assertIn(hashlib.sha256(previous["source"].encode()).hexdigest(), server["known"])
        self.assertTrue(set(previous.get("known", [])).issubset(server["known"]))
        self.assertEqual(report["stage"], 3)
        self.assertEqual(len(rows), 32)
        self.assertIn(("StarterPlayer", "StarterPlayerScripts", "BastiaoCliente", "Foley"), got)
        self.assertIn(("StarterPlayer", "StarterPlayerScripts", "BastiaoCliente", "Efeitos"), got)
        som = got[("StarterPlayer", "StarterPlayerScripts", "BastiaoCliente", "MonstroSom")]
        criatura = got[("ServerScriptService", "BastiaoServidor", "Criatura")]
        # versão 17 (Antigravity no Studio) conferida e juntada: pode ser trocada; o resto continua bloqueado
        self.assertIn("57534ab5b08836746b944f5002fc62041840a60cdbe277a858a652a778b3e69f", criatura["known"])
        self.assertIn("6c1303567f0bd8f99441187cc37adf49df2fc8ace0e6e19195891728cfbc5510", som["known"])
        self.assertNotIn(hashlib.sha256(b"-- outra fonte").hexdigest(), criatura["known"])

    def test_combined_audio_preserves_eight_voices_and_knock_and_binds_new_segments(self):
        files, _ = builder.build_files(self.root)
        data = json.loads(files["audio.json"])
        old = self.read("legado/audio.json")
        for name, segment in old["vozes"]["pt"].items():
            self.assertEqual(data["vozes"]["pt"][name], segment)
        self.assertEqual(data["sfx"]["toques_longe"], [0.05, 4.586])
        self.assertEqual(data["vozes"]["pt"]["pavel_afasta"], [0.1, 2, "new_atlas"])
        self.assertEqual(data["sfx"]["estatica"], [2.3, 2, "new_atlas"])
        self.assertEqual(data["loops"]["ambiente"], [4.5, 3, "new_atlas"])
        config = json.loads(files["package.json"])
        self.assertEqual(config["stage"], 3)
        self.assertEqual(config["legacyAudioIds"], {"efeitos": 500, "voz_pt": 501, "new_atlas": 600})
        self.assertEqual(files["audio/new_atlas.ogg"], b"new atlas bytes")

    def test_every_required_asset_must_be_approved_granted_and_hash_matched(self):
        original = self.read("audio/UPLOADED_ASSETS.json")
        for changes in ({"status": "pending_moderation"}, {"moderationState": "Reviewing"},
                        {"permissionStatus": "pending"}, {"sha256": "b" * 64}, {"assetId": "0"}):
            with self.subTest(changes=changes):
                receipt = copy.deepcopy(original)
                receipt["assets"][0].update(changes)
                write_json(self.root / "audio/UPLOADED_ASSETS.json", receipt)
                with self.assertRaises(builder.BuildError):
                    builder.build_files(self.root)
        write_json(self.root / "audio/UPLOADED_ASSETS.json", original)

    def test_manifest_file_change_cannot_reuse_old_uploaded_asset_id(self):
        (self.root / "audio/publish/new_atlas.ogg").write_bytes(b"modified atlas")
        with self.assertRaises(builder.BuildError):
            builder.build_files(self.root)

    def test_duplicate_or_foreign_target_receipts_block_build(self):
        original = self.read("audio/UPLOADED_ASSETS.json")
        for case in ("duplicate", "foreign"):
            receipt = copy.deepcopy(original)
            if case == "duplicate":receipt["assets"].append(copy.deepcopy(receipt["assets"][0]))
            else:receipt["target"]["placeId"] = "123"
            write_json(self.root / "audio/UPLOADED_ASSETS.json", receipt)
            with self.assertRaises(builder.BuildError):builder.build_files(self.root)

    def test_plan_missing_required_new_clip_blocks_build(self):
        plan = self.read("audio/AUDIO_PLAN.json")
        plan["clips"].append({"key": "missing_voice", "enabled": True})
        write_json(self.root / "audio/AUDIO_PLAN.json", plan)
        with self.assertRaises(builder.BuildError):builder.build_files(self.root)

    def test_missing_runtime_implementation_is_not_silently_skipped(self):
        (self.root / "src/client/Som.luau").unlink()
        with self.assertRaises(builder.BuildError):builder.build_files(self.root)

    def test_monster_catalog_requires_all35_clips_and_keeps_markers(self):
        plan = self.read("modelo/MONSTER_ASSET_PLAN.json")
        catalog = builder.monster_catalog(plan, self.read("modelo/UPLOADED_ASSETS.json"))
        self.assertEqual(len(catalog["animations"]), 35)
        self.assertEqual(catalog["animations"]["01_CLIP"]["id"], 10001)
        self.assertEqual(catalog["animations"]["01_CLIP"]["markers"], [{"name": "Step", "time": 1, "value": "L"}])
        plan["animations"].pop()
        with self.assertRaises(builder.BuildError):builder.monster_catalog(plan, self.read("modelo/UPLOADED_ASSETS.json"))

    def test_verified_package_patches_latest_place_and_refuses_foreign_source(self):
        from instalador.package import Package
        from instalador.codec import Failure
        files, _ = builder.build_files(self.root)
        try:
            package = Package(files)
        except Failure as exc:
            self.fail("The installer must accept the approved bound package: " + str(exc))
        root = ET.Element("roblox", version="4")
        nodes = {(): root}
        from instalador.stamina import source_row, ORIGINAL
        config = source_row(); config["source"] = ORIGINAL
        for row in [*self.baseline, config]:
            path = tuple(row["path"])
            for depth in range(1, len(path)):
                prefix = path[:depth]
                if prefix not in nodes:
                    node = ET.SubElement(nodes[prefix[:-1]], "Item", {"class": prefix[-1]})
                    ET.SubElement(ET.SubElement(node, "Properties"), "string", name="Name").text = prefix[-1]
                    nodes[prefix] = node
            node = ET.SubElement(nodes[path[:-1]], "Item", {"class": row["cls"]})
            props = ET.SubElement(node, "Properties")
            ET.SubElement(props, "string", name="Name").text = path[-1]
            ET.SubElement(props, "ProtectedString", name="Source").text = row["source"]
            nodes[path] = node
        ET.SubElement(root, "External", {"opaque": "keep-map-and-HUD"})
        raw = ET.tostring(root)
        patched, changed = package.patch(raw)
        self.assertTrue(changed)
        self.assertEqual(package.patch(patched), (patched, False))
        self.assertEqual(ET.fromstring(patched).find("External").get("opaque"), "keep-map-and-HUD")
        node = nodes[("ServerScriptService", "BastiaoServidor")]
        node.find("Properties/ProtectedString").text = "print('foreign modification')"
        with self.assertRaises(Failure):package.patch(ET.tostring(root))

    def test_package_cannot_replace_approved_ids_with_silent_zero_ids(self):
        from instalador.package import Package
        from instalador.codec import Failure
        files, _ = builder.build_files(self.root)
        try:
            package = Package(files)
        except Failure as exc:
            self.fail("Approved package could not be constructed: " + str(exc))
        with self.assertRaises(Failure):package.usar_ids({})
        with self.assertRaises(Failure):package.usar_ids({"efeitos": 500, "voz_pt": 0, "new_atlas": 600})


if __name__ == "__main__":
    unittest.main()
