import gzip
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlsplit

from install.cloud import API, Cloud, CREATOR_ID, PLACE_ID, PUBLISH_ROUTE, UNIVERSE_ID, Version
from install.codec import Binary, Failure, pack32, prefs, pstring, puints, uints
from install.cyber_installer import (
    CONFIG_MARKER, CONFIRMATION, V1_ASSET_TYPES, Installer, _asset_table, _luau,
    _prepare_update, _split_assets, load_config, server_from_package, source_from_package,
)
from install.patcher import (
    BINARY_MAGIC, MENU_PATH, SERVER_HEADER, menu_source, patch_place, same_binary_place, server_source, source_digest,
)
from install.paths import locked_state


XML_SHELL = """<?xml version="1.0" encoding="utf-8"?>
<?preserve directive?>
<roblox version="4">
  <!-- Keep exact visual layout -->
  <Item class="Workspace" referent="RBX0">
    <Properties><string name="Name">Workspace</string></Properties>
    <Item class="Part" referent="RBX1">
      <Properties><string name="Name">Existing map</string><string name="Opaque">A&amp;B</string></Properties>
    </Item>
  </Item>
  <Item class="StarterGui" referent="RBX2">
    <Item class="ScreenGui" referent="RBX3"><Properties><string name="Name">HUD</string></Properties></Item>
  </Item>
  <Item class="StarterPlayer" referent="RBX4">
    <Properties><string name="Name">StarterPlayer</string></Properties>
    <Item class="StarterPlayerScripts" referent="RBX5">
      <Properties><string name="Name">StarterPlayerScripts</string></Properties>
      <Item class="LocalScript" referent="RBX6">
        <Properties><string name="Name">Story</string><ProtectedString name="Source"><![CDATA[return 7 < 8]]></ProtectedString></Properties>
      </Item>
      %s
    </Item>
  </Item>
</roblox>
<!-- Keep this trailing comment -->
"""
MINIMAL_XML = b'<roblox version="4"><Item class="Workspace"/></roblox>'
SOURCE = '-- CyberOutlaw\nlocal detail = "ação ]]> & <"\nreturn detail\n'
V1_TEMPLATE = f"-- Release fixture v1\nlocal ASSETS = {CONFIG_MARKER}\nreturn ASSETS\n"
V2_TEMPLATE = f"-- Release fixture v2\nlocal ASSETS = {CONFIG_MARKER}\nreturn ASSETS\n"
LEGACY_CONFIG = {
    "video": 318,
    "sounds": {"click": 21, "hello": 22},
    "clips": {"idle": {"fps": 6, "frames": [{"id": 31, "x": 0, "y": 5, "w": 64, "h": 64}]}},
}
V2_CONFIG = {"art": {"title": 98, "billboard": 99}, "clips": {}, "sounds": {"click": 25}, "video": 0}


def bound(template, assets):
    return template.replace(CONFIG_MARKER, _luau(assets))


def xml_place(extra=""):
    return (XML_SHELL % extra).encode()


def _chunk(tag, body):
    return struct.pack("<4sIII", tag, 0, len(body), 0) + body


def make_binary(avatars=False):
    groups = [
        ("Workspace", [(0, "Workspace", None, -1)], True),
        ("Part", [(1, "Original map", None, 0)], False),
        ("StarterPlayer", [(2, "StarterPlayer", None, -1)], True),
        ("StarterPlayerScripts", [(3, "StarterPlayerScripts", None, 2)], False),
        ("LocalScript", [(4, "Story", b"return 123", 3)], False),
    ]
    if avatars:
        groups += [
            ("AvatarSettings", [(5, "AvatarSettings", None, -1)], True),
            ("AvatarRules", [(6, "DefaultAvatarRules", None, 5), (7, "NPC rules", None, 5)], False),
            ("AvatarBodyRules", [(8, "Body", None, 6), (9, "Body", None, 7)], False),
        ]
    instances, properties, children, parents = [], [], [], []
    for index, (class_name, objects, service) in enumerate(groups):
        group = pack32(index)
        refs, names, sources, ancestors = zip(*objects)
        children.extend(refs)
        parents.extend(ancestors)
        flags = b"\1" if service else b"\0"
        payload = group + pstring(class_name.encode()) + flags + pack32(len(refs)) + prefs(refs)
        instances.append(_chunk(b"INST", payload + (b"\1" if service else b"")))
        properties.append(_chunk(b"PROP", group + pstring(b"Name") + b"\1" + b"".join(pstring(name.encode()) for name in names)))
        if any(source is not None for source in sources):
            properties.append(_chunk(b"PROP", group + pstring(b"Source") + b"\1" + b"".join(pstring(source or b"") for source in sources)))
        if avatars and class_name in ("StarterPlayer", "AvatarRules", "AvatarBodyRules"):
            prop = b"GameSettingsAvatar" if class_name == "StarterPlayer" else b"AvatarType"
            properties.append(_chunk(b"PROP", group + pstring(prop) + b"\x12" + puints([1] * len(refs))))
    header = BINARY_MAGIC + b"\0\0" + struct.pack("<II8x", len(instances), len(children))
    parenting = _chunk(b"PRNT", b"\0" + pack32(len(children)) + prefs(children) + prefs(parents))
    opaque = _chunk(b"TEST", b"preserve unknown blocks bit for bit")
    return header + b"".join(instances + properties) + opaque + parenting + _chunk(b"END\0", b"</roblox>")


def make_binary_with_lighting():
    """Place binário mínimo com o serviço Lighting e Technology = Voxel."""
    groups = [("Lighting", [(0, "Lighting", None, -1)], True)]
    instances, properties, children, parents = [], [], [], []
    for index, (class_name, objects, service) in enumerate(groups):
        group = pack32(index)
        refs, names, _, ancestors = zip(*objects)
        children.extend(refs)
        parents.extend(ancestors)
        payload = group + pstring(class_name.encode()) + b"\1" + pack32(len(refs)) + prefs(refs)
        instances.append(_chunk(b"INST", payload + b"\1"))
        properties.append(_chunk(b"PROP", group + pstring(b"Name") + b"\1" + b"".join(pstring(name.encode()) for name in names)))
        properties.append(_chunk(b"PROP", group + pstring(b"Technology") + b"\x12" + puints([1])))
    header = BINARY_MAGIC + b"\0\0" + struct.pack("<II8x", len(instances), len(children))
    parenting = _chunk(b"PRNT", b"\0" + pack32(len(children)) + prefs(children) + prefs(parents))
    return header + b"".join(instances + properties) + parenting + _chunk(b"END\0", b"</roblox>")


class PatcherTests(unittest.TestCase):
    def test_native_binary_r6_updates_only_the_player_rules(self):
        binary, _ = patch_place(make_binary(avatars=True), SOURCE)
        ready, changed = patch_place(binary, SOURCE, force_r6=True)
        self.assertTrue(changed)
        before, after = Binary(binary), Binary(ready)
        self.assertEqual(before.parents, after.parents)
        self.assertEqual(menu_source(ready), SOURCE)
        for (group, name), (chunk, kind, start) in after.props.items():
            previous = before.props[group, name][0]
            if name == "GameSettingsAvatar":
                self.assertEqual(uints(chunk.data[start:], 1), [0])
            elif name == "AvatarType":
                self.assertEqual(uints(chunk.data[start:], 2), [0, 1])
            else:
                self.assertEqual(chunk.packet, previous.packet)
        self.assertEqual(patch_place(ready, SOURCE, force_r6=True), (ready, False))

    def test_native_xml_r6_with_default_and_linked_avatar_rules(self):
        raw = xml_place().replace(
            b'<string name="Name">StarterPlayer</string>',
            b'<string name="Name">StarterPlayer</string><Ref name="PlaceAvatarRules">custom</Ref>',
        ).replace(b"</roblox>", b"""
<Item class="AvatarSettings">
  <Item class="AvatarRules" referent="default"><Properties>
    <string name="Name">DefaultAvatarRules</string><token name="AvatarType">1</token>
  </Properties><Item class="AvatarBodyRules"><Properties><token name="AvatarType">1</token></Properties></Item></Item>
  <Item class="AvatarRules" referent="custom"><Properties><token name="AvatarType">2</token></Properties></Item>
  <Item class="AvatarRules" referent="untouched"><Properties><token name="AvatarType">1</token></Properties></Item>
</Item>
</roblox>""")
        ready, changed = patch_place(raw, SOURCE, force_r6=True)
        self.assertTrue(changed)
        self.assertEqual(ready.count(b'<token name="GameSettingsAvatar">0</token>'), 1)
        self.assertEqual(ready.count(b'<token name="AvatarType">0</token>'), 3)
        self.assertEqual(ready.count(b'<token name="AvatarType">1</token>'), 1)
        self.assertIn(b'<Ref name="PlaceAvatarRules">custom</Ref>', ready)
        self.assertEqual(patch_place(ready, SOURCE, force_r6=True), (ready, False))

    def test_lighting_realistic_in_xml_and_binary(self):
        raw = xml_place().replace(b"</roblox>", b"""
<Item class="Lighting" referent="L"><Properties><string name="Name">Lighting</string>
  <token name="Technology">1</token><bool name="PrioritizeLightingQuality">false</bool></Properties></Item>
</roblox>""")
        ready, changed = patch_place(raw, SOURCE, force_r6=True)
        self.assertTrue(changed)
        self.assertIn(b'<token name="Technology">5</token>', ready)
        self.assertIn(b'<token name="LightingStyle">0</token>', ready)
        self.assertIn(b'<bool name="PrioritizeLightingQuality">true</bool>', ready)
        self.assertEqual(patch_place(ready, SOURCE, force_r6=True), (ready, False))
        binary = make_binary(avatars=True)
        # Serviço Lighting num place binário: as três propriedades nascem no PROP.
        ready, changed = patch_place(binary, SOURCE, force_r6=True)
        doc = Binary(ready)
        self.assertTrue(changed)
        self.assertEqual(patch_place(ready, SOURCE, force_r6=True), (ready, False))

    def test_binary_lighting_properties(self):
        from install.patcher import _binary_lighting
        groups_raw = make_binary_with_lighting()
        doc = Binary(groups_raw)
        self.assertTrue(_binary_lighting(doc))
        again = Binary(doc.encode())
        values = {}
        for (group, name), (chunk, kind, start) in again.props.items():
            if name in ("Technology", "LightingStyle"):
                values[name] = uints(chunk.data[start:], 1)[0]
            elif name == "PrioritizeLightingQuality":
                values[name] = chunk.data[start]
        self.assertEqual(values, {"Technology": 5, "LightingStyle": 0, "PrioritizeLightingQuality": 1})
        self.assertFalse(_binary_lighting(again))

    def test_xml_keeps_original_bytes_outside_new_script(self):
        raw = xml_place()
        updated, changed = patch_place(raw, SOURCE)
        self.assertTrue(changed)
        self.assertEqual(menu_source(updated), SOURCE)
        begin = updated.index(b'<Item class="LocalScript" referent="RBX_CYBEROUTLAW_CyberOutlawMenu">')
        end = updated.index(b'</Item>', begin) + len(b'</Item>')
        self.assertEqual(updated[:begin] + updated[end:], raw)
        self.assertEqual(patch_place(updated, SOURCE), (updated, False))

    def test_missing_canonical_containers_and_utf16(self):
        for encoding in ("utf-8", "utf-16", "utf-16-be"):
            raw = '<roblox version="4"><Item class="Workspace" referent="RBX1"/></roblox>'.encode(encoding)
            with self.subTest(encoding=encoding):
                updated, changed = patch_place(raw, SOURCE)
                self.assertTrue(changed)
                self.assertEqual(menu_source(updated), SOURCE)
                self.assertEqual(patch_place(updated, SOURCE), (updated, False))
        raw = b'<roblox version="4"><Item class="StarterPlayer"/></roblox>'
        self.assertEqual(menu_source(patch_place(raw, SOURCE)[0]), SOURCE)

    def test_foreign_menu_rejected_even_with_our_name_and_comments(self):
        foreign = (
            '<Item class="LocalScript"><Properties><string name="Name">CyberOutlawMenu</string>'
            '<ProtectedString name="Source">-- CyberOutlaw\nreturn "foreign"</ProtectedString>'
            '</Properties></Item>'
        )
        with self.assertRaisesRegex(Failure, "código desconhecido"):
            patch_place(xml_place(foreign), SOURCE)

    def test_wrong_types_and_ambiguous_ancestors_rejected(self):
        wrong = b'<roblox version="4"><Item class="Folder"><Properties><string name="Name">StarterPlayer</string></Properties></Item></roblox>'
        renamed = b'<roblox version="4"><Item class="StarterPlayer"><Properties><string name="Name">Custom</string></Properties></Item></roblox>'
        duplicated = b'<roblox version="4"><Item class="StarterPlayer"/><Item class="StarterPlayer"/></roblox>'
        for raw in (wrong, renamed, duplicated):
            with self.subTest(raw=raw), self.assertRaises(Failure):
                patch_place(raw, SOURCE)

    def test_xml_update_only_replaces_verified_source_markup(self):
        one, _ = patch_place(xml_place(), SOURCE)
        two, changed = patch_place(one, "return 9", {source_digest(SOURCE)})
        self.assertTrue(changed)
        start = one.index(b'<ProtectedString name="Source">-- CyberOutlaw')
        end = one.index(b'</ProtectedString>', start) + len(b'</ProtectedString>')
        self.assertEqual(two, one[:start] + b'<ProtectedString name="Source">return 9</ProtectedString>' + one[end:])
        self.assertEqual(menu_source(two), "return 9")

    def test_binary_keeps_existing_chunks_and_story_source(self):
        raw = make_binary()
        updated, changed = patch_place(raw, SOURCE)
        self.assertTrue(changed)
        original = Binary(raw)
        candidate = Binary(updated)
        original_packets = [chunk.packet for chunk in original.chunks if chunk.tag != b"PRNT"]
        retained_packets = [chunk.packet for chunk in candidate.chunks if chunk.packet in original_packets]
        self.assertEqual(retained_packets, original_packets)
        self.assertEqual({ref: candidate.parents[ref] for ref in original.objects}, original.parents)
        story_path = (*MENU_PATH[:-1], "Story")
        self.assertEqual(candidate.value(candidate.locate(story_path), "Source"), b"return 123")
        self.assertEqual(patch_place(updated, SOURCE), (updated, False))
        with self.assertRaisesRegex(Failure, "código desconhecido"):
            patch_place(updated, "return 'another menu'")
        newer, _ = patch_place(updated, "return 9", {source_digest(SOURCE)})
        changed_chunks = [
            (before, after) for before, after in zip(candidate.chunks, Binary(newer).chunks)
            if before.packet != after.packet
        ]
        self.assertEqual(len(changed_chunks), 1)
        self.assertEqual(changed_chunks[0][0].tag, b"PROP")
        self.assertEqual(menu_source(newer), "return 9")

    def test_binary_repacking_retains_all_chunks(self):
        original, _ = patch_place(make_binary(), SOURCE)
        parsed = Binary(original)
        repacked = parsed.header + b"".join(_chunk(block.tag, block.data) for block in parsed.chunks)
        self.assertNotEqual(original, repacked)
        self.assertTrue(same_binary_place(original, repacked))
        different_map = repacked.replace(b"preserve unknown blocks", b"preserve strange blocks")
        self.assertFalse(same_binary_place(original, different_map))

    @patch("install.cyber_installer.V1_TEMPLATE_SHA256", source_digest(V1_TEMPLATE))
    def test_upgrade_keeps_granted_assets_and_changes_only_owned_source(self):
        old = bound(V1_TEMPLATE, LEGACY_CONFIG)
        original, _ = patch_place(xml_place(), old)
        ready, changed, source = _prepare_update(original, bound(V2_TEMPLATE, V2_CONFIG))
        expected = {**LEGACY_CONFIG, "art": V2_CONFIG["art"], "sounds": {"click": 25, "hello": 22}}
        self.assertTrue(changed)
        self.assertEqual(source, bound(V2_TEMPLATE, expected))
        self.assertEqual(source, menu_source(ready))
        self.assertEqual(patch_place(original, source, {source_digest(old)}), (ready, True))
        self.assertEqual(_prepare_update(ready, bound(V2_TEMPLATE, V2_CONFIG)), (ready, False, source))

    @patch("install.cyber_installer.V1_TEMPLATE_SHA256", source_digest(V1_TEMPLATE))
    def test_edited_v1_or_executable_asset_line_remains_untouched(self):
        old = bound(V1_TEMPLATE, LEGACY_CONFIG)
        edited_sources = (
            old.replace("return ASSETS", "return {}"),
            old.replace('["video"] = 318}', '["video"] = (function() return 318 end)()}'),
            old.replace('["video"] = 318}', '["video"] = 318}; local other = {}'),
            old.replace('["video"] = 318}', '["video"] = 318, ["video"] = 319}'),
        )
        for edited in edited_sources:
            with self.subTest(edited=edited):
                prior, _ = patch_place(xml_place(), edited)
                with self.assertRaisesRegex(Failure, "código desconhecido"):
                    _prepare_update(prior, bound(V2_TEMPLATE, V2_CONFIG))
                self.assertEqual(menu_source(prior), edited)

    def test_server_scripts_are_added_updated_and_guarded(self):
        guard = f"{SERVER_HEADER}CyberOutlawR6\nprint('r6')\n"
        city = f"{SERVER_HEADER}CyberOutlawCity\nprint('city v1')\n"
        newer_city = f"{SERVER_HEADER}CyberOutlawCity\nprint('city v2')\n"
        for name, raw in (("xml", xml_place()), ("binary", make_binary(avatars=True))):
            with self.subTest(format=name):
                ready, changed = patch_place(raw, SOURCE, force_r6=True, server={"CyberOutlawR6": guard, "CyberOutlawCity": city})
                self.assertTrue(changed)
                self.assertEqual(menu_source(ready), SOURCE)
                self.assertEqual(server_source(ready, "CyberOutlawR6"), guard)
                self.assertEqual(server_source(ready, "CyberOutlawCity"), city)
                servers = {"CyberOutlawR6": guard, "CyberOutlawCity": city}
                self.assertEqual(patch_place(ready, SOURCE, force_r6=True, server=servers), (ready, False))
                updated, changed = patch_place(ready, SOURCE, force_r6=True, server={**servers, "CyberOutlawCity": newer_city})
                self.assertTrue(changed)
                self.assertEqual(server_source(updated, "CyberOutlawCity"), newer_city)
                self.assertEqual(server_source(updated, "CyberOutlawR6"), guard)
                self.assertEqual(menu_source(updated), SOURCE)
                if name == "binary":
                    doc = Binary(updated)
                    services = [ref for ref, obj in doc.objects.items() if obj["class"] == "ServerScriptService"]
                    self.assertEqual(len(services), 1)
                    self.assertEqual(doc.groups[doc.objects[services[0]]["group"]]["service"], 1)
                    self.assertEqual(doc.value(doc.locate(("Workspace", "Original map")), "Name"), b"Original map")
                else:
                    self.assertEqual(updated.count(b'<Item class="ServerScriptService"'), 1)
                    self.assertIn(b"Existing map", updated)

    def test_foreign_server_script_and_missing_header_are_rejected(self):
        foreign = (
            '</Item></Item><Item class="ServerScriptService"><Item class="Script"><Properties>'
            '<string name="Name">CyberOutlawCity</string><ProtectedString name="Source">print("mine")</ProtectedString>'
            '</Properties></Item></Item><Item class="Folder"><Item class="Folder">'
        )
        city = f"{SERVER_HEADER}CyberOutlawCity\nprint('city')\n"
        with self.assertRaisesRegex(Failure, "código desconhecido"):
            patch_place(xml_place(foreign), SOURCE, server={"CyberOutlawCity": city})
        with self.assertRaisesRegex(Failure, "cabeçalho"):
            patch_place(xml_place(), SOURCE, server={"CyberOutlawCity": "print('no header')"})
        with self.assertRaisesRegex(Failure, "Nome inválido"):
            patch_place(xml_place(), SOURCE, server={"Other": f"{SERVER_HEADER}Other\n"})

    def test_package_server_scripts_bind_only_photo_textures(self):
        config = load_config(Path("/nonexistent/ASSETS.json"))
        config["art"] = {"asphalt": 11, "asphalt_normal": 12, "concrete": 13, "billboard": 14, "facades": 15}
        scripts = server_from_package(Path(__file__).resolve().parents[1], config)
        self.assertEqual(sorted(scripts), ["CyberOutlawArsenal", "CyberOutlawCity", "CyberOutlawPlay", "CyberOutlawR6", "CyberOutlawVida"])
        play = scripts.pop("CyberOutlawPlay")
        self.assertTrue(play.startswith("-- CyberOutlaw · script de cliente gerenciado: CyberOutlawPlay\n"))
        self.assertIn('local MEDIA = {["icones"] = 0, ["sons"] = {', play)
        self.assertNotIn("__CYBEROUTLAW_MEDIA__", play)
        for name, code in scripts.items():
            self.assertTrue(code.startswith(f"{SERVER_HEADER}{name}\n"))
            self.assertNotIn("__CYBEROUTLAW_ART__", code)
        city = scripts["CyberOutlawCity"]
        self.assertIn('local ART = {["asphalt"] = 11, ["asphalt_normal"] = 12, ["concrete"] = 13}', city)
        self.assertNotIn("15", city.split("local ART = ", 1)[1].split("\n", 1)[0])
        config["art"].update({"fachada_vidro": 21, "vitrines": 22, "poca_1": 23, "ceu_up": 24, "tijolo": 25})
        city = server_from_package(Path(__file__).resolve().parents[1], config)["CyberOutlawCity"]
        line = city.split("local ART = ", 1)[1].split("\n", 1)[0]
        for key in ("fachada_vidro", "vitrines", "poca_1", "ceu_up", "tijolo"):
            self.assertIn(f'["{key}"]', line, "code-drawn and CC0 city art reaches the city script")
        self.assertNotIn('["facades"]', line)
        self.assertNotIn('["billboard"]', line)

    @patch("install.cyber_installer.HUD_TEMPLATE_SHA256", source_digest(V1_TEMPLATE))
    def test_hud_v1_menu_upgrades_without_local_receipts(self):
        old = bound(V1_TEMPLATE, {**LEGACY_CONFIG, "art": {"asphalt": 41}})
        original, _ = patch_place(xml_place(), old)
        ready, changed, source = _prepare_update(original, bound(V2_TEMPLATE, V2_CONFIG), force_r6=True)
        self.assertTrue(changed)
        self.assertEqual(menu_source(ready), source)
        self.assertIn('["asphalt"] = 41', source)

    def test_malformed_and_dtd_are_rejected(self):
        with self.assertRaisesRegex(Failure, "declaração"):
            patch_place(b'<!DOCTYPE roblox [<!ENTITY unsafe "text">]><roblox version="4"/>', SOURCE)
        with self.assertRaises(Failure):
            patch_place(make_binary()[:-17], SOURCE)


class ConfigTests(unittest.TestCase):
    def test_template_embeds_city_and_numeric_assets(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "src").mkdir()
            (root / "config").mkdir()
            (root / "src" / "menu.client.luau").write_text(
                "local ASSETS = __CYBEROUTLAW_CONFIG__\n-- __CYBEROUTLAW_CITY__\n-- __CYBEROUTLAW_SCENE__\n-- __CYBEROUTLAW_HUD__\nreturn ASSETS"
            )
            (root / "src" / "city.luau").write_text("local function createCyberCity(parent) end\n")
            (root / "src" / "scene.luau").write_text("local function createCyberScene(parent) end\n")
            (root / "src" / "hud.luau").write_text("local function mountCyberOutlawHud() end\n")
            empty, config = source_from_package(root)
            self.assertEqual(config, {"video": 0, "clips": {}, "sounds": {}, "art": {}})
            self.assertIn("local function createCyberCity(parent)", empty)
            self.assertLess(empty.index("local function createCyberCity"), empty.index("local function createCyberScene"))
            self.assertIn("local function mountCyberOutlawHud()", empty)
            data = {
                "video": 218,
                "art": {"title": 24, "billboard": 49},
                "sounds": {"hover": 21},
                "clips": {"idle": {"fps": 6, "frames": [{"id": 31, "x": 0, "y": 5, "w": 64, "h": 64}]}},
            }
            ASSETS = root / "config" / "ASSETS.json"
            ASSETS.write_text(json.dumps(data))
            text, normalized = source_from_package(root)
            self.assertNotIn("__CYBEROUTLAW_", text)
            self.assertIn('["id"] = 31', text)
            self.assertIn('["billboard"] = 49', text)
            self.assertEqual(normalized["sounds"]["hover"], 21)
            self.assertEqual(_asset_table(_split_assets(text)[1], {*V1_ASSET_TYPES, "art"}), normalized)
            ASSETS.write_text('{"video":0,"video":23}')
            with self.assertRaises(Failure):
                load_config(ASSETS)
            ASSETS.write_text('{"background":23}')
            with self.assertRaises(Failure):
                load_config(ASSETS)


class FakeCloud:
    def __init__(self, *, lost_response=False, reject_code=None):
        self.rows = [Version(8, False), Version(7, True)]
        self.versions = {8: xml_place(), 7: MINIMAL_XML}
        self.lost_response = lost_response
        self.reject_code = reject_code
        self.publish_calls = []
        self.download_calls = []
        self.visible = True

    def validate_destination(self):
        pass

    def history(self):
        return list(self.rows)

    def download(self, version):
        self.download_calls.append(version)
        return self.versions[version]

    def publish(self, raw):
        self.publish_calls.append(raw)
        if self.reject_code is not None:
            raise Failure("Publicação rejeitada.", code=self.reject_code)
        if self.visible:
            self.rows.insert(0, Version(9, True))
            self.versions[9] = raw
        if self.lost_response:
            raise Failure("A conexão encerrou durante a resposta.")
        return 9


class InstallTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.state = Path(folder.name)
        self.messages = []
        self.installer = Installer(self.state, report=self.messages.append, sleeper=lambda _: None)

    @patch("install.paths.os.link", create=True, side_effect=AttributeError("os.link indisponível"))
    def test_backup_separate_versions_before_confirmation_and_verify(self, link):
        cloud = FakeCloud()

        def confirm(prompt):
            self.assertIn(CONFIRMATION, prompt)
            self.assertEqual(cloud.download_calls, [7, 8])
            self.assertEqual((self.state / "backup-v7.rbxlx").read_bytes(), cloud.versions[7])
            self.assertEqual((self.state / "backup-v8.rbxlx").read_bytes(), cloud.versions[8])
            self.assertEqual(cloud.publish_calls, [])
            return CONFIRMATION

        with locked_state(self.state):
            self.installer.install(cloud, SOURCE, confirm)
        link.assert_not_called()
        self.assertEqual(len(cloud.publish_calls), 1)
        self.assertEqual(cloud.download_calls, [7, 8, 9])
        self.assertIsNone(self.installer.pending())
        receipt = json.loads(next(self.state.glob("receipt-*.json")).read_text())
        self.assertEqual(receipt["status"], "VERIFIED")
        self.assertEqual(receipt["version"], 9)
        self.assertEqual(receipt["request"]["source_sha256"], source_digest(SOURCE))
        self.assertEqual(menu_source(cloud.versions[9]), SOURCE)
        self.assertEqual(self.installer._known_sources(), {source_digest(SOURCE)})

    def test_confirmation_cancellation_and_version_drift_make_no_post(self):
        cloud = FakeCloud()
        with self.assertRaisesRegex(Failure, "cancelada"):
            self.installer.install(cloud, SOURCE, lambda _: "voltar")
        self.assertEqual(cloud.publish_calls, [])
        self.assertIsNone(self.installer.pending())

        def concurrent_save(_):
            cloud.rows.insert(0, Version(9, False))
            return CONFIRMATION

        with self.assertRaisesRegex(Failure, "mudou"):
            self.installer.install(cloud, SOURCE, concurrent_save)
        self.assertEqual(cloud.publish_calls, [])
        self.assertIsNone(self.installer.pending())

    def test_lost_post_response_verifies_through_get_without_retry(self):
        cloud = FakeCloud(lost_response=True)
        self.installer.install(cloud, SOURCE, lambda _: CONFIRMATION)
        self.assertEqual(len(cloud.publish_calls), 1)
        self.assertEqual(cloud.download_calls, [7, 8, 9])
        self.assertIsNone(self.installer.pending())
        self.assertEqual(len(list(self.state.glob("receipt-*.json"))), 1)

    def test_resume_accepts_only_equivalent_repacked_binary(self):
        cloud = FakeCloud(lost_response=True)
        cloud.versions[8] = make_binary()
        cloud.visible = False
        with self.assertRaisesRegex(Failure, "Execute resume"):
            self.installer.install(cloud, SOURCE, lambda _: CONFIRMATION)
        parsed = Binary(cloud.publish_calls[0])
        repacked = parsed.header + b"".join(_chunk(block.tag, block.data) for block in parsed.chunks)
        cloud.rows.insert(0, Version(9, True))
        cloud.versions[9] = repacked.replace(b"preserve unknown blocks", b"preserve strange blocks")
        with self.assertRaisesRegex(Failure, "Execute resume"):
            self.installer.resume(cloud)
        cloud.versions[9] = repacked
        self.installer.resume(cloud)
        receipt = json.loads(next(self.state.glob("receipt-*.json")).read_text())
        self.assertEqual(receipt["comparison"], "binary_chunks")
        self.assertEqual(len(cloud.publish_calls), 1)

    @patch("install.cyber_installer.V1_TEMPLATE_SHA256", source_digest(V1_TEMPLATE))
    def test_upgrade_carries_published_media_when_saved_place_has_no_menu(self):
        cloud = FakeCloud()
        cloud.versions[7] = patch_place(xml_place(), bound(V1_TEMPLATE, LEGACY_CONFIG))[0]
        cloud.versions[8] = make_binary()
        self.installer.install(cloud, bound(V2_TEMPLATE, V2_CONFIG), lambda _: CONFIRMATION)
        published = cloud.versions[9]
        expected = {**LEGACY_CONFIG, "art": V2_CONFIG["art"], "sounds": {"click": 25, "hello": 22}}
        self.assertEqual(menu_source(published), bound(V2_TEMPLATE, expected))
        original = Binary(published)
        ref = original.locate((*MENU_PATH[:-1], "Story"))
        self.assertEqual(original.value(ref, "Source"), b"return 123")

    def test_resume_keeps_pending_until_matching_download(self):
        cloud = FakeCloud(lost_response=True)
        cloud.visible = False
        with self.assertRaisesRegex(Failure, "Execute resume"):
            self.installer.install(cloud, SOURCE, lambda _: CONFIRMATION)
        self.assertIsNotNone(self.installer.pending())
        with self.assertRaisesRegex(Failure, "Execute resume"):
            self.installer.install(cloud, SOURCE, lambda _: CONFIRMATION)
        self.assertEqual(len(cloud.publish_calls), 1)
        cloud.rows.insert(0, Version(9, True))
        cloud.versions[9] = MINIMAL_XML
        with self.assertRaisesRegex(Failure, "Execute resume"):
            self.installer.resume(cloud)
        self.assertIsNotNone(self.installer.pending())
        cloud.versions[9] = cloud.publish_calls[0]
        self.installer.resume(cloud)
        self.assertIsNone(self.installer.pending())
        self.assertEqual(len(cloud.publish_calls), 1)

    def test_already_published_and_rejected_post(self):
        cloud = FakeCloud(reject_code=403)
        with self.assertRaises(Failure):
            self.installer.install(cloud, SOURCE, lambda _: CONFIRMATION)
        self.assertIsNone(self.installer.pending())
        receipt = json.loads(next(self.state.glob("receipt-*.json")).read_text())
        self.assertEqual(receipt["status"], "REJECTED")
        cloud.rows = [Version(10, True), *cloud.rows]
        cloud.versions[10] = patch_place(xml_place(), SOURCE)[0]
        self.installer.install(cloud, SOURCE, lambda _: self.fail("already live"))
        self.assertEqual(len(cloud.publish_calls), 1)


class _Response(io.BytesIO):
    def __init__(self, raw, headers=None):
        super().__init__(raw)
        self.headers = headers or {}


class CloudTests(unittest.TestCase):
    def test_pinned_identity_paginated_history_and_cdn_key_isolation(self):
        requests = []
        download = "https://assetdelivery.rbxcdn.com/place?signature=mock"

        class Opener:
            def open(self, request, timeout):
                requests.append(request)
                url = urlsplit(request.full_url)
                if url.path.endswith("/universe"):
                    result = {"universeId": UNIVERSE_ID}
                elif url.path == "/v1/games":
                    result = {"data": [{"id": UNIVERSE_ID, "rootPlaceId": PLACE_ID, "creator": {"id": CREATOR_ID, "type": "User"}}]}
                elif url.path.endswith("/versions"):
                    second = "pageToken" in parse_qs(url.query)
                    row = {"path": f"assets/{PLACE_ID}/versions/{7 if second else 8}"}
                    if second:
                        row["published"] = True
                    result = {"assetVersions": [row], "nextPageToken": "" if second else "opaque = token"}
                elif request.full_url == download:
                    return _Response(gzip.compress(MINIMAL_XML), {"Content-Encoding": "gzip"})
                else:
                    result = {"location": download, "assetTypeId": 9}
                return _Response(json.dumps(result).encode())

        cloud = Cloud("test-only", opener=Opener())
        cloud.validate_destination()
        self.assertEqual(cloud.history(), [Version(8, False), Version(7, True)])
        self.assertEqual(cloud.download(8), MINIMAL_XML)
        self.assertEqual([request.get_header("X-api-key") for request in requests], [None, None, "test-only", "test-only", "test-only", None])
        self.assertEqual(parse_qs(urlsplit(requests[3].full_url).query)["pageToken"], ["opaque = token"])

    def test_post_never_retried_or_followed(self):
        for error in (URLError("connection"), HTTPError(API + PUBLISH_ROUTE, 307, "redirect", {"Location": "https://example.com"}, None)):
            requests = []

            class Opener:
                def open(self, request, timeout):
                    requests.append(request)
                    raise error

            with self.subTest(error=error):
                cloud = Cloud("test-only", opener=Opener(), sleeper=lambda _: self.fail("cannot retry"))
                with self.assertRaises(Failure):
                    cloud.publish(MINIMAL_XML)
                self.assertEqual(len(requests), 1)
                self.assertEqual(requests[0].get_method(), "POST")
                self.assertEqual(requests[0].full_url, API + PUBLISH_ROUTE)
                self.assertEqual(requests[0].get_header("Content-type"), "application/xml")


if __name__ == "__main__":
    unittest.main()
